# Hard Kapitalizm — Patch Sistemi Backend Değişiklik Raporu

**Tarih:** 2026-09-09  
**Kapsam:** Backend İkinci Parti — Üretim Konfigürasyonu  
**Backend:** Supabase / PostgreSQL RPC

## 1. Amaç

İkinci partide üretim ürünü, kalite, marka ve üretim envanteri değişikliklerini frontend'e deterministik `changed.patches[]` response'u ile iletecek backend dönüşümü tamamlandı.

Bu grup ilk partiden daha karmaşıktır çünkü tek RPC:
- `production_slots` satırını değiştirebilir,
- `production_inventory` satırı oluşturabilir,
- mevcut inventory satırını güncelleyebilir,
- obsolete inventory satırlarını silebilir,
- marka/kalite overload'ları üzerinden ikinci mutation katmanı uygulayabilir.

Bu yüzden patch üretiminde tahmini yaklaşım yerine işlem öncesi/sonrası gerçek DB state farkı kullanılmaktadır.

---

## 2. Yeni Patch Entity

Frontend dispatcher'a eklenmesi gereken yeni entity:

```text
production_inventory
```

Örnek:

```json
{
  "entity": "production_inventory",
  "operation": "update",
  "id": "uuid",
  "changes": {
    "quantity": 120,
    "pending_quantity": 0,
    "cost": 85.2,
    "owner_kind": "factory",
    "owner_id": "uuid",
    "inventory_type": "input"
  }
}
```

Desteklenen operation'lar:

```text
insert
update
delete
```

---

## 3. Production Inventory Patch Kuralları

### Insert

Yeni inventory satırı:

```json
{
  "entity": "production_inventory",
  "operation": "insert",
  "id": "<inventory_id>",
  "changes": {
    "...": "tam production_inventory satırı"
  }
}
```

### Update

Mevcut inventory değiştiğinde yalnız değişen alanlar döner. Parent discovery için update patch'lerinde şu alanlar korunur:

```text
owner_kind
owner_id
inventory_type
```

### Delete

```json
{
  "entity": "production_inventory",
  "operation": "delete",
  "id": "<inventory_id>",
  "changes": {}
}
```

Frontend ID üzerinden local state'ten kaldırmalıdır.

---

## 4. Precise Patch Üretim Stratejisi

Akış:

```text
RPC çağrısı
  ↓
ilgili production state BEFORE snapshot
  ↓
mevcut business logic
  ↓
production state AFTER snapshot
  ↓
BEFORE / AFTER diff
  ↓
changed.patches[]
```

Böylece:

```text
yeni satır       → insert
değişen satır    → update
silinen satır    → delete
```

gerçek DB sonucuna göre tespit edilir.

---

## 5. Patch Sistemine Geçirilen RPC'ler

### Production slot
- `assign_production_slot_product(...)` normal overload
- `assign_production_slot_product(...)` marka overload
- `change_production_slot_product(...)` normal overload
- `change_production_slot_product(...)` marka overload

### Factory
- `set_factory_product(...)` normal overload
- `set_factory_product(...)` marka overload

### Mine
- `set_mine_product(player, mine, product)`
- `set_mine_product(player, mine, product, quality)`
- `set_mine_product(player, mine, product, quality, brand)`

### Store product selection
- `set_store_slot_product_from_warehouse_slot(...)`

---

## 6. `assign_production_slot_product`

Boş production slot'a ilk kez ürün atar.

Backend naming:

```text
farm  = UI Tarla
field = UI Çiftlik
```

Değişebilen tablolar:

```text
production_slots
production_inventory
```

Production slot örneği:

```json
{
  "entity": "production_slot",
  "operation": "update",
  "id": "<production_slot_id>",
  "changes": {
    "product_id": "DOMATES",
    "quality_level": 2,
    "brand_id": "...",
    "owner_kind": "farm",
    "owner_id": "...",
    "updated_at": "...",
    "last_production_at": "..."
  }
}
```

Ürünün hammaddelerine göre gerekli input inventory satırları oluşturulur.

Örneğin:

```json
{
  "entity": "production_inventory",
  "operation": "insert",
  "id": "...",
  "changes": {
    "owner_kind": "farm",
    "owner_id": "...",
    "inventory_type": "input",
    "product_id": "GUBRE",
    "quality_level": 1,
    "quantity": 0,
    "pending_quantity": 0,
    "cost": 0
  }
}
```

Output inventory yoksa ayrıca `production_inventory insert` oluşur.

---

## 7. `change_production_slot_product`

