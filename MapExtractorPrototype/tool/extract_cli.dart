// Command-line extractor, for tuning without the UI.
//
// Run from the project root:
//   dart run tool/extract_cli.dart OUT.json IMAGE_OR_PDF [IMAGE_OR_PDF ...]
//
// Prints per-image statistics and writes a btmap JSON file. Compare the
// output with tool/reference_pipeline.py on the same images.

import 'dart:io';

import 'package:map_extractor_prototype/map_extractor.dart';

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln('usage: dart run tool/extract_cli.dart OUT.json IMAGE [IMAGE ...]');
    exit(64);
  }
  final models = OcrModels.fromDirectory('assets/models');
  final results = <ImageExtraction>[];
  for (final path in args.skip(1)) {
    final job = ExtractionJob(path, models);
    final r = job.runSync();
    final e = r.extraction;
    stdout.writeln('${e.name}: rot=${e.rotation * 90} ids=${e.anchorCount} '
        'inliers=${e.inlierCount} resid=${e.medianResidual.toStringAsFixed(1)}px '
        'size=${e.maxCol}x${e.maxRow} labelled=${e.readings.length} '
        '${e.seconds.toStringAsFixed(0)}s');
    results.add(e);
  }
  final merged = mergeExtractions(results);
  final sheet = MapSheet(
    name: '',
    grid: merged.grid,
    hexes: merged.terrain,
    unverified: merged.review,
  );
  File(args.first).writeAsStringSync(sheet.toJsonString());
  stdout.writeln('${sheet.hexes.length} hexes with terrain, '
      '${sheet.unverified.length} to review -> ${args.first}');
}
