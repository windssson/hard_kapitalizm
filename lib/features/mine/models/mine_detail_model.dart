import 'package:hard_kapitalizm/core/models/product_model.dart';
import 'package:hard_kapitalizm/features/mine/models/mine_model.dart';

class MineTypeDetailModel {
  final String id;
  final String name;
  final String icon;
  final List<String> acceptedProductIds;
  final int outputCapacity;

  const MineTypeDetailModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.acceptedProductIds,
    required this.outputCapacity,
  });

  factory MineTypeDetailModel.fromJson(Map<String, dynamic> json) {
    return MineTypeDetailModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      icon: (json['icon'] ?? 'mine.webp').toString(),
      acceptedProductIds: _parseAcceptedProductIds(json['accepted_product_ids']),
      outputCapacity: (json['output_capacity'] as num?)?.toInt() ?? 0,
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
  final int qualityLevel;
  final int quantity;
  final double pendingQuantity;
  final double cost;
  final ProductModel? product;

  const MineProductionInventoryModel({
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

  bool get isOutput => inventoryType == 'output';

  factory MineProductionInventoryModel.fromJson(Map<String, dynamic> json) {
    return MineProductionInventoryModel(
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

class MineDetailModel {
  final MineModel mine;
  final MineTypeDetailModel mineType;
  final String cityName;
  final ProductModel? product;
  final List<MineProductionInventoryModel> inventories;

  const MineDetailModel({
    required this.mine,
    required this.mineType,
    required this.cityName,
    required this.product,
    required this.inventories,
  });

  List<MineProductionInventoryModel> get outputInventories =>
      inventories
          .where(
            (e) =>
                e.isOutput &&
                product != null &&
                e.productId == product!.id &&
                e.qualityLevel == mine.qualityLevel,
          )
          .toList()
        ..sort((a, b) => a.productId.compareTo(b.productId));
}
