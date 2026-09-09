# Hard Kapitalizm — Patch Sistemi Backend Değişiklik Raporu

**Tarih:** 2026-09-09  
**Kapsam:** Backend Üçüncü Parti — Production Processing + Kendi Lojistik Transferleri  
**Backend:** Supabase / PostgreSQL RPC

## 1. Amaç

Üçüncü partide iki ana alan patch sistemine geçirildi:

1. Detail-open production processing
2. Oyuncunun kendi depo/üretim lojistik transferleri

Ana hedef, mutation sonrasında full invalidate/refetch yerine sadece gerçekten değişen state'i:

```json
{
  "changed": {
    "player": {},
    "patches": []
  }
}
```

formatında frontend'e göndermektir.

---

## 2. Patch-Aware Hale Gelen RPC'ler

```text
process_player_production_entry
start_multi_warehouse_to_production_transfer
start_multi_production_to_warehouse_transfer
start_warehouse_to_warehouse_transfer
complete_logistics_transfer
finish_logistics_transfer_with_gold
finish_logistics_transfer_with_ad_reward
```

Dolaylı olarak:

```text
start_city_consolidated_transfer
```

de `start_warehouse_to_warehouse_transfer` sonucunu kullandığı için patch sisteminden faydalanır.

---

## 3. Yeni Frontend Entity'leri

Üçüncü partiyle dispatcher'a eklenmesi gereken yeni entity'ler:

```text
logistics_transfer
logistics_transfer_item
building_upgrade
building_boost
```

Önceki partilerden kullanılan mevcut entity'ler:

```text
production_inventory
production_slot
factory
mine
warehouse
warehouse_slot
logistics_vehicle
```

---

## 4. Production Processing Stratejisi

### Detail ekranı

Eğer:

```text
ownerId != null
```

ise yalnız ilgili üretim biriminin BEFORE / AFTER snapshot'ı alınır ve precise patch oluşturulur.

Örneğin:

```text
factory detail
mine detail
Tarla detail
Çiftlik detail
```

### Liste ekranı

Eğer:

```text
ownerId == null
```

ise büyük patch response üretilmez.

Sebep: mevcut list provider akışı production processing çağrısından hemen sonra zaten fresh list RPC'sini çalıştırıyor.

```text
process_player_production_entry
↓
get_*_list_items
```

Tüm oyuncunun production state'ini snapshot ederek response'u büyütmek gereksizdir.

---

## 5. `process_player_production_entry`

Üretim sonucunda değişebilen entity'ler:

```text
factory
mine
production_slot
production_inventory
building_upgrade
building_boost
player
```

### Factory / Mine

Şu alanlar değişebilir:

```text
last_production_at
updated_at
```

### Tarla / Çiftlik

Backend isimlendirmesi:

```text
farm  = UI Tarla
field = UI Çiftlik
```

Production zamanı `production_slots` üzerinde olduğu için:

```text
production_slot update
```

patch'i gelir.

---

## 6. Production Inventory Processing

Üretimde input tüketimi:

```text
production_inventory update
```

Output üretimi:

```text
production_inventory update
```

Değişebilen alanlar:

```text
quantity
pending_quantity
cost
```

Frontend weighted cost hesaplamamalı; backend authoritative değeri patch ile gönderir.

---

## 7. Pending Production

Tam ürün oluşmadığında sadece:

```text
pending_quantity
```

değişebilir.

Frontend `production_inventory` handler'ı decimal `pending_quantity` değerini merge etmelidir.

---

## 8. Production Slot Timestamp Patch

Örnek:

```json
{
  "entity": "production_slot",
  "operation": "update",
  "id": "...",
  "changes": {
    "owner_kind": "field",
    "owner_id": "...",
    "last_production_at": "...",
    "updated_at": "..."
  }
}
```

`owner_kind` ve `owner_id` parent lookup için korunur.

---

## 9. Upgrade / Boost Side Effect

`process_player_production_entry` çağrısı sırasında süresi dolmuş upgrade veya boost otomatik tamamlanabilir.

Yeni entity'ler:

```text
building_upgrade
building_boost
```

Frontend ilgili active provider state'ini güncellemelidir.

Status completed olduğunda active boost/upgrade temizlenebilir.

---

## 10. `start_multi_production_to_warehouse_transfer`

Akış:

```text
production output
→ aynı şehirde Genel Depo
```

Mevcut kurala göre şehir içidir ve:

```text
mode = instant
```

olarak anında tamamlanır.

Olası patch'ler:

```text
production_inventory update
warehouse update
warehouse_slot update/insert
logistics_transfer insert
logistics_transfer_item insert
```

Transfer ve item doğrudan final:

```text
status = completed
```

halinde gelebilir.

---

