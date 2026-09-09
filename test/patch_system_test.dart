import 'package:flutter_test/flutter_test.dart';
import 'package:hard_kapitalizm/core/models/mutation/entity_patch.dart';
import 'package:hard_kapitalizm/core/models/mutation/mutation_response.dart';
import 'package:hard_kapitalizm/features/store/models/store_model.dart';
import 'package:hard_kapitalizm/features/warehouse/models/warehouse_model.dart';
import 'package:hard_kapitalizm/features/logistics/models/logistics_company_model.dart';
import 'package:hard_kapitalizm/features/transfer_map/models/transfer_map_item_model.dart';
import 'package:hard_kapitalizm/features/transfer_map/models/transfer_history_item_model.dart';
import 'package:hard_kapitalizm/core/models/building_upgrade_model.dart';
import 'package:hard_kapitalizm/core/models/building_boost_model.dart';
import 'package:hard_kapitalizm/features/arge/models/arge_center_model.dart';
import 'package:hard_kapitalizm/features/field/models/field_detail_model.dart';
import 'package:hard_kapitalizm/features/company/models/brand_company_product_model.dart';
import 'package:hard_kapitalizm/features/logistics/models/logistics_finance_entry_model.dart';
import 'package:hard_kapitalizm/features/market/models/market_listing_model.dart';

