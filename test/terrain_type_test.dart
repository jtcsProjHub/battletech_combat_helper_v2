import 'package:battletech_combat_helper_v2/maps/terrain_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_extractor_prototype/map_extractor.dart';

void main() {
  test('every woods and feature value maps to its own type', () {
    final mapped = {
      for (final w in Woods.values) ?TerrainType.ofWoods(w),
      for (final f in TerrainFeature.values) TerrainType.ofFeature(f),
    };
    expect(
      mapped.length,
      Woods.values.length - 1 + TerrainFeature.values.length,
    );
  });

  test('a hex with no woods, water or features is clear at any level', () {
    expect(const HexTerrain(level: 3).types, {TerrainType.clear});
    expect(const HexTerrain(level: 3).has(TerrainType.clear), isTrue);
  });

  test('types lists woods, water and features', () {
    const t = HexTerrain(
      woods: Woods.heavy,
      waterDepth: 2,
      features: {TerrainFeature.rough},
    );
    expect(t.types, {
      TerrainType.heavyWoods,
      TerrainType.water,
      TerrainType.rough,
    });
    expect(t.has(TerrainType.clear), isFalse);
    expect(t.has(TerrainType.lightWoods), isFalse);
  });
}
