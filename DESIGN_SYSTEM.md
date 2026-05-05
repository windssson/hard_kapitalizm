# Hard Kapitalizm - UI/UX Design System & Guidelines

Bu doküman, Hard Kapitalizm projesine eklenecek her yeni sayfanın (Pazar, Raporlar, Ayarlar vb.) görsel ve yapısal bütünlüğünü korumak için uyulması gereken zorunlu standartları tanımlar.

## 1. Sayfa Yapısı ve Arka Plan (Global Background)
Oyunun genelinde saydamlık ve endüstriyel "Tycoon" hissi hedeflenmektedir. Arka plan görseli (`assets/back.png` opacity: 0.2) uygulamanın en üst katmanında `main.dart` içinde global olarak tanımlanmıştır. 

Bu nedenle yeni oluşturulan **tüm sayfaların** temel iskeleti (Scaffold) saydam olmalıdır:
```dart
return Scaffold(
  backgroundColor: Colors.transparent, // ZORUNLU
  body: SafeArea(
    child: Column(
      children: [
        const AppTopBar(), // ZORUNLU ÜST MENÜ
        Expanded(
          child: SingleChildScrollView(
            child: // ... İçerik
          ),
        ),
        AppBottomNav(
          selectedIndex: 1, // Sayfanın indexi
          onItemSelected: (index) { ... },
        ),
      ],
    ),
  ),
);
```

## 2. Duyarlılık ve Ekran Ölçekleme (Responsiveness)
Projeye `flutter_screenutil` entegre edilmiştir. Uygulamanın her cihazda (telefon/tablet) **birebir** aynı oranda görünmesi için `const` veya sabit boyut değerleri (örn: `width: 20`) KULLANILAMAZ. 

Her piksel, padding, margin, font ve radius değeri ekran çözünürlüğüne göre dinamik hesaplanmalıdır:
- **Genişlik & Padding yatay:** `.w` kullan (örn: `SizedBox(width: 12.w)`)
- **Yükseklik & Padding dikey:** `.h` kullan (örn: `SizedBox(height: 16.h)`)
- **Font Büyüklüğü:** `.sp` kullan (örn: `fontSize: 14.sp`)
- **Yuvarlama/Radius:** `.r` kullan (örn: `BorderRadius.circular(12.r)`)

## 3. Renk Paleti (`AppColors`)
Sayfalarda doğrudan "Colors.red" veya statik hex kodları kullanmak yasaktır. Daima `lib/core/theme/app_theme.dart` içindeki `AppColors` sınıfı kullanılmalıdır:
- **Arka Planlar:** `AppColors.cardBg` veya daha açık versiyonlar için `AppColors.cardBgLight`.
- **Border'lar (Çizgiler):** Kartlar için `AppColors.borderGold`, menüler için `AppColors.border`.
- **Vurgular (Accent):** Ana para/başarı için `AppColors.gold`, daha parlak detaylar için `AppColors.goldLight`. Pozitif değerler `AppColors.green`, uyarılar `AppColors.red`.
- **Metinler:** `AppColors.textPrimary` (başlıklar/net metinler), `AppColors.textSecondary` (açıklama/alt metinler).

## 4. Tipografi (`AppTextStyles`)
Yazı stilleri `AppTextStyles` üzerinden çağrılmalıdır. Yeni bir text stili tanımlanacaksa bile `Theme.of(context)` veya mevcut yapıya uygun `.sp` kullanılmalıdır:
```dart
Text('Şirket Raporu', style: AppTextStyles.h1);
Text('Günlük gelir artışı', style: AppTextStyles.body);
Text('245.8M', style: AppTextStyles.statValue);
```

## 5. Kart (Card) Tasarım Standardı
Oyunun genelinde kullanılan modüllerin ve raporların arka planları "Düz Renk + Altın Çizgi" mantığına dayanır:
```dart
Container(
  padding: EdgeInsets.all(12.w),
  decoration: BoxDecoration(
    color: AppColors.cardBg, // Koyu Lacivert/Siyah
    borderRadius: BorderRadius.circular(12.r),
    border: Border.all(color: AppColors.borderGold), // Altın çerçeve
  ),
  child: // ...
)
```
Gerekli durumlarda (üst seviye hissi vermek için) `Gradient` kullanılabilir. Gradients genellikle dikey (Top-Bottom) yönlü ve `AppColors.gold.withValues(alpha: 0.1)` şeklinde çok hafif altın rengi yansımalardan oluşmalıdır.

## 6. Görsel ve İkon Yönetimi
- **Modül Görselleri:** Sadece `CachedAssetImage(fileName: 'isim.webp')` ile kullanılmalıdır. Asla `Image.asset()` veya başka bir network image çağrısı KULLANILMAZ.
- **Standart İkonlar:** Material ikonlar veya özel `.png` ikonlar kullanılacaksa, mutlaka `AppColors.gold` veya `AppColors.textSecondary` ile renklendirilmelidir.

Bu doküman projenin anayasasıdır. Yeni modüller üretilirken eski modüllerdeki padding ve yapı kodları kopyalanarak referans alınmalıdır.
