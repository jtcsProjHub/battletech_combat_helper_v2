// File: lib/widgets/skirmish/skirmish_map_view.dart
// The skirmish map with its overlay applied, on the shared HexCanvas.
// Hexes changed for this skirmish carry an inset outline, so players can
// see at a glance where the screen differs from the printed sheet.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:map_extractor_prototype/map_extractor.dart';

import '../../maps/hex_layout.dart';
import '../../maps/hex_selection.dart';
import '../../skirmish/skirmish_map.dart';
import '../map/hex_canvas.dart';
import '../map/hex_map_view.dart';

/// Outline color for hexes changed from the printed sheet. Distinct from
/// the selection blue and the review orange.
const overlayMarkColor = Color(0xFF8E24AA);

/// Lighter shade of [overlayMarkColor], readable as text on dark panels.
const overlayMarkColorLight = Color(0xFFCE93D8);

class SkirmishMapView extends StatelessWidget {
  const SkirmishMapView({
    super.key,
    required this.map,
    required this.selection,
    required this.tool,
    required this.onToolChanged,
  });

  final SkirmishMap map;
  final HexSelection selection;
  final CanvasTool tool;
  final ValueChanged<CanvasTool> onToolChanged;

  @override
  Widget build(BuildContext context) {
    final layout = HexLayout(map.grid);
    return HexCanvas(
      contentSize: layout.size,
      painter: _SkirmishMapPainter(layout, map, selection),
      grid: map.grid,
      hexAt: layout.hitTest,
      centerOf: layout.center,
      selection: selection,
      tool: tool,
      onToolChanged: onToolChanged,
      hexRadius: layout.radius,
    );
  }
}

/// A skirmish map drawn to fit its box, without interaction: the merged
/// terrain, the change marks, and building heights. For previews.
class SkirmishMapThumbnail extends StatelessWidget {
  const SkirmishMapThumbnail({super.key, required this.map});

  final SkirmishMap map;

  @override
  Widget build(BuildContext context) {
    final layout = HexLayout(map.grid);
    return ExcludeSemantics(
      child: FittedBox(
        child: CustomPaint(
          size: layout.size,
          painter: _SkirmishMapPainter(layout, map, null),
        ),
      ),
    );
  }
}

class _SkirmishMapPainter extends CustomPainter {
  _SkirmishMapPainter(this.layout, this.map, this.selection);

  final HexLayout layout;
  final SkirmishMap map;

  /// Null for thumbnails.
  final HexSelection? selection;

  @override
  void paint(Canvas canvas, Size size) {
    paintTerrain(canvas, layout, map.terrainAt);
    final mark = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = overlayMarkColor;
    for (final MapEntry(key: hex, value: o) in map.overlay.entries) {
      canvas.drawPath(_inset(hex, 0.8), mark);
      if (o.buildingHeight case final h?) _paintHeight(canvas, hex, h);
    }
    if (selection case final s?) paintSelection(canvas, s, layout.outline);
  }

  /// The building height in the middle of the hex, between the hex id
  /// and the BUILDING label.
  void _paintHeight(Canvas canvas, HexCoord hex, int height) {
    final tp = TextPainter(
      text: TextSpan(
        text: 'HEIGHT $height',
        style: TextStyle(
          fontSize: layout.radius * 0.26,
          fontWeight: FontWeight.w800,
          color: overlayMarkColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, layout.center(hex) - Offset(tp.width / 2, tp.height / 2));
    tp.dispose();
  }

  /// The hex outline shrunk toward its center, so the mark sits inside
  /// the grid line and the selection outline.
  Path _inset(HexCoord hex, double scale) {
    final c = layout.center(hex);
    final m = Float64List(16)
      ..[0] = scale
      ..[5] = scale
      ..[10] = 1
      ..[15] = 1
      ..[12] = c.dx * (1 - scale)
      ..[13] = c.dy * (1 - scale);
    return layout.outline(hex).transform(m);
  }

  @override
  bool shouldRepaint(_SkirmishMapPainter old) => true;
}
