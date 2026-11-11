// Minimal dart:ffi binding to the ONNX Runtime C API (API version 20,
// ONNX Runtime 1.20.x).
//
// The C API is a struct of function pointers (OrtApi). This file reads the
// pointers by index instead of declaring the whole struct. The indices come
// from the field order in onnxruntime_c_api.h for API version 20. A C test
// called each one by index against libonnxruntime.so.1.20.1 and matched the
// Python onnxruntime output to 1e-6. Newer runtimes only append fields, so
// the indices stay valid for later versions.
//
// The same code works with onnxruntime.dll on Windows x64.

import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

// OrtApi field indices (API version 20).
abstract final class _Idx {
  static const getErrorMessage = 2;
  static const createEnv = 3;
  static const createSessionFromArray = 8;
  static const run = 9;
  static const createSessionOptions = 10;
  static const setSessionGraphOptimizationLevel = 23;
  static const setIntraOpNumThreads = 24;
  static const sessionGetInputName = 36;
  static const sessionGetOutputName = 37;
  static const createTensorWithDataAsOrtValue = 49;
  static const getTensorMutableData = 51;
  static const getDimensionsCount = 61;
  static const getDimensions = 62;
  static const getTensorTypeAndShape = 65;
  static const createCpuMemoryInfo = 69;
  static const allocatorFree = 76;
  static const getAllocatorWithDefaultOptions = 78;
  static const releaseEnv = 92;
  static const releaseStatus = 93;
  static const releaseMemoryInfo = 94;
  static const releaseSession = 95;
  static const releaseValue = 96;
  static const releaseTensorTypeAndShapeInfo = 99;
  static const releaseSessionOptions = 100;
}

const _ortApiVersion = 20;
const _loggingLevelError = 3;
const _graphOptAll = 99;
const _arenaAllocator = 1;
const _memTypeDefault = 0;
const _tensorFloat = 1;

typedef _P = Pointer<Void>;
typedef _PP = Pointer<Pointer<Void>>;

// Native and Dart signatures. Every function returns an OrtStatus*, which
// is null on success.
typedef _GetErrorMessageN = Pointer<Utf8> Function(_P);
typedef _ReleaseN = Void Function(_P);
typedef _ReleaseD = void Function(_P);
typedef _CreateEnvN = _P Function(Int32, Pointer<Utf8>, _PP);
typedef _CreateEnvD = _P Function(int, Pointer<Utf8>, _PP);
typedef _OutOnlyN = _P Function(_PP);
typedef _SetIntN = _P Function(_P, Int32);
typedef _SetIntD = _P Function(_P, int);
typedef _CreateSessionFromArrayN = _P Function(_P, _P, Size, _P, _PP);
typedef _CreateSessionFromArrayD = _P Function(_P, _P, int, _P, _PP);
typedef _GetIoNameN = _P Function(_P, Size, _P, Pointer<Pointer<Utf8>>);
typedef _GetIoNameD = _P Function(_P, int, _P, Pointer<Pointer<Utf8>>);
typedef _AllocatorFreeN = _P Function(_P, _P);
typedef _CreateCpuMemoryInfoN = _P Function(Int32, Int32, _PP);
typedef _CreateCpuMemoryInfoD = _P Function(int, int, _PP);
typedef _CreateTensorN = _P Function(_P, _P, Size, Pointer<Int64>, Size, Int32, _PP);
typedef _CreateTensorD = _P Function(_P, _P, int, Pointer<Int64>, int, int, _PP);
typedef _RunN = _P Function(_P, _P, Pointer<Pointer<Utf8>>, _PP, Size,
    Pointer<Pointer<Utf8>>, Size, _PP);
typedef _RunD = _P Function(_P, _P, Pointer<Pointer<Utf8>>, _PP, int,
    Pointer<Pointer<Utf8>>, int, _PP);
typedef _InOutN = _P Function(_P, _PP);
typedef _GetDimensionsCountN = _P Function(_P, Pointer<Size>);
typedef _GetDimensionsN = _P Function(_P, Pointer<Int64>, Size);
typedef _GetDimensionsD = _P Function(_P, Pointer<Int64>, int);

final class _OrtApiBase extends Struct {
  external Pointer<NativeFunction<_PP Function(Uint32)>> getApi;
  external Pointer<NativeFunction<Pointer<Utf8> Function()>> getVersionString;
}

