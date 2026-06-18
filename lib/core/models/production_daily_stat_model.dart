class ProductionDailyStatModel {
  final DateTime productionDate;
  final String ownerKind;
  final String ownerId;
  final String productId;
  final String productName;
  final String productIcon;
  final double baseSalePrice;
  final int producedQuantity;
  final double totalCost;
  final double estimatedRevenue;
  final double estimatedProfit;

  const ProductionDailyStatModel({
    required this.productionDate,
    required this.ownerKind,
    required this.ownerId,
    required this.productId,
    required this.productName,
    required this.productIcon,
    required this.baseSalePrice,
    required this.producedQuantity,
    required this.totalCost,
    required this.estimatedRevenue,
    required this.estimatedProfit,
  });

  factory ProductionDailyStatModel.fromJson(Map<String, dynamic> json) {
    return ProductionDailyStatModel(
      productionDate:
          DateTime.tryParse(json['production_date']?.toString() ?? '') ??
          DateTime.now(),
      ownerKind: (json['owner_kind'] ?? '').toString(),
      ownerId: (json['owner_id'] ?? '').toString(),
      productId: (json['product_id'] ?? '').toString(),
      productName: (json['product_name'] ?? 'Urun').toString(),
      productIcon: (json['product_icon'] ?? '').toString(),
      baseSalePrice: (json['base_sale_price'] as num?)?.toDouble() ?? 0,
      producedQuantity: (json['produced_quantity'] as num?)?.toInt() ?? 0,
      totalCost: (json['total_cost'] as num?)?.toDouble() ?? 0,
      estimatedRevenue: (json['estimated_revenue'] as num?)?.toDouble() ?? 0,
      estimatedProfit: (json['estimated_profit'] as num?)?.toDouble() ?? 0,
    );
  }
}
