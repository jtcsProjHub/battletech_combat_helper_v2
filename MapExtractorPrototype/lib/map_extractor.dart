/// Core extractor library. It has no Flutter imports, so the main app can
/// reuse it and `dart run tool/extract_cli.dart` can run it without a UI.
library;

export 'src/extract/extraction_job.dart';
export 'src/extract/homography.dart';
export 'src/extract/image_extractor.dart';
export 'src/extract/label_parser.dart';
export 'src/extract/merge.dart';
export 'src/imaging/bgr_image.dart';
export 'src/imaging/image_loader.dart';
export 'src/model/hex_coord.dart';
export 'src/model/hex_terrain.dart';
export 'src/model/map_sheet.dart';
export 'src/ocr/onnx_runtime.dart';
export 'src/ocr/paddle_ocr.dart';
