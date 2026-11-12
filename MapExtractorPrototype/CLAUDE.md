# CLAUDE.md

Context for Claude Code in the Map Extractor Prototype. Read this file first. README.md has the user-facing setup, usage and algorithm description.

## What this project is

This is a standalone Flutter desktop prototype for the BattleTech Combat Helper v2 app (parent folder `battletech_combat_helper_v2`). It turns photos or scanned PDFs of a printed BattleTech map sheet into hex terrain data. The user reviews and corrects the result in a hex editor and saves it as a `btmap` JSON file.

The prototype exists to tune the extractor and the editor UI before the classes move into the main app. The editor UI is the starting point for the skirmish setup editor in the main app, which also needs per-skirmish items such as placed buildings.

- Owner: John (jcameron). He has image processing and object recognition experience. Explain algorithms by name and give the parameters.
- Platforms: Linux desktop (development) and Windows desktop (builds for friends). Android and iOS are out of scope. A future tablet target, if any, means a Windows tablet.
- A phone companion app (for example, photo capture over Bluetooth) is a possible later idea. Keep the extractor input as plain image files so a companion can feed it without changes.
- Design notes live in John's Obsidian vault: `~/Obsidian Docs/BattletechApp_DesignNotes/`, mainly `Data Classes and Handling/Skirmish Running.md` and `Data Classes and Handling/Lance Builder Design.md`.

## Commands

Run from the project root.

```sh
flutter pub get
flutter analyze
flutter test
flutter run -d linux
dart run tool/extract_cli.dart out.btmap.json IMAGE [IMAGE ...]
python3 tool/reference_pipeline.py ref.json IMAGE [IMAGE ...]   # needs onnxruntime, opencv-python, numpy
```

`flutter run` loads ONNX Runtime from `third_party/onnxruntime/linux-x64/` in the current directory. A release bundle needs the `install(FILES ...)` line from README.md in `linux/CMakeLists.txt` (and `windows/CMakeLists.txt`). That line is not added yet.

## Architecture

`lib/map_extractor.dart` exports the core. The core must stay free of Flutter imports, so the CLI tool runs with `dart run` and the main app can reuse it.

| Folder | Contents |
|---|---|
| `lib/src/model/` | `HexCoord` (CCRR ids, even columns half a hex lower), `HexTerrain` (woods, level, waterDepth, features), `MapSheet` and `GridSpec` (immutable saved form, JSON) |
| `lib/src/imaging/` | `BgrImage` (BGR buffer, crop, rotate, bilinear resize like cv2.INTER_LINEAR), `ImageLoader` (JPEG/PNG with EXIF, largest embedded JPEG in a PDF) |
| `lib/src/ocr/` | `onnx_runtime.dart` (dart:ffi binding to the ONNX Runtime C API by OrtApi index), `paddle_ocr.dart` (PP-OCRv4 DB detection and CTC recognition) |
| `lib/src/extract/` | `homography.dart` (DLT, Gauss-Jordan, RANSAC with an LCG), `label_parser.dart`, `image_extractor.dart` (rotation probe, grid fit, label assignment, `SheetGeometry`), `merge.dart` (voting across images, `HexEvidence`), `extraction_job.dart` (background isolate) |
| `lib/src/ui/` | Flutter UI. See below. |
| `tool/` | `extract_cli.dart`, `reference_pipeline.py` |
| `assets/models/` | `ppocrv4_det.onnx`, `ppocrv4_rec.onnx`, `ppocrv4_rec_dict.txt` (see NOTICE.md) |
| `third_party/onnxruntime/` | ONNX Runtime 1.20.1 CPU binaries for linux-x64 and windows-x64 (see NOTICE.md) |

UI classes in `lib/src/ui/`:

- `ExtractorController` (ChangeNotifier): sources, extraction runs, merge, view, tool, open and save. `SourceEntry` holds one photo, its `ExtractionJobResult` and a `ui.Image` preview.
- `MapSheetDraft` (ChangeNotifier): editable map. It follows the main app's `Lance` / `LanceDraft` pattern (`fromSheet` / `toSheet`).
- `HexSelection` (ChangeNotifier) and `CanvasTool` (pan, box, brush): multi-hex selection with click, Ctrl+click, Shift+click block, box and brush drags.
- `HexCanvas`: zoom, pan, tool bar, zoom bar and pointer handling. Content-agnostic: it takes a painter, `hexAt` and `centerOf`. Used by `HexMapView` (schematic) and `SourceOverlayView` (photo with fitted grid, `PhotoProjection`).
- `HexInspector`: edits all selected hexes, shows a `HexPhotoCrop` close-up and OCR evidence per photo for the primary hex.
- `HexLayout`, `TerrainStyle`: schematic geometry and colors.
- `ExtractorScreen`: three columns (sources and map settings, view, inspector) and keyboard shortcuts.

State management follows the main app: ChangeNotifier with ListenableBuilder. Do not add BLoC, Provider or Riverpod.

## The extraction pipeline

