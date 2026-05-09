class LogisticsCompanyTypeModel {
  final String id;
  final String name;
  final double cost;
  final int requiredLevel;
  final int constructionTimeMinutes;
  final int maxVehicleCount;
  final int fuelCapacity;

  LogisticsCompanyTypeModel({
    required this.id,
    required this.name,
    required this.cost,
    required this.requiredLevel,
    required this.constructionTimeMinutes,
    required this.maxVehicleCount,
    required this.fuelCapacity,
  });

  factory LogisticsCompanyTypeModel.fromJson(Map<String, dynamic> json) {
    return LogisticsCompanyTypeModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      cost: (json['cost'] as num?)?.toDouble() ?? 0,
      requiredLevel: json['required_level'] as int? ?? 1,
      constructionTimeMinutes: json['construction_time_minutes'] as int? ?? 0,
      maxVehicleCount: json['max_vehicle_count'] as int? ?? 0,
      fuelCapacity: json['fuel_capacity'] as int? ?? 0,
    );
  }
}
