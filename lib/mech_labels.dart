// File: lib/mech_labels.dart
// Display names and groupings for mech data, kept out of the data model.

import 'mech_data.dart';

/// Thousands separators for display: 2436 -> "2,436".
String groupDigits(int n) {
  final grouped = n.abs().toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return n < 0 ? '-$grouped' : grouped;
}

extension RoleLabel on Role {
  String get label => switch (this) {
    Role.unknown => 'Unknown',
    Role.ambusher => 'Ambusher',
    Role.brawler => 'Brawler',
    Role.juggernaut => 'Juggernaut',
    Role.missileBoat => 'Missile Boat',
    Role.scout => 'Scout',
    Role.skirmisher => 'Skirmisher',
    Role.sniper => 'Sniper',
    Role.striker => 'Striker',
  };
}

extension TechBaseLabel on TechBase {
  String get label => switch (this) {
    TechBase.unknown => 'Unknown',
    TechBase.innerSphere => 'Inner Sphere',
    TechBase.clan => 'Clan',
    TechBase.mixed => 'Mixed',
    TechBase.pirate => 'Pirate',
  };
}

extension MechDisplay on Mech {
  /// Walk / run / jump, e.g. "4/6/0".
  String get moveText => '$walk/$run/$jump';

  /// Heat sinks per turn: double heat sinks dissipate 2 each.
  int get heatDissipation =>
      heatSinks.count * (heatSinks.type == HeatSinkType.dbl ? 2 : 1);

  String get heatSinkShort => switch (heatSinks.type) {
    HeatSinkType.single => 'SHS',
    HeatSinkType.dbl => 'DHS',
    HeatSinkType.unknown => 'HS',
  };

  int get bv => battleValue ?? 0;
}

/// The weapons of one type on a mech: the first entry for display, the total
/// quantity, and every location they mount in, in mount order.
class WeaponGroup {
  const WeaponGroup(this.weapon, this.quantity, this.locations);

  final Weapon weapon;
  final int quantity;
  final List<String> locations;
}

extension WeaponGrouping on Mech {
  /// Weapons grouped by type, in the order each type first appears.
  List<WeaponGroup> get weaponGroups {
    final byType = <String, List<Weapon>>{};
    for (final w in weapons) {
      byType.putIfAbsent(w.type, () => []).add(w);
    }
    return [
      for (final group in byType.values)
        WeaponGroup(
          group.first,
          group.fold(0, (sum, w) => sum + (w.quantity ?? 1)),
          ({for (final w in group) ?w.location}..remove('')).toList(),
        ),
    ];
  }
}
