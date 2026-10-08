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
    this.gunnery = 4,
    this.piloting = 5,
  });

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
        gunnery: (json['gunnery'] as num?)?.toInt() ?? 4,
        piloting: (json['piloting'] as num?)?.toInt() ?? 5,
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
