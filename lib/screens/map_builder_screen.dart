// File: lib/screens/map_builder_screen.dart
// Map Sheets hub. Same layout as the Lance Builder hub: the options on the
// left, a panel on the right. New Map and Import open the full-screen map
// editor; Edit Map lists the saved maps.
//
// Saved maps hold printed reference data only. Changes that players make
// for one skirmish (placed buildings, and later destroyed terrain) belong
// in a separate layer that the skirmish map class manages.

import 'dart:io';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:map_extractor_prototype/map_extractor.dart';
import 'package:path/path.dart' as p;

import '../app_theme.dart';
import '../maps/map_editor_controller.dart' show btmapTypeGroup;
import '../maps/map_repository.dart';
import '../widgets/hex_map_art.dart';
import '../widgets/hud.dart';
import '../widgets/map/hex_map_view.dart';
import '../widgets/map/new_map_form.dart';
import '../widgets/map/saved_map_list.dart';
import 'map_editor_screen.dart';

/// What the side panel shows.
enum _PanelMode { art, newMap, editMap }

class MapBuilderScreen extends ConsumerStatefulWidget {
  const MapBuilderScreen({super.key});

  @override
  ConsumerState<MapBuilderScreen> createState() => _MapBuilderScreenState();
}

class _MapBuilderScreenState extends ConsumerState<MapBuilderScreen> {
  _PanelMode _mode = _PanelMode.art;

  /// The saved map shown in full under Edit Map; null shows the list.
  String? _openMapId;

  static const double _wideBreakpoint = 960;
  static const double _minPanelHeight = 600;

  void _show(_PanelMode mode) => setState(() => _mode = mode);

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Opens the editor. Afterwards the panel shows the map under Edit Map,
  /// or the list when the map was never saved.
  Future<void> _openEditor(SavedMap map) async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => MapEditorScreen(map: map)));
    if (!mounted) return;
    setState(() {
      _mode = _PanelMode.editMap;
      _openMapId = map.id;
    });
  }

  void _onCreate(NewMapRequest request) => _openEditor(
    SavedMap.create(
      MapSheet(name: request.name, grid: request.grid, hexes: const {}),
    ),
  );

  /// Reads a btmap file and opens it in the editor as a new map. The file
  /// is only saved when the user saves in the editor.
  Future<void> _import() async {
    final file = await openFile(acceptedTypeGroups: const [btmapTypeGroup]);
    if (file == null || !mounted) return;
    final MapSheet sheet;
    try {
      sheet = MapSheet.fromJsonString(await File(file.path).readAsString());
    } on Object catch (e) {
      _snack('Could not open ${p.basename(file.path)}: $e');
      return;
    }
    if (!mounted) return;
    await _openEditor(SavedMap.create(sheet));
  }

  Future<void> _export(SavedMap map) async {
    final base = map.name.trim().isEmpty
        ? 'map'
        : map.name.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    try {
      final loc = await getSaveLocation(
        acceptedTypeGroups: const [btmapTypeGroup],
        suggestedName: '$base.btmap.json',
      );
      if (loc == null) return;
      await File(loc.path).writeAsString(map.sheet.toJsonString());
      _snack('Exported ${p.basename(loc.path)}.');
    } on Object catch (e) {
      _snack('Could not export ${map.name}: $e');
    }
  }

  Future<void> _delete(SavedMap map) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${map.name}?'),
        content: const Text('The saved map is removed. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(savedMapsProvider.notifier).delete(map.id);
      if (mounted) setState(() => _openMapId = null);
    } on Object catch (e) {
      _snack('Could not delete ${map.name}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final maps = ref.watch(savedMapsProvider);

    final menu = _MapMenu(
      mode: _mode,
      onNew: () => _show(_PanelMode.newMap),
      onEdit: () => setState(() {
        _openMapId = null;
        _mode = _PanelMode.editMap;
      }),
      onImport: _import,
    );
    final status = _DataStatus(maps: maps);
    final Widget panel;
    const contentPadding = EdgeInsets.fromLTRB(36, 32, 36, 32);
    switch (_mode) {
      case _PanelMode.art:
        panel = const HudFrame(padding: EdgeInsets.zero, child: _ArtPanel());
      case _PanelMode.newMap:
        panel = HudFrame(
          padding: contentPadding,
          child: NewMapForm(
            onCreate: _onCreate,
            onCancel: () => _show(_PanelMode.art),
          ),
        );
      case _PanelMode.editMap:
        panel = HudFrame(
          padding: contentPadding,
          child: _SavedMapsPanel(
            maps: maps,
            openMapId: _openMapId,
            onOpen: (m) => setState(() => _openMapId = m.id),
            onBack: () => setState(() => _openMapId = null),
            onEdit: _openEditor,
            onExport: _export,
            onDelete: _delete,
          ),
        );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('MAP BUILDER')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= _wideBreakpoint) {
            const vPad = 48.0;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(40, vPad, 40, vPad),
              child: SizedBox(
                height: math.max(
                  _minPanelHeight,
                  constraints.maxHeight - vPad * 2,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 480,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [menu, const Spacer(), status],
                      ),
                    ),
                    const SizedBox(width: 40),
                    Expanded(child: panel),
                  ],
                ),
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 32, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                menu,
                const SizedBox(height: 32),
                SizedBox(height: 640, child: panel),
                const SizedBox(height: 24),
                status,
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MapMenu extends StatelessWidget {
  const _MapMenu({
    required this.mode,
    required this.onNew,
    required this.onEdit,
    required this.onImport,
  });

  final _PanelMode mode;
  final VoidCallback onNew;
  final VoidCallback onEdit;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const HudTitleBlock(eyebrow: 'Map Builder', title: 'Map Sheets'),
        const SizedBox(height: 28),
        HudMenuButton(
          number: 1,
          label: 'New Map',
          active: mode == _PanelMode.newMap,
          onTap: onNew,
        ),
        const SizedBox(height: 10),
        HudMenuButton(
          number: 2,
          label: 'Edit Map',
          active: mode == _PanelMode.editMap,
          onTap: onEdit,
        ),
        const SizedBox(height: 10),
        HudMenuButton(
          number: 3,
          label: 'Import File',
          active: false,
          onTap: onImport,
        ),
      ],
    );
  }
}

