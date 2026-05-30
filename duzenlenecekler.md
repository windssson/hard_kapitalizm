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

#### Splash giriş akışı fazla parçalı

Mevcut akış:

1. `signInAnonymouslyIfNeeded()`
2. `playerProvider` invalidate
3. `playerProvider.future` ile `get_player_profile`
4. `complete_due_building_upgrades`
5. `complete_due_market_transfers`
6. `assetManager.prefetchAssets()`
7. `/home` yönlendirmesi

Bu yapı her girişte birden fazla RPC ve storage request oluşturuyor.

#### `ensure_player_record_exists` her girişte çalışıyor

`AuthManager.signInAnonymouslyIfNeeded()` içinde session zaten varsa bile `ensure_player_record_exists` çağrılıyor. Bu güvenli ama performans açısından her girişte gereksiz olabilir.

Öneri:

- İlk kurulum / ilk login sonrası çalışsın.
- Local flag ile oyuncu kaydı garanti edildiyse tekrar çalışmasın.
- `playerProvider` null dönerse fallback olarak tekrar çağrılsın.

#### Splash içinde player yeniden çekiliyor

Splash içinde `playerProvider` invalidate edilip hemen okunuyor. Home açıldığında `AppTopBar` ve company summary da aynı player verisini kullanıyor. Riverpod cache nedeniyle genelde ikinci kez DB'ye gitmez ama mimari olarak bootstrap response ile state doldurmak daha doğru.

#### Asset prefetch her girişte bucket list yapıyor

`assetManager.prefetchAssets()` her splash'te Supabase Storage `assets` bucket'ını listeliyor. Asset sayısı arttıkça giriş request yükü artar.

Öneri:

- `assets_manifest_version` veya benzeri küçük versiyon kontrolü eklensin.
- Versiyon aynıysa storage list/download hiç çalışmasın.
- Versiyon değiştiyse prefetch çalışsın.
- Mümkün olan sabit ana görseller uygulama içine gömülsün.

#### Home screen açılışta büyük sorgu üretmiyor

Home screen ana veri olarak sadece `playerProvider` izliyor. `AppTopBar` ve summary aynı provider cache'ini kullanıyor. Bu taraf şu an büyük sorun değil.

#### Nakliye butonu iki aşamalı sorgu yapıyor

Nakliye modülüne basınca:

1. `playerLogisticsCompanyProvider.future`
2. Şirket yoksa `playerLogisticsConstructionProvider.future`

Bu iki ayrı RPC'ye dönüşüyor.

Öneri:

- Tek RPC: `get_logistics_entry_state()`
- Response örneği:

```json
{
  "has_company": true,
  "has_construction": false,
  "target_route": "/logistics"
}
```

### Önerilen yeni Splash/Home mimarisi

#### Tek bootstrap RPC

Yeni fonksiyon önerisi:

```sql
bootstrap_game_session()
```

Bu fonksiyon şunları yapmalı:

- Oyuncu kaydı yoksa oluşturmalı.
- Gecikmiş bina yükseltmelerini tamamlamalı.
- Gecikmiş market transferlerini tamamlamalı.
- Güncel player bilgisini döndürmeli.
- Gerekirse home özet verisini döndürmeli.

Örnek response:

```json
{
  "success": true,
  "player": {},
  "completed_updates": {},
  "home_summary": {}
}
```

Mevcut yapı:

```text
ensure_player_record_exists
+ get_player_profile
+ complete_due_building_upgrades
+ complete_due_market_transfers
```

Yeni yapı:

```text
bootstrap_game_session
```

#### Home dashboard için ileride tek endpoint

Home ekranındaki finansal statlar ileride gerçek veriye bağlanacaksa ayrı ayrı provider açılmamalı.

Önerilen endpoint:

```sql
get_home_dashboard()
```

Dönebilecek veri:

```json
{
  "player": {},
  "company_summary": {},
  "financial_stats": {},
  "alerts": [],
  "module_status": {}
}
```

### Öncelik kararı

- Home screen şu an büyük sorgu problemi yaratmıyor.
- İlk düzenleme Splash/bootstrap ve Asset prefetch tarafında yapılmalı.
- Nakliye route kontrolü ikinci öncelik olarak tek RPC'ye indirilmeli.

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

#### Liste açılışı tek provider üzerinden çalışıyor ama provider içinde 2-4 RPC var

`StoreScreen` açılışta `storesListProvider` izliyor.

`storesListProvider` içinde ilk aşamada paralel olarak iki RPC çağrılıyor:

1. `get_stores_list`
2. `get_player_building_constructions` (`building_kind = store`, `status = in_progress`)

Eğer inşaat halinde mağaza varsa ek olarak iki katalog RPC'si daha çağrılıyor:

1. `get_store_types_catalog`
2. `get_cities_catalog`

Yani mağaza listeleme ekranı normal durumda 2 RPC, inşaat varsa 4 RPC çalıştırabiliyor.

#### İnşaat halindeki mağazalar Flutter tarafında kataloglarla birleştiriliyor

İnşaat kayıtları backend'den ham `params` olarak geliyor. Flutter sonra şehir ve mağaza tipi bilgilerini ayrıca kataloglardan çekip eşleştiriyor.

Bu iş backend tarafında tek liste fonksiyonuna taşınmalı. Liste ekranı için `get_stores_list` zaten varsa, inşaat halindeki mağazaları da aynı response içine hazır kart verisi olarak koymalı.

#### RouteRefreshMixin listeye dönüşte her zaman tekrar sorgu attırıyor

`StoreScreen` `RouteRefreshMixin` kullanıyor. `didPopNext()` tetiklenince `refreshRouteData()` çağrılıyor.

Mevcut `refreshRouteData()`:

