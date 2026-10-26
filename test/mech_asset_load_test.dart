// File: test/mech_asset_load_test.dart
// In contrast to mech_data_test, which uses synthetic data and tests some additional
// robustness conditions, this test file is focused on loading and parsing actual data.
// It uses the three variants of the first mech from the Force Pack Wave One book (Koshi / Mist Lynx)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:battletech_combat_helper_v2/era.dart';
import 'package:battletech_combat_helper_v2/ammo_rules.dart';
import 'package:battletech_combat_helper_v2/mech_data.dart';
import 'package:battletech_combat_helper_v2/mech_library.dart';
import 'package:battletech_combat_helper_v2/location.dart';

void main() {
  group('chassis variants from sample fixture', () {
    late List<Mech> mechs;

    setUpAll(() {
      mechs = mechsFromJsonString(File('test/fixtures/mech_variant_list_test.json').readAsStringSync());
    });

    test('parses every mech', () {
      expect(mechs.map((m) => m.id), ['koshi_mist_lynx_prime', 'koshi_mist_lynx_a', 'koshi_mist_lynx_b']);
    });

    test('has unique ids', () {
      final ids = mechs.map((m) => m.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('reads basic fields', () {
        final koshiPrime = mechs.first;
        expect(koshiPrime.techBase, TechBase.clan);
        expect(koshiPrime.role, Role.scout);
        expect(koshiPrime.tonnage, 25.0);
        expect(koshiPrime.weightClass, WeightClass.light);
        expect(koshiPrime.heatSinks, (type: HeatSinkType.dbl, count: 10));
        expect(koshiPrime.armorByLocation[Location.rearCenterTorso], 6);
        expect(koshiPrime.ammo['Streak SRM 4'], 25);
        expect(koshiPrime.critTable![Location.centerTorso], hasLength(12));
      });

      test('reads all weapons', () {
        final koshiPrime = mechs.first;
        expect(koshiPrime.weapons, hasLength(4));
        expect(koshiPrime.weapons[0].type, "Active Probe");
        expect(koshiPrime.weapons[0].tons, isNull);
        expect(koshiPrime.weapons[1].type, "Machine Gun");
        expect(koshiPrime.weapons[1].tons, 0.25);
        expect(koshiPrime.weapons[1].quantity, 2);
        expect(koshiPrime.totalWeaponTons, 5.0);
      });

      test('basic ammo testing', () {
        for (final mech in mechs) {
          expect(AmmoRules.ammoWithoutWeapon(mech), isEmpty, reason: mech.id);
        }
      });

      test('all chassis names and tonnage match', () {
        final first = mechs.first;
        for (final mech in mechs) {
          expect(mech.name, first.name, reason: mech.id);
          expect(mech.tonnage, first.tonnage, reason: mech.id);
        }
      });

      test('all variant names do not match', () {
        for (final mech in mechs) {
          expect(mech.variant, isNotEmpty, reason: mech.id);
        }
        final variants = mechs.map((m) => m.variant).toList();
        expect(variants.toSet(), hasLength(variants.length));
      });
  });

  group('full data set', () {
    late MechLibrary library;

    setUpAll(() {
      library = MechLibrary(mechsFromJsonString(File('assets/base_data/mechs_clean.json').readAsStringSync()));
    });

    test('bundled asset loads through the library loader', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final loaded = await loadMechLibrary();
      expect(loaded.mechs, hasLength(library.mechs.length));
    });

    test('every mech has a known intro era and availability', () {
      for (final m in library.mechs) {
        expect(m.era, isNotNull, reason: '${m.id}: ${m.introEra}');
        expect(m.availability, isNotEmpty, reason: m.id);
      }
    });

    test('a mech is available in the era it was introduced in', () {
      for (final m in library.mechs) {
        expect(m.availability.containsKey(m.era), isTrue, reason: m.id);
      }
    });

    test('introducedBy is cumulative and ordered by era', () {
      final early = library.introducedBy(Era.starLeague).length;
      final later = library.introducedBy(Era.clanInvasion).length;
      expect(early, library.introducedIn(Era.ageOfWar).length + library.introducedIn(Era.starLeague).length);
      expect(later, greaterThan(early));
    });

    test('faction lookups agree with each mech\'s availability', () {
      final mechs = library.availableIn(Era.clanInvasion, faction: 'Clan Wolf');
      expect(mechs, isNotEmpty);
      for (final m in mechs) {
        expect(m.availability[Era.clanInvasion], contains('Clan Wolf'));
      }
      expect(library.factions(era: Era.clanInvasion), contains('Clan Wolf'));
      expect(library.availableIn(Era.ageOfWar, faction: 'Clan Wolf'), isEmpty);
    });

    test('json round trip keeps availability', () {
      final m = library.mechs.first;
      expect(Mech.fromJson(m.toJson()).availability, m.availability);
    });
  });
}
