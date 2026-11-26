// File: lib/skirmish/skirmish_map.dart
// The map for one skirmish: a copy of the printed sheet plus a per-hex
// overlay of the changes players make at the table. The printed sheet is
// never changed; the terrain used in play is the two merged.
//
// Merge rules, per hex:
//   - Environment: an override replaces the printed woods, water, and
//     features. It never touches the level.
//   - Level: an override is an absolute level ("this hex is level 1 for
//     this skirmish"), set apart from the environment. Both overrides
//     combine on the same hex.
//   - Building: a placed building wins over everything. The hex plays as
//     an empty level 0 hex holding the building, which matches a model
//     building set on the physical board. Each building has a height in
//     levels above that ground, set per hex. Buildings are indestructible
//     for now; durability (CF, Total War p. 165) comes later.
// During setup each layer is stored on its own, so removing a building
// brings back the environment and level underneath it. Confirming the
// skirmish locks the overlay in (see lockIn): from then on the ground
// under a building is empty level 0, which is what a destroyed building
// will leave behind.

import 'package:map_extractor_prototype/map_extractor.dart';

import '../maps/map_repository.dart';

/// The overlay for one hex. Each layer is independent.
class HexOverlay {
  const HexOverlay({this.environment, this.buildingHeight, this.level})
    : assert(buildingHeight == null || buildingHeight > 0);

  static const none = HexOverlay();

  /// Replaces the printed woods, water, and features. Its level is ignored
  /// and stored as 0.
  final HexTerrain? environment;

  /// Height in levels of a building placed on the hex. Null means no
  /// building.
  final int? buildingHeight;

  /// True when a building stands on the hex.
  bool get building => buildingHeight != null;

  /// Replaces the printed level. Null keeps the printed level.
  final int? level;

  bool get isEmpty =>
      environment == null && buildingHeight == null && level == null;

  static const _buildingHex = HexTerrain(features: {TerrainFeature.building});

  /// The printed terrain with this overlay applied.
  HexTerrain applyTo(HexTerrain printed) {
    if (building) return _buildingHex;
    return (environment ?? printed).copyWith(level: level ?? printed.level);
  }

  HexOverlay copyWith({
    HexTerrain? Function()? environment,
    int? Function()? buildingHeight,
    int? Function()? level,
  }) => HexOverlay(
    environment: environment == null ? this.environment : environment(),
    buildingHeight: buildingHeight == null
        ? this.buildingHeight
        : buildingHeight(),
    level: level == null ? this.level : level(),
  );

  Map<String, Object?> toJson() => {
    if (environment case final e?) 'environment': e.toJson(),
    'building': ?buildingHeight,
    'level': ?level,
  };

  factory HexOverlay.fromJson(Map<String, Object?> json) => HexOverlay(
    environment: json['environment'] is Map
        ? HexTerrain.fromJson(
            (json['environment'] as Map).cast<String, Object?>(),
          )
        : null,
    // Older saves stored `true` before buildings had a height.
    buildingHeight: switch (json['building']) {
      true => SkirmishMap.defaultBuildingHeight,
      final num h when h > 0 => h.toInt(),
      _ => null,
    },
    level: (json['level'] as num?)?.toInt(),
  );

  @override
  bool operator ==(Object other) =>
      other is HexOverlay &&
      other.environment == environment &&
      other.buildingHeight == buildingHeight &&
      other.level == level;

  @override
  int get hashCode => Object.hash(environment, buildingHeight, level);
}

class SkirmishMap {
  SkirmishMap(this.source, [Map<HexCoord, HexOverlay> overlay = const {}])
    : _overlay = {
        for (final e in overlay.entries)
          if (!e.value.isEmpty) e.key: e.value,
      };

  /// Copy of the saved map sheet as printed.
  SavedMap source;

  final Map<HexCoord, HexOverlay> _overlay;

  String get id => source.id;
  String get name => source.name;
  GridSpec get grid => source.sheet.grid;

  Map<HexCoord, HexOverlay> get overlay => Map.unmodifiable(_overlay);

  HexOverlay overlayAt(HexCoord hex) => _overlay[hex] ?? HexOverlay.none;

  /// The terrain used in play: printed terrain with the overlay applied.
  HexTerrain terrainAt(HexCoord hex) =>
      overlayAt(hex).applyTo(source.sheet.terrainAt(hex));

  /// The merged terrain as a sheet, for drawing. Keeps the printed name,
  /// grid, and review flags.
  MapSheet get merged {
    final sheet = source.sheet;
    if (_overlay.isEmpty) return sheet;
    return MapSheet(
      name: sheet.name,
      grid: sheet.grid,
      hexes: {
        ...sheet.hexes,
        for (final hex in _overlay.keys) hex: terrainAt(hex),
      },
      unverified: sheet.unverified,
    );
  }

  /// [merged] under the source id, for widgets that take a SavedMap.
  SavedMap get mergedSaved => SavedMap(id: source.id, sheet: merged);

