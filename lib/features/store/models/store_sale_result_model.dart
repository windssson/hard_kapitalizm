import 'package:hard_kapitalizm/features/auth/models/experience_gain_model.dart';

class StoreSaleItemModel {
  final String slotId;
  final int slotIndex;
  final String productId;
  final String productName;
  final int qualityLevel;
  final int elapsedMinutes;
  final int soldQuantity;
  final double unitPrice;
  final double unitCost;
  final double revenue;
  final double profit;
  final int remainingQuantity;
  // Remaining fractional sale carry-over after whole-unit sales are applied.
  final double pendingSaleAfter;

  const StoreSaleItemModel({
    required this.slotId,
    required this.slotIndex,
    required this.productId,
    required this.productName,
    required this.qualityLevel,
    required this.elapsedMinutes,
    required this.soldQuantity,
    required this.unitPrice,
    required this.unitCost,
    required this.revenue,
    required this.profit,
    required this.remainingQuantity,
    required this.pendingSaleAfter,
  });

  factory StoreSaleItemModel.fromJson(Map<String, dynamic> json) {
    return StoreSaleItemModel(
      slotId: (json['slot_id'] ?? '').toString(),
      slotIndex: (json['slot_index'] as num?)?.toInt() ?? 0,
      productId: (json['product_id'] ?? '').toString(),
      productName: (json['product_name'] ?? 'Ürün').toString(),
      qualityLevel: (json['quality_level'] as num?)?.toInt() ?? 1,
      elapsedMinutes: (json['elapsed_minutes'] as num?)?.toInt() ?? 0,
      soldQuantity: (json['sold_quantity'] as num?)?.toInt() ?? 0,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
      unitCost: (json['unit_cost'] as num?)?.toDouble() ?? 0,
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
      profit: (json['profit'] as num?)?.toDouble() ?? 0,
      remainingQuantity: (json['remaining_quantity'] as num?)?.toInt() ?? 0,
      pendingSaleAfter: (json['pending_sale_after'] as num?)?.toDouble() ?? 0,
    );
  }
}

class StoreSaleResultModel {
  final bool success;
  final bool processed;
  final String? message;
  final DateTime? processedAt;
  final int elapsedMinutes;
  final double totalRevenue;
  final double totalProfit;
  final int totalSoldQuantity;
  final int completedBoostCount;
  final ExperienceGainModel? experience;
  final List<StoreSaleItemModel> items;

  const StoreSaleResultModel({
    required this.success,
    required this.processed,
    required this.message,
    required this.processedAt,
    required this.elapsedMinutes,
    required this.totalRevenue,
    required this.totalProfit,
    required this.totalSoldQuantity,
    required this.completedBoostCount,
    required this.experience,
    required this.items,
  });

  bool get hasVisibleSales => totalSoldQuantity > 0 && items.isNotEmpty;

  factory StoreSaleResultModel.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List?) ?? const [];
    return StoreSaleResultModel(
      success: json['success'] as bool? ?? false,
      processed: json['processed'] as bool? ?? false,
      message: json['message'] as String?,
      processedAt: json['processed_at'] != null
          ? DateTime.tryParse(json['processed_at'].toString())
          : null,
      elapsedMinutes: (json['elapsed_minutes'] as num?)?.toInt() ?? 0,
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0,
      totalProfit: (json['total_profit'] as num?)?.toDouble() ?? 0,
      totalSoldQuantity: (json['total_sold_quantity'] as num?)?.toInt() ?? 0,
      completedBoostCount:
          (json['completed_boost_count'] as num?)?.toInt() ?? 0,
      experience: json['experience'] is Map<String, dynamic>
          ? ExperienceGainModel.fromJson(json['experience'])
          : json['experience'] is Map
              ? ExperienceGainModel.fromJson(
                  Map<String, dynamic>.from(json['experience'] as Map),
                )
              : null,
      items: rawItems
          .whereType<Map>()
          .map(
            (item) => StoreSaleItemModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
    );
  }
}
