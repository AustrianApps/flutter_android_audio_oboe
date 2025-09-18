import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:android_audio_oboe/android_audio_oboe.dart';
import 'package:iirjdart/butterworth.dart';
import 'package:logging/logging.dart';

final _logger = Logger('rms_recorder');

class OboeRmsRecorder {
  final int rmsCalcFrameSize;
  late final OboeRecorder recorder;
  final _sink = StreamController<double>();
  Stream<double> get stream => _sink.stream;
  var lastSampleCount = -1;

  OboeRmsRecorder.startRecording({
    this.rmsCalcFrameSize = 40,
    int sampleRate = 8000,
    int framesPerDataCallback = 0,
    int deviceId = 0,
  }) {
    final butterworth = Butterworth();
    butterworth.bandPass(6, 8000, 300, 400);
    recorder = OboeRecorder.startRecording(
      sampleRate: sampleRate,
      framesPerDataCallback: framesPerDataCallback,
      deviceId: deviceId,
    );
    final rmsCalculator = RmsCalculator(
      rmsCalcFrameSize: rmsCalcFrameSize,
      filter: butterworth,
    );
    _logger.info(
      'Staring recording with rmsCalcFrameSize: $rmsCalcFrameSize , butterworth: $butterworth',
    );
    recorder.stream.listen((data) {
      for (final x in data) {
        if (x < -1 || x > 1) {
          _logger.warning('Invalid sample. return. x: $x');
          return;
        }
      }
      if (lastSampleCount != data.length) {
        lastSampleCount = data.length;
        _logger.fine('sample size: $lastSampleCount');
        print('sample size: $lastSampleCount');
      }
      rmsCalculator.calcRms(data, (rms) {
        _sink.add(rms);
      });
    });
  }

  void stop() {
    recorder.stop();
    _sink.close();
  }

  double _calcRms(Float32List audioData, Butterworth? filter) {
    final absData = Float32List(audioData.length);
    for (var i = 0; audioData.length > i; i++) {
      var v = audioData[i];
      if (filter != null) {
        v = filter.filter(v);
      }
      absData[i] = pow(v, 2.0).toDouble();
    }

    return sqrt(absData.reduce((a, b) => a + b) / absData.length);
  }
}

class RmsCalculator {
  RmsCalculator({
    required this.rmsCalcFrameSize,
    required this.filter,
  });

  final int rmsCalcFrameSize;
  final Butterworth? filter;

  double _absValue = 0;
  int _absCount = 0;

  void calcRms(Float32List audioData, void Function(double rms) onRms) {
    for (var i = 0; audioData.length > i; i++) {
      final v = filter?.filter(audioData[i]) ?? audioData[i];
      _absValue += pow(v, 2.0).toDouble();
      _absCount++;
      if (_absCount > rmsCalcFrameSize) {
        final rms = sqrt(_absValue / _absCount);
        _absValue = 0;
        _absCount = 0;
        onRms(rms);
      }
    }
  }
}
