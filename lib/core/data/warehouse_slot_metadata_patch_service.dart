import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/data/static_catalog_provider.dart';
import 'package:hard_kapitalizm/core/models/mutation/entity_patch.dart';
import 'package:hard_kapitalizm/core/models/product_model.dart';
import 'package:hard_kapitalizm/features/store/data/store_provider.dart';
import 'package:hard_kapitalizm/features/warehouse/data/warehouse_provider.dart';
import 'package:hard_kapitalizm/features/warehouse/models/warehouse_model.dart';

WarehouseSlotModel enrichWarehouseSlotMetadata(
  WarehouseSlotModel slot,
  ProductModel product,
) {
  return slot.copyWith(
    productId: product.id,
    productName: product.urunAdi,
    productIcon: product.urunIconu,
    unitVolume: product.birimHacim,
  );
}

/// `warehouse_slot` patches intentionally stay small on the wire. Raw DB rows do
/// not include product display metadata, so a newly inserted/reused slot can
/// otherwise appear with a null name/icon and `unitVolume == 0` until a refetch.
///
/// This service enriches the already-applied local slot from the static catalog
/// without making another network request. If the static catalog is still
/// loading, the same patch is retried once that already-requested catalog future
/// resolves instead of leaving raw metadata in UI state.
class WarehouseSlotMetadataPatchService {
  WarehouseSlotMetadataPatchService(this._ref);

  final Ref _ref;

  void apply(EntityPatch patch) {
    if (patch.entity != 'warehouse_slot' ||
        patch.operation == PatchOperation.delete) {
      return;
    }

    final productId = patch.changes['product_id']?.toString().trim() ?? '';
    if (productId.isEmpty) return;

    final catalogs = _ref.read(staticCatalogsProvider).value;
    if (catalogs == null) {
      unawaited(_retryAfterCatalogLoad(patch));
      return;
    }

    final product = catalogs.products
        .where((item) => item.id == productId)
        .firstOrNull;
    if (product == null) return;

    var warehouseId = patch.changes['warehouse_id']?.toString().trim() ?? '';
    final warehouses = _ref.read(warehouseListProvider).value;
    if (warehouseId.isEmpty && warehouses != null) {
      for (final warehouse in warehouses) {
        if (warehouse.slots.any((slot) => slot.id == patch.id)) {
          warehouseId = warehouse.id;
          break;
        }
      }
    }
    if (warehouseId.isEmpty) {
      for (final activeId in WarehouseDetailNotifier.activeWarehouseIds) {
        final detail = _ref.read(warehouseDetailProvider(activeId)).value;
        if (detail?.slots.any((slot) => slot.id == patch.id) == true) {
          warehouseId = activeId;
          break;
        }
      }
    }
    if (warehouseId.isEmpty) return;

    if (warehouses != null) {
      final warehouseIndex = warehouses.indexWhere((w) => w.id == warehouseId);
      if (warehouseIndex >= 0) {
        final warehouse = warehouses[warehouseIndex];
        final slotIndex = warehouse.slots.indexWhere((slot) => slot.id == patch.id);
        if (slotIndex >= 0) {
          final slots = [...warehouse.slots];
          slots[slotIndex] = enrichWarehouseSlotMetadata(
            slots[slotIndex],
            product,
          );
          _ref
              .read(warehouseListProvider.notifier)
              .replaceWarehouse(warehouse.copyWith(slots: slots));
        }
      }
    }

    final detail = _ref.read(warehouseDetailProvider(warehouseId)).value;
    if (detail != null) {
      final slotIndex = detail.slots.indexWhere((slot) => slot.id == patch.id);
      if (slotIndex >= 0) {
        final slots = [...detail.slots];
        slots[slotIndex] = enrichWarehouseSlotMetadata(
          slots[slotIndex],
          product,
        );
        _ref
            .read(warehouseDetailProvider(warehouseId).notifier)
            .replaceWarehouse(detail.copyWith(slots: slots));
      }
    }

    // Store detail pages carry a light-weight snapshot of the city's general
    // warehouse. Keep that snapshot enriched too, still without refetching.
    final quantity = (patch.changes['quantity'] as num?)?.toInt();
    final qualityLevel = (patch.changes['quality_level'] as num?)?.toInt();
    if (quantity != null && qualityLevel != null) {
      for (final activeStoreId in StoreDetailPageNotifier.activeStoreIds) {
        _ref
            .read(storeDetailPageProvider(activeStoreId).notifier)
            .patchOrAddCityWarehouseSlot(
              warehouseSlotId: patch.id,
              productId: productId,
              productName: product.urunAdi,
              productIcon: product.urunIconu,
              qualityLevel: qualityLevel,
              brandId: patch.changes['brand_id']?.toString() ??
                  '00000000-0000-0000-0000-000000000000',
              quantity: quantity,
              cost: (patch.changes['cost'] as num?)?.toDouble() ?? 0,
            );
      }
    }
  }

  Future<void> _retryAfterCatalogLoad(EntityPatch patch) async {
    try {
      await _ref.read(staticCatalogsProvider.future);
      apply(patch);
    } catch (_) {
      // Catalog loading has its own provider error state. Do not turn a
      // committed backend mutation into a client-visible mutation failure.
    }
  }
}

final warehouseSlotMetadataPatchServiceProvider =
    Provider<WarehouseSlotMetadataPatchService>(
  WarehouseSlotMetadataPatchService.new,
);
