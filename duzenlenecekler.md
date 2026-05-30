# Düzenlenecekler

Bu dosya, performans odaklı mimari düzenlemeleri sayfa sayfa takip etmek için tutulur.

## Genel performans kuralı

- Aksiyonlardan sonra provider invalidate ederek tüm ekran/veri setini yeniden çektirme yaklaşımı azaltılacak.
- Mutasyon yapan Supabase RPC fonksiyonları, işlem sonunda değişen güncel değerleri response içinde döndürecek.
- Flutter tarafında provider state'i response içindeki küçük patch/update verisiyle güncellenecek.
- `invalidate` sadece ilk yükleme, manuel refresh, oturum değişimi veya hata sonrası hard refresh için kullanılacak.
- Büyük ekran verileri tek devasa response olarak değil, ilgili ekranın ihtiyacı kadar ve mümkünse sadece değişen entity'ler olarak döndürülecek.

---

## 1. Splash Screen + Home Screen

İncelenen dosyalar:

- `lib/features/splash/ui/splash_screen.dart`
- `lib/features/home/ui/home_screen.dart`
- `lib/core/managers/auth_manager.dart`
- `lib/core/managers/asset_manager.dart`
- `lib/core/widgets/app_top_bar.dart`
- `lib/core/widgets/cached_asset_image.dart`
- `lib/features/auth/data/player_provider.dart`
- `lib/features/logistics/data/logistics_provider.dart`

### Tespitler

- Splash giriş akışı fazla parçalı: `signInAnonymouslyIfNeeded()` + `playerProvider` invalidate + `get_player_profile` + `complete_due_building_upgrades` + `complete_due_market_transfers` + `assetManager.prefetchAssets()`.
- `ensure_player_record_exists` session zaten varsa bile her girişte çalışıyor.
- Splash içinde player yeniden çekiliyor; bu bootstrap response ile doldurulmalı.
- Asset prefetch her girişte Supabase Storage `assets` bucket'ını listeliyor.
- Home screen açılışta büyük sorgu üretmiyor; ana veri olarak `playerProvider` izliyor.
- Nakliye butonu iki aşamalı sorgu yapıyor: `playerLogisticsCompanyProvider.future`, şirket yoksa `playerLogisticsConstructionProvider.future`.

### Önerilen yeni yapı

- Tek bootstrap RPC: `bootstrap_game_session()`.
- Bu RPC oyuncu kaydını garanti etmeli, gecikmiş bina yükseltmelerini ve market transferlerini tamamlamalı, güncel player bilgisini ve gerekirse home özetini döndürmeli.
- Asset prefetch için `assets_manifest_version` veya benzeri küçük versiyon kontrolü eklenmeli. Versiyon aynıysa storage list/download hiç çalışmamalı.
- Nakliye giriş kontrolü için tek RPC: `get_logistics_entry_state()`.
- Home finansal statları gerçek veriye bağlanacaksa tek endpoint kullanılmalı: `get_home_dashboard()`.

### Yapılacaklar

- [ ] `bootstrap_game_session()` Supabase RPC tasarlanacak.
- [ ] Splash screen bu tek RPC ile açılış state'ini alacak.
- [ ] `playerProvider` invalidate + `get_player_profile` zorunlu açılış akışından çıkarılacak.
- [ ] `ensure_player_record_exists` her girişte çağrılmayacak şekilde local flag/fallback mantığına alınacak.
- [ ] Asset prefetch için manifest/version kontrolü eklenecek.
- [ ] Nakliye giriş kontrolü için `get_logistics_entry_state()` fonksiyonu eklenecek.
- [ ] Home finansal statları gerçek veriye bağlanacaksa `get_home_dashboard()` ile tek endpoint kullanılacak.

---

## 2. Mağaza Listeleme Ekranı

İncelenen dosyalar:

- `lib/features/store/ui/store_screen.dart`
- `lib/features/store/data/store_provider.dart`
- `lib/core/navigation/route_refresh_mixin.dart`
- `lib/features/store/ui/city_selection_screen.dart`
- `lib/features/store/ui/store_type_selection_screen.dart`

