# Hard Kapitalizm — Patch Sistemi Backend Değişiklik Raporu

**Tarih:** 2026-09-09  
**Kapsam:** Patch sistemi dönüşümü — Backend İlk Parti  
**Backend:** Supabase / PostgreSQL RPC  
**Amaç:** Frontend tarafında `invalidate/refetch` ihtiyacını azaltmak için mutation RPC'lerinin değiştirdiği verileri response içinde deterministik olarak döndürmesi.

---

# 1. Genel Amaç

Bu çalışmanın amacı, oyun içindeki mutation aksiyonlarından sonra frontend'in geniş provider invalidate işlemleri yapması yerine, backend tarafından döndürülen gerçek değişiklikleri doğrudan local state'e uygulamasını sağlamaktır.

Yeni yaklaşım:

```text
Kullanıcı aksiyonu
    ↓
RPC
    ↓
DB mutation
    ↓
changed.player + changed.patches[]
    ↓
Frontend local state patch
    ↓
Gerekmedikçe refetch / invalidate yok
```

Bu ilk partide backend business logic mümkün olduğunca değiştirilmemiş, esas olarak RPC response'ları genişletilmiştir.

---

# 2. Ortak Patch Response Sözleşmesi

Mutation RPC response'larına aşağıdaki yapı eklenmiştir:

```json
{
  "success": true,
  "changed": {
    "player": {
      "cash": 750000
    },
    "patches": [
      {
        "entity": "warehouse_slot",
        "operation": "update",
        "id": "uuid",
        "changes": {
          "quantity": 400
        }
      }
    ]
  }
}
```

## 2.1 `changed.player`

`players` tablosundaki doğrudan kullanıcı state değişiklikleri için kullanılır.

Örnek:

```json
{
  "changed": {
    "player": {
      "cash": 850000,
      "level": 4,
      "experience": 82
    }
  }
}
```

Frontend tarafında mevcut `PlayerNotifier.applyChanges()` benzeri mekanizmayla uygulanabilir.

---

## 2.2 `changed.patches[]`

Entity bazlı değişiklikler bu dizide döner.

Her patch:

```json
{
  "entity": "store_slot",
  "operation": "update",
  "id": "uuid",
  "changes": {
    "price": 120
  }
}
```

alanlarını içerir.

### Desteklenen operation değerleri

```text
insert
update
delete
```

Anlamları:

- `insert`: yeni entity local listeye eklenmeli.
- `update`: aynı `id`'ye sahip mevcut entity `changes` ile merge edilmelidir.
- `delete`: aynı `id`'ye sahip entity local state/listeden kaldırılmalıdır.

---

# 3. Null Semantiği

Patch sisteminde aşağıdaki iki durum birbirinden ayrılmalıdır:

```json
{}
```

Alan response'ta yoksa:

> Değer değişmedi.

Ancak:

```json
{
  "product_id": null
}
```

geliyorsa:

> `product_id` gerçekten `null` yapılmalıdır.

Frontend parser'ı bu nedenle yalnız:

```dart
value != null
```

kontrolü kullanmamalıdır.

Alan varlığı kontrol edilmelidir:

```dart
changes.containsKey('product_id')
```

Bu özellikle mağaza slotundan ürün kaldırma gibi işlemler için kritiktir.

---

# 4. İlk Partide Patch Sistemine Geçirilen Fonksiyonlar

Canlı backend üzerinde toplam **27 JSONB RPC/helper fonksiyonu** `changed.patches[]` standardını destekleyecek hale getirilmiştir.

Bu rapor bunları gruplar halinde açıklar.

---

# 5. Mağaza Aksiyonları

## 5.1 `set_store_active`

### Değişen tablo

```text
stores
```

### Patch

```json
{
  "entity": "store",
  "operation": "update",
  "id": "<store_id>",
  "changes": {
    "is_active": true,
    "updated_at": "..."
  }
}
```

### Frontend sonucu

Artık mağaza listesi/detail provider invalidate edilmek zorunda değildir.

---

## 5.2 `set_store_slot_active`

### Değişen tablo

```text
store_slots
```

### Patch

```json
{
  "entity": "store_slot",
  "operation": "update",
  "id": "<store_slot_id>",
  "changes": {
    "is_active": true,
    "updated_at": "..."
  }
}
```

