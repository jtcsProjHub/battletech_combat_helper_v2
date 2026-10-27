// File: lib/lance_draft.dart
// The editable form of a Lance that the builder screen works on. Lance stays
// immutable; the draft swaps in a new Lance on each change and notifies
// listeners. Totals are computed from MechLibrary, never stored.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'lance.dart';
import 'mech_data.dart';
import 'mech_labels.dart';
import 'mech_library.dart';

class LanceDraft extends ChangeNotifier {
  LanceDraft(Lance lance, this.library) : _lance = lance;

  final MechLibrary library;
  Lance _lance;

  Lance get lance => _lance;
  LanceParameters get parameters => _lance.parameters;

  /// The mechs in slot order. Slots whose mech id is unknown are skipped.
  List<Mech> get mechs => [
    for (final slot in _lance.slots)
      if (library.byId(slot.mechId) case final mech?) mech,
  ];

  int get usedBattleValue => mechs.fold(0, (sum, m) => sum + m.bv);
  double get tonnage => mechs.fold(0.0, (sum, m) => sum + m.tonnage);
  int get remainingBattleValue =>
      parameters.targetBattleValue - usedBattleValue;
  bool get isOverBudget => remainingBattleValue < 0;
  int get openSlots => math.max(0, parameters.maxMechs - _lance.slots.length);
  bool get isFull => openSlots == 0;

  /// Average BV left per open slot, or 0 when the lance is full.
  int get battleValuePerOpenSlot =>
      openSlots == 0 ? 0 : math.max(0, remainingBattleValue ~/ openSlots);

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
