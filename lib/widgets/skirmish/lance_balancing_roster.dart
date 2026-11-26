// File: lib/widgets/skirmish/lance_balancing_roster.dart
// A lance roster that can be balanced: LanceRosterDetail with a
// MechBalanceWidget under each card and a BV change line in its header.
// It keeps which dropdown is open (one across the lance) and the change
// being previewed, and hands every kept change to [onChanged] as a new
// lance. With a ChangeHistory it records each change and offers Undo and
// Redo in the header line. Used on the New Skirmish overview step.

import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../history/change_history.dart';
import '../../lance.dart';
import '../../lance_totals.dart';
import '../../mech_labels.dart';
import '../../mech_library.dart';
import '../../pilot_data.dart';
import '../../variant_options.dart';
import '../lance_roster_detail.dart';
import 'mech_balance_widget.dart';

class LanceBalancingRoster extends StatefulWidget {
  const LanceBalancingRoster({
    super.key,
    required this.lance,
    required this.library,
    required this.onChanged,
    this.savedBattleValue,
    this.history,
  });

  final Lance lance;
  final MechLibrary library;

  /// Called with the lance after a variant swap or a saved pilot.
  final ValueChanged<Lance> onChanged;

  /// BV of the saved lance this one was picked from, so the header can show
  /// how far balancing has moved it. Null when that lance is gone.
  final int? savedBattleValue;

  /// Records each kept change; with it the header line shows Undo and Redo.
  /// The caller owns it, like a controller, so it outlives this widget (for
  /// example while the player steps back to the map and returns).
  final ChangeHistory<Lance>? history;

  @override
  State<LanceBalancingRoster> createState() => _LanceBalancingRosterState();
}

class _LanceBalancingRosterState extends State<LanceBalancingRoster> {
  /// The open dropdown and the slot it is under.
  ({int slot, BalanceDropdown dropdown})? _open;

  /// The lance as it would be with the change being looked at.
  Lance? _preview;

  @override
  void didUpdateWidget(LanceBalancingRoster old) {
    super.didUpdateWidget(old);
    if (widget.lance.id != old.lance.id) {
      _open = null;
      _preview = null;
    }
  }

  Lance _withSlot(int index, LanceSlot slot) =>
      widget.lance.copyWith(slots: [...widget.lance.slots]..[index] = slot);

  void _setOpen(int slot, BalanceDropdown? dropdown) => setState(() {
    _open = dropdown == null ? null : (slot: slot, dropdown: dropdown);
    _preview = null;
  });

  void _commit(int index, LanceSlot slot) {
    setState(() {
      _preview = null;
      // A saved pilot closes its dropdown; the variant list stays open to
      // compare against the new variant.
      if (_open?.dropdown == BalanceDropdown.pilot) _open = null;
    });
    final next = _withSlot(index, slot);
    widget.history?.record(
      Change(
        label: _describe(widget.lance.slots[index], slot),
        before: widget.lance,
        after: next,
      ),
    );
    widget.onChanged(next);
  }

  /// Undo and redo close any dropdown, since what it showed may be gone.
  void _step(Change<Lance>? Function(ChangeHistory<Lance>) move, bool back) {
    final history = widget.history;
    final change = history == null ? null : move(history);
    if (change == null) return;
    setState(() {
      _open = null;
      _preview = null;
    });
    widget.onChanged(back ? change.before : change.after);
  }

  /// "Atlas AS7-D → AS7-K" or "Atlas AS7-D pilot 4/5 → Kai 3/5".
  String _describe(LanceSlot from, LanceSlot to) {
    final before = widget.library.byId(from.mechId);
    final mech = before == null
        ? from.mechId
        : '${before.name} ${before.variant}';
    if (from.mechId != to.mechId) {
      return '$mech → ${widget.library.byId(to.mechId)?.variant ?? to.mechId}';
    }
    String pilot(Pilot p) =>
        '${p.name.isEmpty ? '' : '${p.name} '}${p.gunnery}/${p.piloting}';
    return '$mech pilot ${pilot(from.pilot)} → ${pilot(to.pilot)}';
  }

