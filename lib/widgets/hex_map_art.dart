// File: lib/widgets/hex_map_art.dart
// Placeholder art: a muted hex map with a few mech tokens and a movement
// path. Low contrast on purpose, so it fills space without pulling focus.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_theme.dart';

class HexMapArt extends StatelessWidget {
  const HexMapArt({super.key});

  @override
  Widget build(BuildContext context) {
    return const ExcludeSemantics(
      child: ClipRect(
        child: CustomPaint(painter: _HexMapPainter(), child: SizedBox.expand()),
      ),
    );
  }
}

/// A token at a position given as a fraction of the grid size, so the
/// layout keeps its shape when the panel resizes.
class _Token {
  const _Token(this.fx, this.fy, this.facing, this.friendly);

  final double fx;
  final double fy;

  /// Hex side the token faces, 0 = up, then clockwise.
  final int facing;
  final bool friendly;
}

class _HexMapPainter extends CustomPainter {
  const _HexMapPainter();

  static const double _r = 34; // hex circumradius in px
  static final double _h = math.sqrt(3) * _r; // flat-top hex height

  static const _gridLine = Color(0xFF222930);
  static const _woods = Color(0xFF151C1A);
  static const _rough = Color(0xFF1A1E23);
  static const _friendly = Color(0x99F28A1E); // accent, 60 %
  static const _enemy = Color(0x995C6670);
  static const _path = Color(0x55F28A1E);

  static const _tokens = [
    _Token(0.22, 0.38, 1, true),
    _Token(0.30, 0.58, 1, true),
    _Token(0.18, 0.66, 0, true),
    _Token(0.26, 0.80, 1, true),
    _Token(0.74, 0.30, 4, false),
    _Token(0.80, 0.52, 5, false),
    _Token(0.70, 0.70, 4, false),
  ];

  /// Terrain patches as (fx, fy, radius in hexes, color).
  static const _patches = [
    (0.50, 0.22, 2, _woods),
    (0.56, 0.74, 1, _rough),
    (0.42, 0.50, 1, _woods),
    (0.88, 0.86, 2, _rough),
  ];

  Offset _center(int col, int row) =>
      Offset(_r + col * 1.5 * _r, _h / 2 + row * _h + (col.isOdd ? _h / 2 : 0));

  (int, int) _cell(Size size, double fx, double fy) {
    final col = ((fx * size.width - _r) / (1.5 * _r)).round();
    final row = ((fy * size.height - _h / 2) / _h).round();
    return (math.max(0, col), math.max(0, row));
  }

  Path _hex(Offset c, double r) {
    final p = Path();
    for (var i = 0; i < 6; i++) {
      final a = math.pi / 3 * i;
      final pt = c + Offset(math.cos(a) * r, math.sin(a) * r);
      if (i == 0) {
        p.moveTo(pt.dx, pt.dy);
      } else {
        p.lineTo(pt.dx, pt.dy);
      }
    }
    return p..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cols = (size.width / (1.5 * _r)).ceil() + 1;
    final rows = (size.height / _h).ceil() + 1;

    // Terrain fills.
    for (final (fx, fy, radius, color) in _patches) {
      final (pc, pr) = _cell(size, fx, fy);
      final fill = Paint()..color = color;
      for (var c = pc - radius; c <= pc + radius; c++) {
        for (var r = pr - radius; r <= pr + radius; r++) {
          final d = (_center(c, r) - _center(pc, pr)).distance;
          if (d <= radius * _h + 1) {
            canvas.drawPath(_hex(_center(c, r), _r - 1), fill);
          }
        }
      }
    }

    // Grid.
    final line = Paint()
      ..color = _gridLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var c = 0; c < cols; c++) {
      for (var r = 0; r < rows; r++) {
        canvas.drawPath(_hex(_center(c, r), _r), line);
      }
    }

    // Movement path from the lead friendly token.
    final (sc, sr) = _cell(size, _tokens[0].fx, _tokens[0].fy);
    final (ec, er) = _cell(size, 0.48, 0.34);
    _dashed(canvas, _center(sc, sr), _center(ec, er), _path);
    canvas.drawPath(
      _hex(_center(ec, er), _r - 4),
      Paint()
        ..color = _path
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Tokens.
    for (final t in _tokens) {
      final (c, r) = _cell(size, t.fx, t.fy);
      _token(canvas, _center(c, r), t);
    }
  }

  void _token(Canvas canvas, Offset c, _Token t) {
    final color = t.friendly ? _friendly : _enemy;
    canvas.drawCircle(c, _r * 0.5, Paint()..color = AppColors.background);
    canvas.drawCircle(
      c,
      _r * 0.5,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // Facing wedge on the side the token faces.
    final a = -math.pi / 2 + t.facing * math.pi / 3;
    final tip = c + Offset(math.cos(a), math.sin(a)) * (_r * 0.82);
    final l = c + Offset(math.cos(a - 0.45), math.sin(a - 0.45)) * (_r * 0.5);
    final rr = c + Offset(math.cos(a + 0.45), math.sin(a + 0.45)) * (_r * 0.5);
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(l.dx, l.dy)
        ..lineTo(rr.dx, rr.dy)
        ..close(),
      Paint()..color = color,
    );
    // Simple mech mark: torso block with two arms.
    final mark = Paint()..color = color;
    canvas.drawRect(Rect.fromCenter(center: c, width: 8, height: 10), mark);
    canvas.drawRect(
      Rect.fromCenter(center: c + const Offset(-7, 1), width: 3, height: 9),
      mark,
    );
    canvas.drawRect(
      Rect.fromCenter(center: c + const Offset(7, 1), width: 3, height: 9),
      mark,
    );
  }

  void _dashed(Canvas canvas, Offset a, Offset b, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    final total = (b - a).distance;
    if (total == 0) return;
    final dir = (b - a) / total;
    const dash = 7.0, gap = 6.0;
    for (var d = _r * 0.6; d < total - _r * 0.4; d += dash + gap) {
      final end = math.min(d + dash, total - _r * 0.4);
      canvas.drawLine(a + dir * d, a + dir * end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
