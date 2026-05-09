class LogisticsCompanyModel {
  final String id;
  final String playerId;
  final String? cityId;
  final String name;
  final int level;
  final int currentVehicleCount;
  final int maxVehicleCount;
  final int fuelCapacity;
  final int currentFuel;
  final double fuelCost;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  LogisticsCompanyModel({
    required this.id,
    required this.playerId,
    required this.cityId,
    required this.name,
    required this.level,
    required this.currentVehicleCount,
    required this.maxVehicleCount,
    required this.fuelCapacity,
    required this.currentFuel,
    required this.fuelCost,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LogisticsCompanyModel.fromJson(Map<String, dynamic> json) {
    return LogisticsCompanyModel(
      id: json['id'] as String,
      playerId: json['player_id'] as String,
      cityId: json['city_id'] as String?,
      name: json['name'] as String,
      level: json['level'] as int? ?? 1,
      currentVehicleCount: json['current_vehicle_count'] as int? ?? 0,
      maxVehicleCount: json['max_vehicle_count'] as int? ?? 0,
      fuelCapacity: json['fuel_capacity'] as int? ?? 0,
      currentFuel: json['current_fuel'] as int? ?? 0,
      fuelCost: (json['fuel_cost'] as num?)?.toDouble() ?? 0.0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'player_id': playerId,
      'city_id': cityId,
      'name': name,
      'level': level,
      'current_vehicle_count': currentVehicleCount,
      'max_vehicle_count': maxVehicleCount,
      'fuel_capacity': fuelCapacity,
      'current_fuel': currentFuel,
      'fuel_cost': fuelCost,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
