import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:map_extractor_prototype/map_extractor.dart';

void main() {
  // A perspective transform similar to a hand-held photo of a sheet.
  final truth = Homography.fit(
    [(1.0, 1.0), (15.0, 1.0), (15.0, 17.0), (1.0, 17.0)],
    [(120.0, 90.0), (2100.0, 140.0), (2050.0, 2700.0), (80.0, 2620.0)],
  )!;

  test('fit recovers an exact homography from 4 points', () {
    final (x, y) = truth.project(8, 9);
    final inv = truth.inverse();
    final (u, v) = inv.project(x, y);
    expect(u, closeTo(8, 1e-9));
    expect(v, closeTo(9, 1e-9));
  });

  test('RANSAC ignores misread hex numbers', () {
    final src = <(double, double)>[];
    final dst = <(double, double)>[];
    final rng = math.Random(1);
    for (final hex in GridSpec.standard.allHexes) {
      final g = hex.numberPoint;
      var (x, y) = truth.project(g.$1, g.$2);
      x += rng.nextDouble() * 2 - 1;
      y += rng.nextDouble() * 2 - 1;
      src.add(g);
      dst.add((x, y));
    }
    // 20 % outliers: the OCR read the wrong number.
    for (var i = 0; i < src.length; i += 5) {
      dst[i] = (dst[i].$1 + 300, dst[i].$2 - 250);
    }
    final r = ransacHomography(src, dst)!;
    expect(r.inlierCount, src.length - (src.length / 5).ceil());
    final (x, y) = r.homography.project(8, 9);
    final (tx, ty) = truth.project(8, 9);
    expect(x, closeTo(tx, 1.0));
    expect(y, closeTo(ty, 1.0));
  });

  test('labels belong to the hex above the next number', () {
    // A label printed just above number 0415 belongs to 0414.
    expect(SheetGeometry.labelOwner(4, 14.5 + 0.8), const HexCoord(4, 14));
    expect(SheetGeometry.labelOwner(5, 14 + 0.8), const HexCoord(5, 14));
  });

  test('hexAt finds the hex around its centre', () {
    for (final hex in [const HexCoord(1, 1), const HexCoord(4, 9), const HexCoord(15, 17)]) {
      final (u, v) = SheetGeometry.hexCenter(hex);
      expect(SheetGeometry.hexAt(u, v), hex);
      expect(SheetGeometry.hexAt(u + 0.3, v - 0.3), hex);
    }
  });
}