## 11. Production → Warehouse Kaynak Patch

```json
{
  "entity": "production_inventory",
  "operation": "update",
  "id": "...",
  "changes": {
    "quantity": 1802,
    "owner_kind": "field",
    "owner_id": "...",
    "inventory_type": "output"
  }
}
```

---

## 12. Production → Warehouse Hedef Patch

Matching warehouse slot varsa:

```text
warehouse_slot update
```

Yoksa:

```text
warehouse_slot insert
```

Weighted average `cost` backend tarafından hesaplanır.

---

## 13. `start_multi_warehouse_to_production_transfer`

Akış:

```text
Genel Depo
→ aynı şehir production input inventory
```

Şehir içidir ve instant tamamlanır.

Olası patch'ler:

```text
warehouse_slot update/delete
production_inventory update
logistics_transfer insert
logistics_transfer_item insert
```

Source warehouse slot miktarı 0'a düşer ve pending yoksa:

```text
warehouse_slot delete
```

gelir.

---

## 14. Warehouse → Production Target

Production input inventory'de değişebilen:

```text
quantity
pending_quantity
cost
```

Frontend backend'in verdiği weighted average cost'u doğrudan kullanmalıdır.

---

## 15. `start_warehouse_to_warehouse_transfer`

Akış:

```text
Genel Depo → Genel Depo
```

### Aynı şehir

```text
mode = instant
```

Araç kullanılmaz.

### Farklı şehir

```text
mode = in_transit
```

Araç gerekir.

Olası patch'ler:

```text
player
warehouse
warehouse_slot
logistics_vehicle
logistics_transfer
logistics_transfer_item
```

---

## 16. Intercity Vehicle Patch

Transfer başlangıcında:

```text
status = on_route
current_fuel azalır
condition azalır
updated_at değişir
```

Transfer tamamlandığında:

```text
status = idle
```

---

## 17. Warehouse Reserved Capacity

Intercity transferde hedef warehouse:

```text
reserved_capacity += transferVolume
```

Transfer tamamlanınca reserve çözülür.

Frontend warehouse modelinde `reserved_capacity` patch edilebilir olmalıdır.

---

## 18. Yeni Entity: `logistics_transfer`

Dispatcher:

```dart
case 'logistics_transfer':
  _applyLogisticsTransferPatch(patch);
  break;
```

Minimum model alanları:

```text
id
buyerPlayerId
sellerPlayerId
buyerWarehouseId
sellerWarehouseId
buyerProductionInventoryId
sellerProductionInventoryId
logisticsVehicleId
vehicleOwnerPlayerId
isRental
productId
qualityLevel
brandId
quantity
totalQuantity
itemCount
distanceKm
fuelUsed
conditionLoss
rentalCost
transportCost
reservedCapacityAmount
startedAt
finishAt
completedAt
status
transferType
sellerEntityKind
buyerEntityKind
```

Insert idempotent olmalıdır:

```text
aynı id varsa replace
yoksa insert
```

---

## 19. Yeni Entity: `logistics_transfer_item`

Dispatcher:

```dart
case 'logistics_transfer_item':
  _applyLogisticsTransferItemPatch(patch);
  break;
```

Minimum alanlar:

```text
id
transferId
sourceWarehouseSlotId
targetWarehouseSlotId
targetProductionInventoryId
productId
qualityLevel
brandId
quantity
unitCost
unitPrice
totalCost
totalPrice
productUnitVolume
reservedCapacityAmount
status
createdAt
updatedAt
completedAt
```

Parent lookup:

```text
transfer_id
```

üzerinden yapılabilir.

---

## 20. `complete_logistics_transfer`

Intercity transfer hedefe ulaşınca değişebilen state:

```text
warehouse
warehouse_slot
production_inventory
logistics_transfer
logistics_transfer_item
logistics_vehicle
player
```

Player patch özellikle transfer XP'si sebebiyle gelebilir:

```text
experience
level
```

Şehir içi kendi stok hareketlerinde XP verilmez.

---

## 21. `finish_logistics_transfer_with_gold`

İşlem zinciri:

```text
player.gold azalt
transfer.finish_at geçmişe çek
complete_logistics_transfer
```

Outer wrapper artık işlemin tamamını BEFORE / AFTER diff ile kapsar.

Böylece response final state'i içerir:

```text
player.gold
logistics_transfer.finish_at
logistics_transfer.status
logistics_transfer.completed_at
warehouse / production inventory değişimleri
logistics_vehicle.status
player.experience
player.level
```

---

## 22. `finish_logistics_transfer_with_ad_reward`

Aynı şekilde outer diff kullanır.

Final transfer/inventory/vehicle patch'leri response'a dahil edilir.

Reward usage metadata üst-seviye response alanlarında korunur.

---