  void _update(
    Iterable<HexCoord> hexes,
    HexOverlay Function(HexOverlay overlay, HexTerrain printed) f,
  ) {
    for (final hex in hexes) {
      if (!hex.isInside(grid.columns, grid.rows)) continue;
      final next = f(overlayAt(hex), source.sheet.terrainAt(hex));
      if (next.isEmpty) {
        _overlay.remove(hex);
      } else {
        _overlay[hex] = next;
      }
    }
  }

  /// Overrides the environment; [environment]'s level is ignored. Null
  /// goes back to the printed environment.
  void setEnvironment(Iterable<HexCoord> hexes, HexTerrain? environment) =>
      _update(
        hexes,
        (o, _) =>
            o.copyWith(environment: () => environment?.copyWith(level: 0)),
      );

  /// Height given to a newly placed building.
  static const defaultBuildingHeight = 1;

  /// Places or removes a building. A placed building keeps its height if
  /// the hex already has one, and otherwise gets [defaultBuildingHeight].
  void setBuilding(Iterable<HexCoord> hexes, bool building) => _update(
    hexes,
    (o, _) => o.copyWith(
      buildingHeight: () =>
          building ? (o.buildingHeight ?? defaultBuildingHeight) : null,
    ),
  );

  /// Sets the height of the buildings among [hexes]. Hexes without a
  /// building are left alone.
  void setBuildingHeight(Iterable<HexCoord> hexes, int height) {
    if (height < 1) throw ArgumentError.value(height, 'height', 'must be >= 1');
    _update(
      hexes,
      (o, _) => o.building ? o.copyWith(buildingHeight: () => height) : o,
    );
  }

  /// Height of the building on [hex], or null when there is none.
  int? buildingHeightAt(HexCoord hex) => overlayAt(hex).buildingHeight;

  /// Sets the absolute level for this skirmish. Null, or the printed
  /// level, goes back to the printed level.
  void setLevel(Iterable<HexCoord> hexes, int? level) => _update(
    hexes,
    (o, printed) =>
        o.copyWith(level: () => level == printed.level ? null : level),
  );

  /// The woods, water, and features the hex plays with, at level 0: the
  /// override, or the printed environment. Ignores a placed building.
  HexTerrain environmentAt(HexCoord hex) =>
      (overlayAt(hex).environment ?? source.sheet.terrainAt(hex)).copyWith(
        level: 0,
      );

  /// Edits each hex's current environment with [f], so a change to one
  /// part (say, the woods) keeps each hex's other parts. A result equal to
  /// the printed environment drops the override.
  void updateEnvironment(
    Iterable<HexCoord> hexes,
    HexTerrain Function(HexTerrain environment) f,
  ) => _update(hexes, (o, printed) {
    final base = printed.copyWith(level: 0);
    final next = f(o.environment ?? base).copyWith(level: 0);
    return o.copyWith(environment: () => next == base ? null : next);
  });

  /// Removes every layer from the hexes.
  void clear(Iterable<HexCoord> hexes) =>
      _update(hexes, (_, _) => HexOverlay.none);

  /// Replaces the whole overlay, for undo and redo.
  void restoreOverlay(Map<HexCoord, HexOverlay> overlay) {
    _overlay
      ..clear()
      ..addAll({
        for (final e in overlay.entries)
          if (!e.value.isEmpty) e.key: e.value,
      });
  }

  /// An independent copy with the same source and overlay, for editing
  /// that can be cancelled.
  SkirmishMap copy() => SkirmishMap(source, _overlay);

  /// Called when the skirmish is confirmed. Replaces whatever is under each
  /// building with empty level 0 ground, so removing the building later
  /// (once buildings can be destroyed) leaves a bare level 0 hex rather
  /// than the setup-time terrain.
  void lockIn() {
    for (final MapEntry(key: hex, value: o) in _overlay.entries.toList()) {
      if (!o.building) continue;
      _overlay[hex] = HexOverlay(
        environment: HexTerrain.clear,
        buildingHeight: o.buildingHeight,
        level: 0,
      );
    }
  }

  Map<String, Object?> toJson() {
    final sorted = _overlay.keys.toList()..sort();
    return {
      'id': source.id,
      'sheet': source.sheet.toJson(),
      if (sorted.isNotEmpty)
        'overlay': {for (final h in sorted) h.id: _overlay[h]!.toJson()},
    };
  }

  factory SkirmishMap.fromJson(Map<String, Object?> json) => SkirmishMap(
    SavedMap(
      id: json['id'] as String,
      sheet: MapSheet.fromJson((json['sheet'] as Map).cast<String, Object?>()),
    ),
    {
      for (final e in ((json['overlay'] as Map?) ?? const {}).entries)
        ?HexCoord.tryParse(e.key as String): HexOverlay.fromJson(
          (e.value as Map).cast<String, Object?>(),
        ),
    },
  );
}