```dart
ref.invalidate(storesListProvider);
ref.read(storesListProvider.future);
```

Bu, mağaza detayından veya mağaza kurulum adımlarından geri dönünce listeyi her zaman tekrar DB'den çeker.

Yeni mimaride bu hard refresh varsayılan olmamalı. Detay ekranındaki aksiyonlar veya mağaza kurma işlemi response ile liste state'ini patch etmeli.

#### Pull-to-refresh doğru kullanım alanı

Ekranda `RefreshIndicator` ile manuel refresh var. Bu kalabilir. Kullanıcının elle aşağı çekmesi bilinçli hard refresh kabul edilebilir.

#### İnşaatı altınla tamamlama sonrası liste komple invalidate ediliyor

`_handleQuickFinish` başarılı olunca `storesListProvider` invalidate ediliyor. Bu işlemde backend response yeni tamamlanmış mağazayı, güncel player değerlerini ve gerekirse construction kaydının kaldırıldığını döndürmeli. Flutter da liste state'ini patch etmeli.

#### Mağaza kurma akışında create sonrası iki provider invalidate ediliyor

`StoreTypeSelectionScreen._handleEstablish()` başarılı olunca:

- `storesListProvider` invalidate ediliyor.
- `playerProvider` invalidate ediliyor.
- Sonra `/store` ekranına gidiliyor.

Bu yapı mağaza kurduktan sonra listeye dönüşte yeni sorgu üretir. `start_building_construction` response içinde yeni construction-card verisi ve güncel player bilgisi dönmeli.

#### Şehir ve mağaza tipi katalogları tekrar kullanılabilir statik veriler

`CitySelectionScreen` `citiesProvider` izliyor. `StoreTypeSelectionScreen` ise `storeTypesProvider` ve `playerProvider` izliyor.

`citiesProvider` ve `storeTypesProvider` katalog verileri çoğunlukla statik. Bu veriler her modül tarafından ayrı ayrı çekilmemeli. Global catalog/cache katmanına alınmalı.

### Önerilen yeni mağaza listeleme mimarisi

#### Tek liste endpoint'i

Mevcut yapı:

```text
get_stores_list
+ get_player_building_constructions
+ gerekirse get_store_types_catalog
+ gerekirse get_cities_catalog
```

Yeni öneri:

```sql
get_store_list_page_data()
```

Bu fonksiyon şunları hazır dönmeli:

```json
{
  "success": true,
  "stores": [],
  "summary": {
    "total_count": 0,
    "active_count": 0,
    "total_capacity": 0
  }
}
```

`stores` listesi hem aktif/pasif mağazaları hem de inşaat halindeki mağaza kartlarını tek modelde içermeli.

#### Liste state'i patch edilebilir olmalı

`storesListProvider` klasik `FutureProvider` yerine patch edilebilir bir notifier yapısına alınmalı.

Öneri:

```text
StoreListNotifier
- load()
- refresh()
- addOrUpdateStore(store)
- removeConstruction(constructionId)
- patchStoreSummary(summary)
```

#### Mağaza kurma response'u listeyi güncellemeli

`start_building_construction` veya mağazaya özel wrapper RPC response'u şunları dönmeli:

```json
{
  "success": true,
  "message": "Mağaza inşaatı başladı.",
  "changed": {
    "player": {},
    "store_construction_card": {},
    "store_list_summary": {}
  }
}
```

Flutter:

- Yeni construction kartını listeye ekler.
- Player state'ini patch eder.
- Liste summary değerlerini patch eder.
- `storesListProvider` ve `playerProvider` invalidate etmez.

#### İnşaatı altınla tamamlama response'u listeyi güncellemeli

`finish_construction_with_gold` response'u şunları dönmeli:

```json
{
  "success": true,
  "changed": {
    "player": {},
    "completed_store": {},
    "remove_construction_id": "...",
    "store_list_summary": {}
  }
}
```

Flutter:

- Construction kartını kaldırır veya completed store ile değiştirir.
- Player state'ini patch eder.
- Listeyi komple yenilemez.

#### RouteRefreshMixin varsayılan hard refresh olmamalı

Liste ekranlarında `didPopNext()` sonrası otomatik invalidate kaldırılmalı veya kontrollü hale getirilmeli.

Öneri:

- Detay sayfası değişiklik yaptıysa route result / shared state ile listeye patch bildirsin.
- Hiç değişiklik yoksa listeye dönüşte sorgu atılmasın.
- Gerekirse `RouteRefreshMixin` içine `shouldRefreshOnPopNext` veya dirty flag mantığı eklenmeli.

#### Kataloglar merkezi cache'e alınmalı

Şehirler, mağaza tipleri ve benzeri catalog verileri için ortak bir catalog provider/notifier tasarlanmalı.

Öneri:

```text
CatalogProvider / CatalogCache
- cities
- store_types
- warehouse_types
- factory_types
- farm_types
- field_types
- mine_types
```

Bu kataloglar:

- Uygulama oturumunda bir kez yüklenmeli.
- Manuel debug refresh dışında tekrar çekilmemeli.
- Liste endpoint'leri kart için gerekli isim/icon gibi alanları zaten döndürmeli; katalog sadece seçim ekranlarında kullanılmalı.

### Öncelik kararı

- Mağaza listeleme ekranı tek başına en kötü sorgu kaynağı değil.
- Ancak `RouteRefreshMixin` ve create/finish sonrası invalidate yaklaşımı ileride sorguları katlar.
- İlk düzeltme `storesListProvider` ve route refresh davranışı olmalı.
- İkinci düzeltme inşaat halindeki mağazaların `get_store_list_page_data()` içinde hazır dönmesi olmalı.

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

## Sıradaki inceleme

Bir sonraki sayfa/modül henüz işlenmedi.
