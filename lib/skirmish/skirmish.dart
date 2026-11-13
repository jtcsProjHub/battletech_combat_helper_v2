// File: lib/skirmish/skirmish.dart
// Game state for one skirmish: its name, the two players with their lances,
// the map, the turn, and the game log. Unlike the precon classes this state
// is mutable, because play changes it constantly. Screens change a field
// and then call setState (and save through the repository).
//
// The lances and the map are copies taken when they are picked, so later
// edits to a precon or a saved map never change a game in progress. While
// the skirmish is still in setup, a copy is refreshed from its precon when
// the skirmish is loaded (see Skirmish.refreshFromSources).

import 'package:uuid/uuid.dart';

import '../lance.dart';
import '../location.dart';
import '../maps/map_repository.dart';
import '../mech_library.dart';
import '../pilot_data.dart';
import 'skirmish_map.dart';

/// Where a skirmish is in its life.
enum SkirmishPhase {
  /// Lances and map are still being picked. Nothing is locked in.
  setup,

  /// Confirmed. The units are initialized and play has started.
  active,
}

/// The setup steps, in order.
enum SetupStep {
  player1('Player 1', 'Player 1 Lance'),
  player2('Player 2', 'Player 2 Lance'),
  map('Map', 'Map Selection'),
  overview('Review', 'Review and Confirm');

  const SetupStep(this.shortLabel, this.title);

  /// Label for the step chips in the top bar.
  final String shortLabel;

  /// Full name of the step, shown above the skirmish name.
  final String title;
}

/// In-game state of one mech. Built from a lance slot when the skirmish is
/// confirmed, then changed by play. Only the basics for now; movement mode,
/// terrain modifiers, criticals, and ammo come with the game engine.
class SkirmishUnit {
  SkirmishUnit({
    required this.mechId,
    required this.pilot,
    required Map<Location, int> armor,
    required Map<Location, int> structure,
    this.heat = 0,
    this.pilotHits = 0,
    this.destroyed = false,
  }) : armor = Map.of(armor),
       structure = Map.of(structure);

  /// Starts at full armor and structure from the catalog. Returns null when
  /// the mech id is not in the catalog.
  static SkirmishUnit? fromSlot(LanceSlot slot, MechLibrary library) {
    final mech = library.byId(slot.mechId);
    if (mech == null) return null;
    return SkirmishUnit(
      mechId: mech.id,
      pilot: slot.pilot,
      armor: mech.armorByLocation,
      structure: mech.structureByLocation,
    );
  }

  final String mechId;
  final Pilot pilot;

  /// Armor points left per location, rear torso locations included.
  final Map<Location, int> armor;

  /// Internal structure points left per location.
  final Map<Location, int> structure;

  int heat;
  int pilotHits;
  bool destroyed;

  int get armorLeft => armor.values.fold(0, (a, b) => a + b);
  int get structureLeft => structure.values.fold(0, (a, b) => a + b);

  Map<String, dynamic> toJson() => {
    'mechId': mechId,
    'pilot': pilot.toJson(),
    'armor': _locationsToJson(armor),
    'structure': _locationsToJson(structure),
    'heat': heat,
    'pilotHits': pilotHits,
    'destroyed': destroyed,
  };

  factory SkirmishUnit.fromJson(Map<String, dynamic> json) => SkirmishUnit(
    mechId: json['mechId'] as String,
    pilot: json['pilot'] is Map<String, dynamic>
        ? Pilot.fromJson(json['pilot'] as Map<String, dynamic>)
        : const Pilot(),
    armor: _locationsFromJson(json['armor']),
    structure: _locationsFromJson(json['structure']),
    heat: (json['heat'] as num?)?.toInt() ?? 0,
    pilotHits: (json['pilotHits'] as num?)?.toInt() ?? 0,
    destroyed: json['destroyed'] as bool? ?? false,
  );
}

Map<String, int> _locationsToJson(Map<Location, int> m) => {
  for (final e in m.entries) e.key.jsonKey: e.value,
};

Map<Location, int> _locationsFromJson(Object? json) {
  if (json is! Map) return {};
  return {
    for (final e in json.entries)
      if (Location.fromJsonKey(e.key as String?) case final loc
          when loc != Location.invalid)
        loc: (e.value as num).toInt(),
  };
}

/// One side of the skirmish: its lance and, once confirmed, its units.
class SkirmishPlayer {
  SkirmishPlayer({this.lance, List<SkirmishUnit>? units}) : units = units ?? [];

  /// Copy of the chosen precon. Its id is the precon's id.
  Lance? lance;

  /// One per mech in [lance], in slot order. Empty until confirmed.
  final List<SkirmishUnit> units;

  Map<String, dynamic> toJson() => {
    'lance': lance?.toJson(),
    'units': [for (final u in units) u.toJson()],
  };

  factory SkirmishPlayer.fromJson(Map<String, dynamic> json) => SkirmishPlayer(
    lance: json['lance'] is Map<String, dynamic>
        ? Lance.fromJson(json['lance'] as Map<String, dynamic>)
        : null,
    units: [
      for (final u in (json['units'] as List<dynamic>? ?? const []))
        SkirmishUnit.fromJson(u as Map<String, dynamic>),
    ],
  );
}

class Skirmish {
  Skirmish({
    required this.id,
    required this.name,
    required this.createdAt,
    DateTime? updatedAt,
    this.phase = SkirmishPhase.setup,
    this.step = SetupStep.player1,
    SkirmishPlayer? player1,
    SkirmishPlayer? player2,
    this.map,
    this.turn = 0,
    List<String>? log,
  }) : updatedAt = updatedAt ?? createdAt,
       player1 = player1 ?? SkirmishPlayer(),
       player2 = player2 ?? SkirmishPlayer(),
       log = log ?? [];

