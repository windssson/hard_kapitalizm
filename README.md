# Hard Kapitalizm

Hard Kapitalizm, Flutter ve Supabase ile geliştirilen mobil odaklı bir tycoon ekonomi simülasyonu oyunudur. Oyuncu; üretim tesisleri, depolar, mağazalar, lojistik araçları, pazar ve ar-ge sistemleri üzerinden kendi şirket ekonomisini büyütür.

Bu branch, projenin endüstriyel üretim, üretim lojistiği, ar-ge, mağaza satış raporları ve transfer haritası sistemlerini içeren aktif geliştirme branch'idir.

## Proje Özeti

Oyunun temel döngüsü:

```text
Üretim tesisi kur → ürün/hammadde yönet → depoya aktar → mağazaya taşı → satış yap → gelir elde et → kalite/tesis/lojistik geliştir
```

## Ana Özellikler

- **Oyuncu sistemi:** anonim giriş, oyuncu kaydı, para, altın, seviye, XP ve avatar bilgileri.
- **İnşaat sistemi:** mağaza, depo, tarla, çiftlik, fabrika, maden ve lojistik şirketi için zaman bazlı kurulum akışı.
- **Mağaza sistemi:** mağaza listeleme, mağaza detay, slot yönetimi, ürün seçimi, fiyat belirleme, aktif/pasif slot kontrolü.
- **Satış sistemi:** oyuncu mağaza detayına girdiğinde satışların işlenmesi, satış sonucu popup'ı, performans ve geçmiş kayıtları.
- **Depo sistemi:** depo kurma, stok slotları, kapasite yönetimi, ürün kalite/maliyet takibi.
- **Üretim sistemi:** tarla, çiftlik ve fabrika için üretim slotları, input/output üretim envanteri ve ürün seçimi.
- **Maden sistemi:** maden yapısı ve üretim modülü için altyapı.
- **Lojistik sistemi:** araç satın alma, rota/şehir bilgisi, yakıt, kondisyon, kiralık/özmal araç seçimi ve transfer başlatma.
- **Üretim lojistiği:** depodan üretim input envanterine ve üretim output envanterinden depoya transfer akışı.
- **Transfer haritası:** aktif lojistik transferleri ve geçmiş transferleri izlemek için harita modülü.
- **Ar-Ge sistemi:** ürün kalite seviyesi geliştirme, aktif araştırma takibi, altınla araştırma tamamlama.
- **Pazar sistemi:** ürün bazlı listeleme, depo/mağaza hedefli alım-satım ve transfer seçenekleri.
- **Asset cache sistemi:** Supabase Storage üzerinden oyun görsellerinin indirilmesi ve cihazda önbelleğe alınması.

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
| Realtime | Supabase Stream |
| Storage | Supabase Storage |
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
    providers/
    theme/
    utils/
    widgets/
  features/
    arge/
    auth/
    factory/
    farm/
    field/
    home/
    logistics/
    market/
    mine/
    splash/
    store/
    transfer_map/
    warehouse/
  main.dart

docs/
  logistics_vehicle_route_migration_draft.sql
  logistics_vehicle_route_plan.md
  production_logistics_migration_20260522.sql
  production_logistics_plan.md
  rpc_non_stream_phase1.sql
  rpc_phase1_shared_backend.sql

