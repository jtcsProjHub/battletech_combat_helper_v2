import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_theme.dart';
import '../lance.dart';
import '../lance_repository.dart';
import '../mech_library.dart';
import '../widgets/hex_map_art.dart';
import '../widgets/hud.dart';
import '../widgets/lance_roster_detail.dart';
import '../widgets/new_lance_form.dart';
import '../widgets/saved_lance_list.dart';
import 'lance_editor_screen.dart';

/// What the side panel shows.
enum _PanelMode { art, newLance, editLance, created }

/// Lance Precons hub. Same layout as the main menu: the options on the left,
/// a panel on the right. The panel shows hex map art until an option opens
/// its widget there.
class LanceBuilderScreen extends ConsumerStatefulWidget {
  const LanceBuilderScreen({super.key});

  @override
  ConsumerState<LanceBuilderScreen> createState() => _LanceBuilderScreenState();
}

class _LanceBuilderScreenState extends ConsumerState<LanceBuilderScreen> {
  _PanelMode _mode = _PanelMode.art;
  Lance? _lance;

  /// Set by the builder's back arrow; cleared by Save or Cancel.
  Lance? _inProgress;

  /// The saved lance shown in full under Edit Lance; null shows the list.
  String? _openLanceId;

  static const double _wideBreakpoint = 960;
  static const double _minPanelHeight = 600;

  void _show(_PanelMode mode) => setState(() => _mode = mode);

  /// Opens the full-screen builder for the new lance. The New Lance form
  /// stays mounted underneath, so the back arrow lands on it with its
  /// values, and the mechs picked so far carry over to the next Create.
  Future<void> _onCreated(Lance lance) async {
    final library = ref.read(mechLibraryProvider).value;
    if (library == null) return;
    final previous = _inProgress;
    if (previous != null) {
      lance = previous.copyWith(
        name: lance.name,
        parameters: lance.parameters,
        slots: previous.slots.take(lance.parameters.maxMechs).toList(),
      );
    }
    final result = await Navigator.of(context).push<LanceEditorResult>(
      MaterialPageRoute(
        builder: (_) => LanceEditorScreen(lance: lance, library: library),
      ),
    );
    if (!mounted || result == null) return;
    // A failed save keeps the mechs, like the back arrow does.
    final saved = result.saved && await _save(result.lance);
    if (!mounted) return;
    setState(() {
      if (saved) {
        _inProgress = null;
        _lance = result.lance;
        _mode = _PanelMode.created;
      } else {
        _inProgress = result.lance;
      }
    });
  }

  /// Writes the lance to disk. Shows the error and returns false on failure.
  Future<bool> _save(Lance lance) async {
    try {
      await ref.read(savedLancesProvider.notifier).save(lance);
      return true;
    } on Object catch (e) {
      _showError('Could not save ${lance.name}: $e');
      return false;
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Opens a saved lance in the full-screen builder. Save writes it back
  /// under the same id; the back arrow drops the changes.
  Future<void> _editSaved(Lance lance) async {
    final library = ref.read(mechLibraryProvider).value;
    if (library == null) return;
    final result = await Navigator.of(context).push<LanceEditorResult>(
      MaterialPageRoute(
        builder: (_) => LanceEditorScreen(lance: lance, library: library),
      ),
    );
    if (!mounted || result == null || !result.saved) return;
    await _save(result.lance);
  }

  Future<void> _deleteSaved(Lance lance) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${lance.name}?'),
        content: const Text(
          'The saved lance is removed. This cannot be undone.',
        ),
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
      await ref.read(savedLancesProvider.notifier).delete(lance.id);
      if (mounted) setState(() => _openLanceId = null);
    } on Object catch (e) {
      _showError('Could not delete ${lance.name}: $e');
    }
  }

  void _onCancel() => setState(() {
    _inProgress = null;
    _mode = _PanelMode.art;
  });

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(mechLibraryProvider);

    final menu = _LanceMenu(
      mode: _mode,
      onNew: () => _show(_PanelMode.newLance),
      onEdit: () => setState(() {
        _openLanceId = null;
        _mode = _PanelMode.editLance;
      }),
    );
    final status = _DataStatus(library: library);
    final panel = _SidePanel(
      mode: _mode,
      library: library,
      lance: _lance,
      inProgress: _inProgress,
      onCreate: _onCreated,
      onCancel: _onCancel,
      savedLances: _SavedLancesPanel(
        library: library,
        lances: ref.watch(savedLancesProvider),
        openLanceId: _openLanceId,
        onOpen: (l) => setState(() => _openLanceId = l.id),
        onBack: () => setState(() => _openLanceId = null),
        onEdit: _editSaved,
        onDelete: _deleteSaved,
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('LANCE BUILDER')),
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

class _LanceMenu extends StatelessWidget {
  const _LanceMenu({
    required this.mode,
    required this.onNew,
    required this.onEdit,
  });

  final _PanelMode mode;
  final VoidCallback onNew;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final newActive = mode == _PanelMode.newLance || mode == _PanelMode.created;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const HudTitleBlock(eyebrow: 'Lance Builder', title: 'Lance Precons'),
        const SizedBox(height: 28),
        HudMenuButton(
          number: 1,
          label: 'New Lance',
          active: newActive,
          onTap: onNew,
        ),
        const SizedBox(height: 10),
        HudMenuButton(
          number: 2,
          label: 'Edit Lance',
          active: mode == _PanelMode.editLance,
          onTap: onEdit,
        ),
      ],
    );
  }
}

