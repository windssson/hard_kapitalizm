import 'package:flutter_test/flutter_test.dart';
import 'package:hard_kapitalizm/core/models/mutation/entity_patch.dart';
import 'package:hard_kapitalizm/core/models/mutation/mutation_response.dart';
import 'package:hard_kapitalizm/features/store/models/store_model.dart';
import 'package:hard_kapitalizm/features/warehouse/models/warehouse_model.dart';
import 'package:hard_kapitalizm/features/logistics/models/logistics_company_model.dart';
import 'package:hard_kapitalizm/features/transfer_map/models/transfer_map_item_model.dart';

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
  });
}

