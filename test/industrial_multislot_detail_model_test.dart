import 'package:flutter_test/flutter_test.dart';
import 'package:hard_kapitalizm/core/models/product_model.dart';
import 'package:hard_kapitalizm/core/models/production_slot_model.dart';
import 'package:hard_kapitalizm/features/factory/models/factory_detail_model.dart';
import 'package:hard_kapitalizm/features/factory/models/factory_model.dart';
import 'package:hard_kapitalizm/features/mine/models/mine_detail_model.dart';
import 'package:hard_kapitalizm/features/mine/models/mine_model.dart';

const zeroBrand = ProductionSlotContractModel.zeroBrandId;
const brandA = '11111111-1111-1111-1111-111111111111';

ProductModel product(
  String id, {
  String? input1,
  String? input2,
}) {
  return ProductModel(
    id: id,
    urunAdi: id,
    urunIconu: '$id.webp',
    birimHacim: 1,
    birimAgirlik: 1,
    hammadde1Id: input1,
    hammadde1Miktar: input1 == null ? null : 1,
    hammadde2Id: input2,
    hammadde2Miktar: input2 == null ? null : 1,
    bazSatisFiyati: 100,
    uretimAdedi: 10,
    satisAdedi: 0,
    enDusukFiyat: 0,
    enYuksekFiyat: 0,
    ortalamaFiyat: 0,
    saticiSayisi: 0,
    piyasadakiStok: 0,
    createdAt: DateTime.utc(2026),
  );
}

ProductionSlotContractModel slot({
  required String id,
  required String ownerKind,
  required String ownerId,
  required int index,
  required ProductModel product,
  required int quality,
  required String brand,
  bool active = true,
}) {
  return ProductionSlotContractModel(
    id: id,
    ownerKind: ownerKind,
    ownerId: ownerId,
    slotIndex: index,
    productId: product.id,
    brandId: brand,
    qualityLevel: quality,
    boostMultiplier: 1,
    isActive: active,
    product: product,
  );
}

