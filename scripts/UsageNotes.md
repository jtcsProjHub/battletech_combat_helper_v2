### What it does
- converts each PDF page to an image using `pdf2image`
- runs OCR with `pytesseract`
- parses the extracted text into `Mech`-compatible JSON
- outputs a JSON array matching the structure used by mech_data.dart

### Notes
- mech_data.dart expects `techBase` and `movementType` as enum indexes, and the script emits those numeric values.
- The parser is heuristic-based, so if your PDF layout differs slightly you may need to adjust the regex or table parsing rules.

### How to run
1. Place your Battletech mech PDF in the workspace.
2. Install dependencies:
   - `pip install pdf2image pytesseract pillow`
   - system packages: `sudo apt-get install poppler-utils tesseract-ocr`
3. Run:
   - `python extract_mech_data.py path/to/mechs.pdf output/mechs.json`