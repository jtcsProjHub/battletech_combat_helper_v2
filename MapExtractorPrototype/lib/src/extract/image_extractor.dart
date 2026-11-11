import 'dart:math' as math;

import '../imaging/bgr_image.dart';
import '../model/hex_coord.dart';
import '../ocr/paddle_ocr.dart';
import 'homography.dart';
import 'label_parser.dart';

/// Geometry of the printed sheets, in grid units (1 column, 1 row).
abstract final class SheetGeometry {
  /// A terrain label sits this far below its own hex number.
  static const labelRowOffset = 0.8;

  /// The hex centre sits this far below the hex number.
  static const centerRowOffset = 0.32;

  /// Corners of a flat-topped hex around [center], in grid units.
  static List<(double, double)> hexCorners((double, double) center) {
    final (x, y) = center;
    return [
      (x + 2 / 3, y),
      (x + 1 / 3, y + 0.5),
      (x - 1 / 3, y + 0.5),
      (x - 2 / 3, y),
      (x - 1 / 3, y - 0.5),
      (x + 1 / 3, y - 0.5),
    ];
  }

  static (double, double) hexCenter(HexCoord hex) {
    final (x, y) = hex.numberPoint;
    return (x, y + centerRowOffset);
  }

  /// The hex that owns a label whose centre is at grid point (u, v).
  static HexCoord labelOwner(double u, double v) {
    final c = u.round();
    final r = (v - (c.isEven ? 0.5 : 0.0) - labelRowOffset).round();
    return HexCoord(c, r);
  }

  /// The hex whose outline contains grid point (u, v).
  static HexCoord hexAt(double u, double v) {
    final guess = u.round();
    HexCoord? best;
    var bestD = double.infinity;
    for (var c = guess - 1; c <= guess + 1; c++) {
      final r0 = (v - (c.isEven ? 0.5 : 0.0) - centerRowOffset).round();
      for (var r = r0 - 1; r <= r0 + 1; r++) {
        final (cx, cy) = hexCenter(HexCoord(c, r));
        // One column is 1.5 hex radii and one row is sqrt(3) radii, so a
        // column unit is 1.5 / sqrt(3) = 0.866 of a row unit.
        final dx = (u - cx) * 0.866, dy = v - cy;
        final d = dx * dx + dy * dy;
        if (d < bestD) {
          bestD = d;
          best = HexCoord(c, r);
        }
      }
    }
    return best!;
  }
}

/// One terrain reading of one hex from one image.
class LabelReading {
  const LabelReading(this.token, this.score, this.rawText);
  final LabelToken token;
  final double score;
  final String rawText;
}

/// Everything the extractor learned from one image.
class ImageExtraction {
  ImageExtraction({
    required this.name,
    required this.rotation,
    required this.homography,
    required this.anchorCount,
    required this.inlierCount,
    required this.medianResidual,
    required this.maxCol,
    required this.maxRow,
    required this.readings,
    required this.words,
    required this.imageWidth,
    required this.imageHeight,
    required this.seconds,
  });

  final String name;

  /// Quarter turns clockwise applied to the loaded image.
  final int rotation;

  /// Grid space (column, row) to pixels of the rotated image.
  final Homography homography;
  final int anchorCount;
  final int inlierCount;
  final double medianResidual;
  final int maxCol;
  final int maxRow;
  final Map<HexCoord, List<LabelReading>> readings;

  /// All OCR words, for the debug overlay.
  final List<OcrWord> words;
  final int imageWidth;
  final int imageHeight;
  final double seconds;

  String get summary => '$anchorCount hex numbers, $inlierCount fit, '
      '${medianResidual.toStringAsFixed(1)} px error, '
      '${readings.length} labeled hexes, ${seconds.toStringAsFixed(0)} s';
}

class ExtractionException implements Exception {
  ExtractionException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Runs OCR on one image, fits the hex grid and assigns labels to hexes.
class ImageExtractor {
  ImageExtractor(this.ocr, {this.ransacThreshold = 6.0});

  final PaddleOcr ocr;
  final double ransacThreshold;

  /// Reads the centre tile at each quarter turn and returns the turn that
  /// finds the most hex numbers.
  int probeRotation(BgrImage img) {
    var bestK = 0, bestCount = -1;
    final t = ocr.config.tile;
    for (var k = 0; k < 4; k++) {
      final r = img.rotate(k);
      final x0 = math.max(0, r.width ~/ 2 - t ~/ 2);
      final y0 = math.max(0, r.height ~/ 2 - t ~/ 2);
      final tile = r.crop(x0, y0, x0 + t, y0 + t);
      final count = ocr
          .read(tile)
          .where((w) => LabelParser.parseHexId(w.text) != null)
          .length;
      if (count > bestCount) {
        bestCount = count;
        bestK = k;
      }
    }
    return bestK;
  }

  /// [onStage] receives a short description and a 0..1 fraction.
  (ImageExtraction, BgrImage) extract(
    BgrImage loaded,
    String name, {
    void Function(String stage, double fraction)? onStage,
  }) {
    final sw = Stopwatch()..start();
    onStage?.call('Finding orientation', 0);
    final k = probeRotation(loaded);
    final img = loaded.rotate(k);

    final words = ocr.read(img,
        onProgress: (f) => onStage?.call('Reading text', f));

    onStage?.call('Fitting grid', 1);
    final anchors = <HexCoord, OcrWord>{};
    final others = <OcrWord>[];
    for (final w in words) {
      final hex = LabelParser.parseHexId(w.text);
      if (hex != null) {
        anchors.putIfAbsent(hex, () => w);
      } else {
        others.add(w);
      }
    }
    final keys = anchors.keys.toList();
    final src = [for (final h in keys) h.numberPoint];
    final dst = [for (final h in keys) (anchors[h]!.cx, anchors[h]!.cy)];
    final fit = ransacHomography(src, dst, threshold: ransacThreshold);
    if (fit == null || fit.inlierCount < 8) {
      throw ExtractionException(
          '$name: found ${keys.length} hex numbers, not enough to place the grid.');
    }
    final hmg = fit.homography;
    final inv = hmg.inverse();

    final residuals = <double>[];
    var maxCol = 1, maxRow = 1;
    for (var i = 0; i < keys.length; i++) {
      if (!fit.inliers[i]) continue;
      final (px, py) = hmg.project(src[i].$1, src[i].$2);
      residuals.add(math.sqrt(math.pow(px - dst[i].$1, 2) + math.pow(py - dst[i].$2, 2)));
      maxCol = math.max(maxCol, keys[i].col);
      maxRow = math.max(maxRow, keys[i].row);
    }
    residuals.sort();

    final readings = <HexCoord, List<LabelReading>>{};
    for (final w in others) {
      final tokens = LabelParser.parseLabel(w.text);
      if (tokens.isEmpty) continue;
      final (u, v) = inv.project(w.cx, w.cy);
      final hex = SheetGeometry.labelOwner(u, v);
      if (hex.col < 1 || hex.row < 1) continue;
      for (final t in tokens) {
        readings.putIfAbsent(hex, () => []).add(LabelReading(t, w.minCharScore, w.text));
      }
    }

    return (
      ImageExtraction(
        name: name,
        rotation: k,
        homography: hmg,
        anchorCount: keys.length,
        inlierCount: fit.inlierCount,
        medianResidual: residuals[residuals.length ~/ 2],
        maxCol: maxCol,
        maxRow: maxRow,
        readings: readings,
        words: words,
        imageWidth: img.width,
        imageHeight: img.height,
        seconds: sw.elapsedMilliseconds / 1000,
      ),
      img,
    );
  }
}
