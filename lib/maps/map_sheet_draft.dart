// File: lib/maps/map_sheet_draft.dart
// The editable form of a MapSheet that the map editor works on. Follows the
// Lance / LanceDraft pattern. Ported from the Map Extractor prototype, with
// the saved-map id and an unsaved-changes flag added.

import 'package:flutter/foundation.dart';
import 'package:map_extractor_prototype/map_extractor.dart';

import 'map_repository.dart';

class MapSheetDraft extends ChangeNotifier {
  MapSheetDraft({
    required this.id,
    String name = '',
    GridSpec grid = GridSpec.standard,
  }) : _name = name,
       _grid = grid;

  /// Opens a saved map. The draft starts with no unsaved changes.
  factory MapSheetDraft.fromSaved(SavedMap map) =>
      MapSheetDraft(id: map.id, name: map.sheet.name, grid: map.sheet.grid)
        .._terrain.addAll(map.sheet.hexes)
        .._unverified.addAll(map.sheet.unverified);

  /// The id the map is saved under.
  final String id;

  String _name;
  GridSpec _grid;
  final Map<HexCoord, HexTerrain> _terrain = {};
  final Set<HexCoord> _unverified = {};
  final Map<HexCoord, List<HexEvidence>> _evidence = {};
  bool _dirty = false;

  String get name => _name;
  GridSpec get grid => _grid;
  Set<HexCoord> get unverified => Set.unmodifiable(_unverified);
  int get terrainCount => _terrain.values.where((t) => !t.isClear).length;

  /// Review flags on hexes inside the grid. Flags outside it are kept in
  /// case the grid grows again, but are not counted or saved.
  int get toReviewCount =>
      _unverified.where((h) => h.isInside(_grid.columns, _grid.rows)).length;

  /// True when the draft changed since it was opened or last saved.
  bool get hasUnsavedChanges => _dirty;

  HexTerrain terrainAt(HexCoord hex) => _terrain[hex] ?? HexTerrain.clear;
  bool needsReview(HexCoord hex) => _unverified.contains(hex);
  List<HexEvidence> evidenceFor(HexCoord hex) => _evidence[hex] ?? const [];

  /// Every change goes through here, so every change sets the unsaved flag.
  @override
  void notifyListeners() {
    _dirty = true;
    super.notifyListeners();
  }

  /// Clears the unsaved flag after a save.
  void markSaved() {
    if (!_dirty) return;
    _dirty = false;
    super.notifyListeners();
  }

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

  /// Applies [edit] to every hex in [hexes] with one notification.
  /// Editing a hex counts as checking it.
  void updateTerrain(
    Iterable<HexCoord> hexes,
    HexTerrain Function(HexTerrain) edit,
  ) {
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

  /// Replaces all terrain and review flags with an extraction result.
  void loadMerged(MergedMap merged) {
    _grid = merged.grid;
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
    final list =
        _unverified.where((h) => h.isInside(_grid.columns, _grid.rows)).toList()
          ..sort();
    if (list.isEmpty) return null;
    if (from == null) return list.first;
    return list.firstWhere(
      (h) => h.compareTo(from) > 0,
      orElse: () => list.first,
    );
  }

  MapSheet toSheet() => MapSheet(
    name: _name.trim(),
    grid: _grid,
    hexes: _terrain,
    unverified: {
      for (final h in _unverified)
        if (h.isInside(_grid.columns, _grid.rows)) h,
    },
  );

  SavedMap toSaved() => SavedMap(id: id, sheet: toSheet());
}
