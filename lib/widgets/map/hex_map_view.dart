// File: lib/widgets/map/hex_map_view.dart
// The schematic hex map: an editable view with selection for the map
// editor, and a static thumbnail for saved-map lists. Both use the same
// terrain painting. Ported from the Map Extractor prototype.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:map_extractor_prototype/map_extractor.dart';

import '../../maps/hex_layout.dart';
import '../../maps/hex_selection.dart';
import '../../maps/map_sheet_draft.dart';
import 'hex_canvas.dart';

/// Editable schematic map. It only needs a draft, a selection and the
/// current tool, so the skirmish setup editor can reuse it.
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

/// A saved map drawn to fit its box, without interaction.
class MapThumbnail extends StatelessWidget {
  const MapThumbnail({super.key, required this.sheet, this.showLabels = true});

  final MapSheet sheet;

  /// Hex ids and terrain labels. Turn off for small thumbnails.
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    final layout = HexLayout(sheet.grid);
    return ExcludeSemantics(
      child: FittedBox(
        child: CustomPaint(
          size: layout.size,
          painter: _ThumbnailPainter(layout, sheet, showLabels),
        ),
      ),
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
    paintTerrain(canvas, layout, draft.terrainAt);
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

  @override
  bool shouldRepaint(_HexMapPainter old) => true;
}

class _ThumbnailPainter extends CustomPainter {
  _ThumbnailPainter(this.layout, this.sheet, this.showLabels);

  final HexLayout layout;
  final MapSheet sheet;
  final bool showLabels;

  @override
  void paint(Canvas canvas, Size size) =>
      paintTerrain(canvas, layout, sheet.terrainAt, labels: showLabels);

  @override
  bool shouldRepaint(_ThumbnailPainter old) =>
      old.sheet != sheet || old.showLabels != showLabels;
}

/// Fills, woods and rough marks, grid lines, hex ids and printed labels for
/// every hex in [layout].
void paintTerrain(
  Canvas canvas,
  HexLayout layout,
  HexTerrain Function(HexCoord) terrainAt, {
  bool labels = true,
}) {
  final r = layout.radius;
  final line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..color = TerrainStyle.gridLine;
  final fill = Paint()..style = PaintingStyle.fill;

  for (final hex in layout.grid.allHexes) {
    final t = terrainAt(hex);
    final path = layout.outline(hex);
    fill.color = TerrainStyle.fill(t);
    canvas.drawPath(path, fill);
    _paintFeatures(canvas, layout, hex, t);
    canvas.drawPath(path, line);
    if (!labels) continue;
    final c = layout.center(hex);
    _text(
      canvas,
      hex.id,
      c + Offset(0, -r * 0.62),
      r * 0.24,
      TerrainStyle.idText,
    );
    final printed = t.printedLabels;
    for (var i = 0; i < printed.length; i++) {
      _text(
        canvas,
        printed[i],
        c + Offset(0, r * (0.62 - 0.27 * (printed.length - 1 - i))),
        r * 0.23,
        TerrainStyle.labelText,
        bold: true,
      );
    }
  }
}

void _paintFeatures(
  Canvas canvas,
  HexLayout layout,
  HexCoord hex,
  HexTerrain t,
) {
  final c = layout.center(hex);
  final r = layout.radius;
  final woods = TerrainStyle.woods(t.woods);
  if (woods != null) {
    final p = Paint()..color = woods;
    final n = t.woods == Woods.light ? 3 : 5;
    for (var i = 0; i < n; i++) {
      final a = 2 * math.pi * i / n + 0.4;
      canvas.drawCircle(
        c + Offset(math.cos(a), math.sin(a)) * r * 0.28,
        r * 0.17,
        p,
      );
    }
  }
  if (t.features.contains(TerrainFeature.rough) ||
      t.features.contains(TerrainFeature.rubble)) {
    final p = Paint()..color = const Color(0xFF6D6D6D);
    for (final o in const [
      Offset(-0.35, 0.05),
      Offset(0.3, -0.1),
      Offset(0.05, 0.25),
      Offset(-0.1, -0.25),
      Offset(0.4, 0.25),
    ]) {
      canvas.drawCircle(c + o * r, r * 0.06, p);
    }
  }
}

void _text(
  Canvas canvas,
  String s,
  Offset center,
  double size,
  Color color, {
  bool bold = false,
}) {
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

/// Draws the selection: a tint and outline on every selected hex, and a
/// thicker outline on the primary hex. Shared by the map and photo views.
void paintSelection(
  Canvas canvas,
  HexSelection selection,
  Path Function(HexCoord) outline,
) {
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
        ..color = TerrainStyle.selected,
    );
  }
}
