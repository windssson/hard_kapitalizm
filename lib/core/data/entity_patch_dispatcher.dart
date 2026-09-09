import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/data/static_catalog_provider.dart';
import 'package:hard_kapitalizm/core/models/building_boost_model.dart';
import 'package:hard_kapitalizm/core/models/building_upgrade_model.dart';
import 'package:hard_kapitalizm/core/models/mutation/entity_patch.dart';
import 'package:hard_kapitalizm/core/models/product_model.dart';
import 'package:hard_kapitalizm/features/store/data/store_provider.dart';
import 'package:hard_kapitalizm/features/store/models/store_model.dart';
import 'package:hard_kapitalizm/features/warehouse/data/warehouse_provider.dart';
import 'package:hard_kapitalizm/features/warehouse/models/warehouse_model.dart';
import 'package:hard_kapitalizm/features/logistics/data/logistics_provider.dart';
import 'package:hard_kapitalizm/features/logistics/models/logistics_company_model.dart';
import 'package:hard_kapitalizm/features/logistics/models/logistics_vehicle_model.dart';
import 'package:hard_kapitalizm/features/factory/data/factory_provider.dart';
import 'package:hard_kapitalizm/features/factory/models/factory_model.dart';
import 'package:hard_kapitalizm/features/factory/models/factory_list_item_model.dart';
import 'package:hard_kapitalizm/features/factory/models/factory_detail_model.dart';
import 'package:hard_kapitalizm/features/mine/data/mine_provider.dart';
import 'package:hard_kapitalizm/features/mine/models/mine_model.dart';
import 'package:hard_kapitalizm/features/mine/models/mine_list_item_model.dart';
import 'package:hard_kapitalizm/features/mine/models/mine_detail_model.dart';
import 'package:hard_kapitalizm/features/field/data/field_provider.dart';
import 'package:hard_kapitalizm/features/field/models/field_detail_model.dart';
import 'package:hard_kapitalizm/features/farm/data/farm_provider.dart';
import 'package:hard_kapitalizm/features/farm/models/farm_detail_model.dart';
import 'package:hard_kapitalizm/features/arge/data/arge_provider.dart';
import 'package:hard_kapitalizm/features/arge/models/arge_center_model.dart';
import 'package:hard_kapitalizm/features/transfer_map/data/transfer_map_provider.dart';

/// Mutation RPC response'larından dönen `changed.patches[]` listesini
/// ilgili feature provider'larına yönlendiren merkezi dağıtıcı (dispatcher).
class EntityPatchDispatcher {
  final Ref _ref;

  EntityPatchDispatcher(this._ref);

  /// Tek bir EntityPatch nesnesini uygun feature handler'a yönlendirir.
  void dispatch(EntityPatch patch) {
    switch (patch.entity) {
      case 'store':
        _applyStorePatch(patch);
        break;
      case 'store_slot':
        _applyStoreSlotPatch(patch);
        break;
      case 'warehouse':
        _applyWarehousePatch(patch);
        break;
      case 'warehouse_slot':
        _applyWarehouseSlotPatch(patch);
        break;
      case 'logistics_company':
        _applyLogisticsCompanyPatch(patch);
        break;
      case 'logistics_vehicle':
        _applyLogisticsVehiclePatch(patch);
        break;
      case 'logistics_transfer':
        _applyLogisticsTransferPatch(patch);
        break;
      case 'logistics_transfer_item':
        _applyLogisticsTransferItemPatch(patch);
        break;
      case 'factory':
        _applyFactoryPatch(patch);
        break;
      case 'mine':
        _applyMinePatch(patch);
        break;
      case 'field': // Backend field = UI Çiftlik
        _applyFieldPatch(patch);
        break;
      case 'farm': // Backend farm = UI Tarla
        _applyFarmPatch(patch);
        break;
      case 'production_slot':
        _applyProductionSlotPatch(patch);
        break;
      case 'production_inventory':
        _applyProductionInventoryPatch(patch);
        break;
      case 'arge_center':
        _applyArgeCenterPatch(patch);
        break;
      case 'building_upgrade':
        _applyBuildingUpgradePatch(patch);
        break;
      case 'building_boost':
        _applyBuildingBoostPatch(patch);
        break;
      case 'building_construction':
        _applyBuildingConstructionPatch(patch);
        break;
      default:
        debugPrint('Unhandled entity patch: $patch');
        break;
    }
  }

  // ─── STORE HANDLERS ────────────────────────────────────────────────────────

  void _applyStorePatch(EntityPatch patch) {
    final stores = _ref.read(storesListProvider).value;

    if (patch.operation == PatchOperation.insert) {
      try {
        final newStore = StoreModel.fromJson(patch.changes);
        _ref.read(storesListProvider.notifier).prependStore(newStore);
      } catch (e, st) {
        debugPrint('Error applying insert patch for store: $e\n$st');
      }
      return;
    }

    if (patch.operation == PatchOperation.delete) {
      _ref.read(storesListProvider.notifier).removeStore(patch.id);
      return;
    }

    if (patch.operation == PatchOperation.update) {
      // 1. Mağaza listesindeki mağazayı güncelle
      if (stores != null) {
        final storeIndex = stores.indexWhere((s) => s.id == patch.id);
        if (storeIndex >= 0) {
          final s = stores[storeIndex];
          final updatedStore = s.copyWith(
            isActive: patch.changes['is_active'] as bool? ?? s.isActive,
            currentSlotCount:
                (patch.changes['current_slot_count'] as num?)?.toInt() ??
                s.currentSlotCount,
            level: (patch.changes['level'] as num?)?.toInt() ?? s.level,
            slotCapacity:
                (patch.changes['slot_capacity'] as num?)?.toInt() ??
                s.slotCapacity,
            maxSlotCount:
                (patch.changes['max_slot_count'] as num?)?.toInt() ??
                s.maxSlotCount,
            name: patch.changes['name']?.toString() ?? s.name,
          );
          _ref.read(storesListProvider.notifier).replaceStore(updatedStore);
        }
      }

      // 2. Eğer bu mağazanın detay sayfası açık ise güncelle
      final detailNotifier = _ref.read(storeDetailPageProvider(patch.id).notifier);
      final detailPage = _ref.read(storeDetailPageProvider(patch.id)).value;
      if (detailPage != null) {
        final s = detailPage.store;
        final updatedStore = s.copyWith(
          isActive: patch.changes['is_active'] as bool? ?? s.isActive,
          currentSlotCount:
              (patch.changes['current_slot_count'] as num?)?.toInt() ??
              s.currentSlotCount,
          level: (patch.changes['level'] as num?)?.toInt() ?? s.level,
          slotCapacity:
              (patch.changes['slot_capacity'] as num?)?.toInt() ??
              s.slotCapacity,
          maxSlotCount:
              (patch.changes['max_slot_count'] as num?)?.toInt() ??
              s.maxSlotCount,
          name: patch.changes['name']?.toString() ?? s.name,
        );
        detailNotifier.replacePage(detailPage.copyWith(store: updatedStore));
      }
    }
  }

