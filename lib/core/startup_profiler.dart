import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

class StartupProfiler {
  const StartupProfiler._();

  static final Stopwatch _stopwatch = Stopwatch();

  static void start() {
    if (!kProfileMode) return;
    _stopwatch
      ..reset()
      ..start();
    mark('app_start');
  }

  static void mark(String event, [Map<String, Object?> arguments = const {}]) {
    if (!kProfileMode) return;
    final elapsedMilliseconds = _stopwatch.elapsedMicroseconds / 1000;
    final details = <String, Object?>{
      'elapsed_ms': elapsedMilliseconds,
      ...arguments,
    };
    developer.Timeline.instantSync(event, arguments: details);
    final message =
        '$event elapsed_ms=${elapsedMilliseconds.toStringAsFixed(1)} '
                '${arguments.entries.map((entry) => '${entry.key}=${entry.value}').join(' ')}'
            .trimRight();
    developer.log(message, name: 'SkeChatStartup');
    debugPrint('[SkeChatStartup] $message');
  }
}
