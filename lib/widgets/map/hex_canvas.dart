// File: lib/widgets/map/hex_canvas.dart
// Zoomable, pannable hex content with click, box and brush selection.
// Ported from the Map Extractor prototype. The content can be the schematic
// map or a photo: the caller gives the content size, a painter, and two
// functions in content coordinates, [hexAt] (point to hex) and [centerOf]
// (hex to point).

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:map_extractor_prototype/map_extractor.dart';

import '../../app_theme.dart';
import '../../maps/hex_layout.dart';
import '../../maps/hex_selection.dart';

class HexCanvas extends StatefulWidget {
  const HexCanvas({
    super.key,
    required this.contentSize,
    required this.painter,
    required this.grid,
    required this.hexAt,
    required this.centerOf,
    required this.selection,
    required this.tool,
    required this.onToolChanged,
    this.hexRadius = 40,
  });

  final Size contentSize;
  final CustomPainter painter;
  final GridSpec grid;
  final HexCoord? Function(Offset contentPoint) hexAt;
  final Offset Function(HexCoord hex) centerOf;
  final HexSelection selection;
  final CanvasTool tool;
  final ValueChanged<CanvasTool> onToolChanged;

  /// Approximate hex radius in content units, used for brush sampling.
  final double hexRadius;

  @override
  State<HexCanvas> createState() => _HexCanvasState();
}

class _HexCanvasState extends State<HexCanvas> {
  static const _minScale = 0.05;
  static const _maxScale = 8.0;
  static const _dragSlop = 4.0;

  final _tc = TransformationController();
  final _box = ValueNotifier<Rect?>(null);

  /// Taking focus on click moves it out of any text field, so the screen's
  /// keyboard shortcuts work again.
  final _focus = FocusNode(debugLabel: 'HexCanvas');
  Size _viewport = Size.zero;
  bool _fitted = false;

  // Pointer state for one press.
  int? _pointer;
  Offset _downLocal = Offset.zero;
  Offset _downGlobal = Offset.zero;
  Offset _lastLocal = Offset.zero;
  bool _dragging = false;
  bool _shift = false;
  bool _ctrl = false;
  Set<HexCoord> _base = {};

  @override
  void dispose() {
    _tc.dispose();
    _box.dispose();
    _focus.dispose();
    super.dispose();
  }

  double get _scale => _tc.value.getMaxScaleOnAxis();

  void _fit() {
    if (_viewport.isEmpty) return;
    final c = widget.contentSize;
    final s =
        (math.min(_viewport.width / c.width, _viewport.height / c.height) *
                0.96)
            .clamp(_minScale, _maxScale);
    final tx = (_viewport.width - c.width * s) / 2;
    final ty = (_viewport.height - c.height * s) / 2;
    _tc.value = Matrix4.translationValues(
      tx,
      ty,
      0,
    ).multiplied(Matrix4.diagonal3Values(s, s, 1));
  }

  /// Zooms around the centre of the viewport.
  void _zoomTo(double target) {
    final s = target.clamp(_minScale, _maxScale);
    final k = s / _scale;
    final cx = _viewport.width / 2, cy = _viewport.height / 2;
    final m = Matrix4.translationValues(cx, cy, 0)
        .multiplied(Matrix4.diagonal3Values(k, k, 1))
        .multiplied(Matrix4.translationValues(-cx, -cy, 0));
    _tc.value = m.multiplied(_tc.value);
  }

  void _onDown(PointerDownEvent e) {
    _focus.requestFocus();
    if (_pointer != null || e.buttons != kPrimaryMouseButton) return;
    final kb = HardwareKeyboard.instance;
    _pointer = e.pointer;
    _downLocal = e.localPosition;
    _lastLocal = e.localPosition;
    _downGlobal = e.position;
    _dragging = false;
    _shift = kb.isShiftPressed;
    _ctrl = kb.isControlPressed || kb.isMetaPressed;
  }

  void _onMove(PointerMoveEvent e) {
    if (e.pointer != _pointer) return;
    if (!_dragging) {
      if ((e.position - _downGlobal).distance < _dragSlop) return;
      if (widget.tool == CanvasTool.pan) return; // InteractiveViewer pans
      _dragging = true;
      _base = widget.tool == CanvasTool.box && (_shift || _ctrl)
          ? widget.selection.hexes
          : <HexCoord>{};
      widget.selection.beginDrag(shift: _shift, ctrl: _ctrl);
      if (widget.tool == CanvasTool.brush) _brushAt(_downLocal);
    }
    switch (widget.tool) {
      case CanvasTool.box:
        final rect = Rect.fromPoints(_downLocal, e.localPosition);
        _box.value = rect;
        widget.selection.applyBox(
          _base,
          widget.grid.allHexes.where((h) => rect.contains(widget.centerOf(h))),
          shift: _shift,
          ctrl: _ctrl,
        );
      case CanvasTool.brush:
        // Sample the segment so fast strokes do not skip hexes.
        final from = _lastLocal, to = e.localPosition;
        final steps = math.max(
          1,
          ((to - from).distance / (widget.hexRadius / 3)).ceil(),
        );
        for (var i = 1; i <= steps; i++) {
          _brushAt(Offset.lerp(from, to, i / steps)!);
        }
      case CanvasTool.pan:
        break;
    }
    _lastLocal = e.localPosition;
  }

