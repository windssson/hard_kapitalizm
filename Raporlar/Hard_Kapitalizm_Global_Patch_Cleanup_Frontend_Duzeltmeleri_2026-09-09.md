# Hard Kapitalizm — Global Patch Cleanup Frontend Düzeltmeleri

**Tarih:** 2026-09-09  
**Durum:** Parti 1–6 tamamlandı. Bu dosya patch dönüşümünden sonra kalan global frontend cleanup işlerini içerir.  
**Backend:** İlgili backend cleanup migrationları canlı Supabase üzerinde uygulanmıştır.

---

# 1. Amaç

Ana patch sistemi artık tamamlandı.

Kalan frontend işi:

```text
RPC
↓
MutationSyncService
↓
EntityPatchDispatcher
↓
Feature Notifier
↓
UI
```

zincirini tek authoritative state update yolu haline getirmektir.

Temizlenecek ana problemler:

```text
1. building_construction INSERT dispatcher desteği eksik
2. construction completion gereğinden geniş invalidate yapıyor
3. upgrade mutation sonrası UI tekrar manual patch yapıyor
4. boost mutation sonrası UI tekrar manual patch yapıyor
5. Store bazı response'ları MutationSyncService'e iki kez gönderiyor
6. bulk store aksiyonlarında manual snapshot patch artık gereksiz
7. AR-GE / Logistics construction start invalidate kalıntıları var
8. Son global invalidate / refresh / manual patch taraması yapılmalı
```

---

# 2. Backend'de tamamlanan cleanup

Frontend şu yeni contract'lara güvenebilir.

## 2.1 `start_arge_center_construction`

Artık response:

```text
changed.player
building_construction INSERT
```

döndürür.

## 2.2 `start_logistics_company_construction`

4 parametreli:

```text
start_logistics_company_construction(
  p_player_id,
  p_type_id,
  p_city_id,
  p_name
)
```

artık:

```text
changed.player
building_construction INSERT
```

döndürür.

3-parametreli overload bu fonksiyona delegate eder.

## 2.3 `bulk_update_store_slot_prices`

Artık scoped diff ile gerçek patch üretir:

```text
store
store_slot
warehouse
warehouse_slot
player
```

## 2.4 `fill_store_shelves`

Artık gerçek:

```text
store_slot UPDATE
warehouse_slot UPDATE / DELETE
```

patch'leri döndürür.

Legacy:

```text
updated_store_slots
updated_warehouse_slots
```

alanları response'ta kalsa bile frontend state için authoritative kaynak olmamalıdır.

---

# 3. Öncelik 1 — `building_construction INSERT` handler

Mevcut dispatcher:

```dart
void _applyBuildingConstructionPatch(EntityPatch patch)
```

şu anda esas olarak:

```text
completion/delete
finish_at update
```

işlemektedir.

`insert` desteği eklenmelidir.

---

# 4. Construction model stratejisi

Her feature'daki construction provider yapısını kontrol et.

Beklenen providerlar:

```text
factoryConstructionProvider
mineConstructionProvider
fieldConstructionProvider
farmConstructionProvider
playerArgeConstructionProvider
playerLogisticsConstructionProvider
```

Patch'teki temel alanlar:

```text
id
player_id
building_kind
params
status
started_at
finish_at
completed_at
```

`params` içinde tipe göre:

```text
type_id
city_id
name
```

bulunabilir.

---

# 5. `building_construction INSERT` uygulaması

Önerilen ana yapı:

```dart
void _applyBuildingConstructionPatch(EntityPatch patch) {
  final buildingKind = (
    patch.changes['building_kind'] ??
    patch.changes['entity_kind'] ??
    ''
  ).toString();

  if (patch.operation == PatchOperation.insert) {
    _applyConstructionInsert(
      buildingKind: buildingKind,
      patch: patch,
    );
    return;
  }

  ...
}
```

---

# 6. Field / Farm / AR-GE construction insert

Bu providerlar zaten notifier tabanlı local state destekliyorsa doğrudan set kullanılmalı.

Örnek:

```dart
if (buildingKind == 'field') {
  final model = BuildingConstructionModel.fromJson(patch.changes);
  _ref
      .read(fieldConstructionProvider.notifier)
      .setConstruction(model);
  return;
}
```

Aynı mantık:

```text
farm
arge_center
```

için.

Provider API farklıysa mevcut modele uygun:

```text
setConstruction
set
replace
patch
```

metodu eklenebilir.

---

