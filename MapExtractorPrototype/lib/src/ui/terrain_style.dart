import 'package:flutter/material.dart';

import '../model/hex_terrain.dart';

/// Colors for the schematic map. Kept in one place so the main app can
/// share them with the setup editor.
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
      return Color.lerp(const Color(0xFF8EC5E8), const Color(0xFF1F5F8B),
          ((t.waterDepth - 1) / 3).clamp(0.0, 1.0))!;
    }
    if (t.level < 0) {
      return Color.lerp(clear, const Color(0xFF8A8F96), (-t.level / 3).clamp(0.0, 1.0))!;
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
