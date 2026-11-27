// File: lib/maps/terrain_type.dart
// One enum for every kind of terrain a hex can hold. Game rules (movement
// costs, line-of-sight and to-hit modifiers) look terrain up by this type.
//
// Storage stays in HexTerrain (woods, waterDepth, features), so saved maps
// and the extractor are unchanged. The extension below reads a HexTerrain
// as a set of these types; edit terrain through HexTerrain itself.
// Elevation is not a terrain type: a level 2 hill with nothing else on it
// is Clear terrain at level 2. Read the level and water depth from
// HexTerrain directly.

import 'map_model.dart';

enum TerrainType {
  /// A hex with no other terrain type. Never combined with another type.
  clear('Clear'),
  lightWoods('Light Woods'),
  heavyWoods('Heavy Woods'),
  ultraHeavyWoods('Ultra-Heavy Woods'),

  /// Water of any depth. Read the depth from HexTerrain.waterDepth.
  water('Water'),
  rough('Rough'),
  rubble('Rubble'),
  pavement('Pavement'),
  road('Road'),
  swamp('Swamp'),
  sand('Sand'),
  ice('Ice'),
  building('Building'),
  bridge('Bridge');

  const TerrainType(this.label);

  /// Display name.
  final String label;

  /// The woods types, lightest first. A hex holds at most one of them.
  static const woods = [lightWoods, heavyWoods, ultraHeavyWoods];

  bool get isWoods => woods.contains(this);

  /// The woods type for [w], or null for no woods.
  static TerrainType? ofWoods(Woods w) => switch (w) {
    Woods.none => null,
    Woods.light => lightWoods,
    Woods.heavy => heavyWoods,
    Woods.ultraHeavy => ultraHeavyWoods,
  };

  static TerrainType ofFeature(TerrainFeature f) => switch (f) {
    TerrainFeature.rough => rough,
    TerrainFeature.rubble => rubble,
    TerrainFeature.pavement => pavement,
    TerrainFeature.road => road,
    TerrainFeature.swamp => swamp,
    TerrainFeature.sand => sand,
    TerrainFeature.ice => ice,
    TerrainFeature.building => building,
    TerrainFeature.bridge => bridge,
  };
}

/// Read-only terrain queries for rules and line-of-sight code.
extension HexTerrainTypes on HexTerrain {
  /// Every terrain type in this hex, in enum order. A hex with no woods,
  /// water or features is {clear}, whatever its level.
  Set<TerrainType> get types {
    final found = <TerrainType>{
      ?TerrainType.ofWoods(woods),
      if (waterDepth > 0) TerrainType.water,
      for (final f in TerrainFeature.values)
        if (features.contains(f)) TerrainType.ofFeature(f),
    };
    return found.isEmpty ? const {TerrainType.clear} : found;
  }

  bool has(TerrainType type) => types.contains(type);

  /// The woods type, or null for no woods.
  TerrainType? get woodsType => TerrainType.ofWoods(woods);
}
