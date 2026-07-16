class TenderDetailModel {
  final bool success;
  final String message;
  final TenderDetailTenderModel tender;
  final PlayerTenderDetailSummaryModel? playerTender;
  final PlayerTenderBidSummaryModel? playerBid;
  final List<TenderWarehouseOptionModel> warehouseOptions;
  final List<TenderActiveDeliveryModel> activeDeliveries;

  const TenderDetailModel({
    required this.success,
    required this.message,
    required this.tender,
    required this.playerTender,
    required this.playerBid,
    required this.warehouseOptions,
    required this.activeDeliveries,
  });

  factory TenderDetailModel.fromJson(Map<String, dynamic> json) {
    return TenderDetailModel(
      success: json['success'] as bool? ?? false,
      message: (json['message'] ?? '').toString(),
      tender: TenderDetailTenderModel.fromJson(_asMap(json['tender'])),
      playerTender: json['player_tender'] == null
          ? null
          : PlayerTenderDetailSummaryModel.fromJson(
              _asMap(json['player_tender']),
            ),
      playerBid: json['player_bid'] == null
          ? null
          : PlayerTenderBidSummaryModel.fromJson(_asMap(json['player_bid'])),
      warehouseOptions: _asList(json['warehouse_options'])
          .whereType<Map>()
          .map(
            (item) => TenderWarehouseOptionModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
      activeDeliveries: _asList(json['active_deliveries'])
          .whereType<Map>()
          .map(
            (item) => TenderActiveDeliveryModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
    );
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  static List<dynamic> _asList(dynamic value) {
    if (value is List<dynamic>) return value;
    if (value is List) return List<dynamic>.from(value);
    return const <dynamic>[];
  }
}

class PlayerTenderBidSummaryModel {
  final String id;
  final double bidAmount;
  final double bondPaid;
  final String status;
  final DateTime? submittedAt;
  final DateTime? updatedAt;

  const PlayerTenderBidSummaryModel({
    required this.id,
    required this.bidAmount,
    required this.bondPaid,
    required this.status,
    required this.submittedAt,
    required this.updatedAt,
  });

  factory PlayerTenderBidSummaryModel.fromJson(Map<String, dynamic> json) {
    return PlayerTenderBidSummaryModel(
      id: (json['id'] ?? '').toString(),
      bidAmount: (json['bid_amount'] as num?)?.toDouble() ?? 0,
      bondPaid: (json['bond_paid'] as num?)?.toDouble() ?? 0,
      status: (json['status'] ?? 'active').toString(),
      submittedAt: DateTime.tryParse((json['submitted_at'] ?? '').toString()),
      updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()),
    );
  }
}

class TenderDetailTenderModel {
  final String id;
  final String title;
  final String description;
  final String cityId;
  final String cityName;
  final String productId;
  final String productName;
  final String productIcon;
  final double productUnitVolume;
  final double productBasePrice;
  final int qualityLevel;
  final int requiredQuantity;
  final double rewardCash;
  final double bondAmount;
  final String awardType;
  final DateTime? acceptUntil;
  final int deliveryDurationMinutes;
  final String status;

  const TenderDetailTenderModel({
    required this.id,
    required this.title,
    required this.description,
    required this.cityId,
    required this.cityName,
    required this.productId,
    required this.productName,
    required this.productIcon,
    required this.productUnitVolume,
    required this.productBasePrice,
    required this.qualityLevel,
    required this.requiredQuantity,
    required this.rewardCash,
    required this.bondAmount,
    required this.awardType,
    required this.acceptUntil,
    required this.deliveryDurationMinutes,
    required this.status,
  });

  factory TenderDetailTenderModel.fromJson(Map<String, dynamic> json) {
    return TenderDetailTenderModel(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Ihale').toString(),
      description: (json['description'] ?? '').toString(),
      cityId: (json['city_id'] ?? '').toString(),
      cityName: (json['city_name'] ?? '-').toString(),
      productId: (json['product_id'] ?? '').toString(),
      productName: (json['product_name'] ?? '-').toString(),
      productIcon: (json['product_icon'] ?? 'default.webp').toString(),
      productUnitVolume: (json['product_unit_volume'] as num?)?.toDouble() ?? 0,
      productBasePrice: (json['product_base_price'] as num?)?.toDouble() ?? 0,
      qualityLevel: (json['quality_level'] as num?)?.toInt() ?? 1,
      requiredQuantity: (json['required_quantity'] as num?)?.toInt() ?? 0,
      rewardCash: (json['reward_cash'] as num?)?.toDouble() ?? 0,
      bondAmount: (json['bond_amount'] as num?)?.toDouble() ?? 0,
      awardType: (json['award_type'] ?? 'lowest_bid').toString(),
      acceptUntil: DateTime.tryParse((json['accept_until'] ?? '').toString()),
      deliveryDurationMinutes:
          (json['delivery_duration_minutes'] as num?)?.toInt() ?? 0,
      status: (json['status'] ?? 'open').toString(),
    );
  }
}

class TenderVehicleOptionsRequest {
  final String sourceCityId;
  final String targetCityId;
  final double totalVolume;

  const TenderVehicleOptionsRequest({
    required this.sourceCityId,
    required this.targetCityId,
    required this.totalVolume,
  });

  @override
  bool operator ==(Object other) {
    return other is TenderVehicleOptionsRequest &&
        other.sourceCityId == sourceCityId &&
        other.targetCityId == targetCityId &&
        other.totalVolume == totalVolume;
  }

  @override
  int get hashCode => Object.hash(sourceCityId, targetCityId, totalVolume);
}

class TenderVehicleOptionModel {
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

  const TenderVehicleOptionModel({
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

  factory TenderVehicleOptionModel.fromJson(Map<String, dynamic> json) {
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

    return TenderVehicleOptionModel(
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

class PlayerTenderDetailSummaryModel {
  final String id;
  final DateTime? acceptedAt;
  final DateTime? deadlineAt;
  final int requiredQuantity;
  final int deliveredQuantity;
  final int inTransitQuantity;
  final int remainingQuantity;
  final String status;

  const PlayerTenderDetailSummaryModel({
    required this.id,
    required this.acceptedAt,
    required this.deadlineAt,
    required this.requiredQuantity,
    required this.deliveredQuantity,
    required this.inTransitQuantity,
    required this.remainingQuantity,
    required this.status,
  });

  factory PlayerTenderDetailSummaryModel.fromJson(Map<String, dynamic> json) {
    return PlayerTenderDetailSummaryModel(
      id: (json['id'] ?? '').toString(),
      acceptedAt: DateTime.tryParse((json['accepted_at'] ?? '').toString()),
      deadlineAt: DateTime.tryParse((json['deadline_at'] ?? '').toString()),
      requiredQuantity: (json['required_quantity'] as num?)?.toInt() ?? 0,
      deliveredQuantity: (json['delivered_quantity'] as num?)?.toInt() ?? 0,
      inTransitQuantity: (json['in_transit_quantity'] as num?)?.toInt() ?? 0,
      remainingQuantity: (json['remaining_quantity'] as num?)?.toInt() ?? 0,
      status: (json['status'] ?? 'active').toString(),
    );
  }
}

class TenderWarehouseOptionModel {
  final String warehouseId;
  final String warehouseName;
  final String cityId;
  final String cityName;
  final int availableQuantity;
  final double unitCost;
  final bool sameCity;
  final double distanceKm;
  final int? estimatedDurationMinutes;
  final bool? canDeliverBeforeDeadline;
  final bool recommended;

  const TenderWarehouseOptionModel({
    required this.warehouseId,
    required this.warehouseName,
    required this.cityId,
    required this.cityName,
    required this.availableQuantity,
    required this.unitCost,
    required this.sameCity,
    required this.distanceKm,
    required this.estimatedDurationMinutes,
    required this.canDeliverBeforeDeadline,
    required this.recommended,
  });

  factory TenderWarehouseOptionModel.fromJson(Map<String, dynamic> json) {
    return TenderWarehouseOptionModel(
      warehouseId: (json['warehouse_id'] ?? '').toString(),
      warehouseName: (json['warehouse_name'] ?? 'Depo').toString(),
      cityId: (json['city_id'] ?? '').toString(),
      cityName: (json['city_name'] ?? '-').toString(),
      availableQuantity: (json['available_quantity'] as num?)?.toInt() ?? 0,
      unitCost: (json['unit_cost'] as num?)?.toDouble() ?? 0,
      sameCity: json['same_city'] as bool? ?? false,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0,
      estimatedDurationMinutes:
          (json['estimated_duration_minutes'] as num?)?.toInt(),
      canDeliverBeforeDeadline: json['can_deliver_before_deadline'] as bool?,
      recommended: json['recommended'] as bool? ?? false,
    );
  }
}

class TenderActiveDeliveryModel {
  final String id;
  final String sourceWarehouseId;
  final String sourceWarehouseName;
  final String sourceCityName;
  final int quantity;
  final String status;
  final bool sameCity;
  final DateTime? startedAt;
  final DateTime? finishAt;

  const TenderActiveDeliveryModel({
    required this.id,
    required this.sourceWarehouseId,
    required this.sourceWarehouseName,
    required this.sourceCityName,
    required this.quantity,
    required this.status,
    required this.sameCity,
    required this.startedAt,
    required this.finishAt,
  });

  factory TenderActiveDeliveryModel.fromJson(Map<String, dynamic> json) {
    return TenderActiveDeliveryModel(
      id: (json['id'] ?? '').toString(),
      sourceWarehouseId: (json['source_warehouse_id'] ?? '').toString(),
      sourceWarehouseName: (json['source_warehouse_name'] ?? 'Depo').toString(),
      sourceCityName: (json['source_city_name'] ?? '-').toString(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      status: (json['status'] ?? 'in_transit').toString(),
      sameCity: json['same_city'] as bool? ?? false,
      startedAt: DateTime.tryParse((json['started_at'] ?? '').toString()),
      finishAt: DateTime.tryParse((json['finish_at'] ?? '').toString()),
    );
  }
}
