// File: lib/widgets/lance_roster_panel.dart
// The mechs in the lance as compact cards with their pilots, then one dashed
// outline per open slot with the BV left to spend.

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../bv_rules.dart';
import '../lance_draft.dart';
import '../mech_data.dart';
import '../mech_labels.dart';
import '../pilot_data.dart';
import 'hud.dart';
import 'mech_thumbnail.dart';
import 'pilot_widgets.dart';

class LanceRosterPanel extends StatelessWidget {
  const LanceRosterPanel({
    super.key,
    required this.draft,
    required this.selectedId,
    required this.onSelect,
  });

  final LanceDraft draft;
  final String? selectedId;
  final ValueChanged<Mech> onSelect;

  static const _labelStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 2,
    color: AppColors.textDim,
  );

  @override
  Widget build(BuildContext context) {
    final entries = draft.totals.entries;
    final over = draft.isOverBudget;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      children: [
        Row(
          children: [
            const Text('ROSTER', style: _labelStyle),
            const Spacer(),
            Text(
              '${entries.length} of ${draft.parameters.maxMechs}',
              style: const TextStyle(fontSize: 12, color: AppColors.textDim),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final (:mech, :pilot) in entries) ...[
          _RosterCard(
            mech: mech,
            pilot: pilot,
            selected: mech.id == selectedId,
            onSelect: () => onSelect(mech),
            onRemove: () => draft.remove(mech.id),
            onEditPilot: () async {
              final chosen = await showPilotDialog(
                context,
                mech: mech,
                pilot: pilot,
                lance: draft.totals,
              );
              if (chosen != null) draft.setPilot(mech.id, chosen);
            },
          ),
          const SizedBox(height: 8),
        ],
        if (draft.openSlots > 0) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Text('OPEN SLOTS', style: _labelStyle),
              const Spacer(),
              Text(
                '${draft.remainingBattleValue} BV left',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: over ? const Color(0xFFFF7A6A) : AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < draft.openSlots; i++) ...[
            _OpenSlot(
              number: entries.length + i + 1,
              perSlot: draft.battleValuePerOpenSlot,
            ),
            const SizedBox(height: 8),
          ],
        ] else
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              over
                  ? 'Lance is full and ${-draft.remainingBattleValue} BV over the target.'
                  : 'Lance is full. ${draft.remainingBattleValue} BV left under the target.',
              style: TextStyle(
                fontSize: 13,
                color: over ? const Color(0xFFFF7A6A) : AppColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}

class _RosterCard extends StatelessWidget {
  const _RosterCard({
    required this.mech,
    required this.pilot,
    required this.selected,
    required this.onSelect,
    required this.onRemove,
    required this.onEditPilot,
  });

  final Mech mech;
  final Pilot pilot;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onRemove;
  final VoidCallback onEditPilot;

  @override
  Widget build(BuildContext context) {
    final m = mech;
    return Material(
      color: selected ? AppColors.panelActive : AppColors.panel,
      child: InkWell(
        onTap: onSelect,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: AppColors.accent, width: 3),
              top: BorderSide(color: AppColors.border),
              right: BorderSide(color: AppColors.border),
              bottom: BorderSide(color: AppColors.border),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 64,
                    color: AppColors.panelRaised,
                    alignment: Alignment.center,
                    child: MechThumbnail(mechId: m.id, width: 46, height: 60),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            text: '${m.name.toUpperCase()} ',
                            children: [
                              TextSpan(
                                text: m.variant.toUpperCase(),
                                style: const TextStyle(
                                  color: AppColors.textDim,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${m.tonnage.round()} t · ${m.role.label} · ${m.moveText}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textDim,
                          ),
                        ),
                        Text.rich(
                          TextSpan(
                            text: '${m.bvWith(pilot)} BV',
                            children: [
                              if (!pilot.isStandardSkill)
                                TextSpan(
                                  text: '  base ${m.bv}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w400,
                                    color: AppColors.textDim,
                                  ),
                                ),
                            ],
                          ),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove ${m.name} ${m.variant}',
                    onPressed: onRemove,
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
              const Divider(height: 12),
              PilotRow(pilot: pilot, onEdit: onEditPilot),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpenSlot extends StatelessWidget {
  const _OpenSlot({required this.number, required this.perSlot});

  final int number;
  final int perSlot;

  @override
  Widget build(BuildContext context) {
    return DashedOutline(
      child: SizedBox(
        height: 80,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'SLOT $number',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.4,
                color: AppColors.textDim,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'about $perSlot BV',
              style: const TextStyle(fontSize: 12, color: AppColors.textDim),
            ),
          ],
        ),
      ),
    );
  }
}