void main() {
  test('factory inventories follow every configured slot quality and brand', () {
    final tomatoPaste = product('SALCA', input1: 'DOMATES');
    final bread = product('EKMEK', input1: 'UN');
    final now = DateTime.utc(2026);
    const factoryId = 'factory-1';

    final detail = FactoryDetailModel(
      factory: FactoryModel(
        id: factoryId,
        playerId: 'player-1',
        factoryTypeId: 'type-1',
        cityId: 'city-1',
        name: 'Test Fabrika',
        level: 1,
        qualityLevel: 1,
        inputCapacity: 1000,
        outputCapacity: 1000,
        boostMultiplier: 1,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
      factoryType: const FactoryTypeDetailModel(
        id: 'type-1',
        name: 'Test',
        icon: 'factory.webp',
        acceptedProductIds: ['SALCA', 'EKMEK'],
        maxSlotCount: 3,
        inputCapacity: 1000,
        outputCapacity: 1000,
        cost: 100,
        constructionTimeMinutes: 1,
      ),
      cityName: 'Test Şehir',
      product: tomatoPaste,
      productionSlots: [
        slot(
          id: 'slot-1',
          ownerKind: 'factory',
          ownerId: factoryId,
          index: 1,
          product: tomatoPaste,
          quality: 3,
          brand: brandA,
        ),
        slot(
          id: 'slot-2',
          ownerKind: 'factory',
          ownerId: factoryId,
          index: 2,
          product: bread,
          quality: 1,
          brand: zeroBrand,
        ),
      ],
      inventories: [
        FactoryProductionInventoryModel(
          id: 'in-tomato-q2',
          ownerKind: 'factory',
          ownerId: factoryId,
          inventoryType: 'input',
          productId: 'DOMATES',
          brandId: zeroBrand,
          qualityLevel: 2,
          quantity: 10,
          pendingQuantity: 0,
          cost: 1,
          unitVolume: 1,
          product: product('DOMATES'),
        ),
        FactoryProductionInventoryModel(
          id: 'in-flour-q1',
          ownerKind: 'factory',
          ownerId: factoryId,
          inventoryType: 'input',
          productId: 'UN',
          brandId: zeroBrand,
          qualityLevel: 1,
          quantity: 20,
          pendingQuantity: 0,
          cost: 1,
          unitVolume: 1,
          product: product('UN'),
        ),
        FactoryProductionInventoryModel(
          id: 'old-input',
          ownerKind: 'factory',
          ownerId: factoryId,
          inventoryType: 'input',
          productId: 'SEKER',
          brandId: zeroBrand,
          qualityLevel: 1,
          quantity: 5,
          pendingQuantity: 0,
          cost: 1,
          unitVolume: 1,
          product: product('SEKER'),
        ),
        FactoryProductionInventoryModel(
          id: 'out-paste',
          ownerKind: 'factory',
          ownerId: factoryId,
          inventoryType: 'output',
          productId: 'SALCA',
          brandId: brandA,
          qualityLevel: 3,
          quantity: 30,
          pendingQuantity: 0,
          cost: 5,
          unitVolume: 1,
          product: tomatoPaste,
        ),
        FactoryProductionInventoryModel(
          id: 'out-bread',
          ownerKind: 'factory',
          ownerId: factoryId,
          inventoryType: 'output',
          productId: 'EKMEK',
          brandId: zeroBrand,
          qualityLevel: 1,
          quantity: 40,
          pendingQuantity: 0,
          cost: 5,
          unitVolume: 1,
          product: bread,
        ),
        FactoryProductionInventoryModel(
          id: 'wrong-output-quality',
          ownerKind: 'factory',
          ownerId: factoryId,
          inventoryType: 'output',
          productId: 'SALCA',
          brandId: brandA,
          qualityLevel: 2,
          quantity: 99,
          pendingQuantity: 0,
          cost: 5,
          unitVolume: 1,
          product: tomatoPaste,
        ),
      ],
    );

    expect(detail.inputInventories.map((e) => e.id).toSet(), {
      'in-tomato-q2',
      'in-flour-q1',
    });
    expect(detail.outputInventories.map((e) => e.id).toSet(), {
      'out-paste',
      'out-bread',
    });
    expect(detail.orphanInputInventories.single.id, 'old-input');
    expect(detail.totalInputQuantity, 30);
    expect(detail.totalOutputQuantity, 70);
  });

  test('mine outputs include all configured slot products', () {
    final iron = product('DEMIR');
    final copper = product('BAKIR');
    final now = DateTime.utc(2026);
    const mineId = 'mine-1';

    final detail = MineDetailModel(
      mine: MineModel(
        id: mineId,
        playerId: 'player-1',
        mineTypeId: 'type-1',
        cityId: 'city-1',
        name: 'Test Maden',
        level: 1,
        qualityLevel: 1,
        outputCapacity: 1000,
        boostMultiplier: 1,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
      mineType: const MineTypeDetailModel(
        id: 'type-1',
        name: 'Test',
        icon: 'mine.webp',
        acceptedProductIds: ['DEMIR', 'BAKIR'],
        maxSlotCount: 3,
        outputCapacity: 1000,
        cost: 100,
        constructionTimeMinutes: 1,
      ),
      cityName: 'Test Şehir',
      product: iron,
      productionSlots: [
        slot(
          id: 'slot-1',
          ownerKind: 'mine',
          ownerId: mineId,
          index: 1,
          product: iron,
          quality: 2,
          brand: zeroBrand,
        ),
        slot(
          id: 'slot-2',
          ownerKind: 'mine',
          ownerId: mineId,
          index: 2,
          product: copper,
          quality: 4,
          brand: brandA,
          active: false,
        ),
      ],
      inventories: [
        MineProductionInventoryModel(
          id: 'iron-output',
          ownerKind: 'mine',
          ownerId: mineId,
          inventoryType: 'output',
          productId: 'DEMIR',
          brandId: zeroBrand,
          qualityLevel: 2,
          quantity: 10,
          pendingQuantity: 0,
          cost: 1,
          unitVolume: 1,
          product: iron,
        ),
        MineProductionInventoryModel(
          id: 'copper-output',
          ownerKind: 'mine',
          ownerId: mineId,
          inventoryType: 'output',
          productId: 'BAKIR',
          brandId: brandA,
          qualityLevel: 4,
          quantity: 15,
          pendingQuantity: 0,
          cost: 1,
          unitVolume: 1,
          product: copper,
        ),
        MineProductionInventoryModel(
          id: 'wrong-copper-brand',
          ownerKind: 'mine',
          ownerId: mineId,
          inventoryType: 'output',
          productId: 'BAKIR',
          brandId: zeroBrand,
          qualityLevel: 4,
          quantity: 99,
          pendingQuantity: 0,
          cost: 1,
          unitVolume: 1,
          product: copper,
        ),
      ],
    );

    expect(detail.outputInventories.map((e) => e.id).toSet(), {
      'iron-output',
      'copper-output',
    });
    expect(detail.totalOutputQuantity, 25);
    expect(detail.hasConfiguredProduction, isTrue);
    expect(detail.activeConfiguredSlots.length, 1);
  });
}
