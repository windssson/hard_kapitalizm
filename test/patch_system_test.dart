import 'package:flutter_test/flutter_test.dart';
import 'package:hard_kapitalizm/core/models/mutation/entity_patch.dart';
import 'package:hard_kapitalizm/core/models/mutation/mutation_response.dart';
import 'package:hard_kapitalizm/features/store/models/store_model.dart';
import 'package:hard_kapitalizm/features/warehouse/models/warehouse_model.dart';
import 'package:hard_kapitalizm/features/logistics/models/logistics_company_model.dart';

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
  });
}

