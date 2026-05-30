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
- `lib/features/store/ui/store_history_screen.dart` (detaydan açılan alt ekran olarak daha sonra ayrıca derin incelenecek)
- `lib/features/store/ui/store_performance_screen.dart` (detaydan açılan alt ekran olarak daha sonra ayrıca derin incelenecek)

### Tespitler

#### Detay ekranı açılışında parçalı veri çekiliyor

`StoreDetailScreen` ana veri olarak `storeDetailProvider(storeId)` izliyor. Bu provider `get_store_detail` RPC'sini çağırıyor.

Ekran içeriği oluşturulurken ayrıca:

- `activeStoreBoostProvider(store.id)` → `get_player_active_building_boost`
- `activeStoreUpgradeProvider(store.id)` → `get_player_active_building_upgrade`

çalışıyor.

Yani detay ekranı ilk açılışta satış işleminden önce bile en az 3 ayrı RPC çalıştırabiliyor:

```text
get_store_detail
get_player_active_building_boost
get_player_active_building_upgrade
```

Bu üç veri tek detay endpoint'inde dönmeli.

#### Satış kontrolü detay verisi geldikten sonra ayrı RPC olarak çalışıyor

`_scheduleStoreSalesCheck()` içinde `processStoreSalesOnEntry(store.id)` çağrılıyor. Bu da `process_store_sales_on_entry` RPC'sine gidiyor.

Satış işlenirse şu invalidate zinciri çalışıyor:

- `storeDetailProvider(store.id)`
- `activeStoreBoostProvider(store.id)`
- `storesListProvider`
- `storeHistoryProvider(store.id)`
- `storePerformanceProvider(store.id)`
- `playerProvider`

Bu detay ekranındaki en büyük performans problemi. Kullanıcı mağaza detayına girince önce detay çekiliyor, sonra satış işleniyor, sonra detay ve ilgili provider'lar tekrar çekiliyor.

#### Satış işleme ve detay verisi aynı açılış endpoint'inde birleşmeli

Mağaza detay sayfası açılırken ideal akış tek RPC olmalı:

```sql
open_store_detail_page(p_store_id)
```

Bu fonksiyon:

- Gerekliyse satışları işler.
- Süresi biten boost/upgrade durumlarını tamamlar veya döndürür.
- Güncel mağaza detayını döndürür.
- Aktif boost bilgisini döndürür.
- Aktif upgrade bilgisini döndürür.
- Satış sonucu görünürse dialog için `sale_result` döndürür.
- Güncel player patch döndürür.
- Liste kartı için store summary patch döndürür.

Response örneği:

```json
{
  "success": true,
  "store": {},
  "active_boost": null,
  "active_upgrade": null,
  "sale_result": {},
  "changed": {
    "player": {},
    "store_list_item": {},
    "history_dirty": true,
    "performance_dirty": true
  }
}
```

Böylece açılışta şu yapıdan kaçılır:

```text
get_store_detail
+ process_store_sales_on_entry
+ get_store_detail tekrar
+ get_player_active_building_boost tekrar
+ get_store_history_items invalidate
+ get_store_daily_performance invalidate
+ get_player_profile invalidate
```

#### `activeStoreUpgradeProvider` listener içinde süresi dolduysa RPC çağrılıyor

`ref.listen(activeStoreUpgradeProvider(storeId))` içinde upgrade varsa ve `finishAt` geçmişse `completeDueBuildingUpgrades()` çağrılıyor.

Bu ekran build sırasında ekstra tamamlatma RPC'si doğurabilir. Tamamlanması gereken upgrade/boost işleri detail open RPC içinde yapılmalı veya bootstrap/background completion içinde tek noktada yönetilmeli.

#### Slot açma sonrası gereksiz tekrar okuma var

`_handleOpenSlot()` başarılı olunca önce `ref.read(storeDetailProvider(store.id).future)` çağrılıyor, sonra `storesListProvider` invalidate ediliyor.

Bu yaklaşım yanlış: `add_store_slot` response'u yeni slotu, güncel store summary'yi ve liste kartı patch'ini dönmeli.

