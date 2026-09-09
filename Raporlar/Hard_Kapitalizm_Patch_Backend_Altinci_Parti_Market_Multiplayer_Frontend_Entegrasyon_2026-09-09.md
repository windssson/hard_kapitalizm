# Hard Kapitalizm — Patch Sistemi 6. Parti Frontend Entegrasyon Raporu

**Tarih:** 2026-09-09  
**Kapsam:** Market / Multiplayer Patch Entegrasyonu  
**Backend durumu:** Canlı Supabase üzerinde tamamlandı.  
**Bu parti:** Patch dönüşümünün son frontend aşamasıdır.

---

# 1. Amaç

6. partinin amacı market satın alma ve market transfer tamamlama akışlarını broad refresh/invalidate yapısından çıkarıp patch tabanlı local state senkronizasyonuna geçirmek.

Ana RPC'ler:

```text
start_multi_market_transfer
complete_due_market_transfers
```

Bu partinin en önemli farkı:

> Aynı mutation iki farklı oyuncunun state'ini değiştirebilir.

Bu nedenle buyer frontend response'unda seller'ın private state'i yer almaz.

---

# 2. Backend güvenlik kontratı

Buyer response'una gelebilecek state:

```text
changed.player

warehouse
warehouse_slot
logistics_transfer
logistics_transfer_item
logistics_vehicle

market_listing
```

Seller private state response'a girmez:

```text
seller.cash
seller warehouse private fields
seller cost basis
seller production state
seller private finance state
```

Seller kendi oturumunda mevcut notification / refresh / ilgili mekanizma ile state'ini görür.

---

# 3. Yeni entity

6. partide frontend dispatcher'a yalnız bir yeni entity eklenmesi gerekiyor:

```text
market_listing
```

Önceki entity'ler zaten desteklenmektedir:

```text
warehouse
warehouse_slot
logistics_transfer
logistics_transfer_item
logistics_vehicle
player
```

---

# 4. `market_listing` patch contract

Market'te başka oyuncunun warehouse slot'u bir public listing olarak temsil edilir.

## Partial purchase

Örnek:

```json
{
  "entity": "market_listing",
  "operation": "update",
  "id": "seller-slot-uuid",
  "changes": {
    "quantity": 400
  }
}
```

Frontend:

```text
listing quantity -> 400
```

yapmalıdır.

## Listing tamamen bittiyse

```json
{
  "entity": "market_listing",
  "operation": "delete",
  "id": "seller-slot-uuid",
  "changes": {}
}
```

Frontend:

```text
listing'i local market listesinden kaldır
```

yapmalıdır.

---

# 5. EntityPatchDispatcher

Yeni case:

```dart
case 'market_listing':
  _applyMarketListingPatch(patch);
  break;
```

Önerilen handler:

```dart
void _applyMarketListingPatch(EntityPatch patch) {
  final notifier = _ref.read(marketListingsPatchRegistryProvider);

  switch (patch.operation) {
    case PatchOperation.update:
      notifier.patchListing(
        patch.id,
        patch.changes,
      );
      break;

    case PatchOperation.delete:
      notifier.removeListing(patch.id);
      break;

    case PatchOperation.insert:
      notifier.handleInsertOrRefresh(patch);
      break;
  }
}
```

Not:

Bu backend akışında esas beklenen operasyonlar:

```text
update
delete
```

Insert olağan senaryo değildir.

---

# 6. Market provider yapısı

Mevcut market provider'ları family tabanlıdır:

```text
marketListingsProvider(productId)
marketCityListingsProvider(cityId)
playerMarketListingsProvider(playerId)
```

Bu nedenle tek bir listing patch'i birden fazla aktif listeyi etkileyebilir.

Örnek:

Bir listing:

```text
product = DOMATES
city = Van
seller = player-X
slot_id = abc
```

ise aynı anda:

```text
marketListingsProvider('DOMATES')
marketCityListingsProvider('Van')
playerMarketListingsProvider('player-X')
```

cache'lerinde bulunabilir.

---

# 7. Önerilen MarketListingPatchRegistry

Aktif family provider'ları doğrudan dispatcher içinde brute-force taramayın.

Bunun yerine market feature içinde merkezi registry tutmak daha güvenli.

Örnek:

```dart
class MarketListingPatchRegistry {
  final Ref ref;

  final Set<String> activeProductIds = {};
  final Set<String> activeCityIds = {};
  final Set<String> activeSellerIds = {};

  void patchListing(
    String slotId,
    Map<String, dynamic> changes,
  ) {
    // Aktif product listing provider'larında ara
    // Aktif city listing provider'larında ara
    // Aktif seller listing provider'larında ara
  }

  void removeListing(String slotId) {
    // Tüm aktif market cache'lerinden sil
  }
}
```

Provider build/dispose sırasında registry'ye register/unregister yapılabilir.

Bu, store/detail active ID yaklaşımıyla aynı mantıktadır.

---

# 8. Alternatif daha basit çözüm

Market provider'lar şu anda `FutureProvider.family` ise patch uygulamak zor olabilir.

Bu durumda iki seçenek var.

## Tercih edilen

Market listelerini patch edilebilir `AsyncNotifier.family` yapısına geçirmek.

Örnek:

```dart
class MarketListingsNotifier
    extends FamilyAsyncNotifier<List<MarketListingModel>, String> {

  void patchListing(
    String slotId,
    Map<String, dynamic> changes,
  ) {
    final current = state.value;
    if (current == null) return;

    state = AsyncData(
      current.map((item) {
        if (item.slotId != slotId) return item;

        return item.copyWith(
          quantity: (changes['quantity'] as num?)?.toInt()
              ?? item.quantity,
        );
      }).toList(),
    );
  }

  void removeListing(String slotId) {
    final current = state.value;
    if (current == null) return;

    state = AsyncData(
      current.where((e) => e.slotId != slotId).toList(),
    );
  }
}
```

## Geçici fallback

Provider dönüşümü çok riskliyse:

```text
market_listing update/delete
    ->
yalnız ilgili market provider targeted invalidate
```

kullanılabilir.

Ancak broad:

```text
warehouse
player
transfer map
dashboard
market
```

invalidate zinciri kullanılmamalıdır.

---

# 9. `MarketListingModel.copyWith`

Modelde `copyWith` yoksa ekleyin.

En az:

```dart
MarketListingModel copyWith({
  int? quantity,
  double? price,
  bool? isAvailableForSale,
})
```

gerekir.

Daha generic patch istiyorsanız:

```dart
MarketListingModel applyChanges(
  Map<String, dynamic> changes,
)
```

eklenebilir.

Öneri:

```dart
MarketListingModel applyChanges(Map<String, dynamic> changes) {
  return copyWith(
    quantity: changes.containsKey('quantity')
        ? (changes['quantity'] as num?)?.toInt() ?? 0
        : quantity,
    price: changes.containsKey('price')
        ? (changes['price'] as num?)?.toDouble() ?? 0
        : price,
    isAvailableForSale: changes.containsKey('is_available_for_sale')
        ? changes['is_available_for_sale'] as bool? ?? false
        : isAvailableForSale,
  );
}
```

---

# 10. ID eşlemesi

Backend:

```text
market_listing.id = seller warehouse slot id
```

Frontend model:

```text
slotId
listingId
```

alanlarına sahiptir.

Patch eşlemesi yapılırken öncelik:

```text
item.slotId == patch.id
```

olmalıdır.

Gerekirse fallback:

```text
item.listingId == patch.id
```

kullanılabilir.

---

# 11. `start_multi_market_transfer`

Mevcut frontend akışı kabaca:

```dart
final response = await supabase.rpc(
  'start_multi_market_transfer',
  ...
);
```

Mutation sonrası:

```dart
mutationSyncService.applyRaw(result);
```

zorunludur.

### Eski davranış

Kodda şu tarz opsiyonel invalidate mevcut olabilir:

```dart
if (syncProviders) {
  ref.invalidate(warehouseListProvider);
  ref.invalidate(warehouseDetailProvider(buyerWarehouseId));
}
```

6. parti tamamlandıktan sonra bunlar kaldırılmalıdır.

Çünkü backend response artık buyer tarafında:

```text
changed.player
warehouse
warehouse_slot
logistics_transfer
logistics_transfer_item
logistics_vehicle
market_listing
```

döndürmektedir.

---

# 12. Aynı şehir market purchase

Aynı şehirde:

```text
mode = instant
```

olabilir.

Backend aynı RPC içinde transferi tamamlayabilir.