---

## 5.3 `set_store_slot_price`

### Değişen tablo

```text
store_slots
```

### DB değişiklikleri

```text
price
last_sale_processed_at
updated_at
```

### Patch response

```json
{
  "entity": "store_slot",
  "operation": "update",
  "id": "<store_slot_id>",
  "changes": {
    "price": 120,
    "last_sale_processed_at": "..."
  }
}
```

### Not

DB'de `updated_at` değişmesine rağmen mevcut patch response'ta ayrıca taşınmıyor.

Bu frontend açısından kritik değildir, fakat ileride tüm patch response'larında timestamp standardizasyonu yapılabilir.

---

## 5.4 `add_store_slot`

### Değişen tablolar

```text
store_slots
stores
```

### Patch 1 — yeni slot

```json
{
  "entity": "store_slot",
  "operation": "insert",
  "id": "<slot_id>",
  "changes": {
    "...": "tam store_slots satırı"
  }
}
```

### Patch 2 — mağaza slot sayısı

```json
{
  "entity": "store",
  "operation": "update",
  "id": "<store_id>",
  "changes": {
    "current_slot_count": 3,
    "updated_at": "..."
  }
}
```

### Frontend

Yeni slot:

```text
storeSlots.add(newSlot)
```

Mağaza:

```text
store.currentSlotCount++
```

şeklinde local patch edilebilir.

---

## 5.5 `clear_store_slot_product`

Bu RPC mağaza rafındaki ürünü temizler.

Eğer rafta stok varsa ürün aynı şehirdeki Genel Depoya geri aktarılır.

### Olası değişiklikler

```text
store_slots          UPDATE
warehouse_slots      UPDATE veya INSERT
```

### Store slot patch

```json
{
  "entity": "store_slot",
  "operation": "update",
  "id": "<store_slot_id>",
  "changes": {
    "product_id": null,
    "brand_id": "00000000-0000-0000-0000-000000000000",
    "quality_level": 0,
    "quantity": 0,
    "price": 0,
    "cost": 0,
    "pending_sale": 0,
    "pending_quantity": 0,
    "updated_at": "..."
  }
}
```

### Warehouse slot

Eşleşen slot varsa:

```text
operation = update
```

Yeni slot oluşturulursa:

```text
operation = insert
```

### Önemli

Bu fonksiyon null semantiğinin frontend tarafında doğru uygulanmasını gerektirir.

---

# 6. Mağaza ↔ Genel Depo Transferleri

## 6.1 `transfer_city_warehouse_to_store_slot`

Genel Depodan mağaza rafına stok aktarır.

### Değişen tablolar

```text
store_slots
warehouse_slots
```

### Store slot patch

```json
{
  "entity": "store_slot",
  "operation": "update",
  "id": "<store_slot_id>",
  "changes": {
    "product_id": "DOMATES",
    "quality_level": 4,
    "brand_id": "...",
    "quantity": 350,
    "cost": 12.45,
    "updated_at": "..."
  }
}
```

### Warehouse slot

Kaynak slotta ürün kalırsa:

```json
{
  "entity": "warehouse_slot",
  "operation": "update",
  "id": "<warehouse_slot_id>",
  "changes": {
    "quantity": 120,
    "updated_at": "..."
  }
}
```

Kaynak slot tamamen boşalırsa:

```json
{
  "entity": "warehouse_slot",
  "operation": "delete",
  "id": "<warehouse_slot_id>",
  "changes": {}
}
```

Bu ayrım frontend için önemlidir.

---

## 6.2 `transfer_store_slot_to_city_warehouse`

Mağaza rafından Genel Depoya stok aktarır.

### Değişen tablolar

```text
store_slots
warehouse_slots
```

### Store slot

```json
{
  "entity": "store_slot",
  "operation": "update",
  "id": "<store_slot_id>",
  "changes": {
    "quantity": 100,
    "updated_at": "..."
  }
}
```

### Warehouse slot

Hedef slot mevcutsa:

```text
update
```

Boş reusable slot kullanıldıysa:

```text
update
```

Gerçekten yeni warehouse slot satırı oluşturulduysa:

```text
insert
```

Yeni slot oluşturulduğunda `changes` tam warehouse slot objesidir.

---

# 7. Depo Aksiyonları