  Widget _wrapCard(BuildContext context, int index, Widget card) {
    final slot = widget.lance.slots[index];
    final mech = widget.library.byId(slot.mechId);
    if (mech == null) return card;
    final open = _open;
    return MechBalanceWidget(
      card: card,
      mech: mech,
      pilot: slot.pilot,
      parameters: widget.lance.parameters,
      options: variantOptions(
        current: mech,
        library: widget.library,
        parameters: widget.lance.parameters,
      ),
      open: open != null && open.slot == index ? open.dropdown : null,
      onOpenChanged: (d) => _setOpen(index, d),
      onPreview: (s) =>
          setState(() => _preview = s == null ? null : _withSlot(index, s)),
      onCommit: (s) => _commit(index, s),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final history = widget.history;
    return LanceRosterDetail(
      lance: widget.lance,
      library: widget.library,
      cardWrapper: _wrapCard,
      headerFooter: _BalanceLine(
        current: LanceTotals(widget.lance, widget.library).usedBattleValue,
        preview: preview == null
            ? null
            : LanceTotals(preview, widget.library).usedBattleValue,
        saved: widget.savedBattleValue,
        history: history == null
            ? null
            : (
                undo: history.nextUndo?.label,
                redo: history.nextRedo?.label,
                onUndo: () => _step((h) => h.undo(), true),
                onRedo: () => _step((h) => h.redo(), false),
              ),
      ),
    );
  }
}

/// The Undo and Redo buttons' state: the label of the change each would
/// act on (null when there is none) and what to call.
typedef _HistoryButtons = ({
  String? undo,
  String? redo,
  VoidCallback onUndo,
  VoidCallback onRedo,
});

/// One line under the header's stat boxes, always there so the header
/// keeps its height: the BV a previewed change would give, or else how far
/// the lance has moved from the saved one.
class _BalanceLine extends StatelessWidget {
  const _BalanceLine({
    required this.current,
    this.preview,
    this.saved,
    this.history,
  });

  final int current;
  final int? preview;
  final int? saved;
  final _HistoryButtons? history;

  @override
  Widget build(BuildContext context) {
    final p = preview;
    final s = saved;
    final h = history;
    final (String label, List<InlineSpan> body) = switch ((p, s)) {
      (final int p, _) when p != current => ('PREVIEW', _change(current, p)),
      (_, final int s) when s != current => (
        'VS SAVED LANCE',
        _change(s, current),
      ),
      (_, null) => (
        'BALANCING',
        [const TextSpan(text: 'No saved lance to compare with')],
      ),
      _ => ('VS SAVED LANCE', [const TextSpan(text: 'No changes')]),
    };
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.cellBorder)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: label == 'PREVIEW' ? AppColors.text : AppColors.textDim,
            ),
          ),
          const SizedBox(width: 12),
          // Shrinks rather than overflowing in a narrow column.
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text.rich(
                TextSpan(children: body),
                style: const TextStyle(fontSize: 14, color: AppColors.textDim),
              ),
            ),
          ),
          if (h != null) ...[
            const SizedBox(width: 6),
            _HistoryButton(
              icon: Icons.undo,
              verb: 'Undo',
              label: h.undo,
              onPressed: h.onUndo,
            ),
            _HistoryButton(
              icon: Icons.redo,
              verb: 'Redo',
              label: h.redo,
              onPressed: h.onRedo,
            ),
          ],
        ],
      ),
    );
  }

  static List<InlineSpan> _change(int from, int to) => [
    TextSpan(text: '${groupDigits(from)} → '),
    TextSpan(
      text: groupDigits(to),
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        color: AppColors.text,
      ),
    ),
    TextSpan(
      text: '   ${signedDigits(to - from)} BV',
      style: TextStyle(
        fontWeight: FontWeight.w700,
        color: deltaColor(to - from),
      ),
    ),
  ];
}

class _HistoryButton extends StatelessWidget {
  const _HistoryButton({
    required this.icon,
    required this.verb,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String verb;

  /// The change it would act on; null disables the button.
  final String? label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l = label;
    return IconButton(
      tooltip: l == null ? 'Nothing to ${verb.toLowerCase()}' : '$verb: $l',
      onPressed: l == null ? null : onPressed,
      icon: Icon(icon),
      iconSize: 18,
      color: AppColors.textSecondary,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 32, height: 30),
    );
  }
}
