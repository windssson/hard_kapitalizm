import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hard_kapitalizm/core/data/industrial_production_slot_patch_service.dart';
import 'package:hard_kapitalizm/core/models/production_slot_model.dart';

void main() {
  test('registry inserts, updates, clears and removes factory slots', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final registry = container.read(
      industrialProductionSlotRegistryProvider.notifier,
    );

    const owner = (ownerKind: 'factory', ownerId: 'factory-1');
    registry.insert(
      const ProductionSlotContractModel(
        id: 'slot-2',
        ownerKind: 'factory',
        ownerId: 'factory-1',
        slotIndex: 2,
        productId: 'GUBRE',
        brandId: 'brand-1',
        qualityLevel: 4,
        boostMultiplier: 1,
        isActive: true,
        product: null,
      ),
    );

    var slots = container.read(industrialProductionSlotsProvider(owner));
    expect(slots, hasLength(1));
    expect(slots.single.productId, 'GUBRE');

    registry.update(
      slotId: 'slot-2',
      changes: const {
        'owner_kind': 'factory',
        'owner_id': 'factory-1',
        'is_active': false,
        'boost_multiplier': 2,
      },
    );
    slots = container.read(industrialProductionSlotsProvider(owner));
    expect(slots.single.isActive, isFalse);
    expect(slots.single.boostMultiplier, 2);

    registry.update(
      slotId: 'slot-2',
      changes: const {
        'owner_kind': 'factory',
        'owner_id': 'factory-1',
        'product_id': null,
        'quality_level': 0,
        'brand_id': ProductionSlotContractModel.zeroBrandId,
      },
    );
    slots = container.read(industrialProductionSlotsProvider(owner));
    expect(slots.single.productId, isNull);
    expect(slots.single.qualityLevel, 0);
    expect(slots.single.brandId, ProductionSlotContractModel.zeroBrandId);

    registry.remove(slotId: 'slot-2');
    slots = container.read(industrialProductionSlotsProvider(owner));
    expect(slots, isEmpty);
  });

  test('registry keeps factory and mine slots isolated and sorted', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final registry = container.read(
      industrialProductionSlotRegistryProvider.notifier,
    );

    registry.seed(
      ownerKind: 'factory',
      ownerId: 'factory-1',
      slots: const [
        ProductionSlotContractModel(
          id: 'slot-3',
          ownerKind: 'factory',
          ownerId: 'factory-1',
          slotIndex: 3,
          productId: null,
          brandId: ProductionSlotContractModel.zeroBrandId,
          qualityLevel: 0,
          boostMultiplier: 1,
          isActive: true,
          product: null,
        ),
        ProductionSlotContractModel(
          id: 'slot-1',
          ownerKind: 'factory',
          ownerId: 'factory-1',
          slotIndex: 1,
          productId: null,
          brandId: ProductionSlotContractModel.zeroBrandId,
          qualityLevel: 0,
          boostMultiplier: 1,
          isActive: true,
          product: null,
        ),
      ],
    );
    registry.seed(
      ownerKind: 'mine',
      ownerId: 'mine-1',
      slots: const [
        ProductionSlotContractModel(
          id: 'mine-slot-1',
          ownerKind: 'mine',
          ownerId: 'mine-1',
          slotIndex: 1,
          productId: null,
          brandId: ProductionSlotContractModel.zeroBrandId,
          qualityLevel: 0,
          boostMultiplier: 1,
          isActive: true,
          product: null,
        ),
      ],
    );

    final factorySlots = container.read(
      industrialProductionSlotsProvider(
        (ownerKind: 'factory', ownerId: 'factory-1'),
      ),
    );
    final mineSlots = container.read(
      industrialProductionSlotsProvider(
        (ownerKind: 'mine', ownerId: 'mine-1'),
      ),
    );

    expect(factorySlots.map((slot) => slot.slotIndex), [1, 3]);
    expect(mineSlots.single.id, 'mine-slot-1');
  });
}
