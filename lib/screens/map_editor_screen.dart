// File: lib/screens/map_editor_screen.dart
// Full-screen map editor: sources and map settings | map or photo view |
// hex inspector, with the map stats in the top bar. Save writes the map and
// keeps the editor open, because reviewing a sheet is a long job. Back asks
// first when there are unsaved changes.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:map_extractor_prototype/map_extractor.dart';

import '../app_theme.dart';
import '../maps/hex_layout.dart';
import '../maps/hex_selection.dart';
import '../maps/map_editor_controller.dart';
import '../maps/map_repository.dart';
import '../maps/map_sheet_draft.dart';
import '../widgets/hud.dart';
import '../widgets/map/hex_inspector.dart';
import '../widgets/map/hex_map_view.dart';
import '../widgets/map/source_overlay_view.dart';

class MapEditorScreen extends ConsumerStatefulWidget {
  const MapEditorScreen({super.key, required this.map});

  /// The map to edit. A new map has an id but is not in the repository yet.
  final SavedMap map;

  @override
  ConsumerState<MapEditorScreen> createState() => _MapEditorScreenState();
}

class _MapEditorScreenState extends ConsumerState<MapEditorScreen> {
  late final MapSheetDraft _draft = MapSheetDraft.fromSaved(widget.map);
  late final MapEditorController _c = MapEditorController(_draft);
  bool _saving = false;

  /// Below this width the three panels become tabs.
  static const double _wideBreakpoint = 1200;

  @override
  void dispose() {
    _c.dispose();
    _draft.dispose();
    super.dispose();
  }

  /// True while a text field has focus, so N and Enter go to the field.
  bool get _typing =>
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<EditableText>() !=
      null;

