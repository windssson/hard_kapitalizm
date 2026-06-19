# Hard Kapitalizm

Hard Kapitalizm, Flutter ve Supabase ile geliştirilen mobil odaklı bir tycoon / ekonomi simülasyonu oyunudur. Oyuncu; üretim tesisleri, depolar, mağazalar, lojistik araçları, pazar, ar-ge, görevler ve başarımlar üzerinden kendi şirket ekonomisini büyütür.

Bu README, aktif `redesign` branch'inin güncel mimarisini ve geliştirme durumunu özetler.

## Oyun Döngüsü

```text
Oyuncu şirketini kurar
→ üretim tesisi / depo / mağaza / lojistik altyapısı kurar
→ ürün veya hammadde üretir
→ ürünleri depoya ve mağazaya taşır
→ mağaza satışıyla gelir elde eder
→ kalite, tesis, depo, lojistik ve şirket sistemlerini geliştirir
```

## Güncel Ana Sistemler

- **Oyuncu ve şirket sistemi:** Supabase Auth, oyuncu profili, şirket bilgileri, para, altın, seviye, XP, avatar ve marka/şirket verileri.
- **İnşaat sistemi:** mağaza, depo, tarla, çiftlik, fabrika, maden ve lojistik şirketi için zaman bazlı kurulum akışı.
- **Yükseltme ve boost sistemi:** üretim, mağaza, depo ve ilgili yapıların yükseltme/boost akışları.
- **Mağaza sistemi:** mağaza liste/detay ekranı, slot yönetimi, ürün atama, fiyatlandırma, aktif/pasif kontrol, mağaza deposu, satış geçmişi ve performans raporu.
- **Satış sistemi:** mağaza detayına girildiğinde çalışan pull-based satış işleme, satış sonucu bildirimi, günlük performans ve geçmiş kayıtları.
- **Depo sistemi:** depo listesi/detayı, stok slotları, kalite/maliyet takibi, kapasite ve rezerve kapasite mantığı, satışa açılabilir depo stoğu.
- **Üretim sistemi:** tarla, çiftlik, fabrika ve maden modülleri; üretim slotları, input/output envanteri, ürün seçimi, kalite seviyesi ve üretim raporu.
- **Maden sistemi:** maden tipi seçimi, ürün seçimi, üretim envanteri ve depoya transfer akışı.
- **Lojistik sistemi:** lojistik şirketi, araçlar, kapasite, hız, yakıt, kondisyon, kiralık/özmal araç seçimi, finans raporu ve transfer yönetimi.
- **Multi transfer sistemi:** tek parent transfer kaydı altında birden fazla transfer item'ı taşıyabilen yapı. Depo, mağaza, üretim ve pazar akışları multi transfer mantığına bağlanır.
- **Araç seçimi:** şehirden şehre rota ve toplam hacim bazlı araç seçimi hedeflenir. Multi transferlerde rota bazlı `get_route_transfer_vehicle_options` akışı kullanılmalıdır.
- **Transfer haritası:** aktif transferleri, yoldaki araçları ve transfer geçmişini takip etmek için harita modülü.
- **Pazar sistemi:** ürün bazlı market ekranı; hedef depo veya mağaza slotuna göre alım ve transfer seçenekleri.
- **Ar-Ge sistemi:** ürün kalite seviyelerini geliştirme, aktif araştırma takibi ve altınla araştırma tamamlama.
- **Görev / bildirim / başarı sistemi:** oyuncu ilerlemesini yönlendiren görev ekranı, bildirim ekranı, uyarılar ve başarımlar.
- **Nakit akışı:** para hareketlerini izlemek için cash-flow ekranı.
- **Asset cache sistemi:** Supabase Storage üzerinden oyun görsellerini indirme ve cihazda önbelleğe alma.

## Teknolojiler

| Alan | Teknoloji |
| --- | --- |
| Mobil framework | Flutter |
| Dil | Dart |
| State management | Riverpod |
| Routing | GoRouter |
| Backend | Supabase |
| Veritabanı | PostgreSQL |
| Backend fonksiyonları | Supabase RPC / PLpgSQL |
| Kimlik doğrulama | Supabase Auth / Google Sign-In |
| Storage | Supabase Storage |
| Local storage | Shared Preferences / Flutter Secure Storage |
| Ortam değişkenleri | flutter_dotenv |
| Responsive UI | flutter_screenutil |
| Lint | flutter_lints |
| App icon | flutter_launcher_icons |

## Proje Yapısı

