import 'package:battletech_combat_helper_v2/maps/extractor_bridge.dart';
import 'package:battletech_combat_helper_v2/maps/map_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_extractor_prototype/map_extractor.dart' as ext;

void main() {
  test('hex coordinates convert both ways', () {
    expect(const ext.HexCoord(4, 12).toApp(), const HexCoord(4, 12));
    expect(const HexCoord(4, 12).toExtractor(), const ext.HexCoord(4, 12));
  });

  test('terrain converts with every field', () {
    for (final f in ext.TerrainFeature.values) {
      final converted = ext.HexTerrain(
        woods: ext.Woods.heavy,
        level: -2,
        waterDepth: 3,
        features: {f},
      ).toApp();
      expect(
        converted,
        HexTerrain(
          woods: Woods.heavy,
          level: -2,
          waterDepth: 3,
          features: {TerrainFeature.values.byName(f.name)},
        ),
      );
    }
    expect(ext.HexTerrain.clear.toApp(), HexTerrain.clear);
  });

  test('grid size converts', () {
    expect(
      const ext.GridSpec(columns: 30, rows: 17).toApp(),
      const GridSpec(columns: 30, rows: 17),
    );
  });
}
