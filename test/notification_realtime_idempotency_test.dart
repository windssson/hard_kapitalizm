import 'package:flutter_test/flutter_test.dart';
import 'package:hard_kapitalizm/features/notification/data/notification_provider.dart';

void main() {
  test('live notification id is accepted only once', () {
    final seenIds = <String>{};

    expect(registerLiveNotificationId(seenIds, 'notification-1'), isTrue);
    expect(registerLiveNotificationId(seenIds, 'notification-1'), isFalse);
    expect(registerLiveNotificationId(seenIds, 'notification-2'), isTrue);
    expect(seenIds, {'notification-1', 'notification-2'});
  });

  test('id already known from initial REST page is rejected by realtime', () {
    final seenIds = <String>{'notification-rest'};

    expect(
      registerLiveNotificationId(seenIds, 'notification-rest'),
      isFalse,
    );
    expect(seenIds, {'notification-rest'});
  });

  test('empty legacy notification ids stay processable', () {
    final seenIds = <String>{};

    expect(registerLiveNotificationId(seenIds, ''), isTrue);
    expect(registerLiveNotificationId(seenIds, ''), isTrue);
    expect(seenIds, isEmpty);
  });
}