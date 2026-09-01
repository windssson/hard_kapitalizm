import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hard_kapitalizm/features/notification/data/notification_repository.dart';
import 'package:hard_kapitalizm/features/notification/models/game_notification_model.dart';

// Stream controller for live in-game toast alerts
final inGameNotificationStreamController =
    StreamController<GameNotification>.broadcast();

final inGameNotificationStreamProvider =
    StreamProvider<GameNotification>((ref) {
  return inGameNotificationStreamController.stream;
});

// 1. Unread count notifier & provider
class UnreadCountNotifier extends Notifier<int> {
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

      state = state.copyWith(
        items: [...state.items, ...moreItems],
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

  void insertLiveNotification(GameNotification notification) {
    if (_category != 'all' && notification.category != _category) return;
    state = state.copyWith(items: [notification, ...state.items]);
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
                
                // 1. Canlı listeye ve rozete yansıt
                _ref.read(unreadNotificationCountProvider.notifier).increment();
                _ref.read(notificationsProvider.notifier).insertLiveNotification(notification);

                // 2. Oyun içi kayan toast bildirimini tetikle
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
