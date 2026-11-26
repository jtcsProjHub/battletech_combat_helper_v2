// File: lib/widgets/lance_roster_detail.dart
// One lance in full detail: a header with the filters and totals, then a
// large card per mech with its pilot. Read-only by default; editable mode
// adds remove buttons, pilot editing, and the open slots. Used by Edit Lance and New Skirmish. The
// builder keeps its compact LanceRosterPanel.

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../bv_rules.dart';
import '../lance.dart';
import '../lance_totals.dart';
import '../mech_data.dart';
import '../mech_labels.dart';
import '../mech_library.dart';
import '../pilot_data.dart';
import 'hud.dart';
import 'mech_thumbnail.dart';
import 'pilot_widgets.dart';

/// The header and the SELECTED label stay put while the mech cards scroll
/// below them, so give it a bounded height (for example inside [Expanded]),
/// not a scroll view.
class LanceRosterDetail extends StatelessWidget {
  const LanceRosterDetail({
    super.key,
    required this.lance,
    required this.library,
    this.editable = false,
    this.onRemove,
    this.onEditPilot,
    this.onSelect,
  });

  final Lance lance;
  final MechLibrary library;
  final bool editable;

  /// Called with the mech id. Used only when [editable].
  final ValueChanged<String>? onRemove;

  /// Called with the mech id when its pilot row is tapped. Used only when
  /// [editable].
  final ValueChanged<String>? onEditPilot;

  /// Called when a card is tapped, for example to show a preview.
  final ValueChanged<Mech>? onSelect;

  @override
  Widget build(BuildContext context) {
    final totals = LanceTotals(lance, library);
    final remove = editable ? onRemove : null;
    final editPilot = editable ? onEditPilot : null;
    final select = onSelect;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < _compactWidth;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(totals: totals, compact: compact),
            // Read-only, every card is the roster, so the label adds nothing.
            if (editable) ...[
              const SizedBox(height: 20),
              const Text('SELECTED', style: HudText.sectionLabel),
              const SizedBox(height: 10),
            ] else
              SizedBox(height: compact ? 12 : 16),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  if (totals.entries.isEmpty)
                    const _Note('No mechs in this lance yet.')
                  else
                    for (final (mech: m, :pilot) in totals.entries) ...[
                      _MechCard(
                        mech: m,
                        pilot: pilot,
                        compact: compact,
                        onRemove: remove == null ? null : () => remove(m.id),
                        onEditPilot: editPilot == null
                            ? null
                            : () => editPilot(m.id),
                        onTap: select == null ? null : () => select(m),
                      ),
                      const SizedBox(height: 10),
                    ],
                  const SizedBox(height: 10),
                  _Footer(totals: totals, editable: editable),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Below this width (for example one of the three skirmish setup columns)
/// the header and cards tighten up.
const _compactWidth = 560.0;

const _dimSmall = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w600,
  color: AppColors.textDim,
);

class _Header extends StatelessWidget {
  const _Header({required this.totals, required this.compact});

  final LanceTotals totals;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = totals.parameters;
    final filters =
        'Era: ${p.era?.label ?? 'Any'} · '
        'Faction: ${p.faction ?? 'Any'} · '
        'Tech: ${p.techBase?.label ?? 'Any'}';
    final over = totals.isOverBudget;
    final bvColor = over ? AppColors.overBudget : AppColors.accent;
    final target = p.targetBattleValue;
    final fraction = target > 0
        ? (totals.usedBattleValue / target).clamp(0.0, 1.0)
        : 0.0;

    final boxes = [
      _StatBox(
        compact: compact,
        label: 'BATTLE VALUE',
        value: Text(
          groupDigits(totals.usedBattleValue),
          style: TextStyle(color: bvColor),
        ),
        suffix: ' / ${groupDigits(target)}',
        bar: Container(
          height: 6,
          color: AppColors.cellBorder,
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: fraction,
            child: Container(color: bvColor),
          ),
        ),
      ),
      _StatBox(
        compact: compact,
        label: 'TONNAGE',
        value: Text('${totals.tonnage.round()}'),
        suffix: ' t',
      ),
      _StatBox(
        compact: compact,
        label: 'MECHS',
        value: Text('${totals.mechs.length}'),
        suffix: ' / ${p.maxMechs}',
      ),
    ];

