import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/features/notification/models/player_notification_dashboard_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final playerNotificationDashboardProvider =
    FutureProvider<PlayerNotificationDashboardModel>((ref) async {
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
    });

class NotificationActionNotifier {
  final Ref _ref;
  NotificationActionNotifier(this._ref);

  Future<Map<String, dynamic>> refreshAttention() async {
    final supabase = Supabase.instance.client;
    try {
      final response = await supabase.rpc('refresh_player_attention_notifications');
      _ref.invalidate(playerNotificationDashboardProvider);
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
      _ref.invalidate(playerNotificationDashboardProvider);
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> markAllRead() async {
    final supabase = Supabase.instance.client;
    try {
      final response = await supabase.rpc('mark_all_notifications_read');
      _ref.invalidate(playerNotificationDashboardProvider);
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}

final notificationActionProvider = Provider<NotificationActionNotifier>((ref) {
  return NotificationActionNotifier(ref);
});
