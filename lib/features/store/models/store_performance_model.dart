class StorePerformanceRowModel {
  final DateTime performanceDate;
  final String storeSlotId;
  final int slotIndex;
  final String productId;
  final String productName;
  final int qualityLevel;
  final int soldQuantity;
  final double revenue;
  final double profit;
  final int saleEventCount;
  final DateTime? lastSaleAt;

  const StorePerformanceRowModel({
    required this.performanceDate,
    required this.storeSlotId,
    required this.slotIndex,
    required this.productId,
    required this.productName,
    required this.qualityLevel,
    required this.soldQuantity,
    required this.revenue,
    required this.profit,
    required this.saleEventCount,
    required this.lastSaleAt,
  });

  factory StorePerformanceRowModel.fromJson(Map<String, dynamic> json) {
    return StorePerformanceRowModel(
      performanceDate:
          DateTime.tryParse((json['performance_date'] ?? '').toString()) ??
          DateTime.now(),
      storeSlotId: (json['store_slot_id'] ?? '').toString(),
      slotIndex: (json['slot_index'] as num?)?.toInt() ?? 0,
      productId: (json['product_id'] ?? '').toString(),
      productName: (json['product_name'] ?? 'Urun').toString(),
      qualityLevel: (json['quality_level'] as num?)?.toInt() ?? 0,
      soldQuantity: (json['sold_quantity'] as num?)?.toInt() ?? 0,
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
      profit: (json['profit'] as num?)?.toDouble() ?? 0,
      saleEventCount: (json['sale_event_count'] as num?)?.toInt() ?? 0,
      lastSaleAt: json['last_sale_at'] != null
          ? DateTime.tryParse(json['last_sale_at'].toString())
          : null,
    );
  }
}

class StorePerformanceSummaryModel {
  final double totalRevenue;
  final double totalProfit;
  final int totalSoldQuantity;
  final int totalSaleEvents;

  const StorePerformanceSummaryModel({
    required this.totalRevenue,
    required this.totalProfit,
    required this.totalSoldQuantity,
    required this.totalSaleEvents,
  });

  factory StorePerformanceSummaryModel.fromJson(Map<String, dynamic> json) {
    return StorePerformanceSummaryModel(
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0,
      totalProfit: (json['total_profit'] as num?)?.toDouble() ?? 0,
      totalSoldQuantity: (json['total_sold_quantity'] as num?)?.toInt() ?? 0,
      totalSaleEvents: (json['total_sale_events'] as num?)?.toInt() ?? 0,
    );
  }
}

class StorePerformanceResponseModel {
  final bool success;
  final String? message;
  final StorePerformanceSummaryModel summary;
  final List<StorePerformanceRowModel> rows;

  const StorePerformanceResponseModel({
    required this.success,
    required this.message,
    required this.summary,
    required this.rows,
  });

  factory StorePerformanceResponseModel.fromJson(Map<String, dynamic> json) {
    final rawRows = (json['rows'] as List?) ?? const [];
    return StorePerformanceResponseModel(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String?,
      summary: StorePerformanceSummaryModel.fromJson(
        Map<String, dynamic>.from(
          (json['summary'] as Map?) ?? const <String, dynamic>{},
        ),
      ),
      rows: rawRows
          .whereType<Map>()
          .map(
            (row) => StorePerformanceRowModel.fromJson(
              Map<String, dynamic>.from(row),
            ),
          )
          .toList(),
    );
  }
}
