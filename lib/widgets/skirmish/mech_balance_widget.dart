// File: lib/widgets/skirmish/mech_balance_widget.dart
// The balancing controls for one lance slot, sitting under its roster card
// without changing the card. A footer strip holds two buttons: the arrow
// opens the slot's other variants, and Edit pilot opens a pilot dropdown
// (the button turns into Cancel while it is open). Which dropdown is open,
// and what the header previews, belong to the LanceBalancingRoster that
// owns all the slots, so only one dropdown is open across the lance.

import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../bv_rules.dart';
import '../../lance.dart';
import '../../mech_data.dart';
import '../../mech_labels.dart';
import '../../pilot_data.dart';
import '../../variant_options.dart';
import '../gear_chip.dart';
import '../hud.dart';
import '../pilot_widgets.dart';
import 'skirmish_scaffold.dart' show SkirmishButtons;

enum BalanceDropdown { variants, pilot }

class MechBalanceWidget extends StatefulWidget {
  const MechBalanceWidget({
    super.key,
    required this.card,
    required this.mech,
    required this.pilot,
    required this.parameters,
    required this.options,
    required this.open,
    required this.onOpenChanged,
    required this.onPreview,
    required this.onCommit,
  });

  /// The roster card, shown as is.
  final Widget card;

  /// The slot's current mech and pilot.
  final Mech mech;
  final Pilot pilot;

  /// The lance's filters, for grouping and explaining [options].
  final LanceParameters parameters;

  /// The other variants, sorted (see variantOptions).
  final List<VariantOption> options;

  /// The dropdown open under this card, or null.
  final BalanceDropdown? open;

  /// Asks to open a dropdown, or with null, to close this card's.
  final ValueChanged<BalanceDropdown?> onOpenChanged;

  /// The slot as it would be after a change, while the change is only being
  /// looked at (a hovered variant, unsaved pilot skills); null ends it.
  final ValueChanged<LanceSlot?> onPreview;

  /// Keeps a change: a picked variant or a saved pilot.
  final ValueChanged<LanceSlot> onCommit;

  @override
  State<MechBalanceWidget> createState() => _MechBalanceWidgetState();
}

class _MechBalanceWidgetState extends State<MechBalanceWidget> {
  final _name = TextEditingController();
  late int _gunnery;
  late int _piloting;

  @override
  void initState() {
    super.initState();
    _resetDraft();
    _name.addListener(_onNameChanged);
  }

  @override
  void didUpdateWidget(MechBalanceWidget old) {
    super.didUpdateWidget(old);
    final opened =
        widget.open == BalanceDropdown.pilot &&
        old.open != BalanceDropdown.pilot;
    if (opened || widget.pilot != old.pilot) _resetDraft();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _resetDraft() {
    _name.text = widget.pilot.name;
    _gunnery = widget.pilot.gunnery;
    _piloting = widget.pilot.piloting;
  }

  // Save turns on as soon as the name differs.
  void _onNameChanged() => setState(() {});

  Pilot get _draft =>
      Pilot(name: _name.text.trim(), gunnery: _gunnery, piloting: _piloting);

  void _setSkills({int? gunnery, int? piloting}) {
    setState(() {
      _gunnery = gunnery ?? _gunnery;
      _piloting = piloting ?? _piloting;
    });
    widget.onPreview(LanceSlot(mechId: widget.mech.id, pilot: _draft));
  }

  void _savePilot() {
    if (_draft == widget.pilot) return;
    widget.onCommit(LanceSlot(mechId: widget.mech.id, pilot: _draft));
  }

  void _toggle(BalanceDropdown d) =>
      widget.onOpenChanged(widget.open == d ? null : d);

  @override
  Widget build(BuildContext context) {
    final open = widget.open;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        widget.card,
        _FooterStrip(
          variantsOpen: open == BalanceDropdown.variants,
          pilotOpen: open == BalanceDropdown.pilot,
          hasVariants: widget.options.isNotEmpty,
          onToggleVariants: () => _toggle(BalanceDropdown.variants),
          onTogglePilot: () => _toggle(BalanceDropdown.pilot),
        ),
        if (open == BalanceDropdown.variants)
          _Dropdown(
            child: _VariantList(
              current: widget.mech,
              pilot: widget.pilot,
              parameters: widget.parameters,
              options: widget.options,
              onPreview: (m) => widget.onPreview(
                m == null ? null : LanceSlot(mechId: m.id, pilot: widget.pilot),
              ),
              onPick: (m) =>
                  widget.onCommit(LanceSlot(mechId: m.id, pilot: widget.pilot)),
            ),
          ),
        if (open == BalanceDropdown.pilot)
          _Dropdown(
            accent: true,
            child: _PilotDropdown(
              mech: widget.mech,
              before: widget.pilot,
              name: _name,
              gunnery: _gunnery,
              piloting: _piloting,
              changed: _draft != widget.pilot,
              onGunneryChanged: (v) => _setSkills(gunnery: v),
              onPilotingChanged: (v) => _setSkills(piloting: v),
              onSave: _savePilot,
            ),
          ),
      ],
    );
  }
}

