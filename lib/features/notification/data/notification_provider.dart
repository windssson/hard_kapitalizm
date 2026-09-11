import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hard_kapitalizm/features/notification/data/notification_repository.dart';
import 'package:hard_kapitalizm/features/notification/models/game_notification_model.dart';
import 'package:hard_kapitalizm/features/notification/models/operational_alert_model.dart';

bool registerLiveNotificationId(Set<String> seenIds, String notificationId) {
  if (notificationId.isEmpty) return true;
  return seenIds.add(notificationId);
}

// Stream controller for live in-game toast alerts
final inGameNotificationStreamController =
    StreamController<GameNotification>.broadcast();

final inGameNotificationStreamProvider =
    StreamProvider<GameNotification>((ref) {
  return inGameNotificationStreamController.stream;
});

// 1. Unread count notifier & provider
class UnreadCountNotifier extends Notifier<int> {
  final Set<String> _countedLiveNotificationIds = <String>{};

  @override
  int build() {
    refresh();
    return 0;
  }

  Future<void> refresh() async {
    final repo = ref.read(notificationRepositoryProvider);
    final count = await repo.fetchUnreadCount();
    state = count;
  }

  void increment() {
    state = state + 1;
  }

  /// Marks already-fetched rows as known to the realtime de-duplication guard.
  /// This closes the startup race where the initial REST page and a Realtime
  /// INSERT can contain the same persisted notification row.
  void registerKnownNotifications(Iterable<GameNotification> notifications) {
    for (final notification in notifications) {
      if (notification.id.isNotEmpty) {
        _countedLiveNotificationIds.add(notification.id);
      }
    }
  }

  /// Returns false when the same realtime INSERT was already processed in this
  /// provider lifetime. Postgres Realtime reconnects/retries must not inflate
  /// the unread badge or replay the same in-game toast twice.
  bool registerLiveNotification(GameNotification notification) {
    if (!registerLiveNotificationId(
      _countedLiveNotificationIds,
      notification.id,
    )) {
      return false;
    }

    if (!notification.isRead) {
      state = state + 1;
    }
    return true;
  }

  void decrement() {
    if (state > 0) state = state - 1;
  }

  void clear() {
    state = 0;
  }
}

final unreadNotificationCountProvider =
    NotifierProvider<UnreadCountNotifier, int>(UnreadCountNotifier.new);

// 2. Category filter notifier & provider
class NotificationCategoryNotifier extends Notifier<String> {
  @override
  String build() => 'all';

  void setCategory(String category) {
    state = category;
  }
}

final notificationCategoryFilterProvider =
    NotifierProvider<NotificationCategoryNotifier, String>(
        NotificationCategoryNotifier.new);

// 3. Notification list state & notifier
class NotificationListState {
  final List<GameNotification> items;
  final bool isLoading;
  final bool hasMore;
  final String? error;

  const NotificationListState({
    this.items = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
  });

  NotificationListState copyWith({
    List<GameNotification>? items,
    bool? isLoading,
    bool? hasMore,
    String? error,
  }) {
    return NotificationListState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
    );
  }
}

class NotificationsNotifier extends Notifier<NotificationListState> {
  static const int _pageSize = 25;
  bool _didReconcileUnreadOnInitialLoad = false;

  @override
  NotificationListState build() {
    // Watch category filter to automatically reload on category change
    ref.watch(notificationCategoryFilterProvider);
    Future.microtask(() => loadInitial());
    return const NotificationListState(isLoading: true);
  }

  NotificationRepository get _repo => ref.read(notificationRepositoryProvider);
  String get _category => ref.read(notificationCategoryFilterProvider);

  Future<void> loadInitial() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final items = await _repo.fetchNotifications(
        limit: _pageSize,
        offset: 0,
        category: _category == 'all' ? null : _category,
      );
      state = state.copyWith(
        items: items,
        isLoading: false,
        hasMore: items.length >= _pageSize,
      );

