import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/data/timed_task_runtime_service.dart';

/// Shared one-second UI clock.
///
/// Once TimedTaskRuntime has synchronized, every countdown/progress widget reads
/// the same server-authoritative clock anchor. The device clock is only a
/// startup fallback before the first authenticated runtime snapshot arrives.
final secondTickerProvider = StreamProvider.autoDispose<DateTime>((ref) async* {
  DateTime currentTime() {
    return ref.read(timedTaskRuntimeServiceProvider).serverNow ?? DateTime.now();
  }

  yield currentTime();
  yield* Stream<DateTime>.periodic(
    const Duration(seconds: 1),
    (_) => currentTime(),
  );
});