```text
lib/
  core/
    constants/
    data/
    managers/
    models/
    navigation/
    providers/
    theme/
    utils/
    widgets/
  features/
    achievement/
    arge/
    auth/
    cash_flow/
    company/
    factory/
    farm/
    field/
    home/
    logistics/
    market/
    mine/
    mission/
    notification/
    production_report/
    splash/
    store/
    transfer_map/
    warehouse/
  main.dart

assets/
  theme/
  ...

docs/
  *.md
  *.sql

supabase/
  *.sql

database_schema.sql
ilerleme.md
```

## Uygulama Rotaları

Ana route'lar `lib/main.dart` içindeki GoRouter yapılandırmasında tutulur.

```text
/
/home
/profile
/company

/store
/store/new/city
/store/new/type
/store/:id
/store/:id/history
/store/:id/report
/store/:id/warehouse

/warehouses
/warehouses/new/city
/warehouses/new/type
/warehouses/:id
/warehouses/:id/history

/fields
/fields/new/city
/fields/new/type
/fields/:id

/farms
/farms/new/city
/farms/new/type
/farms/:id

/factories
/factories/new/city
/factories/new/type
/factories/:id

/mines
/mines/new/city
/mines/new/type
/mines/:id

/logistics
/logistics/setup
/logistics/finance
/transfer-map

/market
/market/:productId

/arge
/missions
/notifications
/alerts
/achievements
/cash-history
/production-report/:ownerKind/:id
```

## Ana Modüller

### Store

Mağaza tarafında slot açma, ürün atama, fiyat belirleme, aktif/pasif yönetimi, mağazaya bağlı depo, mağaza deposundan slota ürün aktarma, slot stoğunu mağaza deposuna geri alma, satış işleme, satış geçmişi ve günlük performans raporu bulunur.

### Warehouse

Depo sistemi ürün stoklarını, kalite seviyelerini, maliyet bilgisini, satışa açılma durumunu, kapasite kullanımını ve transfer rezervasyonlarını yönetir. Depolar arası transferlerde multi item payload ve rota bazlı araç seçimi hedeflenir.

### Field / Farm / Factory / Mine

Üretim tesisleri oyuncunun üretim zincirini oluşturur.

- Tarla ve çiftlik üretim slotlarıyla çalışır.
- Fabrika input/output envanteri, ürün seçimi ve üretim lojistiğiyle çalışır.
- Maden modülü ürün seçimi ve üretim output akışına bağlıdır.
- Üretim raporu ekranı, ilgili üretim biriminin üretim/stok performansını izlemek için kullanılır.

### Logistics ve Transfer Map

Lojistik sistemi araç kapasitesi, hız, yakıt, kondisyon, rota ve kiralama maliyetleriyle çalışır. Transfer map ekranı aktif transferlerin ve lojistik geçmişinin görsel takibi için kullanılır.

Multi transfer yapısında beklenen backend akışı:

```text
logistics_transfers          → parent transfer kaydı
logistics_transfer_items     → transferde taşınan ürün kalemleri
```

Aynı şehir transferleri anlık tamamlanabilir. Farklı şehir transferleri araç, rota, süre, yakıt ve kondisyon hesaplarıyla lojistik transfer olarak ilerler.

### Market

Pazar sistemi ürün bazlı satış noktalarını listeler. Oyuncu hedef depo veya mağaza slotuna göre market alımı yapabilir. Uygun transfer senaryosunda pazar alımı da lojistik/multi transfer akışına bağlanır.

### Ar-Ge

Ar-Ge modülü ürünlerin kalite seviyelerini geliştirmek için kullanılır. Oyuncu ürün araştırması başlatabilir, araştırma sürecini takip edebilir ve altın kullanarak araştırmayı hızlandırabilir.

### Görev, Bildirim ve Başarımlar

Görev, bildirim, uyarı ve başarım ekranları oyuncunun ilerlemesini takip etmek ve önemli olayları görünür yapmak için kullanılır.

### Cash Flow

Nakit akışı ekranı oyuncunun gelir/gider hareketlerini takip etmek için kullanılır.

## Veritabanı

Projede veritabanı şeması ve migration denemeleri `database_schema.sql`, `docs/` ve `supabase/` altındaki SQL dosyalarında tutulur.

Başlıca tablo aileleri:

- `players`
- `products`
- `cities`
- `stores`, `store_slots`, store warehouse ilişkili tablolar
- `warehouses`, `warehouse_slots`
- `fields`, `farms`, `factories`, `mines`
- `production_slots`
- `production_inventory`
- `building_constructions`
- `building_upgrades`
- `building_boosts`
- `logistics_companies`
- `logistics_vehicles`
- `logistics_transfers`
- `logistics_transfer_items`
- `store_daily_performance`
- `cash_flow` / para hareketi tabloları
- `arge_researches`
- `player_product_quality_levels`
- görev, bildirim ve başarım tabloları

