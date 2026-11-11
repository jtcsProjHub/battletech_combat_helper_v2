import 'dart:math' as math;
import 'dart:typed_data';

/// A 3x3 projective transform, row major, with h[8] == 1.
class Homography {
  Homography(this.h) : assert(h.length == 9);

  final Float64List h;

  (double, double) project(double x, double y) {
    final w = h[6] * x + h[7] * y + h[8];
    return ((h[0] * x + h[1] * y + h[2]) / w, (h[3] * x + h[4] * y + h[5]) / w);
  }

  Homography inverse() {
    final a = h;
    final det = a[0] * (a[4] * a[8] - a[5] * a[7]) -
        a[1] * (a[3] * a[8] - a[5] * a[6]) +
        a[2] * (a[3] * a[7] - a[4] * a[6]);
    final inv = Float64List.fromList([
      (a[4] * a[8] - a[5] * a[7]) / det,
      (a[2] * a[7] - a[1] * a[8]) / det,
      (a[1] * a[5] - a[2] * a[4]) / det,
      (a[5] * a[6] - a[3] * a[8]) / det,
      (a[0] * a[8] - a[2] * a[6]) / det,
      (a[2] * a[3] - a[0] * a[5]) / det,
      (a[3] * a[7] - a[4] * a[6]) / det,
      (a[1] * a[6] - a[0] * a[7]) / det,
      (a[0] * a[4] - a[1] * a[3]) / det,
    ]);
    return Homography(_scaled(inv));
  }

  /// Returns this transform followed by a uniform scale, for drawing on a
  /// downscaled preview.
  Homography scaledOutput(double s) => Homography(Float64List.fromList([
        h[0] * s, h[1] * s, h[2] * s,
        h[3] * s, h[4] * s, h[5] * s,
        h[6], h[7], h[8],
      ]));

  List<double> toJson() => h.toList();

  factory Homography.fromJson(List<dynamic> v) =>
      Homography(Float64List.fromList([for (final x in v) (x as num).toDouble()]));

  static Float64List _scaled(Float64List m) {
    final s = m[8];
    return Float64List.fromList([for (final v in m) v / s]);
  }

  static Float64List _mul(Float64List a, Float64List b) {
    final out = Float64List(9);
    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < 3; c++) {
        out[r * 3 + c] =
            a[r * 3] * b[c] + a[r * 3 + 1] * b[3 + c] + a[r * 3 + 2] * b[6 + c];
      }
    }
    return out;
  }

  /// Hartley normalisation: centroid to the origin, mean distance sqrt(2).
  static Float64List _normalizer(List<(double, double)> pts) {
    var mx = 0.0, my = 0.0;
    for (final (x, y) in pts) {
      mx += x;
      my += y;
    }
    mx /= pts.length;
    my /= pts.length;
    var md = 0.0;
    for (final (x, y) in pts) {
      md += math.sqrt((x - mx) * (x - mx) + (y - my) * (y - my));
    }
    md /= pts.length;
    final s = math.sqrt2 / math.max(1e-9, md);
    return Float64List.fromList([s, 0, -s * mx, 0, s, -s * my, 0, 0, 1]);
  }

  /// Least-squares DLT with h33 = 1 after Hartley normalisation.
  /// Returns null for degenerate input.
  static Homography? fit(List<(double, double)> src, List<(double, double)> dst) {
    if (src.length < 4) return null;
    final ts = _normalizer(src), td = _normalizer(dst);
    (double, double) apply(Float64List t, (double, double) p) =>
        (t[0] * p.$1 + t[1] * p.$2 + t[2], t[3] * p.$1 + t[4] * p.$2 + t[5]);
    // Normal equations: (A^T A) h = A^T b, 8 unknowns.
    final ata = Float64List(64);
    final atb = Float64List(8);
    void addRow(List<double> row, double rhs) {
      for (var i = 0; i < 8; i++) {
        atb[i] += row[i] * rhs;
        for (var j = 0; j < 8; j++) {
          ata[i * 8 + j] += row[i] * row[j];
        }
      }
    }

    for (var k = 0; k < src.length; k++) {
      final (x, y) = apply(ts, src[k]);
      final (u, v) = apply(td, dst[k]);
      addRow([x, y, 1, 0, 0, 0, -u * x, -u * y], u);
      addRow([0, 0, 0, x, y, 1, -v * x, -v * y], v);
    }
    final sol = solveLinear(ata, atb, 8);
    if (sol == null) return null;
    final hn = Float64List.fromList([...sol, 1.0]);
    final tdInv = Homography(td).inverse().h;
    return Homography(_scaled(_mul(_mul(tdInv, hn), ts)));
  }

  /// Gauss-Jordan elimination with partial pivoting. [a] is n x n, row major.
  static Float64List? solveLinear(Float64List a, Float64List b, int n) {
    final m = Float64List(n * (n + 1));
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        m[r * (n + 1) + c] = a[r * n + c];
      }
      m[r * (n + 1) + n] = b[r];
    }
    final w = n + 1;
    for (var col = 0; col < n; col++) {
      var piv = col;
      for (var r = col + 1; r < n; r++) {
        if (m[r * w + col].abs() > m[piv * w + col].abs()) piv = r;
      }
      if (m[piv * w + col].abs() < 1e-12) return null;
      if (piv != col) {
        for (var c = 0; c < w; c++) {
          final t = m[col * w + c];
          m[col * w + c] = m[piv * w + c];
          m[piv * w + c] = t;
        }
      }
      final d = m[col * w + col];
      for (var c = 0; c < w; c++) {
        m[col * w + c] /= d;
      }
      for (var r = 0; r < n; r++) {
        if (r == col) continue;
        final f = m[r * w + col];
        if (f == 0) continue;
        for (var c = 0; c < w; c++) {
          m[r * w + c] -= f * m[col * w + c];
        }
      }
    }
    return Float64List.fromList([for (var r = 0; r < n; r++) m[r * w + n]]);
  }
}

