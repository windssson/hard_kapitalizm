import 'package:hard_kapitalizm/core/models/product_model.dart';
import 'package:hard_kapitalizm/core/models/production_slot_model.dart';
import 'package:hard_kapitalizm/features/mine/models/mine_model.dart';

const _copyWithUnset = Object();

class MineTypeDetailModel {
  final String id;
  final String name;
  final String icon;
  final List<String> acceptedProductIds;
  final int maxSlotCount;
  final int outputCapacity;
  final int cost;
  final int constructionTimeMinutes;

  const MineTypeDetailModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.acceptedProductIds,
    required this.maxSlotCount,
    required this.outputCapacity,
    required this.cost,
    required this.constructionTimeMinutes,
  });

  factory MineTypeDetailModel.fromJson(Map<String, dynamic> json) {
    return MineTypeDetailModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      icon: (json['icon'] ?? 'mine.webp').toString(),
      acceptedProductIds: _parseAcceptedProductIds(json['accepted_product_ids']),
      maxSlotCount: (json['max_slot_count'] as num?)?.toInt() ?? 3,
      outputCapacity: (json['output_capacity'] as num?)?.toInt() ?? 0,
      cost: (json['cost'] as num?)?.toInt() ?? 0,
      constructionTimeMinutes:
          (json['construction_time_minutes'] as num?)?.toInt() ?? 0,
    );
  }

  static List<String> _parseAcceptedProductIds(dynamic rawValue) {
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
}

class MineProductionInventoryModel {
  final String id;
  final String ownerKind;
  final String ownerId;
  final String inventoryType;
  final String productId;
  final String brandId;
  final int qualityLevel;
  final int quantity;
  final double pendingQuantity;
  final double cost;
  final double unitVolume;
  final ProductModel? product;

  const MineProductionInventoryModel({
    required this.id,
    required this.ownerKind,
    required this.ownerId,
    required this.inventoryType,
    required this.productId,
    required this.brandId,
    required this.qualityLevel,
    required this.quantity,
    required this.pendingQuantity,
    required this.cost,
    required this.unitVolume,
    required this.product,
  });

  bool get isOutput => inventoryType == 'output';

  factory MineProductionInventoryModel.fromJson(Map<String, dynamic> json) {
    final productJson = json['product'] is Map
        ? Map<String, dynamic>.from(json['product'] as Map)
        : null;

    return MineProductionInventoryModel(
      id: (json['id'] ?? '').toString(),
      ownerKind: (json['owner_kind'] ?? '').toString(),
      ownerId: (json['owner_id'] ?? '').toString(),
      inventoryType: (json['inventory_type'] ?? '').toString(),
      productId: (json['product_id'] ?? '').toString(),
      brandId:
          (json['brand_id'] ?? ProductionSlotContractModel.zeroBrandId)
              .toString(),
      qualityLevel: (json['quality_level'] as num?)?.toInt() ?? 0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      pendingQuantity: (json['pending_quantity'] as num?)?.toDouble() ?? 0,
      cost: (json['cost'] as num?)?.toDouble() ?? 0,
      unitVolume:
          (json['unit_volume'] as num?)?.toDouble() ??
          (productJson?['birim_hacim'] as num?)?.toDouble() ??
          0,
      product: productJson != null
          ? ProductModel.fromJson(productJson)
          : null,
    );
  }

  MineProductionInventoryModel copyWith({
    String? id,
    String? ownerKind,
    String? ownerId,
    String? inventoryType,
    String? productId,
    String? brandId,
    int? qualityLevel,
    int? quantity,
    double? pendingQuantity,
    double? cost,
    double? unitVolume,
    Object? product = _copyWithUnset,
  }) {
    return MineProductionInventoryModel(
      id: id ?? this.id,
      ownerKind: ownerKind ?? this.ownerKind,
      ownerId: ownerId ?? this.ownerId,
      inventoryType: inventoryType ?? this.inventoryType,
      productId: productId ?? this.productId,
      brandId: brandId ?? this.brandId,
      qualityLevel: qualityLevel ?? this.qualityLevel,
      quantity: quantity ?? this.quantity,
      pendingQuantity: pendingQuantity ?? this.pendingQuantity,
      cost: cost ?? this.cost,
      unitVolume: unitVolume ?? this.unitVolume,
      product: identical(product, _copyWithUnset)
          ? this.product
          : product as ProductModel?,
    );
  }
}

class MineDetailModel {
  final MineModel mine;
  final MineTypeDetailModel mineType;
  final String cityName;

  /// Legacy slot-1 mirror retained while older consumers are removed.
  final ProductModel? product;

  /// Backend source of truth for mine production configuration.
  final List<ProductionSlotContractModel> productionSlots;
  final List<MineProductionInventoryModel> inventories;

  const MineDetailModel({
    required this.mine,
    required this.mineType,
    required this.cityName,
    required this.product,
    this.productionSlots = const [],
    required this.inventories,
  });

  List<ProductionSlotContractModel> get configuredSlots => productionSlots
      .where((slot) => slot.isConfigured)
      .toList(growable: false);

  List<ProductionSlotContractModel> get activeConfiguredSlots => configuredSlots
      .where((slot) => slot.isActive)
      .toList(growable: false);

  bool get hasConfiguredProduction => configuredSlots.isNotEmpty;
  bool get hasActiveProduction => activeConfiguredSlots.isNotEmpty;

  Set<String> get _outputConfigKeys {
    final keys = <String>{
      for (final slot in configuredSlots)
        '${slot.productId}|${slot.qualityLevel}|${slot.brandId}',
    };
    if (keys.isEmpty && product != null && mine.productId != null) {
      keys.add('${mine.productId}|${mine.qualityLevel}|${mine.brandId}');
    }
    return keys;
  }

  List<MineProductionInventoryModel> get outputInventories => inventories
      .where(
        (inventory) =>
            inventory.isOutput &&
            _outputConfigKeys.contains(
              '${inventory.productId}|${inventory.qualityLevel}|${inventory.brandId}',
            ),
      )
      .toList()
    ..sort((a, b) {
      final byProduct = a.productId.compareTo(b.productId);
      if (byProduct != 0) return byProduct;
      return b.quantity.compareTo(a.quantity);
    });

  int get totalOutputQuantity =>
      outputInventories.fold(0, (sum, item) => sum + item.quantity);

  MineDetailModel copyWith({
    MineModel? mine,
    MineTypeDetailModel? mineType,
    String? cityName,
    Object? product = _copyWithUnset,
    List<ProductionSlotContractModel>? productionSlots,
    List<MineProductionInventoryModel>? inventories,
  }) {
    return MineDetailModel(
      mine: mine ?? this.mine,
      mineType: mineType ?? this.mineType,
      cityName: cityName ?? this.cityName,
      product: identical(product, _copyWithUnset)
          ? this.product
          : product as ProductModel?,
      productionSlots: productionSlots ?? this.productionSlots,
      inventories: inventories ?? this.inventories,
    );
  }
}
