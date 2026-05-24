class ProductionLogisticsWarehouseOption {
  final String id;
  final String name;
  final String cityId;
  final String cityName;
  final bool isSameCity;

  const ProductionLogisticsWarehouseOption({
    required this.id,
    required this.name,
    required this.cityId,
    required this.cityName,
    required this.isSameCity,
  });

  factory ProductionLogisticsWarehouseOption.fromJson(
    Map<String, dynamic> json, {
    required String productionCityId,
  }) {
    final cityId = (json['city_id'] ?? '').toString();
    return ProductionLogisticsWarehouseOption(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Depo').toString(),
      cityId: cityId,
      cityName: (json['city']?['name'] ?? 'Bilinmeyen Sehir').toString(),
      isSameCity: cityId.isNotEmpty && cityId == productionCityId,
    );
  }
}

class ProductionLogisticsVehicleOption {
  final String vehicleId;
  final String vehicleOwnerPlayerId;
  final String vehicleName;
  final bool isRental;
  final int capacity;
  final int speedKmh;
  final int currentFuel;
  final int fuelCapacity;
  final double fuelRate;
  final int condition;
  final double rentalPrice;
  final double totalPrice;
  final double rentalCost;
  final double fuelCost;
  final double distanceKm;
  final double fuelNeeded;
  final double conditionNeeded;
  final int estimatedDurationSeconds;
  final bool canSelect;
  final String? disabledReason;

  const ProductionLogisticsVehicleOption({
    required this.vehicleId,
    required this.vehicleOwnerPlayerId,
    required this.vehicleName,
    required this.isRental,
    required this.capacity,
    required this.speedKmh,
    required this.currentFuel,
    required this.fuelCapacity,
    required this.fuelRate,
    required this.condition,
    required this.rentalPrice,
    required this.totalPrice,
    required this.rentalCost,
    required this.fuelCost,
    required this.distanceKm,
    required this.fuelNeeded,
    required this.conditionNeeded,
    required this.estimatedDurationSeconds,
    required this.canSelect,
    required this.disabledReason,
  });

  factory ProductionLogisticsVehicleOption.fromJson(Map<String, dynamic> json) {
    return ProductionLogisticsVehicleOption(
      vehicleId: (json['vehicle_id'] ?? '').toString(),
      vehicleOwnerPlayerId: (json['vehicle_owner_player_id'] ?? '').toString(),
      vehicleName: (json['vehicle_name'] ?? 'Arac').toString(),
      isRental: json['is_rental'] as bool? ?? false,
      capacity: (json['capacity'] as num?)?.toInt() ?? 0,
      speedKmh: (json['speed_kmh'] as num?)?.toInt() ?? 0,
      currentFuel: (json['current_fuel'] as num?)?.toInt() ?? 0,
      fuelCapacity: (json['fuel_capacity'] as num?)?.toInt() ?? 0,
      fuelRate: (json['fuel_rate'] as num?)?.toDouble() ?? 0,
      condition: (json['condition'] as num?)?.toInt() ?? 0,
      rentalPrice: (json['rental_price'] as num?)?.toDouble() ?? 0,
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0,
      rentalCost: (json['rental_cost'] as num?)?.toDouble() ?? 0,
      fuelCost: (json['fuel_cost'] as num?)?.toDouble() ?? 0,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0,
      fuelNeeded: (json['fuel_needed'] as num?)?.toDouble() ?? 0,
      conditionNeeded: (json['condition_needed'] as num?)?.toDouble() ?? 0,
      estimatedDurationSeconds:
          (json['estimated_duration_seconds'] as num?)?.toInt() ??
          ((json['duration_minutes'] as num?)?.toInt() ?? 0) * 60,
      canSelect: json['can_select'] as bool? ?? false,
      disabledReason: json['disabled_reason']?.toString(),
    );
  }
}

class ProductionLogisticsStartResult {
  final bool success;
  final String message;
  final String? transferId;

  const ProductionLogisticsStartResult({
    required this.success,
    required this.message,
    this.transferId,
  });

  factory ProductionLogisticsStartResult.fromJson(Map<String, dynamic> json) {
    return ProductionLogisticsStartResult(
      success: json['success'] == true,
      message: (json['message'] ?? '').toString(),
      transferId: json['transfer_id']?.toString(),
    );
  }
}
