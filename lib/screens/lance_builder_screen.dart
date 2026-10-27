import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_theme.dart';
import '../lance.dart';
import '../mech_library.dart';
import '../widgets/hex_map_art.dart';
import '../widgets/hud.dart';
import '../widgets/new_lance_form.dart';
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
    setState(() {
      if (result.saved) {
        _inProgress = null;
        _lance = result.lance;
        _mode = _PanelMode.created;
      } else {
        _inProgress = result.lance;
      }
    });
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
      onEdit: () => _show(_PanelMode.editLance),
    );
    final status = _DataStatus(library: library);
    final panel = _SidePanel(
      mode: _mode,
      library: library,
      lance: _lance,
      inProgress: _inProgress,
      onCreate: _onCreated,
      onCancel: _onCancel,
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
  });

  final _PanelMode mode;
  final AsyncValue<MechLibrary> library;
  final Lance? lance;
  final Lance? inProgress;
  final ValueChanged<Lance> onCreate;
  final VoidCallback onCancel;

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
        return const HudFrame(
          padding: contentPadding,
          child: _Message(
            title: 'Edit Lance',
            body: 'The list of saved lances goes here. Not built yet.',
          ),
        );
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

/// Shown after Save in the builder. The lance is kept in memory only.
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
            'Kept in memory for this session. Saving to disk is not built yet.',
            style: TextStyle(fontSize: 14, color: AppColors.textDim),
          ),
        ],
      ),
    );
  }
}
