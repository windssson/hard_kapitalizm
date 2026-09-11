import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/data/timed_task_runtime_revision.dart';
import 'package:hard_kapitalizm/core/data/timed_task_runtime_service.dart';
import 'package:hard_kapitalizm/features/notification/data/push_notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TimedTaskRuntime extends ConsumerStatefulWidget {
  const TimedTaskRuntime({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<TimedTaskRuntime> createState() => _TimedTaskRuntimeState();
}

class _TimedTaskRuntimeState extends ConsumerState<TimedTaskRuntime>
    with WidgetsBindingObserver {
  static const Duration _errorRetryInterval = Duration(seconds: 10);

  Timer? _timer;
  StreamSubscription<AuthState>? _authSubscription;
  bool _isRunning = false;
  bool _needsReschedule = false;
  AppLifecycleState? _lastLifecycleState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((authState) {
      if (!mounted) return;

      if (authState.session == null) {
        _timer?.cancel();
        _timer = null;
        ref.read(timedTaskRuntimeServiceProvider).resetClock();
        return;
      }

      _scheduleNextRun(Duration.zero);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleNextRun(Duration.zero);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lastLifecycleState = state;

    if (state == AppLifecycleState.resumed) {
      _scheduleNextRun(Duration.zero);
      try {
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          ref.read(pushNotificationServiceProvider).initialize();
        }
      } catch (_) {}
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _timer?.cancel();
      _timer = null;
    }
  }

  bool get _isForeground {
    final state = _lastLifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  void _onRuntimeRevisionChanged() {
    if (_isRunning) {
      _needsReschedule = true;
      return;
    }
    _scheduleNextRun(Duration.zero);
  }

  void _scheduleNextRun(Duration? delay) {
    _timer?.cancel();
    _timer = null;

    if (delay == null || !mounted || !_isForeground) return;
    if (Supabase.instance.client.auth.currentUser == null) return;

    _timer = Timer(delay, _runCycle);
  }

  Duration? _delayUntil(DateTime? nextDueAt) {
    if (nextDueAt == null) return null;

    final serverNow = ref.read(timedTaskRuntimeServiceProvider).serverNow;
    if (serverNow == null) return Duration.zero;

    final delay = nextDueAt.difference(serverNow);
    return delay <= Duration.zero ? Duration.zero : delay;
  }

  Future<void> _runCycle() async {
    if (!mounted || !_isForeground || _isRunning) return;
    if (Supabase.instance.client.auth.currentUser == null) return;

    _isRunning = true;
    _needsReschedule = false;

    try {
      final service = ref.read(timedTaskRuntimeServiceProvider);
      var snapshot = await service.fetchSnapshot();
      if (snapshot == null) {
        _scheduleNextRun(null);
        return;
      }

      var serverNow = service.serverNow ?? snapshot.serverTime;
      final dueTasks = snapshot.dueAt(serverNow);

      if (dueTasks.isNotEmpty) {
        final dueKeys = dueTasks.map((task) => task.key).toSet();
        final completion = await service.completeDueTasks(dueTasks);

        // Always re-read authoritative state after completion attempts. This
        // makes cron/client races convergent: if the server completed a task
        // first, its disappearance from this fresh snapshot counts as success.
        final refreshed = await service.fetchSnapshot();
        if (refreshed == null) {
          _scheduleNextRun(null);
          return;
        }

        snapshot = refreshed;
        serverNow = service.serverNow ?? snapshot.serverTime;

        final refreshedKeys = snapshot.taskKeys;
        final unresolvedFailures = completion.failedTaskKeys
            .where(refreshedKeys.contains)
            .toSet();
        final stillDueFromThisBatch = snapshot
            .dueAt(serverNow)
            .map((task) => task.key)
            .where(dueKeys.contains)
            .toSet();

        if (unresolvedFailures.isNotEmpty ||
            stillDueFromThisBatch.isNotEmpty) {
          debugPrint(
            '[TimedTaskRuntime] unresolved due tasks: '
            '${{...unresolvedFailures, ...stillDueFromThisBatch}}',
          );
          _scheduleNextRun(_errorRetryInterval);
          return;
        }

        // Another task may have become due while completions were running.
        if (snapshot.dueAt(serverNow).isNotEmpty) {
          _scheduleNextRun(Duration.zero);
          return;
        }
      }

      _scheduleNextRun(_delayUntil(snapshot.nextDueAfter(serverNow)));
    } catch (e, stackTrace) {
      // Snapshot/network failures must never silently turn the runtime off.
      debugPrint('Unhandled error in TimedTaskRuntime cycle: $e\n$stackTrace');
      _scheduleNextRun(_errorRetryInterval);
    } finally {
      _isRunning = false;
      if (_needsReschedule) {
        _needsReschedule = false;
        _scheduleNextRun(Duration.zero);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(timedTaskRuntimeRevisionProvider, (previous, next) {
      if (previous != next) {
        _onRuntimeRevisionChanged();
      }
    });

    return widget.child;
  }
}