class _DataStatus extends StatelessWidget {
  const _DataStatus({required this.library});

  final AsyncValue<MechLibrary> library;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 13, color: AppColors.textDim);
    return library.when(
      loading: () => const Text('Loading mech data…', style: style),
      error: (error, _) =>
          Text('Could not load mech data: $error', style: style),
      data: (lib) =>
          Text('Mech data: ${lib.mechs.length} mechs loaded', style: style),
    );
  }
}

class _SidePanel extends StatelessWidget {
  const _SidePanel({
    required this.mode,
    required this.library,
    required this.lance,
    required this.inProgress,
    required this.onCreate,
    required this.onCancel,
    required this.savedLances,
  });

  final _PanelMode mode;
  final AsyncValue<MechLibrary> library;
  final Lance? lance;
  final Lance? inProgress;
  final ValueChanged<Lance> onCreate;
  final VoidCallback onCancel;

  /// The Edit Lance panel content.
  final Widget savedLances;

  @override
  Widget build(BuildContext context) {
    const contentPadding = EdgeInsets.fromLTRB(36, 32, 36, 32);
    final created = lance;

    switch (mode) {
      case _PanelMode.art:
        return const HudFrame(padding: EdgeInsets.zero, child: _ArtPanel());
      case _PanelMode.newLance:
        return HudFrame(
          padding: contentPadding,
          child: library.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _Message(
              title: 'New Lance',
              body:
                  'Mech data did not load, so the era and faction lists '
                  'are empty. $error',
            ),
            data: (lib) => NewLanceForm(
              library: lib,
              inProgress: inProgress,
              onCreate: onCreate,
              onCancel: onCancel,
            ),
          ),
        );
      case _PanelMode.editLance:
        return HudFrame(padding: contentPadding, child: savedLances);
      case _PanelMode.created:
        return HudFrame(
          padding: contentPadding,
          child: created == null
              ? const SizedBox.shrink()
              : _CreatedSummary(lance: created),
        );
    }
  }
}

class _ArtPanel extends StatelessWidget {
  const _ArtPanel();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const HexMapArt(),
        // Fade the bottom of the map so the caption stays readable.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.6, 1.0],
              colors: [Color(0x00151A1F), AppColors.panel],
            ),
          ),
        ),
        const Positioned(
          left: 32,
          right: 32,
          bottom: 28,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('TACTICAL MAP', style: HudText.sectionLabel),
              SizedBox(height: 6),
              Text(
                'Choose New Lance to start a precon.',
                style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: HudText.panelTitle),
        const SizedBox(height: 8),
        Text(
          body,
          style: const TextStyle(
            fontSize: 16,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Shown after Save in the builder.
class _CreatedSummary extends StatelessWidget {
  const _CreatedSummary({required this.lance});

  final Lance lance;

  @override
  Widget build(BuildContext context) {
    final p = lance.parameters;
    final rows = <(String, String)>[
      ('Mechs', '${lance.slots.length} of ${p.maxMechs}'),
      ('Target Battle Value', '${p.targetBattleValue}'),
      ('Era', p.era?.label ?? 'Any'),
      ('Faction', p.faction ?? 'Any'),
      (
        'Tech base',
        p.techBase == null
            ? 'Any'
            : techBaseLabels[p.techBase] ?? p.techBase!.name,
      ),
    ];
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('LANCE SAVED', style: HudText.sectionLabel),
          const SizedBox(height: 8),
          Text(lance.name.toUpperCase(), style: HudText.panelTitle),
          const SizedBox(height: 24),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 200,
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textDim,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          const Text(
            'Saved. Open it again from Edit Lance.',
            style: TextStyle(fontSize: 14, color: AppColors.textDim),
          ),
        ],
      ),
    );
  }
}

/// Edit Lance: the saved lances, or one of them in full with Edit and Delete.
class _SavedLancesPanel extends StatelessWidget {
  const _SavedLancesPanel({
    required this.library,
    required this.lances,
    required this.openLanceId,
    required this.onOpen,
    required this.onBack,
    required this.onEdit,
    required this.onDelete,
  });

  final AsyncValue<MechLibrary> library;
  final AsyncValue<List<Lance>> lances;
  final String? openLanceId;
  final ValueChanged<Lance> onOpen;
  final VoidCallback onBack;
  final ValueChanged<Lance> onEdit;
  final ValueChanged<Lance> onDelete;

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
    final lib = library.value;
    final saved = lances.value;
    if (library.hasError) {
      return _Message(
        title: 'Edit Lance',
        body: 'Mech data did not load. ${library.error}',
      );
    }
    if (lances.hasError) {
      return _Message(
        title: 'Edit Lance',
        body: 'Saved lances could not be read. ${lances.error}',
      );
    }
    if (lib == null || saved == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final open = saved.where((l) => l.id == openLanceId).firstOrNull;
    if (open == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('EDIT LANCE', style: HudText.panelTitle),
          const SizedBox(height: 8),
          const Text(
            'Choose a saved lance to see its roster.',
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: SavedLanceList(
              lances: saved,
              library: lib,
              onSelect: onOpen,
              emptyText: 'No saved lances yet. Choose New Lance to build one.',
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
              label: const Text('ALL LANCES', style: _buttonText),
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
                FilledButton(
                  onPressed: () => onEdit(open),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(140, 44),
                    shape: _buttonShape,
                  ),
                  child: const Text('EDIT LANCE', style: _buttonText),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            child: LanceRosterDetail(lance: open, library: lib),
          ),
        ),
      ],
    );
  }
}
