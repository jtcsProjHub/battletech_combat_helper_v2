import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../model/hex_coord.dart';
import '../model/hex_terrain.dart';
import 'hex_canvas.dart';
import 'hex_layout.dart';
import 'hex_selection.dart';
import 'map_sheet_draft.dart';
import 'terrain_style.dart';

/// Schematic hex map with selection. Shared with the future skirmish setup
/// editor: it only needs a draft, a selection and the current tool.
class HexMapView extends StatelessWidget {
  const HexMapView({
    super.key,
    required this.draft,
    required this.selection,
    required this.tool,
    required this.onToolChanged,
  });

  final MapSheetDraft draft;
  final HexSelection selection;
  final CanvasTool tool;
  final ValueChanged<CanvasTool> onToolChanged;

  @override
  Widget build(BuildContext context) {
    final layout = HexLayout(draft.grid);
    return HexCanvas(
      contentSize: layout.size,
      painter: _HexMapPainter(layout, draft, selection),
      grid: draft.grid,
      hexAt: layout.hitTest,
      centerOf: layout.center,
      selection: selection,
      tool: tool,
      onToolChanged: onToolChanged,
      hexRadius: layout.radius,
    );
  }
}

class _HexMapPainter extends CustomPainter {
  _HexMapPainter(this.layout, this.draft, this.selection);

  final HexLayout layout;
  final MapSheetDraft draft;
  final HexSelection selection;

  @override
  void paint(Canvas canvas, Size size) {
    final r = layout.radius;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = TerrainStyle.gridLine;
    final fill = Paint()..style = PaintingStyle.fill;

    for (final hex in draft.grid.allHexes) {
      final t = draft.terrainAt(hex);
      final path = layout.outline(hex);
      fill.color = TerrainStyle.fill(t);
      canvas.drawPath(path, fill);
      _paintFeatures(canvas, hex, t);
      canvas.drawPath(path, line);
      _text(canvas, hex.id, layout.center(hex) + Offset(0, -r * 0.62),
          r * 0.24, TerrainStyle.idText);
      final labels = t.printedLabels;
      for (var i = 0; i < labels.length; i++) {
        _text(canvas, labels[i],
            layout.center(hex) + Offset(0, r * (0.62 - 0.27 * (labels.length - 1 - i))),
            r * 0.23, TerrainStyle.labelText, bold: true);
      }
    }
    final review = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = TerrainStyle.review;
    for (final hex in draft.unverified) {
      if (hex.isInside(draft.grid.columns, draft.grid.rows)) {
        canvas.drawPath(layout.outline(hex), review);
      }
    }
    paintSelection(canvas, selection, layout.outline);
  }

  void _paintFeatures(Canvas canvas, HexCoord hex, HexTerrain t) {
    final c = layout.center(hex);
    final r = layout.radius;
    final woods = TerrainStyle.woods(t.woods);
    if (woods != null) {
      final p = Paint()..color = woods;
      final n = t.woods == Woods.light ? 3 : 5;
      for (var i = 0; i < n; i++) {
        final a = 2 * math.pi * i / n + 0.4;
        canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * r * 0.28, r * 0.17, p);
      }
    }
    if (t.features.contains(TerrainFeature.rough) ||
        t.features.contains(TerrainFeature.rubble)) {
      final p = Paint()..color = const Color(0xFF6D6D6D);
      for (final o in const [
        Offset(-0.35, 0.05), Offset(0.3, -0.1), Offset(0.05, 0.25),
        Offset(-0.1, -0.25), Offset(0.4, 0.25),
      ]) {
        canvas.drawCircle(c + o * r, r * 0.06, p);
      }
    }
  }

  void _text(Canvas canvas, String s, Offset center, double size, Color color,
      {bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: size,
          color: color,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_HexMapPainter old) => true;
}

/// Draws the selection: a tint and outline on every selected hex, and a
/// thicker outline on the primary hex. Shared by both views.
void paintSelection(
    Canvas canvas, HexSelection selection, Path Function(HexCoord) outline) {
  final tint = Paint()..color = TerrainStyle.selected.withAlpha(60);
  final edge = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..color = TerrainStyle.selected;
  for (final hex in selection.hexes) {
    final path = outline(hex);
    canvas.drawPath(path, tint);
    canvas.drawPath(path, edge);
  }
  final p = selection.primary;
  if (p != null) {
    canvas.drawPath(
        outline(p),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = TerrainStyle.selected);
  }
}