  void _applyStoreSlotPatch(EntityPatch patch) {
    final stores = _ref.read(storesListProvider).value;

    // Slotun ait olduğu storeId'yi bul
    String? storeId = patch.changes['store_id']?.toString();
    if (storeId == null) {
      // 1. Yüklü mağaza listesinde ara
      if (stores != null) {
        for (final s in stores) {
          if (s.slots.any((slot) => slot.id == patch.id)) {
            storeId = s.id;
            break;
          }
        }
      }
      // 2. Açık detay ekranlarında ara (deep-link veya liste dispose durumu için fallback)
      if (storeId == null) {
        for (final activeId in StoreDetailPageNotifier.activeStoreIds) {
          final detail = _ref.read(storeDetailPageProvider(activeId)).value;
          if (detail != null && detail.store.slots.any((slot) => slot.id == patch.id)) {
            storeId = activeId;
            break;
          }
        }
      }
    }

    if (patch.operation == PatchOperation.insert) {
      try {
        final newSlot = StoreSlotModel.fromJson(patch.changes);
        final targetStoreId = storeId ?? newSlot.storeId;
        if (targetStoreId.isNotEmpty) {
          // Detay sayfasına ekle (current_slot_count yalnız store patch'i tarafından yönetilir)
          final detailPage =
              _ref.read(storeDetailPageProvider(targetStoreId)).value;
          if (detailPage != null) {
            _ref.read(storeDetailPageProvider(targetStoreId).notifier).addSlot(newSlot, updateCount: false);
          }
          // Listeye ekle
          if (stores != null) {
            final idx = stores.indexWhere((s) => s.id == targetStoreId);
            if (idx >= 0) {
              final store = stores[idx];
              if (!store.slots.any((s) => s.id == newSlot.id)) {
                final updatedSlots = [...store.slots, newSlot];
                final summary = recalculateStoreSummary(updatedSlots, store.summary);
                _ref.read(storesListProvider.notifier).replaceStore(
                  store.copyWith(
                    slots: updatedSlots,
                    summary: summary,
                    // current_slot_count yalnız store patch'i tarafından yönetilir
                  ),
                );
              }
            }
          }
        }
      } catch (e, st) {
        debugPrint('Error applying insert patch for store_slot: $e\n$st');
      }
      return;
    }

    if (patch.operation == PatchOperation.delete) {
      if (storeId != null && storeId.isNotEmpty) {
        // Listeden sil
        if (stores != null) {
          final idx = stores.indexWhere((s) => s.id == storeId);
          if (idx >= 0) {
            final store = stores[idx];
            final updatedSlots =
                store.slots.where((s) => s.id != patch.id).toList();
            final summary = recalculateStoreSummary(updatedSlots, store.summary);
            _ref.read(storesListProvider.notifier).replaceStore(
              store.copyWith(slots: updatedSlots, summary: summary),
            );
          }
        }
        // Detay sayfasından sil
        final detailPage = _ref.read(storeDetailPageProvider(storeId)).value;
        if (detailPage != null) {
          final updatedSlots =
              detailPage.store.slots.where((s) => s.id != patch.id).toList();
          final summary =
              recalculateStoreSummary(updatedSlots, detailPage.store.summary);
          _ref.read(storeDetailPageProvider(storeId).notifier).replacePage(
            detailPage.copyWith(
              store: detailPage.store.copyWith(
                slots: updatedSlots,
                summary: summary,
              ),
            ),
          );
        }
      }
      return;
    }

    if (patch.operation == PatchOperation.update) {
      // Slot güncelleme (Null Semantiği destekli)
      StoreSlotModel mergeSlot(StoreSlotModel slot) {
        final hasProductKey = patch.changes.containsKey('product_id');
        final newProductId =
            hasProductKey ? patch.changes['product_id'] as String? : slot.productId;
        final isCleared = hasProductKey && (newProductId == null || newProductId.isEmpty);

        final isProductChanged =
            hasProductKey && newProductId != slot.productId;
        final resolvedProduct = isProductChanged
            ? (newProductId != null && newProductId.isNotEmpty
                ? _resolveProduct(newProductId)
                : null)
            : slot.product;

        final newQuantity = (patch.changes['quantity'] as num?)?.toInt() ??
            (isCleared ? 0 : slot.quantity);
        final newCost = (patch.changes['cost'] as num?)?.toDouble() ??
            (isCleared ? 0.0 : slot.cost);
        final newPrice = (patch.changes['price'] as num?)?.toDouble() ??
            (isCleared ? 0.0 : slot.price);
        final newQuality = (patch.changes['quality_level'] as num?)?.toInt() ??
            (isCleared ? 0 : slot.qualityLevel);
        final newBrandId = patch.changes['brand_id']?.toString() ??
            (isCleared ? '00000000-0000-0000-0000-000000000000' : slot.brandId);
        final newCapacity = (patch.changes['capacity'] as num?)?.toInt() ?? slot.capacity;
        final newBoostMultiplier =
            (patch.changes['boost_multiplier'] as num?)?.toDouble() ??
            slot.boostMultiplier;

        return slot.copyWith(
          productId: newProductId,
          productName: isCleared
              ? null
              : (resolvedProduct?.urunAdi ?? slot.productName),
          productIcon: isCleared
              ? null
              : (resolvedProduct?.urunIconu ?? slot.productIcon),
          quantity: newQuantity,
          cost: newCost,
          price: newPrice,
          qualityLevel: newQuality,
          brandId: newBrandId,
          capacity: newCapacity,
          boostMultiplier: newBoostMultiplier,
          isActive: patch.changes['is_active'] as bool? ?? slot.isActive,
          pendingSale: (patch.changes['pending_sale'] as num?)?.toDouble() ??
              (isCleared ? 0.0 : slot.pendingSale),
          pendingQuantity:
              (patch.changes['pending_quantity'] as num?)?.toInt() ??
              (isCleared ? 0 : slot.pendingQuantity),
          isEmpty: newProductId == null || newProductId.isEmpty,
          product: isCleared ? null : resolvedProduct,
        );
      }

      // 1. Mağaza listesindeki slotu güncelle
      if (stores != null) {
        for (final store in stores) {
          final slotIdx = store.slots.indexWhere((s) => s.id == patch.id);
          if (slotIdx >= 0) {
            final updatedSlots = [...store.slots];
            updatedSlots[slotIdx] = mergeSlot(updatedSlots[slotIdx]);
            final summary = recalculateStoreSummary(updatedSlots, store.summary);
            _ref.read(storesListProvider.notifier).replaceStore(
              store.copyWith(slots: updatedSlots, summary: summary),
            );
            break;
          }
        }
      }

      // 2. Detay sayfası açıksa slotu güncelle
      if (storeId != null && storeId.isNotEmpty) {
        final detailPage = _ref.read(storeDetailPageProvider(storeId)).value;
        if (detailPage != null) {
          final slotIdx =
              detailPage.store.slots.indexWhere((s) => s.id == patch.id);
          if (slotIdx >= 0) {
            final updatedSlots = [...detailPage.store.slots];
            updatedSlots[slotIdx] = mergeSlot(updatedSlots[slotIdx]);
            final summary =
                recalculateStoreSummary(updatedSlots, detailPage.store.summary);
            _ref.read(storeDetailPageProvider(storeId).notifier).replacePage(
              detailPage.copyWith(
                store: detailPage.store.copyWith(
                  slots: updatedSlots,
                  summary: summary,
                ),
              ),
            );
          }
        }
      }
    }
  }

  // ─── WAREHOUSE HANDLERS ────────────────────────────────────────────────────

  void _applyWarehousePatch(EntityPatch patch) {
    final warehouses = _ref.read(warehouseListProvider).value;

    if (patch.operation == PatchOperation.insert) {
      try {
        final newWarehouse = WarehouseModel.fromJson(patch.changes);
        if (warehouses != null &&
            !warehouses.any((w) => w.id == newWarehouse.id)) {
          _ref.read(warehouseListProvider.notifier).prependWarehouse(newWarehouse);
        }
      } catch (e, st) {
        debugPrint('Error applying insert patch for warehouse: $e\n$st');
      }
      return;
    }

    if (patch.operation == PatchOperation.delete) {
      _ref.read(warehouseListProvider.notifier).removeWarehouse(patch.id);
      return;
    }

    if (patch.operation == PatchOperation.update) {
      // 1. Depo listesinde güncelle
      if (warehouses != null) {
        final idx = warehouses.indexWhere((w) => w.id == patch.id);
        if (idx >= 0) {
          final w = warehouses[idx];
          final updated = w.copyWith(
            reservedCapacity:
                (patch.changes['reserved_capacity'] as num?)?.toDouble() ??
                w.reservedCapacity,
            capacity: (patch.changes['capacity'] as num?)?.toDouble() ?? w.capacity,
            level: (patch.changes['level'] as num?)?.toInt() ?? w.level,
            isActive: patch.changes['is_active'] as bool? ?? w.isActive,
            name: patch.changes['name']?.toString() ?? w.name,
          );
          _ref.read(warehouseListProvider.notifier).replaceWarehouse(updated);
        }
      }

      // 2. Detay sayfası açıksa güncelle
      final detailNotifier =
          _ref.read(warehouseDetailProvider(patch.id).notifier);
      final detail = _ref.read(warehouseDetailProvider(patch.id)).value;
      if (detail != null) {
        final updated = detail.copyWith(
          reservedCapacity:
              (patch.changes['reserved_capacity'] as num?)?.toDouble() ??
              detail.reservedCapacity,
          capacity:
              (patch.changes['capacity'] as num?)?.toDouble() ?? detail.capacity,
          level: (patch.changes['level'] as num?)?.toInt() ?? detail.level,
          isActive: patch.changes['is_active'] as bool? ?? detail.isActive,
          name: patch.changes['name']?.toString() ?? detail.name,
        );
        detailNotifier.replaceWarehouse(updated);
      }
    }
  }

