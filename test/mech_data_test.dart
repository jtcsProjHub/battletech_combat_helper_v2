import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:battletech_combat_helper_v2/mech_data.dart';

// A mech with every field set to a non-default value.
const fullMech = Mech(
  id: 'hbk-4g',
  name: 'Hunchback',
  model: 'HBK-4G',
  techBase: TechBase.innerSphere,
  tonnage: 50,
  era: 3025,
  role: Role.brawler,
  engineType: 'Fusion',
  walk: 4,
  run: 6,
  jump: 0,
  armorTotal: 160,
  armorByLocation: {'head': 9, 'center_torso': 26},
  structureTotal: 83,
  structureByLocation: {'head': 3, 'center_torso': 16},
  heatSinks: (type: HeatSinkType.single, count: 13),
  maxHeat: 13,
  weapons: [
    Weapon(type: 'AC/20', heat: 7, damage: 20, shortRange: 3, mediumRange: 6, longRange: 9, tons: 14, location: 'RT'),
    Weapon(type: 'Medium Laser', heat: 3, damage: 5, shortRange: 3, mediumRange: 6, longRange: 9, tons: 1, location: 'LA'),
    Weapon(type: 'Small Laser', heat: 1, damage: 3, shortRange: 1, mediumRange: 2, longRange: 3, tons: 0.5, location: 'HD'),
  ],
  equipment: [
    Equipment(name: 'CASE', type: 'CASE', tons: 0.5, criticals: 1, meta: {'location': 'RT'}),
  ],
  battleValue: 1041,
  cost: 3467920,
  notes: 'Classic urban brawler',
  critTable: {'crit_head': ['Life Support', 'Sensors', 'Cockpit']},
  ammo: {'AC/20': 10},
);

Mech minimalMech({double tonnage = 20}) => Mech(id: 'x', name: 'Test', tonnage: tonnage);

Mech roundTrip(Mech m) => Mech.fromJson(jsonDecode(jsonEncode(m.toJson())) as Map<String, dynamic>);

