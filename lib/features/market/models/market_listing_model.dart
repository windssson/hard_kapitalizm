class MarketListingModel {
  final String slotId;
  final String warehouseId;
  final String warehouseName;
  final String? warehouseIcon;
  final String cityId;
  final String cityName;
  final double cityX;
  final double cityY;
  final int quantity;
  final int qualityLevel;
  final double cost;
  final bool isAvailableForSale;

  const MarketListingModel({
    required this.slotId,
    required this.warehouseId,
    required this.warehouseName,
    required this.warehouseIcon,
    required this.cityId,
    required this.cityName,
    required this.cityX,
    required this.cityY,
    required this.quantity,
    required this.qualityLevel,
    required this.cost,
    required this.isAvailableForSale,
  });

  factory MarketListingModel.fromJson(Map<String, dynamic> json) {
    final warehouseJson = json['warehouse'] as Map<String, dynamic>? ?? {};
    final cityJson = warehouseJson['city'] as Map<String, dynamic>? ?? {};
    final warehouseTypeJson =
        warehouseJson['warehouse_type'] as Map<String, dynamic>? ?? {};

    double parseNum(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0;
    }

    return MarketListingModel(
      slotId: (json['slot_id'] ?? json['id'] ?? '').toString(),
      warehouseId: (json['warehouse_id'] ?? '').toString(),
      warehouseName:
          (json['warehouse_name'] ?? warehouseJson['name'] ?? 'Depo')
              .toString(),
      warehouseIcon:
          json['warehouse_icon']?.toString() ??
          warehouseTypeJson['icon']?.toString(),
      cityId: (json['city_id'] ?? '').toString(),
      cityName: (json['city_name'] ?? cityJson['name'] ?? 'Bilinmeyen')
          .toString(),
      cityX: parseNum(json['city_x'] ?? cityJson['map_position_x']),
      cityY: parseNum(json['city_y'] ?? cityJson['map_position_y']),
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      qualityLevel: (json['quality_level'] as num?)?.toInt() ?? 0,
      cost: (json['cost'] as num?)?.toDouble() ?? 0,
      isAvailableForSale: json['is_available_for_sale'] as bool? ?? false,
    );
  }
}