## 7.1 `set_warehouse_slot_price`

### Patch

```json
{
  "entity": "warehouse_slot",
  "operation": "update",
  "id": "<warehouse_slot_id>",
  "changes": {
    "price": 250,
    "updated_at": "..."
  }
}
```

---

## 7.2 `set_warehouse_slot_sale_status`

### Patch

```json
{
  "entity": "warehouse_slot",
  "operation": "update",
  "id": "<warehouse_slot_id>",
  "changes": {
    "is_available_for_sale": true,
    "updated_at": "..."
  }
}
```

---

## 7.3 `delete_warehouse_slot`

Yalnız tamamen boş slotlar silinebilir.

### Patch

```json
{
  "entity": "warehouse_slot",
  "operation": "delete",
  "id": "<warehouse_slot_id>",
  "changes": {}
}
```

Frontend listeden doğrudan kaldırabilir.

---

## 7.4 `discard_warehouse_slot`

Depodaki ürün çöpe atılır.

### Patch

```json
{
  "entity": "warehouse_slot",
  "operation": "delete",
  "id": "<warehouse_slot_id>",
  "changes": {}
}
```

---

# 8. `add_product_to_warehouse_with_brand`

Bu fonksiyon kullanıcı ekranından doğrudan çağrılan bir aksiyon olmak zorunda değildir; birçok backend akışının kullandığı ortak warehouse helper fonksiyonudur.

Patch-aware hale getirilmiştir.

### Değişen tablolar

```text
warehouse_slots
warehouses (bazı durumlarda)
```

## 8.1 Aynı ürün/kalite/marka slotu varsa

```text
warehouse_slot → update
```

## 8.2 Boş mevcut slot doldurulursa

```text
warehouse_slot → update
```

## 8.3 Yeni slot satırı oluşturulursa

```text
warehouse_slot → insert
```

## 8.4 Reserved capacity bırakılıyorsa

`p_release_reserved_capacity = true` durumunda ayrıca:

```json
{
  "entity": "warehouse",
  "operation": "update",
  "id": "<warehouse_id>",
  "changes": {
    "reserved_capacity": 1200,
    "updated_at": "..."
  }
}
```

gelir.

---

# 9. Lojistik Araç Aksiyonları

## 9.1 `set_logistics_vehicle_active`

### Patch

```json
{
  "entity": "logistics_vehicle",
  "operation": "update",
  "id": "<vehicle_id>",
  "changes": {
    "status": "idle",
    "updated_at": "..."
  }
}
```

Pasif durumda:

```text
status = inactive
```

Aktif durumda:

```text
status = idle
```

---

## 9.2 `set_logistics_vehicle_rental`

### Patch

```json
{
  "entity": "logistics_vehicle",
  "operation": "update",
  "id": "<vehicle_id>",
  "changes": {
    "is_available_for_rent": true,
    "rental_price": 5000,
    "updated_at": "..."
  }
}
```

Kiralama kapatıldığında:

```text
rental_price = 0
```

---

## 9.3 `set_logistics_vehicle_route`

### Patch

```json
{
  "entity": "logistics_vehicle",
  "operation": "update",
  "id": "<vehicle_id>",
  "changes": {
    "route_city_a_id": "...",
    "route_city_b_id": "...",
    "updated_at": "..."
  }
}
```

---

## 9.4 `refuel_logistics_vehicle`

Araç, lojistik şirketinin merkez yakıt stoğundan doldurulur.

### Değişen tablolar

```text
logistics_vehicles
logistics_companies
```

### Company patch

```json
{
  "entity": "logistics_company",
  "operation": "update",
  "id": "<company_id>",
  "changes": {
    "current_fuel": 500,
    "fuel_cost": 15.4,
    "updated_at": "..."
  }
}
```

### Vehicle patch

```json
{
  "entity": "logistics_vehicle",
  "operation": "update",
  "id": "<vehicle_id>",
  "changes": {
    "current_fuel": 120,
    "fuel_cost": 15.4,
    "updated_at": "..."
  }
}
```

---

## 9.5 `repair_logistics_vehicle`

### Değişen veriler

```text
players.cash
logistics_vehicles.condition
```

### Player

```json
{
  "changed": {
    "player": {
      "cash": 920000
    }
  }
}
```

