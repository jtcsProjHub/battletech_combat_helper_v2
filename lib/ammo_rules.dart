// File: lib/ammo_rules.dart
// Rules for pairing a mech's ammo entries with the weapons that fire them.
// Mirrors the matching in scripts/check_mech_data.py; keep the two in sync.

import 'mech_data.dart';

class AmmoRules {
  const AmmoRules._();

  // Ammo names (loose form) that differ from the name of the weapon that uses them.
  static const Map<String, String> weaponAliases = {
    'ams': 'antimissilesystem',
    'lb5x': 'lb5xac',
    'lb2x': 'lb2xac',
    'lb10x': 'lb10xac',
    'gauss': 'gaussrifle',
  };

  // Ammo for a weapon that can use Artemis or Narc, or LB-X cluster ammo, is listed with a suffix;
  // it is still ammo for that weapon.
  static final RegExp _variantSuffix = RegExp(r'\s*(?:(?:narc|artemis)-capable|\s+cluster)$', caseSensitive: false);

  // Lowercase and strip everything but letters and digits, so 'SRM 6' matches 'SRM6'.
  static String loose(String name) => name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  // The loose name of the weapon that fires this ammo, e.g. 'LB 10-X Cluster' -> 'lb10xac'.
  static String weaponKeyForAmmo(String ammoName) {
    final key = loose(ammoName.replaceFirst(_variantSuffix, ''));
    return weaponAliases[key] ?? key;
  }

  static bool ammoMatchesWeapon(String ammoName, String weaponType) =>
      weaponKeyForAmmo(ammoName) == loose(weaponType);

  // The mech's weapons that can fire this ammo.
  static List<Weapon> weaponsForAmmo(Mech mech, String ammoName) =>
      mech.weapons.where((w) => ammoMatchesWeapon(ammoName, w.type)).toList();

  // The mech's ammo entries that this weapon can fire (e.g. standard and cluster LB-X ammo).
  static List<String> ammoNamesForWeapon(Mech mech, Weapon weapon) =>
      mech.ammo.keys.where((a) => ammoMatchesWeapon(a, weapon.type)).toList();

  // Ammo entries with no matching weapon on the mech; empty when the loadout is consistent.
  static List<String> ammoWithoutWeapon(Mech mech) =>
      mech.ammo.keys.where((a) => weaponsForAmmo(mech, a).isEmpty).toList();
}
