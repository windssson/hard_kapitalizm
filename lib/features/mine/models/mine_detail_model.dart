import 'package:hard_kapitalizm/core/models/product_model.dart';
import 'package:hard_kapitalizm/features/mine/models/mine_model.dart';

class MineTypeDetailModel {
  final String id;
  final String name;
  final String icon;
  final List<String> acceptedProductIds;
  final int outputCapacity;
  final int cost;
  final int constructionTimeMinutes;

  const MineTypeDetailModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.acceptedProductIds,
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
                e.qualityLevel == mine.qualityLevel &&
                e.brandId == mine.brandId,
          )
          .toList()
        ..sort((a, b) => b.quantity.compareTo(a.quantity));

  int get totalOutputQuantity =>
      outputInventories.fold(0, (sum, item) => sum + item.quantity);
}