# 7. Factory / Mine / Logistics construction insert

Eğer bunların mevcut providerları `FutureProvider` ise iki seçenek vardır.

## Tercih edilen

Patch edilebilir `AsyncNotifier` yapısına geçirmek.

Örnek:

```dart
class FactoryConstructionNotifier
    extends AsyncNotifier<BuildingConstructionModel?> {

  @override
  Future<BuildingConstructionModel?> build() => _fetch();

  void setConstruction(BuildingConstructionModel value) {
    state = AsyncData(value);
  }

  void patchFinishAt(DateTime value) {
    final current = state.value;
    if (current == null) return;

    state = AsyncData(
      current.copyWith(finishAt: value),
    );
  }

  void clear() {
    state = const AsyncData(null);
  }
}
```

## Geçici fallback

Provider dönüşümü fazla büyükse:

```text
INSERT -> yalnız ilgili construction provider targeted invalidate
```

kabul edilebilir.

Ama:

```text
factory + mine + logistics
```

üçünü aynı anda invalidate etme.

---

# 8. Construction completion broad invalidate temizliği

Mevcut hatalı pattern:

```dart
if (isComplete) {
  _ref.invalidate(factoryConstructionProvider);
  _ref.invalidate(mineConstructionProvider);
  _ref.invalidate(playerLogisticsConstructionProvider);

  _ref.read(fieldConstructionProvider.notifier).clear();
  _ref.read(farmConstructionProvider.notifier).clear();
  _ref.read(playerArgeConstructionProvider.notifier).clear();
}
```

Bu kaldırılmalı.

---

# 9. Completion yalnız ilgili feature'ı güncellemeli

Öneri:

```dart
if (isComplete) {
  switch (buildingKind) {
    case 'factory':
      _clearFactoryConstruction();
      break;

    case 'mine':
      _clearMineConstruction();
      break;

    case 'field':
      _ref.read(fieldConstructionProvider.notifier).clear();
      break;

    case 'farm':
      _ref.read(farmConstructionProvider.notifier).clear();
      break;

    case 'arge_center':
      _ref.read(playerArgeConstructionProvider.notifier).clear();
      break;

    case 'logistics_company':
      _clearLogisticsConstruction();
      break;
  }

  return;
}
```

Unknown kind durumunda debug log bırak.

---

# 10. Construction `finish_at` update

Aynı prensip:

```text
yalnız ilgili construction provider
```

güncellenmeli.

Factory / Mine / Logistics notifier'a çevrilmişse:

```dart
patchFinishAt(finishAt)
```

kullan.

Aksi halde yalnız ilgili targeted invalidate kabul edilebilir.

---

# 11. AR-GE construction action cleanup

Dosya:

```text
lib/features/arge/data/arge_provider.dart
```

Mevcut:

```dart
final response = await _supabase.rpc(
  'start_arge_center_construction',
  ...
);

if (syncProviders) {
  _ref.invalidate(playerArgeCenterProvider);
  _ref.invalidate(playerArgeConstructionProvider);
}

return _sync(response);
```

Yeni:

```dart
final response = await _supabase.rpc(
  'start_arge_center_construction',
  ...
);

return _sync(response);
```

`syncProviders` parametresi yalnız bu fonksiyon için artık anlamsızsa kaldırılabilir.

---

# 12. Logistics construction action cleanup

Dosya:

```text
lib/features/logistics/data/logistics_provider.dart
```

Mevcut:

```dart
if (syncProviders) {
  _ref.invalidate(playerLogisticsCompanyProvider);
  _ref.invalidate(playerLogisticsConstructionProvider);
}

return _sync(response);
```

Yeni:

```dart
return _sync(response);
```

Construction INSERT dispatcher tarafından local uygulanmalı.

---

# 13. Construction screen callback cleanup

Şu screen'leri tara:

```text
factory_screen.dart
mine_screen.dart
field_screen.dart
farm_screen.dart
arge_screen.dart
logistics_management_screen.dart
warehouse_screen.dart
building_type_selection_screen.dart
```

Mutation success sonrasında şu patternleri ara:

```dart
ref.invalidate(...ConstructionProvider)
ref.read(...ListProvider.notifier).refresh()
ref.invalidate(...ListProvider)
```

RPC patch response zaten entity insert/delete/update getiriyorsa kaldır.

---

# 14. Building creation sonrası list refresh

Önemli:

`complete_building_construction` response'u final entity insert patch'i getirir:

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