  /// A new skirmish in setup, named after the time it was started.
  factory Skirmish.create({DateTime? now}) {
    final time = now ?? DateTime.now();
    return Skirmish(
      id: const Uuid().v4(),
      name: defaultName(time),
      createdAt: time,
    );
  }

  static const formatName = 'btskirmish';
  static const formatVersion = 1;

  /// "Skirmish 2026-11-12 19:05".
  static String defaultName(DateTime time) =>
      'Skirmish ${formatDateTime(time)}';

  final String id;
  String name;
  final DateTime createdAt;

  /// Set by the repository on each save.
  DateTime updatedAt;

  SkirmishPhase phase;

  /// The setup step to show when the skirmish is opened. Kept after
  /// confirmation but no longer used.
  SetupStep step;

  final SkirmishPlayer player1;
  final SkirmishPlayer player2;

  /// The chosen map sheet with this skirmish's overlay (placed buildings,
  /// changed terrain). Picking a different sheet starts a fresh overlay.
  SkirmishMap? map;

  /// 0 during setup, 1 from confirmation on.
  int turn;

  /// Plain-text events, oldest first.
  final List<String> log;

  bool get isActive => phase == SkirmishPhase.active;

  SkirmishPlayer player(int index) => index == 0 ? player1 : player2;

  /// True when the step's choice has been made. The overview has no choice
  /// of its own.
  bool isStepComplete(SetupStep s) => switch (s) {
    SetupStep.player1 => player1.lance != null,
    SetupStep.player2 => player2.lance != null,
    SetupStep.map => map != null,
    SetupStep.overview => canConfirm,
  };

  /// A step can be opened once every step before it is complete.
  bool isStepReachable(SetupStep s) =>
      SetupStep.values.take(s.index).every(isStepComplete);

  bool get canConfirm =>
      player1.lance != null && player2.lance != null && map != null;

  /// True once anything worth keeping has been picked.
  bool get hasSelections =>
      player1.lance != null || player2.lance != null || map != null;

  /// Locks in the setup: builds each player's units from their lance and
  /// starts turn 1. Mechs missing from the catalog are skipped.
  void confirm(MechLibrary library) {
    if (!canConfirm) {
      throw StateError('Both lances and the map must be chosen first');
    }
    if (isActive) return;
    for (final p in [player1, player2]) {
      p.units
        ..clear()
        ..addAll([
          for (final slot in p.lance!.slots)
            ?SkirmishUnit.fromSlot(slot, library),
        ]);
    }
    map!.lockIn();
    phase = SkirmishPhase.active;
    turn = 1;
    log.add(
      'Skirmish started: ${player1.lance!.name} vs ${player2.lance!.name} '
      'on ${map!.name}.',
    );
  }

  /// During setup, replaces each lance and map copy with the current saved
  /// version, so edits made in the builders since the last session show
  /// up. Copies whose source was deleted are kept. Does nothing once
  /// active. Returns true when any copy was replaced.
  bool refreshFromSources({
    required List<Lance> lances,
    required List<SavedMap> maps,
  }) {
    if (isActive) return false;
    var changed = false;
    for (final p in [player1, player2]) {
      final current = p.lance;
      if (current == null) continue;
      final latest = lances.where((l) => l.id == current.id).firstOrNull;
      if (latest != null && !identical(latest, current)) {
        p.lance = latest;
        changed = true;
      }
    }
    final m = map;
    if (m != null) {
      final latest = maps.where((s) => s.id == m.id).firstOrNull;
      if (latest != null && !identical(latest, m.source)) {
        m.source = latest; // The overlay stays.
        changed = true;
      }
    }
    return changed;
  }

  Map<String, dynamic> toJson() => {
    'format': formatName,
    'version': formatVersion,
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'phase': phase.name,
    'step': step.name,
    'player1': player1.toJson(),
    'player2': player2.toJson(),
    if (map case final m?) 'map': m.toJson(),
    'turn': turn,
    'log': log,
  };

  factory Skirmish.fromJson(Map<String, dynamic> json) {
    final created =
        DateTime.tryParse(json['createdAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final mapJson = json['map'];
    return Skirmish(
      id: json['id'] as String,
      name: json['name'] as String? ?? defaultName(created),
      createdAt: created,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      phase:
          SkirmishPhase.values.asNameMap()[json['phase']] ??
          SkirmishPhase.setup,
      step: SetupStep.values.asNameMap()[json['step']] ?? SetupStep.player1,
      player1: _playerFromJson(json['player1']),
      player2: _playerFromJson(json['player2']),
      map: mapJson is Map
          ? SkirmishMap.fromJson(mapJson.cast<String, Object?>())
          : null,
      turn: (json['turn'] as num?)?.toInt() ?? 0,
      log: [for (final e in (json['log'] as List<dynamic>? ?? const [])) '$e'],
    );
  }

  static SkirmishPlayer _playerFromJson(Object? json) =>
      json is Map<String, dynamic>
      ? SkirmishPlayer.fromJson(json)
      : SkirmishPlayer();

  @override
  String toString() => 'Skirmish($name, ${phase.name})';
}

/// "2026-11-12 19:05" in local time.
String formatDateTime(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  final l = t.toLocal();
  return '${l.year}-${two(l.month)}-${two(l.day)} '
      '${two(l.hour)}:${two(l.minute)}';
}
