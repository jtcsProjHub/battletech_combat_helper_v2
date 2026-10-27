// File: lib/lance.dart
// Saved lance precon. Stub: holds the name, the starting parameters set in
// the New Lance form, and the mech slots that the builder fills in later.
// Totals (BV, tonnage) are not stored. Compute them from MechLibrary.

import 'package:uuid/uuid.dart';

import 'era.dart';
import 'mech_data.dart' show TechBase;
import 'pilot_data.dart';

/// Starting limits and filters for a lance. A null filter means "any".
class LanceParameters {
  const LanceParameters({
    this.targetBattleValue = defaultTargetBattleValue,
    this.maxMechs = defaultMaxMechs,
    this.era,
    this.faction,
    this.techBase,
  });

  static const defaultTargetBattleValue = 3000;
  static const defaultMaxMechs = 4;

  final int targetBattleValue;
  final int maxMechs;
  final Era? era;
  final String? faction;
  final TechBase? techBase;

  /// Filters are not settable here, since null means "any" for them.
  LanceParameters copyWith({int? targetBattleValue, int? maxMechs}) =>
      LanceParameters(
        targetBattleValue: targetBattleValue ?? this.targetBattleValue,
        maxMechs: maxMechs ?? this.maxMechs,
        era: era,
        faction: faction,
        techBase: techBase,
      );

  Map<String, dynamic> toJson() => {
    'targetBattleValue': targetBattleValue,
    'maxMechs': maxMechs,
    'era': era?.label,
    'faction': faction,
    'techBase': techBase?.name,
  };

  factory LanceParameters.fromJson(Map<String, dynamic> json) {
    final techBaseName = json['techBase'] as String?;
    return LanceParameters(
      targetBattleValue:
          (json['targetBattleValue'] as num?)?.toInt() ??
          defaultTargetBattleValue,
      maxMechs: (json['maxMechs'] as num?)?.toInt() ?? defaultMaxMechs,
      era: Era.fromLabel(json['era'] as String?),
      faction: json['faction'] as String?,
      techBase: techBaseName == null
          ? null
          : TechBase.values.asNameMap()[techBaseName],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LanceParameters &&
          other.targetBattleValue == targetBattleValue &&
          other.maxMechs == maxMechs &&
          other.era == era &&
          other.faction == faction &&
          other.techBase == techBase;

  @override
  int get hashCode =>
      Object.hash(targetBattleValue, maxMechs, era, faction, techBase);
}

/// One mech in the lance with its pilot. The pilot is a copy, not a link.
class LanceSlot {
  const LanceSlot({required this.mechId, this.pilot = const Pilot()});

  final String mechId;
  final Pilot pilot;

  Map<String, dynamic> toJson() => {'mechId': mechId, 'pilot': pilot.toJson()};

  factory LanceSlot.fromJson(Map<String, dynamic> json) => LanceSlot(
    mechId: json['mechId'] as String,
    pilot: json['pilot'] is Map<String, dynamic>
        ? Pilot.fromJson(json['pilot'] as Map<String, dynamic>)
        : const Pilot(),
  );
}

class Lance {
  Lance({
    required this.id,
    required this.name,
    this.parameters = const LanceParameters(),
    List<LanceSlot> slots = const [],
  }) : slots = List.unmodifiable(slots) {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'A lance must have a name');
    }
  }

  /// New empty lance with a generated id.
  factory Lance.create({
    required String name,
    LanceParameters parameters = const LanceParameters(),
  }) => Lance(id: const Uuid().v4(), name: name.trim(), parameters: parameters);

  final String id;
  final String name;
  final LanceParameters parameters;
  final List<LanceSlot> slots;

  bool get isFull => slots.length >= parameters.maxMechs;

  Lance copyWith({
    String? name,
    LanceParameters? parameters,
    List<LanceSlot>? slots,
  }) => Lance(
    id: id,
    name: name ?? this.name,
    parameters: parameters ?? this.parameters,
    slots: slots ?? this.slots,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'parameters': parameters.toJson(),
    'slots': [for (final s in slots) s.toJson()],
  };

  factory Lance.fromJson(Map<String, dynamic> json) => Lance(
    id: json['id'] as String,
    name: json['name'] as String,
    parameters: json['parameters'] is Map<String, dynamic>
        ? LanceParameters.fromJson(json['parameters'] as Map<String, dynamic>)
        : const LanceParameters(),
    slots: [
      for (final s in (json['slots'] as List<dynamic>? ?? const []))
        LanceSlot.fromJson(s as Map<String, dynamic>),
    ],
  );

  @override
  String toString() => 'Lance($name, ${slots.length}/${parameters.maxMechs})';
}
