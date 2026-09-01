import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hard_kapitalizm/features/notification/models/game_notification_model.dart';
import 'package:hard_kapitalizm/features/notification/models/operational_alert_model.dart';

class NotificationRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<OperationalAlertModel>> fetchOperationalAlerts() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      final response = await _supabase.rpc('get_player_operational_alerts');
      List rawList = [];
      if (response is List) {
        rawList = response;
      } else if (response is Map && response['alerts'] is List) {
        rawList = response['alerts'] as List;
      }
      return rawList
          .whereType<Map>()
          .map((item) => OperationalAlertModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint('Operasyonel uyarılar alınırken hata: $e');
      return [];
    }
  }

  Future<List<GameNotification>> fetchNotifications({
    int limit = 30,
    int offset = 0,
    String? category,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      final response = await _supabase.rpc(
        'get_player_notifications',
        params: {
          'p_limit': limit,
          'p_offset': offset,
          'p_category': (category == null || category == 'all') ? null : category,
        },
      );

      if (response is List) {
        return response
            .map((item) => GameNotification.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Bildirimler yüklenirken hata: $e');
      return [];
    }
  }

  Future<int> fetchUnreadCount() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return 0;

      final response = await _supabase.rpc('get_unread_notification_count');
      return (response as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint('Okunmamış bildirim sayısı alınırken hata: $e');
      return 0;
    }
  }

  Future<bool> markAsRead(String notificationId) async {
    try {
      final response = await _supabase.rpc(
        'mark_notification_read',
        params: {'p_notification_id': notificationId},
      );
      return response == true;
    } catch (e) {
      debugPrint('Bildirim okundu işaretlenirken hata: $e');
      return false;
    }
  }

  Future<bool> markAllAsRead() async {
    try {
      final response = await _supabase.rpc('mark_all_notifications_read');
      return response == true;
    } catch (e) {
      debugPrint('Tüm bildirimler okundu işaretlenirken hata: $e');
      return false;
    }
  }

  Future<bool> clearNotifications({bool onlyRead = false}) async {
    try {
      final response = await _supabase.rpc(
        'clear_player_notifications',
        params: {'p_only_read': onlyRead},
      );
      return response == true;
    } catch (e) {
      debugPrint('Bildirimler silinirken hata: $e');
      return false;
    }
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});