class OrtException implements Exception {
  OrtException(this.message);
  final String message;
  @override
  String toString() => 'ONNX Runtime: $message';
}

/// Loaded ONNX Runtime library and environment. Create one per isolate.
class OnnxRuntime {
  OnnxRuntime._(_PP api, this.version)
      : _getErrorMessage = api[_Idx.getErrorMessage]
            .cast<NativeFunction<_GetErrorMessageN>>()
            .asFunction(),
        _releaseStatus =
            api[_Idx.releaseStatus].cast<NativeFunction<_ReleaseN>>().asFunction(),
        _createEnv =
            api[_Idx.createEnv].cast<NativeFunction<_CreateEnvN>>().asFunction(),
        _createSessionOptions = api[_Idx.createSessionOptions]
            .cast<NativeFunction<_OutOnlyN>>()
            .asFunction(),
        _setIntraOpNumThreads = api[_Idx.setIntraOpNumThreads]
            .cast<NativeFunction<_SetIntN>>()
            .asFunction(),
        _setGraphOptimizationLevel = api[_Idx.setSessionGraphOptimizationLevel]
            .cast<NativeFunction<_SetIntN>>()
            .asFunction(),
        _createSessionFromArray = api[_Idx.createSessionFromArray]
            .cast<NativeFunction<_CreateSessionFromArrayN>>()
            .asFunction(),
        _getAllocator = api[_Idx.getAllocatorWithDefaultOptions]
            .cast<NativeFunction<_OutOnlyN>>()
            .asFunction(),
        _sessionGetInputName = api[_Idx.sessionGetInputName]
            .cast<NativeFunction<_GetIoNameN>>()
            .asFunction(),
        _sessionGetOutputName = api[_Idx.sessionGetOutputName]
            .cast<NativeFunction<_GetIoNameN>>()
            .asFunction(),
        _allocatorFree = api[_Idx.allocatorFree]
            .cast<NativeFunction<_AllocatorFreeN>>()
            .asFunction(),
        _createCpuMemoryInfo = api[_Idx.createCpuMemoryInfo]
            .cast<NativeFunction<_CreateCpuMemoryInfoN>>()
            .asFunction(),
        _createTensor = api[_Idx.createTensorWithDataAsOrtValue]
            .cast<NativeFunction<_CreateTensorN>>()
            .asFunction(),
        _run = api[_Idx.run].cast<NativeFunction<_RunN>>().asFunction(),
        _getTensorTypeAndShape = api[_Idx.getTensorTypeAndShape]
            .cast<NativeFunction<_InOutN>>()
            .asFunction(),
        _getDimensionsCount = api[_Idx.getDimensionsCount]
            .cast<NativeFunction<_GetDimensionsCountN>>()
            .asFunction(),
        _getDimensions = api[_Idx.getDimensions]
            .cast<NativeFunction<_GetDimensionsN>>()
            .asFunction(),
        _getTensorMutableData = api[_Idx.getTensorMutableData]
            .cast<NativeFunction<_InOutN>>()
            .asFunction(),
        _releaseEnv =
            api[_Idx.releaseEnv].cast<NativeFunction<_ReleaseN>>().asFunction(),
        _releaseMemoryInfo = api[_Idx.releaseMemoryInfo]
            .cast<NativeFunction<_ReleaseN>>()
            .asFunction(),
        _releaseSession =
            api[_Idx.releaseSession].cast<NativeFunction<_ReleaseN>>().asFunction(),
        _releaseValue =
            api[_Idx.releaseValue].cast<NativeFunction<_ReleaseN>>().asFunction(),
        _releaseTypeAndShape = api[_Idx.releaseTensorTypeAndShapeInfo]
            .cast<NativeFunction<_ReleaseN>>()
            .asFunction(),
        _releaseSessionOptions = api[_Idx.releaseSessionOptions]
            .cast<NativeFunction<_ReleaseN>>()
            .asFunction() {
    final out = calloc<Pointer<Void>>();
    final logId = 'map_extractor'.toNativeUtf8();
    try {
      _check(_createEnv(_loggingLevelError, logId, out));
      _env = out.value;
    } finally {
      calloc.free(out);
      calloc.free(logId);
    }
  }