/// The strip under the card: the variants arrow and Edit pilot / Cancel.
class _FooterStrip extends StatelessWidget {
  const _FooterStrip({
    required this.variantsOpen,
    required this.pilotOpen,
    required this.hasVariants,
    required this.onToggleVariants,
    required this.onTogglePilot,
  });

  final bool variantsOpen;
  final bool pilotOpen;
  final bool hasVariants;
  final VoidCallback onToggleVariants;
  final VoidCallback onTogglePilot;

  @override
  Widget build(BuildContext context) {
    const small = Size(0, 32);
    final pilotLabel = Text(
      pilotOpen ? 'CANCEL' : 'EDIT PILOT',
      style: SkirmishButtons.text.copyWith(fontSize: 12),
    );
    return Container(
      height: 44,
      padding: const EdgeInsets.only(right: 6),
      decoration: const BoxDecoration(
        color: AppColors.panelRaised,
        border: Border(
          left: BorderSide(color: AppColors.accent, width: 4),
          right: BorderSide(color: AppColors.border),
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: !hasVariants
                ? 'No other variants'
                : variantsOpen
                ? 'Hide variants'
                : 'See variants',
            onPressed: hasVariants ? onToggleVariants : null,
            color: AppColors.accent,
            icon: Icon(variantsOpen ? Icons.expand_less : Icons.expand_more),
          ),
          const Spacer(),
          if (pilotOpen)
            OutlinedButton(
              onPressed: onTogglePilot,
              style: OutlinedButton.styleFrom(
                minimumSize: small,
                shape: SkirmishButtons.shape,
              ),
              child: pilotLabel,
            )
          else
            FilledButton(
              onPressed: onTogglePilot,
              style: FilledButton.styleFrom(
                minimumSize: small,
                shape: SkirmishButtons.shape,
              ),
              child: pilotLabel,
            ),
        ],
      ),
    );
  }
}

/// Indented under the card, with a rail on the left joining it to the card.
class _Dropdown extends StatelessWidget {
  const _Dropdown({required this.child, this.accent = false});

  final Widget child;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 0, 2),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: accent ? AppColors.accent : AppColors.borderStrong,
              width: 2,
            ),
          ),
        ),
        child: child,
      ),
    );
  }
}

// --- Variants ---------------------------------------------------------------

class _VariantList extends StatelessWidget {
  const _VariantList({
    required this.current,
    required this.pilot,
    required this.parameters,
    required this.options,
    required this.onPreview,
    required this.onPick,
  });

  final Mech current;
  final Pilot pilot;
  final LanceParameters parameters;
  final List<VariantOption> options;
  final ValueChanged<Mech?> onPreview;
  final ValueChanged<Mech> onPick;

  @override
  Widget build(BuildContext context) {
    Widget tile(VariantOption o) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _VariantTile(
        option: o,
        current: current,
        pilot: pilot,
        missText: o.miss == null
            ? null
            : parameters.describeMiss(o.miss!, o.mech),
        onHover: (on) => onPreview(on ? o.mech : null),
        onTap: () => onPick(o.mech),
      ),
    );

