import 'package:flutter_test/flutter_test.dart';

import 'package:battletech_combat_helper_v2/ammo_rules.dart';
import 'package:battletech_combat_helper_v2/mech_data.dart';

void main() {
  group('weaponKeyForAmmo', () {
    test('ignores case, spacing and punctuation', () {
      expect(AmmoRules.weaponKeyForAmmo('SRM 6'), 'srm6');
      expect(AmmoRules.weaponKeyForAmmo('AC/20'), 'ac20');
    });

    test('applies aliases', () {
      expect(AmmoRules.weaponKeyForAmmo('AMS'), 'antimissilesystem');
      expect(AmmoRules.weaponKeyForAmmo('Gauss'), 'gaussrifle');
      expect(AmmoRules.weaponKeyForAmmo('LB 10-X'), 'lb10xac');
    });

    test('strips variant suffixes', () {
      expect(AmmoRules.weaponKeyForAmmo('SRM 6 Artemis-capable'), 'srm6');
      expect(AmmoRules.weaponKeyForAmmo('LRM 10 Narc-capable'), 'lrm10');
      expect(AmmoRules.weaponKeyForAmmo('LB 10-X Cluster'), 'lb10xac');
    });
  });

  group('mech matching', () {
    const mech = Mech(
      id: 'test',
      name: 'Test',
      tonnage: 50,
      weapons: [
        Weapon(type: 'LB 10-X AC'),
        Weapon(type: 'Anti-Missile System'),
        Weapon(type: 'Medium Laser'),
      ],
      ammo: {'LB 10-X': 10, 'LB 10-X Cluster': 10, 'AMS': 12, 'SRM 4': 25},
    );

    test('finds weapons and ammo for each other', () {
      expect(AmmoRules.weaponsForAmmo(mech, 'AMS').single.type, 'Anti-Missile System');
      expect(AmmoRules.ammoNamesForWeapon(mech, mech.weapons[0]), ['LB 10-X', 'LB 10-X Cluster']);
      expect(AmmoRules.ammoNamesForWeapon(mech, mech.weapons[2]), isEmpty);
    });

    test('reports ammo without a weapon', () {
      expect(AmmoRules.ammoWithoutWeapon(mech), ['SRM 4']);
    });
  });
}