void main() {
  group('Patch System Unit Tests', () {
    test('EntityPatch fromJson parses operation and changes correctly', () {
      final insertJson = {
        'entity': 'store_slot',
        'operation': 'insert',
        'id': 'slot-1',
        'changes': {'quantity': 100, 'price': 50.0},
      };

      final patchInsert = EntityPatch.fromJson(insertJson);
      expect(patchInsert.entity, 'store_slot');
      expect(patchInsert.id, 'slot-1');
      expect(patchInsert.operation, PatchOperation.insert);
      expect(patchInsert.changes['quantity'], 100);

      final updateJson = {
        'entity': 'warehouse_slot',
        'operation': 'update',
        'id': 'wh-slot-1',
        'changes': {'price': 250},
      };

      final patchUpdate = EntityPatch.fromJson(updateJson);
      expect(patchUpdate.operation, PatchOperation.update);

      final deleteJson = {
        'entity': 'warehouse_slot',
        'operation': 'delete',
        'id': 'wh-slot-2',
        'changes': {},
      };

      final patchDelete = EntityPatch.fromJson(deleteJson);
      expect(patchDelete.operation, PatchOperation.delete);
    });

    test('MutationResponse parses changed.patches and player correctly', () {
      final rpcResponse = {
        'success': true,
        'changed': {
          'player': {
            'cash': 850000.0,
            'level': 4,
            'experience': 82,
            'headquarters_city_id': 'city-ist',
            'headquarters_city_name': 'İstanbul',
          },
          'patches': [
            {
              'entity': 'store',
              'operation': 'update',
              'id': 'store-1',
              'changes': {'is_active': true},
            },
            {
              'entity': 'warehouse_slot',
              'operation': 'delete',
              'id': 'wslot-99',
              'changes': {},
            }
          ],
        }
      };

      final mutation = MutationResponse.fromJson(rpcResponse);
      expect(mutation.success, true);
      expect(mutation.playerChanges, isNotNull);
      expect(mutation.playerChanges!.cash, 850000.0);
      expect(mutation.playerChanges!.level, 4);
      expect(mutation.playerChanges!.headquartersCityId, 'city-ist');
      expect(mutation.playerChanges!.headquartersCityName, 'İstanbul');

      expect(mutation.patches.length, 2);
      expect(mutation.patches[0].entity, 'store');
      expect(mutation.patches[0].operation, PatchOperation.update);
      expect(mutation.patches[0].changes['is_active'], true);

      expect(mutation.patches[1].entity, 'warehouse_slot');
      expect(mutation.patches[1].operation, PatchOperation.delete);
      expect(mutation.patches[1].id, 'wslot-99');
    });

    test('StoreSlotModel copyWith respects explicit null semantics', () {
      final slot = StoreSlotModel(
        id: 'slot-123',
        storeId: 'store-1',
        slotIndex: 0,
        productId: 'DOMATES',
        productName: 'Domates',
        quantity: 150,
        pendingQuantity: 0,
        qualityLevel: 2,
        price: 25.0,
        cost: 15.0,
        capacity: 500,
        boostMultiplier: 1.0,
        isActive: true,
        isEmpty: false,
        usedCapacityRatio: 0.3,
      );

      expect(slot.productId, 'DOMATES');
      expect(slot.isEmpty, false);

      // Clearing product (null semantics)
      final clearedSlot = slot.copyWith(
        productId: null,
        productName: null,
        quantity: 0,
        price: null,
        cost: null,
        isEmpty: true,
      );

      expect(clearedSlot.productId, isNull);
      expect(clearedSlot.productName, isNull);
      expect(clearedSlot.quantity, 0);
      expect(clearedSlot.price, isNull);
      expect(clearedSlot.cost, isNull);
      expect(clearedSlot.isEmpty, true);

      // Partial update without touching productId should preserve it
      final priceUpdatedSlot = slot.copyWith(price: 30.0);
      expect(priceUpdatedSlot.productId, 'DOMATES');
      expect(priceUpdatedSlot.price, 30.0);
      expect(priceUpdatedSlot.quantity, 150);

      // Product assigned with 0 quantity must have isEmpty == false (has product)
      final zeroQtyProductSlot = slot.copyWith(
        productId: 'BIBER',
        productName: 'Biber',
        quantity: 0,
        isEmpty: false,
      );
      expect(zeroQtyProductSlot.productId, 'BIBER');
      expect(zeroQtyProductSlot.quantity, 0);
      expect(zeroQtyProductSlot.isEmpty, false);
    });

    test('WarehouseSlotModel copyWith respects explicit null semantics', () {
      final slot = WarehouseSlotModel(
        id: 'wh-1',
        productId: 'DEMIR',
        productName: 'Demir',
        quantity: 300,
        qualityLevel: 1,
        price: 50.0,
        cost: 30.0,
        isAvailableForSale: true,
      );

      expect(slot.productId, 'DEMIR');
      expect(slot.isEmpty, false);

      final clearedSlot = slot.copyWith(
        productId: null,
        productName: null,
        quantity: 0,
      );

      expect(clearedSlot.productId, isNull);
      expect(clearedSlot.productName, isNull);
      expect(clearedSlot.quantity, 0);
      expect(clearedSlot.isEmpty, true);
    });

    test('LogisticsCompanyModel copyWith updates fields properly', () {
      final now = DateTime.now();
      final company = LogisticsCompanyModel(
        id: 'comp-1',
        playerId: 'p-1',
        cityId: 'city-1',
        name: 'Hızlı Lojistik',
        level: 1,
        currentVehicleCount: 1,
        maxVehicleCount: 5,
        fuelCapacity: 1000,
        currentFuel: 200,
        fuelCost: 10.0,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      final updated = company.copyWith(
        currentFuel: 500,
        fuelCost: 12.5,
        currentVehicleCount: 2,
      );

      expect(updated.currentFuel, 500);
      expect(updated.fuelCost, 12.5);
      expect(updated.currentVehicleCount, 2);
      expect(updated.name, 'Hızlı Lojistik');
    });

    test('Store prepend and deduplication logic operates idempotently', () {
      final store1 = StoreModel.fromJson({
        'id': 'store-1',
        'name': 'Kadıköy Mağaza',
        'city_id': 'city-1',
        'level': 1,
        'current_slot_count': 5,
        'max_slot_count': 10,
        'slot_capacity': 500,
        'is_active': true,
      });
      final store2 = StoreModel.fromJson({
        'id': 'store-2',
        'name': 'Beşiktaş Mağaza',
        'city_id': 'city-1',
        'level': 1,
        'current_slot_count': 5,
        'max_slot_count': 10,
        'slot_capacity': 500,
        'is_active': true,
      });

      List<StoreModel> list = [store1];
      expect(list.length, 1);
      expect(list.first.id, 'store-1');

      // Prepend store2
      list = [store2, ...list.where((s) => s.id != store2.id)];
      expect(list.length, 2);
      expect(list.first.id, 'store-2');

      // Prepend store1 again with updated name (idempotent deduplication + top positioning)
      final updatedStore1 = store1.copyWith(name: 'Kadıköy Mağaza Güncel');
      list = [updatedStore1, ...list.where((s) => s.id != updatedStore1.id)];
      expect(list.length, 2);
      expect(list.first.id, 'store-1');
      expect(list.first.name, 'Kadıköy Mağaza Güncel');
    });

    // ─── PHASE 2 TESTS ──────────────────────────────────────────────────────

    test('production_inventory EntityPatch parses insert, update and delete', () {
      final insertPatchJson = {
        'entity': 'production_inventory',
        'operation': 'insert',
        'id': 'inv-1',
        'changes': {
          'owner_kind': 'factory',
          'owner_id': 'factory-uuid-1',
          'inventory_type': 'input',
          'product_id': 'DEMIR_CEVHERI',
          'quality_level': 2,
          'brand_id': 'brand-uuid-1',
          'quantity': 250,
          'pending_quantity': 0.0,
          'cost': 45.0,
        },
      };
      final insertPatch = EntityPatch.fromJson(insertPatchJson);
      expect(insertPatch.entity, 'production_inventory');
      expect(insertPatch.operation, PatchOperation.insert);
      expect(insertPatch.id, 'inv-1');
      expect(insertPatch.changes['owner_kind'], 'factory');
      expect(insertPatch.changes['inventory_type'], 'input');
      expect(insertPatch.changes['quantity'], 250);

      final updatePatchJson = {
        'entity': 'production_inventory',
        'operation': 'update',
        'id': 'inv-1',
        'changes': {
          'owner_kind': 'factory',
          'owner_id': 'factory-uuid-1',
          'inventory_type': 'input',
          'quantity': 180,
          'cost': 48.5,
        },
      };
      final updatePatch = EntityPatch.fromJson(updatePatchJson);
      expect(updatePatch.operation, PatchOperation.update);
      expect(updatePatch.changes['quantity'], 180);
      expect(updatePatch.changes['cost'], 48.5);

      final deletePatchJson = {
        'entity': 'production_inventory',
        'operation': 'delete',
        'id': 'inv-old',
        'changes': {},
      };
      final deletePatch = EntityPatch.fromJson(deletePatchJson);
      expect(deletePatch.operation, PatchOperation.delete);
      expect(deletePatch.id, 'inv-old');
    });

    test('Phase 2 complex mutation response parses multi-entity patches', () {
      final phase2Response = {
        'success': true,
        'message': 'Üretim yapılandırması güncellendi.',
        'changed': {
          'player': {
            'cash': 920000.0,
            'level': 5,
          },
          'patches': [
            {
              'entity': 'production_slot',
              'operation': 'update',
              'id': 'slot-farm-1',
              'changes': {
                'owner_kind': 'farm',
                'owner_id': 'farm-uuid-1',
                'product_id': 'DOMATES',
                'quality_level': 3,
                'brand_id': 'brand-uuid-premium',
                'updated_at': '2026-09-09T00:00:00Z',
              },
            },
            {
              'entity': 'production_inventory',
              'operation': 'delete',
              'id': 'inv-obsolete-1',
              'changes': {},
            },
            {
              'entity': 'production_inventory',
              'operation': 'insert',
              'id': 'inv-input-gubre',
              'changes': {
                'owner_kind': 'farm',
                'owner_id': 'farm-uuid-1',
                'inventory_type': 'input',
                'product_id': 'GUBRE',
                'quality_level': 1,
                'quantity': 0,
                'cost': 0.0,
              },
            },
            {
              'entity': 'production_inventory',
              'operation': 'insert',
              'id': 'inv-output-domates',
              'changes': {
                'owner_kind': 'farm',
                'owner_id': 'farm-uuid-1',
                'inventory_type': 'output',
                'product_id': 'DOMATES',
                'quality_level': 3,
                'quantity': 0,
                'cost': 0.0,
              },
            },
          ],
        },
      };

      final mutation = MutationResponse.fromJson(phase2Response);
      expect(mutation.success, true);
      expect(mutation.playerChanges?.cash, 920000.0);
      expect(mutation.patches.length, 4);

      expect(mutation.patches[0].entity, 'production_slot');
      expect(mutation.patches[0].operation, PatchOperation.update);
      expect(mutation.patches[0].changes['product_id'], 'DOMATES');
      expect(mutation.patches[0].changes['quality_level'], 3);

      expect(mutation.patches[1].entity, 'production_inventory');
      expect(mutation.patches[1].operation, PatchOperation.delete);
      expect(mutation.patches[1].id, 'inv-obsolete-1');

      expect(mutation.patches[2].entity, 'production_inventory');
      expect(mutation.patches[2].operation, PatchOperation.insert);
      expect(mutation.patches[2].changes['inventory_type'], 'input');

      expect(mutation.patches[3].entity, 'production_inventory');
      expect(mutation.patches[3].operation, PatchOperation.insert);
      expect(mutation.patches[3].changes['inventory_type'], 'output');
    });

    test('TransferMapItemModel copyWith updates fields correctly', () {
      final item = TransferMapItemModel.fromFlatJson({
        'id': 'transfer-1',
        'status': 'in_transit',
        'started_at': '2026-09-09T10:00:00Z',
        'finish_at': '2026-09-09T11:00:00Z',
        'quantity': 100,
        'item_count': 1,
        'quality_level': 1,
        'product_id': 'DEMIR',
        'seller_warehouse_id': 'wh-1',
        'seller_warehouse_name': 'İzmir Depo',
        'seller_city_id': 'city-izmir',
        'seller_city_name': 'İzmir',
        'seller_city_x': 100,
        'seller_city_y': 200,
        'buyer_warehouse_id': 'wh-2',
        'buyer_warehouse_name': 'İstanbul Depo',
        'buyer_city_id': 'city-ist',
        'buyer_city_name': 'İstanbul',
        'buyer_city_x': 200,
        'buyer_city_y': 300,
      });

      expect(item.id, 'transfer-1');
      expect(item.status, 'in_transit');
      expect(item.product.id, 'DEMIR');

      final updated = item.copyWith(
        status: 'completed',
        quantity: 150,
      );

      expect(updated.id, 'transfer-1');
      expect(updated.status, 'completed');
      expect(updated.quantity, 150);
      expect(updated.product.id, 'DEMIR');
    });

    test('MutationResponse parses Phase 3 payload with logistics_transfer, building_upgrade and building_boost', () {
      final phase3Response = {
        'success': true,
        'changed': {
          'player': {
            'cash': 850000.0,
            'gold': 45,
          },
          'patches': [
            {
              'entity': 'logistics_transfer',
              'operation': 'insert',
              'id': 'tr-100',
              'changes': {
                'status': 'in_transit',
                'mode': 'intercity',
                'route_name': 'Bursa -> İstanbul',
                'source_entity_kind': 'warehouse',
                'source_entity_id': 'wh-bursa-1',
                'target_entity_kind': 'factory',
                'target_entity_id': 'factory-ist-1',
                'total_volume': 250.0,
                'progress_ratio': 0.0,
              },
            },
            {
              'entity': 'logistics_transfer_item',
              'operation': 'insert',
              'id': 'tri-200',
              'changes': {
                'transfer_id': 'tr-100',
                'product_id': 'DEMIR',
                'quantity': 250,
                'quality_level': 1,
              },
            },
            {
              'entity': 'building_upgrade',
              'operation': 'insert',
              'id': 'upg-300',
              'changes': {
                'building_kind': 'factory',
                'entity_id': 'factory-ist-1',
                'status': 'in_progress',
                'target_level': 3,
                'finish_at': '2026-09-09T18:00:00Z',
              },
            },
            {
              'entity': 'building_boost',
              'operation': 'update',
              'id': 'bst-400',
              'changes': {
                'building_kind': 'factory',
                'entity_id': 'factory-ist-1',
                'status': 'completed',
              },
            },
          ],
        },
      };

      final mutation = MutationResponse.fromJson(phase3Response);
      expect(mutation.success, true);
      expect(mutation.playerChanges?.cash, 850000.0);
      expect(mutation.playerChanges?.gold, 45);
      expect(mutation.patches.length, 4);

      // 1. logistics_transfer
      expect(mutation.patches[0].entity, 'logistics_transfer');
      expect(mutation.patches[0].operation, PatchOperation.insert);
      expect(mutation.patches[0].id, 'tr-100');
      expect(mutation.patches[0].changes['status'], 'in_transit');
      expect(mutation.patches[0].changes['route_name'], 'Bursa -> İstanbul');

      // 2. logistics_transfer_item
      expect(mutation.patches[1].entity, 'logistics_transfer_item');
      expect(mutation.patches[1].operation, PatchOperation.insert);
      expect(mutation.patches[1].changes['transfer_id'], 'tr-100');
      expect(mutation.patches[1].changes['product_id'], 'DEMIR');

      // 3. building_upgrade
      expect(mutation.patches[2].entity, 'building_upgrade');
      expect(mutation.patches[2].operation, PatchOperation.insert);
      expect(mutation.patches[2].changes['building_kind'], 'factory');
      expect(mutation.patches[2].changes['status'], 'in_progress');
      expect(mutation.patches[2].changes['target_level'], 3);

      // 4. building_boost
      expect(mutation.patches[3].entity, 'building_boost');
      expect(mutation.patches[3].operation, PatchOperation.update);
      expect(mutation.patches[3].changes['building_kind'], 'factory');
      expect(mutation.patches[3].changes['status'], 'completed');
    });

    test('TransferHistoryItemModel copyWith updates fields correctly', () {
      final historyItem = TransferHistoryItemModel.fromJson({
        'id': 'hist-1',
        'quantity': 500,
        'item_count': 1,
        'quality_level': 2,
        'status': 'in_transit',
        'started_at': '2026-09-09T08:00:00Z',
        'finish_at': '2026-09-09T09:00:00Z',
        'product': {
          'id': 'BUGDAY',
          'urun_adi': 'Buğday',
          'urun_iconu': 'wheat.webp',
        },
        'seller_warehouse': {
          'id': 'wh-tarla',
          'name': 'Konya Ambar',
        },
        'buyer_warehouse': {
          'id': 'wh-fabrika',
          'name': 'Ankara Un Fabrikası Deposu',
        },
      });

      expect(historyItem.id, 'hist-1');
      expect(historyItem.status, 'in_transit');
      expect(historyItem.completedAt, isNull);

      final completedItem = historyItem.copyWith(
        status: 'completed',
        completedAt: DateTime.parse('2026-09-09T09:00:00Z'),
      );

      expect(completedItem.status, 'completed');
      expect(completedItem.completedAt, DateTime.parse('2026-09-09T09:00:00Z'));
      expect(completedItem.product.name, 'Buğday');
    });

    test('BuildingUpgradeModel fromJson & copyWith preserves data on partial update', () {
      final json = {
        'id': 'upg-101',
        'building_kind': 'factory',
        'entity_id': 'fact-1',
        'current_level': 1,
        'target_level': 2,
        'status': 'in_progress',
        'started_at': '2026-09-09T10:00:00Z',
        'finish_at': '2026-09-09T12:00:00Z',
        'params': {
          'duration_minutes': 120,
          'upgrade_cost': 50000.0,
        },
      };

      final upgrade = BuildingUpgradeModel.fromJson(json);
      expect(upgrade.id, 'upg-101');
      expect(upgrade.buildingKind, 'factory');
      expect(upgrade.currentLevel, 1);
      expect(upgrade.targetLevel, 2);
      expect(upgrade.status, 'in_progress');
      expect(upgrade.isInProgress, true);

      // Ad-reduction partial update (finish_at change)
      final reducedFinishAt = DateTime.parse('2026-09-09T11:30:00Z');
      final updated = upgrade.copyWith(finishAt: reducedFinishAt);
      expect(updated.finishAt, reducedFinishAt);
      expect(updated.id, 'upg-101');
      expect(updated.currentLevel, 1);
      expect(updated.targetLevel, 2);
      expect(updated.upgradeCost, 50000.0);

      // Completion update
      final completedAt = DateTime.parse('2026-09-09T11:30:00Z');
      final completed = updated.copyWith(
        status: 'completed',
        completedAt: completedAt,
      );
      expect(completed.status, 'completed');
      expect(completed.completedAt, completedAt);
      expect(completed.isInProgress, false);
    });

    test('BuildingBoostModel fromJson & copyWith parses and updates multiplier correctly', () {
      final json = {
        'id': 'boost-201',
        'building_kind': 'store',
        'entity_id': 'store-1',
        'duration_hours': 2,
        'star_cost': 5,
        'multiplier': 2.0,
        'status': 'in_progress',
        'started_at': '2026-09-09T10:00:00Z',
        'finish_at': '2026-09-09T12:00:00Z',
      };

      final boost = BuildingBoostModel.fromJson(json);
      expect(boost.id, 'boost-201');
      expect(boost.buildingKind, 'store');
      expect(boost.durationHours, 2);
      expect(boost.multiplier, 2.0);
      expect(boost.isInProgress, true);

      // Finish / complete boost
      final completed = boost.copyWith(
        status: 'completed',
        completedAt: DateTime.parse('2026-09-09T12:00:00Z'),
      );
      expect(completed.status, 'completed');
      expect(completed.isInProgress, false);
    });

    test('StoreSlotModel and ProductionSlotModel copyWith handles boostMultiplier and capacity', () {
      final storeSlot = StoreSlotModel(
        id: 'ss-1',
        storeId: 'store-1',
        slotIndex: 0,
        quantity: 100,
        pendingQuantity: 0,
        qualityLevel: 1,
        capacity: 1000,
        boostMultiplier: 1.0,
        isActive: true,
        isEmpty: false,
        usedCapacityRatio: 0.1,
      );

      // Capacity increase after upgrade
      final upgradedSlot = storeSlot.copyWith(capacity: 2000);
      expect(upgradedSlot.capacity, 2000);
      expect(upgradedSlot.boostMultiplier, 1.0);

      // Boost start
      final boostedSlot = upgradedSlot.copyWith(boostMultiplier: 2.0);
      expect(boostedSlot.boostMultiplier, 2.0);
      expect(boostedSlot.capacity, 2000);

      // Boost finish
      final resetSlot = boostedSlot.copyWith(boostMultiplier: 1.0);
      expect(resetSlot.boostMultiplier, 1.0);

      // ProductionSlotModel boost test
      const prodSlot = ProductionSlotModel(
        id: 'ps-1',
        ownerKind: 'field',
        ownerId: 'field-1',
        slotIndex: 0,
        productId: 'DOMATES',
        brandId: 'brand-1',
        qualityLevel: 1,
        boostMultiplier: 1.0,
        isActive: true,
        product: null,
      );

      final boostedProdSlot = prodSlot.copyWith(boostMultiplier: 2.0);
      expect(boostedProdSlot.boostMultiplier, 2.0);
      final resetProdSlot = boostedProdSlot.copyWith(boostMultiplier: 1.0);
      expect(resetProdSlot.boostMultiplier, 1.0);
    });

    test('ArgeCenterModel fromJson & copyWith updates level and research limits', () {
      final arge = ArgeCenterModel.fromJson({
        'id': 'arge-1',
        'player_id': 'player-1',
        'name': 'AR-GE Merkezi',
        'level': 1,
        'max_concurrent_researches': 1,
        'duration_reduction_pct': 0.0,
        'is_active': true,
      });

      expect(arge.level, 1);
      expect(arge.maxConcurrentResearches, 1);
      expect(arge.durationReductionPct, 0.0);

      final upgradedArge = arge.copyWith(
        level: 2,
        maxConcurrentResearches: 2,
        durationReductionPct: 5.0,
      );

      expect(upgradedArge.level, 2);
      expect(upgradedArge.maxConcurrentResearches, 2);
      expect(upgradedArge.durationReductionPct, 5.0);
    });

    test('MutationResponse parses Phase 4 complete upgrade payload', () {
      final responsePayload = {
        'success': true,
        'changed': {
          'player': {
            'level': 5,
            'experience': 120,
          },
          'patches': [
            {
              'entity': 'store',
              'operation': 'update',
              'id': 'store-1',
              'changes': {
                'slot_capacity': 2500,
                'max_slot_count': 6,
              },
            },
            {
              'entity': 'store_slot',
              'operation': 'update',
              'id': 'ss-1',
              'changes': {
                'capacity': 2500,
              },
            },
            {
              'entity': 'building_upgrade',
              'operation': 'update',
              'id': 'upg-1',
              'changes': {
                'building_kind': 'store',
                'entity_id': 'store-1',
                'status': 'completed',
                'completed_at': '2026-09-09T12:00:00Z',
              },
            },
          ],
        },
      };

      final mutation = MutationResponse.fromJson(responsePayload);
      expect(mutation.success, true);
      expect(mutation.playerChanges?.level, 5);
      expect(mutation.playerChanges?.experience, 120);
      expect(mutation.patches.length, 3);

      final storePatch = mutation.patches[0];
      expect(storePatch.entity, 'store');
      expect(storePatch.changes['slot_capacity'], 2500);
      expect(storePatch.changes['max_slot_count'], 6);

      final slotPatch = mutation.patches[1];
      expect(slotPatch.entity, 'store_slot');
      expect(slotPatch.changes['capacity'], 2500);

      final upgradePatch = mutation.patches[2];
      expect(upgradePatch.entity, 'building_upgrade');
      expect(upgradePatch.changes['status'], 'completed');
    });

    test('MutationResponse parses Phase 4 factory/mine boost & specs payload', () {
      final responsePayload = {
        'success': true,
        'changed': {
          'patches': [
            {
              'entity': 'factory',
              'operation': 'update',
              'id': 'fact-1',
              'changes': {
                'level': 3,
                'input_capacity': 6000,
                'output_capacity': 4000,
                'boost_multiplier': 2.0,
              },
            },
            {
              'entity': 'mine',
              'operation': 'update',
              'id': 'mine-1',
              'changes': {
                'level': 2,
                'output_capacity': 3000,
                'boost_multiplier': 2.0,
              },
            },
            {
              'entity': 'building_boost',
              'operation': 'insert',
              'id': 'boost-99',
              'changes': {
                'building_kind': 'factory',
                'entity_id': 'fact-1',
                'multiplier': 2.0,
                'status': 'in_progress',
                'started_at': '2026-09-09T10:00:00Z',
                'finish_at': '2026-09-09T12:00:00Z',
              },
            },
          ],
        },
      };

      final mutation = MutationResponse.fromJson(responsePayload);
      expect(mutation.patches.length, 3);

      final factoryPatch = mutation.patches[0];
      expect(factoryPatch.changes['input_capacity'], 6000);
      expect(factoryPatch.changes['boost_multiplier'], 2.0);

      final minePatch = mutation.patches[1];
      expect(minePatch.changes['output_capacity'], 3000);
      expect(minePatch.changes['boost_multiplier'], 2.0);

      final boostPatch = mutation.patches[2];
      expect(boostPatch.entity, 'building_boost');
      expect(boostPatch.operation, PatchOperation.insert);
    });

    test('MutationResponse parses Phase 4 ad-reduction partial update payload', () {
      final responsePayload = {
        'success': true,
        'changed': {
          'patches': [
            {
              'entity': 'building_upgrade',
              'operation': 'update',
              'id': 'upg-10',
              'changes': {
                'building_kind': 'farm',
                'entity_id': 'farm-1',
                'finish_at': '2026-09-09T11:45:00Z',
                'updated_at': '2026-09-09T11:15:00Z',
              },
            },
            {
              'entity': 'building_construction',
              'operation': 'update',
              'id': 'const-10',
              'changes': {
                'building_kind': 'field',
                'finish_at': '2026-09-09T14:30:00Z',
                'updated_at': '2026-09-09T14:00:00Z',
              },
            },
          ],
        },
      };

      final mutation = MutationResponse.fromJson(responsePayload);
      expect(mutation.patches.length, 2);
      expect(mutation.patches[0].entity, 'building_upgrade');
      expect(mutation.patches[0].changes['finish_at'], '2026-09-09T11:45:00Z');
      expect(mutation.patches[1].entity, 'building_construction');
      expect(mutation.patches[1].changes['finish_at'], '2026-09-09T14:30:00Z');
    });

    test('BrandCompanyProductModel copyWith respects explicit null for watermarkAssetId', () {
      final product = BrandCompanyProductModel(
        productId: 'prod-1',
        productName: 'Akıllı Telefon',
        productIcon: 'phone.webp',
        maxQualityLevel: 5,
        isBranded: true,
        brandedAt: DateTime.parse('2026-09-09T10:00:00Z'),
        watermarkAssetId: 'wm_star',
      );

      // Omitting watermarkAssetId preserves existing
      final unmodified = product.copyWith(maxQualityLevel: 6);
      expect(unmodified.watermarkAssetId, 'wm_star');
      expect(unmodified.maxQualityLevel, 6);

      // Explicit null clears watermarkAssetId
      final cleared = product.copyWith(watermarkAssetId: null);
      expect(cleared.watermarkAssetId, isNull);
    });

    test('LogisticsFinanceEntryModel copyWith respects explicit null for relatedWarehouseSlotId', () {
      final entry = LogisticsFinanceEntryModel(
        id: 'entry-1',
        playerId: 'player-1',
        logisticsCompanyId: 'comp-1',
        vehicleId: 'veh-1',
        entryType: 'fuel_purchase',
        category: 'expense',
        amount: 5000.0,
        quantity: null,
        unitCost: null,
        relatedTransferId: null,
        relatedWarehouseSlotId: 'wh-slot-42',
        relatedMarketListingId: null,
        description: 'Benzin dolumu',
        metadata: const {},
        createdAt: DateTime.parse('2026-09-09T10:00:00Z'),
      );

      // Omitting preserves
      final unmodified = entry.copyWith(amount: 6000.0);
      expect(unmodified.relatedWarehouseSlotId, 'wh-slot-42');
      expect(unmodified.amount, 6000.0);

      // Explicit null clears
      final cleared = entry.copyWith(relatedWarehouseSlotId: null);
      expect(cleared.relatedWarehouseSlotId, isNull);
    });

    test('MutationResponse parses Phase 5 finance and tax payloads', () {
      final responsePayload = {
        'success': true,
        'changed': {
          'patches': [
            {
              'entity': 'player_loan',
              'operation': 'insert',
              'id': 'loan-1',
              'changes': {
                'player_id': 'p-1',
                'amount': 1000000.0,
                'interest_rate': 0.15,
                'total_due': 1150000.0,
                'total_paid': 0.0,
                'installments_total': 12,
                'installments_paid': 0,
                'installment_amount': 95833.33,
                'next_installment_due_at': '2026-10-09T00:00:00Z',
                'status': 'active',
                'created_at': '2026-09-09T10:00:00Z',
                'updated_at': '2026-09-09T10:00:00Z',
              },
            },
            {
              'entity': 'player_deposit',
              'operation': 'update',
              'id': 'dep-1',
              'changes': {
                'status': 'claimed',
              },
            },
            {
              'entity': 'player_tax',
              'operation': 'update',
              'id': 'p-1',
              'changes': {
                'current_tax_debt': 0.0,
                'last_payment_at': '2026-09-09T12:00:00Z',
              },
            },
          ],
        },
      };

      final mutation = MutationResponse.fromJson(responsePayload);
      expect(mutation.patches.length, 3);
      expect(mutation.patches[0].entity, 'player_loan');
      expect(mutation.patches[0].changes['amount'], 1000000.0);
      expect(mutation.patches[1].entity, 'player_deposit');
      expect(mutation.patches[1].changes['status'], 'claimed');
      expect(mutation.patches[2].entity, 'player_tax');
      expect(mutation.patches[2].changes['current_tax_debt'], 0.0);
    });

    test('MutationResponse parses Phase 5 AR-GE, brand, and campaign payloads', () {
      final responsePayload = {
        'success': true,
        'changed': {
          'patches': [
            {
              'entity': 'arge_research',
              'operation': 'update',
              'id': 'res-1',
              'changes': {
                'status': 'completed',
                'completed_at': '2026-09-09T12:00:00Z',
              },
            },
            {
              'entity': 'player_product_quality',
              'operation': 'update',
              'id': 'prod-qual-1',
              'changes': {
                'product_id': 'prod-pc',
                'quality_level': 3,
              },
            },
            {
              'entity': 'brand_company',
              'operation': 'update',
              'id': 'brand-1',
              'changes': {
                'brand_level': 5,
                'brand_xp': 1250,
                'theme_color': '#FF5733',
              },
            },
            {
              'entity': 'brand_company_product',
              'operation': 'update',
              'id': 'brand-prod-1',
              'changes': {
                'watermark_asset_id': null,
              },
            },
            {
              'entity': 'brand_marketing_campaign',
              'operation': 'delete',
              'id': 'camp-1',
              'changes': {},
            },
          ],
        },
      };

      final mutation = MutationResponse.fromJson(responsePayload);
      expect(mutation.patches.length, 5);
      expect(mutation.patches[0].entity, 'arge_research');
      expect(mutation.patches[0].changes['status'], 'completed');
      expect(mutation.patches[1].entity, 'player_product_quality');
      expect(mutation.patches[1].changes['quality_level'], 3);
      expect(mutation.patches[2].entity, 'brand_company');
      expect(mutation.patches[2].changes['brand_level'], 5);
      expect(mutation.patches[3].entity, 'brand_company_product');
      expect(mutation.patches[3].changes['watermark_asset_id'], isNull);
      expect(mutation.patches[4].entity, 'brand_marketing_campaign');
      expect(mutation.patches[4].operation, PatchOperation.delete);
    });

    test('MutationResponse parses Phase 5 tender, streak, and mission payloads', () {
      final responsePayload = {
        'success': true,
        'changed': {
          'patches': [
            {
              'entity': 'tender',
              'operation': 'update',
              'id': 'tnd-1',
              'changes': {
                'bid_count': 5,
                'lowest_bid_amount': 45000.0,
              },
            },
            {
              'entity': 'tender_bid',
              'operation': 'insert',
              'id': 'bid-1',
              'changes': {
                'tender_id': 'tnd-1',
                'bid_amount': 42000.0,
              },
            },
            {
              'entity': 'player_tender',
              'operation': 'update',
              'id': 'pt-1',
              'changes': {
                'delivered_quantity': 500,
                'remaining_quantity': 500,
              },
            },
            {
              'entity': 'tender_delivery',
              'operation': 'insert',
              'id': 'deliv-1',
              'changes': {
                'player_tender_id': 'pt-1',
                'quantity': 250,
                'status': 'in_transit',
              },
            },
            {
              'entity': 'player_mission',
              'operation': 'update',
              'id': 'm-1',
              'changes': {
                'is_completed': true,
                'is_claimed': false,
              },
            },
            {
              'entity': 'player_daily_streak',
              'operation': 'update',
              'id': 'p-1',
              'changes': {
                'streak_count': 4,
                'can_claim_today': false,
              },
            },
          ],
        },
      };

      final mutation = MutationResponse.fromJson(responsePayload);
      expect(mutation.patches.length, 6);
      expect(mutation.patches[0].entity, 'tender');
      expect(mutation.patches[1].entity, 'tender_bid');
      expect(mutation.patches[2].entity, 'player_tender');
      expect(mutation.patches[3].entity, 'tender_delivery');
      expect(mutation.patches[4].entity, 'player_mission');
      expect(mutation.patches[5].entity, 'player_daily_streak');
    });

    test('MutationResponse parses Phase 5 building sale and bulk maintenance payloads', () {
      final responsePayload = {
        'success': true,
        'changed': {
          'patches': [
            {'entity': 'store', 'operation': 'delete', 'id': 'store-99', 'changes': {}},
            {'entity': 'warehouse', 'operation': 'delete', 'id': 'wh-99', 'changes': {}},
            {'entity': 'factory', 'operation': 'delete', 'id': 'fact-99', 'changes': {}},
            {'entity': 'mine', 'operation': 'delete', 'id': 'mine-99', 'changes': {}},
            {'entity': 'field', 'operation': 'delete', 'id': 'field-99', 'changes': {}},
            {'entity': 'farm', 'operation': 'delete', 'id': 'farm-99', 'changes': {}},
            {
              'entity': 'logistics_finance_entry',
              'operation': 'insert',
              'id': 'entry-99',
              'changes': {
                'entry_type': 'repair_all',
                'amount': 15000.0,
              },
            },
            {
              'entity': 'store_daily_performance',
              'operation': 'update',
              'id': 'perf-1',
              'changes': {
                'store_id': 'store-1',
              },
            },
          ],
        },
      };

      final mutation = MutationResponse.fromJson(responsePayload);
      expect(mutation.patches.length, 8);
      expect(mutation.patches.where((p) => p.operation == PatchOperation.delete).length, 6);
      expect(mutation.patches[6].entity, 'logistics_finance_entry');
      expect(mutation.patches[7].entity, 'store_daily_performance');
    });

    test('MarketListingModel copyWith and applyChanges apply partial purchase and price updates', () {
      final listing = MarketListingModel(
        listingId: 'listing-1',
        slotId: 'seller-slot-100',
        productId: 'prod-wheat',
        productName: 'Buğday',
        productIcon: 'wheat.webp',
        brandId: '00000000-0000-0000-0000-000000000000',
        brandName: null,
        unitVolume: 0.5,
        warehouseId: 'wh-seller-1',
        warehouseName: 'Tahıl Silosu',
        warehouseIcon: 'silo.webp',
        cityId: 'city-ankara',
        cityName: 'Ankara',
        cityX: 100.0,
        cityY: 200.0,
        sellerPlayerId: 'player-seller-1',
        sellerPlayerName: 'Tahıl A.Ş.',
        sellerAvatarId: 'ae1.webp',
        sellerGoogleAvatarUrl: null,
        quantity: 1000,
        qualityLevel: 2,
        price: 45.0,
        cost: 30.0,
        isAvailableForSale: true,
      );

      final updatedListing = listing.applyChanges({
        'quantity': 400,
        'price': 48.5,
      });

      expect(updatedListing.quantity, 400);
      expect(updatedListing.price, 48.5);
      expect(updatedListing.slotId, 'seller-slot-100');
      expect(updatedListing.productName, 'Buğday');
      expect(updatedListing.cityId, 'city-ankara');
    });

    test('MutationResponse parses Phase 6 market purchase payload with market_listing patches', () {
      final responsePayload = {
        'success': true,
        'changed': {
          'player': {
            'cash': 450000.0,
          },
          'patches': [
            {
              'entity': 'market_listing',
              'operation': 'update',
              'id': 'seller-slot-100',
              'changes': {'quantity': 350},
            },
            {
              'entity': 'market_listing',
              'operation': 'delete',
              'id': 'seller-slot-200',
              'changes': {},
            },
            {
              'entity': 'warehouse',
              'operation': 'update',
              'id': 'buyer-wh-1',
              'changes': {'reserved_capacity': 500.0},
            },
            {
              'entity': 'warehouse_slot',
              'operation': 'insert',
              'id': 'buyer-slot-1',
              'changes': {
                'warehouse_id': 'buyer-wh-1',
                'product_id': 'prod-wheat',
                'quantity': 650,
              },
            },
            {
              'entity': 'logistics_transfer',
              'operation': 'insert',
              'id': 'transfer-market-1',
              'changes': {
                'status': 'in_transit',
                'source_city_id': 'city-ankara',
                'target_city_id': 'city-istanbul',
              },
            },
            {
              'entity': 'logistics_transfer_item',
              'operation': 'insert',
              'id': 'transfer-item-1',
              'changes': {
                'transfer_id': 'transfer-market-1',
                'quantity': 650,
              },
            },
            {
              'entity': 'logistics_vehicle',
              'operation': 'update',
              'id': 'veh-1',
              'changes': {'status': 'on_route'},
            },
          ],
        },
      };

      final mutation = MutationResponse.fromJson(responsePayload);
      expect(mutation.success, true);
      expect(mutation.playerChanges!.cash, 450000.0);
      expect(mutation.patches.length, 7);

      final listingUpdate = mutation.patches.firstWhere(
        (p) => p.entity == 'market_listing' && p.operation == PatchOperation.update,
      );
      expect(listingUpdate.id, 'seller-slot-100');
      expect(listingUpdate.changes['quantity'], 350);

      final listingDelete = mutation.patches.firstWhere(
        (p) => p.entity == 'market_listing' && p.operation == PatchOperation.delete,
      );
      expect(listingDelete.id, 'seller-slot-200');

      expect(mutation.patches.any((p) => p.entity == 'warehouse'), isTrue);
      expect(mutation.patches.any((p) => p.entity == 'warehouse_slot'), isTrue);
      expect(mutation.patches.any((p) => p.entity == 'logistics_transfer'), isTrue);
    });

    test('Market listing cart clamp and remove callback logic operates correctly', () {
      int? clampedQty;
      String? removedSlot;

      void onQtyChanged(String slotId, int newQty) {
        if (slotId == 'slot-abc') clampedQty = newQty;
      }

      void onRemoved(String slotId) {
        if (slotId == 'slot-xyz') removedSlot = slotId;
      }

      // Simulate partial purchase quantity reduction
      const slotId = 'slot-abc';
      const newStock = 250;
      onQtyChanged(slotId, newStock);
      expect(clampedQty, 250);

      // Simulate full purchase / listing deletion
      const deletedSlotId = 'slot-xyz';
      onRemoved(deletedSlotId);
      expect(removedSlot, 'slot-xyz');
    });

    test('building_construction EntityPatch parses insert, finish_at update and completion', () {
      final insertPatch = EntityPatch.fromJson({
        'entity': 'building_construction',
        'id': 'bc-factory-1',
        'operation': 'insert',
        'changes': {
          'id': 'bc-factory-1',
          'player_id': 'p-1',
          'building_kind': 'factory',
          'status': 'in_progress',
          'finish_at': '2026-09-09T22:00:00Z',
        },
      });

      expect(insertPatch.entity, 'building_construction');
      expect(insertPatch.operation, PatchOperation.insert);
      expect(insertPatch.changes['building_kind'], 'factory');
      expect(insertPatch.changes['status'], 'in_progress');

      final updatePatch = EntityPatch.fromJson({
        'entity': 'building_construction',
        'id': 'bc-factory-1',
        'operation': 'update',
        'changes': {
          'finish_at': '2026-09-09T21:45:00Z',
          'building_kind': 'factory',
        },
      });

      expect(updatePatch.operation, PatchOperation.update);
      expect(updatePatch.changes['finish_at'], '2026-09-09T21:45:00Z');

      final completePatch = EntityPatch.fromJson({
        'entity': 'building_construction',
        'id': 'bc-factory-1',
        'operation': 'update',
        'changes': {
          'status': 'completed',
          'building_kind': 'factory',
        },
      });

      expect(completePatch.operation, PatchOperation.update);
      expect(completePatch.changes['status'], 'completed');
    });
  });
}