Bu durumda response'ta tek mutation içerisinde:

```text
player cash düşer
market_listing quantity azalır/delete
warehouse reserved_capacity değişir
warehouse_slot insert/update
logistics_transfer completed
logistics_transfer_item completed
```

gibi final state patch'leri gelebilir.

Frontend kendi başına:

```text
in_transit
```

optimistic state üretmemelidir.

**Backend final patch authoritative kaynaktır.**

---

# 13. Şehirler arası market purchase

Şehirler arası alışverişte:

```text
mode = in_transit
```

olur.

Beklenen patch'ler:

```text
player.cash ↓
market_listing update/delete
warehouse.reserved_capacity ↑
logistics_transfer insert
logistics_transfer_item insert
logistics_vehicle update
```

Ürün henüz warehouse slot'a girmez.

Ürün transfer tamamlandığında:

```text
warehouse_slot insert/update
warehouse.reserved_capacity ↓
logistics_transfer completed
logistics_transfer_item completed
vehicle idle
```

patch'i gelir.

---

# 14. `complete_due_market_transfers`

Bu RPC artık patch-aware.

Önceden internal completion çağırdığı için frontend full refresh gerekebilirdi.

Artık response içinde tamamlanan transferlere ait:

```text
warehouse
warehouse_slot
logistics_transfer
logistics_transfer_item
logistics_vehicle
player
```

patch'leri merge edilerek döner.

Frontend:

```dart
final result = await supabase.rpc(
  'complete_due_market_transfers',
);

ref.read(mutationSyncServiceProvider).applyRaw(
  Map<String, dynamic>.from(result as Map),
);
```

şeklinde işlemelidir.

---

# 15. `complete_due_market_transfers` sonrası invalidate kaldırma

Şu tarz eski pattern'ler aranmalı:

```dart
ref.invalidate(warehouseListProvider);
ref.invalidate(warehouseDetailProvider(...));
ref.invalidate(buyerTransferMapProvider);
ref.invalidate(buyerTransferHistoryProvider);
```

Patch coverage tam olanlar kaldırılmalıdır.

Ancak 3. partide olduğu gibi **enriched transfer map/history modelleri** raw DB patch'ten üretilemiyorsa targeted refresh fallback korunabilir.

Önceki kural devam eder:

```text
raw entity model yeterliyse -> local patch
joined/enriched model gerekiyorsa -> targeted refresh
```

---

# 16. Transfer map davranışı

`logistics_transfer` insert için önceki 3. parti kuralı korunmalıdır:

Raw transfer row:

```text
seller city name
buyer city name
coords
product metadata
warehouse names
```

gibi enriched alanları içermiyorsa:

```text
buyerTransferMapProvider.notifier.refresh()
```

targeted refresh kullanılabilir.

Bu market transferlerinde de geçerlidir.

Market patch entegrasyonu yapılırken 3. parti transfer map çözümünü bozmayın.

---

# 17. Transfer history davranışı

Completed market transfer:

```text
buyer transfer history
```

provider'ında gösteriliyorsa:

- history loaded ise targeted refresh
- loaded değilse gereksiz fetch yapma

3. partideki mevcut davranışı koruyun.

---

# 18. Seller privacy

Frontend kodunda buyer tarafında seller'a ait şu alanları beklemeyin:

```text
seller cash
seller cost basis
seller internal warehouse quantity object
seller private finance state
```

Backend yalnız public listing delta döndürür.

---

# 19. Market `cost` alanı güvenlik değişikliği

Backend güvenlik hardening kapsamında başka oyuncunun ilanında:

```text
cost = price
```

döndürülmektedir.

Oyuncu kendi market ilanlarını çekerken:

```text
cost = gerçek own cost
```

görebilir.

Frontend bunun üzerine iş mantığı kurmamalıdır.

Özellikle başka oyuncunun:

```text
profit margin
production cost
purchase cost
```

hesaplamasını `slot.cost` ile yapmayın.

---

# 20. `market_listing` update sonrası sepet

Market ekranında kullanıcı sepete listing eklemiş olabilir.

Başka bir purchase response'u local listing quantity'yi düşürdüğünde cart state de kontrol edilmelidir.

Örnek:

```text
listing quantity = 100
cart quantity = 80

patch:
quantity = 50
```

