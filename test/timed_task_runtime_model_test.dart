import 'package:flutter_test/flutter_test.dart';
import 'package:hard_kapitalizm/core/models/timed_task_runtime_model.dart';

void main() {
  group('TimedTaskRuntimeSnapshot', () {
    test('sorts tasks and resolves due/next using server time', () {
      final snapshot = TimedTaskRuntimeSnapshot.fromJson({
        'server_time': '2026-09-11T12:00:00+00:00',
        'tasks': [
          {
            'id': 'future-2',
            'kind': 'building_boost',
            'finish_at': '2026-09-11T12:20:00+00:00',
            'subtype': 'factory',
          },
          {
            'id': 'due-1',
            'kind': 'arge_research',
            'finish_at': '2026-09-11T11:59:00+00:00',
            'subtype': 'DOMATES',
          },
          {
            'id': 'future-1',
            'kind': 'tender_delivery',
            'finish_at': '2026-09-11T12:05:00+00:00',
            'subtype': 'tender-1',
          },
        ],
      });

      final now = DateTime.parse('2026-09-11T12:00:00+00:00').toUtc();

      expect(snapshot.serverTime, now);
      expect(snapshot.tasks.map((task) => task.id), [
        'due-1',
        'future-1',
        'future-2',
      ]);
      expect(snapshot.dueAt(now).map((task) => task.id), ['due-1']);
      expect(
        snapshot.nextDueAfter(now),
        DateTime.parse('2026-09-11T12:05:00+00:00').toUtc(),
      );
    });

    test('skips one malformed task without dropping valid tasks', () {
      final snapshot = TimedTaskRuntimeSnapshot.fromJson({
        'server_time': '2026-09-11T12:00:00+00:00',
        'tasks': [
          {
            'id': '',
            'kind': 'building_upgrade',
            'finish_at': 'bad-date',
          },
          {
            'id': 'valid',
            'kind': 'building_construction',
            'finish_at': '2026-09-11T13:00:00+00:00',
            'subtype': 'factory',
            'entity_id': 'entity-1',
          },
        ],
      });

      expect(snapshot.tasks, hasLength(1));
      expect(snapshot.tasks.single.id, 'valid');
      expect(snapshot.tasks.single.entityId, 'entity-1');
    });

    test('task key includes kind to avoid cross-domain id collisions', () {
      final task = TimedTaskRuntimeTask.fromJson({
        'id': 'same-id',
        'kind': 'logistics_transfer',
        'finish_at': '2026-09-11T13:00:00+00:00',
      });

      expect(task.key, 'logistics_transfer:same-id');
    });
  });
}