  void _applyWarehouseSlotPatch(EntityPatch patch) {
    final warehouses = _ref.read(warehouseListProvider).value;

    String? warehouseId = patch.changes['warehouse_id']?.toString();
    if (warehouseId == null) {
      // 1. Yüklü depolar listesinde ara
      if (warehouses != null) {
        for (final w in warehouses) {
          if (w.slots.any((s) => s.id == patch.id)) {
            warehouseId = w.id;
            break;
          }
        }
      }
      // 2. Açık detay ekranlarında ara (deep-link veya liste dispose durumu için fallback)
      if (warehouseId == null) {
        for (final activeId in WarehouseDetailNotifier.activeWarehouseIds) {
          final detail = _ref.read(warehouseDetailProvider(activeId)).value;
          if (detail != null && detail.slots.any((s) => s.id == patch.id)) {
            warehouseId = activeId;
            break;
          }
        }
      }
    }

    if (patch.operation == PatchOperation.delete) {
      // Listeden kaldır
      if (warehouseId != null) {
        _ref.read(warehouseListProvider.notifier).removeSlot(
          warehouseId: warehouseId,
          slotId: patch.id,
        );
        final detail = _ref.read(warehouseDetailProvider(warehouseId)).value;
        if (detail != null) {
          _ref.read(warehouseDetailProvider(warehouseId).notifier).removeSlot(patch.id);
        }
      }
      return;
    }

    if (patch.operation == PatchOperation.insert) {
      try {
        final newSlot = WarehouseSlotModel.fromJson(patch.changes);
        final targetWarehouseId = warehouseId ?? patch.changes['warehouse_id']?.toString();
        if (targetWarehouseId != null && targetWarehouseId.isNotEmpty) {
          if (warehouses != null) {
            final idx = warehouses.indexWhere((w) => w.id == targetWarehouseId);
            if (idx >= 0) {
              final w = warehouses[idx];
              if (!w.slots.any((s) => s.id == newSlot.id)) {
                final updated = w.copyWith(slots: [...w.slots, newSlot]);
                _ref.read(warehouseListProvider.notifier).replaceWarehouse(updated);
              }
            }
          }
          final detail = _ref.read(warehouseDetailProvider(targetWarehouseId)).value;
          if (detail != null && !detail.slots.any((s) => s.id == newSlot.id)) {
            final updated = detail.copyWith(slots: [...detail.slots, newSlot]);
            _ref.read(warehouseDetailProvider(targetWarehouseId).notifier).replaceWarehouse(updated);
          }

          // Aktif mağaza ekranlarındaki şehir genel deposuna ekle/güncelle
          final resolvedProd = _resolveProduct(newSlot.productId);
          for (final activeStoreId in StoreDetailPageNotifier.activeStoreIds) {
            _ref
                .read(storeDetailPageProvider(activeStoreId).notifier)
                .patchOrAddCityWarehouseSlot(
                  warehouseSlotId: newSlot.id,
                  productId: newSlot.productId ?? '',
                  productName:
                      resolvedProd?.urunAdi ?? newSlot.productName ?? 'Ürün',
                  productIcon: resolvedProd?.urunIconu ?? newSlot.productIcon,
                  qualityLevel: newSlot.qualityLevel,
                  brandId: newSlot.brandId,
                  quantity: newSlot.quantity,
                  cost: newSlot.cost,
                );
          }
        }
      } catch (e, st) {
        debugPrint('Error applying insert patch for warehouse_slot: $e\n$st');
      }
      return;
    }

    if (patch.operation == PatchOperation.update) {
      WarehouseSlotModel mergeSlot(WarehouseSlotModel slot) {
        return slot.copyWith(
          quantity: (patch.changes['quantity'] as num?)?.toInt() ?? slot.quantity,
          price: (patch.changes['price'] as num?)?.toDouble() ?? slot.price,
          cost: (patch.changes['cost'] as num?)?.toDouble() ?? slot.cost,
          qualityLevel:
              (patch.changes['quality_level'] as num?)?.toInt() ??
              slot.qualityLevel,
          isAvailableForSale:
              patch.changes['is_available_for_sale'] as bool? ??
              slot.isAvailableForSale,
          productId: patch.changes.containsKey('product_id')
              ? patch.changes['product_id'] as String?
              : slot.productId,
          brandId: patch.changes['brand_id']?.toString() ?? slot.brandId,
        );
      }

      if (warehouses != null) {
        for (final w in warehouses) {
          final sIdx = w.slots.indexWhere((s) => s.id == patch.id);
          if (sIdx >= 0) {
            final updatedSlots = [...w.slots];
            updatedSlots[sIdx] = mergeSlot(updatedSlots[sIdx]);
            _ref.read(warehouseListProvider.notifier).replaceWarehouse(
              w.copyWith(slots: updatedSlots),
            );
            break;
          }
        }
      }

      if (warehouseId != null && warehouseId.isNotEmpty) {
        final detail = _ref.read(warehouseDetailProvider(warehouseId)).value;
        if (detail != null) {
          final sIdx = detail.slots.indexWhere((s) => s.id == patch.id);
          if (sIdx >= 0) {
            final updatedSlots = [...detail.slots];
            updatedSlots[sIdx] = mergeSlot(updatedSlots[sIdx]);
            _ref.read(warehouseDetailProvider(warehouseId).notifier).replaceWarehouse(
              detail.copyWith(slots: updatedSlots),
            );
          }
        }
      }

      // Aktif mağaza ekranındaki şehir genel deposu (cityWarehouse) slotunu güncelle
      if (patch.changes.containsKey('quantity')) {
        final newQty = (patch.changes['quantity'] as num?)?.toInt();
        if (newQty != null) {
          for (final activeStoreId in StoreDetailPageNotifier.activeStoreIds) {
            _ref
                .read(storeDetailPageProvider(activeStoreId).notifier)
                .patchCityWarehouseSlotQuantity(
                  warehouseSlotId: patch.id,
                  quantity: newQty,
                );
          }
        }
      }
    }
  }

  // ─── LOGISTICS HANDLERS ───────────────────────────────────────────────────

  void _applyLogisticsCompanyPatch(EntityPatch patch) {
    if (patch.operation == PatchOperation.update) {
      _ref
          .read(playerLogisticsCompanyProvider.notifier)
          .patchCompanyChanges(patch.changes);
    } else if (patch.operation == PatchOperation.insert) {
      try {
        final newCompany = LogisticsCompanyModel.fromJson(patch.changes);
        _ref
            .read(playerLogisticsCompanyProvider.notifier)
            .replaceCompany(newCompany);
      } catch (e, st) {
        debugPrint('Error applying insert patch for logistics_company: $e\n$st');
      }
    }
  }

  void _applyLogisticsVehiclePatch(EntityPatch patch) {
    final notifier = _ref.read(logisticsVehicleListProvider.notifier);

    if (patch.operation == PatchOperation.insert) {
      try {
        final newVehicle = LogisticsVehicleModel.fromJson(patch.changes);
        notifier.insertVehicle(newVehicle);
      } catch (e, st) {
        debugPrint('Error applying insert patch for logistics_vehicle: $e\n$st');
      }
      return;
    }

    if (patch.operation == PatchOperation.delete) {
      notifier.removeVehicle(patch.id);
      return;
    }

    if (patch.operation == PatchOperation.update) {
      notifier.patchVehicleChanges(
        vehicleId: patch.id,
        changes: patch.changes,
      );
    }
  }

  void _applyLogisticsTransferPatch(EntityPatch patch) {
    final status = patch.changes['status']?.toString();
    final isFinished = patch.operation == PatchOperation.delete ||
        status == 'completed' ||
        status == 'cancelled';

    if (isFinished) {
      // 1. Aktif harita listesinden yerel olarak kaldır
      _ref.read(buyerTransferMapProvider.notifier).patchRemoveTransfer(patch.id);

      // 2. Transfer tamamlandıysa ve geçmiş listesi açıksa/yüklüyse hedeflenmiş yenile
      if (status == 'completed') {
        final historyState = _ref.read(buyerTransferHistoryProvider);
        if (historyState.hasValue) {
          _ref.read(buyerTransferHistoryProvider.notifier).refresh();
        }
      }
      return;
    }

    if (patch.operation == PatchOperation.update) {
      // Aktif haritadaki transferi yerel olarak güncelle
      _ref.read(buyerTransferMapProvider.notifier).patchTransferChanges(
            transferId: patch.id,
            changes: patch.changes,
          );

      // Geçmiş listesinde mevcutsa yerel olarak güncelle
      final historyState = _ref.read(buyerTransferHistoryProvider);
      if (historyState.hasValue) {
        _ref.read(buyerTransferHistoryProvider.notifier).patchHistoryTransfer(
              transferId: patch.id,
              changes: patch.changes,
            );
      }
      return;
    }

    if (patch.operation == PatchOperation.insert) {
      // Raw DB patch'i harita ekranının gerektirdiği zenginleştirilmiş alanları
      // (şehir isimleri, koordinatlar, ürün ikonları vb.) içermez.
      // Eksik/sahte model üretmek yerine sadece aktif transfer haritası için
      // hedeflenmiş (targeted) yenileme yapılır.
      if (status == 'in_transit') {
        _ref.read(buyerTransferMapProvider.notifier).refresh();
      }
    }
  }

