import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/models/mutation/entity_patch.dart';
import 'package:hard_kapitalizm/features/factory/data/factory_provider.dart';
import 'package:hard_kapitalizm/features/farm/data/farm_provider.dart';
import 'package:hard_kapitalizm/features/field/data/field_provider.dart';
import 'package:hard_kapitalizm/features/mine/data/mine_provider.dart';

/// Keeps production list-card stock aggregates aligned with the already-patched
/// detail state. The central dispatcher updates production inventory rows in
/// detail providers, but list cards also cache input/output totals. Without this
/// bridge the detail page can be correct while the list page remains stale until
/// a route/full refresh.
class ProductionInventoryListPatchService {
  ProductionInventoryListPatchService(this._ref);

  final Ref _ref;

  void apply(EntityPatch patch) {
    if (patch.entity != 'production_inventory') return;

    final ownerKind = patch.changes['owner_kind']?.toString() ?? '';
    final ownerId = patch.changes['owner_id']?.toString() ?? '';
    if (ownerKind.isEmpty || ownerId.isEmpty) return;

    switch (ownerKind) {
      case 'factory':
        _syncFactory(ownerId);
        break;
      case 'mine':
        _syncMine(ownerId);
        break;
      case 'field':
        _syncField(ownerId);
        break;
      case 'farm':
        _syncFarm(ownerId);
        break;
    }
  }

  void _syncFactory(String factoryId) {
    final detail = _ref.read(factoryDetailProvider(factoryId)).value;
    final list = _ref.read(factoryListProvider).value;
    if (detail == null || list == null) return;

    final index = list.indexWhere((item) => item.factory.id == factoryId);
    if (index < 0) return;

    var inputTotal = 0;
    var outputTotal = 0;
    for (final inventory in detail.inventories) {
      if (inventory.inventoryType == 'input') {
        inputTotal += inventory.quantity;
      } else if (inventory.inventoryType == 'output') {
        outputTotal += inventory.quantity;
      }
    }

    _ref.read(factoryListProvider.notifier).replaceFactory(
          list[index].copyWith(
            inputStockQuantity: inputTotal,
            outputStockQuantity: outputTotal,
          ),
        );
  }

  void _syncMine(String mineId) {
    final detail = _ref.read(mineDetailProvider(mineId)).value;
    final list = _ref.read(mineListProvider).value;
    if (detail == null || list == null) return;

    final index = list.indexWhere((item) => item.mine.id == mineId);
    if (index < 0) return;

    var outputTotal = 0;
    for (final inventory in detail.inventories) {
      if (inventory.inventoryType == 'output') {
        outputTotal += inventory.quantity;
      }
    }

    _ref.read(mineListProvider.notifier).replaceMine(
          list[index].copyWith(outputStockQuantity: outputTotal),
        );
  }

  void _syncField(String fieldId) {
    final detail = _ref.read(fieldDetailProvider(fieldId)).value;
    final list = _ref.read(fieldListProvider).value;
    if (detail == null || list == null) return;

    final index = list.indexWhere((item) => item.field.id == fieldId);
    if (index < 0) return;

    var inputTotal = 0;
    var outputTotal = 0;
    for (final inventory in detail.inventories) {
      if (inventory.inventoryType == 'input') {
        inputTotal += inventory.quantity;
      } else if (inventory.inventoryType == 'output') {
        outputTotal += inventory.quantity;
      }
    }

    _ref.read(fieldListProvider.notifier).replaceField(
          list[index].copyWith(
            inputStockQuantity: inputTotal,
            outputStockQuantity: outputTotal,
          ),
        );
  }

  void _syncFarm(String farmId) {
    final detail = _ref.read(farmDetailProvider(farmId)).value;
    final list = _ref.read(farmListProvider).value;
    if (detail == null || list == null) return;

    final index = list.indexWhere((item) => item.farm.id == farmId);
    if (index < 0) return;

    var inputTotal = 0;
    var outputTotal = 0;
    for (final inventory in detail.inventories) {
      if (inventory.inventoryType == 'input') {
        inputTotal += inventory.quantity;
      } else if (inventory.inventoryType == 'output') {
        outputTotal += inventory.quantity;
      }
    }

    _ref.read(farmListProvider.notifier).replaceFarm(
          list[index].copyWith(
            inputStockQuantity: inputTotal,
            outputStockQuantity: outputTotal,
          ),
        );
  }
}

final productionInventoryListPatchServiceProvider =
    Provider<ProductionInventoryListPatchService>(
  ProductionInventoryListPatchService.new,
);
