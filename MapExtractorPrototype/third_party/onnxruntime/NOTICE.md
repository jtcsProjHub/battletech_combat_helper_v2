# ONNX Runtime 1.20.1

These files are unmodified prebuilt binaries of ONNX Runtime 1.20.1 (CPU), copied from the `onnxruntime-node@1.20.1` npm package.

- `linux-x64/libonnxruntime.so.1.20.1`
- `windows-x64/onnxruntime.dll`

ONNX Runtime is copyright Microsoft Corporation and is released under the MIT License: https://github.com/microsoft/onnxruntime/blob/main/LICENSE

The Windows DLL needs the Microsoft Visual C++ 2015-2022 Redistributable (x64). Flutter Windows apps need the same runtime.

To use a different version, replace the files and make sure that the version supports C API version 20 or later. The binding in `lib/src/ocr/onnx_runtime.dart` uses API version 20.