  final String version;
  late final _P _env;

  final Pointer<Utf8> Function(_P) _getErrorMessage;
  final _ReleaseD _releaseStatus;
  final _CreateEnvD _createEnv;
  final _P Function(_PP) _createSessionOptions;
  final _SetIntD _setIntraOpNumThreads;
  final _SetIntD _setGraphOptimizationLevel;
  final _CreateSessionFromArrayD _createSessionFromArray;
  final _P Function(_PP) _getAllocator;
  final _GetIoNameD _sessionGetInputName;
  final _GetIoNameD _sessionGetOutputName;
  final _P Function(_P, _P) _allocatorFree;
  final _CreateCpuMemoryInfoD _createCpuMemoryInfo;
  final _CreateTensorD _createTensor;
  final _RunD _run;
  final _P Function(_P, _PP) _getTensorTypeAndShape;
  final _P Function(_P, Pointer<Size>) _getDimensionsCount;
  final _GetDimensionsD _getDimensions;
  final _P Function(_P, _PP) _getTensorMutableData;
  final _ReleaseD _releaseEnv;
  final _ReleaseD _releaseMemoryInfo;
  final _ReleaseD _releaseSession;
  final _ReleaseD _releaseValue;
  final _ReleaseD _releaseTypeAndShape;
  final _ReleaseD _releaseSessionOptions;

  /// Opens the ONNX Runtime library.
  ///
  /// Search order: [explicitPath], the ORT_DYLIB_PATH environment variable,
  /// the `lib` folder next to the executable (release bundles), the
  /// executable folder, and third_party/onnxruntime under the current
  /// directory (`flutter run` and `dart run` from the project root).
  static OnnxRuntime open({String? explicitPath}) {
    final names = Platform.isWindows
        ? const ['onnxruntime.dll']
        : const ['libonnxruntime.so.1.20.1', 'libonnxruntime.so.1', 'libonnxruntime.so'];
    final platformDir = Platform.isWindows ? 'windows-x64' : 'linux-x64';
    final exeDir = p.dirname(Platform.resolvedExecutable);
    final envPath = Platform.environment['ORT_DYLIB_PATH'];
    final candidates = <String>[
      if (explicitPath != null) explicitPath,
      if (envPath != null && envPath.isNotEmpty) envPath,
      for (final n in names) p.join(exeDir, 'lib', n),
      for (final n in names) p.join(exeDir, n),
      for (final n in names)
        p.join(Directory.current.path, 'third_party', 'onnxruntime', platformDir, n),
    ];
    final errors = <String>[];
    for (final path in candidates) {
      if (!File(path).existsSync()) continue;
      try {
        final lib = DynamicLibrary.open(path);
        final getBase = lib.lookupFunction<Pointer<_OrtApiBase> Function(),
            Pointer<_OrtApiBase> Function()>('OrtGetApiBase');
        final base = getBase().ref;
        final getApi = base.getApi.asFunction<_PP Function(int)>();
        final api = getApi(_ortApiVersion);
        if (api == nullptr) {
          errors.add('$path does not support API version $_ortApiVersion');
          continue;
        }
        final getVersion = base.getVersionString.asFunction<Pointer<Utf8> Function()>();
        return OnnxRuntime._(api, getVersion().toDartString());
      } catch (e) {
        errors.add('$path: $e');
      }
    }
    throw OrtException('Could not load the ONNX Runtime library. Tried:\n'
        '${candidates.join('\n')}\n${errors.join('\n')}');
  }

  void _check(_P status) {
    if (status == nullptr) return;
    final msg = _getErrorMessage(status).toDartString();
    _releaseStatus(status);
    throw OrtException(msg);
  }

  /// Creates a session from model bytes. [threads] 0 lets ORT choose.
  OrtSession createSession(Uint8List model, {int threads = 0}) {
    final optsOut = calloc<Pointer<Void>>();
    final sessOut = calloc<Pointer<Void>>();
    final modelPtr = calloc<Uint8>(model.length);
    try {
      _check(_createSessionOptions(optsOut));
      final opts = optsOut.value;
      try {
        _check(_setIntraOpNumThreads(opts, threads));
        _check(_setGraphOptimizationLevel(opts, _graphOptAll));
        modelPtr.asTypedList(model.length).setAll(0, model);
        _check(_createSessionFromArray(
            _env, modelPtr.cast(), model.length, opts, sessOut));
      } finally {
        _releaseSessionOptions(opts);
      }
      final session = sessOut.value;
      return OrtSession._(this, session, _ioName(session, _sessionGetInputName),
          _ioName(session, _sessionGetOutputName));
    } finally {
      calloc.free(optsOut);
      calloc.free(sessOut);
      calloc.free(modelPtr);
    }
  }

