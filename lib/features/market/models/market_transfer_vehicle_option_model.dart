class MarketTransferVehicleOptionModel {
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
  final double distanceKm;
  final double fuelNeeded;
  final double conditionNeeded;
  final double rentalCost;
  final double fuelCost;
  final double transportCost;
  final int estimatedDurationSeconds;
  final bool canSelect;
  final String? disabledReason;

  const MarketTransferVehicleOptionModel({
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
    required this.distanceKm,
    required this.fuelNeeded,
    required this.conditionNeeded,
    required this.rentalCost,
    required this.fuelCost,
    required this.transportCost,
    required this.estimatedDurationSeconds,
    required this.canSelect,
    required this.disabledReason,
  });

  factory MarketTransferVehicleOptionModel.fromJson(Map<String, dynamic> json) {
    double parseNum(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0;
    }

    final rentalCost = parseNum(json['rental_cost']);
    final fuelCost = parseNum(json['fuel_cost']);
    final transportCost = parseNum(json['total_price']);
    final vehicleOwnerPlayerId =
        (json['vehicle_owner_player_id'] ?? '').toString();
    final rentalPrice = parseNum(json['rental_price']);

    return MarketTransferVehicleOptionModel(
      vehicleId: (json['vehicle_id'] ?? '').toString(),
      vehicleOwnerPlayerId: vehicleOwnerPlayerId,
      vehicleName: (json['vehicle_name'] ?? 'Arac').toString(),
      isRental: json['is_rental'] as bool? ??
          (vehicleOwnerPlayerId.isEmpty || rentalPrice > 0 || rentalCost > 0),
      capacity: (json['capacity'] as num?)?.toInt() ?? 0,
      speedKmh: (json['speed_kmh'] as num?)?.toInt() ?? 0,
      currentFuel: (json['current_fuel'] as num?)?.toInt() ?? 0,
      fuelCapacity: (json['fuel_capacity'] as num?)?.toInt() ?? 0,
      fuelRate: parseNum(json['fuel_rate']),
      condition: (json['condition'] as num?)?.toInt() ?? 0,
      rentalPrice: rentalPrice,
      distanceKm: parseNum(json['distance_km']),
      fuelNeeded: parseNum(json['fuel_needed']),
      conditionNeeded: parseNum(json['condition_needed']),
      rentalCost: rentalCost,
      fuelCost: fuelCost,
      transportCost:
          transportCost > 0 ? transportCost : rentalCost + fuelCost,
      estimatedDurationSeconds:
          (json['estimated_duration_seconds'] as num?)?.toInt() ?? 0,
      canSelect: json['can_select'] as bool? ?? false,
      disabledReason: json['disabled_reason']?.toString(),
    );
  }
}
