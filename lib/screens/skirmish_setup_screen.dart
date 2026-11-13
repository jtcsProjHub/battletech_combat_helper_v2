// File: lib/screens/skirmish_setup_screen.dart
// New Skirmish setup: Player 1 lance, Player 2 lance, map, then review and
// confirm. Player 1's column is on the left and Player 2's on the right;
// on a player's step the saved lance list sits in that player's column and
// the center previews the pick. Every step stays open, so players can
// change their minds until they confirm.
//
// Back saves the setup (once anything is picked) and leaves. Confirm
// initializes the game state and replaces this screen with the play screen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:map_extractor_prototype/map_extractor.dart';

import '../app_theme.dart';
import '../lance.dart';
import '../lance_repository.dart';
import '../maps/map_repository.dart';
import '../mech_library.dart';
import '../skirmish/skirmish.dart';
import '../skirmish/skirmish_map.dart';
import '../widgets/hud.dart';
import '../widgets/lance_roster_detail.dart';
import '../widgets/map/new_map_form.dart';
import '../widgets/new_lance_form.dart';
import '../widgets/saved_lance_list.dart';
import '../widgets/skirmish/skirmish_autosave.dart';
import '../widgets/skirmish/skirmish_panels.dart';
import '../widgets/skirmish/skirmish_scaffold.dart';
import 'lance_editor_screen.dart';
import 'map_editor_screen.dart';
import 'skirmish_play_screen.dart';

class SkirmishSetupScreen extends ConsumerStatefulWidget {
  /// Without [skirmish], starts a new one named after the current time.
  const SkirmishSetupScreen({super.key, this.skirmish});

  /// A saved skirmish still in setup, to continue.
  final Skirmish? skirmish;

  @override
  ConsumerState<SkirmishSetupScreen> createState() =>
      _SkirmishSetupScreenState();
}

