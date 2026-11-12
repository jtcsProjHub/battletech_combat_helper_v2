// File: lib/widgets/map/source_overlay_view.dart
// A source photo with the fitted hex grid and the current terrain drawn on
// top, and the per-hex photo close-up used by the inspector. Ported from
// the Map Extractor prototype.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:map_extractor_prototype/map_extractor.dart';

import '../../maps/hex_layout.dart';
import '../../maps/hex_selection.dart';
import '../../maps/map_editor_controller.dart';
import '../../maps/map_sheet_draft.dart';
import 'hex_canvas.dart';
import 'hex_map_view.dart' show paintSelection;

/// Hex geometry projected onto one source photo preview.
class PhotoProjection {
  /// [source] must have a result.
  PhotoProjection(SourceEntry source)
    : toPreview = source.result!.extraction.homography.scaledOutput(
        source.result!.previewScale,
      ) {
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
      painter: _OverlayPainter(
        img,
        proj,
        r.previewScale,
        r.extraction,
        draft,
        selection,
        showOcrBoxes,
      ),
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
  _OverlayPainter(
    this.image,
    this.proj,
    this.scale,
    this.extraction,
    this.draft,
    this.selection,
    this.showOcrBoxes,
  );

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
      if (hex.isInside(draft.grid.columns, draft.grid.rows)) {
        canvas.drawPath(proj.outline(hex), review);
      }
    }
    paintSelection(canvas, selection, proj.outline);
    if (showOcrBoxes) {
      final box = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.cyanAccent;
      for (final w in extraction.words) {
        final rect = Rect.fromLTRB(
          w.x0 * scale,
          w.y0 * scale,
          w.x1 * scale,
          w.y1 * scale,
        );
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

/// A close-up of one hex cut from a source photo, with the fitted hex
/// outline drawn on top.
class HexPhotoCrop extends StatelessWidget {
  const HexPhotoCrop({super.key, required this.source, required this.hex});

  final SourceEntry source;
  final HexCoord hex;

  /// Context around the hex, as a fraction of the hex size on each side.
  static const _margin = 0.45;

  /// True when the centre of [hex] is inside the photo.
  static bool covers(SourceEntry source, HexCoord hex) {
    final img = source.preview;
    if (source.result == null || img == null) return false;
    final c = PhotoProjection(source).center(hex);
    return c.dx >= 0 && c.dy >= 0 && c.dx < img.width && c.dy < img.height;
  }

  @override
  Widget build(BuildContext context) {
    final img = source.preview!;
    final corners = PhotoProjection(source).corners(hex);
    var src = Rect.fromPoints(corners.first, corners.first);
    for (final p in corners) {
      src = src.expandToInclude(Rect.fromPoints(p, p));
    }
    src = src.inflate(math.max(src.width, src.height) * _margin);
    src = src.intersect(
      Offset.zero & Size(img.width.toDouble(), img.height.toDouble()),
    );
    if (src.isEmpty) return const SizedBox.shrink();
    return AspectRatio(
      aspectRatio: src.width / src.height,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF3A434C)),
        ),
        child: CustomPaint(painter: _CropPainter(img, src, corners)),
      ),
    );
  }
}

class _CropPainter extends CustomPainter {
  _CropPainter(this.image, this.src, this.corners);

  final ui.Image image;
  final Rect src;
  final List<Offset> corners;

  @override
  void paint(Canvas canvas, Size size) {
    final dst = Offset.zero & size;
    canvas.drawImageRect(
      image,
      src,
      dst,
      Paint()..filterQuality = FilterQuality.medium,
    );
    final k = size.width / src.width;
    final outline = Path()
      ..addPolygon([for (final p in corners) (p - src.topLeft) * k], true);
    canvas.drawPath(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = TerrainStyle.selected,
    );
  }

  @override
  bool shouldRepaint(_CropPainter old) =>
      old.image != image || old.src != src || old.corners != corners;
}