  KeyEventResult _onKey(KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final kb = HardwareKeyboard.instance;
    final ctrl = kb.isControlPressed || kb.isMetaPressed;
    final key = event.logicalKey;
    // Save works from text fields too; the name field updates as you type.
    if (ctrl && key == LogicalKeyboardKey.keyS) {
      if (event is KeyDownEvent) _save();
      return KeyEventResult.handled;
    }
    if (_typing) return KeyEventResult.ignored;
    if (ctrl && key == LogicalKeyboardKey.keyA) {
      _c.selection.selectAll(_draft.grid);
      return KeyEventResult.handled;
    }
    if (ctrl || kb.isAltPressed || kb.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.escape) {
      _c.selection.clear();
    } else if (key == LogicalKeyboardKey.keyN) {
      _c.selectNextToReview();
    } else if (key == LogicalKeyboardKey.enter) {
      _c.acceptSelection();
    } else if (key == LogicalKeyboardKey.keyH) {
      _c.setTool(CanvasTool.pan);
    } else if (key == LogicalKeyboardKey.keyB) {
      _c.setTool(CanvasTool.box);
    } else if (key == LogicalKeyboardKey.keyP) {
      _c.setTool(CanvasTool.brush);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_draft.name.trim().isEmpty) {
      _snack('Enter a name for the map before you save it.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(savedMapsProvider.notifier).save(_draft.toSaved());
      _draft.markSaved();
      _snack('Saved ${_draft.name.trim()}.');
    } on Object catch (e) {
      _snack('Could not save ${_draft.name.trim()}: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _export() async {
    try {
      final name = await _c.exportJson();
      if (name != null) _snack('Exported $name.');
    } on Object catch (e) {
      _snack('Could not export the map: $e');
    }
  }

  /// Extraction replaces the terrain with the merged photo result, so ask
  /// first when the map already has terrain.
  Future<void> _extract() async {
    if (_draft.terrainCount > 0) {
      final ok = await _confirm(
        title: 'Replace the current terrain?',
        body:
            'Extract replaces the terrain and review flags with the merged '
            'result from all photos. Changes made in the inspector are lost.',
        action: 'EXTRACT',
      );
      if (!ok) return;
    }
    await _c.extractAll();
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String action,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _onBack() async {
    final leave = await _confirm(
      title: 'Discard unsaved changes?',
      body: 'The changes to this map since the last save are lost.',
      action: 'DISCARD',
    );
    if (leave && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_c, _draft, _c.selection]),
      builder: (context, _) {
        final left = _SourcesPanel(c: _c, onExtract: _extract);
        final center = _ViewPanel(c: _c);
        final inspector = HexInspector(
          draft: _draft,
          selection: _c.selection,
          sources: _c.sources,
          onNextToReview: _c.selectNextToReview,
          onAccept: _c.acceptSelection,
        );

        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= _wideBreakpoint;
            final scaffold = Scaffold(
              appBar: _TopBar(
                draft: _draft,
                saving: _saving,
                busy: _c.busy,
                onSave: _save,
                onExport: _export,
                tabs: wide
                    ? null
                    : const TabBar(
                        tabs: [
                          Tab(text: 'SOURCES'),
                          Tab(text: 'MAP'),
                          Tab(text: 'HEX'),
                        ],
                      ),
              ),
              body: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(width: 320, child: left),
                        const VerticalDivider(width: 1),
                        Expanded(child: center),
                        const VerticalDivider(width: 1),
                        SizedBox(
                          width: 360,
                          child: ColoredBox(
                            color: const Color(0xFF12161A),
                            child: inspector,
                          ),
                        ),
                      ],
                    )
                  : TabBarView(
                      physics: const NeverScrollableScrollPhysics(),
                      children: [left, center, inspector],
                    ),
            );
            // A Focus handler instead of CallbackShortcuts: shortcuts report
            // the key as handled, and on desktop a handled key never reaches
            // the focused text field. Returning `ignored` while typing lets
            // N and Enter through.
            return PopScope(
              canPop: !_draft.hasUnsavedChanges,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop) _onBack();
              },
              child: Focus(
                autofocus: true,
                onKeyEvent: (_, event) => _onKey(event),
                child: wide
                    ? scaffold
                    : DefaultTabController(length: 3, child: scaffold),
              ),
            );
          },
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget implements PreferredSizeWidget {
  const _TopBar({
    required this.draft,
    required this.saving,
    required this.busy,
    required this.onSave,
    required this.onExport,
    this.tabs,
  });

  final MapSheetDraft draft;
  final bool saving;
  final bool busy;
  final VoidCallback onSave;
  final VoidCallback onExport;
  final PreferredSizeWidget? tabs;

  static const double _barHeight = 76;

  @override
  Size get preferredSize =>
      Size.fromHeight(_barHeight + (tabs?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final name = draft.name.trim();
    final toReview = draft.toReviewCount;
    const statStyle = TextStyle(fontSize: 20, fontWeight: FontWeight.w700);

    return AppBar(
      toolbarHeight: _barHeight,
      titleSpacing: 0,
      bottom: tabs,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            draft.hasUnsavedChanges ? 'MAP BUILDER · UNSAVED' : 'MAP BUILDER',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
              color: AppColors.accent,
            ),
          ),
          Text(
            name.isEmpty ? 'UNTITLED MAP' : name.toUpperCase(),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      actions: [
        _Stat(
          label: 'SIZE',
          value: Text(
            '${draft.grid.columns} × ${draft.grid.rows}',
            style: statStyle,
          ),
        ),
        _Stat(
          label: 'TERRAIN HEXES',
          value: Text('${draft.terrainCount}', style: statStyle),
        ),
        _Stat(
          label: 'TO REVIEW',
          value: Text(
            '$toReview',
            style: statStyle.copyWith(
              color: toReview > 0 ? TerrainStyle.review : null,
            ),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: busy ? null : onExport,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(110, 44),
            shape: mapButtonShape,
            foregroundColor: AppColors.textSecondary,
            side: const BorderSide(color: AppColors.borderStrong),
          ),
          child: const Text('EXPORT', style: mapButtonText),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Tooltip(
            message: 'Save the map (Ctrl+S)',
            child: FilledButton(
              onPressed: saving || busy ? null : onSave,
              style: FilledButton.styleFrom(
                minimumSize: const Size(140, 44),
                shape: mapButtonShape,
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                ),
              ),
              child: const Text('SAVE MAP'),
            ),
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.4,
              color: AppColors.textDim,
            ),
          ),
          value,
        ],
      ),
    );
  }
}