    return HudFrame(
      padding: compact
          ? const EdgeInsets.fromLTRB(16, 14, 16, 14)
          : const EdgeInsets.fromLTRB(22, 20, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 16,
            runSpacing: 8,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('LANCE ROSTER', style: HudText.eyebrow),
                  const SizedBox(height: 4),
                  Text(
                    totals.lance.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: compact ? 28 : 36,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      height: 1,
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),
              Text(
                filters,
                style: const TextStyle(fontSize: 13, color: AppColors.textDim),
              ),
            ],
          ),
          SizedBox(height: compact ? 10 : 14),
          // Always one row. Narrow, battle value (the widest) gets double
          // width and the boxes shrink rather than wrapping to a second row.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, box) in boxes.indexed) ...[
                if (i > 0) SizedBox(width: compact ? 8 : 10),
                Expanded(flex: compact && i == 0 ? 2 : 1, child: box),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.value,
    required this.suffix,
    required this.compact,
    this.bar,
  });

  final String label;
  final Text value;
  final String suffix;
  final bool compact;
  final Widget? bar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.panelRaised,
        border: Border.all(color: AppColors.cellBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FitText(Text(label, style: HudText.sectionLabel)),
          SizedBox(height: compact ? 4 : 6),
          DefaultTextStyle.merge(
            style: TextStyle(
              fontSize: compact ? 18 : 22,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                value,
                Flexible(
                  child: Text(
                    suffix,
                    style: _dimSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Boxes without a bar keep its height so the row lines up.
          bar ?? const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _MechCard extends StatelessWidget {
  const _MechCard({
    required this.mech,
    required this.pilot,
    required this.compact,
    this.onRemove,
    this.onEditPilot,
    this.onTap,
  });

  final Mech mech;
  final Pilot pilot;
  final bool compact;
  final VoidCallback? onRemove;
  final VoidCallback? onEditPilot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final m = mech;
    final remove = onRemove;
    final groups = m.weaponGroups;
    final thumbColumn = compact ? 112.0 : 148.0;
    final tonnage = '${m.tonnage.round()} t · ${m.weightClassString}';

    // IntrinsicHeight below rules out a LayoutBuilder inside the card, so
    // work out the stats area width here: card minus borders, the thumbnail
    // column and the right column's padding.
    return LayoutBuilder(
      builder: (context, constraints) {
        final statsWidth = constraints.maxWidth - 5 - thumbColumn - 1 - 34;
        final statsGrid = statsWidth < 400;
        return Semantics(
          container: true,
          label: '${m.name} ${m.variant}',
          child: Material(
            color: AppColors.panel,
            child: InkWell(
              onTap: onTap,
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: AppColors.accent, width: 4),
                    top: BorderSide(color: AppColors.border),
                    right: BorderSide(color: AppColors.border),
                    bottom: BorderSide(color: AppColors.border),
                  ),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: thumbColumn,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 12,
                        ),
                        decoration: const BoxDecoration(
                          color: AppColors.panelRaised,
                          border: Border(
                            right: BorderSide(color: AppColors.border),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            MechThumbnail(
                              mechId: m.id,
                              width: compact ? 76 : 96,
                              height: compact ? 92 : 116,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              m.name.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: _fitLongestWord(
                                m.name.toUpperCase(),
                                DefaultTextStyle.of(context).style.merge(
                                  TextStyle(
                                    fontSize: compact ? 16 : 18,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.7,
                                    height: 1.05,
                                    color: AppColors.text,
                                  ),
                                ),
                                // Column minus its horizontal padding and
                                // right border.
                                maxWidth: thumbColumn - 21,
                                textScaler: MediaQuery.textScalerOf(context),
                              ),
                            ),
                            Text(
                              m.variant,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textDim,
                              ),
                            ),
                            // Narrow, the top row has no room for it.
                            if (compact) ...[
                              const SizedBox(height: 4),
                              Text(
                                tonnage,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 14, 16, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  // Compact: tonnage sits in the left column
                                  // and the chip shrinks only if it must.
                                  if (compact)
                                    Flexible(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: _RoleChip(m.role.label),
                                      ),
                                    )
                                  else ...[
                                    _RoleChip(m.role.label),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        tonnage,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (compact) const SizedBox(width: 10),
                                  Text.rich(
                                    TextSpan(
                                      text: groupDigits(m.bvWith(pilot)),
                                      children: [
                                        const TextSpan(
                                          text: ' BV',
                                          style: TextStyle(
                                            fontSize: 13,
                                            letterSpacing: 1.3,
                                            color: AppColors.textDim,
                                          ),
                                        ),
                                        if (!pilot.isStandardSkill)
                                          TextSpan(
                                            text: '\nbase ${groupDigits(m.bv)}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w400,
                                              color: AppColors.textDim,
                                            ),
                                          ),
                                      ],
                                    ),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.accent,
                                    ),
                                  ),
                                  if (remove != null) ...[
                                    const SizedBox(width: 10),
                                    SizedBox.square(
                                      dimension: 32,
                                      child: IconButton(
                                        tooltip:
                                            'Remove ${m.name} ${m.variant}',
                                        onPressed: remove,
                                        padding: EdgeInsets.zero,
                                        iconSize: 18,
                                        color: AppColors.textDim,
                                        style: IconButton.styleFrom(
                                          shape: const RoundedRectangleBorder(
                                            side: BorderSide(
                                              color: AppColors.borderStrong,
                                            ),
                                            borderRadius: BorderRadius.all(
                                              Radius.circular(2),
                                            ),
                                          ),
                                        ),
                                        icon: const Icon(Icons.close),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 12),
                              _StatGrid(mech: m, twoByTwo: statsGrid),
                              if (groups.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    for (final g in groups) _WeaponChip(g),
                                  ],
                                ),
                              ],
                              const Spacer(),
                              const Divider(height: 20),
                              PilotRow(pilot: pilot, onEdit: onEditPilot),
                            ],
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
      },
    );
  }
}

/// [style] with its font size reduced, if needed, so the longest word of
/// [text] fits in [maxWidth]. Names still wrap between words, but a long
/// single word such as THUNDERBOLT never breaks mid-word.
TextStyle _fitLongestWord(
  String text,
  TextStyle style, {
  required double maxWidth,
  required TextScaler textScaler,
}) {
  var widest = 0.0;
  for (final word in text.split(' ')) {
    final painter = TextPainter(
      text: TextSpan(text: word, style: style),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    if (painter.width > widest) widest = painter.width;
    painter.dispose();
  }
  if (widest <= maxWidth) return style;
  // A little under the exact ratio: line breaking can differ from the
  // measurement by a fraction of a pixel.
  return style.copyWith(fontSize: style.fontSize! * maxWidth / widest * 0.95);
}

/// Move, armor, structure and heat sinks: four across, or two by two when
/// the card is too narrow for four.
class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.mech, required this.twoByTwo});

  final Mech mech;
  final bool twoByTwo;

  @override
  Widget build(BuildContext context) {
    final m = mech;
    final cells = [
      _StatCell(label: 'MOVE', value: m.moveText),
      _StatCell(label: 'ARMOR', value: '${m.armorTotal}'),
      _StatCell(label: 'STRUCT', value: '${m.structureTotal}'),
      _StatCell(
        label: 'HEAT SINKS',
        value: '${m.heatSinks.count} ${m.heatSinkShort}',
      ),
    ];
    Widget row(List<Widget> items) => Row(
      children: [
        for (final (i, c) in items.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: c),
        ],
      ],
    );
    if (!twoByTwo) return row(cells);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row(cells.sublist(0, 2)),
        const SizedBox(height: 8),
        row(cells.sublist(2)),
      ],
    );
  }
}

