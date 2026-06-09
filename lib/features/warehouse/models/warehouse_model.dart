class WarehouseModel {
  final String id;
  final String playerId;
  final String warehouseTypeId;
  final Map<String, dynamic>? warehouseType;
  final String? typeIcon; // Depo tipi ikonu
  final String cityId;
  final String? cityName;
  final String name;
  final int level;
  final double capacity;
  final double reservedCapacity;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<WarehouseSlotModel> slots;

  final bool isUnderConstruction;
  final DateTime? finishAt;

  WarehouseModel({
    required this.id,
    required this.playerId,
    required this.warehouseTypeId,
    this.warehouseType,
    this.typeIcon,
    required this.cityId,
    this.cityName,
    required this.name,
    required this.level,
    required this.capacity,
    required this.reservedCapacity,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.slots = const [],
    this.isUnderConstruction = false,
    this.finishAt,
  });

  factory WarehouseModel.fromJson(Map<String, dynamic> json) {
    final warehouseTypeJson = json['warehouse_type'] is Map<String, dynamic>
        ? json['warehouse_type'] as Map<String, dynamic>
        : json['warehouse_type'] is Map
            ? Map<String, dynamic>.from(json['warehouse_type'] as Map)
            : null;
    final cityJson = json['city'] is Map<String, dynamic>
        ? json['city'] as Map<String, dynamic>
        : json['city'] is Map
            ? Map<String, dynamic>.from(json['city'] as Map)
            : null;

    return WarehouseModel(
      id: (json['id'] ?? '').toString(),
      playerId: (json['player_id'] ?? '').toString(),
      warehouseTypeId: (json['warehouse_type_id'] ?? '').toString(),
      warehouseType: warehouseTypeJson,
      typeIcon: warehouseTypeJson?['icon']?.toString(),
      cityId: (json['city_id'] ?? '').toString(),
      cityName: cityJson?['name']?.toString(),
      name: (json['name'] ?? '').toString(),
      level: (json['level'] as num?)?.toInt() ?? 1,
      capacity: (json['capacity'] as num?)?.toDouble() ?? 0.0,
      reservedCapacity: (json['reserved_capacity'] as num?)?.toDouble() ?? 0.0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
      updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()) ??
          DateTime.now(),
      slots: json['warehouse_slots'] != null
          ? (json['warehouse_slots'] as List)
              .map((s) => WarehouseSlotModel.fromJson(s))
              .toList()
          : [],
      isUnderConstruction: json['is_under_construction'] as bool? ?? false,
      finishAt: json['finish_at'] != null
          ? DateTime.tryParse(json['finish_at'] as String)
          : null,
    );
  }

  WarehouseModel copyWith({
    String? id,
    String? playerId,
    String? warehouseTypeId,
    Object? warehouseType = _warehouseUnset,
    String? typeIcon,
    String? cityId,
    Object? cityName = _warehouseUnset,
    String? name,
    int? level,
    double? capacity,
    double? reservedCapacity,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<WarehouseSlotModel>? slots,
    bool? isUnderConstruction,
    Object? finishAt = _warehouseUnset,
  }) {
    return WarehouseModel(
      id: id ?? this.id,
      playerId: playerId ?? this.playerId,
      warehouseTypeId: warehouseTypeId ?? this.warehouseTypeId,
      warehouseType: identical(warehouseType, _warehouseUnset)
          ? this.warehouseType
          : warehouseType as Map<String, dynamic>?,
      typeIcon: typeIcon ?? this.typeIcon,
      cityId: cityId ?? this.cityId,
      cityName: identical(cityName, _warehouseUnset)
          ? this.cityName
          : cityName as String?,
      name: name ?? this.name,
      level: level ?? this.level,
      capacity: capacity ?? this.capacity,
      reservedCapacity: reservedCapacity ?? this.reservedCapacity,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      slots: slots ?? this.slots,
      isUnderConstruction: isUnderConstruction ?? this.isUnderConstruction,
      finishAt: identical(finishAt, _warehouseUnset)
          ? this.finishAt
          : finishAt as DateTime?,
    );
  }
}

class WarehouseSlotModel {
  final String id;
  final String? productId;
  final String? productName;
  final String? productIcon;
  final int quantity;
  final double unitVolume;
  final int qualityLevel;
  final double price;
  final double cost;
  final bool isAvailableForSale;

  WarehouseSlotModel({
    required this.id,
    this.productId,
    this.productName,
    this.productIcon,
    required this.quantity,
    this.unitVolume = 0,
    required this.qualityLevel,
    this.price = 0,
    this.cost = 0,
    this.isAvailableForSale = false,
  });

  factory WarehouseSlotModel.fromJson(Map<String, dynamic> json) {
    final productJson = json['product'] is Map<String, dynamic>
        ? json['product'] as Map<String, dynamic>
        : json['product'] is Map
            ? Map<String, dynamic>.from(json['product'] as Map)
            : null;
    
    return WarehouseSlotModel(
      id: (json['id'] ?? '').toString(),
      productId: json['product_id']?.toString(),
      productName: json['product_name'] as String? ?? productJson?['urun_adi'] as String?,
      productIcon: productJson?['urun_iconu'] as String?,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      unitVolume: (productJson?['birim_hacim'] as num?)?.toDouble() ?? 0.0,
      qualityLevel: (json['quality_level'] as num?)?.toInt() ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      cost: (json['cost'] as num?)?.toDouble() ?? 0.0,
      isAvailableForSale: json['is_available_for_sale'] as bool? ?? false,
    );
  }

  WarehouseSlotModel copyWith({
    String? id,
    Object? productId = _warehouseUnset,
    Object? productName = _warehouseUnset,
    Object? productIcon = _warehouseUnset,
    int? quantity,
    double? unitVolume,
    int? qualityLevel,
    double? price,
    double? cost,
    bool? isAvailableForSale,
  }) {
    return WarehouseSlotModel(
      id: id ?? this.id,
      productId: identical(productId, _warehouseUnset)
          ? this.productId
          : productId as String?,
      productName: identical(productName, _warehouseUnset)
          ? this.productName
          : productName as String?,
      productIcon: identical(productIcon, _warehouseUnset)
          ? this.productIcon
          : productIcon as String?,
      quantity: quantity ?? this.quantity,
      unitVolume: unitVolume ?? this.unitVolume,
      qualityLevel: qualityLevel ?? this.qualityLevel,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      isAvailableForSale: isAvailableForSale ?? this.isAvailableForSale,
    );
  }

  bool get isEmpty => productId == null || quantity <= 0;
}

const _warehouseUnset = Object();
