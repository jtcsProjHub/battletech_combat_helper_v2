import 'dart:math' as math;
import 'dart:typed_data';

import '../imaging/bgr_image.dart';
import 'onnx_runtime.dart';

/// Tunable values. The defaults match tool/reference_pipeline.py.
class OcrConfig {
  const OcrConfig({
    this.tile = 1408,
    this.tileOverlap = 160,
    this.detLimitMinSide = 736,
    this.detThresh = 0.3,
    this.detBoxThresh = 0.5,
    this.detUnclipRatio = 1.6,
    this.detMinSize = 3,
    this.recHeight = 48,
    this.recMinWidth = 320,
    this.textScore = 0.5,
    this.edgeMargin = 4,
    this.asciiOnly = true,
  });

  /// Tile size in pixels. A multiple of 32, so full tiles need no resize.
  final int tile;
  final int tileOverlap;
  final int detLimitMinSide;
  final double detThresh;
  final double detBoxThresh;
  final double detUnclipRatio;
  final int detMinSize;
  final int recHeight;
  final int recMinWidth;
  final double textScore;

  /// Boxes that touch an inner tile edge within this margin are dropped,
  /// because the neighbouring tile sees them whole.
  final int edgeMargin;

  /// Limit the recognizer to ASCII letters, digits, '-', '|' and space.
  final bool asciiOnly;
}

/// One recognized text box, in pixels of the image passed to [PaddleOcr.read].
class OcrWord {
  const OcrWord(this.x0, this.y0, this.x1, this.y1, this.text, this.score,
      this.minCharScore);

  final int x0, y0, x1, y1;
  final String text;

  /// Mean confidence of the decoded characters.
  final double score;

  /// Lowest confidence of any decoded character.
  final double minCharScore;

  double get cx => (x0 + x1) / 2;
  double get cy => (y0 + y1) / 2;

  @override
  String toString() => '"$text" ${score.toStringAsFixed(2)} @($x0,$y0)-($x1,$y1)';
}

class _Box {
  _Box(this.x0, this.y0, this.x1, this.y1);
  final int x0, y0, x1, y1;
}

/// PaddleOCR PP-OCRv4 text detection (DB) and recognition (CTC) on ONNX
/// Runtime.
///
/// Differences from the stock PaddleOCR / RapidOCR pipeline:
/// - Text boxes are axis-aligned bounding boxes of connected components,
///   not minimum-area rotated rectangles. Map text is horizontal after the
///   page rotation step, so this loses nothing and needs no OpenCV.
/// - No angle classifier, for the same reason.
/// - Optional ASCII-only decoding (see [OcrConfig.asciiOnly]).
class PaddleOcr {
  PaddleOcr(OnnxRuntime rt, Uint8List detModel, Uint8List recModel,
      String dictionary, {this.config = const OcrConfig()})
      : _det = rt.createSession(detModel),
        _rec = rt.createSession(recModel) {
    final chars = dictionary.split('\n');
    if (chars.isNotEmpty && chars.last.isEmpty) chars.removeLast();
    // Index 0 is the CTC blank, then the dictionary, then a space.
    _charset = ['', ...chars, ' '];
    _allowed = Int32List.fromList([
      for (var i = 0; i < _charset.length; i++)
        if (i == 0 || _isAllowed(_charset[i])) i,
    ]);
  }

  final OcrConfig config;
  final OrtSession _det;
  final OrtSession _rec;
  late final List<String> _charset;
  late final Int32List _allowed;

  static bool _isAllowed(String c) {
    if (c.length != 1) return false;
    final u = c.codeUnitAt(0);
    return (u >= 0x30 && u <= 0x39) || // 0-9
        (u >= 0x41 && u <= 0x5A) || // A-Z
        (u >= 0x61 && u <= 0x7A) || // a-z
        c == '-' ||
        c == '|' ||
        c == ' ';
  }

  void dispose() {
    _det.dispose();
    _rec.dispose();
  }

