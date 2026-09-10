import 'package:flutter_test/flutter_test.dart';
import 'package:hard_kapitalizm/core/models/mutation/entity_patch.dart';
import 'package:hard_kapitalizm/core/models/mutation/mutation_response.dart';
import 'package:hard_kapitalizm/features/store/models/store_model.dart';
import 'package:hard_kapitalizm/features/warehouse/models/warehouse_model.dart';

void main() {
  group('Patch integrity regressions', () {
    test('unknown patch operation is rejected instead of guessed as update', () {
      expect(
        () => EntityPatch.fromJson({
          'entity': 'store_slot',
          'id': 'slot-1',
          'operation': 'upsert_magic',
          'changes': {'quantity': 5},
        }),
        throwsFormatException,
      );
    });

    test('one malformed patch does not drop valid patches or player changes', () {
      final response = MutationResponse.fromJson({
        'success': true,
        'changed': {
          'player': {'cash': 12345.0},
          'dashboard_dirty': true,
          'history_dirty': true,
          'performance_dirty': true,
          'patches': [
            {
              'entity': 'store_slot',
              'id': 'good-1',
              'operation': 'update',
              'changes': {'quantity': 12},
            },
            {
              'entity': 'warehouse_slot',
              'id': 'bad-1',
              'operation': 'future_unknown_operation',
              'changes': {'quantity': 99},
            },
            {
              'entity': 'warehouse',
              'id': 'good-2',
              'operation': 'update',
              'changes': {'reserved_capacity': 2.5},
            },
          ],
        },
      });

      expect(response.playerChanges?.cash, 12345.0);
      expect(response.dashboardDirty, isTrue);
      expect(response.historyDirty, isTrue);
      expect(response.performanceDirty, isTrue);
      expect(response.patches.map((p) => p.id).toList(), ['good-1', 'good-2']);
    });

    test('malformed patch without id is skipped independently', () {
      final response = MutationResponse.fromJson({
        'success': true,
        'changed': {
          'patches': [
            {
              'entity': 'store',
              'operation': 'update',
              'changes': {'level': 2},
            },
            {
              'entity': 'store',
              'id': 'store-2',
              'operation': 'update',
              'changes': {'level': 3},
            },
          ],
        },
      });

      expect(response.patches, hasLength(1));
      expect(response.patches.single.id, 'store-2');
    });

    test('warehouse slot product id change clears stale metadata', () {
      final old = WarehouseSlotModel(
        id: 'wh-slot',
        productId: 'DOMATES',
        productName: 'Domates',
        productIcon: 'domates.webp',
        quantity: 10,
        qualityLevel: 1,
      );

      final changed = old.copyWith(productId: 'BIBER');

      expect(changed.productId, 'BIBER');
      expect(changed.productName, isNull);
      expect(changed.productIcon, isNull);
    });

    test('warehouse slot ordinary quantity patch preserves product metadata', () {
      final old = WarehouseSlotModel(
        id: 'wh-slot',
        productId: 'DOMATES',
        productName: 'Domates',
        productIcon: 'domates.webp',
        quantity: 10,
        qualityLevel: 1,
      );

      final changed = old.copyWith(quantity: 9);

      expect(changed.productId, 'DOMATES');
      expect(changed.productName, 'Domates');
      expect(changed.productIcon, 'domates.webp');
    });

    test('store slot product change rejects old metadata fallback', () {
      final old = StoreSlotModel(
        id: 'store-slot',
        storeId: 'store-1',
        slotIndex: 1,
        productId: 'DOMATES',
        productName: 'Domates',
        productIcon: 'domates.webp',
        quantity: 10,
        pendingQuantity: 0,
        qualityLevel: 1,
        capacity: 100,
        boostMultiplier: 1,
        isActive: true,
        isEmpty: false,
        usedCapacityRatio: 0.1,
      );

      // Dispatcher katalog hazır değilken eski metadata'yı fallback olarak
      // gönderebilir. Ürün ID değiştiyse bu metadata taşınmamalıdır.
      final changed = old.copyWith(
        productId: 'BIBER',
        productName: old.productName,
        productIcon: old.productIcon,
        product: null,
      );

      expect(changed.productId, 'BIBER');
      expect(changed.productName, isNull);
      expect(changed.productIcon, isNull);
      expect(changed.product, isNull);
    });

    test('store slot product change keeps genuinely new metadata', () {
      final old = StoreSlotModel(
        id: 'store-slot',
        storeId: 'store-1',
        slotIndex: 1,
        productId: 'DOMATES',
        productName: 'Domates',
        productIcon: 'domates.webp',
        quantity: 10,
        pendingQuantity: 0,
        qualityLevel: 1,
        capacity: 100,
        boostMultiplier: 1,
        isActive: true,
        isEmpty: false,
        usedCapacityRatio: 0.1,
      );

      final changed = old.copyWith(
        productId: 'BIBER',
        productName: 'Biber',
        productIcon: 'biber.webp',
        quantity: 0,
      );

      expect(changed.productId, 'BIBER');
      expect(changed.productName, 'Biber');
      expect(changed.productIcon, 'biber.webp');
    });
  });
}