  void _brushAt(Offset p) {
    final hex = widget.hexAt(p);
    if (hex != null) widget.selection.brush(hex, erase: _ctrl);
  }

  void _onUp(PointerUpEvent e) {
    if (e.pointer != _pointer) return;
    if (!_dragging) {
      widget.selection.click(
        widget.hexAt(_downLocal),
        widget.grid,
        shift: _shift,
        ctrl: _ctrl,
      );
    }
    _reset();
  }

  void _reset() {
    _pointer = null;
    _dragging = false;
    _box.value = null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = constraints.biggest;
        if (!_fitted) {
          _fitted = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _fit();
          });
        }
        return Focus(
          focusNode: _focus,
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  transformationController: _tc,
                  constrained: false,
                  minScale: _minScale,
                  maxScale: _maxScale,
                  boundaryMargin: const EdgeInsets.all(double.infinity),
                  panEnabled: widget.tool == CanvasTool.pan,
                  child: Listener(
                    onPointerDown: _onDown,
                    onPointerMove: _onMove,
                    onPointerUp: _onUp,
                    onPointerCancel: (_) => _reset(),
                    child: CustomPaint(
                      size: widget.contentSize,
                      painter: widget.painter,
                      foregroundPainter: _BoxPainter(_box, _tc),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                top: 12,
                child: _ToolBar(
                  tool: widget.tool,
                  onChanged: widget.onToolChanged,
                ),
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: ListenableBuilder(
                  listenable: _tc,
                  builder: (context, _) => _ZoomBar(
                    scale: _scale,
                    min: _minScale,
                    max: _maxScale,
                    onChanged: _zoomTo,
                    onFit: _fit,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BoxPainter extends CustomPainter {
  _BoxPainter(this.box, this.tc) : super(repaint: Listenable.merge([box, tc]));

  final ValueNotifier<Rect?> box;
  final TransformationController tc;

  @override
  void paint(Canvas canvas, Size size) {
    final r = box.value;
    if (r == null) return;
    final s = tc.value.getMaxScaleOnAxis();
    canvas.drawRect(r, Paint()..color = TerrainStyle.selected.withAlpha(40));
    canvas.drawRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 / s
        ..color = TerrainStyle.selected,
    );
  }

  @override
  bool shouldRepaint(_BoxPainter old) => old.box != box;
}

/// Floating HUD strip that holds the tool and zoom controls.
class _FloatingBar extends StatelessWidget {
  const _FloatingBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.panel.withAlpha(235),
        border: Border.all(color: AppColors.borderStrong),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 8)],
      ),
      child: child,
    );
  }
}

class _ToolBar extends StatelessWidget {
  const _ToolBar({required this.tool, required this.onChanged});

  final CanvasTool tool;
  final ValueChanged<CanvasTool> onChanged;

  static const _tools = [
    (CanvasTool.pan, Icons.pan_tool_outlined, 'Pan: drag moves the view (H)'),
    (
      CanvasTool.box,
      Icons.highlight_alt,
      'Box select: Shift adds, Ctrl removes (B)',
    ),
    (
      CanvasTool.brush,
      Icons.brush_outlined,
      'Brush select: Shift adds, Ctrl erases (P)',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _FloatingBar(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (t, icon, tip) in _tools)
            _BarIconButton(
              icon: icon,
              tooltip: tip,
              selected: t == tool,
              onPressed: () => onChanged(t),
            ),
        ],
      ),
    );
  }
}

class _BarIconButton extends StatelessWidget {
  const _BarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      isSelected: selected,
      onPressed: onPressed,
      icon: Icon(icon),
      style:
          IconButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            backgroundColor: Colors.transparent,
            shape: const RoundedRectangleBorder(),
          ).copyWith(
            foregroundColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected)
                  ? AppColors.background
                  : AppColors.textSecondary,
            ),
            backgroundColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected)
                  ? AppColors.accent
                  : Colors.transparent,
            ),
          ),
    );
  }
}

class _ZoomBar extends StatelessWidget {
  const _ZoomBar({
    required this.scale,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.onFit,
  });

  final double scale;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final VoidCallback onFit;

  @override
  Widget build(BuildContext context) {
    // The slider is logarithmic, so each step changes the zoom by the
    // same factor.
    final lo = math.log(min), hi = math.log(max);
    final v = math.log(scale).clamp(lo, hi);
    return _FloatingBar(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BarIconButton(
            icon: Icons.remove,
            tooltip: 'Zoom out',
            onPressed: () => onChanged(scale / 1.25),
          ),
          SizedBox(
            width: 160,
            child: Slider(
              value: v,
              min: lo,
              max: hi,
              onChanged: (x) => onChanged(math.exp(x)),
            ),
          ),
          _BarIconButton(
            icon: Icons.add,
            tooltip: 'Zoom in',
            onPressed: () => onChanged(scale * 1.25),
          ),
          SizedBox(
            width: 52,
            child: Text(
              '${(scale * 100).round()}%',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          _BarIconButton(
            icon: Icons.fit_screen_outlined,
            tooltip: 'Fit to view',
            onPressed: onFit,
          ),
        ],
      ),
    );
  }
}
