import 'package:flutter/material.dart';

enum AlertSeverity { critical, warning, info }

class OperationalAlertModel {
  final String id;
  final AlertSeverity severity;
  final String category;
  final String title;
  final String description;
  final String route;
  final int count;

  const OperationalAlertModel({
    required this.id,
    required this.severity,
    required this.category,
    required this.title,
    required this.description,
    required this.route,
    this.count = 1,
  });

  factory OperationalAlertModel.fromJson(Map<String, dynamic> json) {
    final sevStr = json['severity']?.toString().toLowerCase() ?? 'warning';
    final severity = sevStr == 'critical'
        ? AlertSeverity.critical
        : AlertSeverity.warning;

    return OperationalAlertModel(
      id: json['id']?.toString() ?? '',
      severity: severity,
      category: json['category']?.toString() ?? 'system',
      title: json['title']?.toString() ?? 'Uyarı',
      description: json['description']?.toString() ?? '',
      route: json['route']?.toString() ?? '/home',
      count: (json['count'] as num?)?.toInt() ?? 1,
    );
  }

  Color get color {
    switch (severity) {
      case AlertSeverity.critical:
        return const Color(0xFFFF4D4D);
      case AlertSeverity.warning:
        return const Color(0xFFFFB800);
      case AlertSeverity.info:
        return const Color(0xFF00E5FF);
    }
  }

  IconData get icon {
    switch (category) {
      case 'tax':
        return Icons.receipt_long_rounded;
      case 'bank':
        return Icons.account_balance_rounded;
      case 'factory':
        return Icons.precision_manufacturing_rounded;
      case 'mine':
        return Icons.terrain_rounded;
      case 'field':
        return Icons.grass_rounded;
      case 'farm':
        return Icons.pets_rounded;
      case 'store':
        return Icons.storefront_rounded;
      case 'logistics':
        return Icons.local_shipping_rounded;
      case 'tender':
        return Icons.gavel_rounded;
      default:
        return Icons.warning_amber_rounded;
    }
  }
}
