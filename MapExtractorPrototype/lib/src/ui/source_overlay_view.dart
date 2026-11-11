import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../extract/homography.dart';
import '../extract/image_extractor.dart';
import '../extract/label_parser.dart';
import '../model/hex_coord.dart';
import 'extractor_controller.dart';
import 'hex_canvas.dart';
import 'hex_map_view.dart';
import 'hex_selection.dart';
import 'map_sheet_draft.dart';
import 'terrain_style.dart';

/// Hex geometry projected onto one source photo preview.
class PhotoProjection {
  /// [source] must have a result.
  PhotoProjection(SourceEntry source)
      : toPreview = source.result!.extraction.homography
            .scaledOutput(source.result!.previewScale) {
    fromPreview = toPreview.inverse();
  }

  final Homography toPreview;
  late final Homography fromPreview;

  Offset _project((double, double) g) {
    final (x, y) = toPreview.project(g.$1, g.$2);
    return Offset(x, y);
  }

  Offset center(HexCoord hex) => _project(SheetGeometry.hexCenter(hex));

  List<Offset> corners(HexCoord hex) => [
        for (final g in SheetGeometry.hexCorners(SheetGeometry.hexCenter(hex)))
          _project(g),
      ];

  Path outline(HexCoord hex) => Path()..addPolygon(corners(hex), true);

  HexCoord hexAt(Offset p) {
    final (u, v) = fromPreview.project(p.dx, p.dy);
    return SheetGeometry.hexAt(u, v);
  }
}

/// The source photo with the fitted hex grid and the current terrain drawn
/// on top.
class SourceOverlayView extends StatelessWidget {
  const SourceOverlayView({
    super.key,
    required this.source,
    required this.draft,
    required this.selection,
    required this.showOcrBoxes,
    required this.tool,
    required this.onToolChanged,
  });

  final SourceEntry source;
  final MapSheetDraft draft;
  final HexSelection selection;
  final bool showOcrBoxes;
  final CanvasTool tool;
  final ValueChanged<CanvasTool> onToolChanged;

  @override
  Widget build(BuildContext context) {
    final r = source.result;
    final img = source.preview;
    if (r == null || img == null) {
      return Center(child: Text(source.error ?? 'Not extracted yet.'));
    }
    final proj = PhotoProjection(source);
    final size = Size(img.width.toDouble(), img.height.toDouble());
    final bounds = Offset.zero & size;
    // Approximate hex radius in preview pixels, for brush sampling.
    final c = proj.corners(const HexCoord(8, 9));
    final radius = (c[0] - c[3]).distance / 2;
    return HexCanvas(
      contentSize: size,
      painter: _OverlayPainter(img, proj, r.previewScale, r.extraction, draft,
          selection, showOcrBoxes),
      grid: draft.grid,
      hexAt: (p) {
        if (!bounds.contains(p)) return null;
        final hex = proj.hexAt(p);
        return hex.isInside(draft.grid.columns, draft.grid.rows) ? hex : null;
      },
      // Hexes outside the photo must never fall inside a selection box.
      centerOf: (hex) {
        final p = proj.center(hex);
        return bounds.contains(p) ? p : const Offset(-1e9, -1e9);
      },
      selection: selection,
      tool: tool,
      onToolChanged: onToolChanged,
      hexRadius: radius.isFinite && radius > 0 ? radius : 40,
    );
  }
}

class _OverlayPainter extends CustomPainter {
  _OverlayPainter(this.image, this.proj, this.scale, this.extraction, this.draft,
      this.selection, this.showOcrBoxes);

  final ui.Image image;
  final PhotoProjection proj;
  final double scale;
  final ImageExtraction extraction;
  final MapSheetDraft draft;
  final HexSelection selection;
  final bool showOcrBoxes;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    canvas.drawImage(image, Offset.zero, Paint());
    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xCCFF00FF);
    for (final hex in draft.grid.allHexes) {
      canvas.drawPath(proj.outline(hex), grid);
      final labels = draft.terrainAt(hex).printedLabels;
      if (labels.isEmpty) continue;
      final c = proj.center(hex);
      final tp = TextPainter(
        text: TextSpan(
          text: labels.join('\n'),
          style: const TextStyle(
            color: TerrainStyle.ocrText,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            shadows: [Shadow(color: Colors.white, blurRadius: 3)],
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - tp.height / 2));
    }
    final review = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = TerrainStyle.review;
    for (final hex in draft.unverified) {
      canvas.drawPath(proj.outline(hex), review);
    }
    paintSelection(canvas, selection, proj.outline);
    if (showOcrBoxes) {
      final box = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.cyanAccent;
      for (final w in extraction.words) {
        final rect = Rect.fromLTRB(
            w.x0 * scale, w.y0 * scale, w.x1 * scale, w.y1 * scale);
        canvas.drawRect(rect, box);
        final isId = LabelParser.parseHexId(w.text) != null;
        final tp = TextPainter(
          text: TextSpan(
            text: w.text,
            style: TextStyle(
              color: isId ? Colors.cyanAccent : Colors.yellowAccent,
              fontSize: 10,
              backgroundColor: const Color(0xAA000000),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, rect.bottomLeft);
      }
    }
  }

  @override
  bool shouldRepaint(_OverlayPainter old) => true;
}
