# Hard Kapitalizm

Hard Kapitalizm, mobil odaklı bir ekonomi ve ticaret simülasyonu oyunudur. Oyuncu; mağaza, depo, tarla, çiftlik, fabrika, maden, lojistik ve pazar sistemleri üzerinden üretim-satış zincirini yönetir.

Proje Flutter ile geliştirilmiştir ve backend tarafında Supabase kullanır.

## İçindekiler

- [Özellikler](#özellikler)
- [Teknolojiler](#teknolojiler)
- [Proje Yapısı](#proje-yapısı)
- [Kurulum](#kurulum)
- [Ortam Değişkenleri](#ortam-değişkenleri)
- [Çalıştırma](#çalıştırma)
- [Geliştirme Notları](#geliştirme-notları)

## Özellikler

- **Mağaza yönetimi:** oyuncuya ait mağazaları listeleme, mağaza kurma ve mağaza detay ekranları.
- **Depo yönetimi:** şehir ve depo türüne göre depo kurma, depo listeleme ve depo detay yönetimi.
- **Üretim alanları:** tarla, çiftlik, fabrika ve maden modülleri.
- **Pazar ekranı:** ürün bazlı market/alış-satış akışı için ekran yapısı.
- **Lojistik yönetimi:** lojistik yönetim ve kurulum ekranları.
- **Profil ve başlangıç akışı:** splash, home ve profil ekranları.
- **Responsive arayüz:** `flutter_screenutil` ile mobil ekranlara uyumlu ölçülendirme.
- **Supabase entegrasyonu:** proje ayarları `.env` üzerinden okunur ve uygulama başlangıcında Supabase başlatılır.

## Teknolojiler

| Alan | Teknoloji |
| --- | --- |
| Mobil framework | Flutter |
| Dil | Dart |
| State management | Riverpod |
| Routing | GoRouter |
| Backend / servis | Supabase |
| Ortam değişkenleri | flutter_dotenv |
| Responsive UI | flutter_screenutil |
| Lint | flutter_lints |
| App icon | flutter_launcher_icons |

## Proje Yapısı

Proje feature-first yapıya göre düzenlenmiştir. Her ana oyun sistemi kendi `features` klasörü altında toplanır.

```text
lib/
  core/
    constants/
    models/
    theme/
  features/
    auth/
    farm/
    factory/
    field/
    home/
    logistics/
    market/
    mine/
    splash/
    store/
    warehouse/
  main.dart
assets/
  logo.png
  back.png
```

Ana route yapısı `lib/main.dart` içinde tanımlanır. Uygulamadaki temel yollar:

```text
/                     Splash
/home                 Ana ekran
/profile              Profil
/store                Mağazalar
/store/new/city       Mağaza için şehir seçimi
/store/new/type       Mağaza türü seçimi
/store/:id            Mağaza detay
/fields               Tarlalar
/farms                Çiftlikler
/factories            Fabrikalar
/mines                Madenler
/warehouses           Depolar
/warehouses/:id       Depo detay
/logistics            Lojistik yönetimi
/logistics/setup      Lojistik kurulumu
/market/:productId    Ürün pazarı
```

## Kurulum

Önce Flutter SDK'nın kurulu olduğundan emin olun.

```bash
git clone https://github.com/windssson/hard_kapitalizm.git
cd hard_kapitalizm
flutter pub get
```

## Ortam Değişkenleri

Proje Supabase bilgilerini kök dizindeki `.env` dosyasından okur.

Kök dizinde `.env` dosyası oluşturun:

```env
SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_supabase_anon_key
```

> Not: Gerçek Supabase anahtarlarını repoya commit etmeyin. `.env` dosyası yerel geliştirme ortamında tutulmalıdır.

## Çalıştırma

```bash
flutter run
```

Belirli bir cihaz seçmek için:

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

- UI tarafı feature klasörleri altında tutulur.
- Supabase bağlantı değerleri `lib/core/constants/supabase_constants.dart` üzerinden okunur.
- Route yönetimi `GoRouter` ile yapılır.
- Uygulama `ProviderScope` ile başlatıldığı için Riverpod provider yapısı tüm uygulama genelinde kullanılabilir.
- Tema ve ana arka plan yapısı `MaterialApp.router` builder katmanında uygulanır.

## Durum

Proje aktif geliştirme aşamasındadır. Oyun sistemleri modül modül geliştiriliyor ve mevcut yapı özellikle mobil ekonomi simülasyonu akışına göre şekillendiriliyor.

## Lisans

Bu repoda henüz lisans dosyası bulunmuyor. Kullanım ve dağıtım şartları daha sonra netleştirilmelidir.