### Vehicle

```json
{
  "entity": "logistics_vehicle",
  "operation": "update",
  "id": "<vehicle_id>",
  "changes": {
    "condition": 100,
    "updated_at": "..."
  }
}
```

`logistics_finance_entries` insert edilir fakat frontend core state patch listesine dahil edilmemiştir.

---

## 9.6 `purchase_logistics_vehicle`

### Değişen tablolar

```text
players
logistics_vehicles
logistics_companies
logistics_finance_entries
```

### Player

```json
{
  "cash": 850000
}
```

### New vehicle

```json
{
  "entity": "logistics_vehicle",
  "operation": "insert",
  "id": "<vehicle_id>",
  "changes": {
    "...": "tam yeni logistics_vehicles satırı"
  }
}
```

### Company

```json
{
  "entity": "logistics_company",
  "operation": "update",
  "id": "<company_id>",
  "changes": {
    "current_vehicle_count": 3,
    "updated_at": "..."
  }
}
```

Bu işlem sonrasında artık aşağıdaki gibi geniş invalidate zinciri gerekmemelidir:

```text
playerProvider
logisticsCompanyProvider
logisticsVehiclesProvider
```

Hepsi response üzerinden patch edilebilir.

---

# 10. Depodan Lojistik Şirketine Yakıt Aktarma

## RPC

```text
transfer_warehouse_fuel_to_logistics_company
```

### Değişen tablolar

```text
warehouse_slots
logistics_companies
```

### Warehouse slot

```json
{
  "entity": "warehouse_slot",
  "operation": "update",
  "id": "<slot_id>",
  "changes": {
    "quantity": 200,
    "cost": 12.0,
    "updated_at": "..."
  }
}
```

### Logistics company

```json
{
  "entity": "logistics_company",
  "operation": "update",
  "id": "<company_id>",
  "changes": {
    "current_fuel": 900,
    "fuel_cost": 12.0,
    "updated_at": "..."
  }
}
```

Not: Slot quantity sıfıra inse bile bu RPC şu anda slotu silmiyor; quantity/cost update ediyor.

Frontend de `delete` beklememelidir.

---

# 11. Üretim — Basit State Aksiyonları

Bu ilk partide yalnız basit ve deterministik üretim mutation'ları dönüştürülmüştür.

Ürün/kalite/brand seçimi henüz ikinci partiye bırakılmıştır.

---

## 11.1 `set_factory_active`

### Patch

```json
{
  "entity": "factory",
  "operation": "update",
  "id": "<factory_id>",
  "changes": {
    "is_active": true,
    "updated_at": "...",
    "last_production_at": "..."
  }
}
```

---

## 11.2 `set_mine_active`

### Patch

```json
{
  "entity": "mine",
  "operation": "update",
  "id": "<mine_id>",
  "changes": {
    "is_active": true,
    "updated_at": "...",
    "last_production_at": "..."
  }
}
```

---

## 11.3 `set_production_slot_active`

### Patch

```json
{
  "entity": "production_slot",
  "operation": "update",
  "id": "<slot_id>",
  "changes": {
    "is_active": true,
    "updated_at": "...",
    "last_production_at": "..."
  }
}
```

---

## 11.4 `add_production_slot`

### Değişen tablolar

```text
production_slots
fields veya farms
```

### New production slot

```json
{
  "entity": "production_slot",
  "operation": "insert",
  "id": "<slot_id>",
  "changes": {
    "...": "tam production_slots satırı"
  }
}
```

### Owner patch

Backend owner kind'a göre:

```text
field
```

veya:

```text
farm
```

patch'i üretir.

```json
{
  "entity": "field",
  "operation": "update",
  "id": "<owner_id>",
  "changes": {
    "current_slot_count": 3,
    "updated_at": "..."
  }
}
```

---

# 12. Backend `field` / `farm` Naming Uyarısı

Bu proje için mevcut backend naming korunmaktadır.

```text
backend farm  = UI Tarla
backend field = UI Çiftlik
```

Patch `entity` değerleri backend isimlerini kullanır:

```text
field
farm
```

Frontend dispatcher UI label'e göre değil backend entity adına göre route etmelidir.

---

# 13. `add_production_slot` Geriye Dönük Uyumluluk Riski