    if (!parameters.filtersAvailability) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final o in options) tile(o)],
      );
    }
    final fit = [
      for (final o in options)
        if (o.fitsFilters) o,
    ];
    final off = [
      for (final o in options)
        if (!o.fitsFilters) o,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GroupHeader(
          icon: Icons.check,
          label: 'FITS LANCE FILTERS',
          count: fit.length,
          color: AppColors.added,
        ),
        if (fit.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'No other variant fits the lance\'s era and faction.',
              style: TextStyle(fontSize: 13, color: AppColors.textDim),
            ),
          ),
        for (final o in fit) tile(o),
        if (off.isNotEmpty) ...[
          _GroupHeader(
            icon: Icons.close,
            label: 'OUTSIDE LANCE FILTERS',
            count: off.length,
            color: AppColors.offFilter,
          ),
          for (final o in off) tile(o),
        ],
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(child: Divider(height: 1)),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: const TextStyle(fontSize: 12, color: AppColors.textDim),
          ),
        ],
      ),
    );
  }
}

/// One variant: name, BV and its change, the card's four stats compared
/// with the current variant, then the gear it removes and adds. Hovering
/// previews it; tapping swaps to it.
class _VariantTile extends StatelessWidget {
  const _VariantTile({
    required this.option,
    required this.current,
    required this.pilot,
    required this.missText,
    required this.onHover,
    required this.onTap,
  });

  final VariantOption option;
  final Mech current;
  final Pilot pilot;
  final String? missText;
  final ValueChanged<bool> onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = option.mech;
    final bv = m.bvWith(pilot);
    final delta = bv - current.bvWith(pilot);
    final gear = option.gear;
    final miss = missText;

    return Opacity(
      opacity: option.fitsFilters ? 1 : 0.8,
      child: Material(
        color: AppColors.panel,
        shape: const Border.fromBorderSide(BorderSide(color: AppColors.border)),
        child: InkWell(
          onTap: onTap,
          onHover: onHover,
          onFocusChange: onHover,
          hoverColor: AppColors.panelActive,
          child: Semantics(
            button: true,
            label: 'Swap to ${m.variant}',
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        m.variant,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      if (miss != null) ...[
                        const SizedBox(width: 8),
                        Expanded(child: _MissTag(miss)),
                      ] else
                        const Spacer(),
                      if (miss != null) const SizedBox(width: 8),
                      Text(
                        groupDigits(bv),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
                      SizedBox(
                        width: 56,
                        child: Text(
                          signedDigits(delta),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: deltaColor(delta),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _StatDiffRow(from: current, to: m),
                  if (gear.removed.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _GearRow(
                      label: '− REMOVED',
                      color: AppColors.removed,
                      tone: GearChipTone.removed,
                      changes: gear.removed,
                    ),
                  ],
                  if (gear.added.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _GearRow(
                      label: '+ ADDED',
                      color: AppColors.added,
                      tone: GearChipTone.added,
                      changes: gear.added,
                    ),
                  ],
                  if (gear.isEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Same weapons and equipment.',
                      style: TextStyle(fontSize: 12, color: AppColors.textDim),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MissTag extends StatelessWidget {
  const _MissTag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.offFilter.withValues(alpha: 0.5)),
        ),
        child: Text(
          '✕ $text',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.offFilter,
          ),
        ),
      ),
    );
  }
}

/// Move, armor, structure and heat sinks, as on the card: the variant's
/// value, colored better or worse, with what changed underneath.
/// Unchanged stats are dimmed.
class _StatDiffRow extends StatelessWidget {
  const _StatDiffRow({required this.from, required this.to});

  final Mech from;
  final Mech to;

  @override
  Widget build(BuildContext context) {
    final moves = <String>[
      for (final (label, a, b) in [
        ('walk', from.walk, to.walk),
        ('run', from.run, to.run),
        ('jump', from.jump, to.jump),
      ])
        if (a != b) '${signedDigits(b - a)} $label',
    ];
    final moveBetter = to.walk > from.walk || to.jump > from.jump;
    final moveWorse = to.walk < from.walk || to.jump < from.jump;
    final sinksChanged =
        to.heatSinks.count != from.heatSinks.count ||
        to.heatSinks.type != from.heatSinks.type;

    final cells = [
      _StatDiffCell(
        label: 'MOVE',
        value: to.moveText,
        note: moves.join(' '),
        trend: moveBetter && !moveWorse
            ? 1
            : moveWorse && !moveBetter
            ? -1
            : 0,
      ),
      _StatDiffCell.number('ARMOR', from.armorTotal, to.armorTotal),
      _StatDiffCell.number('STRUCT', from.structureTotal, to.structureTotal),
      _StatDiffCell(
        label: 'HEAT SINKS',
        value: '${to.heatSinks.count} ${to.heatSinkShort}',
        note: sinksChanged
            ? 'was ${from.heatSinks.count} ${from.heatSinkShort}'
            : '',
        trend: (to.heatDissipation - from.heatDissipation).sign,
      ),
    ];
    return Row(
      children: [
        for (final (i, c) in cells.indexed) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(child: c),
        ],
      ],
    );
  }
}

class _StatDiffCell extends StatelessWidget {
  const _StatDiffCell({
    required this.label,
    required this.value,
    required this.note,
    required this.trend,
  });

  _StatDiffCell.number(String label, int from, int to)
    : this(
        label: label,
        value: '$to',
        note: from == to ? '' : signedDigits(to - from),
        trend: (to - from).sign,
      );

  final String label;
  final String value;

  /// What changed, or empty when nothing did.
  final String note;

  /// 1 better, -1 worse, 0 the same or mixed.
  final int trend;

  @override
  Widget build(BuildContext context) {
    final same = note.isEmpty;
    final color = switch (trend) {
      > 0 => AppColors.added,
      < 0 => AppColors.removed,
      _ => AppColors.textSecondary,
    };
    return Opacity(
      opacity: same ? 0.55 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.panelRaised,
          border: Border.all(color: AppColors.cellBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: HudText.sectionLabel.copyWith(fontSize: 10),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              same ? '=' : note,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: AppColors.textDim),
            ),
          ],
        ),
      ),
    );
  }
}