  void _applyLogisticsTransferItemPatch(EntityPatch patch) {
    final transferId = patch.changes['transfer_id']?.toString();
    if (transferId != null && transferId.isNotEmpty) {
      _ref.invalidate(transferItemsProvider(transferId));
    }
  }

  // ─── PRODUCTION HANDLERS ──────────────────────────────────────────────────

  ProductModel? _resolveProduct(String? productId) {
    if (productId == null || productId.isEmpty) return null;
    final catalogs = _ref.read(staticCatalogsProvider).value;
    if (catalogs == null) return null;
    try {
      return catalogs.products.firstWhere((p) => p.id == productId);
    } catch (_) {
      return null;
    }
  }

  void _applyFactoryPatch(EntityPatch patch) {
    if (patch.operation == PatchOperation.update) {
      if (patch.changes.containsKey('is_active')) {
        final isActive = patch.changes['is_active'] as bool;
        _ref.read(factoryListProvider.notifier).patchFactoryActive(
          factoryId: patch.id,
          isActive: isActive,
        );
        final detail = _ref.read(factoryDetailProvider(patch.id)).value;
        if (detail != null) {
          _ref.read(factoryDetailProvider(patch.id).notifier).patchFactoryActive(isActive);
        }
      }

      final hasSpecChanges = patch.changes.containsKey('level') ||
          patch.changes.containsKey('input_capacity') ||
          patch.changes.containsKey('output_capacity') ||
          patch.changes.containsKey('boost_multiplier');

      if (hasSpecChanges) {
        final level = (patch.changes['level'] as num?)?.toInt();
        final inputCapacity = (patch.changes['input_capacity'] as num?)?.toInt();
        final outputCapacity = (patch.changes['output_capacity'] as num?)?.toInt();
        final boostMultiplier = (patch.changes['boost_multiplier'] as num?)?.toDouble();

        _ref.read(factoryListProvider.notifier).patchFactorySpecs(
          factoryId: patch.id,
          level: level,
          inputCapacity: inputCapacity,
          outputCapacity: outputCapacity,
          boostMultiplier: boostMultiplier,
        );
        final detail = _ref.read(factoryDetailProvider(patch.id)).value;
        if (detail != null) {
          _ref.read(factoryDetailProvider(patch.id).notifier).patchFactorySpecs(
            level: level,
            inputCapacity: inputCapacity,
            outputCapacity: outputCapacity,
            boostMultiplier: boostMultiplier,
          );
        }
      }

      final hasConfigChanges = patch.changes.containsKey('product_id') ||
          patch.changes.containsKey('quality_level') ||
          patch.changes.containsKey('brand_id');

      if (hasConfigChanges) {
        final productId = patch.changes['product_id']?.toString();
        final qualityLevel = (patch.changes['quality_level'] as num?)?.toInt();
        final brandId = patch.changes['brand_id']?.toString();
        final product = _resolveProduct(productId);

        _ref.read(factoryListProvider.notifier).patchFactoryConfig(
          factoryId: patch.id,
          productId: productId,
          qualityLevel: qualityLevel,
          brandId: brandId,
          product: product,
        );
        _ref.read(factoryDetailProvider(patch.id).notifier).patchFactoryConfig(
          productId: productId,
          qualityLevel: qualityLevel,
          brandId: brandId,
          product: product,
        );
      }
    } else if (patch.operation == PatchOperation.insert) {
      try {
        final factory = FactoryModel.fromJson(patch.changes);
        final listItem = FactoryListItemModel(
          factory: factory,
          cityName: patch.changes['city_name']?.toString() ?? 'Şehir',
          factoryTypeName: patch.changes['factory_type_name']?.toString() ?? 'Fabrika',
          factoryTypeIcon: patch.changes['factory_type_icon']?.toString() ?? 'factory.webp',
          inputStockQuantity: 0,
          outputStockQuantity: 0,
          selectedProduct: null,
        );
        _ref.read(factoryListProvider.notifier).addFactory(listItem);
      } catch (e, st) {
        debugPrint('Error applying insert patch for factory: $e\n$st');
      }
    }
  }

  void _applyMinePatch(EntityPatch patch) {
    if (patch.operation == PatchOperation.update) {
      if (patch.changes.containsKey('is_active')) {
        final isActive = patch.changes['is_active'] as bool;
        _ref.read(mineListProvider.notifier).patchMineActive(
          mineId: patch.id,
          isActive: isActive,
        );
        final detail = _ref.read(mineDetailProvider(patch.id)).value;
        if (detail != null) {
          _ref.read(mineDetailProvider(patch.id).notifier).patchMineActive(isActive);
        }
      }

      final hasSpecChanges = patch.changes.containsKey('level') ||
          patch.changes.containsKey('output_capacity') ||
          patch.changes.containsKey('boost_multiplier');

      if (hasSpecChanges) {
        final level = (patch.changes['level'] as num?)?.toInt();
        final outputCapacity = (patch.changes['output_capacity'] as num?)?.toInt();
        final boostMultiplier = (patch.changes['boost_multiplier'] as num?)?.toDouble();

        _ref.read(mineListProvider.notifier).patchMineSpecs(
          mineId: patch.id,
          level: level,
          outputCapacity: outputCapacity,
          boostMultiplier: boostMultiplier,
        );
        final detail = _ref.read(mineDetailProvider(patch.id)).value;
        if (detail != null) {
          _ref.read(mineDetailProvider(patch.id).notifier).patchMineSpecs(
            level: level,
            outputCapacity: outputCapacity,
            boostMultiplier: boostMultiplier,
          );
        }
      }

      final hasConfigChanges = patch.changes.containsKey('product_id') ||
          patch.changes.containsKey('quality_level') ||
          patch.changes.containsKey('brand_id');

      if (hasConfigChanges) {
        final productId = patch.changes['product_id']?.toString();
        final qualityLevel = (patch.changes['quality_level'] as num?)?.toInt();
        final brandId = patch.changes['brand_id']?.toString();
        final product = _resolveProduct(productId);

        _ref.read(mineListProvider.notifier).patchMineConfig(
          mineId: patch.id,
          productId: productId,
          qualityLevel: qualityLevel,
          brandId: brandId,
          product: product,
        );
        _ref.read(mineDetailProvider(patch.id).notifier).patchMineConfig(
          productId: productId,
          qualityLevel: qualityLevel,
          brandId: brandId,
          product: product,
        );
      }
    } else if (patch.operation == PatchOperation.insert) {
      try {
        final mine = MineModel.fromJson(patch.changes);
        final listItem = MineListItemModel(
          mine: mine,
          cityName: patch.changes['city_name']?.toString() ?? 'Şehir',
          mineTypeName: patch.changes['mine_type_name']?.toString() ?? 'Maden',
          mineTypeIcon: patch.changes['mine_type_icon']?.toString() ?? 'mine.webp',
          outputStockQuantity: 0,
          selectedProduct: null,
        );
        _ref.read(mineListProvider.notifier).addMine(listItem);
      } catch (e, st) {
        debugPrint('Error applying insert patch for mine: $e\n$st');
      }
    }
  }