Dispatcher insert handler'ı ilgili list provider'ı patchliyorsa success sonrasında:

```dart
listProvider.refresh()
```

gereksizdir.

Ancak raw DB insert'te UI list modeli için zorunlu joined metadata yoksa targeted refresh kalabilir.

Her entity için ayrı karar ver.

---

# 15. Factory insert metadata riski

Factory insert handler şu tarz fallback isimler üretiyorsa:

```text
cityName = "Şehir"
factoryTypeName = "Fabrika"
factoryTypeIcon = "factory.webp"
```

bu eksik metadata üretebilir.

Eğer backend final factory patch sadece raw `factories` row döndürüyorsa:

```text
factory INSERT -> factoryListProvider targeted refresh
```

daha güvenlidir.

Aynı kontrol:

```text
mine
store
warehouse
```

için de yapılmalı.

---

# 16. Öncelik 2 — Upgrade double patch temizliği

Patch-aware RPC'ler:

```text
start_building_upgrade
complete_building_upgrade
finish_building_upgrade_with_gold
reduce_building_upgrade_time_with_ad
```

Action provider zaten:

```dart
_sync(response)
```

çalıştırır.

UI bir daha state yazmamalıdır.

---

# 17. Upgrade manual patch kaldırılacak yerler

Ara:

```text
BuildingUpgradeModel.fromJson(result)
setUpgrade(
patchActiveUpgrade(
```

Özellikle:

```text
arge_screen.dart
factory_detail_screen.dart
mine_detail_screen.dart
field_detail_screen.dart
farm_detail_screen.dart
warehouse_detail_screen.dart
store_detail_screen.dart
```

---

# 18. Upgrade success yeni pattern

Eski:

```dart
final result = await action.startUpgrade(...);

if (result['success'] == true) {
  final upgrade = BuildingUpgradeModel.fromJson(result);

  ref
      .read(activeFactoryUpgradeProvider(id).notifier)
      .setUpgrade(upgrade);

  showSuccess();
}
```

Yeni:

```dart
final result = await action.startUpgrade(...);

if (result['success'] == true) {
  showSuccess();
}
```

State dispatcher tarafından uygulanmış olmalı.

---

# 19. Store upgrade özel double sync

Store tarafında şu tip akış varsa:

```dart
final result = await action.startStoreUpgrade(...);

final upgrade = BuildingUpgradeModel.fromJson(result);

ref
    .read(storeDetailPageProvider(store.id).notifier)
    .patchActiveUpgrade(upgrade);

ref
    .read(storeDetailPageProvider(store.id).notifier)
    .applyMutation(result);
```

bu tamamen yanlış.

Çünkü action zaten:

```text
_sync(result)
```

yaptı.

Yeni:

```dart
final result = await action.startStoreUpgrade(...);

if (result['success'] == true) {
  showSuccess();
}
```

---

# 20. Upgrade completion manual level patch

Şu patternleri ara:

```text
patchStoreLevel
patchFactoryLevel
patchMineLevel
patchFieldLevel
patchFarmLevel
```

upgrade completion response'u final building entity patch'i döndürüyorsa UI seviyeyi tekrar elle değiştirmemeli.

Örnek eski:

```dart
ref
    .read(storesListProvider.notifier)
    .patchStoreLevel(
      storeId: widget.storeId,
      level: upgrade.targetLevel,
    );

applyMutation(result);
```

Yeni:

```dart
// hiçbir state write yok
```

---

# 21. Öncelik 3 — Boost double patch temizliği

Patch-aware RPC'ler:

```text
start_building_boost
start_building_boost_with_ad_reward
finish_building_boost
```

Action `_sync(response)` yaptıktan sonra UI tekrar:

```dart
setBoost(
  BuildingBoostModel.fromJson(result),
);
```

yapmamalıdır.

---

# 22. Boost manual patch kaldırılacak yerler

Ara:

```text
BuildingBoostModel.fromJson(result)
setBoost(
patchActiveBoost(
```

Dosyalar:

```text
factory_detail_screen.dart
mine_detail_screen.dart
field_detail_screen.dart
farm_detail_screen.dart
store_detail_screen.dart
```

---

# 23. Boost success yeni pattern

Eski:

```dart
final result = await action.startFieldBoost(...);

if (result['success'] == true) {
  ref
      .read(activeFieldBoostProvider(id).notifier)
      .setBoost(
        BuildingBoostModel.fromJson(result),
      );
}
```

Yeni:

```dart
final result = await action.startFieldBoost(...);

if (result['success'] == true) {
  showSuccess();
}
```

---

# 24. Öncelik 4 — Store `applyMutation(result)` double sync

Ara:

```text
applyMutation(result)
```

Özellikle:

```text
store_detail_screen.dart
```

Action method zaten `_sync()` çağırdıysa UI'daki:

```dart
ref
    .read(storeDetailPageProvider(id).notifier)
    .applyMutation(result);
```

kaldır.

---

# 25. `StoreDetailPageNotifier.applyMutation`

Metot:

```dart
void applyMutation(Map<String, dynamic> response) {
  ref
      .read(mutationSyncServiceProvider)
      .applyRaw(response);
}
```

Eğer cleanup sonrası hiçbir callsite kalmazsa bu metodu tamamen kaldır.

---

# 26. Öncelik 5 — Bulk store price manual patch temizliği

Backend artık:

```text
bulk_update_store_slot_prices
```

için gerçek `store_slot` patch'leri döndürüyor.

Eski UI:

```dart
final updatedSlots = result['updated_slots'];

storeDetailNotifier.bulkPatchSlotPrices(updatedSlots);

storesListNotifier.bulkPatchSlotPrices(
  storeId: store.id,
  updatedSlots: updatedSlots,
);
```

kaldırılmalı.

Yeni:

```dart
final result =
    await storeAction.bulkUpdateStoreSlotPrices(...);

if (result['success'] == true) {
  showSuccess();
}
```

---

# 27. Bulk price compatibility

Response'taki:

```text
updated_slots
```

alanını UI feedback için kullanmak istersen kalabilir.

Ama state update için kullanılmamalıdır.

---

# 28. Öncelik 6 — Fill shelves manual patch temizliği

Backend artık gerçek:

```text
store_slot
warehouse_slot
```

patch'leri üretmektedir.

Eski:

```dart
final updatedStoreSlots =
    result['updated_store_slots'];

final updatedWarehouseSlots =
    result['updated_warehouse_slots'];

storeDetailNotifier.bulkPatchSlotQuantities(
  updatedStoreSlots,
);

storeDetailNotifier.bulkPatchCityWarehouseSlots(
  updatedWarehouseSlots,
);
```

kaldırılmalıdır.

---

# 29. Fill shelves success yeni pattern

```dart
final result =
    await storeAction.fillStoreShelves(
      storeId: store.id,
    );

if (result['success'] == true) {
  showSuccess();
}
```

State:

```text
MutationSyncService
→ store_slot handler
→ warehouse_slot handler
```

ile güncellenmeli.

---

# 30. Store slot dispatcher kontrolü

Bulk price / fill shelves cleanup'tan önce doğrula:

`store_slot UPDATE` handler en az:

```text
quantity
price
cost
pending_quantity
capacity
is_active
product_id
quality_level
brand_id
```

alanlarını doğru uyguluyor olmalı.

Eksik alan varsa tamamla.

---

# 31. Warehouse slot dispatcher kontrolü

`warehouse_slot UPDATE/DELETE` en az:

```text
quantity
cost
price
is_available_for_sale
product_id
quality_level
brand_id
```

alanlarını doğru uygulamalı.

Delete:

```text
warehouse list/detail
store embedded city warehouse
market own listing
```

state'inde gerekli etkileri kontrol et.

---

# 32. `syncProviders` cleanup

Projede şu pattern çok yaygın:

```dart
someMutation(..., syncProviders: false)
```

ama action her durumda:

```dart
_sync(response)
```

çalıştırıyor.

Bu nedenle parametre adı yanıltıcıdır.

İki seçenek:

## Tercih edilen

Patch-aware mutationlarda `syncProviders` parametresini kaldır.

## Alternatif

Anlamını:

```text
legacy targeted refresh enable/disable
```

olarak netleştir ve sadece gerçekten fallback gereken yerlerde kullan.

Ama:

```text
syncProviders = false
```

asla `MutationSyncService`i kapatmamalıdır.

---

# 33. Global search — manual patch

Şu kelimeleri tüm repo'da ara:

```text
BuildingUpgradeModel.fromJson(result)
BuildingBoostModel.fromJson(result)

applyMutation(result)

bulkPatchSlotPrices(
bulkPatchSlotQuantities(
bulkPatchCityWarehouseSlots(

setUpgrade(
setBoost(

patchActiveUpgrade(
patchActiveBoost(
```

Her callsite için sor:

```text
Action zaten _sync(response) yaptı mı?
```

