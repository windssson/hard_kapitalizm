import 'package:hard_kapitalizm/core/models/product_model.dart';

class StoreTypeModel {
  final String id;
  final String name;
  final String icon;
  final List<String> acceptedProductIds;
  final int cost;
  final int requiredLevel;
  final int constructionTimeMinutes;

  StoreTypeModel({
    required this.id,
    required this.name,
    required this.icon,
    this.acceptedProductIds = const [],
    this.cost = 0,
    this.requiredLevel = 1,
    this.constructionTimeMinutes = 30,
  });

  factory StoreTypeModel.fromJson(Map<String, dynamic> json) {
    return StoreTypeModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      icon: (json['icon'] ?? '').toString(),
      acceptedProductIds: _parseAcceptedProductIds(json['accepted_product_ids']),
      cost: (json['cost'] as num?)?.toInt() ?? 0,
      requiredLevel: (json['required_level'] as num?)?.toInt() ?? 1,
      constructionTimeMinutes: (json['construction_time_minutes'] as num?)?.toInt() ?? 30,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'icon': icon,
    'accepted_product_ids': acceptedProductIds,
    'cost': cost,
    'required_level': requiredLevel,
    'construction_time_minutes': constructionTimeMinutes,
  };

  StoreTypeModel copyWith({
    String? id,
    String? name,
    String? icon,
    List<String>? acceptedProductIds,
    int? cost,
    int? requiredLevel,
    int? constructionTimeMinutes,
  }) {
    return StoreTypeModel(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      acceptedProductIds: acceptedProductIds ?? this.acceptedProductIds,
      cost: cost ?? this.cost,
      requiredLevel: requiredLevel ?? this.requiredLevel,
      constructionTimeMinutes:
          constructionTimeMinutes ?? this.constructionTimeMinutes,
    );
  }
}

List<String> _parseAcceptedProductIds(dynamic rawValue) {
  if (rawValue == null) return const [];

  final cleaned = rawValue
      .toString()
      .replaceAll('[', '')
      .replaceAll(']', '')
      .replaceAll('{', '')
      .replaceAll('}', '')
      .replaceAll('"', '')
      .replaceAll("'", '');

  return cleaned
      .split(',')
      .map((e) => e.trim().toUpperCase())
      .where((e) => e.isNotEmpty)
      .toList();
}

class StoreSummaryModel {
  final int totalQuantity;
  final int totalCapacity;
  final int pendingQuantity;
  final int availableCapacity;
  final double usedCapacityRatio;
  // Fractional sales carried over until they accumulate to a whole sale.
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

