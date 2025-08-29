import 'dart:async';

import 'package:android_audio_oboe/android_audio_oboe.dart'
    as android_audio_oboe;
import 'package:android_audio_oboe_example/ui/rms_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late int sumResult;
  late Future<int> sumAsyncResult;

  @override
  void initState() {
    super.initState();
    sumResult = android_audio_oboe.sum(1, 2);
    sumAsyncResult = android_audio_oboe.sumAsync(3, 4);
  }

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(fontSize: 25);
    const spacerSmall = SizedBox(height: 10);
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Native Packages')),
        body: Container(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              const Text(
                'This calls a native function through FFI that is shipped as source in the package. '
                'The native code is built as part of the Flutter Runner build.',
                style: textStyle,
                textAlign: TextAlign.center,
              ),
              spacerSmall,
              Text(
                'sum(1, 2) = $sumResult',
                style: textStyle,
                textAlign: TextAlign.center,
              ),
              spacerSmall,
              FutureBuilder<int>(
                future: sumAsyncResult,
                builder: (BuildContext context, AsyncSnapshot<int> value) {
                  final displayValue = (value.hasData) ? value.data : 'loading';
                  return Text(
                    'await sumAsync(3, 4) = $displayValue',
                    style: textStyle,
                    textAlign: TextAlign.center,
                  );
                },
              ),
              spacerSmall,
              ElevatedButton(
                onPressed: () async {
                  final data = await rootBundle.load(
                    'assets/beep_48000_16bit.raw',
                  );
                  final int16List = data.buffer.asInt16List();
                  android_audio_oboe.loadBeepData(int16List);
                  android_audio_oboe.playBeep();
                },
                child: Text("Press me."),
              ),
              Expanded(child: RecorderView()),
            ],
          ),
        ),
      ),
    );
  }
}
