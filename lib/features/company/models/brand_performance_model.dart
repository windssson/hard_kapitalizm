class TopBrandedProductModel {
  final String productId;
  final String productName;
  final int soldQuantity;
  final double revenue;
  final double profit;

  const TopBrandedProductModel({
    required this.productId,
    required this.productName,
    required this.soldQuantity,
    required this.revenue,
    required this.profit,
  });

  factory TopBrandedProductModel.fromJson(Map<String, dynamic> json) {
    return TopBrandedProductModel(
      productId: (json['product_id'] ?? '').toString(),
      productName: (json['product_name'] ?? '').toString(),
      soldQuantity: (json['sold_quantity'] as num?)?.toInt() ?? 0,
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0.0,
      profit: (json['profit'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class BrandPerformanceModel {
  final int totalSold;
  final double totalRevenue;
  final double totalProfit;
  final List<TopBrandedProductModel> topProducts;

  const BrandPerformanceModel({
    required this.totalSold,
    required this.totalRevenue,
    required this.totalProfit,
    required this.topProducts,
  });

  factory BrandPerformanceModel.fromJson(Map<String, dynamic> json) {
    final rawTop = json['top_products'] as List<dynamic>? ?? const [];
    return BrandPerformanceModel(
      totalSold: (json['total_sold'] as num?)?.toInt() ?? 0,
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0.0,
      totalProfit: (json['total_profit'] as num?)?.toDouble() ?? 0.0,
      topProducts: rawTop
          .map((item) => TopBrandedProductModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
    );
  }

  factory BrandPerformanceModel.empty() {
    return const BrandPerformanceModel(
      totalSold: 0,
      totalRevenue: 0.0,
      totalProfit: 0.0,
      topProducts: [],
    );
  }
}
