import 'package:hard_kapitalizm/features/notification/models/player_notification_model.dart';

class PlayerNotificationDashboardModel {
  final bool success;
  final List<PlayerNotificationModel> notifications;
  final int unreadCount;
  final int activeWarningCount;

  const PlayerNotificationDashboardModel({
    required this.success,
    required this.notifications,
    required this.unreadCount,
    required this.activeWarningCount,
  });

  bool get hasAnyNotification => notifications.isNotEmpty;

  factory PlayerNotificationDashboardModel.fromJson(Map<String, dynamic> json) {
    final rawNotifications = (json['notifications'] as List?) ?? const [];
    final rawSummary = json['summary'];
    final summaryMap = rawSummary is Map<String, dynamic>
        ? rawSummary
        : rawSummary is Map
            ? Map<String, dynamic>.from(rawSummary)
            : const <String, dynamic>{};

    return PlayerNotificationDashboardModel(
      success: json['success'] as bool? ?? false,
      notifications: rawNotifications
          .whereType<Map>()
          .map(
            (item) => PlayerNotificationModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
      unreadCount: (summaryMap['unread_count'] as num?)?.toInt() ?? 0,
      activeWarningCount:
          (summaryMap['active_warning_count'] as num?)?.toInt() ?? 0,
    );
  }

  PlayerNotificationDashboardModel copyWith({
    bool? success,
    List<PlayerNotificationModel>? notifications,
    int? unreadCount,
    int? activeWarningCount,
  }) {
    return PlayerNotificationDashboardModel(
      success: success ?? this.success,
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      activeWarningCount: activeWarningCount ?? this.activeWarningCount,
    );
  }
}
