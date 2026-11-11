# OCR models

These are the PaddleOCR PP-OCRv4 models, converted to ONNX. The files come from the `rapidocr_onnxruntime` Python package.

| File | Original name | Purpose |
|---|---|---|
| `ppocrv4_det.onnx` | `ch_PP-OCRv4_det_infer.onnx` | Text detection (DB) |
| `ppocrv4_rec.onnx` | `ch_PP-OCRv4_rec_infer.onnx` | Text recognition (CTC) |
| `ppocrv4_rec_dict.txt` | `character` metadata of the recognition model | Recognizer character list |

PaddleOCR is released under the Apache License 2.0: https://github.com/PaddlePaddle/PaddleOCR/blob/main/LICENSE

The recognition model covers Chinese and English. The extractor limits decoding to ASCII letters, digits, `-`, `|` and space.