#### Boost ve upgrade aksiyonları çoklu invalidate yapıyor

`startStoreBoost`, `startStoreUpgrade`, `finishStoreUpgradeWithGold` başarılı olunca genelde şunlar invalidate ediliyor:

- `activeStoreBoostProvider` veya `activeStoreUpgradeProvider`
- `storeDetailProvider`
- `storesListProvider`
- `playerProvider`

Bunlar patch response ile güncellenmeli.

#### Slot aksiyonlarında tüm detay tekrar çekiliyor

Aşağıdaki aksiyonlar başarılı olunca detay veya liste invalidate ediliyor:

- Slot aktif/pasif değiştirme: `set_store_slot_active`
- Slot ürününü temizleme: `clear_store_slot_product`
- Slot fiyatı değiştirme: `set_store_slot_price`
- Slot ürünü seçme: `set_store_slot_product`

Bu aksiyonlar sadece ilgili slotu ve store/list summary değerlerini etkiler. Tüm mağaza detayını yeniden çekmek gereksiz.

#### Ürün seçimi her açılışta RPC ile ürünleri getiriyor

`_showProductSelectionDialog()` her açıldığında `get_available_products_for_store` çağırıyor. Ürün kataloğu ve mağaza uygunlukları sık değişmiyorsa bu response kısa süreli cache'lenebilir veya detay açılışında uygun ürün listesi opsiyonel olarak getirilebilir.

Öneri:

- Store tipine göre uygun ürün katalogları merkezi cache'e alınsın.
- Slot ürün seçimi açıldığında sadece gerçekten gerekiyorsa RPC çalışsın.
- Ürün seçimi sonrası sadece ilgili slot patch edilsin.

#### Depodan mağazaya stok aktarım akışı çok adımlı ve sorgu üretmeye yatkın

Depodan mağazaya stok ekleme akışında:

1. `get_player_active_warehouses_with_slots`
2. Şehirler arası ise `get_transfer_vehicle_options`
3. Gerekirse `set_store_slot_product`
4. `start_warehouse_to_store_transfer`
5. Başarılı olursa `storeDetailProvider.future`
6. `storesListProvider` invalidate
7. `playerProvider` invalidate

Aynı şehir transferinde araç seçimi atlanıyor ama yine de transfer sonrası detay/liste/player yeniden çekiliyor.

Bu akış için transfer RPC'si değişen store slot, warehouse slot, player, active transfer ve store list item patch dönmeli.

#### Mağazadan depoya stok gönderme akışı da çok adımlı

Mağazadan depoya gönderimde:

1. `get_player_active_warehouses_basic`
2. Şehirler arası ise `get_transfer_vehicle_options`
3. `start_store_to_warehouse_transfer`
4. Başarılı olursa `storeDetailProvider.future`
5. `storesListProvider` invalidate
6. `playerProvider` invalidate

Bu da patch response ile çözülmeli. Same-city transfer tamamlandıysa store slot ve warehouse slot anlık patch edilmeli; şehirler arası transfer başladıysa store slot pending/reserved alanı ve transfer kaydı patch edilmeli.

#### History ve performance provider'ları detay ekranında doğrudan yüklenmiyor ama satış sonrası invalidate ediliyor

Detay ekranı içinde `history` ve `performance` ayrı ekranlara `context.push` ile gidiyor. Fakat satış işlenince `storeHistoryProvider` ve `storePerformanceProvider` invalidate ediliyor.

Bu provider'lar o anda izlenmiyorsa invalidate cache'i kirletmekten başka işe yaramaz. Yeni mimaride `history_dirty` ve `performance_dirty` flag tutulmalı. Kullanıcı history/performance ekranına girdiğinde gerekiyorsa refresh yapılmalı.

### Önerilen yeni mağaza detay mimarisi

#### Tek açılış endpoint'i

```sql
open_store_detail_page(p_store_id)
```

Bu fonksiyon şunları döndürmeli:

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

#### Patch edilebilir detail notifier

`storeDetailProvider` klasik `FutureProvider.family` yerine patch edilebilir bir notifier yapısına alınmalı.

Öneri:

```text
StoreDetailNotifier(storeId)
- open()
- refresh()
- applySaleResult(result)
- patchStore(store)
- patchSlot(slot)
- patchSummary(summary)
- patchActiveBoost(boost)
- patchActiveUpgrade(upgrade)
- markHistoryDirty()
- markPerformanceDirty()
```

#### Aksiyon response standartları

Her mağaza detay aksiyonu değişen veriyi dönmeli:

```json
{
  "success": true,
  "message": "İşlem başarılı.",
  "changed": {
    "store": {},
    "store_slot": {},
    "store_summary": {},
    "store_list_item": {},
    "player": {},
    "active_boost": null,
    "active_upgrade": null,
    "warehouse_slot": {},
    "transfer": {},
    "history_dirty": true,
    "performance_dirty": true
  }
}
```

Her aksiyon tüm alanları döndürmek zorunda değil. Sadece değişen entity'leri döndürmeli.

#### Invalidate yerine patch uygulanacak aksiyonlar

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

#### Transfer akışları için endpoint iyileştirmesi

Uzun vadede transfer başlatma endpoint'leri hem işlemi yapmalı hem de UI patch döndürmeli:

- `store_slot`
- `warehouse_slot`
- `player`
- `transfer`
- `store_list_item`

Ayrıca aynı şehir transferinde anlık tamamlanan sonuç ile şehirler arası transferde başlayan lojistik kaydı aynı response formatında ayrışmalı:

```json
{
  "mode": "instant" | "logistics",
  "changed": {}
}
```

#### History/performance lazy refresh

Satış işlenince history/performance provider'ları doğrudan invalidate edilmemeli.

Yerine detail state içinde:

```json
{
  "history_dirty": true,
  "performance_dirty": true
}
```

tutulmalı. Kullanıcı ilgili ekrana girerse ve dirty ise refresh yapılmalı.

### Öncelik kararı

- Mağaza detay ekranı şu ana kadar incelenen mağaza sayfaları içinde en büyük sorgu şişirme kaynağıdır.
- İlk düzeltme `open_store_detail_page()` ile açılış akışının tek RPC'ye indirilmesi olmalı.
- İkinci düzeltme satış sonrası invalidate zincirinin kaldırılması olmalı.
- Üçüncü düzeltme slot/boost/upgrade/transfer aksiyonlarının patch response üretmesi olmalı.

### Yapılacaklar

- [ ] `open_store_detail_page(p_store_id)` RPC tasarlanacak.
- [ ] `get_store_detail`, `process_store_sales_on_entry`, `get_player_active_building_boost`, `get_player_active_building_upgrade` açılışta tek response'a indirilecek.
- [ ] `process_store_sales_on_entry` response'u güncel `store`, `player`, `store_list_item`, `sale_result`, `history_dirty`, `performance_dirty` dönecek şekilde düzenlenecek veya açılış RPC içine taşınacak.
- [ ] `StoreDetailNotifier` patch edilebilir hale getirilecek.
- [ ] `activeStoreBoostProvider` ve `activeStoreUpgradeProvider` detail ekranında ayrı provider olarak izlenmeyecek; detail state içinde tutulacak.
- [ ] Satış sonrası `storeDetailProvider`, `storesListProvider`, `storeHistoryProvider`, `storePerformanceProvider`, `playerProvider` invalidate zinciri kaldırılacak.
- [ ] Slot açma response'u yeni slot + store summary + store list item patch dönecek.
- [ ] Boost başlatma response'u active boost + player + store/list patch dönecek.
- [ ] Upgrade başlatma/bitirme response'u active upgrade veya completed store + player + store/list patch dönecek.
- [ ] Slot aktif/pasif, fiyat, ürün seçme, ürün temizleme aksiyonları sadece ilgili slotu ve summary'yi patch edecek.
- [ ] Depodan mağazaya ve mağazadan depoya transfer response'ları store slot, warehouse slot, player, transfer ve store list item patch dönecek.
- [ ] History/performance için dirty flag mantığı kurulacak.

---

## Sıradaki inceleme

Bir sonraki sayfa/modül henüz işlenmedi.
