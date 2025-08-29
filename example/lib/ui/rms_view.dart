import 'dart:async';
import 'dart:typed_data';

import 'package:android_audio_oboe/android_audio_oboe.dart';
import 'package:android_audio_oboe_example/ui/rms_painter.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class RecorderView extends StatefulWidget {
  const RecorderView({super.key});

  @override
  State<RecorderView> createState() => _RecorderViewState();
}

class _RecorderViewState extends State<RecorderView> {
  OboeRecorder? _recorder;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Column(
      children: [
        if (_recorder case final recorder?) ...[
          Expanded(
            child: RmsView(
              stream: recorder.stream,
              maxRmsLength: mq.size.width.toInt(),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              recorder.stop();
              _recorder = null;
              setState(() {});
            },
            child: Text('stop'),
          ),
        ] else ...[
          ElevatedButton(
            onPressed: () async {
              final result = await Permission.microphone.request();
              print('permission result: $result');
              _recorder = startRecording();
              setState(() {});
            },
            child: Text('Start Recorder'),
          ),
        ],
      ],
    );
  }
}

class RmsView extends StatefulWidget {
  const RmsView({
    super.key,
    required this.maxRmsLength,
    required this.stream,
  });
  final Stream<Float32List> stream;
  final int maxRmsLength;

  @override
  State<RmsView> createState() => _RmsViewState();
}

class _RmsViewState extends State<RmsView> {
  final _rmsList = <double>[];

  StreamSubscription<Float32List>? _subscription;

  @override
  void initState() {
    super.initState();
    _updateListeners();
  }

  @override
  void didUpdateWidget(covariant RmsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stream != widget.stream ||
        widget.maxRmsLength != oldWidget.maxRmsLength) {
      _updateListeners();
    }
  }

  void _updateListeners() {
    print('maxRmsLength: ${widget.maxRmsLength}');
    _subscription?.cancel();
    _subscription = widget.stream.listen((event) {
      _rmsList.addAll(event);
      if (_rmsList.length > widget.maxRmsLength) {
        _rmsList.removeRange(0, _rmsList.length - widget.maxRmsLength);
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(double.infinity, double.infinity),
      painter: RmsPainter(_rmsList, widget.maxRmsLength),
    );
  }
}