void main() {
  group('JSON round trip', () {
    test('a fully populated mech survives jsonEncode/fromJson unchanged', () {
      expect(roundTrip(fullMech).toJson(), fullMech.toJson());
    });

    test('a minimal mech survives jsonEncode/fromJson unchanged', () {
      expect(roundTrip(minimalMech()).toJson(), minimalMech().toJson());
    });

    test('heat sinks are written as [typeIndex, count]', () {
      expect(fullMech.toJson()['heatSinkTypeAndNumber'], [HeatSinkType.single.index, 13]);
    });

    test('heat sink record keeps value equality after a round trip', () {
      expect(roundTrip(fullMech).heatSinks, (type: HeatSinkType.single, count: 13));
    });
  });

  group('Mech.fromJson defaults', () {
    final parsed = Mech.fromJson({'id': 'x', 'name': 'Test', 'tonnage': 20});

    test('match the constructor defaults when optional keys are missing', () {
      expect(parsed.toJson(), minimalMech().toJson());
    });

    test('use unknown for enums', () {
      expect(parsed.techBase, TechBase.unknown);
      expect(parsed.role, Role.unknown);
      expect(parsed.heatSinks, (type: HeatSinkType.unknown, count: 0));
    });

    test('leave nullable fields null', () {
      expect(parsed.battleValue, isNull);
      expect(parsed.cost, isNull);
      expect(parsed.notes, isNull);
    });

    test('throw when a required field is missing', () {
      expect(() => Mech.fromJson({'name': 'Test', 'tonnage': 20}), throwsA(isA<TypeError>()));
      expect(() => Mech.fromJson({'id': 'x', 'tonnage': 20}), throwsA(isA<TypeError>()));
      expect(() => Mech.fromJson({'id': 'x', 'name': 'Test'}), throwsA(isA<TypeError>()));
    });
  });

  group('Mech.fromJson parsing', () {
    test('converts integer tonnage to double', () {
      final m = Mech.fromJson({'id': 'x', 'name': 'Test', 'tonnage': 70});
      expect(m.tonnage, 70.0);
    });

    test('reads valid enum indexes', () {
      final m = Mech.fromJson({
        'id': 'x', 'name': 'Test', 'tonnage': 20,
        'techBase': 2, 'role': 4, 'heatSinkTypeAndNumber': [2, 10],
      });
      expect(m.techBase, TechBase.clan);
      expect(m.role, Role.missileBoat);
      expect(m.heatSinks, (type: HeatSinkType.dbl, count: 10));
    });

    test('falls back to unknown for out-of-range enum indexes', () {
      final m = Mech.fromJson({
        'id': 'x', 'name': 'Test', 'tonnage': 20,
        'techBase': 99, 'role': -1, 'heatSinkTypeAndNumber': [7, 10],
      });
      expect(m.techBase, TechBase.unknown);
      expect(m.role, Role.unknown);
      // A bad type should not throw away a good count.
      expect(m.heatSinks, (type: HeatSinkType.unknown, count: 10));
    });

    test('falls back to unknown for non-integer enum values', () {
      final m = Mech.fromJson({'id': 'x', 'name': 'Test', 'tonnage': 20, 'techBase': 'clan', 'role': 'scout'});
      expect(m.techBase, TechBase.unknown);
      expect(m.role, Role.unknown);
    });

    test('ignores a heat sink list of the wrong length', () {
      final m = Mech.fromJson({'id': 'x', 'name': 'Test', 'tonnage': 20, 'heatSinkTypeAndNumber': [2]});
      expect(m.heatSinks, (type: HeatSinkType.unknown, count: 0));
    });

    test('converts crit table entries to strings', () {
      final m = Mech.fromJson({
        'id': 'x', 'name': 'Test', 'tonnage': 20,
        'critTable': {'crit_left_arm': ['Shoulder', 1, null]},
      });
      expect(m.critTable!['crit_left_arm'], ['Shoulder', '1', 'null']);
    });

    test('ignores the derived weightClass key', () {
      final m = Mech.fromJson({'id': 'x', 'name': 'Test', 'tonnage': 100, 'weightClass': WeightClass.light.index});
      expect(m.weightClass, WeightClass.assault);
    });
  });

  group('weightClass', () {
    final cases = {
      0.0: WeightClass.unknown,
      -5.0: WeightClass.unknown,
      20.0: WeightClass.light,
      35.0: WeightClass.light,
      35.5: WeightClass.medium,
      40.0: WeightClass.medium,
      55.0: WeightClass.medium,
      60.0: WeightClass.heavy,
      75.0: WeightClass.heavy,
      80.0: WeightClass.assault,
      100.0: WeightClass.assault,
    };
    cases.forEach((tonnage, expected) {
      test('$tonnage tons is $expected', () {
        expect(minimalMech(tonnage: tonnage).weightClass, expected);
      });
    });

    test('weightClassString names each class', () {
      expect(minimalMech(tonnage: 0).weightClassString, 'Unknown');
      expect(minimalMech(tonnage: 20).weightClassString, 'Light');
      expect(minimalMech(tonnage: 50).weightClassString, 'Medium');
      expect(minimalMech(tonnage: 70).weightClassString, 'Heavy');
      expect(minimalMech(tonnage: 100).weightClassString, 'Assault');
    });
  });

  group('heatSinkTypeString', () {
    test('names each heat sink type', () {
      String label(HeatSinkType t) => minimalMech().copyWith(heatSinks: (type: t, count: 10)).heatSinkTypeString;
      expect(label(HeatSinkType.single), 'Single');
      expect(label(HeatSinkType.dbl), 'Double');
      expect(label(HeatSinkType.unknown), 'Unknown');
    });
  });

  group('totals', () {
    test('are zero with no weapons or equipment', () {
      final m = minimalMech();
      expect(m.totalWeaponHeat, 0);
      expect(m.totalWeaponTons, 0.0);
      expect(m.totalEquipmentTons, 0.0);
      expect(m.totalTonsUsed, 0.0);
    });

    test('sum weapon heat and tonnage, including half tons', () {
      expect(fullMech.totalWeaponHeat, 11);
      expect(fullMech.totalWeaponTons, 15.5);
      expect(fullMech.totalEquipmentTons, 0.5);
      expect(fullMech.totalTonsUsed, 16.0);
    });

    test('treat null heat and tons as zero', () {
      final m = minimalMech().copyWith(
        weapons: const [Weapon(type: 'Active Probe'), Weapon(type: 'Medium Laser', heat: 3, tons: 1)],
        equipment: const [Equipment(name: 'Gyro')],
      );
      expect(m.totalWeaponHeat, 3);
      expect(m.totalWeaponTons, 1.0);
      expect(m.totalEquipmentTons, 0.0);
    });

    test('multiply weapon heat and tonnage by quantity', () {
      final m = minimalMech().copyWith(
        weapons: const [
          Weapon(type: 'Medium Laser', heat: 3, tons: 1, quantity: 2),
          Weapon(type: 'Machine Gun', heat: 0, tons: 0.5, quantity: 3),
        ],
      );
      expect(m.totalWeaponHeat, 6);
      expect(m.totalWeaponTons, 3.5);
    });

    test('treat a null quantity as one', () {
      final m = minimalMech().copyWith(
        weapons: const [Weapon(type: 'Medium Laser', heat: 3, tons: 1, quantity: null)],
      );
      expect(m.totalWeaponHeat, 3);
      expect(m.totalWeaponTons, 1.0);
    });
  });

  group('copyWith', () {
    test('with no arguments returns an identical mech', () {
      expect(fullMech.copyWith().toJson(), fullMech.toJson());
    });

    test('changes only the given field', () {
      final changed = fullMech.copyWith(tonnage: 55);
      final expected = fullMech.toJson()
        ..['tonnage'] = 55.0
        ..['weightClass'] = WeightClass.medium.index;
      expect(changed.toJson(), expected);
    });

    test('replaces the heat sink record', () {
      final changed = fullMech.copyWith(heatSinks: (type: HeatSinkType.dbl, count: 10));
      expect(changed.heatSinks, (type: HeatSinkType.dbl, count: 10));
    });

    // Documents current behaviour: passing null means "keep", so a
    // nullable field cannot be cleared through copyWith.
    test('cannot clear a nullable field', () {
      expect(fullMech.copyWith(notes: null).notes, 'Classic urban brawler');
    });
  });

  group('Weapon', () {
    test('round trips through JSON', () {
      const w = Weapon(
        type: 'LRM 10', heat: 4, heatType: 0, damage: 1, damageType: 2,
        minRange: 6, shortRange: 7, mediumRange: 14, longRange: 21,
        tons: 5, location: 'LT', quantity: 2,
      );
      final back = Weapon.fromJson(jsonDecode(jsonEncode(w.toJson())) as Map<String, dynamic>);
      expect(back.toJson(), w.toJson());
    });

    test('applies defaults for missing keys', () {
      final w = Weapon.fromJson({});
      expect(w.type, '');
      expect(w.minRange, 0);
      expect(w.quantity, 1);
      expect(w.heat, isNull);
      expect(w.tons, isNull);
    });

    test('treats explicit null minRange and quantity as defaults', () {
      final w = Weapon.fromJson({'type': 'Active Probe', 'minRange': null, 'quantity': null});
      expect(w.minRange, 0);
      expect(w.quantity, 1);
    });

    test('reads integer and fractional tons as double', () {
      expect(Weapon.fromJson({'type': 'AC/5', 'tons': 8}).tons, 8.0);
      expect(Weapon.fromJson({'type': 'Machine Gun', 'tons': 0.5}).tons, 0.5);
    });
  });

  group('Equipment', () {
    test('round trips through JSON, including nested meta', () {
      const e = Equipment(
        name: 'Jump Jet', type: 'jumpJet', tons: 0.5, criticals: 1,
        meta: {'location': 'LL', 'tags': ['improved'], 'rating': {'mp': 1}},
      );
      final back = Equipment.fromJson(jsonDecode(jsonEncode(e.toJson())) as Map<String, dynamic>);
      expect(back.toJson(), e.toJson());
    });

    test('applies defaults for missing keys', () {
      final e = Equipment.fromJson({'name': 'Gyro'});
      expect(e.type, '');
      expect(e.tons, isNull);
      expect(e.criticals, isNull);
      expect(e.meta, isNull);
    });

    test('reads integer tons as double', () {
      expect(Equipment.fromJson({'name': 'Gyro', 'tons': 3}).tons, 3.0);
    });
  });

  group('mechsFromJsonString', () {
    test('returns an empty list for an empty array', () {
      expect(mechsFromJsonString('[]'), isEmpty);
    });

    test('throws when the top level is not an array', () {
      expect(() => mechsFromJsonString('{"id": "x"}'), throwsA(isA<TypeError>()));
    });

    test('throws on malformed JSON', () {
      expect(() => mechsFromJsonString('[{'), throwsFormatException);
    });

    group('with the sample fixture', () {
      late List<Mech> mechs;

      setUpAll(() {
        mechs = mechsFromJsonString(File('test/fixtures/mechs_sample.json').readAsStringSync());
      });

      test('parses every mech', () {
        expect(mechs.map((m) => m.id), ['koshi_mist_lynx_prime', 'atlas_as7_d']);
      });

      test('has unique ids', () {
        final ids = mechs.map((m) => m.id).toList();
        expect(ids.toSet(), hasLength(ids.length));
      });

      test('reads core fields', () {
        final koshi = mechs.first;
        expect(koshi.techBase, TechBase.clan);
        expect(koshi.role, Role.scout);
        expect(koshi.tonnage, 25.0);
        expect(koshi.weightClass, WeightClass.light);
        expect(koshi.heatSinks, (type: HeatSinkType.dbl, count: 20));
        expect(koshi.armorByLocation['rear_center_torso'], 6);
        expect(koshi.ammo['Streak SRM 4'], 25);
        expect(koshi.critTable!['crit_center_torso'], hasLength(3));
      });

      test('reads weapons, including null and half-ton entries', () {
        final koshi = mechs.first;
        expect(koshi.weapons, hasLength(3));
        expect(koshi.weapons[0].tons, isNull);
        expect(koshi.weapons[1].tons, 0.5);
        expect(koshi.weapons[1].quantity, 2);
        // 2 x 0.5-ton Machine Gun + 3-ton Streak SRM 4.
        expect(koshi.totalWeaponTons, 4.0);
      });

      test('fills defaults for a sparse record', () {
        final atlas = mechs.last;
        expect(atlas.jump, 0);
        expect(atlas.weightClass, WeightClass.assault);
        expect(atlas.weapons.single.quantity, 1);
      });
    });
  });

  group('loaders', () {
    late Directory tempDir;

    setUp(() => tempDir = Directory.systemTemp.createTempSync('mech_data_test'));
    tearDown(() => tempDir.deleteSync(recursive: true));

    test('loadMechsFromFile reads mechs from disk', () async {
      final file = File('${tempDir.path}/mechs.json')
        ..writeAsStringSync(jsonEncode([fullMech.toJson()]));
      final mechs = await loadMechsFromFile(file.path);
      expect(mechs.single.toJson(), fullMech.toJson());
    });

    test('loadMechsFromFile throws when the file is missing', () {
      expect(loadMechsFromFile('${tempDir.path}/missing.json'), throwsA(isA<FileSystemException>()));
    });

    test('loadMechsFromAsset reads mechs from the asset bundle', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final payload = utf8.encode(jsonEncode([fullMech.toJson()]));
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', (_) async => ByteData.sublistView(payload));
      addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', null));

      final mechs = await loadMechsFromAsset('assets/test_mechs.json');
      expect(mechs.single.toJson(), fullMech.toJson());
    });
  });
}
