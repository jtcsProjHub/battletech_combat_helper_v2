import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../extract/extraction_job.dart';
import '../extract/image_extractor.dart';
import '../extract/merge.dart';
import '../model/map_sheet.dart';
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

/// Screen state for the extractor prototype.
class ExtractorController extends ChangeNotifier {
  final List<SourceEntry> sources = [];
  MapSheetDraft draft = MapSheetDraft();
  final HexSelection selection = HexSelection();
  CanvasTool tool = CanvasTool.box;

  /// -1 shows the schematic map. Other values index [sources].
  int view = -1;
  bool showOcrBoxes = false;
  bool busy = false;
  String status = 'Add photos or a scanned PDF of one map sheet.';
  OcrModels? _models;

  static const _imageTypes = XTypeGroup(
    label: 'Map images',
    extensions: ['jpg', 'jpeg', 'png', 'pdf'],
  );
  static const _jsonTypes = XTypeGroup(label: 'btmap JSON', extensions: ['json']);

  Future<OcrModels> _loadModels() async {
    if (_models != null) return _models!;
    Future<Uint8List> bytes(String f) async =>
        (await rootBundle.load('assets/models/$f')).buffer.asUint8List();
    _models = OcrModels(
      await bytes(OcrModels.detFile),
      await bytes(OcrModels.recFile),
      await rootBundle.loadString('assets/models/${OcrModels.dictFile}'),
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

  /// Extracts every source that has not run yet, one at a time.
  Future<void> extractAll() async {
    if (busy) return;
    busy = true;
    notifyListeners();
    try {
      final models = await _loadModels();
      for (final s in sources) {
        if (s.status == SourceStatus.done) continue;
        s
          ..status = SourceStatus.running
          ..error = null;
        notifyListeners();
        try {
          final r = await ExtractionJob(s.path, models).run(onStage: (stage, f) {
            s
              ..stage = stage
              ..fraction = f;
            notifyListeners();
          });
          s
            ..result = r
            ..preview = await _toImage(r)
            ..status = SourceStatus.done
            ..stage = r.extraction.summary;
        } catch (e) {
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
    ui.decodeImageFromPixels(r.previewRgba, r.previewWidth, r.previewHeight,
        ui.PixelFormat.rgba8888, c.complete);
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
    final merged = mergeExtractions(done, photoNumbers: photoNumbers);
    draft.loadMerged(merged);
    status = '${draft.terrainCount} hexes with terrain, '
        '${draft.unverified.length} to review.';
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

  Future<void> saveJson() async {
    final suggested = draft.name.isEmpty
        ? 'map.btmap.json'
        : '${draft.name.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')}.btmap.json';
    final loc = await getSaveLocation(
      acceptedTypeGroups: const [_jsonTypes],
      suggestedName: suggested,
    );
    if (loc == null) return;
    await File(loc.path).writeAsString(draft.toSheet().toJsonString());
    status = 'Saved ${p.basename(loc.path)}.';
    notifyListeners();
  }

  /// True when opening a file would discard photos or map data.
  bool get hasLoadedData =>
      sources.isNotEmpty ||
      draft.terrainCount > 0 ||
      draft.unverified.isNotEmpty ||
      draft.name.isNotEmpty;

  /// Shows the file dialog. Returns the chosen path, or null.
  Future<String?> pickJson() async =>
      (await openFile(acceptedTypeGroups: const [_jsonTypes]))?.path;

  /// Replaces everything (photos, extraction results, map and selection)
  /// with the map in [path]. The file is parsed first, so a bad file
  /// leaves the current data as it was.
  Future<void> openJson(String path) async {
    final MapSheet sheet;
    try {
      sheet = MapSheet.fromJsonString(await File(path).readAsString());
    } catch (e) {
      status = 'Could not open ${p.basename(path)}: $e';
      notifyListeners();
      return;
    }
    for (final s in sources) {
      s.preview?.dispose();
    }
    sources.clear();
    draft.dispose();
    draft = MapSheetDraft.fromSheet(sheet);
    selection.clear();
    view = -1;
    showOcrBoxes = false;
    status = 'Opened ${p.basename(path)}.';
    notifyListeners();
  }

  @override
  void dispose() {
    for (final s in sources) {
      s.preview?.dispose();
    }
    draft.dispose();
    selection.dispose();
    super.dispose();
  }
}
