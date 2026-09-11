class TimedTaskRuntimeTask {
  const TimedTaskRuntimeTask({
    required this.id,
    required this.kind,
    required this.finishAt,
    required this.subtype,
    this.entityId,
  });

  final String id;
  final String kind;
  final DateTime finishAt;
  final String subtype;
  final String? entityId;

  String get key => '$kind:$id';

  factory TimedTaskRuntimeTask.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString().trim() ?? '';
    final kind = json['kind']?.toString().trim() ?? '';
    final finishAtRaw = json['finish_at']?.toString().trim() ?? '';
    final finishAt = DateTime.tryParse(finishAtRaw)?.toUtc();

    if (id.isEmpty || kind.isEmpty || finishAt == null) {
      throw FormatException('Invalid timed task payload: $json');
    }

    final entityId = json['entity_id']?.toString().trim();

    return TimedTaskRuntimeTask(
      id: id,
      kind: kind,
      finishAt: finishAt,
      subtype: json['subtype']?.toString().trim() ?? '',
      entityId: entityId == null || entityId.isEmpty ? null : entityId,
    );
  }
}

class TimedTaskRuntimeSnapshot {
  const TimedTaskRuntimeSnapshot({
    required this.serverTime,
    required this.tasks,
  });

  final DateTime serverTime;
  final List<TimedTaskRuntimeTask> tasks;

  Set<String> get taskKeys => tasks.map((task) => task.key).toSet();

  List<TimedTaskRuntimeTask> dueAt(DateTime serverNow) {
    return tasks
        .where((task) => !task.finishAt.isAfter(serverNow))
        .toList(growable: false);
  }

  DateTime? nextDueAfter(DateTime serverNow) {
    DateTime? next;
    for (final task in tasks) {
      if (!task.finishAt.isAfter(serverNow)) continue;
      if (next == null || task.finishAt.isBefore(next)) {
        next = task.finishAt;
      }
    }
    return next;
  }

  factory TimedTaskRuntimeSnapshot.fromJson(Map<String, dynamic> json) {
    final serverTimeRaw = json['server_time']?.toString().trim() ?? '';
    final serverTime = DateTime.tryParse(serverTimeRaw)?.toUtc();
    if (serverTime == null) {
      throw FormatException('Timed runtime response has no valid server_time.');
    }

    final rawTasks = json['tasks'] as List<dynamic>? ?? const [];
    final tasks = <TimedTaskRuntimeTask>[];
    for (final raw in rawTasks) {
      if (raw is! Map) continue;
      try {
        tasks.add(
          TimedTaskRuntimeTask.fromJson(Map<String, dynamic>.from(raw)),
        );
      } catch (_) {
        // One malformed task must not disable scheduling for all valid tasks.
      }
    }

    tasks.sort((a, b) {
      final byTime = a.finishAt.compareTo(b.finishAt);
      if (byTime != 0) return byTime;
      final byKind = a.kind.compareTo(b.kind);
      if (byKind != 0) return byKind;
      return a.id.compareTo(b.id);
    });

    return TimedTaskRuntimeSnapshot(
      serverTime: serverTime,
      tasks: List.unmodifiable(tasks),
    );
  }
}
