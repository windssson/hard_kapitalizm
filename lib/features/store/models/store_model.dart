import 'package:hard_kapitalizm/core/models/product_model.dart';

class StoreTypeModel {
  final String id;
  final String name;
  final String icon;
  final int cost;
  final int requiredLevel;
  final int constructionTimeMinutes;

  StoreTypeModel({
    required this.id,
    required this.name,
    required this.icon,
    this.cost = 0,
    this.requiredLevel = 1,
    this.constructionTimeMinutes = 30,
  });

  factory StoreTypeModel.fromJson(Map<String, dynamic> json) {
    return StoreTypeModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      icon: (json['icon'] ?? '').toString(),
      cost: (json['cost'] as num?)?.toInt() ?? 0,
      requiredLevel: (json['required_level'] as num?)?.toInt() ?? 1,
      constructionTimeMinutes: (json['construction_time_minutes'] as num?)?.toInt() ?? 30,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'icon': icon,
    'cost': cost,
    'required_level': requiredLevel,
    'construction_time_minutes': constructionTimeMinutes,
  };
}

class StoreSummaryModel {
  final int totalQuantity;
  final int totalCapacity;
  final int pendingQuantity;
  final int availableCapacity;
  final double usedCapacityRatio;
  final double? pendingSaleTotal;
  final double? totalStockCostValue;
  final double? totalStockSaleValue;

  StoreSummaryModel({
    required this.totalQuantity,
    required this.totalCapacity,
    required this.pendingQuantity,
    required this.availableCapacity,
    required this.usedCapacityRatio,
    this.pendingSaleTotal,
    this.totalStockCostValue,
    this.totalStockSaleValue,
  });

  factory StoreSummaryModel.fromJson(Map<String, dynamic> json) {
    return StoreSummaryModel(
      totalQuantity: (json['total_quantity'] as num?)?.toInt() ?? 0,
      totalCapacity: (json['total_capacity'] as num?)?.toInt() ?? 0,
      pendingQuantity: (json['pending_quantity'] as num?)?.toInt() ?? 0,
      availableCapacity: (json['available_capacity'] as num?)?.toInt() ?? 0,
      usedCapacityRatio: (json['used_capacity_ratio'] as num?)?.toDouble() ?? 0.0,
      pendingSaleTotal: (json['pending_sale_total'] as num?)?.toDouble(),
      totalStockCostValue: (json['total_stock_cost_value'] as num?)?.toDouble(),
      totalStockSaleValue: (json['total_stock_sale_value'] as num?)?.toDouble(),
    );
  }
}

class StoreSlotModel {
  final String id;
  final String storeId;
  final int slotIndex;
  final String? productId;
  final String? productName;
  final String? productIcon;
  final int quantity;
  final int pendingQuantity;
  final int qualityLevel;
  final double? price;
  final double? cost;
  final int capacity;
  final double boostMultiplier;
  final double? pendingSale;
  final bool isActive;
  final bool isEmpty;
  final double usedCapacityRatio;
  final ProductModel? product;

  StoreSlotModel({
    required this.id,
    required this.storeId,
    required this.slotIndex,
    this.productId,
    this.productName,
    this.productIcon,
    required this.quantity,
    required this.pendingQuantity,
    required this.qualityLevel,
    this.price,
    this.cost,
    required this.capacity,
    required this.boostMultiplier,
    this.pendingSale,
    required this.isActive,
    required this.isEmpty,
    required this.usedCapacityRatio,
    this.product,
  });

  factory StoreSlotModel.fromJson(Map<String, dynamic> json) {
    final productJson = json['product'] as Map<String, dynamic>?;
    
    return StoreSlotModel(
      id: (json['id'] ?? json['slot_id'] ?? '').toString(),
      storeId: (json['store_id'] ?? '').toString(),
      slotIndex: (json['slot_index'] as num?)?.toInt() ?? 0,
      productId: json['product_id'] as String?,
      productName: json['product_name'] as String? ?? productJson?['urun_adi'] as String?,
      productIcon: json['product_icon'] as String? ?? productJson?['urun_iconu'] as String?,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      pendingQuantity: (json['pending_quantity'] as num?)?.toInt() ?? 0,
      qualityLevel: (json['quality_level'] as num?)?.toInt() ?? 0,
      price: (json['price'] as num?)?.toDouble(),
      cost: (json['cost'] as num?)?.toDouble(),
      capacity: (json['capacity'] as num?)?.toInt() ?? 0,
      boostMultiplier: (json['boost_multiplier'] as num?)?.toDouble() ?? 1.0,
      pendingSale: (json['pending_sale'] as num?)?.toDouble(),
      isActive: json['is_active'] as bool? ?? true,
      isEmpty: json['is_empty'] as bool? ?? true,
      usedCapacityRatio: (json['used_capacity_ratio'] as num?)?.toDouble() ?? 0.0,
      product: productJson != null ? ProductModel.fromJson(productJson) : null,
    );
  }
}

class StoreModel {
  final String id;
  final String name;
  final String? cityId;
  final String? cityName;
  final int level;
  final bool isActive;
  final int currentSlotCount;
  final int maxSlotCount;
  final StoreTypeModel storeType;
  final StoreSummaryModel summary;
  final List<StoreSlotModel> slots;
  final bool isUnderConstruction;
  final DateTime? startedAt;
  final DateTime? finishAt;
  final double? constructionProgress;

  StoreModel({
    required this.id,
    required this.name,
    this.cityId,
    this.cityName,
    required this.level,
    required this.isActive,
    required this.currentSlotCount,
    required this.maxSlotCount,
    required this.storeType,
    required this.summary,
    required this.slots,
    this.isUnderConstruction = false,
    this.startedAt,
    this.finishAt,
    this.constructionProgress = 1.0,
  });

  factory StoreModel.fromJson(Map<String, dynamic> json) {
    return StoreModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      cityId: json['city_id'] as String?,
      cityName: json['city_name'] as String? ?? json['city']?['name'] as String?,
      level: (json['level'] as num?)?.toInt() ?? 1,
      isActive: json['is_active'] as bool? ?? true,
      currentSlotCount: (json['current_slot_count'] as num?)?.toInt() ?? 0,
      maxSlotCount: (json['max_slot_count'] as num?)?.toInt() ?? 0,
      storeType: json['store_type'] != null 
          ? StoreTypeModel.fromJson(json['store_type']) 
          : StoreTypeModel(id: '', name: '', icon: ''),
      summary: StoreSummaryModel.fromJson(json['summary'] ?? {}),
      slots: (json['slots'] as List? ?? [])
          .map((e) => StoreSlotModel.fromJson(e))
          .toList(),
      isUnderConstruction: json['is_under_construction'] as bool? ?? false,
      startedAt: json['started_at'] != null ? DateTime.tryParse(json['started_at'].toString()) : null,
      finishAt: json['finish_at'] != null ? DateTime.tryParse(json['finish_at'].toString()) : null,
      constructionProgress: (json['construction_progress'] as num?)?.toDouble() ?? 1.0,
    );
  }
}