### Tespitler

- `StoreScreen` açılışta `storesListProvider` izliyor.
- `storesListProvider` normal durumda 2 RPC çalıştırıyor: `get_stores_list` + `get_player_building_constructions`.
- İnşaat halinde mağaza varsa ek olarak `get_store_types_catalog` + `get_cities_catalog` çalışıyor. Yani liste ekranı 2-4 RPC arası çalışabiliyor.
- İnşaat halindeki mağaza kartları Flutter tarafında kataloglarla birleştiriliyor. Bu backend tarafında hazır kart verisi olarak dönmeli.
- `RouteRefreshMixin` yüzünden detaydan listeye dönünce `storesListProvider` her zaman invalidate ediliyor.
- Pull-to-refresh kalabilir; bu manuel hard refresh kabul edilebilir.
- İnşaatı altınla tamamlama sonrası liste komple invalidate ediliyor.
- Mağaza kurma sonrası `storesListProvider` ve `playerProvider` invalidate ediliyor.
- `citiesProvider` ve `storeTypesProvider` merkezi catalog cache'e taşınmalı.

### Önerilen yeni yapı

- Tek liste endpoint'i: `get_store_list_page_data()` veya mevcut `get_stores_list` genişletmesi.
- Response hem aktif/pasif mağazaları hem de inşaat halindeki mağaza kartlarını içermeli.
- Liste summary backend'den dönmeli: `total_count`, `active_count`, `total_capacity`.
- `storesListProvider` klasik `FutureProvider` yerine patch edilebilir `StoreListNotifier` yapısına alınmalı.
- Mağaza kurma response'u `player`, `store_construction_card`, `store_list_summary` dönmeli.
- Altınla inşaat bitirme response'u `player`, `completed_store`, `remove_construction_id`, `store_list_summary` dönmeli.
- `RouteRefreshMixin` varsayılan hard refresh yapmamalı; dirty flag veya route result mantığıyla sınırlandırılmalı.

### Yapılacaklar

- [ ] `get_store_list_page_data()` veya mevcut `get_stores_list` genişletmesi tasarlanacak.
- [ ] İnşaat halindeki mağaza kartları backend'de hazırlanıp liste response'una eklenecek.
- [ ] Liste summary backend'den dönülecek veya mevcut liste üzerinden tek yerde hesaplanacak.
- [ ] `storesListProvider` patch edilebilir notifier yapısına taşınacak.
- [ ] `RouteRefreshMixin` kaynaklı otomatik invalidate kaldırılacak veya dirty flag ile sınırlandırılacak.
- [ ] Mağaza kurma response'u `player`, `store_construction_card`, `store_list_summary` dönecek.
- [ ] Altınla inşaat bitirme response'u `player`, `completed_store`, `remove_construction_id`, `store_list_summary` dönecek.
- [ ] `citiesProvider` ve `storeTypesProvider` merkezi catalog cache'e taşınacak.
- [ ] Pull-to-refresh hard refresh olarak kalacak.

---

## 3. Mağaza Detay Ekranı

İncelenen dosyalar:

- `lib/features/store/ui/store_detail_screen.dart`
- `lib/features/store/data/store_provider.dart`

### Tespitler