## 23. `start_city_consolidated_transfer`

Bu RPC:

```text
start_warehouse_to_warehouse_transfer
```

çağrısını wrap ettiği için yeni patch contract'ını otomatik taşır.

Ek frontend entity gerekmez.

---

## 24. Bilerek Hariç Tutulan RPC

```text
start_multi_market_transfer
```

üçüncü partiye dahil edilmedi.

Sebep: tek işlem içinde başka oyuncuların da state'i değişebilir:

```text
buyer cash
seller cash
seller warehouse slot
market listing state
rental payout
notifications
```

Bu akış ayrı partide ele alınmalıdır.

Frontend'de market transferleri için mevcut fallback refresh/invalidate şimdilik korunmalıdır.

---

## 25. Production Entry Frontend Entegrasyonu

Mevcut `processProductionEntry()` response'u detail akışında `MutationSyncService` üzerinden uygulanmalıdır.

Öneri:

```dart
final result = await processProductionEntry(...);

if (ownerId != null) {
  ref.read(mutationSyncServiceProvider).applyRaw(result);
}
```

Liste ekranlarında `ownerId == null` olduğu için patch apply zorunlu değildir; fresh list fetch zaten yapılır.

---

## 26. Dispatcher'a Eklenecek Case'ler

```dart
case 'logistics_transfer':
  _applyLogisticsTransferPatch(patch);
  break;

case 'logistics_transfer_item':
  _applyLogisticsTransferItemPatch(patch);
  break;

case 'building_upgrade':
  _applyBuildingUpgradePatch(patch);
  break;

case 'building_boost':
  _applyBuildingBoostPatch(patch);
  break;
```

---

## 27. Active Transfer UI Davranışı

`logistics_transfer insert` ve:

```text
status = in_transit
```

ise active transfer listesine eklenmeli.

Transfer:

```text
status = completed
```

olunca:

- active listeden çıkar,
- history state varsa güncelle,
- map marker varsa kaldır.

Bunlar frontend derived davranışlarıdır.

---

## 28. Refresh / Invalidate Temizliği

Frontend entegrasyonu tamamlandıktan sonra aşağıdaki mutation sonrası full refresh'ler kaldırılabilir:

```text
start_multi_warehouse_to_production_transfer
start_multi_production_to_warehouse_transfer
start_warehouse_to_warehouse_transfer
complete_logistics_transfer
finish_logistics_transfer_with_gold
finish_logistics_transfer_with_ad_reward
```

Örneğin:

```dart
ref.invalidate(warehouseDetailProvider(...));
ref.invalidate(factoryDetailProvider(...));
ref.invalidate(mineDetailProvider(...));
ref.invalidate(farmDetailProvider(...));
ref.invalidate(fieldDetailProvider(...));
ref.invalidate(logisticsVehicleListProvider);
ref.invalidate(activeTransfersProvider);
```

Ancak yalnız ilgili provider patch-aware olduktan sonra.

---

## 29. Fallback Politikası

```text
patch
↓
targeted detail refresh
↓
feature invalidate
```

Global refresh kullanılmamalıdır.

---

## 30. Production Detail Test Checklist

### Factory
- [ ] Detail aç
- [ ] Input quantity azalıyor
- [ ] Output quantity artıyor
- [ ] Output cost güncelleniyor
- [ ] pending_quantity doğru
- [ ] last_production_at patch geliyor
- [ ] Full detail refetch olmadan UI güncelleniyor

### Mine
- [ ] Output quantity artıyor
- [ ] pending değişiyor
- [ ] cost doğru
- [ ] timestamp güncelleniyor

### Tarla / Çiftlik
- [ ] production_slot timestamp değişiyor
- [ ] input azalıyor
- [ ] output artıyor
- [ ] owner output capacity korunuyor

---

## 31. Warehouse → Production Checklist

- [ ] Aynı şehir kuralı
- [ ] Warehouse quantity azalıyor
- [ ] Sıfır source slot delete oluyor
- [ ] Production input quantity artıyor
- [ ] Cost doğru
- [ ] Transfer completed
- [ ] Item completed
- [ ] Gereksiz invalidate yok

---

## 32. Production → Warehouse Checklist

- [ ] Production output azalıyor
- [ ] Warehouse matching slot update
- [ ] Gerekirse warehouse slot insert
- [ ] Weighted cost doğru
- [ ] Transfer completed
- [ ] Item completed
- [ ] UI anında güncelleniyor

---

## 33. Warehouse → Warehouse Same City Checklist

- [ ] Araç istemiyor
- [ ] Source azalıyor/delete
- [ ] Target update/insert
- [ ] Transfer completed
- [ ] Item completed
- [ ] Reserved capacity final doğru

---

## 34. Warehouse → Warehouse Intercity Checklist