/// Left column: photo sources and extraction, then the map name and size.
class _SourcesPanel extends StatelessWidget {
  const _SourcesPanel({required this.c, required this.onExtract});

  final MapEditorController c;
  final VoidCallback onExtract;

  static const _body = TextStyle(
    fontSize: 13,
    height: 1.4,
    color: AppColors.textDim,
  );

  @override
  Widget build(BuildContext context) {
    final draft = c.draft;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('PHOTO SOURCES', style: HudText.sectionLabel),
        const SizedBox(height: 6),
        const Text(
          'Optional. One full photo, four quadrant photos, or a scanned PDF '
          'of the same sheet. Quadrant photos give the best result.',
          style: _body,
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < c.sources.length; i++) _SourceTile(c: c, index: i),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: c.busy ? null : c.pickSources,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  shape: mapButtonShape,
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.borderStrong),
                ),
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: const Text('ADD', style: mapButtonText),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: c.busy || !c.hasPendingSources ? null : onExtract,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  shape: mapButtonShape,
                ),
                icon: const Icon(Icons.auto_fix_high, size: 18),
                label: const Text('EXTRACT', style: mapButtonText),
              ),
            ),
          ],
        ),
        if (c.status case final status?) ...[
          const SizedBox(height: 10),
          Text(
            status,
            style: const TextStyle(fontSize: 13, color: AppColors.accent),
          ),
        ],
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Divider(height: 1),
        ),
        const Text('MAP SHEET', style: HudText.sectionLabel),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: draft.name,
          decoration: hudInputDecoration(
            'Map name',
            hint: 'Foothills #1',
            dense: true,
          ),
          onChanged: (v) => draft.name = v,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _GridSizeField(
                // Rebuild when extraction changes the size.
                key: ValueKey('cols-${draft.grid.columns}'),
                label: 'Columns',
                value: draft.grid.columns,
                onChanged: (v) =>
                    c.setGrid(GridSpec(columns: v, rows: draft.grid.rows)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _GridSizeField(
                key: ValueKey('rows-${draft.grid.rows}'),
                label: 'Rows',
                value: draft.grid.rows,
                onChanged: (v) =>
                    c.setGrid(GridSpec(columns: draft.grid.columns, rows: v)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Standard sheets are 15 × 17. Extract sets the size from the '
          'highest hex numbers it reads.',
          style: _body,
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Divider(height: 1),
        ),
        const Text('KEYS', style: HudText.sectionLabel),
        const SizedBox(height: 8),
        const Text(
          'N  next hex to review\n'
          'Enter  accept the selection and go to the next\n'
          'Esc  clear the selection\n'
          'Ctrl+A  select all\n'
          'H / B / P  pan, box and brush tools\n'
          'Ctrl+S  save',
          style: TextStyle(fontSize: 13, height: 1.6, color: AppColors.textDim),
        ),
      ],
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({required this.c, required this.index});

  final MapEditorController c;
  final int index;

  @override
  Widget build(BuildContext context) {
    final s = c.sources[index];
    final failed = s.status == SourceStatus.failed;
    final subtitle = switch (s.status) {
      SourceStatus.waiting => 'Waiting',
      SourceStatus.running => s.stage,
      SourceStatus.done => s.stage,
      SourceStatus.failed => s.error ?? 'Failed',
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 10),
      decoration: BoxDecoration(
        color: AppColors.panelRaised,
        border: Border(
          left: BorderSide(
            color: failed
                ? AppColors.danger
                : s.status == SourceStatus.done
                ? AppColors.accent
                : AppColors.border,
            width: 3,
          ),
          top: const BorderSide(color: AppColors.cellBorder),
          right: const BorderSide(color: AppColors.cellBorder),
          bottom: const BorderSide(color: AppColors.cellBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'PHOTO ${index + 1}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: AppColors.textDim,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: AppColors.text),
                ),
              ),
              IconButton(
                tooltip: 'Remove photo',
                visualDensity: VisualDensity.compact,
                onPressed: c.busy ? null : () => c.removeSource(index),
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: failed ? AppColors.danger : AppColors.textDim,
            ),
          ),
          if (s.status == SourceStatus.running)
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 8),
              child: LinearProgressIndicator(
                value: s.fraction,
                minHeight: 4,
                backgroundColor: AppColors.cellBorder,
              ),
            ),
        ],
      ),
    );
  }
}