- Detay ekranı açılışta `get_store_detail`, `get_player_active_building_boost`, `get_player_active_building_upgrade` şeklinde en az 3 ayrı RPC çalıştırabiliyor.
- Detay verisi geldikten sonra `_scheduleStoreSalesCheck()` içinde `process_store_sales_on_entry` ayrı RPC olarak çalışıyor.
- Satış işlenirse `storeDetailProvider`, `activeStoreBoostProvider`, `storesListProvider`, `storeHistoryProvider`, `storePerformanceProvider`, `playerProvider` invalidate ediliyor.
- Bu, detay ekranındaki en büyük performans problemidir: kullanıcı mağaza detayına girince önce veri çekiliyor, sonra satış işleniyor, sonra birçok veri tekrar çekiliyor.
- `activeStoreUpgradeProvider` listener içinde upgrade süresi geçmişse `completeDueBuildingUpgrades()` çağrılıyor; bu da build sırasında ekstra RPC doğurabilir.
- Slot açma sonrası `storeDetailProvider.future` okunuyor ve `storesListProvider` invalidate ediliyor.
- Boost ve upgrade aksiyonları genelde `activeStoreBoostProvider` / `activeStoreUpgradeProvider`, `storeDetailProvider`, `storesListProvider`, `playerProvider` invalidate ediyor.
- Slot aktif/pasif, ürün temizleme, fiyat değiştirme, ürün seçme gibi aksiyonlar tüm detay veya listeyi tekrar çektiriyor.
- Ürün seçimi her açılışta `get_available_products_for_store` RPC'si çalıştırıyor.
- Depodan mağazaya ve mağazadan depoya transfer akışları çok adımlı ve işlem sonrası tekrar okuma/invalidate üretiyor.

### Önerilen yeni yapı

- Tek açılış endpoint'i: `open_store_detail_page(p_store_id)`.
- Bu fonksiyon gerekirse satışları işlemeli, süresi biten boost/upgrade durumlarını tamamlamalı veya güncel durumlarını dönmeli, güncel mağaza detayını, aktif boost'u, aktif upgrade'i, görünür satış sonucunu, player patch'i ve store list item patch'i döndürmeli.

Örnek response:

```json
{
  "success": true,
  "store": {},
  "active_boost": null,
  "active_upgrade": null,
  "sale_result": null,
  "changed": {
    "player": {},
    "store_list_item": {},
    "history_dirty": false,
    "performance_dirty": false
  }
}
```

- `storeDetailProvider` klasik `FutureProvider.family` yerine patch edilebilir `StoreDetailNotifier` yapısına alınmalı.
- `activeStoreBoostProvider` ve `activeStoreUpgradeProvider` detay ekranında ayrı provider olarak izlenmemeli; detail state içinde tutulmalı.
- History/performance doğrudan invalidate edilmemeli; detail state içinde dirty flag tutulmalı.
- Tüm mağaza aksiyonları sadece değişen entity'leri döndürmeli.

### Patch response üretmesi gereken aksiyonlar

- `process_store_sales_on_entry`
- `add_store_slot`
- `start_building_boost`
- `start_building_upgrade`
- `finish_building_upgrade_with_gold`
- `set_store_slot_active`
- `clear_store_slot_product`
- `set_store_slot_price`
- `set_store_slot_product`
- `start_warehouse_to_store_transfer`
- `start_store_to_warehouse_transfer`

### Yapılacaklar

- [ ] `open_store_detail_page(p_store_id)` RPC tasarlanacak.
- [ ] `get_store_detail`, `process_store_sales_on_entry`, `get_player_active_building_boost`, `get_player_active_building_upgrade` açılışta tek response'a indirilecek.
- [ ] `process_store_sales_on_entry` response'u güncel `store`, `player`, `store_list_item`, `sale_result`, `history_dirty`, `performance_dirty` dönecek şekilde düzenlenecek veya açılış RPC içine taşınacak.
- [ ] `StoreDetailNotifier` patch edilebilir hale getirilecek.
- [ ] `activeStoreBoostProvider` ve `activeStoreUpgradeProvider` detail ekranında ayrı provider olarak izlenmeyecek.
- [ ] Satış sonrası provider invalidate zinciri kaldırılacak.
- [ ] Slot açma response'u yeni slot + store summary + store list item patch dönecek.
- [ ] Boost başlatma response'u active boost + player + store/list patch dönecek.
- [ ] Upgrade başlatma/bitirme response'u active upgrade veya completed store + player + store/list patch dönecek.
- [ ] Slot aktif/pasif, fiyat, ürün seçme, ürün temizleme aksiyonları sadece ilgili slotu ve summary'yi patch edecek.
- [ ] Depodan mağazaya ve mağazadan depoya transfer response'ları store slot, warehouse slot, player, transfer ve store list item patch dönecek.
- [ ] History/performance için dirty flag mantığı kurulacak.