  void _applyFieldPatch(EntityPatch patch) {
    // Backend field = UI Çiftlik
    if (patch.operation == PatchOperation.update) {
      final inputCapacity = (patch.changes['input_capacity'] as num?)?.toInt();
      final outputCapacity = (patch.changes['output_capacity'] as num?)?.toInt();
      final level = (patch.changes['level'] as num?)?.toInt();

      final fields = _ref.read(fieldListProvider).value;
      if (fields != null) {
        final idx = fields.indexWhere((f) => f.field.id == patch.id);
        if (idx >= 0) {
          final current = fields[idx];
          final updatedField = current.field.copyWith(
            currentSlotCount:
                (patch.changes['current_slot_count'] as num?)?.toInt() ??
                current.field.currentSlotCount,
            level: level ?? current.field.level,
            inputCapacity: inputCapacity ?? current.field.inputCapacity,
            outputCapacity: outputCapacity ?? current.field.outputCapacity,
          );
          _ref
              .read(fieldListProvider.notifier)
              .replaceField(current.copyWith(field: updatedField));
        }
      }
      final detail = _ref.read(fieldDetailProvider(patch.id)).value;
      if (detail != null) {
        _ref
            .read(fieldDetailProvider(patch.id).notifier)
            .patchFieldLevelAndCapacity(
              level: level ?? detail.field.level,
              outputCapacity: outputCapacity ?? detail.field.outputCapacity,
              inputCapacity: inputCapacity,
            );
      }
    } else if (patch.operation == PatchOperation.insert) {
      _ref.read(fieldListProvider.notifier).refresh();
    }
  }

  void _applyFarmPatch(EntityPatch patch) {
    // Backend farm = UI Tarla
    if (patch.operation == PatchOperation.update) {
      final inputCapacity = (patch.changes['input_capacity'] as num?)?.toInt();
      final outputCapacity = (patch.changes['output_capacity'] as num?)?.toInt();
      final level = (patch.changes['level'] as num?)?.toInt();

      final farms = _ref.read(farmListProvider).value;
      if (farms != null) {
        final idx = farms.indexWhere((f) => f.farm.id == patch.id);
        if (idx >= 0) {
          final current = farms[idx];
          final updatedFarm = current.farm.copyWith(
            currentSlotCount:
                (patch.changes['current_slot_count'] as num?)?.toInt() ??
                current.farm.currentSlotCount,
            level: level ?? current.farm.level,
            inputCapacity: inputCapacity ?? current.farm.inputCapacity,
            outputCapacity: outputCapacity ?? current.farm.outputCapacity,
          );
          _ref
              .read(farmListProvider.notifier)
              .replaceFarm(current.copyWith(farm: updatedFarm));
        }
      }
      final detail = _ref.read(farmDetailProvider(patch.id)).value;
      if (detail != null) {
        _ref
            .read(farmDetailProvider(patch.id).notifier)
            .patchFarmLevelAndCapacity(
              level: level ?? detail.farm.level,
              outputCapacity: outputCapacity ?? detail.farm.outputCapacity,
              inputCapacity: inputCapacity,
            );
      }
    } else if (patch.operation == PatchOperation.insert) {
      _ref.read(farmListProvider.notifier).refresh();
    }
  }

  void _applyProductionSlotPatch(EntityPatch patch) {
    if (patch.operation == PatchOperation.update) {
      final ownerKind = patch.changes['owner_kind']?.toString();
      final ownerId = patch.changes['owner_id']?.toString();

      // 1. is_active değişikliği
      if (patch.changes.containsKey('is_active')) {
        final isActive = patch.changes['is_active'] as bool;
        _patchProductionSlotActive(
          slotId: patch.id,
          isActive: isActive,
          ownerKind: ownerKind,
          ownerId: ownerId,
        );
      }

      // 2. boost_multiplier değişikliği
      if (patch.changes.containsKey('boost_multiplier')) {
        final boostMultiplier =
            (patch.changes['boost_multiplier'] as num).toDouble();
        _patchProductionSlotBoost(
          slotId: patch.id,
          boostMultiplier: boostMultiplier,
          ownerKind: ownerKind,
          ownerId: ownerId,
        );
      }

      // 3. Ürün, Kalite, Marka konfigürasyon değişikliği
      final hasConfigChanges = patch.changes.containsKey('product_id') ||
          patch.changes.containsKey('quality_level') ||
          patch.changes.containsKey('brand_id');

      if (hasConfigChanges) {
        final productId = patch.changes['product_id']?.toString();
        final qualityLevel = (patch.changes['quality_level'] as num?)?.toInt();
        final brandId = patch.changes['brand_id']?.toString();
        final product = _resolveProduct(productId);

        _patchProductionSlotConfig(
          slotId: patch.id,
          productId: productId,
          qualityLevel: qualityLevel,
          brandId: brandId,
          product: product,
          ownerKind: ownerKind,
          ownerId: ownerId,
        );
      }
    }
  }

  void _patchProductionSlotBoost({
    required String slotId,
    required double boostMultiplier,
    String? ownerKind,
    String? ownerId,
  }) {
    // 1. Çiftlik (Field)
    if (ownerKind == 'field' && ownerId != null && ownerId.isNotEmpty) {
      final detail = _ref.read(fieldDetailProvider(ownerId)).value;
      if (detail != null) {
        _ref.read(fieldDetailProvider(ownerId).notifier).patchSlotBoost(
              slotId: slotId,
              boostMultiplier: boostMultiplier,
            );
      }
      return;
    }

    // 2. Tarla (Farm)
    if (ownerKind == 'farm' && ownerId != null && ownerId.isNotEmpty) {
      final detail = _ref.read(farmDetailProvider(ownerId)).value;
      if (detail != null) {
        _ref.read(farmDetailProvider(ownerId).notifier).patchSlotBoost(
              slotId: slotId,
              boostMultiplier: boostMultiplier,
            );
      }
      return;
    }

    // Fallback: açık ekranları tara
    for (final fid in FieldDetailNotifier.activeFieldIds) {
      final detail = _ref.read(fieldDetailProvider(fid)).value;
      if (detail != null && detail.slots.any((s) => s.id == slotId)) {
        _ref.read(fieldDetailProvider(fid).notifier).patchSlotBoost(
              slotId: slotId,
              boostMultiplier: boostMultiplier,
            );
        return;
      }
    }

    for (final fid in FarmDetailNotifier.activeFarmIds) {
      final detail = _ref.read(farmDetailProvider(fid)).value;
      if (detail != null && detail.slots.any((s) => s.id == slotId)) {
        _ref.read(farmDetailProvider(fid).notifier).patchSlotBoost(
              slotId: slotId,
              boostMultiplier: boostMultiplier,
            );
        return;
      }
    }
  }

  void _patchProductionSlotActive({
    required String slotId,
    required bool isActive,
    String? ownerKind,
    String? ownerId,
  }) {
    // 1. Çiftlik (Field)
    if (ownerKind == 'field' && ownerId != null && ownerId.isNotEmpty) {
      _ref.read(fieldListProvider.notifier).patchSlotActive(
            fieldId: ownerId,
            slotId: slotId,
            isActive: isActive,
          );
      final detail = _ref.read(fieldDetailProvider(ownerId)).value;
      if (detail != null) {
        _ref.read(fieldDetailProvider(ownerId).notifier).patchSlotActive(
              slotId: slotId,
              isActive: isActive,
            );
      }
      return;
    }

    // 2. Tarla (Farm)
    if (ownerKind == 'farm' && ownerId != null && ownerId.isNotEmpty) {
      _ref.read(farmListProvider.notifier).patchSlotActive(
            farmId: ownerId,
            slotId: slotId,
            isActive: isActive,
          );
      final detail = _ref.read(farmDetailProvider(ownerId)).value;
      if (detail != null) {
        _ref.read(farmDetailProvider(ownerId).notifier).patchSlotActive(
              slotId: slotId,
              isActive: isActive,
            );
      }
      return;
    }

    // Fallback: slot ID'den ara
    final fields = _ref.read(fieldListProvider).value;
    if (fields != null) {
      for (final f in fields) {
        if (f.slots.any((s) => s.id == slotId)) {
          _ref.read(fieldListProvider.notifier).patchSlotActive(
                fieldId: f.field.id,
                slotId: slotId,
                isActive: isActive,
              );
          final detail = _ref.read(fieldDetailProvider(f.field.id)).value;
          if (detail != null) {
            _ref.read(fieldDetailProvider(f.field.id).notifier).patchSlotActive(
                  slotId: slotId,
                  isActive: isActive,
                );
          }
          return;
        }
      }
    }

    final farms = _ref.read(farmListProvider).value;
    if (farms != null) {
      for (final f in farms) {
        if (f.slots.any((s) => s.id == slotId)) {
          _ref.read(farmListProvider.notifier).patchSlotActive(
                farmId: f.farm.id,
                slotId: slotId,
                isActive: isActive,
              );
          final detail = _ref.read(farmDetailProvider(f.farm.id)).value;
          if (detail != null) {
            _ref.read(farmDetailProvider(f.farm.id).notifier).patchSlotActive(
                  slotId: slotId,
                  isActive: isActive,
                );
          }
          return;
        }
      }
    }
  }

