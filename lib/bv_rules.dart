// File: lib/bv_rules.dart
// Battle Value adjustments from docs/100_TechManual-Battle-Value-v4.1.pdf.
// A mech's listed BV assumes Gunnery 4 / Piloting 5; other skills multiply it
// (BV Skill Multiplier Table, last page). Force-level adjustments that come
// before skill (TAG, C3) are not handled yet.

import 'mech_data.dart';
import 'mech_labels.dart';
import 'pilot_data.dart';

class BvRules {
  const BvRules._();

  /// BV Skill Multiplier Table in hundredths, indexed [gunnery][piloting].
  static const List<List<int>> _skillMultiplier = [
    [242, 231, 221, 210, 193, 175, 168, 159, 150],
    [221, 211, 202, 192, 176, 160, 154, 146, 138],
    [193, 185, 176, 168, 154, 140, 135, 128, 121],
    [166, 158, 151, 144, 132, 120, 116, 110, 104],
    [138, 132, 126, 120, 110, 100, 95, 90, 85],
    [131, 119, 113, 108, 99, 90, 86, 81, 77],
    [124, 112, 107, 102, 94, 85, 81, 77, 72],
    [117, 106, 101, 96, 88, 80, 76, 72, 68],
    [110, 99, 95, 90, 83, 75, 71, 68, 64],
  ];

  static int _hundredths(Pilot pilot) =>
      _skillMultiplier[pilot.gunnery][pilot.piloting];

  /// The multiplier for [pilot]'s skills, e.g. 1.32 for Gunnery 3 /
  /// Piloting 4.
  static double skillMultiplier(Pilot pilot) => _hundredths(pilot) / 100;

  /// [baseBattleValue] for a unit with [pilot], rounded to the nearest whole
  /// number with .5 rounding up. Integer math, so no float rounding errors.
  static int adjustedBattleValue(int baseBattleValue, Pilot pilot) =>
      (baseBattleValue * _hundredths(pilot) + 50) ~/ 100;
}

extension PilotedBattleValue on Mech {
  /// This mech's BV with [pilot] at the controls.
  int bvWith(Pilot pilot) => BvRules.adjustedBattleValue(bv, pilot);
}