Mevcut Tarla/Çiftlik production slot'unun:
- ürününü,
- kalitesini,
- markasını

değiştirir.

Olası patch'ler:

```text
production_slot update
production_inventory insert
production_inventory update
production_inventory delete
```

Business kuralları korunmuştur:
- Eski output stock varsa ürün değişimi engellenir.
- Yeni üründe kullanılmayacak input stock varsa engellenir.
- Pending input varsa engellenir.
- Gerekirse eski output `pending_quantity` temizlenir.
- Boş ve artık gereksiz inventory satırları silinir.

---

## 8. `set_factory_product`

Değişebilen ana state:

```text
factories
production_inventory
```

Internal side effects:

```text
logistics_transfer_items
logistics_transfers
```

Frontend core patch olarak `factory` ve `production_inventory` alır.

Factory patch örneği:

```json
{
  "entity": "factory",
  "operation": "update",
  "id": "<factory_id>",
  "changes": {
    "product_id": "GUBRE",
    "quality_level": 3,
    "brand_id": "...",
    "updated_at": "...",
    "last_production_at": "..."
  }
}
```

Hammaddelere göre input inventory insert'leri oluşabilir. Yeni output kombinasyonu için output inventory insert edilir. Ürün değişince obsolete boş inventory'ler delete patch'i olarak döner.

---

## 9. `set_mine_product`

Üç overload da patch-aware hale getirildi:

```text
set_mine_product(player, mine, product)
set_mine_product(player, mine, product, quality)
set_mine_product(player, mine, product, quality, brand)
```

Mine patch örneği:

```json
{
  "entity": "mine",
  "operation": "update",
  "id": "<mine_id>",
  "changes": {
    "product_id": "DEMIR",
    "quality_level": 2,
    "brand_id": "...",
    "updated_at": "...",
    "last_production_at": "..."
  }
}
```

Maden output cost mantığı korunur:

```text
baz_satis_fiyati * 0.10
```

Kalite değişiminde:
- eski kalite stock/pending kontrol edilir,
- uygun inventory reuse/update edilebilir,
- yeni satır insert edilebilir,
- boş eski inventory delete edilebilir.

---

## 10. Marka Seçimi

Şu RPC ailelerinde manual marka seçimi patch-aware:

```text
assign_production_slot_product
change_production_slot_product
set_factory_product
set_mine_product
```

Akış:

```text
base product/quality mutation
+
manual brand mutation
```

tek public RPC içinde gerçekleşir.

Frontend'e ara state değil, final `brand_id` state'i döner.

---

## 11. Internal Brand Helper

```text
apply_manual_production_brand
```

internal helper olarak bırakılmıştır.

Frontend doğrudan çağırmamalıdır.

Authenticated direct execute erişimi kapatılmıştır. Brand seçimi yalnız public wrapper RPC üzerinden yapılmalıdır.

---

## 12. `set_store_slot_product_from_warehouse_slot`

Warehouse slot ürün varyantını mağaza slotuna ürün olarak seçer.

Değişebilen tablolar:

```text
store_slots
warehouse_slots
```

Store slot patch örneği:

```json
{
  "entity": "store_slot",
  "operation": "update",
  "id": "<store_slot_id>",
  "changes": {
    "store_id": "<store_id>",
    "product_id": "DOMATES",
    "quality_level": 4,
    "brand_id": "...",
    "quantity": 0,
    "price": 0,
    "cost": 82.4,
    "pending_sale": 0,
    "pending_quantity": 0,
    "updated_at": "..."
  }
}
```

Rafta farklı eski ürün stoğu varsa Genel Depoya iade edilir.

Duruma göre:

```text
warehouse_slot update
```

veya:

```text
warehouse_slot insert
```

patch'i oluşur.

---

## 13. Parent ID Standardı

Frontend dispatcher parent entity'yi bulabilsin diye şu alanlar patch'lerde korunur:

### `production_slot`

```text
owner_kind
owner_id
```

### `production_inventory`

```text
owner_kind
owner_id
inventory_type
```

### `store_slot`

```text
store_id
```

### `warehouse_slot`

```text
warehouse_id
```

---

## 14. Frontend Dispatcher

Yeni case:

```dart
case 'production_inventory':
  _applyProductionInventoryPatch(patch);
  break;
```

Örnek handler:

```dart
void applyProductionInventoryPatch(EntityPatch patch) {
  switch (patch.operation) {
    case PatchOperation.insert:
      insertInventory(
        ProductionInventoryModel.fromJson(patch.changes),
      );
      break;

    case PatchOperation.update:
      patchInventory(
        id: patch.id,
        changes: patch.changes,
      );
      break;

    case PatchOperation.delete:
      removeInventory(patch.id);
      break;
  }
}
```

