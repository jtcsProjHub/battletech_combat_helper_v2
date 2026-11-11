import 'package:flutter_test/flutter_test.dart';
import 'package:map_extractor_prototype/map_extractor.dart';

void main() {
  test('JSON round trip keeps size, terrain and review flags', () {
    final sheet = MapSheet(
      name: 'Foothills #1',
      grid: const GridSpec(columns: 15, rows: 17),
      hexes: {
        const HexCoord(1, 2): const HexTerrain(woods: Woods.light),
        const HexCoord(13, 5): const HexTerrain(level: 2, woods: Woods.light),
        const HexCoord(5, 5): const HexTerrain(features: {TerrainFeature.rough}),
        const HexCoord(3, 3): HexTerrain.clear, // dropped
        const HexCoord(16, 1): const HexTerrain(level: 1), // outside, dropped
      },
      unverified: {const HexCoord(12, 7)},
    );
    final back = MapSheet.fromJsonString(sheet.toJsonString());
    expect(back.name, 'Foothills #1');
    expect(back.grid, const GridSpec(columns: 15, rows: 17));
    expect(back.hexes.length, 3);
    expect(back.terrainAt(const HexCoord(13, 5)),
        const HexTerrain(level: 2, woods: Woods.light));
    expect(back.terrainAt(const HexCoord(3, 3)).isClear, isTrue);
    expect(back.unverified, {const HexCoord(12, 7)});
  });

  test('clear hexes serialize to nothing', () {
    expect(HexTerrain.clear.toJson(), isEmpty);
    expect(const HexTerrain(level: -1).toJson(), {'level': -1});
  });

  test('merge votes across images and flags conflicts', () {
    ImageExtraction fake(String name, Map<HexCoord, List<LabelReading>> r) =>
        ImageExtraction(
          name: name,
          rotation: 0,
          homography: Homography.fit(
            [(1.0, 1.0), (2.0, 1.0), (2.0, 2.0), (1.0, 2.0)],
            [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)],
          )!,
          anchorCount: 0,
          inlierCount: 0,
          medianResidual: 0,
          maxCol: 15,
          maxRow: 17,
          readings: r,
          words: const [],
          imageWidth: 1,
          imageHeight: 1,
          seconds: 0,
        );
    const a = HexCoord(9, 2), b = HexCoord(10, 5), c = HexCoord(1, 5);
    final merged = mergeExtractions([
      fake('scan', {
        a: [const LabelReading(LabelToken('LEVEL', number: 8, certain: false), 0.2, 'LEVELB')],
        b: [const LabelReading(LabelToken('LEVEL', certain: false), 0.9, 'LEVEL')],
        c: [const LabelReading(LabelToken('LIGHT'), 0.9, 'LIGHT')],
      }),
      fake('photo', {
        a: [const LabelReading(LabelToken('LEVEL', number: 2), 0.9, 'LEVEL2')],
        b: [const LabelReading(LabelToken('LEVEL', number: 1), 0.8, 'LEVEL1')],
      }),
    ]);
    expect(merged.grid, GridSpec.standard);
    expect(merged.terrain[a]!.level, 2);
    expect(merged.review, contains(a)); // two values were read
    expect(merged.terrain[b]!.level, 1);
    expect(merged.review, isNot(contains(b))); // the unknown digit is outvoted
    expect(merged.terrain[c]!.woods, Woods.light);
    expect(merged.review, isNot(contains(c)));
  });
}