Bu ilk parti çalışmasında tespit edilen önemli bir uyumluluk konusu vardır.

Daha önce RPC'nin üst seviye `slot` alanı frontend için zenginleştirilmiş formda dönüyordu:

```json
{
  "slot": {
    "id": "...",
    "product": null
  }
}
```

Şu anda canlı fonksiyonda:

```json
{
  "slot": {
    "...": "ham production_slots satırı"
  }
}
```

dönmektedir.

Yeni:

```text
changed.patches[0].changes
```

alanının ham DB entity olması doğrudur.

Ancak eski üst-seviye:

```text
response.slot
```

frontend tarafından `slot.product` gibi zenginleştirilmiş alanlarla kullanılıyorsa breaking change oluşabilir.

## Öneri

Frontend düzenlemesine başlamadan önce bu RPC'nin eski `slot` response formatı restore edilmelidir.

Patch tarafı aynen kalabilir.

Bu rapordaki ilk parti içinde tespit edilen en belirgin response compatibility riskidir.

---

# 14. İnşaat Başlatma

## RPC

```text
start_building_construction
```

### Değişen tablolar

```text
players
building_constructions
```

### Player

```json
{
  "cash": 750000
}
```

### Construction insert

```json
{
  "entity": "building_construction",
  "operation": "insert",
  "id": "<construction_id>",
  "changes": {
    "id": "...",
    "player_id": "...",
    "building_kind": "factory",
    "params": {},
    "status": "in_progress",
    "started_at": "...",
    "finish_at": "...",
    "completed_at": null
  }
}
```

### Frontend

İnşaat başlatıldıktan sonra:

```text
player invalidate
construction invalidate
```

yerine local patch yapılabilir.

---

# 15. İnşaat Tamamlama

## RPC

```text
complete_building_construction
```

### Değişen tablolar

```text
building_constructions
gerçek bina tablosu
players (XP/level)
```

### Construction

```json
{
  "entity": "building_construction",
  "operation": "update",
  "id": "<construction_id>",
  "changes": {
    "status": "complete",
    "completed_at": "..."
  }
}
```

### Yeni bina

`entity` building kind değerine göre değişir:

```text
store
warehouse
factory
field
farm
mine
arge_center
logistics_company
```

Örneğin factory:

```json
{
  "entity": "factory",
  "operation": "insert",
  "id": "<factory_id>",
  "changes": {
    "...": "tam factories satırı"
  }
}
```

### Player XP

```json
{
  "changed": {
    "player": {
      "level": 4,
      "experience": 82
    }
  }
}
```

Burada bilerek `get_player_profile()` çağrısı kullanılmamaktadır.

Amaç, yalnız değişen player alanlarını dönerek patch response üretiminin kendisini pahalı hale getirmemektir.

---

# 16. Başlangıç Paketi

## RPC

```text
grant_starter_package
```

Tek RPC birden fazla entity'yi değiştirebilir.

### Değişebilen veriler

```text
players
warehouses
warehouse_slots
stores
store_slots
```

### Player

```json
{
  "headquarters_city_id": "...",
  "starter_pack_claimed": true
}
```

### Warehouse

Eğer oyuncunun şehirde Genel Deposu yoksa:

```text
warehouse → insert
```

Depo zaten varsa bu patch oluşmaz.

### Başlangıç ürünleri

```text
DOMATES 500
BIBER   500
```

`add_product_to_warehouse_with_brand` helper üzerinden eklenir.

Bu nedenle slot duruma göre:

```text
warehouse_slot → insert
```

veya:

```text
warehouse_slot → update
```

olabilir.

### Starter store

```text
store → insert
```

### Store slots

`base_slot_count` kadar:

```text
store_slot → insert
```

patch'i oluşur.

---

# 17. Merkez Şehir Seçimi

## RPC

```text
set_player_headquarters_city
```

### Player response

```json
{
  "changed": {
    "player": {
      "headquarters_city_id": "...",
      "headquarters_city_name": "...",
      "starter_pack_claimed": true
    }
  }
}
```

### Starter paket ilk kez veriliyorsa

`grant_starter_package` içindeki patch'ler yukarı taşınır.

Yani aynı response içinde:

```text
warehouse
warehouse_slot
store
store_slot
```

patch'leri de bulunabilir.

