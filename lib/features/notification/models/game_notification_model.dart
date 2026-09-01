import 'package:flutter/material.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';

class GameNotification {
  final String id;
  final String playerId;
  final String title;
  final String message;
  final String category;
  final String? entityType;
  final String? entityId;
  final bool isRead;
  final DateTime createdAt;

  const GameNotification({
    required this.id,
    required this.playerId,
    required this.title,
    required this.message,
    required this.category,
    this.entityType,
    this.entityId,
    required this.isRead,
    required this.createdAt,
  });

  factory GameNotification.fromJson(Map<String, dynamic> json) {
    return GameNotification(
      id: (json['id'] ?? '').toString(),
      playerId: (json['player_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      category: (json['category'] ?? 'system').toString(),
      entityType: json['entity_type']?.toString(),
      entityId: json['entity_id']?.toString(),
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  GameNotification copyWith({
    String? id,
    String? playerId,
    String? title,
    String? message,
    String? category,
    String? entityType,
    String? entityId,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return GameNotification(
      id: id ?? this.id,
      playerId: playerId ?? this.playerId,
      title: title ?? this.title,
      message: message ?? this.message,
      category: category ?? this.category,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Color get categoryColor {
    switch (category.toLowerCase()) {
      case 'trade':
      case 'market':
        return AppColors.gold;
      case 'production':
        return AppColors.green;
      case 'logistics':
      case 'transfer':
        return AppColors.teal;
      case 'building':
      case 'upgrade':
        return AppColors.orange;
      case 'research':
        return AppColors.purple;
      case 'system':
      default:
        return AppColors.blue;
    }
  }

  IconData get categoryIcon {
    switch (category.toLowerCase()) {
      case 'trade':
      case 'market':
        return Icons.store_rounded;
      case 'production':
        return Icons.factory_rounded;
      case 'logistics':
      case 'transfer':
        return Icons.local_shipping_rounded;
      case 'building':
      case 'upgrade':
        return Icons.domain_rounded;
      case 'research':
        return Icons.science_rounded;
      case 'system':
      default:
        return Icons.notifications_active_rounded;
    }
  }

  String get categoryLabel {
    switch (category.toLowerCase()) {
      case 'trade':
      case 'market':
        return 'Ticaret';
      case 'production':
        return 'Üretim';
      case 'logistics':
      case 'transfer':
        return 'Lojistik';
      case 'building':
      case 'upgrade':
        return 'İnşaat';
      case 'research':
        return 'Ar-Ge';
      case 'system':
      default:
        return 'Sistem';
    }
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inSeconds < 60) {
      return 'Az önce';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} dk önce';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} sa önce';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} gün önce';
    } else {
      return '${createdAt.day}.${createdAt.month}.${createdAt.year}';
    }
  }
}
