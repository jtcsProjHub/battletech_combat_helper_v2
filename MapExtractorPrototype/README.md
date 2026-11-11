# Map Extractor Prototype

This standalone Flutter desktop app turns photos or scanned PDFs of a BattleTech map sheet into hex terrain data. You review the result in a hex editor and save it as a `btmap` JSON file. The core classes have no Flutter imports, so the main app can reuse them later.

Target platforms are Linux and Windows desktop.

## First-time setup

The repository has no platform runner folders yet. The `flutter` command creates them.

1. Open a terminal in this folder.
2. Run `flutter create --platforms=linux,windows --project-name map_extractor_prototype .`
3. Run `flutter pub get`.
4. Add the ONNX Runtime library to the Linux bundle. Append these lines to the end of `linux/CMakeLists.txt`:

   ```cmake
   install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/onnxruntime/linux-x64/libonnxruntime.so.1.20.1"
     DESTINATION "${INSTALL_BUNDLE_LIB_DIR}" COMPONENT Runtime)
   ```

5. For a Windows build, append these lines to the end of `windows/CMakeLists.txt`:

   ```cmake
   install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/onnxruntime/windows-x64/onnxruntime.dll"
     DESTINATION "${INSTALL_BUNDLE_LIB_DIR}" COMPONENT Runtime)
   ```

The `flutter create` command does not overwrite the existing files in `lib/` and `test/`.

If you skip step 4, `flutter run` still works from the project root. The app then loads the library from `third_party/onnxruntime/` in the current directory. A release bundle needs step 4.

## Run

1. Run `flutter run -d linux`.
2. Click Add and select one or more images of the same sheet. Four quadrant photos give the best result. One full photo also works well. A PDF from a phone scanner works, but the result needs more review.
3. Click Extract. Each image takes about 15 to 40 seconds.
4. Review the hexes with an orange outline. Press N to go to the next hex to review. Press Enter to accept a hex and go to the next one.
5. Fix the selected hexes in the inspector on the right. With several hexes selected, an edit applies to all of them. An edit also marks the hexes as checked.
6. Make sure that the map name and the size are correct.
7. Click Save JSON.

The inspector shows a close-up of the primary hex from each photo that covers it, with the OCR lines read from that photo under it.

Select hexes on the map or on a photo:

- Click selects one hex. Ctrl+click adds or removes one hex. Shift+click selects the block of columns and rows from the last clicked hex.
- The toolbar at the top left of the view sets what a drag does: pan (H), box select (B) or brush select (P). With box or brush, hold Shift to add to the selection and Ctrl to remove from it.
- Ctrl+A selects all hexes. Esc clears the selection.
- The zoom bar at the bottom right has a slider, zoom buttons and a fit button. The mouse wheel also zooms.

Click a Photo chip above the map to see the fitted grid on that photo. Turn on OCR boxes to see every text box that the recognizer read. Cyan text is a hex number. Yellow text is other text.

## How the extractor works

The code is in `lib/src/`. `tool/reference_pipeline.py` is a Python copy of the same algorithm with the same constants. Use it to compare intermediate values when the Dart output looks wrong.

1. Load. `ImageLoader` decodes JPEG or PNG and applies the EXIF orientation. For a PDF, it takes the largest embedded JPEG stream. Phone scanner apps write PDFs this way. Vector PDFs are not supported.
2. Orientation. `ImageExtractor.probeRotation` runs OCR on the centre tile at each quarter turn. It keeps the turn that reads the most valid hex numbers.
3. OCR. `PaddleOcr` runs PaddleOCR PP-OCRv4 on ONNX Runtime, in 1408 px tiles with 160 px overlap.
   - Detection (DB, differentiable binarization) gives a text probability map. The code thresholds the map at 0.3, dilates it 2x2 and finds 8-connected components. Each component becomes an axis-aligned box, expanded by the DB unclip distance (area x 1.6 / perimeter). Map text is horizontal after step 2, so rotated rectangles and OpenCV are not necessary.
   - Recognition (CTC, connectionist temporal classification) reads each box at 48 px height. Greedy decoding is limited to ASCII letters, digits, `-`, `|` and space. This limit removes confusions with Chinese characters in the model's 6623-character dictionary.
   - A box that touches an inner tile edge is dropped, because the neighbouring tile sees it whole.