---

## 4. Mağaza History ve Performance Ekranları

İncelenen dosyalar:

- `lib/features/store/ui/store_history_screen.dart`
- `lib/features/store/ui/store_performance_screen.dart`
- `lib/features/store/data/store_provider.dart`

### Tespitler

- History ekranı açılınca `storeHistoryProvider(storeId)` üzerinden tek RPC çalışıyor: `get_store_history_items`.
- Performance ekranı açılınca `storePerformanceProvider(storeId)` üzerinden tek RPC çalışıyor: `get_store_daily_performance`, `p_days: 14`.
- Bu iki ekran detay ekranında doğrudan yüklenmiyor; kullanıcı `History` veya `Report` aksiyonuna basınca ayrı route olarak açılıyor.
- Asıl sorun bu ekranların kendisinde değil, detay ekranındaki satış sonrası erken invalidate davranışında.
- Detayda satış işlenince kullanıcı bu ekranlara girmemiş olsa bile `storeHistoryProvider(store.id)` ve `storePerformanceProvider(store.id)` invalidate ediliyor.
- İki ekranda da `RouteRefreshMixin` var; `didPopNext()` tetiklenirse provider invalidate edilip tekrar okunuyor. Bu genel mimari kuralına aykırı.
- Pull-to-refresh kalmalı; bu bilinçli hard refresh kabul edilebilir.
- History ekranında filtreleme ve özet hesapları local list üzerinden yapılıyor. Veri büyürse pagination gerekir.
- Performance ekranı 14 günlük veriyle sınırlı olduğu için mevcut sorgu genişliği şimdilik makul.

### Önerilen yeni yapı

- Detay ekranında satış/transfer/slot değişiklikleri olduğunda history ve performance provider'ları doğrudan invalidate edilmemeli.
- Bunun yerine store detail state içinde dirty flag tutulmalı:

```json
{
  "history_dirty": true,
  "performance_dirty": true
}
```

- Kullanıcı history/performance ekranına girdiğinde dirty flag kontrol edilmeli. Dirty ise refresh yapılmalı, değilse cache kullanılmalı.
- `RouteRefreshMixin` burada kaldırılmalı veya dirty flag'e bağlanmalı.
- History uzun vadede pagination desteklemeli.

Önerilen notifier yapıları:

```text
StoreHistoryNotifier(storeId)
- loadIfNeeded()
- refresh()
- markDirty()
- prependItems(items)
```

```text
StorePerformanceNotifier(storeId)
- loadIfNeeded()
- refresh()
- markDirty()
```

History pagination önerisi:

```sql
get_store_history_items(p_store_id, p_limit, p_before)
```

veya:

```sql
get_store_history_items(p_store_id, p_limit, p_offset)
```

Örnek response:

```json
{
  "items": [],
  "next_cursor": null,
  "has_more": false
}
```

### Yapılacaklar

- [ ] Detay ekranındaki satış sonrası `storeHistoryProvider` ve `storePerformanceProvider` invalidate kaldırılacak.
- [ ] Store detail state içinde `history_dirty` ve `performance_dirty` tutulacak.
- [ ] History ekranı açılırken dirty flag kontrolü yapılacak.
- [ ] Performance ekranı açılırken dirty flag kontrolü yapılacak.
- [ ] History ve performance ekranlarında `RouteRefreshMixin` kaynaklı otomatik hard refresh kaldırılacak veya dirty flag'e bağlanacak.
- [ ] Pull-to-refresh manuel hard refresh olarak kalacak.
- [ ] History provider uzun vadede pagination destekleyecek şekilde planlanacak.
- [ ] Performance provider 14 günlük veriyle kalabilir; şimdilik tek RPC yeterli.

---

## Sıradaki inceleme

Bir sonraki sayfa/modül henüz işlenmedi.
