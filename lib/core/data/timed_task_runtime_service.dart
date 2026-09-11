import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/data/mutation_sync_service.dart';
import 'package:hard_kapitalizm/core/models/timed_task_runtime_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TimedTaskCompletionResult {
  const TimedTaskCompletionResult({
    required this.failedTaskKeys,
    required this.originToken,
  });

  final Set<String> failedTaskKeys;
  final String originToken;

  bool get hasFailures => failedTaskKeys.isNotEmpty;
}

class TimedTaskRuntimeService {
  TimedTaskRuntimeService(this._ref);

  final Ref _ref;
  final SupabaseClient _supabase = Supabase.instance.client;
  final Random _random = Random.secure();

  DateTime? _serverAnchor;
  Stopwatch? _serverStopwatch;
  int? _lastEventRevision;
  int _originSequence = 0;
  bool _isApplyingCompletion = false;

  DateTime? get serverNow {
    final anchor = _serverAnchor;
    final stopwatch = _serverStopwatch;
    if (anchor == null || stopwatch == null) return null;
    return anchor.add(stopwatch.elapsed);
  }

  bool get isApplyingCompletion => _isApplyingCompletion;

  void resetClock() {
    _serverStopwatch?.stop();
    _serverStopwatch = null;
    _serverAnchor = null;
    _lastEventRevision = null;
  }

  Future<TimedTaskRuntimeSnapshot?> fetchSnapshot({
    Set<String> ignoredOriginTokens = const <String>{},
  }) async {
    if (_supabase.auth.currentUser == null) {
      resetClock();
      return null;
    }

    var cursor = _lastEventRevision;
    final accumulatedEvents = <TimedTaskRuntimeEvent>[];
    TimedTaskRuntimeSnapshot? latest;

    // A page is capped server-side. Normal gameplay will use one page, but the
    // loop prevents long background periods from dropping completion events.
    for (var pageIndex = 0; pageIndex < 20; pageIndex++) {
      final dynamic response = cursor == null
          ? await _supabase.rpc('get_timed_task_runtime_state')
          : await _supabase.rpc(
              'get_timed_task_runtime_state',
              params: {'p_after_event_id': cursor},
            );

      if (response is! Map) {
        throw const FormatException('Timed runtime response is not an object.');
      }

      final page = TimedTaskRuntimeSnapshot.fromJson(
        Map<String, dynamic>.from(response),
      );
      latest = page;

      // First fetch establishes the cursor. Providers are freshly bootstrapped
      // on a new app session, so historical terminal events are intentionally
      // not replayed from the beginning of time.
      if (_lastEventRevision == null) {
        cursor = page.eventRevision;
        break;
      }

      accumulatedEvents.addAll(page.events);

      if (!page.eventsHasMore) {
        cursor = page.eventRevision;
        break;
      }

      if (page.events.isEmpty) {
        debugPrint(
          '[TimedTaskRuntime] event page reported more rows but contained none; '
          'advancing to authoritative revision ${page.eventRevision}.',
        );
        cursor = page.eventRevision;
        break;
      }

      cursor = page.events.last.eventId;
    }

    if (latest == null) return null;

    _lastEventRevision = cursor ?? latest.eventRevision;

    // Anchor the clock at response receipt. This intentionally leaves the
    // client a tiny bit behind server time (roughly response latency), which
    // prevents early completion attempts while avoiding device-clock drift.
    _serverStopwatch?.stop();
    _serverAnchor = latest.serverTime;
    _serverStopwatch = Stopwatch()..start();

    final externalEvents = accumulatedEvents
        .where(
          (event) =>
              event.originToken == null ||
              !ignoredOriginTokens.contains(event.originToken),
        )
        .toList(growable: false);

    return TimedTaskRuntimeSnapshot(
      serverTime: latest.serverTime,
      eventRevision: _lastEventRevision ?? latest.eventRevision,
      events: List.unmodifiable(externalEvents),
      eventsHasMore: false,
      tasks: latest.tasks,
    );
  }

  Future<TimedTaskCompletionResult> completeDueTasks(
    List<TimedTaskRuntimeTask> tasks,
  ) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return TimedTaskCompletionResult(
        failedTaskKeys: tasks.map((task) => task.key).toSet(),
        originToken: '',
      );
    }

    if (tasks.isEmpty) {
      return const TimedTaskCompletionResult(
        failedTaskKeys: <String>{},
        originToken: '',
      );
    }

    final originToken = _newOriginToken(user.id);
    final requestedKeys = tasks.map((task) => task.key).toSet();
    final failed = <String>{};

    _isApplyingCompletion = true;
    try {
      final result = await _callAndSync(
        'complete_timed_task_runtime_due',
        params: {
          'p_tasks': tasks.map((task) => task.toCompletionJson()).toList(),
          'p_origin_token': originToken,
        },
      );

      final successfulKeys = <String>{};
      final outcomes = result['outcomes'] as List<dynamic>? ?? const [];
      for (final raw in outcomes) {
        if (raw is! Map) continue;
        final outcome = Map<String, dynamic>.from(raw);
        final key = outcome['key']?.toString().trim() ?? '';
        if (key.isEmpty || !requestedKeys.contains(key)) continue;

        if (outcome['success'] == true) {
          successfulKeys.add(key);
        } else {
          failed.add(key);
          debugPrint(
            '[TimedTaskRuntime] completion failed for $key: '
            '${outcome['message'] ?? 'Unknown backend error'}',
          );
        }
      }

      for (final key in requestedKeys) {
        if (!successfulKeys.contains(key) && !failed.contains(key)) {
          failed.add(key);
          debugPrint(
            '[TimedTaskRuntime] completion response had no outcome for $key.',
          );
        }
      }
    } catch (e, st) {
      failed.addAll(requestedKeys);
      debugPrint('[TimedTaskRuntime] batch completion RPC failed: $e\n$st');
    } finally {
      _isApplyingCompletion = false;
    }

    return TimedTaskCompletionResult(
      failedTaskKeys: failed,
      originToken: originToken,
    );
  }

  String _newOriginToken(String userId) {
    _originSequence += 1;
    final randomPart = _random.nextInt(0x7fffffff).toRadixString(16);
    return '$userId:$_originSequence:$randomPart';
  }

  Future<Map<String, dynamic>> _callAndSync(
    String rpc, {
    Map<String, dynamic>? params,
  }) async {
    final dynamic response = params == null
        ? await _supabase.rpc(rpc)
        : await _supabase.rpc(rpc, params: params);

    if (response is! Map) {
      throw FormatException('$rpc response is not an object.');
    }

    final result = Map<String, dynamic>.from(response);
    _ref.read(mutationSyncServiceProvider).applyRaw(result);
    return result;
  }
}

final timedTaskRuntimeServiceProvider = Provider<TimedTaskRuntimeService>((ref) {
  return TimedTaskRuntimeService(ref);
});
