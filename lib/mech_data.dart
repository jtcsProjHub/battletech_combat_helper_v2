// File: lib/mech_data.dart
// A compact Dart model for representing a BattleTech 'Mech.

import 'dart:convert';
import 'dart:io' show File;
import 'package:tuple/tuple.dart';

import 'package:flutter/services.dart' show rootBundle;

enum TechBase { innerSphere, clan, mixed, pirate, unknown }
enum MovementType { biped, quad, tracked, wheeled, hover, vtol }

class Mech {
  final String id;
  final String name;
  final String manufacturer;
  final TechBase techBase;
  final double tonnage;
  final int era; // e.g. 3025, 3075
  final MovementType movementType;

  // Movement (in hexes / facing conventions are up to caller)
  final int walk; // hexes
  final int run; // hexes
  final int jump; // hexes (0 if none)

  // Core internals
  final int armorTotal;
  final Map<String, int> armorByLocation; // optional armor by location
  final int structureTotal; // total internal structure points
  final Map<String, int> structureByLocation; // optional structure by location
  final Tuple2<int, int>? heatSinkTypeAndNumber; // (type, number) for heat sinks
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
    this.manufacturer = '',
    this.techBase = TechBase.unknown,
    required this.tonnage,
    this.era = 0,
    this.movementType = MovementType.biped,
    this.walk = 0,
    this.run = 0,
    this.jump = 0,
    this.armorTotal = 0,
    this.armorByLocation = const {},
    this.structureTotal = 0,
    this.structureByLocation = const {},
    this.heatSinkTypeAndNumber = const Tuple2(1, 0),
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
    String? manufacturer,
    TechBase? techBase,
    double? tonnage,
    int? era,
    MovementType? movementType,
    int? walk,
    int? run,
    int? jump,
    int? armorTotal,
    Map<String, int>? armorByLocation,
    int? structureTotal,
    Map<String, int>? structureByLocation,
    Tuple2<int, int>? heatSinkTypeAndNumber, // (type, number) for heat sinks
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
      manufacturer: manufacturer ?? this.manufacturer,
      techBase: techBase ?? this.techBase,
      tonnage: tonnage ?? this.tonnage,
      era: era ?? this.era,
      movementType: movementType ?? this.movementType,
      walk: walk ?? this.walk,
      run: run ?? this.run,
      jump: jump ?? this.jump,
      armorTotal: armorTotal ?? this.armorTotal,
      armorByLocation: armorByLocation ?? this.armorByLocation,
      structureTotal: structureTotal ?? this.structureTotal,
      structureByLocation: structureByLocation ?? this.structureByLocation,
      heatSinkTypeAndNumber: heatSinkTypeAndNumber ?? this.heatSinkTypeAndNumber,
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

  int get totalWeaponHeat => weapons.fold(0, (s, w) => s + (w.heat ?? 0));
  int get totalWeaponTons => weapons.fold(0, (s, w) => s + (w.tons ?? 0));
  int get totalEquipmentTons => equipment.fold(0, (s, e) => s + (e.tons ?? 0));
  int get totalTonsUsed => totalWeaponTons + totalEquipmentTons;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'manufacturer': manufacturer,
        'techBase': techBase.index,
        'tonnage': tonnage,
        'era': era,
        'movementType': movementType.index,
        'walk': walk,
        'run': run,
        'jump': jump,
        'armorTotal': armorTotal,
        'armorByLocation': armorByLocation,
        'structureTotal': structureTotal,
        'structureByLocation': structureByLocation,
        'heatSinkTypeAndNumber': heatSinkTypeAndNumber,
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
        manufacturer: json['manufacturer'] as String? ?? '',
        techBase: TechBase.values[
            (json['techBase'] is int) ? json['techBase'] as int : 0],
        tonnage: (json['tonnage'] as num).toDouble(),
        era: json['era'] as int? ?? 0,
        movementType: MovementType.values[
            (json['movementType'] is int) ? json['movementType'] as int : 0],
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
        heatSinkTypeAndNumber: (json['heatSinkTypeAndNumber'] is List &&
                (json['heatSinkTypeAndNumber'] as List).length == 2)
            ? Tuple2<int, int>(
                (json['heatSinkTypeAndNumber'][0] as num).toInt(),
                (json['heatSinkTypeAndNumber'][1] as num).toInt(),
              )
            : const Tuple2(1, 0),
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
}

class Weapon {
  final String type; // E.g. "AC/5", "LB 10-X", "Medium Laser"
  final int? heat;
  final int? damage; // can be null for complex weapons
  final int? shortRange;
  final int? mediumRange;
  final int? longRange;
  final int? tons;
  final int? criticals;
  final String? location; // head, leftArm, rightTorso, etc.
  final int? quantity; // how many of this weapon are mounted at this location (default 1)

  const Weapon({
    required this.type,
    this.heat,
    this.damage,
    this.shortRange,
    this.mediumRange,
    this.longRange,
    this.tons,
    this.criticals,
    this.location,
    this.quantity = 1,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'heat': heat,
        'damage': damage,
        'shortRange': shortRange,
        'mediumRange': mediumRange,
        'longRange': longRange,
        'tons': tons,
        'criticals': criticals,
        'location': location,
        'quantity': quantity,
      };

  factory Weapon.fromJson(Map<String, dynamic> json) => Weapon(
        type: json['type'] as String? ?? '',
        heat: json['heat'] as int?,
        damage: json['damage'] as int?,
        shortRange: json['shortRange'] as int?,
        mediumRange: json['mediumRange'] as int?,
        longRange: json['longRange'] as int?,
        tons: json['tons'] as int?,
        criticals: json['criticals'] as int?,
        location: json['location'] as String?,
        quantity: json['quantity'] as int? ?? 1,
      );
}

class Equipment {
  final String name;
  final String type; // heatSink, gyro, CASE, AMS, etc.
  final int? tons;
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
        tons: json['tons'] as int?,
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
