// File: lib/mech_labels.dart
// Display names for the mech enums, kept out of the data model.

import 'mech_data.dart';

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
