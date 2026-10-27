// File: lib/widgets/lance_roster_panel.dart
// The mechs in the lance as compact cards, then one dashed outline per open
// slot with the BV left to spend.

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../lance_draft.dart';
import '../mech_data.dart';
import '../mech_labels.dart';
import 'mech_thumbnail.dart';

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
    final mechs = draft.mechs;
    final over = draft.isOverBudget;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      children: [
        Row(
          children: [
            const Text('ROSTER', style: _labelStyle),
            const Spacer(),
            Text(
              '${mechs.length} of ${draft.parameters.maxMechs}',
              style: const TextStyle(fontSize: 12, color: AppColors.textDim),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final m in mechs) ...[
          _RosterCard(
            mech: m,
            selected: m.id == selectedId,
            onSelect: () => onSelect(m),
            onRemove: () => draft.remove(m.id),
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
              number: mechs.length + i + 1,
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
    required this.selected,
    required this.onSelect,
    required this.onRemove,
  });

  final Mech mech;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onRemove;

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
          child: Row(
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
                            style: const TextStyle(color: AppColors.textDim),
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
                    Text(
                      '${m.bv} BV',
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
    return CustomPaint(
      painter: const _DashedBorderPainter(),
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

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.borderStrong
      ..strokeWidth = 2;
    const dash = 6.0, gap = 5.0;
    void line(Offset a, Offset b) {
      final total = (b - a).distance;
      final dir = (b - a) / total;
      for (var d = 0.0; d < total; d += dash + gap) {
        final end = d + dash < total ? d + dash : total;
        canvas.drawLine(a + dir * d, a + dir * end, paint);
      }
    }

    final r = Offset.zero & size;
    line(r.topLeft, r.topRight);
    line(r.topRight, r.bottomRight);
    line(r.bottomRight, r.bottomLeft);
    line(r.bottomLeft, r.topLeft);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