Bu nedenle frontend HQ seçimi sonrasında geniş bootstrap reload yapmak zorunda kalmadan local state'i güncelleyebilir.

---

# 18. İlk Partide Kullanılan Entity İsimleri

Frontend dispatcher aşağıdaki entity değerlerini desteklemelidir:

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

`player` ayrıca generic `patches[]` içinde değil:

```text
changed.player
```

üzerinden güncellenmektedir.

---

# 19. Frontend Mutation Dispatcher Önerisi

Önerilen merkezi akış:

```dart
void applyMutationResponse(Map<String, dynamic> response) {
  final changed = response['changed'];

  if (changed is! Map<String, dynamic>) return;

  final player = changed['player'];

  if (player is Map<String, dynamic>) {
    ref.read(playerProvider.notifier).applyChanges(
      PlayerChanges.fromJson(player),
    );
  }

  final patches = changed['patches'];

  if (patches is List) {
    for (final rawPatch in patches) {
      applyEntityPatch(
        EntityPatch.fromJson(rawPatch),
      );
    }
  }
}
```

Generic model:

```dart
enum PatchOperation {
  insert,
  update,
  delete,
}

class EntityPatch {
  final String entity;
  final String id;
  final PatchOperation operation;
  final Map<String, dynamic> changes;
}
```

---

# 20. Önerilen Patch Routing

Örnek dispatcher:

```dart
switch (patch.entity) {
  case 'store':
    storePatchHandler.apply(patch);
    break;

  case 'store_slot':
    storeSlotPatchHandler.apply(patch);
    break;

  case 'warehouse':
    warehousePatchHandler.apply(patch);
    break;

  case 'warehouse_slot':
    warehouseSlotPatchHandler.apply(patch);
    break;

  case 'logistics_company':
    logisticsCompanyPatchHandler.apply(patch);
    break;

  case 'logistics_vehicle':
    logisticsVehiclePatchHandler.apply(patch);
    break;

  case 'factory':
    factoryPatchHandler.apply(patch);
    break;

  case 'mine':
    minePatchHandler.apply(patch);
    break;

  case 'field':
    fieldPatchHandler.apply(patch);
    break;

  case 'farm':
    farmPatchHandler.apply(patch);
    break;

  case 'production_slot':
    productionSlotPatchHandler.apply(patch);
    break;

  case 'building_construction':
    buildingConstructionPatchHandler.apply(patch);
    break;
}
```

Her şeyi `MutationSyncService` içine doğrudan koymak yerine feature handler'lara dağıtmak daha sürdürülebilir olacaktır.

---

# 21. Update Merge Kuralı

`update` operation geldiğinde frontend yalnız `changes` içindeki alanları değiştirmelidir.

Örnek mevcut entity:

```json
{
  "id": "x",
  "quantity": 500,
  "price": 100,
  "quality_level": 4,
  "product_id": "DOMATES"
}
```

Patch:

```json
{
  "operation": "update",
  "changes": {
    "quantity": 400
  }
}
```

Sonuç:

```json
{
  "id": "x",
  "quantity": 400,
  "price": 100,
  "quality_level": 4,
  "product_id": "DOMATES"
}
```

Tam entity replace yapılmamalıdır.

---

# 22. Insert Kuralı

`insert` operation için backend mümkün olduğunca tam yeni entity satırını döndürmektedir.

Frontend:

1. Aynı ID zaten varsa duplicate insert yapmamalı.
2. Varsa update/replace fallback yapabilir.
3. Yoksa listeye eklemelidir.

Öneri:

```dart
if (list.any((e) => e.id == patch.id)) {
  patchExisting();
} else {
  insertNew();
}
```

Bu retry/double-response durumlarına karşı sistemi idempotent hale getirir.

---

# 23. Delete Kuralı

`delete` patch için yalnız ID yeterlidir.

```json
{
  "entity": "warehouse_slot",
  "operation": "delete",
  "id": "...",
  "changes": {}
}
```

Frontend:

```dart
list.removeWhere((e) => e.id == patch.id);
```

Entity local state'te yoksa hata verilmemesi önerilir.

---

# 24. Invalidate Fallback Politikası

Patch migration tamamlanırken invalidate tamamen kaldırılmamalıdır.

Önerilen geçiş sırası:

