import 'dart:math' as math;
import 'dart:ui';

import '../model/hex_coord.dart';
import '../model/map_sheet.dart';

/// Screen geometry for drawing a map as flat-topped hexes.
///
/// The same layout serves the extractor review screen and, later, the
/// skirmish setup editor in the main app.
class HexLayout {
  const HexLayout(this.grid, {this.radius = 44});

  final GridSpec grid;

  /// Centre-to-corner distance in logical pixels.
  final double radius;

  static final _sqrt3 = math.sqrt(3);

  double get _h => _sqrt3 * radius;

  Size get size => Size(
        radius * (1.5 * (grid.columns - 1) + 2),
        _h * (grid.rows + 0.5),
      );

  Offset center(HexCoord hex) => Offset(
        radius + 1.5 * radius * (hex.col - 1),
        _h / 2 + _h * (hex.row - 1) + (hex.isEvenColumn ? _h / 2 : 0),
      );

  Path outline(HexCoord hex) {
    final c = center(hex);
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final a = math.pi / 3 * i;
      final p = c + Offset(radius * math.cos(a), radius * math.sin(a));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path..close();
  }

  /// The hex under [pos], or null outside the grid.
  HexCoord? hitTest(Offset pos) {
    final guess = ((pos.dx - radius) / (1.5 * radius)).round() + 1;
    HexCoord? best;
    var bestD = double.infinity;
    for (var c = guess - 1; c <= guess + 1; c++) {
      final shift = c.isEven ? _h / 2 : 0.0;
      final r0 = ((pos.dy - _h / 2 - shift) / _h).round() + 1;
      for (var r = r0 - 1; r <= r0 + 1; r++) {
        final hex = HexCoord(c, r);
        final d = (center(hex) - pos).distanceSquared;
        if (d < bestD) {
          bestD = d;
          best = hex;
        }
      }
    }
    if (best == null || bestD > radius * radius) return null;
    return best.isInside(grid.columns, grid.rows) ? best : null;
  }
}
