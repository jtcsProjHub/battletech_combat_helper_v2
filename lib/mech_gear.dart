// File: lib/mech_gear.dart
// The weapons and equipment a mech carries, as plain names, and the filter
// that tests them. The catalog keeps equipment in several places:
//   - weapons: weapon types, plus electronics such as ECM Suite and TAG
//     that the source sheets list with the weapons;
//   - equipment: empty in the current data, read in case it is filled;
//   - critTable: OCR text with truncated entries, so only the known names
//     in [critTableEquipment] are taken from it;
//   - engineType and heat sink type.

import 'mech_data.dart';

/// Equipment names that only show up in the critical hit table. Entries
/// must match exactly.
const critTableEquipment = {
  'CASE',
  'MASC',
  'Artemis IV FCS',
  'Endo Steel',
  'Ferro-Fibrous',
};

/// Names listed with the weapons that are equipment rather than weapons.
const _equipmentInWeapons = {
  'Active Probe',
  'Anti-Missile System',
  'A-Pod',
  'ECM Suite',
  'EW Equipment',
  'Narc',
  'TAG',
  'Targeting Computer',
};

const doubleHeatSinks = 'Double Heat Sinks';

/// Gear names that count as equipment rather than weapons, for grouping.
bool isEquipment(String name, Mech m) =>
    _equipmentInWeapons.contains(name) ||
    critTableEquipment.contains(name) ||
    name == doubleHeatSinks ||
    name == m.engineType ||
    m.equipment.any((e) => e.name == name);

final _gearCache = Expando<Set<String>>('gear');

extension MechGear on Mech {
  /// Every weapon and equipment name on the mech. Cached per mech.
  Set<String> get gear => _gearCache[this] ??= {
    for (final w in weapons)
      if (w.type.trim().isNotEmpty) w.type.trim(),
    for (final e in equipment)
      if (e.name.trim().isNotEmpty) e.name.trim(),
    for (final slots in (critTable ?? const {}).values)
      for (final s in slots)
        if (critTableEquipment.contains(s.trim())) s.trim(),
    if (engineType.trim().isNotEmpty) engineType.trim(),
    if (heatSinks.type == HeatSinkType.dbl) doubleHeatSinks,
  };
}

/// Every gear name in [mechs], split into weapons and equipment, each
/// sorted by name, with how many mechs carry it.
({Map<String, int> weapons, Map<String, int> equipment}) gearCatalog(
  Iterable<Mech> mechs,
) {
  final weapons = <String, int>{};
  final equipment = <String, int>{};
  for (final m in mechs) {
    for (final g in m.gear) {
      final bucket = isEquipment(g, m) ? equipment : weapons;
      bucket[g] = (bucket[g] ?? 0) + 1;
    }
  }
  Map<String, int> sorted(Map<String, int> m) => {
    for (final k in m.keys.toList()..sort()) k: m[k]!,
  };
  return (weapons: sorted(weapons), equipment: sorted(equipment));
}

enum GearMatch {
  all('Has all'),
  any('Has any');

  const GearMatch(this.label);

  final String label;
}

/// Keeps mechs that carry all (or any) of [items].
class GearFilter {
  const GearFilter({this.items = const {}, this.match = GearMatch.all});

  static const none = GearFilter();

  final Set<String> items;
  final GearMatch match;

  bool get isEmpty => items.isEmpty;

  bool matches(Mech m) {
    if (items.isEmpty) return true;
    final gear = m.gear;
    return match == GearMatch.all
        ? items.every(gear.contains)
        : items.any(gear.contains);
  }

  /// "Has all: ECM Suite, LRM 20".
  String describe() => '${match.label}: ${(items.toList()..sort()).join(', ')}';
}
