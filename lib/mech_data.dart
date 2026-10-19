// File: lib/mech_data.dart
// A compact Dart model for representing a BattleTech 'Mech.

import 'dart:convert';
import 'dart:io' show File;

import 'package:flutter/services.dart' show rootBundle;

enum TechBase { unknown, innerSphere, clan, mixed, pirate }
enum HeatSinkType { unknown, single, dbl }
enum Role { unknown, ambusher, brawler, juggernaut, missileBoat, scout, skirmisher, sniper, striker }
enum WeightClass { unknown, light, medium, heavy, assault }

typedef HeatSinks = ({HeatSinkType type, int count});

// Looks up an enum by its stored index, falling back when missing or out of range.
T _enumFromIndex<T extends Enum>(List<T> values, dynamic raw, T fallback) =>
    (raw is int && raw >= 0 && raw < values.length) ? values[raw] : fallback;

class Mech {
  final String id;
  final String name;
  final String variant;
  final String mulSlug; // key of this variant in the Master Unit List data; the id keeps the datasheet naming
  final TechBase techBase;
  final double tonnage;
  final int introYear; // e.g. 3025, 3075
  final String introEra; // e.g. 'Star League'
  final Role role;
  final String engineType; // optional engine type (e.g. "Fusion", "XL Fusion", etc.)

  // Movement (in hexes / facing conventions are up to caller)
  final int walk; // hexes
  final int run; // hexes
  final int jump; // hexes (0 if none)

  // Core internals
  final int armorTotal;
  final Map<String, int> armorByLocation; // optional armor by location
  final int structureTotal; // total internal structure points
  final Map<String, int> structureByLocation; // optional structure by location
  final HeatSinks heatSinks;
  final int maxHeat; // optional thermal limit (0 if not used)

  // Equipment & weapons
  final List<Weapon> weapons;
  final List<Equipment> equipment;
  final Map<String, int> ammo; // ammo counts by weapon name

  // Crit Tables
  final Map<String, List<String>>? critTable; // critical hit table

  // Optional values
  final int? battleValue;
  final int? cost; // C-bills

  final String? notes;

  const Mech({
    required this.id,
    required this.name,
    this.variant = '',
    this.mulSlug = '',
    this.techBase = TechBase.unknown,
    required this.tonnage,
    this.introYear = 0,
    this.introEra = '',
    this.role = Role.unknown,
    this.engineType = '',
    this.walk = 0,
    this.run = 0,
    this.jump = 0,
    this.armorTotal = 0,
    this.armorByLocation = const {},
    this.structureTotal = 0,
    this.structureByLocation = const {},
    this.heatSinks = (type: HeatSinkType.unknown, count: 0),
    this.maxHeat = 0,
    this.weapons = const [],
    this.equipment = const [],
    this.battleValue,
    this.cost,
    this.notes,
    this.critTable = const {},
    this.ammo = const {},
  });

  Mech copyWith({
    String? id,
    String? name,
    String? variant,
    String? mulSlug,
    String? manufacturer,
    TechBase? techBase,
    double? tonnage,
    int? introYear,
    String? introEra,
    Role? role,
    String? engineType,
    int? walk,
    int? run,
    int? jump,
    int? armorTotal,
    Map<String, int>? armorByLocation,
    int? structureTotal,
    Map<String, int>? structureByLocation,
    HeatSinks? heatSinks,
    int? maxHeat,
    List<Weapon>? weapons,
    List<Equipment>? equipment,
    int? battleValue,
    int? cost,
    String? notes,
    Map<String, List<String>>? critTable,
    Map<String, int>? ammo,
  }) {
    return Mech(
      id: id ?? this.id,
      name: name ?? this.name,
      variant: variant ?? this.variant,
      mulSlug: mulSlug ?? this.mulSlug,
      techBase: techBase ?? this.techBase,
      tonnage: tonnage ?? this.tonnage,
      introYear: introYear ?? this.introYear,
      introEra: introEra ?? this.introEra,
      role: role ?? this.role,
      engineType: engineType ?? this.engineType,
      walk: walk ?? this.walk,
      run: run ?? this.run,
      jump: jump ?? this.jump,
      armorTotal: armorTotal ?? this.armorTotal,
      armorByLocation: armorByLocation ?? this.armorByLocation,
      structureTotal: structureTotal ?? this.structureTotal,
      structureByLocation: structureByLocation ?? this.structureByLocation,
      heatSinks: heatSinks ?? this.heatSinks,
      maxHeat: maxHeat ?? this.maxHeat,
      weapons: weapons ?? this.weapons,
      equipment: equipment ?? this.equipment,
      battleValue: battleValue ?? this.battleValue,
      cost: cost ?? this.cost,
      notes: notes ?? this.notes,
      critTable: critTable ?? this.critTable,
      ammo: ammo ?? this.ammo,
    );
  }

