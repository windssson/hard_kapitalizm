class MarketBuyerWarehouseModel {
  final String warehouseId;
  final String warehouseName;
  final String? warehouseIcon;
  final String cityId;
  final String cityName;
  final double cityX;
  final double cityY;
  final bool isActive;

  const MarketBuyerWarehouseModel({
    required this.warehouseId,
    required this.warehouseName,
    required this.warehouseIcon,
    required this.cityId,
    required this.cityName,
    required this.cityX,
    required this.cityY,
    required this.isActive,
  });

  factory MarketBuyerWarehouseModel.fromJson(Map<String, dynamic> json) {
    final cityJson = json['city'] as Map<String, dynamic>? ?? {};
    final warehouseTypeJson =
        json['warehouse_type'] as Map<String, dynamic>? ?? {};

    double parseNum(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0;
    }

    return MarketBuyerWarehouseModel(
      warehouseId: (json['id'] ?? '').toString(),
      warehouseName: (json['name'] ?? 'Depo').toString(),
      warehouseIcon: warehouseTypeJson['icon']?.toString(),
      cityId: (json['city_id'] ?? '').toString(),
      cityName: (cityJson['name'] ?? 'Bilinmeyen').toString(),
      cityX: parseNum(cityJson['map_position_x']),
      cityY: parseNum(cityJson['map_position_y']),
      isActive: json['is_active'] as bool? ?? false,
    );
  }
}
