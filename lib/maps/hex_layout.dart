// File: lib/maps/hex_layout.dart
// Screen geometry for drawing a map sheet as flat-topped hexes, and the
// terrain colors. Ported from the Map Extractor prototype.

import 'dart:math' as math;
import 'dart:ui';

import 'package:map_extractor_prototype/map_extractor.dart';

class HexLayout {
  const HexLayout(this.grid, {this.radius = 44});

  final GridSpec grid;

  /// Centre-to-corner distance in logical pixels.
  final double radius;

  static final _sqrt3 = math.sqrt(3);

  double get _h => _sqrt3 * radius;

  Size get size =>
      Size(radius * (1.5 * (grid.columns - 1) + 2), _h * (grid.rows + 0.5));

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

/// Colors for the schematic map. The map keeps the printed-sheet palette
/// so it reads like the sheet on the table; the app accent is not used for
/// map content.
abstract final class TerrainStyle {
  static const clear = Color(0xFFDCD4B6);
  static const gridLine = Color(0xFF6E6650);
  static const idText = Color(0xFF5A5340);
  static const labelText = Color(0xFF1F1B12);
  static const review = Color(0xFFFF8C00);
  static const selected = Color(0xFF1E88E5);
  static const ocrText = Color(0xFFE53935);

  static const _levelUp = [
    Color(0xFFDCD4B6),
    Color(0xFFC3B98F),
    Color(0xFFA99C6E),
    Color(0xFF8E7F52),
    Color(0xFF73643C),
  ];

  static Color fill(HexTerrain t) {
    if (t.waterDepth > 0) {
      return Color.lerp(
        const Color(0xFF8EC5E8),
        const Color(0xFF1F5F8B),
        ((t.waterDepth - 1) / 3).clamp(0.0, 1.0),
      )!;
    }
    if (t.level < 0) {
      return Color.lerp(
        clear,
        const Color(0xFF8A8F96),
        (-t.level / 3).clamp(0.0, 1.0),
      )!;
    }
    return _levelUp[t.level.clamp(0, _levelUp.length - 1)];
  }

  static Color? woods(Woods w) => switch (w) {
    Woods.none => null,
    Woods.light => const Color(0xFF7CB342),
    Woods.heavy => const Color(0xFF2E7D32),
    Woods.ultraHeavy => const Color(0xFF1B3D1F),
  };
}
