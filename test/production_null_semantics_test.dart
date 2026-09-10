import 'package:flutter_test/flutter_test.dart';
import 'package:hard_kapitalizm/core/models/product_model.dart';
import 'package:hard_kapitalizm/core/models/production_slot_model.dart';
import 'package:hard_kapitalizm/features/factory/models/factory_detail_model.dart';
import 'package:hard_kapitalizm/features/factory/models/factory_list_item_model.dart';
import 'package:hard_kapitalizm/features/factory/models/factory_model.dart';
import 'package:hard_kapitalizm/features/field/models/field_detail_model.dart';
import 'package:hard_kapitalizm/features/farm/models/farm_detail_model.dart';
import 'package:hard_kapitalizm/features/mine/models/mine_detail_model.dart';
import 'package:hard_kapitalizm/features/mine/models/mine_list_item_model.dart';
import 'package:hard_kapitalizm/features/mine/models/mine_model.dart';

void main() {
  final now = DateTime.utc(2026, 9, 11);
  final product = ProductModel(
    id: 'KUM',
    urunAdi: 'Kum',
    urunIconu: 'kum.webp',
    birimHacim: 1,
    birimAgirlik: 1,
    bazSatisFiyati: 10,
    uretimAdedi: 10,
    satisAdedi: 0,
    enDusukFiyat: 0,
    enYuksekFiyat: 0,
    ortalamaFiyat: 0,
    saticiSayisi: 0,
    piyasadakiStok: 0,
    createdAt: now,
  );

  FactoryModel factory() => FactoryModel(
        id: 'factory-1',
        playerId: 'player-1',
        factoryTypeId: 'factory-type-1',
        cityId: 'city-1',
        name: 'Test Fabrika',
        level: 1,
        productId: product.id,
        qualityLevel: 1,
        inputCapacity: 100,
        outputCapacity: 100,
        boostMultiplier: 1,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

  MineModel mine() => MineModel(
        id: 'mine-1',
        playerId: 'player-1',
        mineTypeId: 'mine-type-1',
        cityId: 'city-1',
        name: 'Test Maden',
        level: 1,
        productId: product.id,
        qualityLevel: 1,
        outputCapacity: 100,
        boostMultiplier: 1,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

  test('factory list explicit null clears legacy selected product', () {
    final item = FactoryListItemModel(
      factory: factory(),
      cityName: 'İstanbul',
      factoryTypeName: 'Gıda',
      factoryTypeIcon: 'factory.webp',
      inputStockQuantity: 0,
      outputStockQuantity: 0,
      selectedProduct: product,
    );

    expect(item.copyWith().selectedProduct, same(product));
    expect(item.copyWith(selectedProduct: null).selectedProduct, isNull);
  });

  test('mine list explicit null clears legacy selected product', () {
    final item = MineListItemModel(
      mine: mine(),
      cityName: 'İstanbul',
      mineTypeName: 'Taş Ocağı',
      mineTypeIcon: 'mine.webp',
      outputStockQuantity: 0,
      selectedProduct: product,
    );

    expect(item.copyWith().selectedProduct, same(product));
    expect(item.copyWith(selectedProduct: null).selectedProduct, isNull);
  });

  test('factory detail and inventory explicit null clear product objects', () {
    final inventory = FactoryProductionInventoryModel(
      id: 'inventory-1',
      ownerKind: 'factory',
      ownerId: 'factory-1',
      inventoryType: 'output',
      productId: product.id,
      brandId: '00000000-0000-0000-0000-000000000000',
      qualityLevel: 1,
      quantity: 1,
      pendingQuantity: 0,
      cost: 0,
      unitVolume: 1,
      product: product,
    );
    final detail = FactoryDetailModel(
      factory: factory(),
      factoryType: const FactoryTypeDetailModel(
        id: 'factory-type-1',
        name: 'Gıda',
        icon: 'factory.webp',
        acceptedProductIds: ['KUM'],
        maxSlotCount: 3,
        inputCapacity: 100,
        outputCapacity: 100,
        cost: 0,
        constructionTimeMinutes: 0,
      ),
      cityName: 'İstanbul',
      product: product,
      inventories: [inventory],
    );

    expect(detail.copyWith().product, same(product));
    expect(detail.copyWith(product: null).product, isNull);
    expect(inventory.copyWith().product, same(product));
    expect(inventory.copyWith(product: null).product, isNull);
  });

  test('mine detail and inventory explicit null clear product objects', () {
    final inventory = MineProductionInventoryModel(
      id: 'inventory-1',
      ownerKind: 'mine',
      ownerId: 'mine-1',
      inventoryType: 'output',
      productId: product.id,
      brandId: '00000000-0000-0000-0000-000000000000',
      qualityLevel: 1,
      quantity: 1,
      pendingQuantity: 0,
      cost: 0,
      unitVolume: 1,
      product: product,
    );
    final detail = MineDetailModel(
      mine: mine(),
      mineType: const MineTypeDetailModel(
        id: 'mine-type-1',
        name: 'Taş Ocağı',
        icon: 'mine.webp',
        acceptedProductIds: ['KUM'],
        maxSlotCount: 3,
        outputCapacity: 100,
        cost: 0,
        constructionTimeMinutes: 0,
      ),
      cityName: 'İstanbul',
      product: product,
      inventories: [inventory],
    );

    expect(detail.copyWith().product, same(product));
    expect(detail.copyWith(product: null).product, isNull);
    expect(inventory.copyWith().product, same(product));
    expect(inventory.copyWith(product: null).product, isNull);
  });

  test('factory configured state survives missing product metadata', () {
    const slot = ProductionSlotContractModel(
      id: 'slot-1',
      ownerKind: 'factory',
      ownerId: 'factory-1',
      slotIndex: 1,
      productId: 'KUM',
      brandId: ProductionSlotContractModel.zeroBrandId,
      qualityLevel: 1,
      boostMultiplier: 1,
      isActive: true,
      product: null,
    );
    final detail = FactoryDetailModel(
      factory: factory(),
      factoryType: const FactoryTypeDetailModel(
        id: 'factory-type-1',
        name: 'Gıda',
        icon: 'factory.webp',
        acceptedProductIds: ['KUM'],
        maxSlotCount: 3,
        inputCapacity: 100,
        outputCapacity: 100,
        cost: 0,
        constructionTimeMinutes: 0,
      ),
      cityName: 'İstanbul',
      product: null,
      productionSlots: const [slot],
      inventories: const [],
    );

    expect(detail.hasConfiguredProduction, isTrue);
    expect(detail.hasActiveProduction, isTrue);
    expect(detail.configuredSlots, [slot]);
  });

  test('mine configured state survives missing product metadata', () {
    const slot = ProductionSlotContractModel(
      id: 'slot-1',
      ownerKind: 'mine',
      ownerId: 'mine-1',
      slotIndex: 1,
      productId: 'KUM',
      brandId: ProductionSlotContractModel.zeroBrandId,
      qualityLevel: 1,
      boostMultiplier: 1,
      isActive: true,
      product: null,
    );
    final detail = MineDetailModel(
      mine: mine(),
      mineType: const MineTypeDetailModel(
        id: 'mine-type-1',
        name: 'Taş Ocağı',
        icon: 'mine.webp',
        acceptedProductIds: ['KUM'],
        maxSlotCount: 3,
        outputCapacity: 100,
        cost: 0,
        constructionTimeMinutes: 0,
      ),
      cityName: 'İstanbul',
      product: null,
      productionSlots: const [slot],
      inventories: const [],
    );

    expect(detail.hasConfiguredProduction, isTrue);
    expect(detail.hasActiveProduction, isTrue);
    expect(detail.configuredSlots, [slot]);
  });

  test('field production slot explicit null clears product id and object', () {
    final slot = ProductionSlotModel(
      id: 'slot-1',
      ownerKind: 'field',
      ownerId: 'field-1',
      slotIndex: 1,
      productId: product.id,
      brandId: '00000000-0000-0000-0000-000000000000',
      qualityLevel: 1,
      boostMultiplier: 1,
      isActive: true,
      product: product,
    );

    expect(slot.copyWith().productId, product.id);
    final cleared = slot.copyWith(productId: null, product: null);
    expect(cleared.productId, isNull);
    expect(cleared.product, isNull);
  });

  test('farm production slot explicit null clears product id and object', () {
    final slot = FarmProductionSlotModel(
      id: 'slot-1',
      ownerKind: 'farm',
      ownerId: 'farm-1',
      slotIndex: 1,
      productId: product.id,
      brandId: '00000000-0000-0000-0000-000000000000',
      qualityLevel: 1,
      boostMultiplier: 1,
      isActive: true,
      product: product,
    );

    expect(slot.copyWith().productId, product.id);
    final cleared = slot.copyWith(productId: null, product: null);
    expect(cleared.productId, isNull);
    expect(cleared.product, isNull);
  });
}
