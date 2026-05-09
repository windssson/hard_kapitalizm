class LogisticsVehicleTypeModel {
  final String id;
  final String name;
  final String type;
  final String description;
  final int capacity;
  final int speedKmh;
  final int fuelCapacity;
  final double fuelRate;
  final double purchasePrice;
  final String icon;

  LogisticsVehicleTypeModel({
    required this.id,
    required this.name,
    required this.type,
    required this.description,
    required this.capacity,
    required this.speedKmh,
    required this.fuelCapacity,
    required this.fuelRate,
    required this.purchasePrice,
    required this.icon,
  });

  factory LogisticsVehicleTypeModel.fromJson(Map<String, dynamic> json) {
    return LogisticsVehicleTypeModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      capacity: json['capacity'] as int? ?? 0,
      speedKmh: json['speed_kmh'] as int? ?? 0,
      fuelCapacity: json['fuel_capacity'] as int? ?? 0,
      fuelRate: (json['fuel_rate'] as num?)?.toDouble() ?? 0,
      purchasePrice: (json['purchase_price'] as num?)?.toDouble() ?? 0,
      icon: (json['icon'] ?? '').toString(),
    );
  }
}
