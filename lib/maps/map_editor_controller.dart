// File: lib/maps/map_editor_controller.dart
// Screen state for the map editor: photo sources, extraction runs, the
// draft map, the hex selection, the view and the canvas tool. Ported from
// the Map Extractor prototype's ExtractorController. Opening btmap files is
// done by the Map Builder hub (Import), not here.

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:map_extractor_prototype/map_extractor.dart';
import 'package:path/path.dart' as p;

import 'hex_selection.dart';
import 'map_sheet_draft.dart';

enum SourceStatus { waiting, running, done, failed }

/// One image or PDF added by the user.
class SourceEntry {
  SourceEntry(this.path);

  final String path;
  SourceStatus status = SourceStatus.waiting;
  String stage = '';
  double fraction = 0;
  String? error;
  ExtractionJobResult? result;
  ui.Image? preview;

  String get name => p.basename(path);
}

/// Where the OCR models sit in the asset bundle. They ship with the
/// map_extractor_prototype package.
const _modelAssetDir = 'packages/map_extractor_prototype/assets/models';

/// The btmap file type for the file dialogs.
const btmapTypeGroup = XTypeGroup(label: 'btmap JSON', extensions: ['json']);

class MapEditorController extends ChangeNotifier {
  MapEditorController(this.draft);

  final MapSheetDraft draft;
  final List<SourceEntry> sources = [];
  final HexSelection selection = HexSelection();
  CanvasTool tool = CanvasTool.box;

  /// -1 shows the schematic map. Other values index [sources].
  int view = -1;
  bool showOcrBoxes = false;
  bool busy = false;
  String? status;
  OcrModels? _models;

  static const _imageTypes = XTypeGroup(
    label: 'Map images',
    extensions: ['jpg', 'jpeg', 'png', 'pdf'],
  );

  Future<OcrModels> _loadModels() async {
    if (_models != null) return _models!;
    Future<Uint8List> bytes(String f) async =>
        (await rootBundle.load('$_modelAssetDir/$f')).buffer.asUint8List();
    _models = OcrModels(
      await bytes(OcrModels.detFile),
      await bytes(OcrModels.recFile),
      await rootBundle.loadString('$_modelAssetDir/${OcrModels.dictFile}'),
    );
    return _models!;
  }

  Future<void> pickSources() async {
    final files = await openFiles(acceptedTypeGroups: const [_imageTypes]);
    addSources(files.map((f) => f.path));
  }

  void addSources(Iterable<String> paths) {
    for (final path in paths) {
      if (sources.any((s) => s.path == path)) continue;
      sources.add(SourceEntry(path));
    }
    notifyListeners();
  }

  void removeSource(int index) {
    sources.removeAt(index).preview?.dispose();
    if (view >= sources.length) view = -1;
    _remerge();
    notifyListeners();
  }

  /// True when some source has not been extracted yet.
  bool get hasPendingSources =>
      sources.any((s) => s.status != SourceStatus.done);

  /// Extracts every source that has not run yet, one at a time, then
  /// merges all results into the draft. The merge replaces the terrain.
  Future<void> extractAll() async {
    if (busy) return;
    busy = true;
    notifyListeners();
    try {
      final OcrModels models;
      try {
        models = await _loadModels();
      } on Object catch (e) {
        status = 'Could not load the OCR models: $e';
        return;
      }
      for (final s in sources) {
        if (s.status == SourceStatus.done) continue;
        s
          ..status = SourceStatus.running
          ..error = null;
        notifyListeners();
        try {
          final r = await ExtractionJob(s.path, models).run(
            onStage: (stage, f) {
              s
                ..stage = stage
                ..fraction = f;
              notifyListeners();
            },
          );
          s
            ..result = r
            ..preview = await _toImage(r)
            ..status = SourceStatus.done
            ..stage = r.extraction.summary;
        } on Object catch (e) {
          s
            ..status = SourceStatus.failed
            ..error = '$e';
        }
        notifyListeners();
      }
      _remerge();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<ui.Image> _toImage(ExtractionJobResult r) {
    final c = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      r.previewRgba,
      r.previewWidth,
      r.previewHeight,
      ui.PixelFormat.rgba8888,
      c.complete,
    );
    return c.future;
  }

  void _remerge() {
    final done = <ImageExtraction>[];
    final photoNumbers = <int>[];
    for (var i = 0; i < sources.length; i++) {
      final r = sources[i].result;
      if (r == null) continue;
      done.add(r.extraction);
      photoNumbers.add(i + 1);
    }
    if (done.isEmpty) return;
    draft.loadMerged(mergeExtractions(done, photoNumbers: photoNumbers));
    selection.clip(draft.grid);
    status =
        '${draft.terrainCount} hexes with terrain, '
        '${draft.toReviewCount} to review.';
  }

  void selectNextToReview() {
    final next = draft.nextToReview(selection.primary);
    if (next != null) selection.selectOnly(next);
  }

  /// Marks every selected hex as checked, then moves to the next one.
  void acceptSelection() {
    draft.setVerifiedAll(selection.hexes, true);
    selectNextToReview();
  }

  void setTool(CanvasTool t) {
    if (t == tool) return;
    tool = t;
    notifyListeners();
  }

  void setGrid(GridSpec grid) {
    draft.grid = grid;
    selection.clip(grid);
  }

  void setView(int v) {
    view = v;
    notifyListeners();
  }

  void toggleOcrBoxes() {
    showOcrBoxes = !showOcrBoxes;
    notifyListeners();
  }

  /// Writes the draft to a btmap file the user picks. Returns the file
  /// name, or null when the user cancels.
  Future<String?> exportJson() async {
    final base = draft.name.trim().isEmpty
        ? 'map'
        : draft.name.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    final loc = await getSaveLocation(
      acceptedTypeGroups: const [btmapTypeGroup],
      suggestedName: '$base.btmap.json',
    );
    if (loc == null) return null;
    await File(loc.path).writeAsString(draft.toSheet().toJsonString());
    return p.basename(loc.path);
  }

  @override
  void dispose() {
    for (final s in sources) {
      s.preview?.dispose();
    }
    selection.dispose();
    super.dispose();
  }
}
