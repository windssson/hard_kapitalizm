class PlayerNotificationModel {
  final String id;
  final String kind;
  final String category;
  final String title;
  final String message;
  final String? entityKind;
  final String? entityId;
  final String severity;
  final String status;
  final Map<String, dynamic> meta;
  final DateTime createdAt;

  const PlayerNotificationModel({
    required this.id,
    required this.kind,
    required this.category,
    required this.title,
    required this.message,
    required this.entityKind,
    required this.entityId,
    required this.severity,
    required this.status,
    required this.meta,
    required this.createdAt,
  });

  bool get isUnread => status == 'unread';
  bool get isWarning => kind == 'warning';
  bool get isEvent => kind == 'event';
  bool get isResolved => status == 'resolved';
  bool get isActiveWarning => isWarning && status != 'resolved';
  bool get isActiveReminder =>
      category == 'inactive_reminder' && status != 'resolved';
  bool get needsAttention => isActiveWarning || isActiveReminder;

  factory PlayerNotificationModel.fromJson(Map<String, dynamic> json) {
    return PlayerNotificationModel(
      id: (json['id'] ?? '').toString(),
      kind: (json['kind'] ?? 'event').toString(),
      category: (json['category'] ?? '').toString(),
      title: (json['title'] ?? 'Bildirim').toString(),
      message: (json['message'] ?? '').toString(),
      entityKind: json['entity_kind']?.toString(),
      entityId: json['entity_id']?.toString(),
      severity: (json['severity'] ?? 'info').toString(),
      status: (json['status'] ?? 'read').toString(),
      meta: json['meta'] is Map<String, dynamic>
          ? json['meta'] as Map<String, dynamic>
          : json['meta'] is Map
              ? Map<String, dynamic>.from(json['meta'] as Map)
              : const <String, dynamic>{},
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  PlayerNotificationModel copyWith({
    String? id,
    String? kind,
    String? category,
    String? title,
    String? message,
    String? entityKind,
    String? entityId,
    String? severity,
    String? status,
    Map<String, dynamic>? meta,
    DateTime? createdAt,
  }) {
    return PlayerNotificationModel(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      category: category ?? this.category,
      title: title ?? this.title,
      message: message ?? this.message,
      entityKind: entityKind ?? this.entityKind,
      entityId: entityId ?? this.entityId,
      severity: severity ?? this.severity,
      status: status ?? this.status,
      meta: meta ?? this.meta,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
