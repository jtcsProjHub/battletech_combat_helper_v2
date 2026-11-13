// File: lib/screens/load_skirmish_screen.dart
// Load Skirmish: saved skirmishes on the left, most recent first; the
// chosen one's summary on the right with Continue and Delete. Continue
// opens setup for a skirmish still in setup, or the play screen for a
// confirmed one.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_theme.dart';
import '../lance_repository.dart';
import '../maps/map_repository.dart';
import '../skirmish/skirmish.dart';
import '../skirmish/skirmish_repository.dart';
import '../widgets/hud.dart';
import '../widgets/map/hex_map_view.dart';
import 'skirmish_play_screen.dart';
import 'skirmish_setup_screen.dart';

class LoadSkirmishScreen extends ConsumerStatefulWidget {
  const LoadSkirmishScreen({super.key});

  @override
  ConsumerState<LoadSkirmishScreen> createState() => _LoadSkirmishScreenState();
}

class _LoadSkirmishScreenState extends ConsumerState<LoadSkirmishScreen> {
  String? _selectedId;

  static const double _wideBreakpoint = 960;
  static const double _minPanelHeight = 600;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _continue(Skirmish s) async {
    if (!s.isActive) {
      // Pick up edits made to the precons or maps since the last session.
      try {
        s.refreshFromSources(
          lances: await ref.read(savedLancesProvider.future),
          maps: await ref.read(savedMapsProvider.future),
        );
      } on Object {
        // Keep the saved copies.
      }
    }
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => s.isActive
            ? SkirmishPlayScreen(skirmish: s)
            : SkirmishSetupScreen(skirmish: s),
      ),
    );
  }

  Future<void> _delete(Skirmish s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${s.name}?'),
        content: const Text(
          'The saved skirmish is removed. This cannot be undone.',
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
      await ref.read(savedSkirmishesProvider.notifier).delete(s.id);
      if (mounted) setState(() => _selectedId = null);
    } on Object catch (e) {
      _snack('Could not delete ${s.name}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(savedSkirmishesProvider);
    final list = saved.value ?? const <Skirmish>[];
    final selected = list.where((s) => s.id == _selectedId).firstOrNull;

    final Widget listPanel;
    if (saved.hasError) {
      listPanel = Text(
        'Saved skirmishes could not be read. ${saved.error}',
        style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
      );
    } else if (!saved.hasValue) {
      listPanel = const Center(child: CircularProgressIndicator());
    } else if (list.isEmpty) {
      listPanel = const Text(
        'No saved skirmishes yet. Start one with New Skirmish.',
        style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
      );
    } else {
      listPanel = ListView.separated(
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) => _SkirmishRow(
          skirmish: list[i],
          selected: list[i].id == _selectedId,
          onTap: () => setState(() => _selectedId = list[i].id),
        ),
      );
    }

    final menu = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const HudTitleBlock(eyebrow: 'Load Skirmish', title: 'Saved Games'),
        const SizedBox(height: 28),
        Expanded(child: listPanel),
      ],
    );
    final panel = HudFrame(
      padding: const EdgeInsets.fromLTRB(36, 32, 36, 32),
      child: selected == null
          ? const Text(
              'Choose a saved skirmish to see its status.',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            )
          : _SkirmishDetail(
              skirmish: selected,
              onContinue: () => _continue(selected),
              onDelete: () => _delete(selected),
            ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('LOAD SKIRMISH')),
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
                    SizedBox(width: 480, child: menu),
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
                SizedBox(height: 480, child: menu),
                const SizedBox(height: 32),
                SizedBox(height: 560, child: panel),
              ],
            ),
          );
        },
      ),
    );
  }
}

String _statusText(Skirmish s) =>
    s.isActive ? 'In progress · Turn ${s.turn}' : 'Setup · ${s.step.title}';

String _matchupText(Skirmish s) =>
    '${s.player1.lance?.name ?? 'No lance'} vs '
    '${s.player2.lance?.name ?? 'No lance'}';

class _SkirmishRow extends StatelessWidget {
  const _SkirmishRow({
    required this.skirmish,
    required this.selected,
    required this.onTap,
  });

  final Skirmish skirmish;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = skirmish;
    final edge = selected ? AppColors.borderStrong : AppColors.border;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.panelActive : AppColors.panelRaised,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: selected ? AppColors.accent : edge,
                  width: 4,
                ),
                top: BorderSide(color: edge),
                right: BorderSide(color: edge),
                bottom: BorderSide(color: edge),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.name.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.7,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: _statusText(s),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: s.isActive
                                    ? AppColors.accent
                                    : AppColors.textSecondary,
                              ),
                            ),
                            TextSpan(
                              text: ' · Saved ${formatDateTime(s.updatedAt)}',
                            ),
                          ],
                        ),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textDim,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: selected ? AppColors.accent : AppColors.iconDim,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SkirmishDetail extends StatelessWidget {
  const _SkirmishDetail({
    required this.skirmish,
    required this.onContinue,
    required this.onDelete,
  });

  final Skirmish skirmish;
  final VoidCallback onContinue;
  final VoidCallback onDelete;

  static const _shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(2)),
  );
  static const _buttonText = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
  );

  @override
  Widget build(BuildContext context) {
    final s = skirmish;
    final rows = <(String, String)>[
      ('Status', _statusText(s)),
      ('Player 1', s.player1.lance?.name ?? 'Not chosen'),
      ('Player 2', s.player2.lance?.name ?? 'Not chosen'),
      ('Map', s.map?.name ?? 'Not chosen'),
      ('Started', formatDateTime(s.createdAt)),
      ('Last saved', formatDateTime(s.updatedAt)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton(
              onPressed: onDelete,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(110, 44),
                shape: _shape,
              ),
              child: const Text('DELETE', style: _buttonText),
            ),
            FilledButton(
              onPressed: onContinue,
              style: FilledButton.styleFrom(
                minimumSize: const Size(140, 44),
                shape: _shape,
              ),
              child: Text(
                s.isActive ? 'RESUME' : 'CONTINUE SETUP',
                style: _buttonText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(s.name.toUpperCase(), style: HudText.panelTitle),
        const SizedBox(height: 4),
        Text(
          _matchupText(s),
          style: const TextStyle(fontSize: 15, color: AppColors.textDim),
        ),
        const SizedBox(height: 20),
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 160,
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
                    style: const TextStyle(fontSize: 15, color: AppColors.text),
                  ),
                ),
              ],
            ),
          ),
        if (s.map case final map?) ...[
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              color: AppColors.background,
              child: MapThumbnail(sheet: map.merged),
            ),
          ),
        ],
      ],
    );
  }
}