class _DataStatus extends StatelessWidget {
  const _DataStatus({required this.maps});

  final AsyncValue<List<SavedMap>> maps;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 13, color: AppColors.textDim);
    return maps.when(
      loading: () => const Text('Loading saved maps…', style: style),
      error: (error, _) =>
          Text('Could not read saved maps: $error', style: style),
      data: (list) => Text(
        list.length == 1 ? '1 saved map' : '${list.length} saved maps',
        style: style,
      ),
    );
  }
}

class _ArtPanel extends StatelessWidget {
  const _ArtPanel();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: [
        HexMapArt(),
        // Fade the bottom of the map so the caption stays readable.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.6, 1.0],
              colors: [Color(0x00151A1F), AppColors.panel],
            ),
          ),
        ),
        Positioned(
          left: 32,
          right: 32,
          bottom: 28,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('MAP SHEETS', style: HudText.sectionLabel),
              SizedBox(height: 6),
              Text(
                'Choose New Map to enter a sheet by hand or from photos, or '
                'Import File to bring in a btmap file.',
                style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Edit Map: the saved maps, or one of them in full with Edit, Export and
/// Delete.
class _SavedMapsPanel extends StatelessWidget {
  const _SavedMapsPanel({
    required this.maps,
    required this.openMapId,
    required this.onOpen,
    required this.onBack,
    required this.onEdit,
    required this.onExport,
    required this.onDelete,
  });

  final AsyncValue<List<SavedMap>> maps;
  final String? openMapId;
  final ValueChanged<SavedMap> onOpen;
  final VoidCallback onBack;
  final ValueChanged<SavedMap> onEdit;
  final ValueChanged<SavedMap> onExport;
  final ValueChanged<SavedMap> onDelete;

  static final _buttonShape = const RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(2)),
  );
  static const _buttonText = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
  );

  @override
  Widget build(BuildContext context) {
    if (maps.hasError) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('EDIT MAP', style: HudText.panelTitle),
          const SizedBox(height: 8),
          Text(
            'Saved maps could not be read. ${maps.error}',
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      );
    }
    final saved = maps.value;
    if (saved == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final open = saved.where((m) => m.id == openMapId).firstOrNull;
    if (open == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('EDIT MAP', style: HudText.panelTitle),
          const SizedBox(height: 8),
          const Text(
            'Choose a saved map to see it.',
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: SavedMapList(
              maps: saved,
              onSelect: onOpen,
              emptyText: 'No saved maps yet. Choose New Map to make one.',
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            TextButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
              label: const Text('ALL MAPS', style: _buttonText),
            ),
            Wrap(
              spacing: 12,
              children: [
                OutlinedButton(
                  onPressed: () => onDelete(open),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(110, 44),
                    shape: _buttonShape,
                  ),
                  child: const Text('DELETE', style: _buttonText),
                ),
                OutlinedButton(
                  onPressed: () => onExport(open),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(110, 44),
                    shape: _buttonShape,
                  ),
                  child: const Text('EXPORT', style: _buttonText),
                ),
                FilledButton(
                  onPressed: () => onEdit(open),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(140, 44),
                    shape: _buttonShape,
                  ),
                  child: const Text('EDIT MAP', style: _buttonText),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          open.name.isEmpty ? 'UNTITLED MAP' : open.name.toUpperCase(),
          style: HudText.panelTitle,
        ),
        const SizedBox(height: 4),
        Text(
          mapSummary(open),
          style: const TextStyle(fontSize: 15, color: AppColors.textDim),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            color: AppColors.background,
            child: MapThumbnail(sheet: open.sheet),
          ),
        ),
      ],
    );
  }
}
