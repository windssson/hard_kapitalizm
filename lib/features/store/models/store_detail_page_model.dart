import 'package:hard_kapitalizm/core/models/building_boost_model.dart';
import 'package:hard_kapitalizm/core/models/building_upgrade_model.dart';
import 'package:hard_kapitalizm/features/auth/models/player_model.dart';
import 'package:hard_kapitalizm/features/store/models/store_model.dart';
import 'package:hard_kapitalizm/features/store/models/store_sale_result_model.dart';

class StoreDetailPageChangedModel {
  final PlayerModel? player;
  final bool historyDirty;
  final bool performanceDirty;

  const StoreDetailPageChangedModel({
    required this.player,
    required this.historyDirty,
    required this.performanceDirty,
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
    );
  }

  StoreDetailPageChangedModel copyWith({
    PlayerModel? player,
    bool? historyDirty,
    bool? performanceDirty,
  }) {
    return StoreDetailPageChangedModel(
      player: player ?? this.player,
      historyDirty: historyDirty ?? this.historyDirty,
      performanceDirty: performanceDirty ?? this.performanceDirty,
    );
  }
}

class StoreDetailPageModel {
  final bool success;
  final StoreModel store;
  final BuildingBoostModel? activeBoost;
  final BuildingUpgradeModel? activeUpgrade;
  final StoreSaleResultModel? saleResult;
  final StoreDetailPageChangedModel changed;

  const StoreDetailPageModel({
    required this.success,
    required this.store,
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

    return StoreDetailPageModel(
      success: json['success'] as bool? ?? false,
      store: StoreModel.fromJson(
        storeJson is Map<String, dynamic>
            ? storeJson
            : Map<String, dynamic>.from(storeJson as Map),
      ),
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
    BuildingBoostModel? activeBoost,
    BuildingUpgradeModel? activeUpgrade,
    StoreSaleResultModel? saleResult,
    StoreDetailPageChangedModel? changed,
  }) {
    return StoreDetailPageModel(
      success: success ?? this.success,
      store: store ?? this.store,
      activeBoost: activeBoost ?? this.activeBoost,
      activeUpgrade: activeUpgrade ?? this.activeUpgrade,
      saleResult: saleResult ?? this.saleResult,
      changed: changed ?? this.changed,
    );
  }
}
