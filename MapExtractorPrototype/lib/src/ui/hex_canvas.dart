import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../model/hex_coord.dart';
import '../model/map_sheet.dart';
import 'hex_selection.dart';
import 'terrain_style.dart';

/// Zoomable, pannable hex content with click, box and brush selection.
///
/// The content can be the schematic map or a photo. The caller gives the
/// content size, a painter, and two functions in content coordinates:
/// [hexAt] (point to hex) and [centerOf] (hex to point). The same widget
/// works for the setup editor in the main app.
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
    final s = (math.min(_viewport.width / c.width, _viewport.height / c.height) * 0.96)
        .clamp(_minScale, _maxScale);
    final tx = (_viewport.width - c.width * s) / 2;
    final ty = (_viewport.height - c.height * s) / 2;
    _tc.value = Matrix4.translationValues(tx, ty, 0)
        .multiplied(Matrix4.diagonal3Values(s, s, 1));
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

  // ---------------------------------------------------------------- pointer

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
        final steps = math.max(1, ((to - from).distance / (widget.hexRadius / 3)).ceil());
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
      widget.selection.click(widget.hexAt(_downLocal), widget.grid,
          shift: _shift, ctrl: _ctrl);
    }
    _reset();
  }

  void _reset() {
    _pointer = null;
    _dragging = false;
    _box.value = null;
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
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
            child: _ToolBar(tool: widget.tool, onChanged: widget.onToolChanged),
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
    });
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
          ..color = TerrainStyle.selected);
  }

  @override
  bool shouldRepaint(_BoxPainter old) => old.box != box;
}

class _ToolBar extends StatelessWidget {
  const _ToolBar({required this.tool, required this.onChanged});
  final CanvasTool tool;
  final ValueChanged<CanvasTool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(8),
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: SegmentedButton<CanvasTool>(
          segments: const [
            ButtonSegment(
                value: CanvasTool.pan,
                icon: Icon(Icons.pan_tool_outlined),
                tooltip: 'Pan: drag moves the view (H)'),
            ButtonSegment(
                value: CanvasTool.box,
                icon: Icon(Icons.highlight_alt),
                tooltip: 'Box select: Shift adds, Ctrl removes (B)'),
            ButtonSegment(
                value: CanvasTool.brush,
                icon: Icon(Icons.brush_outlined),
                tooltip: 'Brush select: Shift adds, Ctrl erases (P)'),
          ],
          selected: {tool},
          showSelectedIcon: false,
          onSelectionChanged: (s) => onChanged(s.first),
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
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(8),
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Zoom out',
              onPressed: () => onChanged(scale / 1.25),
              icon: const Icon(Icons.remove),
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
            IconButton(
              tooltip: 'Zoom in',
              onPressed: () => onChanged(scale * 1.25),
              icon: const Icon(Icons.add),
            ),
            SizedBox(
              width: 48,
              child: Text('${(scale * 100).round()}%', textAlign: TextAlign.center),
            ),
            IconButton(
              tooltip: 'Fit to view',
              onPressed: onFit,
              icon: const Icon(Icons.fit_screen_outlined),
            ),
          ],
        ),
      ),
    );
  }
}