  /// Converts BGR bytes to a normalized NCHW float tensor: x / 127.5 - 1.
  static Float32List _toTensor(BgrImage img, int width) {
    final h = img.height, w = img.width;
    final plane = h * width;
    final out = Float32List(3 * plane); // zero padding = mid grey
    final d = img.data;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final s = (y * w + x) * 3;
        final t = y * width + x;
        out[t] = d[s] / 127.5 - 1.0;
        out[plane + t] = d[s + 1] / 127.5 - 1.0;
        out[2 * plane + t] = d[s + 2] / 127.5 - 1.0;
      }
    }
    return out;
  }

  /// Text detection on one tile. Returns boxes in tile pixels.
  List<_Box> _detect(BgrImage img) {
    final h = img.height, w = img.width;
    var ratio = 1.0;
    final minSide = math.min(h, w);
    if (minSide < config.detLimitMinSide) ratio = config.detLimitMinSide / minSide;
    // Python's round() rounds halves to even, so 2064 / 32 = 64.5 -> 64.
    int round32(double v) {
      final q = v.toInt(), k = q ~/ 32, rem = q % 32;
      final n = rem > 16 || (rem == 16 && k.isOdd) ? k + 1 : k;
      return math.max(32, n * 32);
    }
    final rh = round32(h * ratio), rw = round32(w * ratio);
    final input = (rh == h && rw == w) ? img : img.resize(rw, rh);
    final out = _det.run(_toTensor(input, rw), [1, 3, rh, rw]);
    final ph = out.shape[2], pw = out.shape[3];
    final pred = out.data;

    // Binary mask, then 2x2 dilation with anchor (1,1):
    // dilated(y,x) = max(mask[y-1..y, x-1..x]).
    final mask = Uint8List(ph * pw);
    for (var i = 0; i < pred.length; i++) {
      if (pred[i] > config.detThresh) mask[i] = 1;
    }
    final dil = Uint8List.fromList(mask);
    for (var y = 0; y < ph; y++) {
      for (var x = 0; x < pw; x++) {
        if (dil[y * pw + x] == 1) continue;
        if ((y > 0 && mask[(y - 1) * pw + x] == 1) ||
            (x > 0 && mask[y * pw + x - 1] == 1) ||
            (y > 0 && x > 0 && mask[(y - 1) * pw + x - 1] == 1)) {
          dil[y * pw + x] = 1;
        }
      }
    }

    // Integral image of pred for box means.
    final integ = Float64List((ph + 1) * (pw + 1));
    for (var y = 0; y < ph; y++) {
      var rowSum = 0.0;
      for (var x = 0; x < pw; x++) {
        rowSum += pred[y * pw + x];
        integ[(y + 1) * (pw + 1) + x + 1] = integ[y * (pw + 1) + x + 1] + rowSum;
      }
    }
    double rectMean(int x0, int y0, int x1, int y1) {
      final a = integ[y0 * (pw + 1) + x0];
      final b = integ[y0 * (pw + 1) + x1 + 1];
      final c = integ[(y1 + 1) * (pw + 1) + x0];
      final d = integ[(y1 + 1) * (pw + 1) + x1 + 1];
      return (d - b - c + a) / ((x1 - x0 + 1) * (y1 - y0 + 1));
    }

    // 8-connected components by flood fill.
    final visited = Uint8List(ph * pw);
    final stack = Int32List(ph * pw);
    final boxes = <_Box>[];
    final sx = w / pw, sy = h / ph;
    for (var start = 0; start < dil.length; start++) {
      if (dil[start] == 0 || visited[start] == 1) continue;
      var top = 0;
      stack[top++] = start;
      visited[start] = 1;
      var minX = pw, minY = ph, maxX = -1, maxY = -1;
      while (top > 0) {
        final i = stack[--top];
        final y = i ~/ pw, x = i - y * pw;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
        for (var dy = -1; dy <= 1; dy++) {
          final ny = y + dy;
          if (ny < 0 || ny >= ph) continue;
          for (var dx = -1; dx <= 1; dx++) {
            final nx = x + dx;
            if (nx < 0 || nx >= pw) continue;
            final j = ny * pw + nx;
            if (dil[j] == 1 && visited[j] == 0) {
              visited[j] = 1;
              stack[top++] = j;
            }
          }
        }
      }
      final ew = maxX - minX, eh = maxY - minY;
      if (math.min(ew, eh) < config.detMinSize) continue;
      final score = rectMean(minX, minY, maxX, maxY);
      if (score < config.detBoxThresh) continue;
      final dist = ew * eh * config.detUnclipRatio / (2 * (ew + eh));
      final ux0 = minX - dist, uy0 = minY - dist;
      final ux1 = maxX + dist, uy1 = maxY + dist;
      if (math.min(ux1 - ux0, uy1 - uy0) < config.detMinSize + 2) continue;
      // Python's round() rounds halves to even. The difference is at most
      // one pixel on an exact .5, which does not matter here.
      boxes.add(_Box(
        (ux0 * sx).round().clamp(0, w),
        (uy0 * sy).round().clamp(0, h),
        (ux1 * sx).round().clamp(0, w),
        (uy1 * sy).round().clamp(0, h),
      ));
    }
    return boxes;
  }

  /// Recognizes one cropped text line. Returns text, mean and min char
  /// confidence.
  (String, double, double) recognize(BgrImage crop) {
    final rh = config.recHeight;
    final ratio = crop.width / crop.height;
    final imgW = (rh * math.max(config.recMinWidth / rh, ratio)).toInt();
    final rw = math.min(imgW, (rh * ratio).ceil());
    final resized = crop.resize(rw, rh);
    final out = _rec.run(_toTensor(resized, imgW), [1, 3, rh, imgW]);
    final steps = out.shape[1], classes = out.shape[2];
    final probs = out.data;
    final sb = StringBuffer();
    final confs = <double>[];
    var prev = -1;
    for (var t = 0; t < steps; t++) {
      final row = t * classes;
      var best = 0;
      var bestP = -1.0;
      if (config.asciiOnly) {
        for (final i in _allowed) {
          final v = probs[row + i];
          if (v > bestP) {
            bestP = v;
            best = i;
          }
        }
      } else {
        for (var i = 0; i < classes; i++) {
          final v = probs[row + i];
          if (v > bestP) {
            bestP = v;
            best = i;
          }
        }
      }
      if (best != 0 && best != prev && best < _charset.length) {
        sb.write(_charset[best]);
        confs.add(bestP);
      }
      prev = best;
    }
    if (confs.isEmpty) return ('', 0.0, 0.0);
    final mean = confs.reduce((a, b) => a + b) / confs.length;
    return (sb.toString(), mean, confs.reduce(math.min));
  }

  /// Tiles the image, detects and recognizes text.
  List<OcrWord> read(BgrImage img, {void Function(double fraction)? onProgress}) {
    final t = config.tile;
    List<int> starts(int n) {
      if (n <= t) return [0];
      final s = <int>[];
      for (var v = 0; v < n - t; v += t - config.tileOverlap) {
        s.add(v);
      }
      s.add(n - t);
      return s;
    }

    final ys = starts(img.height), xs = starts(img.width);
    final total = ys.length * xs.length;
    var done = 0;
    final out = <OcrWord>[];
    final m = config.edgeMargin;
    for (final ty in ys) {
      for (final tx in xs) {
        final tile = img.crop(tx, ty, tx + t, ty + t);
        final tw = tile.width, th = tile.height;
        for (final b in _detect(tile)) {
          if ((tx > 0 && b.x0 <= m) ||
              (ty > 0 && b.y0 <= m) ||
              (tx + tw < img.width && b.x1 >= tw - m) ||
              (ty + th < img.height && b.y1 >= th - m)) {
            continue;
          }
          final bw = b.x1 - b.x0, bh = b.y1 - b.y0;
          if (bw < 2 || bh < 2 || bh / bw >= 1.5) continue;
          final (text, score, minScore) =
              recognize(tile.crop(b.x0, b.y0, b.x1, b.y1));
          final trimmed = text.trim();
          if (score >= config.textScore && trimmed.isNotEmpty) {
            out.add(OcrWord(tx + b.x0, ty + b.y0, tx + b.x1, ty + b.y1, trimmed,
                score, minScore));
          }
        }
        done++;
        onProgress?.call(done / total);
      }
    }
    return out;
  }
}