Evet ise UI manual state write'ı büyük ihtimalle kaldırılmalı.

---

# 34. Global search — invalidate

Tüm repo'da ara:

```text
ref.invalidate(
invalidateSelf(
.refresh()
reload
refetch
```

Ancak her invalidate hata değildir.

---

# 35. Korunması gereken invalidate türleri

Aşağıdakiler normaldir:

```text
pull-to-refresh
route refresh
explicit user refresh
session/login/logout reset
static catalog manual refresh

joined/enriched view targeted refresh
transfer map enriched refresh
transfer history loaded-state refresh
derived financial limit refresh
derived capacity status refresh
```

---

# 36. Kaldırılması gereken invalidate türleri

Mutation success'tan hemen sonra:

```text
RPC
↓
patch response
↓
aynı entity provider invalidate
```

oluyorsa gereksizdir.

Örnek:

```text
start construction
→ building_construction insert patch
→ constructionProvider invalidate
```

kaldır.

---

# 37. Route refresh ile mutation refresh'i karıştırma

Örneğin:

```dart
@override
void refreshRouteData() {
  ref.invalidate(factoryListProvider);
}
```

route tekrar görünür olduğunda bilerek fresh data almak için kullanılıyorsa bu patch sisteminin hatası değildir.

Global cleanup sırasında route lifecycle refresh'lerini körlemesine silme.

---

# 38. Dashboard dirty

`MutationSyncService` içinde:

```dart
if (mutation.dashboardDirty) {
  _ref.invalidate(homeDashboardProvider);
}
```

şimdilik kalabilir.

Dashboard joined/aggregate model olduğu için patch etmek ayrı çalışma gerektirir.

Bu cleanup'ın kapsamına dahil değil.

---

# 39. Mission dirty

Mevcut kural doğru:

```text
player_mission patch varsa local
yoksa targeted dashboard invalidate
```

koru.

---

# 40. Tax dirty

Mevcut kural doğru:

```text
player_tax patch varsa local
yoksa targeted tax refresh
```

koru.

---

# 41. Achievement dirty

Şu anda achievement patch entity yoksa:

```text
playerAchievementDashboardProvider invalidate
```

kalabilir.

---

# 42. Transfer item targeted invalidate

`logistics_transfer_item` raw patch sonrası:

```dart
ref.invalidate(
  transferItemsProvider(transferId),
);
```

kullanılıyorsa bu provider enriched veya grouped bir getter ise kabul edilebilir.

Bu cleanup'ta zorla kaldırma.

---

# 43. Construction provider standardizasyonu

Uzun vadeli öneri:

Bütün construction providerlarını aynı interface'e getir:

```dart
abstract interface class ConstructionPatchController {
  void setConstruction(BuildingConstructionModel model);
  void patchFinishAt(DateTime finishAt);
  void clear();
}
```

Feature notifierları:

```text
factory
mine
field
farm
arge
logistics
warehouse
store
```

mümkün olduğunca aynı API'yi kullansın.

---

# 44. MutationSync tek owner prensibi

Final kural:

```text
RPC response state ownership = MutationSyncService
```

UI yalnız:

```text
loading
dialog
snackbar
navigation
animation
```

yönetmelidir.

UI mutation response'tan entity model oluşturup provider'a yazmamalıdır.

---

# 45. İstisna

Backend patch'inde UI için gerekli joined/enriched metadata yoksa:

```text
MutationSyncService
→ targeted refresh
```

yapılabilir.

Ama bu fallback dispatcher/notifier katmanında merkezi olmalıdır.

UI ekranı kendi başına:

```dart
if success:
  invalidate X
  refresh Y
```

yapmamalıdır.

---

# 46. Test — Construction start

Her building kind için:

```text
factory
mine
field
farm
arge_center
logistics_company
warehouse
store
```

test et.

- [ ] mutation success
- [ ] player cash patch
- [ ] building_construction insert local görünür
- [ ] broad invalidate yok
- [ ] timer anında başlıyor
- [ ] uygulamayı kapatmadan doğru state

---

# 47. Test — Construction finish

Her kind için:

- [ ] completion patch
- [ ] construction yalnız ilgili feature'da clear
- [ ] final building insert/update geliyor
- [ ] diğer construction providerları etkilenmiyor
- [ ] list/detail state doğru

---

# 48. Test — Upgrade

Her yapı:

```text
store
warehouse
factory
mine
field
farm
arge_center
```

için:

