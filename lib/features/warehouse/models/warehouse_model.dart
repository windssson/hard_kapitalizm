class WarehouseModel {
  final String id;
  final String playerId;
  final String warehouseTypeId;
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
    return WarehouseModel(
      id: json['id'] as String,
      playerId: json['player_id'] as String,
      warehouseTypeId: json['warehouse_type_id'] as String,
      typeIcon: json['warehouse_type']?['icon'] as String?,
      cityId: json['city_id'] as String,
      cityName: json['city']?['name'] as String?,
      name: json['name'] as String,
      level: json['level'] as int? ?? 1,
      capacity: (json['capacity'] as num?)?.toDouble() ?? 0.0,
      reservedCapacity: (json['reserved_capacity'] as num?)?.toDouble() ?? 0.0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      slots: json['warehouse_slots'] != null
          ? (json['warehouse_slots'] as List)
              .map((s) => WarehouseSlotModel.fromJson(s))
              .toList()
          : [],
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
    final productJson = json['product'] as Map<String, dynamic>?;
    
    return WarehouseSlotModel(
      id: json['id'] as String,
      productId: json['product_id'] as String?,
      productName: json['product_name'] as String? ?? productJson?['urun_adi'] as String?,
      productIcon: productJson?['urun_iconu'] as String?,
      quantity: json['quantity'] as int? ?? 0,
      unitVolume: (productJson?['birim_hacim'] as num?)?.toDouble() ?? 0.0,
      qualityLevel: json['quality_level'] as int? ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      cost: (json['cost'] as num?)?.toDouble() ?? 0.0,
      isAvailableForSale: json['is_available_for_sale'] as bool? ?? false,
    );
  }

  bool get isEmpty => productId == null;
}
