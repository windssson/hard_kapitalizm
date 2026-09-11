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

  Map<String, dynamic> toCompletionJson() {
    return {'id': id, 'kind': kind};
  }

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

class TimedTaskRuntimeEvent {
  const TimedTaskRuntimeEvent({
    required this.eventId,
    required this.taskKind,
    required this.taskId,
    required this.terminalStatus,
    required this.payload,
    required this.occurredAt,
    this.originToken,
  });

  final int eventId;
  final String taskKind;
  final String taskId;
  final String terminalStatus;
  final String? originToken;
  final Map<String, dynamic> payload;
  final DateTime occurredAt;

  String get taskKey => '$taskKind:$taskId';

  factory TimedTaskRuntimeEvent.fromJson(Map<String, dynamic> json) {
    final eventId = (json['event_id'] as num?)?.toInt();
    final taskKind = json['task_kind']?.toString().trim() ?? '';
    final taskId = json['task_id']?.toString().trim() ?? '';
    final occurredAt =
        DateTime.tryParse(json['occurred_at']?.toString() ?? '')?.toUtc();

    if (eventId == null ||
        eventId <= 0 ||
        taskKind.isEmpty ||
        taskId.isEmpty ||
        occurredAt == null) {
      throw FormatException('Invalid timed task event payload: $json');
    }

    final rawPayload = json['payload'];
    final originToken = json['origin_token']?.toString().trim();

    return TimedTaskRuntimeEvent(
      eventId: eventId,
      taskKind: taskKind,
      taskId: taskId,
      terminalStatus: json['terminal_status']?.toString().trim() ?? '',
      originToken:
          originToken == null || originToken.isEmpty ? null : originToken,
      payload: rawPayload is Map
          ? Map<String, dynamic>.from(rawPayload)
          : const <String, dynamic>{},
      occurredAt: occurredAt,
    );
  }
}

class TimedTaskRuntimeSnapshot {
  const TimedTaskRuntimeSnapshot({
    required this.serverTime,
    required this.eventRevision,
    required this.events,
    required this.eventsHasMore,
    required this.tasks,
  });

  final DateTime serverTime;
  final int eventRevision;
  final List<TimedTaskRuntimeEvent> events;
  final bool eventsHasMore;
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

    final rawEvents = json['events'] as List<dynamic>? ?? const [];
    final events = <TimedTaskRuntimeEvent>[];
    for (final raw in rawEvents) {
      if (raw is! Map) continue;
      try {
        events.add(
          TimedTaskRuntimeEvent.fromJson(Map<String, dynamic>.from(raw)),
        );
      } catch (_) {
        // As with tasks, one malformed event must not block the runtime.
      }
    }
    events.sort((a, b) => a.eventId.compareTo(b.eventId));

    return TimedTaskRuntimeSnapshot(
      serverTime: serverTime,
      eventRevision: (json['event_revision'] as num?)?.toInt() ?? 0,
      events: List.unmodifiable(events),
      eventsHasMore: json['events_has_more'] as bool? ?? false,
      tasks: List.unmodifiable(tasks),
    );
  }
}