- [ ] Route uyumlu araç gerekiyor
- [ ] Source slot azalıyor
- [ ] Target reserved capacity artıyor
- [ ] Vehicle on_route
- [ ] Fuel azalıyor
- [ ] Condition azalıyor
- [ ] Rental ise player cash azalıyor
- [ ] Transfer in_transit
- [ ] Item in_transit
- [ ] Active transfer UI'ya ekleniyor

---

## 35. Intercity Completion Checklist

- [ ] Target warehouse / production inventory güncelleniyor
- [ ] Reserved capacity çözülüyor
- [ ] Transfer completed
- [ ] Items completed
- [ ] Vehicle idle
- [ ] XP patch geliyor
- [ ] Level-up varsa uygulanıyor
- [ ] Active transfer listeden kalkıyor

---

## 36. Gold Finish Checklist

- [ ] Gold cost doğru
- [ ] Player gold azalıyor
- [ ] Transfer final completed
- [ ] Target patch'ler geliyor
- [ ] Vehicle idle
- [ ] XP uygulanıyor
- [ ] Full profile refetch yapılmıyor

---

## 37. Ad Finish Checklist

- [ ] Son 10 dakika kuralı
- [ ] Reward usage metadata korunuyor
- [ ] Transfer final completed
- [ ] Inventory patch uygulanıyor
- [ ] Vehicle patch uygulanıyor

---

## 38. Canlı Rollback Testi

Gerçek production output üzerinden:

```text
1 adet YUMURTA
production → warehouse
```

transferi transaction içinde çalıştırıldı.

Response:

```text
production_inventory update
warehouse update
warehouse_slot update
logistics_transfer insert
logistics_transfer_item insert
```

Transfer/item final:

```text
status = completed
```

Transaction rollback edildi.

Kaynak stok tekrar:

```text
1803
```

olarak doğrulandı.

Kalıcı kullanıcı state'i değişmedi.

---

## 39. Production Processing Rollback Testi

Scoped detail call:

```text
owner_kind = field
owner_id = ...
```

ile çalıştırıldı.

Response:

```text
production_slot update × 2
```

Parent identity:

```text
owner_kind
owner_id
```

patch içinde mevcuttu.

Rollback sonrası kalıcı state değişmedi.

---

## 40. Güvenlik

Üçüncü parti public RPC'lerde varsayılan:

```text
PUBLIC EXECUTE
```

kaldırıldı.

Yetkiler:

```text
postgres
authenticated
service_role
```

`anon` / `PUBLIC` execute yoktur.

---

## 41. Advisor Sonucu

Üçüncü parti migration kaynaklı yeni security/performance advisor problemi tespit edilmedi.

Mevcut teknik borçlar:

```text
logistics_companies_type_fk unindexed FK
6 auth RLS initplan
21 unused indexes
2 duplicate index
3 RLS enabled/no-policy
existing SECURITY DEFINER audit surface
leaked password protection disabled
```

---

## 42. Üçüncü Parti Frontend Tamamlanma Kriterleri

- [ ] `logistics_transfer` dispatcher eklendi
- [ ] `logistics_transfer_item` dispatcher eklendi
- [ ] `building_upgrade` dispatcher eklendi
- [ ] `building_boost` dispatcher eklendi
- [ ] Active transfer insert/update çalışıyor
- [ ] Completed transfer active state'ten çıkıyor
- [ ] Transfer history patch ediliyor
- [ ] Vehicle on_route/idle patch uygulanıyor
- [ ] Warehouse reserved capacity patch uygulanıyor
- [ ] Production detail processing response sync ediliyor
- [ ] Production detail gereksiz refetch kaldırıldı
- [ ] Warehouse→production invalidate temizlendi
- [ ] Production→warehouse invalidate temizlendi
- [ ] Warehouse→warehouse invalidate temizlendi
- [ ] Completion refresh'leri temizlendi
- [ ] Gold finish refresh'leri temizlendi
- [ ] Ad finish refresh'leri temizlendi
- [ ] Targeted fallback korunuyor
- [ ] Tüm transfer akışları manuel test edildi

---

## 43. Sonraki Parti Önerisi

Frontend üçüncü parti entegrasyonu tamamlandıktan sonra:

```text
building upgrade
building boost
construction acceleration
```

grubu önerilir.

Özellikle:

```text
start_building_upgrade
complete_building_upgrade
finish_building_upgrade_with_gold
reduce_building_upgrade_time_with_ad
start_building_boost
start_building_boost_with_ad_reward
finish_building_boost
finish_construction_with_gold
reduce_construction_time_with_ad
```

Bu grup mevcut `building_upgrade`, `building_boost`, `building_construction` ve building entity patch altyapısına doğal şekilde oturur.
