/// Woods density printed on a hex.
enum Woods { none, light, heavy, ultraHeavy }

/// Terrain properties without a numeric value.
enum TerrainFeature { rough, rubble, pavement, road, swamp, sand, ice, building, bridge }

/// The printed terrain of one hex. A hex with default values is Clear.
///
/// This class holds reference data from the printed sheet only. Things
/// that players add for one skirmish, such as miniature buildings, belong
/// in a separate per-skirmish layer.
class HexTerrain {
  const HexTerrain({
    this.woods = Woods.none,
    this.level = 0,
    this.waterDepth = 0,
    this.features = const {},
  });

  static const clear = HexTerrain();

  final Woods woods;

  /// Elevation level. Negative values are depressions.
  final int level;

  /// Water depth. Zero means no water.
  final int waterDepth;

  final Set<TerrainFeature> features;

  bool get isClear =>
      woods == Woods.none && level == 0 && waterDepth == 0 && features.isEmpty;

  HexTerrain copyWith({
    Woods? woods,
    int? level,
    int? waterDepth,
    Set<TerrainFeature>? features,
  }) =>
      HexTerrain(
        woods: woods ?? this.woods,
        level: level ?? this.level,
        waterDepth: waterDepth ?? this.waterDepth,
        features: features ?? this.features,
      );

  HexTerrain toggle(TerrainFeature f) {
    final next = Set<TerrainFeature>.of(features);
    if (!next.remove(f)) next.add(f);
    return copyWith(features: next);
  }

  /// The labels the sheet would print for this terrain, for example
  /// ["LEVEL 2", "LIGHT"].
  List<String> get printedLabels => [
        if (level != 0) 'LEVEL $level',
        if (waterDepth != 0) 'DEPTH $waterDepth',
        if (woods == Woods.light) 'LIGHT',
        if (woods == Woods.heavy) 'HEAVY',
        if (woods == Woods.ultraHeavy) 'ULTRA HEAVY',
        for (final f in TerrainFeature.values)
          if (features.contains(f)) f.name.toUpperCase(),
      ];

  /// JSON with default values left out, so a clear hex is `{}`.
  Map<String, Object?> toJson() => {
        if (woods != Woods.none) 'woods': woods.name,
        if (level != 0) 'level': level,
        if (waterDepth != 0) 'waterDepth': waterDepth,
        if (features.isNotEmpty)
          'features': [
            for (final f in TerrainFeature.values)
              if (features.contains(f)) f.name,
          ],
      };

  factory HexTerrain.fromJson(Map<String, Object?> json) => HexTerrain(
        woods: Woods.values.byName((json['woods'] as String?) ?? 'none'),
        level: (json['level'] as num?)?.toInt() ?? 0,
        waterDepth: (json['waterDepth'] as num?)?.toInt() ?? 0,
        features: {
          for (final f in (json['features'] as List?) ?? const [])
            TerrainFeature.values.byName(f as String),
        },
      );

  @override
  bool operator ==(Object other) =>
      other is HexTerrain &&
      other.woods == woods &&
      other.level == level &&
      other.waterDepth == waterDepth &&
      other.features.length == features.length &&
      other.features.containsAll(features);

  @override
  int get hashCode => Object.hash(
      woods, level, waterDepth, Object.hashAllUnordered(features));

  @override
  String toString() => isClear ? 'CLEAR' : printedLabels.join(' ');
}