Bu durumda cart 80 olarak bırakılamaz.

Öneri:

```text
cartQuantity = min(cartQuantity, listing.quantity)
```

Listing delete geldiyse:

```text
cart'tan ilgili item kaldır
```

ve kullanıcıya kısa bir bilgi gösterilebilir:

```text
"Sepetteki bir ilan artık mevcut değil."
```

---

# 21. Market UI active cache

Market ekranında şu cache'ler aktif olabilir:

```text
product listings
city listings
seller listings
cart
selected listing
```

`market_listing delete` geldiğinde:

```text
product list -> remove
city list -> remove
seller list -> remove
cart -> remove/clamp
selected listing -> null
```

olmalıdır.

---

# 22. NPC market

`source_kind = npc_market` için seller warehouse slot yoktur.

Bu nedenle normal oyuncu listing patch'i beklenmez.

Frontend:

```text
market_listing patch gelmediyse
NPC listing'i local azaltma
```

yapmamalıdır.

NPC stock server-side sanal/stabil olabilir.

Backend authoritative response kullanılmalıdır.

---

# 23. Rental vehicle

Market purchase sırasında kiralık araç seçilmiş olabilir.

Buyer response'unda seller/rental vehicle owner private state'i patchlenmemelidir.

Frontend yalnız:

```text
logistics_transfer
player cash
buyer warehouse
market listing
```

gibi kendi state'ine güvenmelidir.

Eğer selected rental vehicle için local availability ekranı güncellenecekse targeted vehicle options refresh kabul edilebilir.

---

# 24. Mutation ordering

Tek market response'unda:

```text
market_listing delete
warehouse update
warehouse_slot insert
logistics_transfer insert/update
logistics_transfer_item insert/update
logistics_vehicle update
```

gelebilir.

Dispatcher patch'leri sırayla uygulasın.

Handler'lar ordering'e bağımlı olmamalıdır.

---

# 25. Market invalidate temizliği

Kod tabanında şu kelimeleri ara:

```text
start_multi_market_transfer
complete_due_market_transfers

invalidate(
refresh(
reload
syncProviders
```

Özellikle:

```text
market_provider.dart
market_screen.dart
transfer_map
warehouse
```

çevresini kontrol et.

---

# 26. Kaldırılabilecek invalidation örneği

Eski:

```dart
if (syncProviders) {
  ref.invalidate(warehouseListProvider);
  ref.invalidate(
    warehouseDetailProvider(buyerWarehouseId),
  );
}

return _sync(response);
```

Yeni:

```dart
return _sync(response);
```

Ancak bunu yalnız `warehouse` ve `warehouse_slot` patch handler'larının ilgili local provider'ı gerçekten güncellediği doğrulandıktan sonra kaldır.

---

# 27. Targeted fallback bırakılabilecek yerler

Şunlar normaldir:

```text
transfer map enriched refresh
transfer history enriched refresh
vehicle option sheet refresh
market listing provider family yapısı patch edilemiyorsa ilgili tek family invalidate
```

Şunlar normal değildir:

```text
global dashboard invalidate
global warehouse invalidate
global logistics invalidate
full app refresh
```

---

# 28. Market listing provider dönüşümü önerisi

Eğer bu son partiyle birlikte cleanup yapmak istiyorsanız:

Mevcut:

```dart
FutureProvider.family<List<MarketListingModel>, String>
```

yerine:

```dart
AsyncNotifierProvider.family<
  MarketListingsNotifier,
  List<MarketListingModel>,
  String
>
```

kullanmak uzun vadede daha iyi olur.

Aynı öneri:

```text
marketCityListingsProvider
playerMarketListingsProvider
```

için de geçerli.

Ancak bu dönüşüm şart değildir.

---

# 29. Manual test checklist

## Player-to-player same city

- [ ] Başka oyuncunun listing'ini aç
- [ ] Partial miktar satın al
- [ ] buyer cash anında azalıyor
- [ ] seller listing quantity local azalıyor
- [ ] market full refetch yok
- [ ] ürün buyer warehouse slot'a anında giriyor
- [ ] reserved capacity final state doğru
- [ ] transfer completed görünüyor
- [ ] seller private cash response'ta yok

## Player-to-player intercity