```text
1. RPC response patch uygula
2. Patch başarıyla uygulandıysa invalidate yapma
3. Patch parse/apply edilemediyse targeted invalidate
4. Gerekirse feature refresh
5. En son global refresh
```

Amaç:

```text
Patch first
Refetch second
Invalidate fallback
```

olmalıdır.

---

# 25. Bu Partide Henüz Dönüştürülmeyen Ana Alanlar

Aşağıdaki sistemler ikinci ve sonraki partilere bırakılmıştır:

## Production config

```text
assign_production_slot_product
change_production_slot_product
set_factory_product
set_mine_product
brand/quality selection
production_inventory lifecycle
```

## Intercity logistics

```text
start_warehouse_to_warehouse_transfer
start_multi_warehouse_to_production_transfer
start_multi_production_to_warehouse_transfer
start_multi_market_transfer
start_city_consolidated_transfer
transfer completion
gold/ad fast finish
```

## Building upgrade / boost

```text
start_building_upgrade
complete_building_upgrade
finish_building_upgrade_with_gold
reduce_building_upgrade_time_with_ad
start_building_boost
finish_building_boost
ad boost
```

## Economy

```text
loans
deposits
tax
tenders
market
store sales
```

## Progression

```text
missions
achievements
daily streak
Ar-Ge
brand company
```

Bu sistemlere frontend ilk parti entegrasyonu tamamlandıktan sonra geçilecektir.

---

# 26. Bilinçli Olarak Patch'e Dahil Edilmeyen Yan Etki Tabloları

Bazı mutation'larda audit/history tablolarına da kayıt atılır.

Örnek:

```text
player_cash_ledger
logistics_finance_entries
player_experience_logs
```

Bu tablolar mutation'ın core gameplay state'i olarak patch listesine eklenmemiştir.

Sebep:

- çoğu ekran tarafından sürekli local state olarak tutulmuyor,
- history/ledger ekranları ayrı getter/RPC üzerinden yükleniyor,
- her mutation response'unu gereksiz büyütmemek gerekiyor.

İleride ilgili ekran açıkken patch edilmesi istenirse ayrı `dirty` veya history patch stratejisi eklenebilir.

---

# 27. Player Patch Optimizasyonu

Patch response oluşturmak için mümkün olduğunca:

```text
get_player_profile()
```

çağrısı kullanılmamalıdır.

Bu getter:

- achievement senkronizasyonu,
- company value hesabı,
- level progress,
- profile composition

gibi ekstra işler yapabilmektedir.

Örneğin araç satın alma işleminde yalnız:

```json
{
  "cash": 850000
}
```

dönmektedir.

İnşaat tamamlamada yalnız:

```json
{
  "level": 4,
  "experience": 82
}
```

dönmektedir.

Bu patch mimarisinin performans amacına uygundur.

---

# 28. Geriye Dönük Uyumluluk Politikası

Patch migration sırasında RPC'lerin mevcut üst-seviye response alanlarının mümkün olduğunca korunması hedeflenmiştir.

Yeni:

```text
changed
```

alanı mevcut response'un üzerine eklenmektedir.

Frontend eski alanları kullanmaya devam ederken yeni patch sistemine kademeli geçebilir.

### Bilinen istisna

`add_production_slot.slot` formatı kontrol edilmelidir.

Bu fonksiyon ikinci parti başlamadan önce restore edilmelidir.

---

# 29. Frontend İçin Önerilen İlk Uygulama Sırası

Backend ilk partisine karşı frontend tarafında önerilen sıra:

## 1. Generic patch model

```text
EntityPatch
PatchOperation
```

## 2. Mutation response parser

```text
changed.player
changed.patches[]
```

## 3. Warehouse handlers

```text
warehouse
warehouse_slot
```

## 4. Store handlers

```text
store
store_slot
```

## 5. Logistics handlers

```text
logistics_company
logistics_vehicle
```

## 6. Production simple handlers

```text
factory
mine
field
farm
production_slot
```

## 7. Construction handlers

```text
building_construction
new building insert
```

## 8. İlgili invalidate'ları kaldır

Her mutation tek tek test edilerek kaldırılmalı.

---

# 30. Test Checklist — İlk Parti

Frontend dönüşümü sırasında aşağıdaki aksiyonlar test edilmelidir.

## Store