  void _patchProductionSlotConfig({
    required String slotId,
    required String? productId,
    required int? qualityLevel,
    required String? brandId,
    required ProductModel? product,
    String? ownerKind,
    String? ownerId,
  }) {
    // 1. Çiftlik (Field)
    if (ownerKind == 'field' && ownerId != null && ownerId.isNotEmpty) {
      _ref.read(fieldListProvider.notifier).patchSlotConfig(
            fieldId: ownerId,
            slotId: slotId,
            productId: productId,
            qualityLevel: qualityLevel,
            brandId: brandId,
            product: product,
          );
      final detail = _ref.read(fieldDetailProvider(ownerId)).value;
      if (detail != null) {
        _ref.read(fieldDetailProvider(ownerId).notifier).patchSlotConfig(
              slotId: slotId,
              productId: productId,
              qualityLevel: qualityLevel,
              brandId: brandId,
              product: product,
            );
      }
      return;
    }

    // 2. Tarla (Farm)
    if (ownerKind == 'farm' && ownerId != null && ownerId.isNotEmpty) {
      _ref.read(farmListProvider.notifier).patchSlotConfig(
            farmId: ownerId,
            slotId: slotId,
            productId: productId,
            qualityLevel: qualityLevel,
            brandId: brandId,
            product: product,
          );
      final detail = _ref.read(farmDetailProvider(ownerId)).value;
      if (detail != null) {
        _ref.read(farmDetailProvider(ownerId).notifier).patchSlotConfig(
              slotId: slotId,
              productId: productId,
              qualityLevel: qualityLevel,
              brandId: brandId,
              product: product,
            );
      }
      return;
    }

    // Fallback: slot ID'den ara
    final fields = _ref.read(fieldListProvider).value;
    if (fields != null) {
      for (final f in fields) {
        if (f.slots.any((s) => s.id == slotId)) {
          _ref.read(fieldListProvider.notifier).patchSlotConfig(
                fieldId: f.field.id,
                slotId: slotId,
                productId: productId,
                qualityLevel: qualityLevel,
                brandId: brandId,
                product: product,
              );
          final detail = _ref.read(fieldDetailProvider(f.field.id)).value;
          if (detail != null) {
            _ref.read(fieldDetailProvider(f.field.id).notifier).patchSlotConfig(
                  slotId: slotId,
                  productId: productId,
                  qualityLevel: qualityLevel,
                  brandId: brandId,
                  product: product,
                );
          }
          return;
        }
      }
    }

    final farms = _ref.read(farmListProvider).value;
    if (farms != null) {
      for (final f in farms) {
        if (f.slots.any((s) => s.id == slotId)) {
          _ref.read(farmListProvider.notifier).patchSlotConfig(
                farmId: f.farm.id,
                slotId: slotId,
                productId: productId,
                qualityLevel: qualityLevel,
                brandId: brandId,
                product: product,
              );
          final detail = _ref.read(farmDetailProvider(f.farm.id)).value;
          if (detail != null) {
            _ref.read(farmDetailProvider(f.farm.id).notifier).patchSlotConfig(
                  slotId: slotId,
                  productId: productId,
                  qualityLevel: qualityLevel,
                  brandId: brandId,
                  product: product,
                );
          }
          return;
        }
      }
    }
  }

  // ─── PRODUCTION INVENTORY HANDLERS ────────────────────────────────────────

  void _applyProductionInventoryPatch(EntityPatch patch) {
    final ownerKind = (patch.changes['owner_kind'] ?? '').toString();
    final ownerId = (patch.changes['owner_id'] ?? '').toString();

    if (patch.operation == PatchOperation.delete) {
      if (ownerKind == 'factory' && ownerId.isNotEmpty) {
        _ref.read(factoryDetailProvider(ownerId).notifier).removeInventory(patch.id);
      } else if (ownerKind == 'mine' && ownerId.isNotEmpty) {
        _ref.read(mineDetailProvider(ownerId).notifier).removeInventory(patch.id);
      } else if (ownerKind == 'field' && ownerId.isNotEmpty) {
        _ref.read(fieldDetailProvider(ownerId).notifier).removeInventory(patch.id);
      } else if (ownerKind == 'farm' && ownerId.isNotEmpty) {
        _ref.read(farmDetailProvider(ownerId).notifier).removeInventory(patch.id);
      } else {
        // Fallback: açık ekranları tara ve envanteri kaldır
        for (final fid in FactoryDetailNotifier.activeFactoryIds) {
          _ref.read(factoryDetailProvider(fid).notifier).removeInventory(patch.id);
        }
        for (final mid in MineDetailNotifier.activeMineIds) {
          _ref.read(mineDetailProvider(mid).notifier).removeInventory(patch.id);
        }
        for (final fid in FieldDetailNotifier.activeFieldIds) {
          _ref.read(fieldDetailProvider(fid).notifier).removeInventory(patch.id);
        }
        for (final fid in FarmDetailNotifier.activeFarmIds) {
          _ref.read(farmDetailProvider(fid).notifier).removeInventory(patch.id);
        }
      }
      return;
    }

    if (patch.operation == PatchOperation.insert) {
      try {
        final productId = patch.changes['product_id']?.toString();
        final resolvedProduct = _resolveProduct(productId);
        final effectiveKind = ownerKind.isNotEmpty
            ? ownerKind
            : _inferInventoryOwnerKind(ownerId);

        if (effectiveKind == 'factory') {
          final item = FactoryProductionInventoryModel.fromJson(patch.changes)
              .copyWith(product: resolvedProduct);
          final targetId = ownerId.isNotEmpty
              ? ownerId
              : FactoryDetailNotifier.activeFactoryIds.firstOrNull;
          if (targetId != null) {
            _ref.read(factoryDetailProvider(targetId).notifier).insertInventory(item);
          }
        } else if (effectiveKind == 'mine') {
          final item = MineProductionInventoryModel.fromJson(patch.changes)
              .copyWith(product: resolvedProduct);
          final targetId = ownerId.isNotEmpty
              ? ownerId
              : MineDetailNotifier.activeMineIds.firstOrNull;
          if (targetId != null) {
            _ref.read(mineDetailProvider(targetId).notifier).insertInventory(item);
          }
        } else if (effectiveKind == 'field') {
          final item = ProductionInventoryModel.fromJson(patch.changes)
              .copyWith(product: resolvedProduct);
          final targetId = ownerId.isNotEmpty
              ? ownerId
              : FieldDetailNotifier.activeFieldIds.firstOrNull;
          if (targetId != null) {
            _ref.read(fieldDetailProvider(targetId).notifier).insertInventory(item);
          }
        } else if (effectiveKind == 'farm') {
          final item = FarmProductionInventoryModel.fromJson(patch.changes)
              .copyWith(product: resolvedProduct);
          final targetId = ownerId.isNotEmpty
              ? ownerId
              : FarmDetailNotifier.activeFarmIds.firstOrNull;
          if (targetId != null) {
            _ref.read(farmDetailProvider(targetId).notifier).insertInventory(item);
          }
        }
      } catch (e, st) {
        debugPrint('Error applying insert patch for production_inventory: $e\n$st');
      }
      return;
    }

    if (patch.operation == PatchOperation.update) {
      final productId = patch.changes['product_id']?.toString();
      final resolvedProduct = _resolveProduct(productId);
      final effectiveKind = ownerKind.isNotEmpty
          ? ownerKind
          : _inferInventoryOwnerKind(ownerId);

      if (effectiveKind == 'factory' && ownerId.isNotEmpty) {
        _ref.read(factoryDetailProvider(ownerId).notifier).patchInventoryChanges(
              id: patch.id,
              changes: patch.changes,
              resolvedProduct: resolvedProduct,
            );
      } else if (effectiveKind == 'mine' && ownerId.isNotEmpty) {
        _ref.read(mineDetailProvider(ownerId).notifier).patchInventoryChanges(
              id: patch.id,
              changes: patch.changes,
              resolvedProduct: resolvedProduct,
            );
      } else if (effectiveKind == 'field' && ownerId.isNotEmpty) {
        _ref.read(fieldDetailProvider(ownerId).notifier).patchInventoryChanges(
              id: patch.id,
              changes: patch.changes,
              resolvedProduct: resolvedProduct,
            );
      } else if (effectiveKind == 'farm' && ownerId.isNotEmpty) {
        _ref.read(farmDetailProvider(ownerId).notifier).patchInventoryChanges(
              id: patch.id,
              changes: patch.changes,
              resolvedProduct: resolvedProduct,
            );
      } else {
        // Fallback: açık ekranlarda güncelle
        for (final fid in FactoryDetailNotifier.activeFactoryIds) {
          _ref.read(factoryDetailProvider(fid).notifier).patchInventoryChanges(
                id: patch.id,
                changes: patch.changes,
                resolvedProduct: resolvedProduct,
              );
        }
        for (final mid in MineDetailNotifier.activeMineIds) {
          _ref.read(mineDetailProvider(mid).notifier).patchInventoryChanges(
                id: patch.id,
                changes: patch.changes,
                resolvedProduct: resolvedProduct,
              );
        }
        for (final fid in FieldDetailNotifier.activeFieldIds) {
          _ref.read(fieldDetailProvider(fid).notifier).patchInventoryChanges(
                id: patch.id,
                changes: patch.changes,
                resolvedProduct: resolvedProduct,
              );
        }
        for (final fid in FarmDetailNotifier.activeFarmIds) {
          _ref.read(farmDetailProvider(fid).notifier).patchInventoryChanges(
                id: patch.id,
                changes: patch.changes,
                resolvedProduct: resolvedProduct,
              );
        }
      }
    }
  }