- [ ] Listing satın al
- [ ] buyer cash azalıyor
- [ ] market listing quantity azalıyor/delete
- [ ] buyer warehouse reserved capacity artıyor
- [ ] vehicle on_route
- [ ] transfer map targeted refresh ile doğru görünüyor
- [ ] ürün henüz warehouse slot'a girmiyor
- [ ] süre dolunca `complete_due_market_transfers`
- [ ] warehouse slot insert/update
- [ ] reserved capacity düşüyor
- [ ] vehicle idle
- [ ] transfer completed
- [ ] history doğru

## Full listing purchase

- [ ] Satıcı slotunun tamamını al
- [ ] `market_listing delete`
- [ ] listing product list'ten kalkıyor
- [ ] city list'ten kalkıyor
- [ ] seller list'ten kalkıyor
- [ ] cart item kalkıyor
- [ ] selected item temizleniyor

## Cart clamp

- [ ] Cart'ta 80 adet ürün tut
- [ ] Listing quantity patch ile 50'ye düşür
- [ ] cart quantity <= 50 oluyor

## NPC market

- [ ] NPC item purchase çalışıyor
- [ ] yanlış `market_listing delete/update` beklenmiyor
- [ ] buyer cash doğru azalıyor
- [ ] transfer doğru

## Rental vehicle

- [ ] Rental vehicle ile purchase
- [ ] buyer cash rental dahil doğru azalıyor
- [ ] transfer oluşuyor
- [ ] başka oyuncunun private vehicle state'i buyer provider'a patchlenmiyor

---

# 30. Privacy checklist

- [ ] Buyer response'ta seller cash yok
- [ ] Buyer response'ta seller gerçek cost yok
- [ ] Buyer response'ta seller private warehouse state yok
- [ ] Market listing yalnız public alanları değiştiriyor
- [ ] Own listing ekranında own cost görülebiliyor
- [ ] Other-player listing ekranında cost üzerinden margin hesaplanmıyor

---

# 31. Regression checklist

- [ ] Phase 1 store/warehouse patches çalışıyor
- [ ] Phase 2 production config bozulmadı
- [ ] Phase 3 transfer map targeted refresh çalışıyor
- [ ] Phase 3 transfer history sync çalışıyor
- [ ] Phase 4 upgrade/boost çalışıyor
- [ ] Phase 5 finance/tender çalışıyor
- [ ] unknown entity loglanıyor
- [ ] null semantics korunuyor
- [ ] patch apply failure fallback'i var

---

# 32. 6. parti tamamlanma kriteri

Frontend entegrasyonu şu koşullarda tamamlanmış sayılır:

```text
✓ market_listing entity dispatcher'da var
✓ market listing quantity local update oluyor
✓ market listing delete local remove oluyor
✓ active market cache'leri senkron kalıyor
✓ cart clamp/remove çalışıyor
✓ start_multi_market_transfer broad invalidate kullanmıyor
✓ complete_due_market_transfers patch response'u uygulanıyor
✓ same-city final state doğru
✓ intercity completion doğru
✓ transfer map/history targeted fallback korunuyor
✓ seller private state buyer'a taşınmıyor
✓ NPC market bozulmuyor
✓ rental vehicle akışı bozulmuyor
```

---

# 33. Patch sistemi final mimarisi

Tüm sistemin final mutation zinciri:

```text
User Action
   ↓
Supabase RPC
   ↓
DB Transaction
   ↓
Before / After Scoped Diff
   ↓
changed.player
changed.patches[]
   ↓
MutationSyncService
   ↓
EntityPatchDispatcher
   ↓
Feature Notifier
   ↓
UI local state
```

Fallback:

```text
1. Local patch
2. Targeted enriched refresh
3. Feature-specific invalidate
4. Global refresh — yalnız son çare
```

---

# 34. Sonuç

6. parti frontend entegrasyonu tamamlandığında Hard Kapitalizm'deki ana gameplay mutation'larının patch dönüşümü tamamlanmış olacaktır.

Final hedef:

```text
Mutation
≠
Provider'ı komple invalidate et
```

yerine:

```text
Mutation
=
Backend'in döndürdüğü kesin diff'i uygula
```

olmalıdır.

Market / multiplayer tarafında ek kural:

> Buyer yalnız kendi private state'ini ve public market delta'sını alır. Seller'ın private state'i başka oyuncuya asla patch edilmez.
