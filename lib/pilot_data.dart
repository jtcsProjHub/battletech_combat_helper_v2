// lib/pilot_data.dart
//
// Static pilot data. Entered manually in the Lance Builder (defaulting to the
// pilot on the Force Pack card) and embedded as a copy in each LanceSlot.
//
// Dynamic in-game data (hits taken, consciousness #) lives with the in-game
// unit class, not here.

class Pilot {
  final String name;
  final int gunnery;
  final int piloting;

  const Pilot({
    this.name = '',
    this.gunnery = defaultGunnery,
    this.piloting = defaultPiloting,
  });

  /// Classic BattleTech's standard pilot.
  static const defaultGunnery = 4;
  static const defaultPiloting = 5;

  /// Skills run from 0 (best) to 8.
  static const minSkill = 0;
  static const maxSkill = 8;

  /// An unnamed pilot with the standard skills, which means no pilot has
  /// been assigned. The mech still plays at the standard skills.
  bool get isDefault => this == const Pilot();

  Pilot copyWith({String? name, int? gunnery, int? piloting}) => Pilot(
    name: name ?? this.name,
    gunnery: gunnery ?? this.gunnery,
    piloting: piloting ?? this.piloting,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'gunnery': gunnery,
    'piloting': piloting,
  };

  factory Pilot.fromJson(Map<String, dynamic> json) => Pilot(
    name: json['name'] as String? ?? '',
    gunnery: (json['gunnery'] as num?)?.toInt() ?? defaultGunnery,
    piloting: (json['piloting'] as num?)?.toInt() ?? defaultPiloting,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Pilot &&
          other.name == name &&
          other.gunnery == gunnery &&
          other.piloting == piloting;

  @override
  int get hashCode => Object.hash(name, gunnery, piloting);

  @override
  String toString() => 'Pilot($name, G$gunnery/P$piloting)';
}