  String? _inferInventoryOwnerKind(String ownerId) {
    if (ownerId.isEmpty) return null;
    if (FactoryDetailNotifier.activeFactoryIds.contains(ownerId)) return 'factory';
    if (MineDetailNotifier.activeMineIds.contains(ownerId)) return 'mine';
    if (FieldDetailNotifier.activeFieldIds.contains(ownerId)) return 'field';
    if (FarmDetailNotifier.activeFarmIds.contains(ownerId)) return 'farm';
    return null;
  }

  // ─── AR-GE CENTER HANDLERS ───────────────────────────────────────────────

  void _applyArgeCenterPatch(EntityPatch patch) {
    if (patch.operation == PatchOperation.insert) {
      try {
        final center = ArgeCenterModel.fromJson(patch.changes);
        _ref.read(playerArgeCenterProvider.notifier).setCenter(center);
      } catch (e, st) {
        debugPrint('Error applying insert patch for arge_center: $e\n$st');
      }
      return;
    }

    if (patch.operation == PatchOperation.update) {
      final level = (patch.changes['level'] as num?)?.toInt();
      final maxResearches =
          (patch.changes['max_concurrent_researches'] as num?)?.toInt();
      final durationReduction =
          (patch.changes['duration_reduction_pct'] as num?)?.toDouble();

      _ref.read(playerArgeCenterProvider.notifier).patchSpecs(
            level: level,
            maxConcurrentResearches: maxResearches,
            durationReductionPct: durationReduction,
          );
    }
  }

  // ─── CONSTRUCTION HANDLERS ────────────────────────────────────────────────

  void _applyBuildingConstructionPatch(EntityPatch patch) {
    final status = patch.changes['status']?.toString();
    final isComplete = status == 'complete' ||
        status == 'completed' ||
        patch.operation == PatchOperation.delete;

    final buildingKind = (patch.changes['building_kind'] ??
            patch.changes['entity_kind'] ??
            '')
        .toString();

    // İnşaat tamamlandıysa ilgili bina sağlayıcılarını veya inşaat providerlarını senkronize et
    if (isComplete) {
      _ref.invalidate(factoryConstructionProvider);
      _ref.invalidate(mineConstructionProvider);
      _ref.invalidate(playerLogisticsConstructionProvider);
      _ref.read(fieldConstructionProvider.notifier).clear();
      _ref.read(farmConstructionProvider.notifier).clear();
      _ref.read(playerArgeConstructionProvider.notifier).clear();
      return;
    }

    if (patch.operation == PatchOperation.update &&
        patch.changes.containsKey('finish_at')) {
      final finishAtStr = patch.changes['finish_at']?.toString();
      final finishAt =
          finishAtStr != null ? DateTime.tryParse(finishAtStr) : null;
      if (finishAt != null) {
        if (buildingKind == 'field') {
          _ref.read(fieldConstructionProvider.notifier).patchFinishAt(finishAt);
        } else if (buildingKind == 'farm') {
          _ref.read(farmConstructionProvider.notifier).patchFinishAt(finishAt);
        } else if (buildingKind == 'arge_center') {
          _ref.read(playerArgeConstructionProvider.notifier).patchFinishAt(finishAt);
        } else if (buildingKind == 'factory') {
          _ref.invalidate(factoryConstructionProvider);
        } else if (buildingKind == 'mine') {
          _ref.invalidate(mineConstructionProvider);
        } else if (buildingKind == 'logistics_company') {
          _ref.invalidate(playerLogisticsConstructionProvider);
        }
      }
    }
  }

  // ─── UPGRADE & BOOST HANDLERS ─────────────────────────────────────────────

  void _applyBuildingUpgradePatch(EntityPatch patch) {
    final status = patch.changes['status']?.toString();
    final isDone = patch.operation == PatchOperation.delete ||
        status == 'completed' ||
        status == 'cancelled';

    final buildingKind = (patch.changes['building_kind'] ??
            patch.changes['entity_kind'] ??
            '')
        .toString();
    final entityId = (patch.changes['entity_id'] ??
            patch.changes['building_id'] ??
            patch.id)
        .toString();

    if (isDone) {
      _clearBuildingUpgrade(buildingKind: buildingKind, entityId: entityId);
      return;
    }

    if (patch.operation == PatchOperation.insert) {
      try {
        final upgrade = BuildingUpgradeModel.fromJson(patch.changes);
        _setBuildingUpgrade(
          buildingKind:
              buildingKind.isNotEmpty ? buildingKind : upgrade.buildingKind,
          entityId: entityId.isNotEmpty ? entityId : upgrade.entityId,
          upgrade: upgrade,
        );
      } catch (e, st) {
        debugPrint('Error applying insert patch for building_upgrade: $e\n$st');
      }
      return;
    }

    if (patch.operation == PatchOperation.update) {
      final current = _getActiveUpgrade(buildingKind, entityId);
      if (current != null) {
        final newFinishAt = patch.changes.containsKey('finish_at')
            ? (DateTime.tryParse(patch.changes['finish_at']?.toString() ?? '') ??
                current.finishAt)
            : current.finishAt;
        final newCompletedAt = patch.changes.containsKey('completed_at')
            ? (patch.changes['completed_at'] != null
                ? DateTime.tryParse(patch.changes['completed_at'].toString())
                : null)
            : current.completedAt;
        final newStatus = patch.changes['status']?.toString() ?? current.status;
        final newCurrentLevel =
            (patch.changes['current_level'] as num?)?.toInt() ?? current.currentLevel;
        final newTargetLevel =
            (patch.changes['target_level'] as num?)?.toInt() ?? current.targetLevel;

        final updated = current.copyWith(
          finishAt: newFinishAt,
          completedAt: newCompletedAt,
          status: newStatus,
          currentLevel: newCurrentLevel,
          targetLevel: newTargetLevel,
        );
        _setBuildingUpgrade(
          buildingKind: buildingKind,
          entityId: entityId,
          upgrade: updated,
        );
      } else {
        try {
          final upgrade = BuildingUpgradeModel.fromJson(patch.changes);
          _setBuildingUpgrade(
            buildingKind:
                buildingKind.isNotEmpty ? buildingKind : upgrade.buildingKind,
            entityId: entityId.isNotEmpty ? entityId : upgrade.entityId,
            upgrade: upgrade,
          );
        } catch (_) {
          // Kısmi patch ve yerel model yoksa targeted fallback
          _clearBuildingUpgrade(buildingKind: buildingKind, entityId: entityId);
        }
      }
    }
  }

  BuildingUpgradeModel? _getActiveUpgrade(String buildingKind, String entityId) {
    if (buildingKind == 'factory') {
      return _ref.read(activeFactoryUpgradeProvider(entityId)).value;
    } else if (buildingKind == 'mine') {
      return _ref.read(activeMineUpgradeProvider(entityId)).value;
    } else if (buildingKind == 'field') {
      return _ref.read(activeFieldUpgradeProvider(entityId)).value;
    } else if (buildingKind == 'farm') {
      return _ref.read(activeFarmUpgradeProvider(entityId)).value;
    } else if (buildingKind == 'warehouse') {
      return _ref.read(activeWarehouseUpgradeProvider(entityId)).value;
    } else if (buildingKind == 'store') {
      return _ref.read(storeDetailPageProvider(entityId)).value?.activeUpgrade;
    } else if (buildingKind == 'arge_center') {
      return _ref.read(activeArgeCenterUpgradeProvider(entityId)).value;
    }
    return null;
  }

