// File: lib/widgets/saved_lance_list.dart
// Pick one saved lance: a row per lance with its mech count, battle value,
// and filters. Used by Edit Lance, and later by New Skirmish for each side.

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../lance.dart';
import '../lance_totals.dart';
import '../mech_labels.dart';
import '../mech_library.dart';

class SavedLanceList extends StatelessWidget {
  const SavedLanceList({
    super.key,
    required this.lances,
    required this.library,
    required this.onSelect,
    this.selectedId,
    this.emptyText = 'No saved lances yet.',
  });

  final List<Lance> lances;
  final MechLibrary library;
  final ValueChanged<Lance> onSelect;
  final String? selectedId;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (lances.isEmpty) {
      return Text(
        emptyText,
        style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
      );
    }
    return ListView.separated(
      itemCount: lances.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _LanceRow(
        totals: LanceTotals(lances[i], library),
        selected: lances[i].id == selectedId,
        onTap: () => onSelect(lances[i]),
      ),
    );
  }
}

class _LanceRow extends StatelessWidget {
  const _LanceRow({
    required this.totals,
    required this.selected,
    required this.onTap,
  });

  final LanceTotals totals;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lance = totals.lance;
    final p = totals.parameters;
    final edge = selected ? AppColors.borderStrong : AppColors.border;
    const dim = TextStyle(fontSize: 13, color: AppColors.textDim);

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
                        lance.name.toUpperCase(),
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
                              text:
                                  '${totals.mechs.length} of ${p.maxMechs} '
                                  'mechs · ',
                            ),
                            TextSpan(
                              text:
                                  '${groupDigits(totals.usedBattleValue)} / '
                                  '${groupDigits(p.targetBattleValue)} BV',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: totals.isOverBudget
                                    ? AppColors.overBudget
                                    : AppColors.accent,
                              ),
                            ),
                            TextSpan(
                              text:
                                  ' · ${p.era?.label ?? 'Any era'}'
                                  ' · ${p.faction ?? 'Any faction'}'
                                  ' · ${p.techBase?.label ?? 'Any tech'}',
                            ),
                          ],
                        ),
                        style: dim,
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