---

## 15. Production Slot Handler Genişletmesi

İlk partide production slot daha çok active-state içindi.

Şimdi ayrıca desteklenmeli:

```text
product_id
quality_level
brand_id
updated_at
last_production_at
owner_kind
owner_id
```

Ürün değiştiğinde frontend modelindeki enriched alanlara dikkat:

```text
product
productName
productIcon
```

Bunlar tercihen static catalog'dan `product_id` üzerinden resolve edilmelidir.

---

## 16. Factory Handler Genişletmesi

Factory update patch şu alanları taşıyabilir:

```text
product_id
quality_level
brand_id
updated_at
last_production_at
```

Factory list/detail state merge edilmelidir.

---

## 17. Mine Handler Genişletmesi

Mine update patch:

```text
product_id
quality_level
brand_id
updated_at
last_production_at
```

alanlarını desteklemelidir.

---

## 18. Eski Üst-Seviye Response Alanları Korundu

Geriye dönük uyumluluk için şu alanlar korunmuştur:

```text
slots
inventories
product
product_id
product_name
quality_level
input_quality_level
output_inventory_id
same_setting
created_input_count
created_output_count
deleted_obsolete_inventory_count
```

Yeni `changed.patches[]` bunlara ek olarak gelir.

---

## 19. `get_player_profile()` Temizliği

Eski production mutation'larında gereksiz:

```text
changed.player = get_player_profile(...)
```

yaklaşımı kaldırıldı.

Bu aksiyonlar player cash/gold/xp/level değiştirmediği için full profile çağrısına gerek yoktur.

---

## 20. Frontend Entity Set

İlk parti entity'leri:

```text
store
store_slot
warehouse
warehouse_slot
factory
mine
field
farm
production_slot
logistics_company
logistics_vehicle
building_construction
arge_center
```

İkinci parti ile eklenen:

```text
production_inventory
```

---

## 21. Frontend Entegrasyon Sırası

1. `production_inventory` handler ekle.
2. Insert/update/delete desteğini tamamla.
3. `production_slot` ürün/kalite/marka patch'ini destekle.
4. `factory` ürün/kalite/marka patch'ini destekle.
5. `mine` ürün/kalite/marka patch'ini destekle.
6. `set_store_slot_product_from_warehouse_slot` akışını patch'e geçir.
7. İlgili gereksiz invalidate/refetch'leri kaldır.

---

## 22. Production Inventory Model

Frontend model en az şu alanları patch edebilmelidir:

```text
id
ownerKind
ownerId
inventoryType
productId
qualityLevel
brandId
quantity
pendingQuantity
cost
createdAt
updatedAt
```

Enriched `product` verisi static product catalog'dan çözülebilir.

---

## 23. Update Merge Kuralı

Full replace yapılmamalıdır.

Mevcut:

```json
{
  "id": "x",
  "product_id": "GUBRE",
  "quantity": 100,
  "pending_quantity": 20,
  "cost": 50
}
```

Patch:

```json
{
  "quantity": 80,
  "pending_quantity": 0
}
```

Sonuç:

```json
{
  "id": "x",
  "product_id": "GUBRE",
  "quantity": 80,
  "pending_quantity": 0,
  "cost": 50
}
```

---

## 24. Idempotency

Insert:

```text
aynı id varsa duplicate oluşturma
```

Delete:

```text
id yoksa hata verme
```

Update:

```text
id yoksa debug log + targeted refresh fallback
```

---

## 25. Fallback Politikası

Önerilen sıra:

```text
patch apply
  ↓ başarısızsa
owner detail targeted refresh
  ↓
feature invalidate
```

Full global invalidate yapılmamalıdır.

---

## 26. Test Checklist — Production Slot

### Assign
- [ ] Boş Tarla slotuna ürün ata
- [ ] `production_slot update` geliyor mu?
- [ ] Input inventory insert oluyor mu?
- [ ] Output inventory insert oluyor mu?
- [ ] Aynı ürün ikinci slotta engelleniyor mu?
- [ ] Kalite limiti doğru mu?
- [ ] Marka doğru mu?

### Change
- [ ] Ürünü değiştir
- [ ] Eski output stock varsa hata
- [ ] Eski unused input stock varsa hata
- [ ] Pending input varsa hata
- [ ] Eski pending output temizleniyor mu?
- [ ] Obsolete inventory delete geliyor mu?
- [ ] Yeni input inventory insert oluyor mu?
- [ ] Yeni output inventory insert oluyor mu?