      if (!_didReconcileUnreadOnInitialLoad) {
        _didReconcileUnreadOnInitialLoad = true;
        final unreadNotifier =
            ref.read(unreadNotificationCountProvider.notifier);
        unreadNotifier.registerKnownNotifications(items);
        try {
          // The server count is authoritative after the initial REST/realtime
          // overlap window. This removes any startup double-count drift.
          await unreadNotifier.refresh();
        } catch (e) {
          debugPrint('Okunmamis bildirim sayisi uzlastirilamadi: $e');
        }
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;

    try {
      final moreItems = await _repo.fetchNotifications(
        limit: _pageSize,
        offset: state.items.length,
        category: _category == 'all' ? null : _category,
      );

      final existingIds = state.items.map((item) => item.id).toSet();
      final uniqueMoreItems = moreItems
          .where((item) => !existingIds.contains(item.id))
          .toList();
      state = state.copyWith(
        items: [...state.items, ...uniqueMoreItems],
        hasMore: moreItems.length >= _pageSize,
      );
    } catch (e) {
      debugPrint('Daha fazla bildirim yüklenirken hata: $e');
    }
  }

  Future<void> markAsRead(String id) async {
    final index = state.items.indexWhere((item) => item.id == id);
    if (index == -1) return;

    final target = state.items[index];
    if (target.isRead) return;

    final updated = target.copyWith(isRead: true);
    final updatedList = List<GameNotification>.from(state.items);
    updatedList[index] = updated;
    state = state.copyWith(items: updatedList);

    ref.read(unreadNotificationCountProvider.notifier).decrement();
    await _repo.markAsRead(id);
  }

  Future<void> markAllAsRead() async {
    final updatedList = state.items.map((e) => e.copyWith(isRead: true)).toList();
    state = state.copyWith(items: updatedList);

    ref.read(unreadNotificationCountProvider.notifier).clear();
    await _repo.markAllAsRead();
  }

  Future<void> clearAll({bool onlyRead = false}) async {
    if (onlyRead) {
      final remaining = state.items.where((e) => !e.isRead).toList();
      state = state.copyWith(items: remaining);
    } else {
      state = state.copyWith(items: const []);
      ref.read(unreadNotificationCountProvider.notifier).clear();
    }

    await _repo.clearNotifications(onlyRead: onlyRead);
  }

  bool insertLiveNotification(GameNotification notification) {
    if (state.items.any((item) => item.id == notification.id)) return false;
    if (_category != 'all' && notification.category != _category) return false;
    state = state.copyWith(items: [notification, ...state.items]);
    return true;
  }
}

final notificationsProvider =
    NotifierProvider<NotificationsNotifier, NotificationListState>(
        NotificationsNotifier.new);

// 4. Realtime service provider to manage subscription
final notificationRealtimeServiceProvider = Provider<NotificationRealtimeService>((ref) {
  final service = NotificationRealtimeService(ref);
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

class NotificationRealtimeService {
  final Ref _ref;
  RealtimeChannel? _channel;

  NotificationRealtimeService(this._ref);

  void startListening() {
    if (_channel != null) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    _channel = Supabase.instance.client
        .channel('player_notifications_realtime_${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'player_notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'player_id',
            value: user.id,
          ),
          callback: (payload) {
            try {
              if (payload.newRecord.isNotEmpty) {
                final notification = GameNotification.fromJson(payload.newRecord);

                // Count/process each persisted notification id once. The list
                // notifier has its own id guard as a second line of defense.
                final isNewRealtimeNotification = _ref
                    .read(unreadNotificationCountProvider.notifier)
                    .registerLiveNotification(notification);
                if (!isNewRealtimeNotification) return;

                _ref
                    .read(notificationsProvider.notifier)
                    .insertLiveNotification(notification);

                // Trigger the in-game toast only once for the same persisted row.
                inGameNotificationStreamController.add(notification);
              }
            } catch (e) {
              debugPrint('Realtime bildirim işleme hatası: $e');
            }
          },
        )
        .subscribe();
  }

  void dispose() {
    _channel?.unsubscribe();
    _channel = null;
  }
}

// 5. Operational alerts notifier & provider
class OperationalAlertsNotifier extends AsyncNotifier<List<OperationalAlertModel>> {
  @override
  Future<List<OperationalAlertModel>> build() async {
    final repo = ref.read(notificationRepositoryProvider);
    return await repo.fetchOperationalAlerts();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(notificationRepositoryProvider);
      return await repo.fetchOperationalAlerts();
    });
  }
}

final operationalAlertsProvider =
    AsyncNotifierProvider<OperationalAlertsNotifier, List<OperationalAlertModel>>(
        OperationalAlertsNotifier.new);