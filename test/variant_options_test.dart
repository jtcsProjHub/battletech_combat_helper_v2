import 'package:flutter_test/flutter_test.dart';

import 'package:battletech_combat_helper_v2/era.dart';
import 'package:battletech_combat_helper_v2/lance.dart';
import 'package:battletech_combat_helper_v2/mech_data.dart';
import 'package:battletech_combat_helper_v2/mech_library.dart';
import 'package:battletech_combat_helper_v2/variant_options.dart';

const _renaissance = Era.lateSuccessionWarRenaissance;

Mech _atlas(
  String variant,
  int bv, {
  List<Weapon> weapons = const [],
  HeatSinkType sinks = HeatSinkType.single,
  Map<Era, List<String>> availability = const {
    _renaissance: ['Federated Suns', 'Draconis Combine'],
  },
  String introEra = 'Star League',
  int introYear = 2755,
}) => Mech(
  id: 'atlas_${variant.toLowerCase()}',
  name: 'Atlas',
  variant: variant,
  tonnage: 100,
  battleValue: bv,
  heatSinks: (type: sinks, count: 20),
  weapons: weapons,
  availability: availability,
  introEra: introEra,
  introYear: introYear,
);

final _d = _atlas(
  'AS7-D',
  1897,
  weapons: const [
    Weapon(type: 'AC/20'),
    Weapon(type: 'Medium Laser', quantity: 4),
  ],
);
final _k = _atlas(
  'AS7-K',
  2175,
  sinks: HeatSinkType.dbl,
  weapons: const [
    Weapon(type: 'Gauss Rifle'),
    Weapon(type: 'Medium Laser', quantity: 2),
    Weapon(type: 'Anti-Missile System'),
  ],
  availability: const {
    Era.clanInvasion: ['Federated Suns'],
  },
  introEra: 'Clan Invasion',
  introYear: 3050,
);
final _a = _atlas(
  'AS7-A',
  1747,
  availability: const {
    _renaissance: ['Draconis Combine'],
  },
);
final _s = _atlas('AS7-S', 2009);
const _locust = Mech(
  id: 'locust_lct_1v',
  name: 'Locust',
  variant: 'LCT-1V',
  tonnage: 20,
);

const _fedSuns3025 = LanceParameters(
  era: _renaissance,
  faction: 'Federated Suns',
);

void main() {
  group('filterMiss', () {
    test('with era and faction, the faction must field it in that era', () {
      expect(_fedSuns3025.filterMiss(_d), isNull);
      expect(_fedSuns3025.filterMiss(_k), FilterMiss.era);
      expect(_fedSuns3025.filterMiss(_a), FilterMiss.faction);
    });

    test('with only an era, any faction fielding it in that era will do', () {
      const p = LanceParameters(era: _renaissance);
      expect(p.filterMiss(_a), isNull);
      expect(p.filterMiss(_k), FilterMiss.era);
    });

    test('with only a faction, any era will do', () {
      const p = LanceParameters(faction: 'Federated Suns');
      expect(p.filterMiss(_k), isNull);
      expect(p.filterMiss(_a), FilterMiss.faction);
    });

    test('with neither, everything fits', () {
      const p = LanceParameters();
      expect(p.filtersAvailability, isFalse);
      expect([_d, _k, _a].map(p.filterMiss), everyElement(isNull));
    });

    test('explains the miss', () {
      expect(
        _fedSuns3025.describeMiss(FilterMiss.era, _k),
        'Era · introduced 3050',
      );
      expect(
        _fedSuns3025.describeMiss(FilterMiss.faction, _a),
        'Faction · not fielded by Federated Suns in this era',
      );
    });
  });

  group('GearDiff', () {
    test('shows changed quantities as the difference, in variant order', () {
      final diff = GearDiff.between(_d, _k);
      expect(diff.removed, const [
        GearChange('AC/20', 1),
        GearChange('Medium Laser', 2),
      ]);
      expect(diff.added, const [
        GearChange('Gauss Rifle', 1),
        GearChange('Anti-Missile System', 1),
      ]);
    });

    test('leaves double heat sinks to the heat sink stat', () {
      expect(gearCounts(_k).keys, isNot(contains('Double Heat Sinks')));
    });

    test('is empty between identical loadouts', () {
      expect(GearDiff.between(_d, _d).isEmpty, isTrue);
    });
  });

  group('variantOptions', () {
    final library = MechLibrary([_d, _k, _a, _s, _locust]);

    test('finds the chassis variants only', () {
      expect(library.variantsOf(_d), [_d, _k, _a, _s]);
      expect(library.variantsOf(_locust), [_locust]);
    });

    test('puts variants that fit first, each part cheapest first', () {
      final options = variantOptions(
        current: _d,
        library: library,
        parameters: _fedSuns3025,
      );
      expect(options.map((o) => o.mech.variant), ['AS7-S', 'AS7-A', 'AS7-K']);
      expect(options.map((o) => o.fitsFilters), [true, false, false]);
    });

    test('sorts by BV alone without filters', () {
      final options = variantOptions(
        current: _d,
        library: library,
        parameters: const LanceParameters(),
      );
      expect(options.map((o) => o.mech.variant), ['AS7-A', 'AS7-S', 'AS7-K']);
    });
  });
}
