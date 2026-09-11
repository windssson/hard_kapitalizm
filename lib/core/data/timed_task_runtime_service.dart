import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/data/mutation_sync_service.dart';
import 'package:hard_kapitalizm/core/models/timed_task_runtime_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class TimedTaskCompletionResult {
  const TimedTaskCompletionResult({
    required this.failedTaskKeys,
    this.originToken,
  });

  final Set<String> failedTaskKeys;
  final String? originToken;

  bool get hasFailures => failedTaskKeys.isNotEmpty;
}

class TimedTaskEventApplyResult {
  const TimedTaskEventApplyResult({
    required this.appliedCount,
    required this.ignoredLocalCount,
    required this.missingChangedCount,
  });

  final int appliedCount;
  final int ignoredLocalCount;
  final int missingChangedCount;
}

class TimedTaskRuntimeService {
  TimedTaskRuntimeService(this._ref);

  static const int _rememberedOriginLimit = 32;

  final Ref _ref;
  final SupabaseClient _supabase = Supabase.instance.client;
  final Uuid _uuid = const Uuid();
  final Set<String> _locallyAppliedOrigins = <String>{};
  final ListQueue<String> _originOrder = ListQueue<String>();

  DateTime? _serverAnchor;
  Stopwatch? _serverStopwatch;

  DateTime? get serverNow {
    final anchor = _serverAnchor;
    final stopwatch = _serverStopwatch;
    if (anchor == null || stopwatch == null) return null;
    return anchor.add(stopwatch.elapsed);
  }

  void resetClock() {
    _serverStopwatch?.stop();
    _serverStopwatch = null;
    _serverAnchor = null;
    _locallyAppliedOrigins.clear();
    _originOrder.clear();
  }

  Future<TimedTaskRuntimeSnapshot?> fetchSnapshot({int? afterEventId}) async {
    if (_supabase.auth.currentUser == null) {
      resetClock();
      return null;
    }

    final dynamic response = afterEventId == null
        ? await _supabase.rpc('get_timed_task_runtime_state')
        : await _supabase.rpc(
            'get_timed_task_runtime_state',
            params: {'p_after_event_id': afterEventId},
          );

    if (response is! Map) {
      throw const FormatException('Timed runtime response is not an object.');
    }

    final snapshot = TimedTaskRuntimeSnapshot.fromJson(
      Map<String, dynamic>.from(response),
    );

    // Anchor the clock at response receipt. This intentionally leaves the
    // client a tiny bit behind server time (roughly response latency), which
    // prevents early completion attempts while avoiding device-clock drift.
    _serverStopwatch?.stop();
    _serverAnchor = snapshot.serverTime;
    _serverStopwatch = Stopwatch()..start();

    return snapshot;
  }

  TimedTaskEventApplyResult applyRuntimeEvents(
    List<TimedTaskRuntimeEvent> events,
  ) {
    var appliedCount = 0;
    var ignoredLocalCount = 0;
    var missingChangedCount = 0;

    for (final event in events) {
      final origin = event.originToken;
      if (origin != null && _locallyAppliedOrigins.contains(origin)) {
        ignoredLocalCount++;
        continue;
      }

      final changed = event.changed;
      if (changed == null) {
        missingChangedCount++;
        debugPrint(
          '[TimedTaskRuntime] external event has no changed envelope: '
          '${event.eventId}/${event.taskKey}/${event.terminalStatus}',
        );
        continue;
      }

      _ref.read(mutationSyncServiceProvider).applyRaw({
        'success': true,
        'changed': changed,
      });
      appliedCount++;
    }

    return TimedTaskEventApplyResult(
      appliedCount: appliedCount,
      ignoredLocalCount: ignoredLocalCount,
      missingChangedCount: missingChangedCount,
    );
  }

  Future<TimedTaskCompletionResult> completeDueTasks(
    List<TimedTaskRuntimeTask> tasks,
  ) async {
    if (tasks.isEmpty) {
      return const TimedTaskCompletionResult(failedTaskKeys: <String>{});
    }

    if (_supabase.auth.currentUser == null) {
      return TimedTaskCompletionResult(
        failedTaskKeys: tasks.map((task) => task.key).toSet(),
      );
    }

    final requestedKeys = tasks.map((task) => task.key).toSet();
    final failed = <String>{...requestedKeys};
    final originToken = _uuid.v4();

    try {
      final response = await _supabase.rpc(
        'complete_timed_task_runtime_due',
        params: {
          'p_tasks': tasks
              .map(
                (task) => <String, dynamic>{
                  'kind': task.kind,
                  'id': task.id,
                },
              )
              .toList(growable: false),
          'p_origin_token': originToken,
        },
      );

      if (response is! Map) {
        throw const FormatException(
          'complete_timed_task_runtime_due response is not an object.',
        );
      }

      final result = Map<String, dynamic>.from(response);
      _rememberOrigin(originToken);

      // The runtime RPC aggregates every committed domain mutation into one
      // standard `changed` envelope, so provider state is patched once per
      // completion wave instead of once per timed task.
      _ref.read(mutationSyncServiceProvider).applyRaw(result);

      if (result['success'] != true) {
        debugPrint(
          '[TimedTaskRuntime] complete_timed_task_runtime_due returned '
          'unsuccessful: ${result['message'] ?? result}',
        );
        return TimedTaskCompletionResult(
          failedTaskKeys: failed,
          originToken: originToken,
        );
      }

      final rawOutcomes = result['outcomes'];
      if (rawOutcomes is List) {
        for (final raw in rawOutcomes) {
          if (raw is! Map) continue;
          final outcome = Map<String, dynamic>.from(raw);
          final key = outcome['key']?.toString().trim() ?? '';
          if (!requestedKeys.contains(key)) continue;

          if (outcome['success'] == true) {
            failed.remove(key);
          } else {
            debugPrint(
              '[TimedTaskRuntime] timed task completion failed for $key: '
              '${outcome['message'] ?? outcome}',
            );
          }
        }
      }

      final returnedOrigin = result['origin_token']?.toString().trim();
      if (returnedOrigin != null &&
          returnedOrigin.isNotEmpty &&
          returnedOrigin != originToken) {
        debugPrint(
          '[TimedTaskRuntime] runtime origin token mismatch: '
          '$returnedOrigin != $originToken',
        );
      }
    } catch (e, st) {
      debugPrint(
        '[TimedTaskRuntime] complete_timed_task_runtime_due failed: $e\n$st',
      );
    }

    return TimedTaskCompletionResult(
      failedTaskKeys: failed,
      originToken: originToken,
    );
  }

  void _rememberOrigin(String token) {
    if (!_locallyAppliedOrigins.add(token)) return;
    _originOrder.addLast(token);

    while (_originOrder.length > _rememberedOriginLimit) {
      final oldest = _originOrder.removeFirst();
      _locallyAppliedOrigins.remove(oldest);
    }
  }
}

final timedTaskRuntimeServiceProvider = Provider<TimedTaskRuntimeService>((ref) {
  return TimedTaskRuntimeService(ref);
});