- [ ] Mağazayı pasif yap
- [ ] Mağazayı aktif yap
- [ ] Store slot aktif/pasif
- [ ] Store slot fiyat değiştir
- [ ] Yeni store slot aç
- [ ] Store slot ürününü temizle
- [ ] Depodan mağazaya ürün aktar
- [ ] Mağazadan depoya ürün aktar
- [ ] Kaynak warehouse slot tamamen bitince local listeden siliniyor mu?

## Warehouse

- [ ] Warehouse slot fiyat değiştir
- [ ] Market satışına aç
- [ ] Market satışından kaldır
- [ ] Boş warehouse slot sil
- [ ] Dolu slotu çöpe at
- [ ] Existing slot update
- [ ] New slot insert
- [ ] Reserved capacity patch

## Logistics

- [ ] Araç satın al
- [ ] Company vehicle count local artıyor mu?
- [ ] Player cash local azalıyor mu?
- [ ] Araç aktif/pasif
- [ ] Araç kiraya aç/kapat
- [ ] Kira fiyat değişikliği
- [ ] Araç rota değişikliği
- [ ] Araç yakıt doldurma
- [ ] Company fuel local azalıyor mu?
- [ ] Vehicle fuel local artıyor mu?
- [ ] Araç tamiri
- [ ] Cash düşüyor mu?
- [ ] Condition 100 oluyor mu?
- [ ] Depodan lojistik merkezine yakıt gönder

## Production simple

- [ ] Factory active toggle
- [ ] Mine active toggle
- [ ] Production slot active toggle
- [ ] Yeni production slot aç
- [ ] Owner current_slot_count artıyor mu?

## Construction

- [ ] İnşaat başlat
- [ ] Player cash anlık düşüyor mu?
- [ ] Construction local listeye insert oluyor mu?
- [ ] İnşaat tamamlanınca status complete oluyor mu?
- [ ] Yeni bina local listeye insert oluyor mu?
- [ ] Player XP/level doğru patch oluyor mu?

## Starter

- [ ] HQ seç
- [ ] Starter warehouse local state'e geliyor mu?
- [ ] 500 DOMATES geliyor mu?
- [ ] 500 BIBER geliyor mu?
- [ ] Starter store geliyor mu?
- [ ] Store slots geliyor mu?
- [ ] Player starter_pack_claimed true oluyor mu?

---

# 31. Patch Uygulaması Sonrası Beklenen Kazanç

Bu ilk partinin frontend entegrasyonu tamamlandığında aşağıdaki geniş invalidate/refetch akışlarının önemli kısmı kaldırılabilir:

```text
warehouse list refresh
warehouse detail refresh
store list refresh
store detail refresh
vehicle list refresh
logistics company refresh
player profile refresh
construction refresh
production list refresh
```

Özellikle:

```text
warehouse ↔ store
vehicle management
construction
```

aksiyonlarında network round-trip sayısının ciddi şekilde düşmesi beklenir.

---

# 32. Son Durum

Backend ilk parti patch dönüşümü tamamlanmış durumdadır.

Canlı backend'de:

```text
27 JSONB RPC/helper
```

yeni `changed.patches[]` sözleşmesini üretmektedir.

Bu aşamada plan:

```text
1. Frontend ilk parti patch entegrasyonu
2. Test
3. add_production_slot compatibility düzeltmesi
4. Kalan invalidate'ların ilk parti için temizlenmesi
5. İkinci backend partisi
```

şeklinde ilerlemelidir.

---

# 33. İkinci Partiye Geçmeden Önce Kontrol Edilecekler

- [ ] Frontend `changed.player` parse ediyor.
- [ ] Frontend `changed.patches[]` parse ediyor.
- [ ] `insert/update/delete` destekleniyor.
- [ ] Null patch semantiği doğru.
- [ ] Warehouse slot delete doğru çalışıyor.
- [ ] Insert duplicate koruması var.
- [ ] Field/farm naming doğru.
- [ ] `add_production_slot.slot` compatibility kontrol edildi.
- [ ] İlk parti mutation'larında unnecessary invalidate kaldırıldı.
- [ ] İlk parti aksiyonlar manuel/integration testten geçti.

Bu kontroller tamamlandıktan sonra ikinci backend partisine geçilmesi önerilir.