class _SkirmishSetupScreenState extends ConsumerState<SkirmishSetupScreen>
    with SkirmishAutosave {
  late final Skirmish _s = widget.skirmish ?? Skirmish.create();

  /// A loaded skirmish is always saved again, even with nothing picked.
  late final bool _wasSaved = widget.skirmish != null;

  /// The center column shows the New Lance or New Map form.
  bool _creating = false;

  /// The lance from the builder's back arrow, kept for the next Create.
  Lance? _inProgress;

  bool _leaving = false;

  @override
  Skirmish get skirmish => _s;

  @override
  bool get worthSaving => _wasSaved || _s.hasSelections;

  SetupStep get _step => _s.step;

  void _goTo(SetupStep step) {
    if (!_s.isStepReachable(step)) return;
    setState(() {
      _s.step = step;
      _creating = false;
      _inProgress = null;
    });
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _ask({
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
    if (_leaving) return;
    _leaving = true;
    final error = await saveSkirmish();
    if (!mounted) return;
    if (error != null &&
        !await _ask(
          title: 'Could not save the skirmish',
          body: '$error\n\nLeave anyway? The setup is lost.',
          action: 'LEAVE',
        )) {
      _leaving = false;
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  // --- Lances -------------------------------------------------------------

  void _pickLance(int player, Lance lance) => setState(() {
    _s.player(player).lance = lance;
    _creating = false;
    _inProgress = null;
  });

  /// Opens the full-screen builder for a lance made from the New Lance form.
  /// Save writes the precon and picks it; the back arrow keeps the mechs
  /// for the next Create, as in the Lance Builder.
  Future<void> _onLanceCreated(int player, Lance lance) async {
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
    if (!result.saved) {
      setState(() => _inProgress = result.lance);
      return;
    }
    try {
      await ref.read(savedLancesProvider.notifier).save(result.lance);
    } on Object catch (e) {
      _snack('Could not save ${result.lance.name}: $e');
      setState(() => _inProgress = result.lance);
      return;
    }
    if (mounted) _pickLance(player, result.lance);
  }

  // --- Map ----------------------------------------------------------------

  void _pickMap(SavedMap map) => setState(() {
    _s.map = SkirmishMap(map);
    _creating = false;
  });

  /// Opens the map editor for a new sheet. If it was saved there, it is
  /// picked when the editor closes.
  Future<void> _onMapCreated(NewMapRequest request) async {
    final map = SavedMap.create(
      MapSheet(name: request.name, grid: request.grid, hexes: const {}),
    );
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => MapEditorScreen(map: map)));
    if (!mounted) return;
    final List<SavedMap> maps;
    try {
      maps = await ref.read(savedMapsProvider.future);
    } on Object {
      return;
    }
    final saved = maps.where((m) => m.id == map.id).firstOrNull;
    if (saved != null && mounted) _pickMap(saved);
  }

  // --- Confirm ------------------------------------------------------------

  Future<void> _confirm() async {
    final library = ref.read(mechLibraryProvider).value;
    if (library == null || !_s.canConfirm) return;
    setState(() => _s.confirm(library));
    final error = await saveSkirmish();
    if (error != null) _snack('Could not save the skirmish: $error');
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => SkirmishPlayScreen(skirmish: _s)),
    );
  }

  // --- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(mechLibraryProvider).value;
    final lances = ref.watch(savedLancesProvider);
    final maps = ref.watch(savedMapsProvider);

    Widget playerPanel(int i) => PlayerLancePanel(
      label: 'Player ${i + 1}',
      lance: _s.player(i).lance,
      library: library,
      emptyText: i == 0
          ? 'Player 1 has not chosen a lance.'
          : 'Player 2 chooses a lance after Player 1.',
    );

    final List<SkirmishColumn> columns = switch (_step) {
      SetupStep.player1 => [
        (label: 'PLAYER 1', child: _lancePicker(0, lances, library)),
        (label: 'PREVIEW', child: _lancePreview(0, library)),
        (label: 'PLAYER 2', child: playerPanel(1)),
      ],
      SetupStep.player2 => [
        (label: 'PLAYER 1', child: playerPanel(0)),
        (label: 'PREVIEW', child: _lancePreview(1, library)),
        (label: 'PLAYER 2', child: _lancePicker(1, lances, library)),
      ],
      SetupStep.map => [
        (label: 'PLAYER 1', child: playerPanel(0)),
        (label: 'MAP', child: _mapPicker(maps)),
        (label: 'PLAYER 2', child: playerPanel(1)),
      ],
      SetupStep.overview => [
        (label: 'PLAYER 1', child: playerPanel(0)),
        (label: 'MAP', child: _overviewCenter()),
        (label: 'PLAYER 2', child: playerPanel(1)),
      ],
    };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: SkirmishScaffold(
        eyebrow: 'New Skirmish · ${_step.title}',
        name: _s.name,
        onRename: (name) => setState(() => _s.name = name),
        actions: [_StepChips(skirmish: _s, onSelect: _goTo)],
        columns: columns,
        bottomBar: _bottomBar(library),
      ),
    );
  }

  Widget _bottomBar(MechLibrary? library) {
    final next = _step.index + 1 < SetupStep.values.length
        ? SetupStep.values[_step.index + 1]
        : null;
    final status = switch (_step) {
      SetupStep.player1 when _s.player1.lance == null =>
        'Choose a lance for Player 1.',
      SetupStep.player2 when _s.player2.lance == null =>
        'Choose a lance for Player 2.',
      SetupStep.map when _s.map == null => 'Choose a map.',
      SetupStep.overview =>
        'Check both lances and the map, then confirm to start.',
      _ => 'Continue when ready. Every step stays open until you confirm.',
    };
    final back = _step.index > 0 ? SetupStep.values[_step.index - 1] : null;
    return SkirmishBottomBar(
      status: status,
      children: [
        if (back != null) SkirmishButtons.outlined('BACK', () => _goTo(back)),
        if (next != null)
          SkirmishButtons.filled(
            'NEXT: ${next.shortLabel.toUpperCase()}',
            _s.isStepComplete(_step) ? () => _goTo(next) : null,
          )
        else
          SkirmishButtons.filled(
            'CONFIRM & START',
            _s.canConfirm && library != null ? _confirm : null,
          ),
      ],
    );
  }

  Widget _lancePicker(
    int player,
    AsyncValue<List<Lance>> lances,
    MechLibrary? library,
  ) {
    final saved = lances.value;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SkirmishColumnHeader(
            label: 'Player ${player + 1}',
            help: 'Choose a saved lance, or build a new one.',
          ),
          const SizedBox(height: 16),
          Expanded(
            child: lances.hasError
                ? Text(
                    'Saved lances could not be read. ${lances.error}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  )
                : saved == null || library == null
                ? const Center(child: CircularProgressIndicator())
                : SavedLanceList(
                    lances: saved,
                    library: library,
                    selectedId: _creating ? null : _s.player(player).lance?.id,
                    onSelect: (l) => _pickLance(player, l),
                    emptyText: 'No saved lances yet. Build one with New Lance.',
                  ),
          ),
          const SizedBox(height: 12),
          SkirmishNewTile(
            label: 'NEW LANCE',
            active: _creating,
            onTap: () => setState(() => _creating = true),
          ),
        ],
      ),
    );
  }

  Widget _lancePreview(int player, MechLibrary? library) {
    const pad = EdgeInsets.all(24);
    if (_creating) {
      if (library == null) {
        return const Center(child: CircularProgressIndicator());
      }
      return Padding(
        padding: pad,
        child: NewLanceForm(
          library: library,
          inProgress: _inProgress,
          onCreate: (l) => _onLanceCreated(player, l),
          onCancel: () => setState(() {
            _creating = false;
            _inProgress = null;
          }),
        ),
      );
    }
    final lance = _s.player(player).lance;
    if (lance == null || library == null) {
      return const Padding(
        padding: pad,
        child: _Prompt(
          title: 'Preview',
          body: 'Pick a lance from the list to see its roster here.',
        ),
      );
    }
    return ListView(
      padding: pad,
      children: [LanceRosterDetail(lance: lance, library: library)],
    );
  }

  Widget _mapPicker(AsyncValue<List<SavedMap>> maps) {
    final saved = maps.value;
    final Widget top;
    if (_creating) {
      top = NewMapForm(
        onCreate: _onMapCreated,
        onCancel: () => setState(() => _creating = false),
      );
    } else if (_s.map case final map?) {
      top = MapPreview(map: map.mergedSaved);
    } else {
      top = const _Prompt(
        title: 'Map',
        body: 'Pick a saved map from the strip below, or make a new one.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Padding(padding: const EdgeInsets.all(24), child: top),
        ),
        const Divider(height: 1),
        if (maps.hasError)
          SizedBox(
            height: MapGallery.height,
            child: Center(
              child: Text(
                'Saved maps could not be read. ${maps.error}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          )
        else if (saved == null)
          const SizedBox(
            height: MapGallery.height,
            child: Center(child: CircularProgressIndicator()),
          )
        else
          MapGallery(
            maps: saved,
            selectedId: _s.map?.id,
            onSelect: _pickMap,
            creating: _creating,
            onNew: () => setState(() => _creating = true),
          ),
      ],
    );
  }

  /// Placeholder for the balancing tools (variant swaps, pilot tweaks, map
  /// overlays); for now the map and a reminder of the matchup.
  Widget _overviewCenter() {
    final map = _s.map;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${_s.player1.lance?.name ?? '—'}  vs  '
                    '${_s.player2.lance?.name ?? '—'}'
                .toUpperCase(),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: map == null
                ? const _Prompt(title: 'Map', body: 'No map chosen yet.')
                : MapPreview(map: map.mergedSaved),
          ),
        ],
      ),
    );
  }
}