/// One line that shrinks to fit its width instead of cutting off with an
/// ellipsis, left-aligned.
class _FitText extends StatelessWidget {
  const _FitText(this.text);

  final Text text;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: text,
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip(this.role);

  final String role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      color: AppColors.textSecondary,
      child: Text(
        role.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: AppColors.background,
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.panelRaised,
        border: Border.all(color: AppColors.cellBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FitText(
            Text(
              label,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: AppColors.textDim,
              ),
            ),
          ),
          const SizedBox(height: 2),
          _FitText(
            Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeaponChip extends StatelessWidget {
  const _WeaponChip(this.group);

  final WeaponGroup group;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.panelActive,
        border: Border.all(color: AppColors.chipBorder),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${group.quantity}×',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
              ),
            ),
            TextSpan(text: ' ${group.weapon.type}'),
          ],
        ),
        style: const TextStyle(fontSize: 13, color: AppColors.text),
      ),
    );
  }
}

/// What follows the cards: open slots when editable, or one status line.
class _Footer extends StatelessWidget {
  const _Footer({required this.totals, required this.editable});

  final LanceTotals totals;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    final over = totals.isOverBudget;
    final overText =
        '${groupDigits(-totals.remainingBattleValue)} BV over the '
        'target.';

    if (totals.isFull) {
      return _Note(
        over
            ? 'Lance is full. $overText'
            : 'Lance is full. ${groupDigits(totals.remainingBattleValue)} BV '
                  'left under the target.',
        over: over,
      );
    }
    if (!editable) {
      return _Note(
        '${totals.mechs.length} of ${totals.parameters.maxMechs} slots filled',
      );
    }

    final filled = totals.parameters.maxMechs - totals.openSlots;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 12,
          runSpacing: 4,
          children: [
            const Text('REMAINING SLOTS', style: HudText.sectionLabel),
            if (over)
              Text(
                overText,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.overBudget,
                ),
              )
            else
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text:
                          '${groupDigits(totals.remainingBattleValue)} BV left',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    ),
                    TextSpan(
                      text:
                          ' · about '
                          '${groupDigits(totals.battleValuePerOpenSlot)} BV '
                          'per slot',
                    ),
                  ],
                ),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < totals.openSlots; i++) ...[
          DashedOutline(
            child: SizedBox(
              height: 150,
              child: Center(
                child: Text(
                  '+ ADD MECH · SLOT ${filled + i + 1}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                    color: AppColors.textDim,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text, {this.over = false});

  final String text;
  final bool over;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        color: over ? AppColors.overBudget : AppColors.textSecondary,
      ),
    );
  }
}