/// Small deterministic RNG, identical to Lcg in tool/reference_pipeline.py.
class Lcg {
  Lcg([this._s = 12345]);
  int _s;
  int nextInt(int n) {
    _s = (_s * 1103515245 + 12345) & 0x7FFFFFFF;
    return _s % n;
  }
}

class RansacResult {
  RansacResult(this.homography, this.inliers);
  final Homography homography;
  final List<bool> inliers;
  int get inlierCount => inliers.where((v) => v).length;
}

/// RANSAC over 4-point samples, then two least-squares refits on inliers.
RansacResult? ransacHomography(
  List<(double, double)> src,
  List<(double, double)> dst, {
  int iterations = 1000,
  double threshold = 6.0,
}) {
  final n = src.length;
  if (n < 4) return null;
  final rng = Lcg();

  List<bool> inliersOf(Homography h) => [
        for (var i = 0; i < n; i++)
          () {
            final (px, py) = h.project(src[i].$1, src[i].$2);
            final dx = px - dst[i].$1, dy = py - dst[i].$2;
            final e = math.sqrt(dx * dx + dy * dy);
            return e.isFinite && e < threshold;
          }(),
      ];

  List<bool>? best;
  var bestCount = 0;
  for (var it = 0; it < iterations; it++) {
    final idx = <int>{};
    while (idx.length < 4) {
      idx.add(rng.nextInt(n));
    }
    final sample = idx.toList()..sort();
    final h = Homography.fit([for (final i in sample) src[i]], [for (final i in sample) dst[i]]);
    if (h == null) continue;
    final inl = inliersOf(h);
    final count = inl.where((v) => v).length;
    if (count > bestCount) {
      bestCount = count;
      best = inl;
    }
  }
  if (best == null) return null;
  var inl = best;
  Homography? h;
  for (var k = 0; k < 2; k++) {
    final s = <(double, double)>[], d = <(double, double)>[];
    for (var i = 0; i < n; i++) {
      if (inl[i]) {
        s.add(src[i]);
        d.add(dst[i]);
      }
    }
    final refit = Homography.fit(s, d);
    if (refit == null) break;
    h = refit;
    inl = inliersOf(h);
  }
  if (h == null) return null;
  return RansacResult(h, inl);
}
