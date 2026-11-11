import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../imaging/image_loader.dart';
import '../ocr/onnx_runtime.dart';
import '../ocr/paddle_ocr.dart';
import 'image_extractor.dart';

/// Model files used by the extractor.
class OcrModels {
  const OcrModels(this.det, this.rec, this.dictionary);

  final Uint8List det;
  final Uint8List rec;
  final String dictionary;

  static const detFile = 'ppocrv4_det.onnx';
  static const recFile = 'ppocrv4_rec.onnx';
  static const dictFile = 'ppocrv4_rec_dict.txt';

  /// Loads the models from a folder, for the command-line tool.
  static OcrModels fromDirectory(String dir) => OcrModels(
        File(p.join(dir, detFile)).readAsBytesSync(),
        File(p.join(dir, recFile)).readAsBytesSync(),
        File(p.join(dir, dictFile)).readAsStringSync(),
      );
}

/// Result of [ExtractionJob.run]: the extraction plus a downscaled RGBA
/// preview of the rotated image for display.
class ExtractionJobResult {
  ExtractionJobResult(this.extraction, this.previewRgba, this.previewWidth,
      this.previewHeight, this.previewScale);

  final ImageExtraction extraction;
  final Uint8List previewRgba;
  final int previewWidth;
  final int previewHeight;

  /// Preview pixels per original pixel.
  final double previewScale;
}

/// Progress message sent from the worker isolate.
class ExtractionProgress {
  ExtractionProgress(this.stage, this.fraction);
  final String stage;
  final double fraction;
}

/// Runs one image through the extractor on a background isolate.
class ExtractionJob {
  ExtractionJob(this.path, this.models, {this.previewMaxSide = 2400});

  final String path;
  final OcrModels models;
  final int previewMaxSide;

  /// Runs the job in the current isolate.
  ExtractionJobResult runSync({void Function(String, double)? onStage}) {
    onStage?.call('Loading image', 0);
    final img = ImageLoader.load(File(path).readAsBytesSync());
    final rt = OnnxRuntime.open();
    final ocr = PaddleOcr(rt, models.det, models.rec, models.dictionary);
    try {
      final (extraction, rotated) = ImageExtractor(ocr)
          .extract(img, p.basename(path), onStage: onStage);
      onStage?.call('Making preview', 1);
      final preview = rotated.toRgbaPreview(previewMaxSide);
      return ExtractionJobResult(extraction, preview.rgba, preview.width,
          preview.height, preview.scale);
    } finally {
      ocr.dispose();
      rt.dispose();
    }
  }

  /// Runs the job on a new isolate and reports progress.
  Future<ExtractionJobResult> run({void Function(String, double)? onStage}) async {
    final port = ReceivePort();
    final done = Completer<ExtractionJobResult>();
    late final Isolate isolate;
    port.listen((msg) {
      if (msg is ExtractionProgress) {
        onStage?.call(msg.stage, msg.fraction);
      } else if (msg is ExtractionJobResult) {
        if (!done.isCompleted) done.complete(msg);
      } else if (msg is List && msg.length == 2) {
        // [error, stack] from the worker or from onError.
        if (!done.isCompleted) {
          done.completeError(Exception(msg[0]), StackTrace.fromString('${msg[1]}'));
        }
      } else if (msg == null && !done.isCompleted) {
        // onExit without a result: the worker died.
        done.completeError(Exception('The extraction worker stopped unexpectedly.'));
      }
    });
    isolate = await Isolate.spawn(_worker, (this, port.sendPort),
        onError: port.sendPort, onExit: port.sendPort);
    try {
      return await done.future;
    } finally {
      port.close();
      isolate.kill();
    }
  }

  static void _worker((ExtractionJob, SendPort) args) {
    final (job, send) = args;
    try {
      final result = job.runSync(
          onStage: (s, f) => send.send(ExtractionProgress(s, f)));
      send.send(result);
    } catch (e, st) {
      send.send(['$e', '$st']);
    }
  }
}
