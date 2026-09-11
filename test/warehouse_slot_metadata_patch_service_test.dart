import 'package:flutter_test/flutter_test.dart';
import 'package:hard_kapitalizm/core/data/warehouse_slot_metadata_patch_service.dart';
import 'package:hard_kapitalizm/core/models/product_model.dart';
import 'package:hard_kapitalizm/features/warehouse/models/warehouse_model.dart';

void main() {
  test('warehouse slot enrichment fills catalog metadata without losing stock state', () {
    final slot = WarehouseSlotModel(
      id: 'slot-1',
      brandId: 'brand-1',
      productId: 'DOMATES',
      productName: null,
      productIcon: null,
      quantity: 125,
      unitVolume: 0,
      qualityLevel: 4,
      price: 37.5,
      cost: 21.25,
      isAvailableForSale: true,
    );

    final product = ProductModel(
      id: 'DOMATES',
      urunAdi: 'Domates',
      urunIconu: 'domates.webp',
      birimHacim: 0.4,
      birimAgirlik: 0.3,
      bazSatisFiyati: 30,
      uretimAdedi: 0,
      satisAdedi: 0,
      enDusukFiyat: 0,
      enYuksekFiyat: 0,
      ortalamaFiyat: 0,
      saticiSayisi: 0,
      piyasadakiStok: 0,
      createdAt: DateTime.utc(2026, 1, 1),
    );

    final enriched = enrichWarehouseSlotMetadata(slot, product);

    expect(enriched.id, 'slot-1');
    expect(enriched.productId, 'DOMATES');
    expect(enriched.productName, 'Domates');
    expect(enriched.productIcon, 'domates.webp');
    expect(enriched.unitVolume, 0.4);

    expect(enriched.quantity, 125);
    expect(enriched.qualityLevel, 4);
    expect(enriched.brandId, 'brand-1');
    expect(enriched.price, 37.5);
    expect(enriched.cost, 21.25);
    expect(enriched.isAvailableForSale, isTrue);
  });
}
