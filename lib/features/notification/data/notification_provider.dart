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

  Future<bool> refresh() async {
    final repo = ref.read(notificationRepositoryProvider);
    try {
      final count = await repo.fetchUnreadCount();
      state = count;
      return true;
    } catch (e) {
      // Keep the last known count. A transient RPC/network failure must not be
      // interpreted as "zero unread notifications".
      debugPrint('Okunmamis bildirim sayisi korunuyor: $e');
      return false;
    }
  }

  void increment() {
    state = state + 1;
  }

  /// Restores a count that was optimistically cleared while preserving unread
  /// notifications that arrived through Realtime during the RPC round-trip.
  void restoreClearedCount(int previousCount) {
    state = previousCount + state;
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
        final unreadNotifier =
            ref.read(unreadNotificationCountProvider.notifier);
        unreadNotifier.registerKnownNotifications(items);
        _didReconcileUnreadOnInitialLoad = await unreadNotifier.refresh();
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

    final unreadNotifier = ref.read(unreadNotificationCountProvider.notifier);
    unreadNotifier.decrement();

    final success = await _repo.markAsRead(id);
    if (success) return;

    // Roll back only the target row. Other realtime/list changes that happened
    // while the RPC was in flight must be preserved.
    final rollbackIndex = state.items.indexWhere((item) => item.id == id);
    if (rollbackIndex == -1 || !state.items[rollbackIndex].isRead) return;
    final rolledBack = List<GameNotification>.from(state.items);
    rolledBack[rollbackIndex] = state.items[rollbackIndex].copyWith(isRead: false);
    state = state.copyWith(items: rolledBack);
    unreadNotifier.increment();
  }

  Future<void> markAllAsRead() async {
    final previousItems = List<GameNotification>.from(state.items);
    final previousUnreadCount = ref.read(unreadNotificationCountProvider);

    final updatedList = state.items.map((e) => e.copyWith(isRead: true)).toList();
    state = state.copyWith(items: updatedList);

    final unreadNotifier = ref.read(unreadNotificationCountProvider.notifier);
    unreadNotifier.clear();

    final success = await _repo.markAllAsRead();
    if (success) return;

    // Restore only rows that existed before the optimistic mutation. New live
    // notifications remain untouched and their unread increments are retained.
    final previousById = {for (final item in previousItems) item.id: item};
    final restoredItems = state.items
        .map((item) => previousById[item.id] ?? item)
        .toList();
    state = state.copyWith(items: restoredItems);
    unreadNotifier.restoreClearedCount(previousUnreadCount);
  }

  Future<void> clearAll({bool onlyRead = false}) async {
    final previousItems = List<GameNotification>.from(state.items);
    final previousUnreadCount = ref.read(unreadNotificationCountProvider);

    if (onlyRead) {
      final remaining = state.items.where((e) => !e.isRead).toList();
      state = state.copyWith(items: remaining);
    } else {
      state = state.copyWith(items: const []);
      ref.read(unreadNotificationCountProvider.notifier).clear();
    }

    final success = await _repo.clearNotifications(onlyRead: onlyRead);
    if (success) return;

    // Keep any notifications delivered while the RPC was in flight, then
    // restore rows removed by the failed optimistic mutation without duplicates.
    final currentItems = List<GameNotification>.from(state.items);
    final currentIds = currentItems.map((item) => item.id).toSet();
    final restoredItems = [
      ...currentItems,
      ...previousItems.where((item) => !currentIds.contains(item.id)),
    ];
    state = state.copyWith(items: restoredItems);

    if (!onlyRead) {
      ref
          .read(unreadNotificationCountProvider.notifier)
          .restoreClearedCount(previousUnreadCount);
    }
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