  StoreSummaryModel copyWith({
    int? totalQuantity,
    int? totalCapacity,
    int? pendingQuantity,
    int? availableCapacity,
    double? usedCapacityRatio,
    double? pendingSaleTotal,
    double? totalStockCostValue,
    double? totalStockSaleValue,
  }) {
    return StoreSummaryModel(
      totalQuantity: totalQuantity ?? this.totalQuantity,
      totalCapacity: totalCapacity ?? this.totalCapacity,
      pendingQuantity: pendingQuantity ?? this.pendingQuantity,
      availableCapacity: availableCapacity ?? this.availableCapacity,
      usedCapacityRatio: usedCapacityRatio ?? this.usedCapacityRatio,
      pendingSaleTotal: pendingSaleTotal ?? this.pendingSaleTotal,
      totalStockCostValue: totalStockCostValue ?? this.totalStockCostValue,
      totalStockSaleValue: totalStockSaleValue ?? this.totalStockSaleValue,
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
  // Fractional sale carry-over for this slot. This is not stock in transit.
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
    final productJson = json['product'] is Map<String, dynamic>
        ? json['product'] as Map<String, dynamic>
        : json['product'] is Map
            ? Map<String, dynamic>.from(json['product'] as Map)
            : null;
    
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

  StoreSlotModel copyWith({
    String? id,
    String? storeId,
    int? slotIndex,
    String? productId,
    String? productName,
    String? productIcon,
    int? quantity,
    int? pendingQuantity,
    int? qualityLevel,
    double? price,
    double? cost,
    int? capacity,
    double? boostMultiplier,
    double? pendingSale,
    bool? isActive,
    bool? isEmpty,
    double? usedCapacityRatio,
    ProductModel? product,
  }) {
    return StoreSlotModel(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      slotIndex: slotIndex ?? this.slotIndex,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productIcon: productIcon ?? this.productIcon,
      quantity: quantity ?? this.quantity,
      pendingQuantity: pendingQuantity ?? this.pendingQuantity,
      qualityLevel: qualityLevel ?? this.qualityLevel,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      capacity: capacity ?? this.capacity,
      boostMultiplier: boostMultiplier ?? this.boostMultiplier,
      pendingSale: pendingSale ?? this.pendingSale,
      isActive: isActive ?? this.isActive,
      isEmpty: isEmpty ?? this.isEmpty,
      usedCapacityRatio: usedCapacityRatio ?? this.usedCapacityRatio,
      product: product ?? this.product,
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
  final int slotCapacity;
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
    required this.slotCapacity,
    required this.storeType,
    required this.summary,
    required this.slots,
    this.isUnderConstruction = false,
    this.startedAt,
    this.finishAt,
    this.constructionProgress = 1.0,
  });

  factory StoreModel.fromJson(Map<String, dynamic> json) {
    final cityJson = json['city'] is Map<String, dynamic>
        ? json['city'] as Map<String, dynamic>
        : json['city'] is Map
            ? Map<String, dynamic>.from(json['city'] as Map)
            : null;
    final storeTypeJson = json['store_type'] is Map<String, dynamic>
        ? json['store_type'] as Map<String, dynamic>
        : json['store_type'] is Map
            ? Map<String, dynamic>.from(json['store_type'] as Map)
            : null;
    final summaryJson = json['summary'] is Map<String, dynamic>
        ? json['summary'] as Map<String, dynamic>
        : json['summary'] is Map
            ? Map<String, dynamic>.from(json['summary'] as Map)
            : <String, dynamic>{};
    final slotsJson = (json['slots'] as List? ?? const []);

    return StoreModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      cityId:
          json['city_id']?.toString().isNotEmpty == true
              ? json['city_id']?.toString()
              : cityJson?['id']?.toString(),
      cityName:
          json['city_name']?.toString().isNotEmpty == true
              ? json['city_name']?.toString()
              : cityJson?['name']?.toString(),
      level: (json['level'] as num?)?.toInt() ?? 1,
      isActive: json['is_active'] as bool? ?? true,
      currentSlotCount: (json['current_slot_count'] as num?)?.toInt() ?? 0,
      maxSlotCount: (json['max_slot_count'] as num?)?.toInt() ?? 0,
      slotCapacity: (json['slot_capacity'] as num?)?.toInt() ?? 0,
      storeType: storeTypeJson != null
          ? StoreTypeModel.fromJson(storeTypeJson)
          : StoreTypeModel(id: '', name: '', icon: ''),
      summary: StoreSummaryModel.fromJson(summaryJson),
      slots: slotsJson
          .whereType<Map>()
          .map((e) => StoreSlotModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      isUnderConstruction: json['is_under_construction'] as bool? ?? false,
      startedAt: json['started_at'] != null ? DateTime.tryParse(json['started_at'].toString()) : null,
      finishAt: json['finish_at'] != null ? DateTime.tryParse(json['finish_at'].toString()) : null,
      constructionProgress: (json['construction_progress'] as num?)?.toDouble() ?? 1.0,
    );
  }

  StoreModel copyWith({
    String? id,
    String? name,
    String? cityId,
    String? cityName,
    int? level,
    bool? isActive,
    int? currentSlotCount,
    int? maxSlotCount,
    int? slotCapacity,
    StoreTypeModel? storeType,
    StoreSummaryModel? summary,
    List<StoreSlotModel>? slots,
    bool? isUnderConstruction,
    DateTime? startedAt,
    DateTime? finishAt,
    double? constructionProgress,
  }) {
    return StoreModel(
      id: id ?? this.id,
      name: name ?? this.name,
      cityId: cityId ?? this.cityId,
      cityName: cityName ?? this.cityName,
      level: level ?? this.level,
      isActive: isActive ?? this.isActive,
      currentSlotCount: currentSlotCount ?? this.currentSlotCount,
      maxSlotCount: maxSlotCount ?? this.maxSlotCount,
      slotCapacity: slotCapacity ?? this.slotCapacity,
      storeType: storeType ?? this.storeType,
      summary: summary ?? this.summary,
      slots: slots ?? this.slots,
      isUnderConstruction: isUnderConstruction ?? this.isUnderConstruction,
      startedAt: startedAt ?? this.startedAt,
      finishAt: finishAt ?? this.finishAt,
      constructionProgress: constructionProgress ?? this.constructionProgress,
    );
  }
}
