import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:logging/logging.dart';

import 'android_audio_oboe_bindings_generated.dart';

export './src/rms_recorder.dart';

final _logger = Logger('android_audio_oboe');

/// A very short-lived native function.
///
/// For very short-lived functions, it is fine to call them on the main isolate.
/// They will block the Dart execution while running the native function, so
/// only do this for native functions which are guaranteed to be short-lived.
int sum(int a, int b) => _bindings.sum(a, b);

/// A longer lived native function, which occupies the thread calling it.
///
/// Do not call these kind of native functions in the main isolate. They will
/// block Dart execution. This will cause dropped frames in Flutter applications.
/// Instead, call these native functions on a separate isolate.
///
/// Modify this to suit your own use case. Example use cases:
///
/// 1. Reuse a single isolate for various different kinds of requests.
/// 2. Use multiple helper isolates for parallel execution.
Future<int> sumAsync(int a, int b) async {
  final SendPort helperIsolateSendPort = await _helperIsolateSendPort;
  final int requestId = _nextSumRequestId++;
  final _SumRequest request = _SumRequest(requestId, a, b);
  final Completer<int> completer = Completer<int>();
  _sumRequests[requestId] = completer;
  helperIsolateSendPort.send(request);
  return completer.future;
}

enum PlayBeepCallback {
  started,
  finished,
}

void playBeep(void Function(PlayBeepCallback type, int sec, int usec) cb) {
  late final NativeCallable<Void Function(Int, Long, Long)> callback;
  void playBeepCallback(int type, int sec, int usec) {
    switch (type) {
      case 1:
        // start beep;
        cb(PlayBeepCallback.started, sec, usec);
        break;
      case 2:
        // beep finished.
        cb(PlayBeepCallback.finished, sec, usec);
        callback.close();
        break;
      default:
        throw UnsupportedError('Unsupported type: $type');
    }
  }

  callback = NativeCallable<Void Function(Int, ffi.Long, ffi.Long)>.listener(
    playBeepCallback,
  );
  _bindings.my_play_beep(callback.nativeFunction);
}

void loadBeepData(Int16List data) {
  final pointer = malloc.allocate<Int16>(data.length * 2);
  pointer.asTypedList(data.length * 2).setAll(0, data);
  _bindings.load_beep_data(pointer, data.length);
}

class OboeRecorder {
  OboeRecorder.startRecording({
    int sampleRate = 8000,
    int framesPerDataCallback = 0,
    int deviceId = 0,
  }) {
    _bindings.oboe_options(
      sampleRate,
      framesPerDataCallback,
      deviceId,
    );
    // ffi.Void onData(ffi.Pointer<ffi.Float> data, ffi.Int size) {}
    callback =
        NativeCallable<ffi.Void Function(ffi.Pointer<Float>, ffi.Int)>.listener(
          onData,
        );
    onErrorAfterCloseCallback =
        NativeCallable<Void Function(ffi.Int32)>.listener(
          onErrorAfterClose,
        );

    final ret = _bindings.start_recording(
      callback.nativeFunction,
      onErrorAfterCloseCallback.nativeFunction,
    );
    if (ret != 0) {
      callback.close();
      onErrorAfterCloseCallback.close();
      throw StateError('Error while starting recording.');
    }
  }

  late final NativeCallable<Void Function(Pointer<Float>, Int)> callback;
  late final NativeCallable<Void Function(ffi.Int32)> onErrorAfterCloseCallback;
  final sink = StreamController<Float32List>(sync: true);
  late final stream = sink.stream;

  void onData(ffi.Pointer<ffi.Float> data, int size) {
    final rmsData = data.asTypedList(size);
    sink.add(rmsData);
    calloc.free(data);
  }

  void onErrorAfterClose(int errorCode) {
    final result = OboeResult.fromValue(errorCode);
    _logger.fine(
      'onErrorAfterClose $errorCode ($result). Closing stream. and disposing.',
    );
    sink.addError(StateError('Error while recording. $errorCode $result'));
    sink.close();
    dispose();
  }

  void setRecorderOptions({
    int sampleRate = 8000,
    int framesPerDataCallback = 0,
    int deviceId = 0,
  }) {
    _bindings.oboe_options(
      sampleRate,
      framesPerDataCallback,
      deviceId,
    );
  }

  void stop() {
    _bindings.stop_recording();
    dispose();
  }

  void dispose() {
    sink.close();
    callback.close();
    onErrorAfterCloseCallback.close();
  }
}

OboeRecorder? startRecording() {
  return OboeRecorder.startRecording();
}

const String _libName = 'android_audio_oboe';

/// The dynamic library in which the symbols for [AndroidAudioOboeBindings] can be found.
final DynamicLibrary _dylib = () {
  if (Platform.isMacOS || Platform.isIOS) {
    return DynamicLibrary.open('$_libName.framework/$_libName');
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('lib$_libName.so');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('$_libName.dll');
  }
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}();