- [ ] start upgrade
- [ ] active upgrade bir kez oluşuyor
- [ ] duplicate state write yok
- [ ] ad time reduction
- [ ] gold finish
- [ ] natural completion
- [ ] level/capacity final patch doğru
- [ ] upgrade clear

---

# 49. Test — Boost

```text
store
factory
mine
field
farm
```

- [ ] star boost
- [ ] ad boost
- [ ] active boost bir kez oluşuyor
- [ ] multiplier doğru
- [ ] natural finish
- [ ] manual double patch yok

---

# 50. Test — Bulk prices

- [ ] mağazada birden fazla aktif ürün slotu oluştur
- [ ] toplu kâr marjı uygula
- [ ] bütün slot price değerleri local güncelleniyor
- [ ] full store refetch yok
- [ ] `updated_slots` manual patch kullanılmıyor

---

# 51. Test — Fill shelves

- [ ] şehir deposunda uygun ürün stoğu oluştur
- [ ] mağazada boş kapasite bırak
- [ ] "rafları doldur"
- [ ] store slot quantity artıyor
- [ ] warehouse slot quantity azalıyor
- [ ] sıfırlanan warehouse slot local siliniyor
- [ ] full warehouse/store refresh yok
- [ ] manual bulk snapshot patch kullanılmıyor

---

# 52. Regression — Market

6. parti bozulmamalı:

- [ ] market listing patch
- [ ] cart clamp/remove
- [ ] same-city purchase
- [ ] intercity purchase
- [ ] batch market completion
- [ ] market transfer double-completion yok

---

# 53. Regression — Production

- [ ] production_slot product config
- [ ] brand/quality change
- [ ] production inventory insert/update/delete
- [ ] detail-open production processing
- [ ] transfer completion

---

# 54. Regression — Finance/Tender

- [ ] loan
- [ ] deposit
- [ ] tax
- [ ] brand
- [ ] AR-GE research
- [ ] mission reward
- [ ] tender accept/bid/delivery

---

# 55. Static audit commands / searches

Agent repo'da şunları tarasın:

```text
ref.invalidate(
invalidateSelf(
.refresh(
applyMutation(
BuildingUpgradeModel.fromJson(result)
BuildingBoostModel.fromJson(result)
bulkPatchSlotPrices(
bulkPatchSlotQuantities(
bulkPatchCityWarehouseSlots(
syncProviders
```

Her eşleşme için:

```text
mutation sonrası mı?
manual refresh mı?
joined fallback mı?
route lifecycle mı?
session reset mi?
```

etiketle.

---

# 56. Son hedef

Cleanup tamamlandığında mutation tarafında standart:

```text
Action
↓
Supabase RPC
↓
_sync(response)
↓
MutationSyncService
↓
EntityPatchDispatcher
↓
Notifier
```

olmalı.

UI:

```text
state write yapmaz
```

---

# 57. Completion kriteri

Global frontend cleanup tamamlandı sayılır:

```text
✓ building_construction INSERT merkezi olarak işleniyor
✓ completion yalnız ilgili construction feature'ı temizliyor
✓ AR-GE construction broad invalidate yok
✓ Logistics construction broad invalidate yok
✓ upgrade manual double patch yok
✓ boost manual double patch yok
✓ Store response double MutationSync yok
✓ bulk price manual snapshot patch yok
✓ fill shelves manual snapshot patch yok
✓ mutation sonrası gereksiz broad invalidateler temiz
✓ targeted enriched fallback'ler korunuyor
✓ Parti 1–6 regression testleri temiz
```

---

# 58. Agent için önerilen uygulama sırası

```text
1. building_construction dispatcher insert
2. construction provider standardizasyonu
3. construction completion broad invalidate cleanup
4. AR-GE + Logistics action invalidate cleanup
5. Upgrade UI manual patch cleanup
6. Boost UI manual patch cleanup
7. Store applyMutation double-sync cleanup
8. bulk price manual patch cleanup
9. fill shelves manual patch cleanup
10. global invalidate/manual patch search
11. regression tests
12. son audit
```

---

# 59. Dikkat

Bu cleanup sırasında:

```text
joined/enriched getter refresh
route refresh
pull-to-refresh
session reset
dashboard aggregate refresh
```

gibi bilinçli invalidationları otomatik olarak silmeyin.

Ama mutation response aynı entity'nin final state'ini patch olarak getiriyorsa:

```text
patch + aynı provider refresh
```

ikilisi bırakılmamalıdır.
