import 'package:hard_kapitalizm/core/models/product_model.dart';
import 'package:hard_kapitalizm/features/factory/models/factory_model.dart';

class FactoryTypeDetailModel {
  final String id;
  final String name;
  final String icon;
  final List<String> acceptedProductIds;
  final int inputCapacity;
  final int outputCapacity;
  final int cost;
  final int constructionTimeMinutes;

  const FactoryTypeDetailModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.acceptedProductIds,
    required this.inputCapacity,
    required this.outputCapacity,
    required this.cost,
    required this.constructionTimeMinutes,
  });

  factory FactoryTypeDetailModel.fromJson(Map<String, dynamic> json) {
    return FactoryTypeDetailModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      icon: (json['icon'] ?? 'factory.webp').toString(),
      acceptedProductIds: _parseAcceptedProductIds(json['accepted_product_ids']),
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

class FactoryProductionInventoryModel {
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

  const FactoryProductionInventoryModel({
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

  factory FactoryProductionInventoryModel.fromJson(Map<String, dynamic> json) {
    return FactoryProductionInventoryModel(
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
          ? ProductModel.fromJson(
              Map<String, dynamic>.from(json['product'] as Map),
            )
          : null,
    );
  }
}

class FactoryDetailModel {
  final FactoryModel factory;
  final FactoryTypeDetailModel factoryType;
  final String cityName;
  final ProductModel? product;
  final List<FactoryProductionInventoryModel> inventories;

  const FactoryDetailModel({
    required this.factory,
    required this.factoryType,
    required this.cityName,
    required this.product,
    required this.inventories,
  });

  Set<String> get _activeInputProductIds {
    final currentProduct = product;
    if (currentProduct == null) return const <String>{};

    return {
      if ((currentProduct.hammadde1Id ?? '').isNotEmpty) currentProduct.hammadde1Id!,
      if ((currentProduct.hammadde2Id ?? '').isNotEmpty) currentProduct.hammadde2Id!,
      if ((currentProduct.hammadde3Id ?? '').isNotEmpty) currentProduct.hammadde3Id!,
    };
  }

  List<FactoryProductionInventoryModel> get inputInventories =>
      inventories
          .where(
            (e) => e.isInput && _activeInputProductIds.contains(e.productId),
          )
          .toList()
        ..sort((a, b) => a.productId.compareTo(b.productId));

  List<FactoryProductionInventoryModel> get outputInventories =>
      inventories
          .where(
            (e) =>
                e.isOutput &&
                product != null &&
                e.productId == product!.id &&
                e.qualityLevel == factory.qualityLevel,
          )
          .toList()
        ..sort((a, b) => a.productId.compareTo(b.productId));

  List<FactoryProductionInventoryModel> get orphanInputInventories =>
      inventories
          .where(
            (e) =>
                e.isInput &&
                !_activeInputProductIds.contains(e.productId) &&
                (e.quantity > 0 || e.pendingQuantity > 0),
          )
          .toList()
        ..sort((a, b) => a.productId.compareTo(b.productId));
}