  int get totalWeaponHeat => weapons.fold(0, (s, w) => s + (w.heat ?? 0) * (w.quantity ?? 1));
  double get totalWeaponTons => weapons.fold(0.0, (s, w) => s + (w.tons ?? 0) * (w.quantity ?? 1));
  double get totalEquipmentTons => equipment.fold(0.0, (s, e) => s + (e.tons ?? 0));
  double get totalTonsUsed => totalWeaponTons + totalEquipmentTons;
  WeightClass get weightClass {
    if (tonnage <= 0) return WeightClass.unknown;
    if (tonnage <= 35) return WeightClass.light;
    if (tonnage <= 55) return WeightClass.medium;
    if (tonnage <= 75) return WeightClass.heavy;
    return WeightClass.assault;
  }
  String get weightClassString {
    switch (weightClass) {
      case WeightClass.light:
        return 'Light';
      case WeightClass.medium:
        return 'Medium';
      case WeightClass.heavy:
        return 'Heavy';
      case WeightClass.assault:
        return 'Assault';
      default:
        return 'Unknown';
    }
  }
  String get heatSinkTypeString {
    switch (heatSinks.type) {
      case HeatSinkType.single:
        return 'Single';
      case HeatSinkType.dbl:
        return 'Double';
      default:
        return 'Unknown';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'variant': variant,
        'mulSlug': mulSlug,
        'techBase': techBase.index,
        'tonnage': tonnage,
        'introYear': introYear,
        'introEra': introEra,
        'weightClass': weightClass.index,
        'role': role.index,
        'engineType': engineType,
        'walk': walk,
        'run': run,
        'jump': jump,
        'armorTotal': armorTotal,
        'armorByLocation': armorByLocation,
        'structureTotal': structureTotal,
        'structureByLocation': structureByLocation,
        'heatSinkTypeAndNumber': [heatSinks.type.index, heatSinks.count],
        'maxHeat': maxHeat,
        'weapons': weapons.map((w) => w.toJson()).toList(),
        'equipment': equipment.map((e) => e.toJson()).toList(),
        'battleValue': battleValue,
        'cost': cost,
        'notes': notes,
        'critTable': critTable,
        'ammo': ammo,
      };

  factory Mech.fromJson(Map<String, dynamic> json) => Mech(
        id: json['id'] as String,
        name: json['name'] as String,
        variant: json['variant'] as String? ?? '',
        mulSlug: json['mulSlug'] as String? ?? '',
        techBase: _enumFromIndex(TechBase.values, json['techBase'], TechBase.unknown),
        tonnage: (json['tonnage'] as num).toDouble(),
        introYear: json['introYear'] as int? ?? 0,
        introEra: json['introEra'] as String? ?? '',
        role: _enumFromIndex(Role.values, json['role'], Role.unknown),
        engineType: json['engineType'] as String? ?? '',
        walk: json['walk'] as int? ?? 0,
        run: json['run'] as int? ?? 0,
        jump: json['jump'] as int? ?? 0,
        armorTotal: json['armorTotal'] as int? ?? 0,
        armorByLocation: (json['armorByLocation'] as Map<String, dynamic>?)
                ?.map((key, value) => MapEntry(key, value as int)) ??
            const {},
        structureTotal: json['structureTotal'] as int? ?? 0,
        structureByLocation: (json['structureByLocation'] as Map<String, dynamic>?)
                ?.map((key, value) => MapEntry(key, value as int)) ??
            const {},
        heatSinks: _heatSinksFromJson(json['heatSinkTypeAndNumber']),
        maxHeat: json['maxHeat'] as int? ?? 0,
        weapons: (json['weapons'] as List<dynamic>?)
                ?.map((m) => Weapon.fromJson(m as Map<String, dynamic>))
                .toList() ??
            [],
        equipment: (json['equipment'] as List<dynamic>?)
                ?.map((m) => Equipment.fromJson(m as Map<String, dynamic>))
                .toList() ??
            [],
        battleValue: json['battleValue'] as int?,
        cost: json['cost'] as int?,
        notes: json['notes'] as String?,
        critTable: (json['critTable'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(
            key,
            (value as List<dynamic>).map((e) => e.toString()).toList(),
          ),
        ) ?? const {},
        ammo: (json['ammo'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(key, value as int),
        ) ?? const {}
      );

  // Heat sinks are stored in JSON as [typeIndex, count].
  static HeatSinks _heatSinksFromJson(dynamic value) {
    if (value is List && value.length == 2) {
      return (
        type: _enumFromIndex(HeatSinkType.values, value[0], HeatSinkType.unknown),
        count: (value[1] as num).toInt(),
      );
    }
    return (type: HeatSinkType.unknown, count: 0);
  }
}

class Weapon {
  final String type; // E.g. "AC/5", "LB 10-X", "Medium Laser"
  final int? heat;
  final int? heatType; // 0 = standard, 1 = per shot, 2 = per missile
  final int? damage; // can be 0 for certain weapons
  final int? damageType; // 0 = standard, 1 = per shot, 2 = per missile
  final int? minRange; // minimum range (0 if none)
  final int? shortRange;
  final int? mediumRange;
  final int? longRange;
  final double? tons;
  final String? location; // head, leftArm, rightTorso, etc.
  final int? quantity; // how many of this weapon are mounted at this location (default 1)

  const Weapon({
    required this.type,
    this.heat,
    this.heatType,
    this.damage,
    this.damageType,
    this.minRange = 0,
    this.shortRange,
    this.mediumRange,
    this.longRange,
    this.tons,
    this.location,
    this.quantity = 1,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'heat': heat,
        'heatType': heatType,
        'damage': damage,
        'damageType': damageType,
        'minRange': minRange,
        'shortRange': shortRange,
        'mediumRange': mediumRange,
        'longRange': longRange,
        'tons': tons,
        'location': location,
        'quantity': quantity,
      };

  factory Weapon.fromJson(Map<String, dynamic> json) => Weapon(
        type: json['type'] as String? ?? '',
        heat: json['heat'] as int?,
        heatType: json['heatType'] as int?,
        damage: json['damage'] as int?,
        damageType: json['damageType'] as int?,
        minRange: json['minRange'] as int? ?? 0,
        shortRange: json['shortRange'] as int?,
        mediumRange: json['mediumRange'] as int?,
        longRange: json['longRange'] as int?,
        tons: (json['tons'] as num?)?.toDouble(),
        location: json['location'] as String?,
        quantity: json['quantity'] as int? ?? 1,
      );
}

class Equipment {
  final String name;
  final String type; // heatSink, gyro, CASE, AMS, etc.
  final double? tons;
  final int? criticals;
  final Map<String, dynamic>? meta;

  const Equipment({
    required this.name,
    this.type = '',
    this.tons,
    this.criticals,
    this.meta,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        'tons': tons,
        'criticals': criticals,
        'meta': meta,
      };

  factory Equipment.fromJson(Map<String, dynamic> json) => Equipment(
        name: json['name'] as String,
        type: json['type'] as String? ?? '',
        tons: (json['tons'] as num?)?.toDouble(),
        criticals: json['criticals'] as int?,
        meta: (json['meta'] as Map<String, dynamic>?)?.cast<String, dynamic>(),
      );
}

List<Mech> mechsFromJsonString(String jsonString) {
  final parsed = json.decode(jsonString) as List<dynamic>;
  return parsed
      .map((item) => Mech.fromJson(item as Map<String, dynamic>))
      .toList();
}

Future<List<Mech>> loadMechsFromAsset(String assetPath) async {
  final jsonString = await rootBundle.loadString(assetPath);
  return mechsFromJsonString(jsonString);
}

Future<List<Mech>> loadMechsFromFile(String filePath) async {
  final jsonString = await File(filePath).readAsString();
  return mechsFromJsonString(jsonString);
}
