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

## Sıradaki inceleme

Bir sonraki sayfa/modül henüz işlenmedi.