/// The four steps as chips in the top bar. Done steps show a check; steps
/// not reachable yet are disabled.
class _StepChips extends StatelessWidget {
  const _StepChips({required this.skirmish, required this.onSelect});

  final Skirmish skirmish;
  final ValueChanged<SetupStep> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final s in SetupStep.values)
          _StepChip(
            number: s.index + 1,
            label: s.shortLabel,
            current: s == skirmish.step,
            done: s != SetupStep.overview && skirmish.isStepComplete(s),
            onTap: skirmish.isStepReachable(s) ? () => onSelect(s) : null,
          ),
      ],
    );
  }
}

class _StepChip extends StatelessWidget {
  const _StepChip({
    required this.number,
    required this.label,
    required this.current,
    required this.done,
    required this.onTap,
  });

  final int number;
  final String label;
  final bool current;
  final bool done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final fg = current
        ? AppColors.background
        : enabled
        ? AppColors.text
        : AppColors.iconDim;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Semantics(
        button: true,
        selected: current,
        enabled: enabled,
        label: 'Step $number, $label',
        child: Material(
          color: current ? AppColors.accent : AppColors.panelRaised,
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(
                  color: current ? AppColors.accent : AppColors.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (done && !current)
                    const Icon(Icons.check, size: 16, color: AppColors.accent)
                  else
                    Text(
                      '$number',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: fg,
                      ),
                    ),
                  const SizedBox(width: 8),
                  ExcludeSemantics(
                    child: Text(
                      label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: fg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Prompt extends StatelessWidget {
  const _Prompt({required this.title, required this.body});

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