  String _ioName(_P session, _GetIoNameD getName) {
    final alloc = calloc<Pointer<Void>>();
    final name = calloc<Pointer<Utf8>>();
    try {
      _check(_getAllocator(alloc));
      _check(getName(session, 0, alloc.value, name));
      final s = name.value.toDartString();
      _check(_allocatorFree(alloc.value, name.value.cast()));
      return s;
    } finally {
      calloc.free(alloc);
      calloc.free(name);
    }
  }

  void dispose() => _releaseEnv(_env);
}

/// Output of a single-input, single-output float model.
class OrtTensor {
  OrtTensor(this.shape, this.data);
  final List<int> shape;
  final Float32List data;
}

class OrtSession {
  OrtSession._(this._rt, this._session, this.inputName, this.outputName);

  final OnnxRuntime _rt;
  final _P _session;
  final String inputName;
  final String outputName;

  /// Runs the model on one float32 tensor and returns the first output.
  OrtTensor run(Float32List input, List<int> shape) {
    final rt = _rt;
    final memInfo = calloc<Pointer<Void>>();
    final inputValue = calloc<Pointer<Void>>();
    final outputValue = calloc<Pointer<Void>>();
    final data = calloc<Float>(input.length);
    final shapePtr = calloc<Int64>(shape.length);
    final inName = inputName.toNativeUtf8();
    final outName = outputName.toNativeUtf8();
    final inNames = calloc<Pointer<Utf8>>();
    final outNames = calloc<Pointer<Utf8>>();
    final infoOut = calloc<Pointer<Void>>();
    final dataOut = calloc<Pointer<Void>>();
    final countOut = calloc<Size>();
    try {
      inNames.value = inName;
      outNames.value = outName;
      data.asTypedList(input.length).setAll(0, input);
      for (var i = 0; i < shape.length; i++) {
        shapePtr[i] = shape[i];
      }
      rt._check(rt._createCpuMemoryInfo(_arenaAllocator, _memTypeDefault, memInfo));
      rt._check(rt._createTensor(memInfo.value, data.cast(), input.length * 4,
          shapePtr, shape.length, _tensorFloat, inputValue));
      rt._check(rt._run(
          _session, nullptr, inNames, inputValue, 1, outNames, 1, outputValue));

      rt._check(rt._getTensorTypeAndShape(outputValue.value, infoOut));
      final info = infoOut.value;
      final dims = <int>[];
      try {
        rt._check(rt._getDimensionsCount(info, countOut));
        final n = countOut.value;
        final dimPtr = calloc<Int64>(n);
        try {
          rt._check(rt._getDimensions(info, dimPtr, n));
          for (var i = 0; i < n; i++) {
            dims.add(dimPtr[i]);
          }
        } finally {
          calloc.free(dimPtr);
        }
      } finally {
        rt._releaseTypeAndShape(info);
      }
      rt._check(rt._getTensorMutableData(outputValue.value, dataOut));
      final total = dims.fold<int>(1, (a, b) => a * b);
      final out = Float32List.fromList(dataOut.value.cast<Float>().asTypedList(total));
      return OrtTensor(dims, out);
    } finally {
      if (outputValue.value != nullptr) rt._releaseValue(outputValue.value);
      if (inputValue.value != nullptr) rt._releaseValue(inputValue.value);
      if (memInfo.value != nullptr) rt._releaseMemoryInfo(memInfo.value);
      calloc.free(memInfo);
      calloc.free(inputValue);
      calloc.free(outputValue);
      calloc.free(data);
      calloc.free(shapePtr);
      calloc.free(inName);
      calloc.free(outName);
      calloc.free(inNames);
      calloc.free(outNames);
      calloc.free(infoOut);
      calloc.free(dataOut);
      calloc.free(countOut);
    }
  }

  void dispose() => _rt._releaseSession(_session);
}
