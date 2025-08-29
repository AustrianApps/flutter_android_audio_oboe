import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:android_audio_oboe/android_audio_oboe.dart';
import 'package:iirjdart/butterworth.dart';

class OboeRmsRecorder {
  final int rmsCalcFrameSize;
  late final OboeRecorder recorder;
  final _sink = StreamController<double>();
  Stream<double> get stream => _sink.stream;

  OboeRmsRecorder.startRecording({this.rmsCalcFrameSize = 40}) {
    final butterworth = Butterworth();
    butterworth.bandPass(6, 8000, 300, 400);
    recorder = OboeRecorder.startRecording();
    recorder.stream.listen((data) {
      if (rmsCalcFrameSize <= 0) {
        final rms = _calcRms(data, butterworth);
        _sink.add(rms);
      } else {
        final availableSamples = data.length;
        final samplesPerFrame = rmsCalcFrameSize;
        for (
          int start = 0;
          start < availableSamples;
          start += samplesPerFrame
        ) {
          final rms = _calcRms(
            data.sublist(start, min(data.length, start + samplesPerFrame)),
            butterworth,
          );
          // _logger.finer("sending $rms (${frameList.length})");
          _sink.add(rms);
        }
      }
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
