import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/features/home/data/home_dashboard_provider.dart';
import 'package:hard_kapitalizm/features/notification/models/player_notification_dashboard_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PlayerNotificationDashboardNotifier
    extends AsyncNotifier<PlayerNotificationDashboardModel> {
  @override
  Future<PlayerNotificationDashboardModel> build() async {
    final supabase = Supabase.instance.client;
    try {
      final response = await supabase.rpc(
        'get_player_notifications',
        params: {'p_limit': 30},
      );
      return PlayerNotificationDashboardModel.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
    } catch (_) {
      return const PlayerNotificationDashboardModel(
        success: false,
        notifications: [],
        unreadCount: 0,
        activeWarningCount: 0,
      );
    }
  }

  void patchMarkRead(String notificationId) {
    final current = state.value;
    if (current == null) return;

    bool wasUnread = false;
    final updatedNotifications = current.notifications.map((item) {
      if (item.id == notificationId) {
        if (item.isUnread) wasUnread = true;
        return item.copyWith(status: 'read');
      }
      return item;
    }).toList();

    final newUnreadCount = wasUnread
        ? (current.unreadCount - 1).clamp(0, 999999)
        : current.unreadCount;

    state = AsyncData(
      current.copyWith(
        notifications: updatedNotifications,
        unreadCount: newUnreadCount,
      ),
    );
  }

  void patchMarkAllRead() {
    final current = state.value;
    if (current == null) return;

    final updatedNotifications = current.notifications.map((item) {
      if (item.isUnread) {
        return item.copyWith(status: 'read');
      }
      return item;
    }).toList();

    state = AsyncData(
      current.copyWith(
        notifications: updatedNotifications,
        unreadCount: 0,
      ),
    );
  }

  Future<void> refresh() async {
    try {
      final fresh = await build();
      state = AsyncData(fresh);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final playerNotificationDashboardProvider = AsyncNotifierProvider<
    PlayerNotificationDashboardNotifier, PlayerNotificationDashboardModel>(
  PlayerNotificationDashboardNotifier.new,
);

class NotificationActionNotifier {
  final Ref _ref;
  NotificationActionNotifier(this._ref);

  Future<Map<String, dynamic>> refreshAttention() async {
    final supabase = Supabase.instance.client;
    try {
      final response =
          await supabase.rpc('refresh_player_attention_notifications');
      await _ref.read(playerNotificationDashboardProvider.notifier).refresh();
      _ref.invalidate(homeDashboardProvider);
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> markRead(String notificationId) async {
    final supabase = Supabase.instance.client;
    try {
      final response = await supabase.rpc(
        'mark_notification_read',
        params: {'p_notification_id': notificationId},
      );
      _ref
          .read(playerNotificationDashboardProvider.notifier)
          .patchMarkRead(notificationId);
      _ref.invalidate(homeDashboardProvider);
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> markAllRead() async {
    final supabase = Supabase.instance.client;
    try {
      final response = await supabase.rpc('mark_all_notifications_read');
      _ref
          .read(playerNotificationDashboardProvider.notifier)
          .patchMarkAllRead();
      _ref.invalidate(homeDashboardProvider);
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}

final notificationActionProvider = Provider<NotificationActionNotifier>((ref) {
  return NotificationActionNotifier(ref);
});
