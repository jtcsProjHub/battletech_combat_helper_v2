import 'package:flutter_test/flutter_test.dart';

import 'package:battletech_combat_helper_v2/bv_rules.dart';
import 'package:battletech_combat_helper_v2/lance.dart';
import 'package:battletech_combat_helper_v2/lance_totals.dart';
import 'package:battletech_combat_helper_v2/mech_data.dart';
import 'package:battletech_combat_helper_v2/mech_library.dart';
import 'package:battletech_combat_helper_v2/pilot_data.dart';

Pilot _skills(int gunnery, int piloting) =>
    Pilot(gunnery: gunnery, piloting: piloting);

void main() {
  test('skill multipliers match the BV Skill Multiplier Table', () {
    // Corners, the standard pilot, and a few cells from each region.
    expect(BvRules.skillMultiplier(_skills(4, 5)), 1.0);
    expect(BvRules.skillMultiplier(_skills(3, 4)), 1.32);
    expect(BvRules.skillMultiplier(_skills(0, 0)), 2.42);
    expect(BvRules.skillMultiplier(_skills(0, 8)), 1.5);
    expect(BvRules.skillMultiplier(_skills(8, 0)), 1.1);
    expect(BvRules.skillMultiplier(_skills(8, 8)), 0.64);
    expect(BvRules.skillMultiplier(_skills(5, 0)), 1.31);
    expect(BvRules.skillMultiplier(_skills(2, 7)), 1.28);
    expect(BvRules.skillMultiplier(_skills(6, 3)), 1.02);
  });

  test('better skills always cost more BV', () {
    for (var g = 0; g <= 8; g++) {
      for (var p = 0; p <= 8; p++) {
        final m = BvRules.skillMultiplier(_skills(g, p));
        if (g < 8) {
          expect(m, greaterThan(BvRules.skillMultiplier(_skills(g + 1, p))));
        }
        if (p < 8) {
          expect(m, greaterThan(BvRules.skillMultiplier(_skills(g, p + 1))));
        }
      }
    }
  });

  test('adjusted BV rounds to the nearest whole number, .5 up', () {
    expect(BvRules.adjustedBattleValue(1335, const Pilot()), 1335);
    expect(BvRules.adjustedBattleValue(1335, _skills(3, 4)), 1762); // 1762.2
    expect(BvRules.adjustedBattleValue(150, _skills(4, 8)), 128); // 127.5
    expect(BvRules.adjustedBattleValue(5, _skills(3, 7)), 6); // 5.5
    expect(BvRules.adjustedBattleValue(1101, _skills(5, 6)), 947); // 946.86
  });

  test('lance totals use each pilot', () {
    final library = MechLibrary(const [
      Mech(
        id: 'tb',
        name: 'Thunderbolt',
        variant: 'TDR-5S',
        tonnage: 65,
        battleValue: 1335,
      ),
      Mech(
        id: 'wv',
        name: 'Wolverine',
        variant: 'WVR-6R',
        tonnage: 55,
        battleValue: 1101,
      ),
    ]);
    final lance = Lance(
      id: 'alpha',
      name: 'Alpha',
      slots: [
        LanceSlot(mechId: 'tb', pilot: _skills(3, 4)),
        const LanceSlot(mechId: 'wv'),
      ],
    );
    expect(LanceTotals(lance, library).usedBattleValue, 1762 + 1101);
  });
}
