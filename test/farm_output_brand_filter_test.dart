import 'package:flutter_test/flutter_test.dart';
import 'package:hard_kapitalizm/features/farm/models/farm_detail_model.dart';
import 'package:hard_kapitalizm/features/farm/models/farm_model.dart';

void main() {
  test('farm output inventory only includes the configured slot brand', () {
    final now = DateTime.utc(2026, 9, 11);
    const branded = '11111111-1111-1111-1111-111111111111';
    const unbranded = '00000000-0000-0000-0000-000000000000';

    final detail = FarmDetailModel(
      farm: FarmModel(
        id: 'farm-1',
        playerId: 'player-1',
        farmTypeId: 'farm-type-1',
        cityId: 'city-1',
        name: 'Test Tarla',
        level: 1,
        currentSlotCount: 1,
        maxSlotCount: 3,
        inputCapacity: 100,
        outputCapacity: 100,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
      farmType: const FarmTypeDetailModel(
        id: 'farm-type-1',
        name: 'Sebze Tarlası',
        icon: 'farm.webp',
        acceptedProductIds: ['DOMATES'],
        maxSlotCount: 3,
        inputCapacity: 100,
        outputCapacity: 100,
        cost: 0,
        constructionTimeMinutes: 0,
      ),
      cityName: 'İstanbul',
      slots: const [
        FarmProductionSlotModel(
          id: 'slot-1',
          ownerKind: 'farm',
          ownerId: 'farm-1',
          slotIndex: 1,
          productId: 'DOMATES',
          brandId: branded,
          qualityLevel: 4,
          boostMultiplier: 1,
          isActive: true,
          product: null,
        ),
      ],
      inventories: const [
        FarmProductionInventoryModel(
          id: 'branded-output',
          ownerKind: 'farm',
          ownerId: 'farm-1',
          inventoryType: 'output',
          productId: 'DOMATES',
          brandId: branded,
          qualityLevel: 4,
          quantity: 20,
          pendingQuantity: 0,
          cost: 0,
          unitVolume: 1,
          product: null,
        ),
        FarmProductionInventoryModel(
          id: 'unbranded-output',
          ownerKind: 'farm',
          ownerId: 'farm-1',
          inventoryType: 'output',
          productId: 'DOMATES',
          brandId: unbranded,
          qualityLevel: 4,
          quantity: 30,
          pendingQuantity: 0,
          cost: 0,
          unitVolume: 1,
          product: null,
        ),
      ],
    );

    expect(detail.outputInventories.map((item) => item.id), ['branded-output']);
  });
}
