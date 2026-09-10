import 'package:flutter_test/flutter_test.dart';
import 'package:hard_kapitalizm/core/models/product_model.dart';
import 'package:hard_kapitalizm/core/models/production_slot_model.dart';
import 'package:hard_kapitalizm/features/factory/models/factory_list_item_model.dart';
import 'package:hard_kapitalizm/features/factory/models/factory_model.dart';
import 'package:hard_kapitalizm/features/mine/models/mine_list_item_model.dart';
import 'package:hard_kapitalizm/features/mine/models/mine_model.dart';

void main() {
  final now = DateTime.utc(2026, 9, 10);
  final product = ProductModel(
    id: 'URUN_A',
    urunAdi: 'Ürün A',
    urunIconu: 'urun_a.webp',
    birimHacim: 1,
    birimAgirlik: 1,
    bazSatisFiyati: 100,
    uretimAdedi: 10,
    satisAdedi: 0,
    enDusukFiyat: 0,
    enYuksekFiyat: 0,
    ortalamaFiyat: 0,
    saticiSayisi: 0,
    piyasadakiStok: 0,
    createdAt: now,
  );

  final slot = ProductionSlotContractModel(
    id: 'slot-2',
    ownerKind: 'factory',
    ownerId: 'factory-1',
    slotIndex: 2,
    productId: product.id,
    brandId: ProductionSlotContractModel.zeroBrandId,
    qualityLevel: 1,
    boostMultiplier: 1,
    isActive: true,
    product: product,
  );

  test('factory list recognises configured non-legacy production slot', () {
    final item = FactoryListItemModel(
      factory: FactoryModel(
        id: 'factory-1',
        playerId: 'player-1',
        factoryTypeId: 'type-1',
        cityId: 'city-1',
        name: 'Fabrika',
        level: 1,
        productId: null,
        qualityLevel: 0,
        currentSlotCount: 2,
        maxSlotCount: 5,
        inputCapacity: 100,
        outputCapacity: 100,
        boostMultiplier: 1,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
      cityName: 'Van',
      factoryTypeName: 'Test Fabrika',
      factoryTypeIcon: 'factory.webp',
      inputStockQuantity: 10,
      outputStockQuantity: 0,
      selectedProduct: null,
      productionSlots: [slot],
    );

    expect(item.hasSelectedProduct, isTrue);
    expect(item.warningReason, isNull);
  });

  test('mine list recognises configured slot when legacy mirror is empty', () {
    final mineSlot = ProductionSlotContractModel(
      id: 'slot-2',
      ownerKind: 'mine',
      ownerId: 'mine-1',
      slotIndex: 2,
      productId: product.id,
      brandId: ProductionSlotContractModel.zeroBrandId,
      qualityLevel: 1,
      boostMultiplier: 1,
      isActive: true,
      product: product,
    );

    final item = MineListItemModel(
      mine: MineModel(
        id: 'mine-1',
        playerId: 'player-1',
        mineTypeId: 'type-1',
        cityId: 'city-1',
        name: 'Maden',
        level: 1,
        productId: null,
        qualityLevel: 0,
        currentSlotCount: 2,
        maxSlotCount: 5,
        outputCapacity: 100,
        boostMultiplier: 1,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
      cityName: 'Van',
      mineTypeName: 'Test Maden',
      mineTypeIcon: 'mine.webp',
      outputStockQuantity: 0,
      selectedProduct: null,
      productionSlots: [mineSlot],
    );

    expect(item.hasSelectedProduct, isTrue);
    expect(item.warningReason, isNull);
  });
}
