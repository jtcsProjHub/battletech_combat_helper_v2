// File: lib/lance_draft.dart
// The editable form of a Lance that the builder screen works on. Lance stays
// immutable; the draft swaps in a new Lance on each change and notifies
// listeners. Totals come from LanceTotals and are never stored.

import 'package:flutter/foundation.dart';

import 'lance.dart';
import 'lance_totals.dart';
import 'mech_data.dart';
import 'mech_library.dart';
import 'pilot_data.dart';

class LanceDraft extends ChangeNotifier {
  LanceDraft(Lance lance, this.library) : _lance = lance;

  final MechLibrary library;
  Lance _lance;

  Lance get lance => _lance;
  LanceParameters get parameters => _lance.parameters;

  /// Recomputed on each read; the lance changes on every edit.
  LanceTotals get totals => LanceTotals(_lance, library);

  /// The mechs in slot order. Slots whose mech id is unknown are skipped.
  List<Mech> get mechs => totals.mechs;

  int get usedBattleValue => totals.usedBattleValue;
  double get tonnage => totals.tonnage;
  int get remainingBattleValue => totals.remainingBattleValue;
  bool get isOverBudget => totals.isOverBudget;
  int get openSlots => totals.openSlots;
  bool get isFull => totals.isFull;

  /// Average BV left per open slot, or 0 when the lance is full.
  int get battleValuePerOpenSlot => totals.battleValuePerOpenSlot;

  bool contains(String mechId) =>
      _lance.slots.any((slot) => slot.mechId == mechId);

  /// One copy of each variant per lance for now.
  bool canAdd(Mech mech) => !isFull && !contains(mech.id);

  void add(Mech mech) {
    if (!canAdd(mech)) return;
    _lance = _lance.copyWith(
      slots: [
        ..._lance.slots,
        LanceSlot(mechId: mech.id),
      ],
    );
    notifyListeners();
  }

  void remove(String mechId) {
    if (!contains(mechId)) return;
    _lance = _lance.copyWith(
      slots: _lance.slots.where((slot) => slot.mechId != mechId).toList(),
    );
    notifyListeners();
  }

  /// Replaces the pilot of the slot holding [mechId].
  void setPilot(String mechId, Pilot pilot) {
    if (!contains(mechId)) return;
    _lance = _lance.copyWith(
      slots: [
        for (final slot in _lance.slots)
          slot.mechId == mechId
              ? LanceSlot(mechId: mechId, pilot: pilot)
              : slot,
      ],
    );
    notifyListeners();
  }

  /// Ignores values of 0 or less.
  void setTargetBattleValue(int value) {
    if (value <= 0 || value == parameters.targetBattleValue) return;
    _lance = _lance.copyWith(
      parameters: parameters.copyWith(targetBattleValue: value),
    );
    notifyListeners();
  }

  Lance toLance() => _lance;
}
