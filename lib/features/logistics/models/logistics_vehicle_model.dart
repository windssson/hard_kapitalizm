class LogisticsVehicleModel {
  final String id;
  final String playerId;
  final String logisticsCompanyId;
  final String logisticsVehicleTypeId;
  final int capacity;
  final int speedKmh;
  final int fuelCapacity;
  final int currentFuel;
  final double fuelRate;
  final int condition;
  final String status;
  final bool isAvailableForRent;
  final double rentalPrice;
  final DateTime createdAt;
  final DateTime updatedAt;

  LogisticsVehicleModel({
    required this.id,
    required this.playerId,
    required this.logisticsCompanyId,
    required this.logisticsVehicleTypeId,
    required this.capacity,
    required this.speedKmh,
    required this.fuelCapacity,
    required this.currentFuel,
    required this.fuelRate,
    required this.condition,
    required this.status,
    required this.isAvailableForRent,
    required this.rentalPrice,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LogisticsVehicleModel.fromJson(Map<String, dynamic> json) {
    return LogisticsVehicleModel(
      id: json['id'] as String,
      playerId: json['player_id'] as String,
      logisticsCompanyId: json['logistics_company_id'] as String,
      logisticsVehicleTypeId: json['logistics_vehicle_type_id'] as String,
      capacity: json['capacity'] as int? ?? 0,
      speedKmh: json['speed_kmh'] as int? ?? 0,
      fuelCapacity: json['fuel_capacity'] as int? ?? 0,
      currentFuel: json['current_fuel'] as int? ?? 0,
      fuelRate: (json['fuel_rate'] as num?)?.toDouble() ?? 0.0,
      condition: json['condition'] as int? ?? 100,
      status: json['status'] as String? ?? 'idle',
      isAvailableForRent: json['is_available_for_rent'] as bool? ?? false,
      rentalPrice: (json['rental_price'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'player_id': playerId,
      'logistics_company_id': logisticsCompanyId,
      'logistics_vehicle_type_id': logisticsVehicleTypeId,
      'capacity': capacity,
      'speed_kmh': speedKmh,
      'fuel_capacity': fuelCapacity,
      'current_fuel': currentFuel,
      'fuel_rate': fuelRate,
      'condition': condition,
      'status': status,
      'is_available_for_rent': isAvailableForRent,
      'rental_price': rentalPrice,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