/// A grid size field. The value applies on Enter or when the field loses
/// focus, so typing "15" does not pass through a 1-column grid.
class _GridSizeField extends StatefulWidget {
  const _GridSizeField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  State<_GridSizeField> createState() => _GridSizeFieldState();
}

class _GridSizeFieldState extends State<_GridSizeField> {
  late final _text = TextEditingController(text: '${widget.value}');
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _apply();
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _apply() {
    final n = int.tryParse(_text.text);
    if (n != null && n >= 1 && n <= 99) {
      if (n != widget.value) widget.onChanged(n);
    } else {
      _text.text = '${widget.value}';
    }
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _text,
    focusNode: _focus,
    decoration: hudInputDecoration(widget.label, dense: true),
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    onSubmitted: (_) => _apply(),
  );
}

/// Centre column: the view switcher and the map or one photo.
class _ViewPanel extends StatelessWidget {
  const _ViewPanel({required this.c});

  final MapEditorController c;

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (c.view < 0 || c.view >= c.sources.length) {
      body = HexMapView(
        key: const ValueKey('map'),
        draft: c.draft,
        selection: c.selection,
        tool: c.tool,
        onToolChanged: c.setTool,
      );
    } else {
      body = SourceOverlayView(
        key: ValueKey(c.sources[c.view].path),
        source: c.sources[c.view],
        draft: c.draft,
        selection: c.selection,
        showOcrBoxes: c.showOcrBoxes,
        tool: c.tool,
        onToolChanged: c.setTool,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _ViewChip(
                label: 'MAP',
                selected: c.view < 0,
                onTap: () => c.setView(-1),
              ),
              for (var i = 0; i < c.sources.length; i++)
                _ViewChip(
                  label: 'PHOTO ${i + 1}',
                  selected: c.view == i,
                  onTap: c.sources[i].result == null
                      ? null
                      : () => c.setView(i),
                ),
              if (c.view >= 0)
                FilterChip(
                  label: const Text('OCR BOXES'),
                  selected: c.showOcrBoxes,
                  onSelected: (_) => c.toggleOcrBoxes(),
                  shape: mapButtonShape,
                  side: const BorderSide(color: AppColors.chipBorder),
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ColoredBox(
            color: AppColors.background,
            child: ClipRect(child: body),
          ),
        ),
      ],
    );
  }
}

class _ViewChip extends StatelessWidget {
  const _ViewChip({required this.label, required this.selected, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: onTap == null ? null : (_) => onTap!(),
      shape: mapButtonShape,
      side: BorderSide(
        color: selected ? AppColors.accent : AppColors.chipBorder,
      ),
      selectedColor: AppColors.accent.withAlpha(48),
      backgroundColor: AppColors.panelRaised,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: selected ? AppColors.accent : AppColors.textSecondary,
      ),
    );
  }
}
