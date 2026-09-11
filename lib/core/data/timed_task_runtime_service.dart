import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/data/mutation_sync_service.dart';
import 'package:hard_kapitalizm/core/models/timed_task_runtime_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TimedTaskCompletionResult {
  const TimedTaskCompletionResult({required this.failedTaskKeys});

  final Set<String> failedTaskKeys;

  bool get hasFailures => failedTaskKeys.isNotEmpty;
}

class TimedTaskRuntimeService {
  TimedTaskRuntimeService(this._ref);

  final Ref _ref;
  final SupabaseClient _supabase = Supabase.instance.client;

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
  }

  Future<TimedTaskRuntimeSnapshot?> fetchSnapshot() async {
    if (_supabase.auth.currentUser == null) {
      resetClock();
      return null;
    }

    final response = await _supabase.rpc('get_timed_task_runtime_state');
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

  Future<TimedTaskCompletionResult> completeDueTasks(
    List<TimedTaskRuntimeTask> tasks,
  ) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return TimedTaskCompletionResult(
        failedTaskKeys: tasks.map((task) => task.key).toSet(),
      );
    }

    final failed = <String>{};

    Future<void> completeSingle(
      TimedTaskRuntimeTask task,
      String rpc, {
      Map<String, dynamic>? params,
    }) async {
      try {
        final result = await _callAndSync(rpc, params: params);
        if (result['success'] != true) {
          failed.add(task.key);
          debugPrint(
            '[TimedTaskRuntime] $rpc returned unsuccessful for ${task.key}: '
            '${result['message'] ?? result}',
          );
        }
      } catch (e, st) {
        failed.add(task.key);
        debugPrint(
          '[TimedTaskRuntime] $rpc failed for ${task.key}: $e\n$st',
        );
      }
    }

    final transfers = tasks
        .where((task) => task.kind == 'logistics_transfer')
        .toList(growable: false);
    for (final task in transfers) {
      await completeSingle(
        task,
        'complete_logistics_transfer',
        params: {'p_transfer_id': task.id},
      );
    }

    final researches = tasks
        .where((task) => task.kind == 'arge_research')
        .toList(growable: false);
    for (final task in researches) {
      await completeSingle(
        task,
        'complete_arge_research',
        params: {'p_research_id': task.id},
      );
    }

    final constructions = tasks
        .where((task) => task.kind == 'building_construction')
        .toList(growable: false);
    for (final task in constructions) {
      await completeSingle(
        task,
        'complete_building_construction',
        params: {
          'p_player_id': user.id,
          'p_construction_id': task.id,
        },
      );
    }

    final boosts = tasks
        .where((task) => task.kind == 'building_boost')
        .toList(growable: false);
    for (final task in boosts) {
      await completeSingle(
        task,
        'finish_building_boost',
        params: {
          'p_player_id': user.id,
          'p_boost_id': task.id,
        },
      );
    }

    final upgrades = tasks
        .where((task) => task.kind == 'building_upgrade')
        .toList(growable: false);
    if (upgrades.isNotEmpty) {
      try {
        final result = await _callAndSync(
          'complete_due_player_building_upgrades',
          params: {
            'p_player_id': user.id,
            'p_limit': 100,
          },
        );
        if (result['success'] != true) {
          failed.addAll(upgrades.map((task) => task.key));
          debugPrint(
            '[TimedTaskRuntime] upgrade batch returned unsuccessful: '
            '${result['message'] ?? result}',
          );
        }
      } catch (e, st) {
        failed.addAll(upgrades.map((task) => task.key));
        debugPrint('[TimedTaskRuntime] upgrade batch failed: $e\n$st');
      }
    }

    final tenderDeliveries = tasks
        .where((task) => task.kind == 'tender_delivery')
        .toList(growable: false);
    if (tenderDeliveries.isNotEmpty) {
      try {
        final result = await _callAndSync(
          'process_tender_deliveries',
          params: {'p_player_id': user.id},
        );
        if (result['success'] != true) {
          failed.addAll(tenderDeliveries.map((task) => task.key));
          debugPrint(
            '[TimedTaskRuntime] tender delivery batch returned unsuccessful: '
            '${result['message'] ?? result}',
          );
        }
      } catch (e, st) {
        failed.addAll(tenderDeliveries.map((task) => task.key));
        debugPrint('[TimedTaskRuntime] tender delivery batch failed: $e\n$st');
      }
    }

    return TimedTaskCompletionResult(failedTaskKeys: failed);
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
