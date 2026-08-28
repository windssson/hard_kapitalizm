import 'package:hard_kapitalizm/features/warehouse/models/warehouse_model.dart';

class ProductionLogisticsWarehouseOption {
  final String id;
  final String name;
  final String cityId;
  final String cityName;
  final bool isSameCity;
  final List<WarehouseSlotModel> slots;
  final double capacity;
  final double reservedCapacity;
  final String? warehouseTypeCode;
  final bool isStoreWarehouse;

  const ProductionLogisticsWarehouseOption({
    required this.id,
    required this.name,
    required this.cityId,
    required this.cityName,
    required this.isSameCity,
    required this.slots,
    this.capacity = 0.0,
    this.reservedCapacity = 0.0,
    this.warehouseTypeCode,
    this.isStoreWarehouse = false,
  });

  double get freeCapacity => (capacity - reservedCapacity).clamp(0.0, capacity);
  double get capacityRatio => capacity > 0 ? (reservedCapacity / capacity).clamp(0.0, 1.0) : 0.0;

  factory ProductionLogisticsWarehouseOption.fromJson(
    Map<String, dynamic> json, {
    required String productionCityId,
  }) {
    final cityId = (json['city_id'] ?? '').toString();
    final slotsRaw = json['warehouse_slots'] as List<dynamic>? ?? [];
    final capacity = (json['capacity'] as num?)?.toDouble() ?? 0.0;
    final reservedCapacity = (json['reserved_capacity'] as num?)?.toDouble() ?? 0.0;
    final typeMap = json['warehouse_type'] as Map?;
    final typeCode = typeMap?['code']?.toString();
    final isStore = typeCode == 'store_warehouse' ||
        typeMap?['is_store_warehouse'] == true ||
        (json['name']?.toString().toLowerCase().contains('mağaza') ?? false) ||
        (json['name']?.toString().toLowerCase().contains('magaza') ?? false);

    return ProductionLogisticsWarehouseOption(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Depo').toString(),
      cityId: cityId,
      cityName: (json['city']?['name'] ?? 'Bilinmeyen Şehir').toString(),
      isSameCity: cityId.isNotEmpty && cityId == productionCityId,
      slots: slotsRaw.map((s) => WarehouseSlotModel.fromJson(s)).toList(),
      capacity: capacity,
      reservedCapacity: reservedCapacity,
      warehouseTypeCode: typeCode,
      isStoreWarehouse: isStore,
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
    final vehicleOwnerPlayerId =
        (json['vehicle_owner_player_id'] ?? '').toString();
    final rentalPrice = (json['rental_price'] as num?)?.toDouble() ?? 0;
    final rentalCost = (json['rental_cost'] as num?)?.toDouble() ?? 0;

    return ProductionLogisticsVehicleOption(
      vehicleId: (json['vehicle_id'] ?? '').toString(),
      vehicleOwnerPlayerId: vehicleOwnerPlayerId,
      vehicleName: (json['vehicle_name'] ?? 'Araç').toString(),
      isRental: json['is_rental'] as bool? ??
          (vehicleOwnerPlayerId.isEmpty || rentalPrice > 0 || rentalCost > 0),
      capacity: (json['capacity'] as num?)?.toInt() ?? 0,
      speedKmh: (json['speed_kmh'] as num?)?.toInt() ?? 0,
      currentFuel: (json['current_fuel'] as num?)?.toInt() ?? 0,
      fuelCapacity: (json['fuel_capacity'] as num?)?.toInt() ?? 0,
      fuelRate: (json['fuel_rate'] as num?)?.toDouble() ?? 0,
      condition: (json['condition'] as num?)?.toInt() ?? 0,
      rentalPrice: rentalPrice,
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0,
      rentalCost: rentalCost,
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