database_schema.sql
ilerleme.md
assets/
```

## Ana Modüller

### Store

Mağaza tarafında slot açma, ürün atama, fiyat belirleme, aktif/pasif yönetimi, depodan mağazaya transfer, mağazadan depoya geri transfer, satış işleme, satış geçmişi ve günlük performans raporu bulunur.

İlgili ekranlar:

```text
/store
/store/new/city
/store/new/type
/store/:id
/store/:id/history
/store/:id/report
```

### Warehouse

Depo sistemi ürün stoklarını, kalite seviyelerini, maliyet bilgisini, satışa açılma durumunu ve kapasite kullanımını yönetir.

İlgili ekranlar:

```text
/warehouses
/warehouses/new/city
/warehouses/new/type
/warehouses/:id
```

### Field / Farm / Factory / Mine

Üretim tesisleri oyuncunun üretim zincirini oluşturur. Tarla ve çiftlik üretim slotlarıyla çalışır. Fabrika ürün seçimi, input/output envanteri ve üretim lojistiğiyle daha gelişmiş bir yapıya sahiptir. Maden modülü aynı üretim yaklaşımına bağlanacak şekilde hazırlanmıştır.

İlgili ekranlar:

```text
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
```

### Logistics ve Transfer Map

Lojistik sistemi araç kapasitesi, hız, yakıt, kondisyon, rota ve kiralama maliyetleriyle çalışır. Transfer map ekranı aktif transferlerin ve lojistik geçmişinin görsel olarak izlenmesi için kullanılır.

İlgili ekranlar:

```text
/logistics
/logistics/setup
/transfer-map
```

### Ar-Ge

Ar-Ge modülü ürünlerin kalite seviyelerini geliştirmek için kullanılır. Oyuncu ürün araştırması başlatabilir, araştırma sürecini takip edebilir ve altın kullanarak araştırmayı hızlandırabilir.

İlgili ekran:

```text
/arge
```

### Market

Pazar sistemi ürün bazlı satış noktalarını listeler. Hedef depo veya mağaza slotu üzerinden transfer seçenekleriyle satın alma/taşıma akışına bağlanır.

İlgili ekran:

```text
/market/:productId
```

## Veritabanı

Bu branch'te tüm veritabanı yapısı `database_schema.sql` dosyasında tutulur.

Şema içinde başlıca tablolar:

- `players`
- `products`
- `cities`
- `stores`
- `store_slots`
- `store_daily_performance`
- `warehouses`
- `warehouse_slots`
- `fields`
- `farms`
- `factories`
- `mines`
- `production_slots`
- `production_inventory`
- `logistics_companies`
- `logistics_vehicles`
- `logistics_transfers`
- `arge_researches`
- `player_product_quality_levels`

Veritabanı tarafında Supabase RPC fonksiyonları yoğun kullanılır. Öne çıkan RPC aileleri:

- yapı kurulum ve inşaat fonksiyonları
- mağaza liste/detay/satış fonksiyonları
- depo stok ve kapasite fonksiyonları
- üretim slot ve üretim envanteri fonksiyonları
- üretim lojistiği transfer fonksiyonları
- ar-ge kalite geliştirme fonksiyonları
- market ve transfer araç seçenekleri fonksiyonları

## Kurulum

Flutter SDK'nın kurulu olduğundan emin olun.

```bash
git clone https://github.com/windssson/hard_kapitalizm.git
cd hard_kapitalizm
git checkout feature/setup-industrial-units
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
- Realtime gereken yerlerde Supabase stream kullanılır.
- Büyük işlemler mümkün olduğunca backend RPC tarafında yapılır.
- Üretim, mağaza, depo ve lojistik işlemlerinde kalite seviyesi ve maliyet bilgisi korunmalıdır.
- Aynı şehir transferleri anlık, farklı şehir transferleri lojistik transfer sistemi üzerinden ilerleyecek şekilde tasarlanmıştır.

## Aktif Geliştirme Durumu

Bu branch'in odağı:

- endüstriyel üretim birimlerini tamamlamak,
- üretim envanteri ile depo/mağaza akışını bağlamak,
- üretim lojistiğini transfer map'e entegre etmek,
- mağaza satış raporlarını ve geçmişini oturtmak,
- ar-ge kalite sistemini üretim ve satış zincirine bağlamak.

## Öncelikli Kontrol Senaryosu

MVP doğrulaması için şu uçtan uca zincir test edilmelidir:

```text
Yeni oyuncu → depo kur → üretim tesisi kur → ürün seç → üretim input/output kontrolü → depoya aktar → mağazaya aktar → mağazaya girince satış işle → para artışı → satış raporu/geçmiş kontrolü
```

## Lisans

Bu repoda henüz lisans dosyası bulunmuyor. Kullanım ve dağıtım şartları daha sonra netleştirilmelidir.
