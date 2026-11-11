import 'dart:typed_data';

/// An 8-bit, 3-channel image in BGR order, row major.
///
/// BGR matches the channel order that the PaddleOCR models were trained
/// with (OpenCV order). The class has only the operations the extractor
/// needs, so the behavior is easy to compare with tool/reference_pipeline.py.
class BgrImage {
  BgrImage(this.width, this.height, this.data)
      : assert(data.length == width * height * 3);

  BgrImage.blank(this.width, this.height)
      : data = Uint8List(width * height * 3);

  final int width;
  final int height;
  final Uint8List data;

  /// Copy of the rectangle [x0, x1) x [y0, y1), clipped to the image.
  BgrImage crop(int x0, int y0, int x1, int y1) {
    x0 = x0.clamp(0, width);
    x1 = x1.clamp(0, width);
    y0 = y0.clamp(0, height);
    y1 = y1.clamp(0, height);
    final w = x1 - x0, h = y1 - y0;
    final out = BgrImage.blank(w, h);
    for (var y = 0; y < h; y++) {
      final src = ((y0 + y) * width + x0) * 3;
      out.data.setRange(y * w * 3, (y + 1) * w * 3, data, src);
    }
    return out;
  }

  /// Rotates by [quarterTurnsCw] quarter turns clockwise.
  BgrImage rotate(int quarterTurnsCw) {
    final k = quarterTurnsCw % 4;
    if (k == 0) return this;
    final w = k == 2 ? width : height;
    final h = k == 2 ? height : width;
    final out = BgrImage.blank(w, h);
    final d = out.data;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        int nx, ny;
        switch (k) {
          case 1: // clockwise
            nx = height - 1 - y;
            ny = x;
          case 2:
            nx = width - 1 - x;
            ny = height - 1 - y;
          default: // counter-clockwise
            nx = y;
            ny = width - 1 - x;
        }
        final s = (y * width + x) * 3, t = (ny * w + nx) * 3;
        d[t] = data[s];
        d[t + 1] = data[s + 1];
        d[t + 2] = data[s + 2];
      }
    }
    return out;
  }

  /// Bilinear resize with half-pixel centres, like cv2.INTER_LINEAR.
  BgrImage resize(int newWidth, int newHeight) {
    if (newWidth == width && newHeight == height) return this;
    final out = BgrImage.blank(newWidth, newHeight);
    final sx = width / newWidth, sy = height / newHeight;
    final x0s = Int32List(newWidth), x1s = Int32List(newWidth);
    final fxs = Float64List(newWidth);
    for (var x = 0; x < newWidth; x++) {
      var fx = (x + 0.5) * sx - 0.5;
      if (fx < 0) fx = 0;
      var ix = fx.floor();
      if (ix >= width - 1) {
        ix = width - 1;
        fx = ix.toDouble();
      }
      x0s[x] = ix;
      x1s[x] = ix + 1 < width ? ix + 1 : ix;
      fxs[x] = fx - ix;
    }
    final d = out.data;
    for (var y = 0; y < newHeight; y++) {
      var fy = (y + 0.5) * sy - 0.5;
      if (fy < 0) fy = 0;
      var iy = fy.floor();
      if (iy >= height - 1) {
        iy = height - 1;
        fy = iy.toDouble();
      }
      final iy1 = iy + 1 < height ? iy + 1 : iy;
      final wy = fy - iy;
      final row0 = iy * width * 3, row1 = iy1 * width * 3;
      for (var x = 0; x < newWidth; x++) {
        final a = row0 + x0s[x] * 3, b = row0 + x1s[x] * 3;
        final c = row1 + x0s[x] * 3, e = row1 + x1s[x] * 3;
        final wx = fxs[x];
        final t = (y * newWidth + x) * 3;
        for (var ch = 0; ch < 3; ch++) {
          final top = data[a + ch] + (data[b + ch] - data[a + ch]) * wx;
          final bot = data[c + ch] + (data[e + ch] - data[c + ch]) * wx;
          d[t + ch] = (top + (bot - top) * wy).round().clamp(0, 255);
        }
      }
    }
    return out;
  }

  /// RGBA bytes for display, downscaled so the longer side is at most
  /// [maxSide]. Returns the bytes, size and the scale (preview / original).
  ({Uint8List rgba, int width, int height, double scale}) toRgbaPreview(
      int maxSide) {
    final longSide = width > height ? width : height;
    final scale = longSide <= maxSide ? 1.0 : maxSide / longSide;
    final small = resize((width * scale).round(), (height * scale).round());
    final n = small.width * small.height;
    final rgba = Uint8List(n * 4);
    for (var i = 0; i < n; i++) {
      rgba[i * 4] = small.data[i * 3 + 2];
      rgba[i * 4 + 1] = small.data[i * 3 + 1];
      rgba[i * 4 + 2] = small.data[i * 3];
      rgba[i * 4 + 3] = 255;
    }
    return (
      rgba: rgba,
      width: small.width,
      height: small.height,
      scale: small.width / width,
    );
  }
}