The Dart code and `tool/reference_pipeline.py` implement the same algorithm with the same constants. When you change one, change the other, and compare their outputs on the same images.

1. Load the image, apply EXIF orientation. For a PDF, take the largest DCTDecode stream.
2. Rotation probe: OCR the centre 1408 px tile at each quarter turn, keep the turn with the most valid hex numbers.
3. OCR in 1408 px tiles with 160 px overlap. DB detection: threshold 0.3, 2x2 dilation, 8-connected components, axis-aligned boxes, box score threshold 0.5, unclip ratio 1.6. Recognition at 48 px height, minimum width 320, greedy CTC limited to ASCII letters, digits, `-`, `|` and space. Drop boxes that touch an inner tile edge (4 px margin). Text score threshold 0.5.
4. Grid fit: hex numbers are anchors at grid point (col, row + 0.5 for even columns). RANSAC homography, 1000 iterations, 6 px threshold, LCG seed 12345, then two least-squares refits.
5. Labels: Levenshtein ratio of at least 0.8 against a fixed word list. A label belongs to the hex whose number is 0.8 row above it. The hex centre is 0.32 row below its number.
6. Uncertainty: a LEVEL or DEPTH digit from a letter substitution, a missing digit, or a negative value is uncertain.
7. Merge: sum of min-character confidences per token per hex, halved when uncertain. A hex needs review when its winning token was never certain or another value for the same slot got votes.
8. Grid size: highest column and row among inlier anchors. The user can override it.

Test results (Python reference): Foothills #1 quadrant photos and full photo 125 of 126 correct, scanner PDF 117 of 126. Desert #1 full photo 20 of 20, scanner PDF 18 of 20. Every wrong hex was flagged for review. Ground truth for Foothills #1 is the quadrant result, checked by eye.

## The btmap JSON format

```json
{
  "format": "btmap", "version": 1, "name": "Foothills #1",
  "grid": { "columns": 15, "rows": 17, "numbering": "CCRR", "layout": "evenColumnsDown" },
  "hexes": { "0102": { "woods": "light" }, "1305": { "woods": "light", "level": 2 } },
  "unverified": ["1207"]
}
```

`grid` is required because not every sheet is 15 x 17. `hexes` holds only non-Clear hexes. `unverified` is optional. The file holds printed reference data only. Per-skirmish additions belong in a separate layer in the main app. Bump `version` for incompatible changes.

## Decisions and why

- ONNX Runtime with PaddleOCR, not ML Kit (no desktop support) and not Tesseract (it read 3 of 20 woods labels on the Desert scan).
- A hand-written FFI binding by OrtApi index, not a pub package, because Windows support in the Flutter ONNX packages was uncertain. The indices were verified from C against libonnxruntime 1.20.1. Function types must stay concrete; `asFunction` cannot take a generic type argument.
- No OpenCV. Map text is horizontal after the rotation probe, so connected-component bounding boxes replace rotated rectangles.
- ASCII-only decoding and tile-edge filtering each fixed real errors on the test images.
- Quadrant photos merge in grid space through separate homographies. No image stitching.
- Opening a JSON file clears photos and map data, after a confirmation dialog when anything is loaded. The file is parsed before anything is cleared.

## Status and open items

Done and working on John's machine: extraction, merge, review editor, multi-select (click, Ctrl, Shift, box, brush, Ctrl+A, Esc), zoom bar, photo close-ups with per-photo OCR evidence, open and save JSON.

Open items and ideas:

- Add the ONNX Runtime `install(FILES ...)` lines to `linux/CMakeLists.txt` and `windows/CMakeLists.txt` before release builds.
- Each extraction spawns a new isolate and reloads the models (about 1 s per image). A long-lived worker isolate would remove this.
- Vector PDFs are not supported. `pdfrx` would add them.
- The label word list covers the test sheets plus common terrain words. Unknown words are ignored. Collect new words from other sheets with the OCR boxes overlay.
- Corrections made in the editor are labeled training data. A small classifier on label crops is a possible later improvement.
- Not checked: whether `package:image` already applies EXIF orientation before `bakeOrientation`. The rotation probe corrects a double rotation anyway.
- Hex 1207 on Foothills #1 reads as LEVEL -1. Negative levels are kept but always flagged.

## Test images

The test images are not in the repository. They are Foothills #1, Grassland #1 and Desert #1: three scanner PDFs, one full photo each of Foothills and Desert, and four quadrant photos of Foothills. Ask John for them if needed. Do not commit map images or extracted map data from copyrighted sheets to a public repository.

## Writing style for docs and replies

John prefers plain English in the style of ASD-STE100 Simplified Technical English. In documents: imperative steps, at most 20 words per instruction sentence and 25 per description sentence, active voice, simple tenses, no contractions, no semicolons or em dashes, no should/may/might/could, condition before command, and one word per meaning ("make sure that" instead of check, verify, confirm or ensure). In chat replies: prose, answer first, no headers, bullets, bold or tables unless a list is necessary. Code, identifiers and quoted errors stay exact.