---

## 27. Test Checklist — Factory

- [ ] İlk ürün seçimi
- [ ] Ürün değiştirme
- [ ] Kalite değiştirme
- [ ] Marka değiştirme
- [ ] Factory local product güncelleniyor mu?
- [ ] Quality güncelleniyor mu?
- [ ] Brand güncelleniyor mu?
- [ ] Input inventory doğru oluşuyor mu?
- [ ] Eski inventory doğru siliniyor mu?
- [ ] Output stock varken ürün değişimi engelleniyor mu?
- [ ] Pending input varken engelleniyor mu?

---

## 28. Test Checklist — Mine

- [ ] Ürün seç
- [ ] Otomatik max kalite
- [ ] Manual kalite
- [ ] Manual marka
- [ ] Mine patch doğru uygulanıyor mu?
- [ ] Output inventory oluşuyor mu?
- [ ] Output cost doğru mu?
- [ ] Kalite değişiminde boş eski inventory temizleniyor mu?
- [ ] Stock varken kalite/ürün değişimi engelleniyor mu?

---

## 29. Test Checklist — Store Product Selection

- [ ] Empty store slot'a warehouse ürünü seç
- [ ] Product/quality/brand değişiyor mu?
- [ ] Eski raftaki stock depoya dönüyor mu?
- [ ] Matching warehouse slot update oluyor mu?
- [ ] Matching slot yoksa insert oluyor mu?
- [ ] Genel depo capacity kontrolü çalışıyor mu?
- [ ] Store summary doğru hesaplanıyor mu?

---

## 30. Güvenlik

Public production RPC wrapper'ları:

```text
authenticated
service_role
```

rollerine açıktır.

Internal core/helper fonksiyonlar doğrudan frontend API değildir.

Migration sonrası security/performance advisor çalıştırılmıştır. Bu ikinci parti değişikliklerden kaynaklanan yeni anon exposure, yeni RLS problemi veya yeni index problemi tespit edilmemiştir.

Mevcut eski proje uyarıları devam etmektedir:
- RLS enabled/no policy
- authenticated SECURITY DEFINER audit yüzeyi
- leaked password protection disabled
- unindexed logistics company type FK
- auth RLS initplan
- unused indexes
- duplicate indexes

---

## 31. Canlı Doğrulama

Canlı veritabanında mevcut production slot üzerinde transaction + rollback testi yapılmıştır.

Test:

```text
farm
BIBER
quality 1
```

aynı ayar tekrar uygulanmıştır.

Response yalnız gerçekten değişen production slot alanlarını patch olarak döndürmüştür.

Transaction rollback edilmiştir; test kullanıcısının kalıcı verisi değiştirilmemiştir.

---

## 32. Kritik Frontend Uyarıları

- `production_inventory` handler hazır olmadan production config invalidate'larını kaldırma.
- `product_id` değiştiğinde eski enriched `product` objesini local state'te bırakma.
- Default marka UUID:
  `00000000-0000-0000-0000-000000000000`
- Delete patch gelen inventory mutlaka local listeden kaldırılmalı.
- Update patch'lerinde yalnız `changes` içindeki alanlar merge edilmeli.

---

## 33. İkinci Parti Tamamlanma Kriterleri

- [ ] `production_inventory` dispatcher case eklendi
- [ ] insert destekleniyor
- [ ] update destekleniyor
- [ ] delete destekleniyor
- [ ] `production_slot` ürün/kalite/marka patch'i destekleniyor
- [ ] `factory` ürün/kalite/marka patch'i destekleniyor
- [ ] `mine` ürün/kalite/marka patch'i destekleniyor
- [ ] store product selection patch akışı çalışıyor
- [ ] product enrichment local catalog'dan resolve ediliyor
- [ ] production config invalidate'ları temizlendi
- [ ] production config aksiyonları test edildi

---

## 34. Sonraki Backend Parti

Frontend bu gruba göre düzenlendikten sonra önerilen sonraki backend grubu:

```text
production processing
+
intercity logistics transfers
```

Özellikle:

```text
process_factory_production_entry
process_field_farm_production_entry
process_mine_production_entry
process_player_production_entry
start_multi_warehouse_to_production_transfer
start_multi_production_to_warehouse_transfer
start_warehouse_to_warehouse_transfer
complete_logistics_transfer
```

Bu alanlar quantity/pending ve vehicle state'i yoğun değiştirdiği için patch sisteminde sonraki büyük performans kazancını sağlayacaktır.
