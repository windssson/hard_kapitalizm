import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/models/mutation/entity_patch.dart';
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
import 'package:hard_kapitalizm/features/mine/data/mine_provider.dart';
import 'package:hard_kapitalizm/features/mine/models/mine_model.dart';
import 'package:hard_kapitalizm/features/mine/models/mine_list_item_model.dart';
import 'package:hard_kapitalizm/features/field/data/field_provider.dart';
import 'package:hard_kapitalizm/features/farm/data/farm_provider.dart';

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
        if (stores != null && !stores.any((s) => s.id == newStore.id)) {
          _ref.read(storesListProvider.notifier).replaceStore(newStore);
        }
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
        final isCleared = hasProductKey && newProductId == null;

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

        return slot.copyWith(
          productId: newProductId,
          productName: isCleared ? null : slot.productName,
          productIcon: isCleared ? null : slot.productIcon,
          quantity: newQuantity,
          cost: newCost,
          price: newPrice,
          qualityLevel: newQuality,
          brandId: newBrandId,
          isActive: patch.changes['is_active'] as bool? ?? slot.isActive,
          pendingSale: (patch.changes['pending_sale'] as num?)?.toDouble() ??
              (isCleared ? 0.0 : slot.pendingSale),
          pendingQuantity:
              (patch.changes['pending_quantity'] as num?)?.toInt() ??
              (isCleared ? 0 : slot.pendingQuantity),
          isEmpty: isCleared || newQuantity <= 0,
          product: isCleared ? null : slot.product,
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

  // ─── PRODUCTION HANDLERS ──────────────────────────────────────────────────

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
      if (patch.changes.containsKey('level')) {
        final level = (patch.changes['level'] as num).toInt();
        _ref.read(factoryListProvider.notifier).patchFactoryLevel(
          factoryId: patch.id,
          level: level,
        );
        final detail = _ref.read(factoryDetailProvider(patch.id)).value;
        if (detail != null) {
          _ref.read(factoryDetailProvider(patch.id).notifier).patchFactoryLevel(level);
        }
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
      if (patch.changes.containsKey('level')) {
        final level = (patch.changes['level'] as num).toInt();
        _ref.read(mineListProvider.notifier).patchMineLevel(
          mineId: patch.id,
          level: level,
        );
        final detail = _ref.read(mineDetailProvider(patch.id)).value;
        if (detail != null) {
          _ref.read(mineDetailProvider(patch.id).notifier).patchMineLevel(level);
        }
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
      final fields = _ref.read(fieldListProvider).value;
      if (fields != null) {
        final idx = fields.indexWhere((f) => f.field.id == patch.id);
        if (idx >= 0) {
          final current = fields[idx];
          final updatedField = current.field.copyWith(
            currentSlotCount:
                (patch.changes['current_slot_count'] as num?)?.toInt() ??
                current.field.currentSlotCount,
            level: (patch.changes['level'] as num?)?.toInt() ?? current.field.level,
            outputCapacity:
                (patch.changes['output_capacity'] as num?)?.toInt() ??
                current.field.outputCapacity,
          );
          _ref
              .read(fieldListProvider.notifier)
              .replaceField(current.copyWith(field: updatedField));
        }
      }
      final detail = _ref.read(fieldDetailProvider(patch.id)).value;
      if (detail != null) {
        final updatedField = detail.field.copyWith(
          currentSlotCount:
              (patch.changes['current_slot_count'] as num?)?.toInt() ??
              detail.field.currentSlotCount,
          level: (patch.changes['level'] as num?)?.toInt() ?? detail.field.level,
          outputCapacity:
              (patch.changes['output_capacity'] as num?)?.toInt() ??
              detail.field.outputCapacity,
        );
        _ref
            .read(fieldDetailProvider(patch.id).notifier)
            .patchFieldLevelAndCapacity(
              level: updatedField.level,
              outputCapacity: updatedField.outputCapacity,
            );
      }
    } else if (patch.operation == PatchOperation.insert) {
      _ref.read(fieldListProvider.notifier).refresh();
    }
  }

  void _applyFarmPatch(EntityPatch patch) {
    // Backend farm = UI Tarla
    if (patch.operation == PatchOperation.update) {
      final farms = _ref.read(farmListProvider).value;
      if (farms != null) {
        final idx = farms.indexWhere((f) => f.farm.id == patch.id);
        if (idx >= 0) {
          final current = farms[idx];
          final updatedFarm = current.farm.copyWith(
            currentSlotCount:
                (patch.changes['current_slot_count'] as num?)?.toInt() ??
                current.farm.currentSlotCount,
            level: (patch.changes['level'] as num?)?.toInt() ?? current.farm.level,
            outputCapacity:
                (patch.changes['output_capacity'] as num?)?.toInt() ??
                current.farm.outputCapacity,
          );
          _ref
              .read(farmListProvider.notifier)
              .replaceFarm(current.copyWith(farm: updatedFarm));
        }
      }
      final detail = _ref.read(farmDetailProvider(patch.id)).value;
      if (detail != null) {
        final updatedFarm = detail.farm.copyWith(
          currentSlotCount:
              (patch.changes['current_slot_count'] as num?)?.toInt() ??
              detail.farm.currentSlotCount,
          level: (patch.changes['level'] as num?)?.toInt() ?? detail.farm.level,
          outputCapacity:
              (patch.changes['output_capacity'] as num?)?.toInt() ??
              detail.farm.outputCapacity,
        );
        _ref
            .read(farmDetailProvider(patch.id).notifier)
            .patchFarmLevelAndCapacity(
              level: updatedFarm.level,
              outputCapacity: updatedFarm.outputCapacity,
            );
      }
    } else if (patch.operation == PatchOperation.insert) {
      _ref.read(farmListProvider.notifier).refresh();
    }
  }

  void _applyProductionSlotPatch(EntityPatch patch) {
    if (patch.operation == PatchOperation.update &&
        patch.changes.containsKey('is_active')) {
      final isActive = patch.changes['is_active'] as bool;

      // 1. Çiftlik (Field) içinde ara
      final fields = _ref.read(fieldListProvider).value;
      if (fields != null) {
        for (final f in fields) {
          if (f.slots.any((s) => s.id == patch.id)) {
            _ref.read(fieldListProvider.notifier).patchSlotActive(
              fieldId: f.field.id,
              slotId: patch.id,
              isActive: isActive,
            );
            final detail = _ref.read(fieldDetailProvider(f.field.id)).value;
            if (detail != null) {
              _ref.read(fieldDetailProvider(f.field.id).notifier).patchSlotActive(
                slotId: patch.id,
                isActive: isActive,
              );
            }
            return;
          }
        }
      }

      // 2. Tarla (Farm) içinde ara
      final farms = _ref.read(farmListProvider).value;
      if (farms != null) {
        for (final f in farms) {
          if (f.slots.any((s) => s.id == patch.id)) {
            _ref.read(farmListProvider.notifier).patchSlotActive(
              farmId: f.farm.id,
              slotId: patch.id,
              isActive: isActive,
            );
            final detail = _ref.read(farmDetailProvider(f.farm.id)).value;
            if (detail != null) {
              _ref.read(farmDetailProvider(f.farm.id).notifier).patchSlotActive(
                slotId: patch.id,
                isActive: isActive,
              );
            }
            return;
          }
        }
      }
    }
  }

  // ─── CONSTRUCTION HANDLERS ────────────────────────────────────────────────

  void _applyBuildingConstructionPatch(EntityPatch patch) {
    final status = patch.changes['status']?.toString();
    final isComplete = status == 'complete';

    // İnşaat tamamlandıysa ilgili bina sağlayıcılarını veya inşaat providerlarını senkronize et
    if (isComplete) {
      _ref.invalidate(factoryConstructionProvider);
      _ref.invalidate(mineConstructionProvider);
      _ref.invalidate(playerLogisticsConstructionProvider);
      _ref.read(fieldConstructionProvider.notifier).clear();
      _ref.read(farmConstructionProvider.notifier).clear();
    }
  }
}

final entityPatchDispatcherProvider = Provider<EntityPatchDispatcher>((ref) {
  return EntityPatchDispatcher(ref);
});
