// lib/pilot_data.dart

import 'dart:convert';
import 'package:uuid/uuid.dart';

class Pilot {
  // Immutable identifier
  final String id;

  // Basic identity
  String name;
  String callsign;
  String faction;
  String rank;
  int age;
  String notes;

  // Experience and status
  int experiencePoints;
  bool retired;
  bool incapacitated;

  // Flexible skill map (e.g. "Gunnery", "Piloting", "Tactics", "Brawling", etc.)
  final Map<String, int> skills;

  // Optional specializations (e.g. "AC/20", "Light Mechs", "Jump Jets")
  final List<String> specializations;

  Pilot({
    String? id,
    required this.name,
    this.callsign = '',
    this.faction = '',
    this.rank = '',
    this.age = 0,
    this.notes = '',
    this.experiencePoints = 0,
    this.retired = false,
    this.incapacitated = false,
    Map<String, int>? skills,
    List<String>? specializations,
  })  : id = id ?? Uuid().v4(),
        skills = Map<String, int>.from(skills ?? const {}),
        specializations = List<String>.from(specializations ?? const []);

  // Convenience getters for common Battletech RPG skills
  int get gunnery => skills['Gunnery'] ?? 0;
  int get piloting => skills['Piloting'] ?? 0;

  // Set or update a skill value (non-negative). Returns new value.
  int setSkill(String name, int value) {
    if (value < 0) throw ArgumentError.value(value, 'value', 'Skill values must be non-negative');
    skills[name] = value;
    return value;
  }

  // Increment a skill by delta (can be negative). Returns new value.
  int modifySkill(String name, int delta) {
    final current = skills[name] ?? 0;
    final updated = (current + delta).clamp(0, 100).toInt();
    skills[name] = updated;
    return updated;
  }

  // Add experience points
  void gainExperience(int xp) {
    if (xp <= 0) return;
    experiencePoints += xp;
  }

  // Quick summary string
  @override
  String toString() {
    return 'Pilot(id: $id, name: $name, callsign: $callsign, rank: $rank, faction: $faction, gunnery: $gunnery, piloting: $piloting)';
  }

  // JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'callsign': callsign,
      'faction': faction,
      'rank': rank,
      'age': age,
      'notes': notes,
      'experiencePoints': experiencePoints,
      'retired': retired,
      'incapacitated': incapacitated,
      'skills': skills,
      'specializations': specializations,
    };
  }

  factory Pilot.fromJson(Map<String, dynamic> json) {
    return Pilot(
      id: json['id'] as String?,
      name: json['name'] as String? ?? '',
      callsign: json['callsign'] as String? ?? '',
      faction: json['faction'] as String? ?? '',
      rank: json['rank'] as String? ?? '',
      age: json['age'] as int? ?? 0,
      notes: json['notes'] as String? ?? '',
      experiencePoints: json['experiencePoints'] as int? ?? 0,
      retired: json['retired'] as bool? ?? false,
      incapacitated: json['incapacitated'] as bool? ?? false,
      skills: (json['skills'] as Map?)?.map((k, v) => MapEntry(k as String, (v as num).toInt())) ?? {},
      specializations: (json['specializations'] as List?)?.cast<String>() ?? [],
    );
  }

  // Convenience: encode to json string
  String toJsonString() => jsonEncode(toJson());

  // Convenience: create from json string
  factory Pilot.fromJsonString(String jsonString) => Pilot.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);

  // Copy-with style
  Pilot copyWith({
    String? name,
    String? callsign,
    String? faction,
    String? rank,
    int? age,
    String? notes,
    int? experiencePoints,
    bool? retired,
    bool? incapacitated,
    Map<String, int>? skills,
    List<String>? specializations,
  }) {
    return Pilot(
      id: id,
      name: name ?? this.name,
      callsign: callsign ?? this.callsign,
      faction: faction ?? this.faction,
      rank: rank ?? this.rank,
      age: age ?? this.age,
      notes: notes ?? this.notes,
      experiencePoints: experiencePoints ?? this.experiencePoints,
      retired: retired ?? this.retired,
      incapacitated: incapacitated ?? this.incapacitated,
      skills: skills ?? Map<String, int>.from(this.skills),
      specializations: specializations ?? List<String>.from(this.specializations),
    );
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is Pilot && other.id == id;

  @override
  int get hashCode => id.hashCode;
}