class _GearRow extends StatelessWidget {
  const _GearRow({
    required this.label,
    required this.color,
    required this.tone,
    required this.changes,
  });

  final String label;
  final Color color;
  final GearChipTone tone;
  final List<GearChange> changes;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: color,
              ),
            ),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              for (final c in changes)
                GearChip(quantity: c.quantity, name: c.name, tone: tone),
            ],
          ),
        ),
      ],
    );
  }
}

// --- Pilot ------------------------------------------------------------------

/// The shared pilot fields, then the BV change and Save.
class _PilotDropdown extends StatelessWidget {
  const _PilotDropdown({
    required this.mech,
    required this.before,
    required this.name,
    required this.gunnery,
    required this.piloting,
    required this.changed,
    required this.onGunneryChanged,
    required this.onPilotingChanged,
    required this.onSave,
  });

  final Mech mech;
  final Pilot before;
  final TextEditingController name;
  final int gunnery;
  final int piloting;
  final bool changed;
  final ValueChanged<int> onGunneryChanged;
  final ValueChanged<int> onPilotingChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final after = Pilot(gunnery: gunnery, piloting: piloting);
    final delta = mech.bvWith(after) - mech.bvWith(before);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'PILOT · ${mech.name.toUpperCase()} ${mech.variant}',
            style: HudText.sectionLabel,
          ),
          const SizedBox(height: 4),
          PilotEditorFields(
            mech: mech,
            before: before,
            name: name,
            gunnery: gunnery,
            piloting: piloting,
            onGunneryChanged: onGunneryChanged,
            onPilotingChanged: onPilotingChanged,
            onSubmitted: onSave,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  delta == 0 ? 'No change in BV' : '${signedDigits(delta)} BV',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: delta == 0 ? AppColors.textDim : deltaColor(delta),
                  ),
                ),
              ),
              FilledButton(
                onPressed: changed ? onSave : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(96, 40),
                  shape: SkirmishButtons.shape,
                ),
                child: Text('SAVE', style: SkirmishButtons.text),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "+278", "−150" or "±0", for BV and stat changes.
String signedDigits(int n) => n > 0
    ? '+${groupDigits(n)}'
    : n < 0
    ? '−${groupDigits(-n)}'
    : '±0';

/// A BV change's color: a decrease is blue, an increase red.
Color deltaColor(int delta) => delta < 0
    ? AppColors.decrease
    : delta > 0
    ? AppColors.removed
    : AppColors.textDim;
