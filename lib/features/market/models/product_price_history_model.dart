class ProductPriceHistoryModel {
  final String productId;
  final List<double> prices; // Chronological order: [day_4, day_3, day_2, day_1, day_0]
  final DateTime updatedAt;

  ProductPriceHistoryModel({
    required this.productId,
    required this.prices,
    required this.updatedAt,
  });

  factory ProductPriceHistoryModel.fromJson(Map<String, dynamic> json) {
    return ProductPriceHistoryModel(
      productId: json['product_id'] as String,
      prices: [
        (double.tryParse(json['price_day_4']?.toString() ?? '0') ?? 0.0),
        (double.tryParse(json['price_day_3']?.toString() ?? '0') ?? 0.0),
        (double.tryParse(json['price_day_2']?.toString() ?? '0') ?? 0.0),
        (double.tryParse(json['price_day_1']?.toString() ?? '0') ?? 0.0),
        (double.tryParse(json['price_day_0']?.toString() ?? '0') ?? 0.0),
      ],
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
