// File: lib/screens/skirmish_play_screen.dart
// A confirmed skirmish. Stub until the game engine exists: shows each
// player's units with their starting state and the map. Back asks first,
// saves, and returns to the main menu.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_theme.dart';
import '../mech_library.dart';
import '../skirmish/skirmish.dart';
import '../widgets/skirmish/skirmish_autosave.dart';
import '../widgets/skirmish/skirmish_panels.dart';
import '../widgets/skirmish/skirmish_scaffold.dart';

class SkirmishPlayScreen extends ConsumerStatefulWidget {
  const SkirmishPlayScreen({super.key, required this.skirmish});

  final Skirmish skirmish;

  @override
  ConsumerState<SkirmishPlayScreen> createState() => _SkirmishPlayScreenState();
}

class _SkirmishPlayScreenState extends ConsumerState<SkirmishPlayScreen>
    with SkirmishAutosave {
  bool _leaving = false;

  @override
  Skirmish get skirmish => widget.skirmish;

  Future<void> _onBack() async {
    if (_leaving) return;
    _leaving = true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave the skirmish?'),
        content: const Text(
          'The game is saved. Resume it later from Load Skirmish.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('STAY'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('LEAVE'),
          ),
        ],
      ),
    );
    if (leave != true || !mounted) {
      _leaving = false;
      return;
    }
    final error = await saveSkirmish();
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save the skirmish: $error')),
      );
      _leaving = false;
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.skirmish;
    final library = ref.watch(mechLibraryProvider).value;
    final map = s.map;

    Widget units(int i) {
      final p = s.player(i);
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SkirmishColumnHeader(label: 'Player ${i + 1}', help: p.lance?.name),
          const SizedBox(height: 16),
          if (p.units.isEmpty)
            const Text(
              'No units.',
              style: TextStyle(fontSize: 15, color: AppColors.textDim),
            ),
          for (final u in p.units) ...[
            _UnitCard(unit: u, library: library),
            const SizedBox(height: 10),
          ],
        ],
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: SkirmishScaffold(
        eyebrow: 'Skirmish · Turn ${s.turn}',
        name: s.name,
        onRename: (name) => setState(() => s.name = name),
        columns: [
          (label: 'PLAYER 1', child: units(0)),
          (
            label: 'MAP',
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: map == null
                  ? const SizedBox.shrink()
                  : MapPreview(map: map.mergedSaved),
            ),
          ),
          (label: 'PLAYER 2', child: units(1)),
        ],
        bottomBar: const SkirmishBottomBar(
          status: 'Turn tracking is not built yet.',
          children: [],
        ),
      ),
    );
  }
}

class _UnitCard extends StatelessWidget {
  const _UnitCard({required this.unit, required this.library});

  final SkirmishUnit unit;
  final MechLibrary? library;

  @override
  Widget build(BuildContext context) {
    final mech = library?.byId(unit.mechId);
    final pilot = unit.pilot;
    const dim = TextStyle(fontSize: 13, color: AppColors.textDim);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.panelRaised,
        border: Border(
          left: BorderSide(color: AppColors.accent, width: 4),
          top: BorderSide(color: AppColors.border),
          right: BorderSide(color: AppColors.border),
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            mech == null
                ? unit.mechId
                : '${mech.name} ${mech.variant}'.toUpperCase(),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${pilot.name.isEmpty ? 'Unnamed pilot' : pilot.name} · '
            'G${pilot.gunnery} / P${pilot.piloting}',
            style: dim,
          ),
          const SizedBox(height: 6),
          Text(
            'Armor ${unit.armorLeft}'
            '${mech == null ? '' : ' / ${mech.armorTotal}'} · '
            'Structure ${unit.structureLeft}'
            '${mech == null ? '' : ' / ${mech.structureTotal}'} · '
            'Heat ${unit.heat}',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
