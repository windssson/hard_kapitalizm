import 'package:hard_kapitalizm/core/models/product_model.dart';
import 'package:hard_kapitalizm/features/farm/models/farm_model.dart';

class FarmTypeDetailModel {
  final String id;
  final String name;
  final String icon;
  final List<String> acceptedProductIds;
  final int maxSlotCount;
  final int inputCapacity;
  final int outputCapacity;
  final int cost;
  final int constructionTimeMinutes;

  const FarmTypeDetailModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.acceptedProductIds,
    required this.maxSlotCount,
    required this.inputCapacity,
    required this.outputCapacity,
    required this.cost,
    required this.constructionTimeMinutes,
  });

  factory FarmTypeDetailModel.fromJson(Map<String, dynamic> json) {
    return FarmTypeDetailModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      icon: (json['icon'] ?? 'farm.webp').toString(),
      acceptedProductIds: _parseAcceptedProductIds(json['accepted_product_ids']),
      maxSlotCount: (json['max_slot_count'] as num?)?.toInt() ?? 5,
      inputCapacity: (json['input_capacity'] as num?)?.toInt() ?? 0,
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

class FarmProductionSlotModel {
  final String id;
  final String ownerKind;
  final String ownerId;
  final int slotIndex;
  final String? productId;
  final String brandId;
  final int qualityLevel;
  final double boostMultiplier;
  final bool isActive;
  final ProductModel? product;

  const FarmProductionSlotModel({
    required this.id,
    required this.ownerKind,
    required this.ownerId,
    required this.slotIndex,
    required this.productId,
    required this.brandId,
    required this.qualityLevel,
    required this.boostMultiplier,
    required this.isActive,
    required this.product,
  });

  bool get isEmpty => productId == null || productId!.isEmpty;

  factory FarmProductionSlotModel.fromJson(Map<String, dynamic> json) {
    return FarmProductionSlotModel(
      id: (json['id'] ?? '').toString(),
      ownerKind: (json['owner_kind'] ?? '').toString(),
      ownerId: (json['owner_id'] ?? '').toString(),
      slotIndex: (json['slot_index'] as num?)?.toInt() ?? 0,
      productId: json['product_id'] as String?,
      brandId:
          (json['brand_id'] ?? '00000000-0000-0000-0000-000000000000')
              .toString(),
      qualityLevel: (json['quality_level'] as num?)?.toInt() ?? 0,
      boostMultiplier: (json['boost_multiplier'] as num?)?.toDouble() ?? 1,
      isActive: json['is_active'] as bool? ?? true,
      product: json['product'] != null
          ? ProductModel.fromJson(Map<String, dynamic>.from(json['product'] as Map))
          : null,
    );
  }
}

class FarmProductionInventoryModel {
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

  const FarmProductionInventoryModel({
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

  bool get isInput => inventoryType == 'input';
  bool get isOutput => inventoryType == 'output';

  factory FarmProductionInventoryModel.fromJson(Map<String, dynamic> json) {
    final productJson = json['product'] is Map
        ? Map<String, dynamic>.from(json['product'] as Map)
        : null;

    return FarmProductionInventoryModel(
      id: (json['id'] ?? '').toString(),
      ownerKind: (json['owner_kind'] ?? '').toString(),
      ownerId: (json['owner_id'] ?? '').toString(),
      inventoryType: (json['inventory_type'] ?? '').toString(),
      productId: (json['product_id'] ?? '').toString(),
      brandId:
          (json['brand_id'] ?? '00000000-0000-0000-0000-000000000000')
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
}

class FarmDetailModel {
  final FarmModel farm;
  final FarmTypeDetailModel farmType;
  final String cityName;
  final List<FarmProductionSlotModel> slots;
  final List<FarmProductionInventoryModel> inventories;

  const FarmDetailModel({
    required this.farm,
    required this.farmType,
    required this.cityName,
    required this.slots,
    required this.inventories,
  });

  Set<String> get _activeInputProductIds {
    final ids = <String>{};
    for (final slot in slots) {
      final product = slot.product;
      if (slot.isEmpty || product == null) continue;
      ids.addAll(product.inputProductIds);
    }
    return ids;
  }

  List<FarmProductionInventoryModel> get inputInventories =>
      inventories
          .where(
            (e) => e.isInput && _activeInputProductIds.contains(e.productId),
          )
          .toList()
        ..sort((a, b) => a.productId.compareTo(b.productId));

  List<FarmProductionInventoryModel> get orphanInputInventories =>
      inventories
          .where(
            (e) =>
                e.isInput &&
                !_activeInputProductIds.contains(e.productId) &&
                (e.quantity > 0 || e.pendingQuantity > 0),
          )
          .toList()
        ..sort((a, b) => a.productId.compareTo(b.productId));

  List<FarmProductionInventoryModel> get outputInventories =>
      inventories
          .where(
            (e) => e.isOutput && slots.any(
              (slot) =>
                  !slot.isEmpty &&
                  slot.productId == e.productId &&
                  slot.qualityLevel == e.qualityLevel &&
                  slot.brandId == e.brandId,
            ),
          )
          .toList()
        ..sort((a, b) => a.productId.compareTo(b.productId));
}
