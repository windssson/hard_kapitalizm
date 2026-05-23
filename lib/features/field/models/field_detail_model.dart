import 'package:hard_kapitalizm/core/models/product_model.dart';
import 'package:hard_kapitalizm/features/field/models/field_model.dart';

class FieldTypeDetailModel {
  final String id;
  final String name;
  final String icon;
  final List<String> acceptedProductIds;
  final int maxSlotCount;
  final int inputCapacity;
  final int outputCapacity;
  final int slotCapacity;

  const FieldTypeDetailModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.acceptedProductIds,
    required this.maxSlotCount,
    required this.inputCapacity,
    required this.outputCapacity,
    required this.slotCapacity,
  });

  factory FieldTypeDetailModel.fromJson(Map<String, dynamic> json) {
    return FieldTypeDetailModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      icon: (json['icon'] ?? 'field.webp').toString(),
      acceptedProductIds: _parseAcceptedProductIds(json['accepted_product_ids']),
      maxSlotCount: (json['max_slot_count'] as num?)?.toInt() ?? 5,
      inputCapacity: (json['input_capacity'] as num?)?.toInt() ?? 0,
      outputCapacity: (json['output_capacity'] as num?)?.toInt() ?? 0,
      slotCapacity: (json['slot_capacity'] as num?)?.toInt() ?? 0,
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

class ProductionSlotModel {
  final String id;
  final String ownerKind;
  final String ownerId;
  final int slotIndex;
  final String? productId;
  final int qualityLevel;
  final double boostMultiplier;
  final bool isActive;
  final ProductModel? product;

  const ProductionSlotModel({
    required this.id,
    required this.ownerKind,
    required this.ownerId,
    required this.slotIndex,
    required this.productId,
    required this.qualityLevel,
    required this.boostMultiplier,
    required this.isActive,
    required this.product,
  });

  bool get isEmpty => productId == null || productId!.isEmpty;

  factory ProductionSlotModel.fromJson(Map<String, dynamic> json) {
    return ProductionSlotModel(
      id: (json['id'] ?? '').toString(),
      ownerKind: (json['owner_kind'] ?? '').toString(),
      ownerId: (json['owner_id'] ?? '').toString(),
      slotIndex: (json['slot_index'] as num?)?.toInt() ?? 0,
      productId: json['product_id'] as String?,
      qualityLevel: (json['quality_level'] as num?)?.toInt() ?? 0,
      boostMultiplier: (json['boost_multiplier'] as num?)?.toDouble() ?? 1,
      isActive: json['is_active'] as bool? ?? true,
      product: json['product'] != null
          ? ProductModel.fromJson(Map<String, dynamic>.from(json['product'] as Map))
          : null,
    );
  }
}

class ProductionInventoryModel {
  final String id;
  final String ownerKind;
  final String ownerId;
  final String inventoryType;
  final String productId;
  final int qualityLevel;
  final int quantity;
  final double pendingQuantity;
  final double cost;
  final ProductModel? product;

  const ProductionInventoryModel({
    required this.id,
    required this.ownerKind,
    required this.ownerId,
    required this.inventoryType,
    required this.productId,
    required this.qualityLevel,
    required this.quantity,
    required this.pendingQuantity,
    required this.cost,
    required this.product,
  });

  bool get isInput => inventoryType == 'input';
  bool get isOutput => inventoryType == 'output';

  factory ProductionInventoryModel.fromJson(Map<String, dynamic> json) {
    return ProductionInventoryModel(
      id: (json['id'] ?? '').toString(),
      ownerKind: (json['owner_kind'] ?? '').toString(),
      ownerId: (json['owner_id'] ?? '').toString(),
      inventoryType: (json['inventory_type'] ?? '').toString(),
      productId: (json['product_id'] ?? '').toString(),
      qualityLevel: (json['quality_level'] as num?)?.toInt() ?? 0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      pendingQuantity: (json['pending_quantity'] as num?)?.toDouble() ?? 0,
      cost: (json['cost'] as num?)?.toDouble() ?? 0,
      product: json['product'] != null
          ? ProductModel.fromJson(Map<String, dynamic>.from(json['product'] as Map))
          : null,
    );
  }
}

class FieldDetailModel {
  final FieldModel field;
  final FieldTypeDetailModel fieldType;
  final String cityName;
  final List<ProductionSlotModel> slots;
  final List<ProductionInventoryModel> inventories;

  const FieldDetailModel({
    required this.field,
    required this.fieldType,
    required this.cityName,
    required this.slots,
    required this.inventories,
  });

  Set<String> get _activeInputProductIds {
    final ids = <String>{};
    for (final slot in slots) {
      final product = slot.product;
      if (slot.isEmpty || product == null) continue;
      if ((product.hammadde1Id ?? '').isNotEmpty) ids.add(product.hammadde1Id!);
      if ((product.hammadde2Id ?? '').isNotEmpty) ids.add(product.hammadde2Id!);
      if ((product.hammadde3Id ?? '').isNotEmpty) ids.add(product.hammadde3Id!);
    }
    return ids;
  }

  List<ProductionInventoryModel> get inputInventories =>
      inventories
          .where(
            (e) => e.isInput && _activeInputProductIds.contains(e.productId),
          )
          .toList()
        ..sort((a, b) => a.productId.compareTo(b.productId));

  List<ProductionInventoryModel> get outputInventories =>
      inventories
          .where(
            (e) => e.isOutput && slots.any(
              (slot) =>
                  !slot.isEmpty &&
                  slot.productId == e.productId &&
                  slot.qualityLevel == e.qualityLevel,
            ),
          )
          .toList()
        ..sort((a, b) => a.productId.compareTo(b.productId));
}
