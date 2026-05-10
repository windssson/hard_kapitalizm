class MarketBuyerStoreSlotModel {
  final String storeSlotId;
  final String storeId;
  final String storeName;
  final String cityId;
  final String cityName;
  final double cityX;
  final double cityY;
  final bool isActive;
  final String? productId;
  final int qualityLevel;
  final int quantity;
  final int pendingQuantity;
  final int capacity;

  const MarketBuyerStoreSlotModel({
    required this.storeSlotId,
    required this.storeId,
    required this.storeName,
    required this.cityId,
    required this.cityName,
    required this.cityX,
    required this.cityY,
    required this.isActive,
    required this.productId,
    required this.qualityLevel,
    required this.quantity,
    required this.pendingQuantity,
    required this.capacity,
  });

  double get availableCapacity =>
      ((capacity - quantity - pendingQuantity).toDouble().clamp(
        0.0,
        capacity.toDouble(),
      ) as num)
          .toDouble();

  factory MarketBuyerStoreSlotModel.fromJson(Map<String, dynamic> json) {
    final storeJson = json['store'] as Map<String, dynamic>? ?? {};
    final cityJson = storeJson['city'] as Map<String, dynamic>? ?? {};

    double parseNum(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0;
    }

    return MarketBuyerStoreSlotModel(
      storeSlotId: (json['id'] ?? '').toString(),
      storeId: (json['store_id'] ?? storeJson['id'] ?? '').toString(),
      storeName: (storeJson['name'] ?? 'Magaza').toString(),
      cityId: (storeJson['city_id'] ?? cityJson['id'] ?? '').toString(),
      cityName: (cityJson['name'] ?? storeJson['city_name'] ?? 'Bilinmeyen')
          .toString(),
      cityX: parseNum(cityJson['map_position_x']),
      cityY: parseNum(cityJson['map_position_y']),
      isActive: storeJson['is_active'] as bool? ?? false,
      productId: json['product_id']?.toString(),
      qualityLevel: (json['quality_level'] as num?)?.toInt() ?? 0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      pendingQuantity: (json['pending_quantity'] as num?)?.toInt() ?? 0,
      capacity: (json['capacity'] as num?)?.toInt() ?? 0,
    );
  }
}
