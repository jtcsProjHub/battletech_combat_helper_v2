import 'package:flutter/foundation.dart';

import '../extract/merge.dart';
import '../model/hex_coord.dart';
import '../model/hex_terrain.dart';
import '../model/map_sheet.dart';

/// Editable form of a [MapSheet], following the Lance / LanceDraft pattern.
class MapSheetDraft extends ChangeNotifier {
  MapSheetDraft({String name = '', GridSpec grid = GridSpec.standard})
      : _name = name,
        _grid = grid;

  factory MapSheetDraft.fromSheet(MapSheet sheet) => MapSheetDraft(
        name: sheet.name,
        grid: sheet.grid,
      )
        .._terrain.addAll(sheet.hexes)
        .._unverified.addAll(sheet.unverified);

  String _name;
  GridSpec _grid;
  final Map<HexCoord, HexTerrain> _terrain = {};
  final Set<HexCoord> _unverified = {};
  final Map<HexCoord, List<HexEvidence>> _evidence = {};

  String get name => _name;
  GridSpec get grid => _grid;
  Set<HexCoord> get unverified => Set.unmodifiable(_unverified);
  int get terrainCount => _terrain.values.where((t) => !t.isClear).length;

  HexTerrain terrainAt(HexCoord hex) => _terrain[hex] ?? HexTerrain.clear;
  bool needsReview(HexCoord hex) => _unverified.contains(hex);
  List<HexEvidence> evidenceFor(HexCoord hex) => _evidence[hex] ?? const [];

  set name(String v) {
    if (v == _name) return;
    _name = v;
    notifyListeners();
  }

  set grid(GridSpec v) {
    if (v == _grid) return;
    _grid = v;
    notifyListeners();
  }

  void setTerrain(HexCoord hex, HexTerrain t) {
    if (t.isClear) {
      _terrain.remove(hex);
    } else {
      _terrain[hex] = t;
    }
    // Editing a hex counts as checking it.
    _unverified.remove(hex);
    notifyListeners();
  }

  /// Applies [edit] to every hex in [hexes] with one notification.
  /// Editing a hex counts as checking it.
  void updateTerrain(Iterable<HexCoord> hexes, HexTerrain Function(HexTerrain) edit) {
    for (final hex in hexes) {
      final t = edit(terrainAt(hex));
      if (t.isClear) {
        _terrain.remove(hex);
      } else {
        _terrain[hex] = t;
      }
      _unverified.remove(hex);
    }
    notifyListeners();
  }

  void setVerifiedAll(Iterable<HexCoord> hexes, bool verified) {
    var changed = false;
    for (final hex in hexes) {
      changed |= verified ? _unverified.remove(hex) : _unverified.add(hex);
    }
    if (changed) notifyListeners();
  }

  void setVerified(HexCoord hex, bool verified) {
    final changed = verified ? _unverified.remove(hex) : _unverified.add(hex);
    if (changed) notifyListeners();
  }

  /// Replaces all terrain with an extraction result.
  void loadMerged(MergedMap merged, {bool keepGrid = false}) {
    if (!keepGrid) _grid = merged.grid;
    _terrain
      ..clear()
      ..addAll(merged.terrain);
    _unverified
      ..clear()
      ..addAll(merged.review);
    _evidence
      ..clear()
      ..addAll(merged.evidence);
    notifyListeners();
  }

  /// The next hex to review after [from], in column-then-row order.
  HexCoord? nextToReview(HexCoord? from) {
    final list = _unverified.where((h) => h.isInside(_grid.columns, _grid.rows)).toList()
      ..sort();
    if (list.isEmpty) return null;
    if (from == null) return list.first;
    return list.firstWhere((h) => h.compareTo(from) > 0, orElse: () => list.first);
  }

  MapSheet toSheet() => MapSheet(
        name: _name,
        grid: _grid,
        hexes: _terrain,
        unverified: _unverified,
      );
}
