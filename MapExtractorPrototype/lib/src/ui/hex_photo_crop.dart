import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../model/hex_coord.dart';
import 'extractor_controller.dart';
import 'source_overlay_view.dart';
import 'terrain_style.dart';

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
    final proj = PhotoProjection(source);
    final corners = proj.corners(hex);
    var src = Rect.fromPoints(corners.first, corners.first);
    for (final p in corners) {
      src = src.expandToInclude(Rect.fromPoints(p, p));
    }
    src = src.inflate(math.max(src.width, src.height) * _margin);
    src = src.intersect(Offset.zero & Size(img.width.toDouble(), img.height.toDouble()));
    if (src.isEmpty) return const SizedBox.shrink();
    return AspectRatio(
      aspectRatio: src.width / src.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
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
        image, src, dst, Paint()..filterQuality = FilterQuality.medium);
    final k = size.width / src.width;
    final outline = Path()
      ..addPolygon([for (final p in corners) (p - src.topLeft) * k], true);
    canvas.drawPath(
        outline,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = TerrainStyle.selected);
  }

  @override
  bool shouldRepaint(_CropPainter old) =>
      old.image != image || old.src != src || old.corners != corners;
}
