import 'package:hard_kapitalizm/core/models/building_boost_model.dart';
import 'package:hard_kapitalizm/core/models/building_upgrade_model.dart';
import 'package:hard_kapitalizm/features/auth/models/player_model.dart';
import 'package:hard_kapitalizm/features/store/models/store_model.dart';
import 'package:hard_kapitalizm/features/store/models/store_sale_result_model.dart';

class StoreWarehouseSlotSummaryModel {
  final String id;
  final String productId;
  final String productName;
  final String? productIcon;
  final int qualityLevel;
  final String brandId;
  final int quantity;
  final double cost;

  const StoreWarehouseSlotSummaryModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productIcon,
    required this.qualityLevel,
    required this.brandId,
    required this.quantity,
    required this.cost,
  });

  factory StoreWarehouseSlotSummaryModel.fromJson(Map<String, dynamic> json) {
    return StoreWarehouseSlotSummaryModel(
      id: (json['id'] ?? '').toString(),
      productId: (json['product_id'] ?? '').toString(),
      productName: (json['product_name'] ?? 'Urun').toString(),
      productIcon: json['product_icon']?.toString(),
      qualityLevel: (json['quality_level'] as num?)?.toInt() ?? 0,
      brandId: (json['brand_id'] ?? '00000000-0000-0000-0000-000000000000')
          .toString(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      cost: (json['cost'] as num?)?.toDouble() ?? 0,
    );
  }
}

class StoreWarehouseSummaryModel {
  final String id;
  final String name;
  final double capacity;
  final double usedCapacity;
  final List<StoreWarehouseSlotSummaryModel> slots;

  const StoreWarehouseSummaryModel({
    required this.id,
    required this.name,
    required this.capacity,
    required this.usedCapacity,
    required this.slots,
  });

  factory StoreWarehouseSummaryModel.fromJson(Map<String, dynamic> json) {
    final slotsJson = (json['slots'] as List? ?? const []);
    return StoreWarehouseSummaryModel(
      id: (json['id'] ?? json['store_warehouse_id'] ?? '').toString(),
      name: (json['name'] ?? json['store_warehouse_name'] ?? 'Magaza Deposu')
          .toString(),
      capacity: (json['capacity'] as num?)?.toDouble() ??
          (json['store_warehouse_capacity'] as num?)?.toDouble() ??
          0,
      usedCapacity: (json['used_capacity'] as num?)?.toDouble() ??
          (json['store_warehouse_used_capacity'] as num?)?.toDouble() ??
          0,
      slots: slotsJson
          .whereType<Map>()
          .map(
            (slot) => StoreWarehouseSlotSummaryModel.fromJson(
              Map<String, dynamic>.from(slot),
            ),
          )
          .toList(),
    );
  }
}

class StoreDetailPageChangedModel {
  final PlayerModel? player;
  final bool historyDirty;
  final bool performanceDirty;
  final bool taxDirty;

  const StoreDetailPageChangedModel({
    required this.player,
    required this.historyDirty,
    required this.performanceDirty,
    required this.taxDirty,
  });

  factory StoreDetailPageChangedModel.fromJson(Map<String, dynamic> json) {
    final playerJson = json['player'];
    return StoreDetailPageChangedModel(
      player: playerJson is Map<String, dynamic>
          ? PlayerModel.fromJson(playerJson)
          : playerJson is Map
              ? PlayerModel.fromJson(Map<String, dynamic>.from(playerJson))
              : null,
      historyDirty: json['history_dirty'] as bool? ?? false,
      performanceDirty: json['performance_dirty'] as bool? ?? false,
      taxDirty: json['tax_dirty'] as bool? ?? false,
    );
  }

  StoreDetailPageChangedModel copyWith({
    PlayerModel? player,
    bool? historyDirty,
    bool? performanceDirty,
    bool? taxDirty,
  }) {
    return StoreDetailPageChangedModel(
      player: player ?? this.player,
      historyDirty: historyDirty ?? this.historyDirty,
      performanceDirty: performanceDirty ?? this.performanceDirty,
      taxDirty: taxDirty ?? this.taxDirty,
    );
  }
}

class StoreDetailPageModel {
  final bool success;
  final StoreModel store;
  final StoreWarehouseSummaryModel? storeWarehouse;
  final BuildingBoostModel? activeBoost;
  final BuildingUpgradeModel? activeUpgrade;
  final StoreSaleResultModel? saleResult;
  final StoreDetailPageChangedModel changed;

  const StoreDetailPageModel({
    required this.success,
    required this.store,
    required this.storeWarehouse,
    required this.activeBoost,
    required this.activeUpgrade,
    required this.saleResult,
    required this.changed,
  });

  factory StoreDetailPageModel.fromJson(Map<String, dynamic> json) {
    final storeJson = json['store'];
    if (storeJson == null) {
      throw Exception('Store detail page response missing store.');
    }

    final storeMap = storeJson is Map<String, dynamic>
        ? storeJson
        : Map<String, dynamic>.from(storeJson as Map);

    final rawWarehouse = json['store_warehouse'] ?? storeMap['store_warehouse'];

    return StoreDetailPageModel(
      success: json['success'] as bool? ?? false,
      store: StoreModel.fromJson(storeMap),
      storeWarehouse: rawWarehouse is Map<String, dynamic>
          ? StoreWarehouseSummaryModel.fromJson(rawWarehouse)
          : rawWarehouse is Map
              ? StoreWarehouseSummaryModel.fromJson(
                  Map<String, dynamic>.from(rawWarehouse),
                )
              : null,
      activeBoost: json['active_boost'] is Map<String, dynamic>
          ? BuildingBoostModel.fromJson(json['active_boost'])
          : json['active_boost'] is Map
              ? BuildingBoostModel.fromJson(
                  Map<String, dynamic>.from(json['active_boost'] as Map),
                )
              : null,
      activeUpgrade: json['active_upgrade'] is Map<String, dynamic>
          ? BuildingUpgradeModel.fromJson(json['active_upgrade'])
          : json['active_upgrade'] is Map
              ? BuildingUpgradeModel.fromJson(
                  Map<String, dynamic>.from(json['active_upgrade'] as Map),
                )
              : null,
      saleResult: json['sale_result'] is Map<String, dynamic>
          ? StoreSaleResultModel.fromJson(json['sale_result'])
          : json['sale_result'] is Map
              ? StoreSaleResultModel.fromJson(
                  Map<String, dynamic>.from(json['sale_result'] as Map),
                )
              : null,
      changed: StoreDetailPageChangedModel.fromJson(
        json['changed'] is Map<String, dynamic>
            ? json['changed']
            : Map<String, dynamic>.from((json['changed'] as Map?) ?? const {}),
      ),
    );
  }

  StoreDetailPageModel copyWith({
    bool? success,
    StoreModel? store,
    StoreWarehouseSummaryModel? storeWarehouse,
    BuildingBoostModel? activeBoost,
    BuildingUpgradeModel? activeUpgrade,
    StoreSaleResultModel? saleResult,
    StoreDetailPageChangedModel? changed,
  }) {
    return StoreDetailPageModel(
      success: success ?? this.success,
      store: store ?? this.store,
      storeWarehouse: storeWarehouse ?? this.storeWarehouse,
      activeBoost: activeBoost ?? this.activeBoost,
      activeUpgrade: activeUpgrade ?? this.activeUpgrade,
      saleResult: saleResult ?? this.saleResult,
      changed: changed ?? this.changed,
    );
  }
}
