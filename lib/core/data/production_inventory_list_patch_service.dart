import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/models/mutation/entity_patch.dart';
import 'package:hard_kapitalizm/features/factory/data/factory_provider.dart';
import 'package:hard_kapitalizm/features/farm/data/farm_provider.dart';
import 'package:hard_kapitalizm/features/field/data/field_provider.dart';
import 'package:hard_kapitalizm/features/mine/data/mine_provider.dart';

typedef ProductionInventoryQuantitySnapshot = ({
  String inventoryType,
  int quantity,
});

class ProductionInventoryTotals {
  final int inputQuantity;
  final int outputQuantity;

  const ProductionInventoryTotals({
    required this.inputQuantity,
    required this.outputQuantity,
  });
}

ProductionInventoryTotals calculateProductionInventoryTotals(
  Iterable<ProductionInventoryQuantitySnapshot> items,
) {
  var inputTotal = 0;
  var outputTotal = 0;
  for (final item in items) {
    if (item.inventoryType == 'input') {
      inputTotal += item.quantity;
    } else if (item.inventoryType == 'output') {
      outputTotal += item.quantity;
    }
  }
  return ProductionInventoryTotals(
    inputQuantity: inputTotal,
    outputQuantity: outputTotal,
  );
}

/// Small mutation-batch accumulator used by the targeted fallback path. A
/// single production mutation can emit several inventory patches for the same
/// owner (multiple inputs + output). When the detail snapshot is not loaded we
/// only need one list refetch for that feature, not one refetch per row patch.
class ProductionInventoryFallbackInvalidationAccumulator {
  final Set<String> _ownerKinds = <String>{};

  bool add(String ownerKind) {
    if (ownerKind.isEmpty) return false;
    return _ownerKinds.add(ownerKind);
  }

  Set<String> drain() {
    final snapshot = Set<String>.from(_ownerKinds);
    _ownerKinds.clear();
    return snapshot;
  }
}

/// Keeps production list-card stock aggregates aligned with the already-patched
/// detail state. The central dispatcher updates production inventory rows in
/// detail providers, but list cards also cache input/output totals. Without this
/// bridge the detail page can be correct while the list page remains stale until
/// a route/full refresh.
///
/// If the relevant detail snapshot is not loaded, a local aggregate cannot be
/// reconstructed safely from one sparse inventory patch. In that edge case only
/// the already-loaded feature list is invalidated as a targeted correctness
/// fallback; unloaded lists are left untouched. Repeated row patches from the
/// same synchronous mutation are collapsed into one fallback refresh per feature.
class ProductionInventoryListPatchService {
  ProductionInventoryListPatchService(this._ref);

  final Ref _ref;
  final ProductionInventoryFallbackInvalidationAccumulator
      _fallbackInvalidations = ProductionInventoryFallbackInvalidationAccumulator();
  bool _fallbackFlushScheduled = false;

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
    final list = _ref.read(factoryListProvider).value;
    if (list == null) return;

    final index = list.indexWhere((item) => item.factory.id == factoryId);
    if (index < 0) return;

    final detail = _ref.read(factoryDetailProvider(factoryId)).value;
    if (detail == null) {
      _scheduleFallbackInvalidation('factory');
      return;
    }

    final totals = calculateProductionInventoryTotals(
      detail.inventories.map(
        (inventory) => (
          inventoryType: inventory.inventoryType,
          quantity: inventory.quantity,
        ),
      ),
    );

    _ref.read(factoryListProvider.notifier).replaceFactory(
          list[index].copyWith(
            inputStockQuantity: totals.inputQuantity,
            outputStockQuantity: totals.outputQuantity,
          ),
        );
  }

  void _syncMine(String mineId) {
    final list = _ref.read(mineListProvider).value;
    if (list == null) return;

    final index = list.indexWhere((item) => item.mine.id == mineId);
    if (index < 0) return;

    final detail = _ref.read(mineDetailProvider(mineId)).value;
    if (detail == null) {
      _scheduleFallbackInvalidation('mine');
      return;
    }

    final totals = calculateProductionInventoryTotals(
      detail.inventories.map(
        (inventory) => (
          inventoryType: inventory.inventoryType,
          quantity: inventory.quantity,
        ),
      ),
    );

    _ref.read(mineListProvider.notifier).replaceMine(
          list[index].copyWith(outputStockQuantity: totals.outputQuantity),
        );
  }

  void _syncField(String fieldId) {
    final list = _ref.read(fieldListProvider).value;
    if (list == null) return;

    final index = list.indexWhere((item) => item.field.id == fieldId);
    if (index < 0) return;

    final detail = _ref.read(fieldDetailProvider(fieldId)).value;
    if (detail == null) {
      _scheduleFallbackInvalidation('field');
      return;
    }

    final totals = calculateProductionInventoryTotals(
      detail.inventories.map(
        (inventory) => (
          inventoryType: inventory.inventoryType,
          quantity: inventory.quantity,
        ),
      ),
    );

    _ref.read(fieldListProvider.notifier).replaceField(
          list[index].copyWith(
            inputStockQuantity: totals.inputQuantity,
            outputStockQuantity: totals.outputQuantity,
          ),
        );
  }

  void _syncFarm(String farmId) {
    final list = _ref.read(farmListProvider).value;
    if (list == null) return;

    final index = list.indexWhere((item) => item.farm.id == farmId);
    if (index < 0) return;

    final detail = _ref.read(farmDetailProvider(farmId)).value;
    if (detail == null) {
      _scheduleFallbackInvalidation('farm');
      return;
    }

    final totals = calculateProductionInventoryTotals(
      detail.inventories.map(
        (inventory) => (
          inventoryType: inventory.inventoryType,
          quantity: inventory.quantity,
        ),
      ),
    );

    _ref.read(farmListProvider.notifier).replaceFarm(
          list[index].copyWith(
            inputStockQuantity: totals.inputQuantity,
            outputStockQuantity: totals.outputQuantity,
          ),
        );
  }

  void _scheduleFallbackInvalidation(String ownerKind) {
    _fallbackInvalidations.add(ownerKind);
    if (_fallbackFlushScheduled) return;
    _fallbackFlushScheduled = true;

    Future<void>.microtask(() {
      _fallbackFlushScheduled = false;
      final ownerKinds = _fallbackInvalidations.drain();
      for (final kind in ownerKinds) {
        switch (kind) {
          case 'factory':
            _ref.invalidate(factoryListProvider);
            break;
          case 'mine':
            _ref.invalidate(mineListProvider);
            break;
          case 'field':
            _ref.invalidate(fieldListProvider);
            break;
          case 'farm':
            _ref.invalidate(farmListProvider);
            break;
        }
      }
    });
  }
}

final productionInventoryListPatchServiceProvider =
    Provider<ProductionInventoryListPatchService>(
  ProductionInventoryListPatchService.new,
);