  void _clearBuildingUpgrade({
    required String buildingKind,
    required String entityId,
  }) {
    if (buildingKind == 'factory') {
      _ref.read(activeFactoryUpgradeProvider(entityId).notifier).clear();
    } else if (buildingKind == 'mine') {
      _ref.read(activeMineUpgradeProvider(entityId).notifier).clear();
    } else if (buildingKind == 'field') {
      _ref.read(activeFieldUpgradeProvider(entityId).notifier).clear();
    } else if (buildingKind == 'farm') {
      _ref.read(activeFarmUpgradeProvider(entityId).notifier).clear();
    } else if (buildingKind == 'warehouse') {
      _ref.read(activeWarehouseUpgradeProvider(entityId).notifier).clear();
    } else if (buildingKind == 'store') {
      _ref.read(storeDetailPageProvider(entityId).notifier).patchActiveUpgrade(null);
    } else if (buildingKind == 'arge_center') {
      _ref.read(activeArgeCenterUpgradeProvider(entityId).notifier).clear();
    } else {
      // Fallback: tüm açık ekranlarda ara
      for (final id in FactoryDetailNotifier.activeFactoryIds) {
        _ref.read(activeFactoryUpgradeProvider(id).notifier).clear();
      }
      for (final id in MineDetailNotifier.activeMineIds) {
        _ref.read(activeMineUpgradeProvider(id).notifier).clear();
      }
      for (final id in FieldDetailNotifier.activeFieldIds) {
        _ref.read(activeFieldUpgradeProvider(id).notifier).clear();
      }
      for (final id in FarmDetailNotifier.activeFarmIds) {
        _ref.read(activeFarmUpgradeProvider(id).notifier).clear();
      }
    }
  }

  void _setBuildingUpgrade({
    required String buildingKind,
    required String entityId,
    required BuildingUpgradeModel upgrade,
  }) {
    if (buildingKind == 'factory') {
      _ref.read(activeFactoryUpgradeProvider(entityId).notifier).setUpgrade(upgrade);
    } else if (buildingKind == 'mine') {
      _ref.read(activeMineUpgradeProvider(entityId).notifier).setUpgrade(upgrade);
    } else if (buildingKind == 'field') {
      _ref.read(activeFieldUpgradeProvider(entityId).notifier).setUpgrade(upgrade);
    } else if (buildingKind == 'farm') {
      _ref.read(activeFarmUpgradeProvider(entityId).notifier).setUpgrade(upgrade);
    } else if (buildingKind == 'warehouse') {
      _ref.read(activeWarehouseUpgradeProvider(entityId).notifier).setUpgrade(upgrade);
    } else if (buildingKind == 'store') {
      _ref.read(storeDetailPageProvider(entityId).notifier).patchActiveUpgrade(upgrade);
    } else if (buildingKind == 'arge_center') {
      _ref.read(activeArgeCenterUpgradeProvider(entityId).notifier).setUpgrade(upgrade);
    }
  }

  void _applyBuildingBoostPatch(EntityPatch patch) {
    final status = patch.changes['status']?.toString();
    final isDone = patch.operation == PatchOperation.delete ||
        status == 'completed' ||
        status == 'cancelled';

    final buildingKind = (patch.changes['building_kind'] ??
            patch.changes['entity_kind'] ??
            '')
        .toString();
    final entityId = (patch.changes['entity_id'] ??
            patch.changes['building_id'] ??
            patch.id)
        .toString();

    if (isDone) {
      _clearBuildingBoost(buildingKind: buildingKind, entityId: entityId);
      return;
    }

    if (patch.operation == PatchOperation.insert) {
      try {
        final boost = BuildingBoostModel.fromJson(patch.changes);
        _setBuildingBoost(
          buildingKind:
              buildingKind.isNotEmpty ? buildingKind : boost.buildingKind,
          entityId: entityId.isNotEmpty ? entityId : boost.entityId,
          boost: boost,
        );
      } catch (e, st) {
        debugPrint('Error applying patch for building_boost: $e\n$st');
      }
      return;
    }

    if (patch.operation == PatchOperation.update) {
      final current = _getActiveBoost(buildingKind, entityId);
      if (current != null) {
        final newFinishAt = patch.changes.containsKey('finish_at')
            ? (DateTime.tryParse(patch.changes['finish_at']?.toString() ?? '') ??
                current.finishAt)
            : current.finishAt;
        final newCompletedAt = patch.changes.containsKey('completed_at')
            ? (patch.changes['completed_at'] != null
                ? DateTime.tryParse(patch.changes['completed_at'].toString())
                : null)
            : current.completedAt;
        final newStatus = patch.changes['status']?.toString() ?? current.status;
        final newMultiplier =
            (patch.changes['multiplier'] as num?)?.toDouble() ?? current.multiplier;

        final updated = current.copyWith(
          finishAt: newFinishAt,
          completedAt: newCompletedAt,
          status: newStatus,
          multiplier: newMultiplier,
        );
        _setBuildingBoost(
          buildingKind: buildingKind,
          entityId: entityId,
          boost: updated,
        );
      } else {
        try {
          final boost = BuildingBoostModel.fromJson(patch.changes);
          _setBuildingBoost(
            buildingKind:
                buildingKind.isNotEmpty ? buildingKind : boost.buildingKind,
            entityId: entityId.isNotEmpty ? entityId : boost.entityId,
            boost: boost,
          );
        } catch (_) {
          _clearBuildingBoost(buildingKind: buildingKind, entityId: entityId);
        }
      }
    }
  }

  BuildingBoostModel? _getActiveBoost(String buildingKind, String entityId) {
    if (buildingKind == 'factory') {
      return _ref.read(activeFactoryBoostProvider(entityId)).value;
    } else if (buildingKind == 'mine') {
      return _ref.read(activeMineBoostProvider(entityId)).value;
    } else if (buildingKind == 'field') {
      return _ref.read(activeFieldBoostProvider(entityId)).value;
    } else if (buildingKind == 'farm') {
      return _ref.read(activeFarmBoostProvider(entityId)).value;
    } else if (buildingKind == 'store') {
      return _ref.read(storeDetailPageProvider(entityId)).value?.activeBoost;
    }
    return null;
  }

  void _clearBuildingBoost({
    required String buildingKind,
    required String entityId,
  }) {
    if (buildingKind == 'factory') {
      _ref.read(activeFactoryBoostProvider(entityId).notifier).clear();
    } else if (buildingKind == 'mine') {
      _ref.read(activeMineBoostProvider(entityId).notifier).clear();
    } else if (buildingKind == 'field') {
      _ref.read(activeFieldBoostProvider(entityId).notifier).clear();
    } else if (buildingKind == 'farm') {
      _ref.read(activeFarmBoostProvider(entityId).notifier).clear();
    } else if (buildingKind == 'store') {
      _ref.read(storeDetailPageProvider(entityId).notifier).patchActiveBoost(null);
    } else {
      // Fallback
      for (final id in FactoryDetailNotifier.activeFactoryIds) {
        _ref.read(activeFactoryBoostProvider(id).notifier).clear();
      }
      for (final id in MineDetailNotifier.activeMineIds) {
        _ref.read(activeMineBoostProvider(id).notifier).clear();
      }
      for (final id in FieldDetailNotifier.activeFieldIds) {
        _ref.read(activeFieldBoostProvider(id).notifier).clear();
      }
      for (final id in FarmDetailNotifier.activeFarmIds) {
        _ref.read(activeFarmBoostProvider(id).notifier).clear();
      }
    }
  }

  void _setBuildingBoost({
    required String buildingKind,
    required String entityId,
    required BuildingBoostModel boost,
  }) {
    if (buildingKind == 'factory') {
      _ref.read(activeFactoryBoostProvider(entityId).notifier).setBoost(boost);
    } else if (buildingKind == 'mine') {
      _ref.read(activeMineBoostProvider(entityId).notifier).setBoost(boost);
    } else if (buildingKind == 'field') {
      _ref.read(activeFieldBoostProvider(entityId).notifier).setBoost(boost);
    } else if (buildingKind == 'farm') {
      _ref.read(activeFarmBoostProvider(entityId).notifier).setBoost(boost);
    } else if (buildingKind == 'store') {
      _ref.read(storeDetailPageProvider(entityId).notifier).patchActiveBoost(boost);
    }
  }
}

final entityPatchDispatcherProvider = Provider<EntityPatchDispatcher>((ref) {
  return EntityPatchDispatcher(ref);
});