Öne çıkan RPC aileleri:

- oyuncu, şirket, profil ve marka fonksiyonları
- yapı kurulum, tamamlama, yükseltme ve boost fonksiyonları
- mağaza liste/detay/satış/geçmiş/rapor fonksiyonları
- depo stok, kapasite ve transfer fonksiyonları
- üretim slot, üretim envanteri ve üretim raporu fonksiyonları
- multi lojistik transfer başlatma ve tamamlama fonksiyonları
- rota/toplam hacim bazlı araç seçimi fonksiyonları
- market satın alma ve transfer fonksiyonları
- ar-ge kalite geliştirme fonksiyonları
- görev, bildirim, başarım ve nakit akışı fonksiyonları

## Transfer Sistemi Notları

Aktif hedef, tüm gerçek transfer başlatma akışlarının multi transfer yapısını kullanmasıdır.

Kullanılması beklenen ana RPC'ler:

```text
start_multi_logistics_transfer
start_multi_market_transfer
start_multi_warehouse_to_production_transfer
start_multi_production_to_warehouse_transfer
complete_logistics_transfer
get_route_transfer_vehicle_options
```

Eski tekil araç seçimi mantığı olan `get_transfer_vehicle_options`, multi transferlerde tercih edilmemelidir. Multi transferlerde araç seçimi şehirden şehre toplam hacim üzerinden yapılmalıdır.

## Kurulum

Flutter SDK'nın kurulu olduğundan emin olun.

```bash
git clone https://github.com/windssson/hard_kapitalizm.git
cd hard_kapitalizm
git checkout redesign
flutter pub get
```

## Ortam Değişkenleri

Kök dizinde `.env` dosyası oluşturun:

```env
SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_supabase_anon_key
```

> Gerçek Supabase bilgilerini repoya commit etmeyin.

## Çalıştırma

```bash
flutter run
```

Belirli cihaz seçmek için:

```bash
flutter devices
flutter run -d <device_id>
```

## Faydalı Komutlar

```bash
# Bağımlılıkları yükle
flutter pub get

# Statik analiz
flutter analyze

# Testleri çalıştır
flutter test

# Android release build
flutter build apk --release

# Launcher icon üretimi
flutter pub run flutter_launcher_icons
```

## Geliştirme Notları

- Proje feature-based mimariyle ilerler.
- UI, model ve data/provider dosyaları modül bazlı ayrılır.
- Supabase bağlantı değerleri `.env` üzerinden okunur.
- Büyük işlemler mümkün olduğunca Supabase RPC tarafında yapılır.
- Üretim, mağaza, depo ve lojistik işlemlerinde kalite seviyesi, maliyet bilgisi ve kapasite hesapları korunmalıdır.
- Multi transferlerde tek parent transfer ve birden fazla item satırı mantığı korunmalıdır.
- Aynı şehir transferleri anlık, farklı şehir transferleri araçlı lojistik transfer olarak ilerleyecek şekilde tasarlanmıştır.
- Transfer araç seçimi, multi transferlerde toplam hacim ve rota mantığıyla yapılmalıdır.
- UI tarafında premium/oyunsu tasarım dili korunur; asset tabanlı panel, ikon ve kart yaklaşımı tercih edilir.

## Aktif Geliştirme Durumu

`redesign` branch'inin güncel odağı:

- multi transfer sistemini tüm transfer akışlarında standart hale getirmek,
- araç seçimini toplam hacim ve rota bazlı hale getirmek,
- üretim, depo, mağaza ve lojistik zincirini uçtan uca stabil hale getirmek,
- rapor, geçmiş, bildirim, görev ve başarım ekranlarını oyun döngüsüne bağlamak,
- mobil UI/UX tarafını daha premium ve okunabilir hale getirmek.

## Öncelikli Kontrol Senaryosu

MVP doğrulaması için şu uçtan uca zincir test edilmelidir:

```text
Yeni oyuncu
→ şirket/profil oluştur
→ depo kur
→ üretim tesisi kur
→ ürün seç
→ üretim input/output kontrolü
→ üretimi depoya aktar
→ depodan mağazaya aktar
→ mağazaya girince satış işle
→ para artışı, cash-flow, satış geçmişi ve rapor kontrolü
→ görev/bildirim/başarım tetiklerini kontrol et
→ transfer haritasında aktif/geçmiş transferleri doğrula
```

## Lisans

Bu repoda henüz lisans dosyası bulunmuyor. Kullanım ve dağıtım şartları daha sonra netleştirilmelidir.
