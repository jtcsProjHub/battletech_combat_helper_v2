import 'package:flutter/foundation.dart';

import '../model/hex_coord.dart';
import '../model/map_sheet.dart';

/// What a drag on the map does.
enum CanvasTool {
  /// Drag pans the view.
  pan,

  /// Drag draws a box. Hexes with their centre inside the box are selected.
  box,

  /// Drag paints: every hex under the pointer is selected.
  brush,
}

/// Multi-hex selection with the usual desktop modifiers.
///
/// - Click: select one hex.
/// - Ctrl+click: add or remove one hex.
/// - Shift+click: select the block of columns and rows between the last
///   clicked hex and this one.
/// - Box or brush drag: replace the selection. Hold Shift to add, Ctrl to
///   remove.
///
/// [primary] is the hex that the inspector shows photos and OCR evidence
/// for. It is the last hex that was clicked.
class HexSelection extends ChangeNotifier {
  final Set<HexCoord> _hexes = {};
  HexCoord? _primary;
  HexCoord? _anchor;

  Set<HexCoord> get hexes => Set.unmodifiable(_hexes);
  HexCoord? get primary => _primary;
  bool get isEmpty => _hexes.isEmpty;
  int get length => _hexes.length;
  bool contains(HexCoord hex) => _hexes.contains(hex);

  /// A click on [hex], or on empty space when [hex] is null.
  void click(HexCoord? hex, GridSpec grid, {bool shift = false, bool ctrl = false}) {
    if (hex == null) {
      if (!shift && !ctrl) clear();
      return;
    }
    if (ctrl) {
      if (!_hexes.remove(hex)) _hexes.add(hex);
      _primary = _hexes.contains(hex) ? hex : (_hexes.isEmpty ? null : _hexes.last);
      _anchor = hex;
    } else if (shift && _anchor != null) {
      final a = _anchor!;
      _hexes.addAll(_block(a, hex, grid));
      _primary = hex;
    } else {
      _hexes
        ..clear()
        ..add(hex);
      _primary = hex;
      _anchor = hex;
    }
    notifyListeners();
  }

  /// Selects exactly [hex], for example from "next to review".
  void selectOnly(HexCoord hex) {
    _hexes
      ..clear()
      ..add(hex);
    _primary = hex;
    _anchor = hex;
    notifyListeners();
  }

  /// Start of a box or brush drag.
  void beginDrag({bool shift = false, bool ctrl = false}) {
    if (!shift && !ctrl) {
      _hexes.clear();
      _primary = null;
      notifyListeners();
    }
  }

  /// Applies a box result. [base] is the selection when the drag started.
  void applyBox(Set<HexCoord> base, Iterable<HexCoord> inBox,
      {bool shift = false, bool ctrl = false}) {
    _hexes
      ..clear()
      ..addAll(base);
    if (ctrl) {
      _hexes.removeAll(inBox);
    } else {
      _hexes.addAll(inBox);
    }
    if (_primary == null || !_hexes.contains(_primary)) {
      _primary = _hexes.isEmpty ? null : _hexes.first;
    }
    notifyListeners();
  }

  /// One hex under the brush.
  void brush(HexCoord hex, {bool erase = false}) {
    final changed = erase ? _hexes.remove(hex) : _hexes.add(hex);
    if (!erase) {
      _primary ??= hex;
      _anchor = hex;
    } else if (_primary == hex) {
      _primary = _hexes.isEmpty ? null : _hexes.first;
    }
    if (changed) notifyListeners();
  }

  void selectAll(GridSpec grid) {
    _hexes
      ..clear()
      ..addAll(grid.allHexes);
    _primary ??= _hexes.isEmpty ? null : _hexes.first;
    notifyListeners();
  }

  void clear() {
    if (_hexes.isEmpty && _primary == null) return;
    _hexes.clear();
    _primary = null;
    notifyListeners();
  }

  /// Drops hexes outside [grid], after the grid size changes.
  void clip(GridSpec grid) {
    final before = _hexes.length;
    _hexes.removeWhere((h) => !h.isInside(grid.columns, grid.rows));
    if (_primary != null && !_hexes.contains(_primary)) {
      _primary = _hexes.isEmpty ? null : _hexes.first;
    }
    if (_hexes.length != before) notifyListeners();
  }

  static Iterable<HexCoord> _block(HexCoord a, HexCoord b, GridSpec grid) sync* {
    final c0 = a.col < b.col ? a.col : b.col, c1 = a.col < b.col ? b.col : a.col;
    final r0 = a.row < b.row ? a.row : b.row, r1 = a.row < b.row ? b.row : a.row;
    for (var c = c0; c <= c1; c++) {
      for (var r = r0; r <= r1; r++) {
        final h = HexCoord(c, r);
        if (h.isInside(grid.columns, grid.rows)) yield h;
      }
    }
  }
}
