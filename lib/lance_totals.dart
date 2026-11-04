// File: lib/lance_totals.dart
// Totals for a lance, computed from MechLibrary on each read and never stored.
// LanceDraft and the read-only roster views share this so the numbers agree.

import 'dart:math' as math;

import 'bv_rules.dart';
import 'lance.dart';
import 'mech_data.dart';
import 'mech_library.dart';
import 'pilot_data.dart';

class LanceTotals {
  LanceTotals(this.lance, this.library)
    : entries = [
        for (final slot in lance.slots)
          if (library.byId(slot.mechId) case final mech?)
            (mech: mech, pilot: slot.pilot),
      ];

  final Lance lance;
  final MechLibrary library;

  /// Each mech with its pilot, in slot order. Slots whose mech id is unknown
  /// are skipped.
  final List<({Mech mech, Pilot pilot})> entries;

  /// The mechs in slot order. Slots whose mech id is unknown are skipped.
  List<Mech> get mechs => [for (final e in entries) e.mech];

  LanceParameters get parameters => lance.parameters;

  /// Each mech's BV adjusted for its pilot's skills.
  int get usedBattleValue =>
      entries.fold(0, (sum, e) => sum + e.mech.bvWith(e.pilot));
  double get tonnage => mechs.fold(0.0, (sum, m) => sum + m.tonnage);
  int get remainingBattleValue =>
      parameters.targetBattleValue - usedBattleValue;
  bool get isOverBudget => remainingBattleValue < 0;
  int get openSlots => math.max(0, parameters.maxMechs - lance.slots.length);
  bool get isFull => openSlots == 0;

  /// Average BV left per open slot, or 0 when the lance is full.
  int get battleValuePerOpenSlot =>
      openSlots == 0 ? 0 : math.max(0, remainingBattleValue ~/ openSlots);
}