/// The bindings to the native functions in [_dylib].
final AndroidAudioOboeBindings _bindings = AndroidAudioOboeBindings(_dylib);

/// A request to compute `sum`.
///
/// Typically sent from one isolate to another.
class _SumRequest {
  final int id;
  final int a;
  final int b;

  const _SumRequest(this.id, this.a, this.b);
}

/// A response with the result of `sum`.
///
/// Typically sent from one isolate to another.
class _SumResponse {
  final int id;
  final int result;

  const _SumResponse(this.id, this.result);
}

/// Counter to identify [_SumRequest]s and [_SumResponse]s.
int _nextSumRequestId = 0;

/// Mapping from [_SumRequest] `id`s to the completers corresponding to the correct future of the pending request.
final Map<int, Completer<int>> _sumRequests = <int, Completer<int>>{};

/// The SendPort belonging to the helper isolate.
Future<SendPort> _helperIsolateSendPort = () async {
  // The helper isolate is going to send us back a SendPort, which we want to
  // wait for.
  final Completer<SendPort> completer = Completer<SendPort>();

  // Receive port on the main isolate to receive messages from the helper.
  // We receive two types of messages:
  // 1. A port to send messages on.
  // 2. Responses to requests we sent.
  final ReceivePort receivePort = ReceivePort()
    ..listen((dynamic data) {
      if (data is SendPort) {
        // The helper isolate sent us the port on which we can sent it requests.
        completer.complete(data);
        return;
      }
      if (data is _SumResponse) {
        // The helper isolate sent us a response to a request we sent.
        final Completer<int> completer = _sumRequests[data.id]!;
        _sumRequests.remove(data.id);
        completer.complete(data.result);
        return;
      }
      throw UnsupportedError('Unsupported message type: ${data.runtimeType}');
    });

  // Start the helper isolate.
  await Isolate.spawn((SendPort sendPort) async {
    final ReceivePort helperReceivePort = ReceivePort()
      ..listen((dynamic data) {
        // On the helper isolate listen to requests and respond to them.
        if (data is _SumRequest) {
          final int result = _bindings.sum_long_running(data.a, data.b);
          final _SumResponse response = _SumResponse(data.id, result);
          sendPort.send(response);
          return;
        }
        throw UnsupportedError('Unsupported message type: ${data.runtimeType}');
      });

    // Send the port to the main isolate on which we can receive requests.
    sendPort.send(helperReceivePort.sendPort);
  }, receivePort.sendPort);

  // Wait until the helper isolate has sent us back the SendPort on which we
  // can start sending requests.
  return completer.future;
}();

enum OboeResult {
  ok(0), // AAUDIO_OK
  errorBase(-900), // AAUDIO_ERROR_BASE
  errorDisconnected(-899), // AAUDIO_ERROR_DISCONNECTED
  errorIllegalArgument(-898), // AAUDIO_ERROR_ILLEGAL_ARGUMENT
  errorInternal(-896), // AAUDIO_ERROR_INTERNAL
  errorInvalidState(-895), // AAUDIO_ERROR_INVALID_STATE
  errorInvalidHandle(-892), // AAUDIO_ERROR_INVALID_HANDLE
  errorUnimplemented(-890), // AAUDIO_ERROR_UNIMPLEMENTED
  errorUnavailable(-889), // AAUDIO_ERROR_UNAVAILABLE
  errorNoFreeHandles(-888), // AAUDIO_ERROR_NO_FREE_HANDLES
  errorNoMemory(-887), // AAUDIO_ERROR_NO_MEMORY
  errorNull(-886), // AAUDIO_ERROR_NULL
  errorTimeout(-885), // AAUDIO_ERROR_TIMEOUT
  errorWouldBlock(-884), // AAUDIO_ERROR_WOULD_BLOCK
  errorInvalidFormat(-883), // AAUDIO_ERROR_INVALID_FORMAT
  errorOutOfRange(-882), // AAUDIO_ERROR_OUT_OF_RANGE
  errorNoService(-881), // AAUDIO_ERROR_NO_SERVICE
  errorInvalidRate(-880), // AAUDIO_ERROR_INVALID_RATE
  reserved1(-879),
  reserved2(-878),
  reserved3(-877),
  reserved4(-876),
  reserved5(-875),
  reserved6(-874),
  reserved7(-873),
  reserved8(-872),
  reserved9(-871),
  reserved10(-870),
  errorClosed(-869),
  unknown(-999);

  final int value;
  const OboeResult(this.value);

  /// Converts an int into a Result enum value.
  /// Returns null if no matching value exists.
  static OboeResult fromValue(int value) {
    return OboeResult.values.firstWhere(
      (e) => e.value == value,
      orElse: () => OboeResult.unknown,
    );
  }
}