4. Grid fit. Every four-digit text that parses as a hex number is an anchor. Grid space has one unit per column and one per row, and even columns are 0.5 row lower. RANSAC (random sample consensus) fits a homography (a projective transform) from grid space to pixels, with 1000 four-point samples and a 6 px inlier threshold. Two least-squares refits on the inliers follow. Misread numbers fall out as outliers.
5. Labels. Other text goes through `LabelParser`, which matches a fixed word list with a Levenshtein ratio of at least 0.8. The inverse homography maps the label centre to grid space. A label sits 0.8 row below the number of its own hex.
6. Uncertainty. A LEVEL or DEPTH digit that came from a letter substitution (for example B read as 8), a missing digit, or a negative value is marked uncertain.
7. Merge. `mergeExtractions` sums the reading confidences per token per hex over all images. Uncertain readings count half. Each slot (LEVEL, DEPTH or a word) keeps its best token. A hex needs review when its winning token was never read with certainty, or when another value for the same slot also got votes.
8. Size. The grid size comes from the highest column and row among the anchors that fit. You can change it in the left panel.

## Results on the test images

These numbers come from the Python reference pipeline. The Foothills #1 reference is the result of the four quadrant photos, which was checked by eye.

| Input | Correct | Wrong, flagged for review | Missed |
|---|---|---|---|
| Foothills #1, four quadrant photos | 125 of 126 | 1 | 0 |
| Foothills #1, one full photo | 125 of 126 | 1 | 0 |
| Foothills #1, scanner PDF | 117 of 126 | 7 | 2 |
| Desert #1, one full photo | 20 of 20 | 0 | 0 |
| Desert #1, scanner PDF | 18 of 20 | 0 | 2 |

Every wrong hex in these tests was flagged for review. The one wrong hex in the photos is 1207, which reads as LEVEL -1. The extractor keeps negative levels but always flags them.

## Command-line tool

Use the command-line tool to tune the extractor without the UI.

```sh
dart run tool/extract_cli.dart out.btmap.json photo1.jpg photo2.jpg
```

Run the Python reference on the same images to compare:

```sh
pip install onnxruntime opencv-python numpy
python3 tool/reference_pipeline.py ref.json photo1.jpg photo2.jpg
```

The Python output has one entry per labeled hex. The Dart output is the full `btmap` file.

## The btmap format

```json
{
  "format": "btmap",
  "version": 1,
  "name": "Foothills #1",
  "grid": { "columns": 15, "rows": 17, "numbering": "CCRR", "layout": "evenColumnsDown" },
  "hexes": {
    "0102": { "woods": "light" },
    "1305": { "woods": "light", "level": 2 },
    "0505": { "features": ["rough"] }
  },
  "unverified": ["1207"]
}
```

- `grid` gives the sheet size. Not every sheet is the standard 15 x 17.
- `hexes` lists only hexes that are not Clear. A missing hex is Clear.
- `woods` is `light`, `heavy` or `ultraHeavy`. `level` and `waterDepth` are integers. `features` uses the names in `TerrainFeature`.
- `unverified` lists hexes that nobody has checked yet. A fully reviewed map has no `unverified` key.

The file holds printed reference data only. Items that players add for one skirmish, such as miniature buildings, belong in a separate per-skirmish layer in the main app.

## Reuse in the main app

- `lib/map_extractor.dart` exports the core: model, imaging, OCR and extraction. It has no Flutter imports.
- `MapSheet` is the immutable saved form. `MapSheetDraft` is the editable form for screens, like `Lance` and `LanceDraft`.
- `HexLayout`, `HexMapView` and `HexInspector` are the parts to share with the skirmish setup editor.

## Known limits

- The code was written without a Dart SDK in the build environment. The algorithm was checked with the Python reference, and the ONNX Runtime binding was checked from C. Run `flutter analyze` and `flutter test` first, and expect small fixes.
- Each extraction starts a new isolate and loads the models again. This costs about one second per image.
- Vector PDFs need a PDF renderer such as `pdfrx`.
- The OCR word list covers the labels on the test sheets plus common terrain words. Unknown words are ignored. Turn on OCR boxes to find them.
