# Hard Kapitalizm - Geliştirme Rehberi ve İlerleme Durumu

## 🎯 Proje Özeti
- **Adı:** Hard Kapitalizm
- **Tür:** Tycoon Ekonomi Simülasyonu
- **State Management:** Riverpod
- **Routing:** GoRouter
- **Mimari:** Feature-based (Her modül `lib/features` altında: `data`, `models`, `ui`, `widget`)
- **Backend:** Supabase (PostgreSQL, RPC, RLS, Storage)
- **Tasarım Dili:** Glassmorphism, Koyu Tema (Dark Mode), Altın/Premium Vurgular (Tycoon Aesthetics)

## 📂 Klasör Yapısı
```text
lib/
├── core/            # Tema, Widget'lar, Yöneticiler (AppColors, AppTextStyles, vb.)
└── features/
    ├── auth/        # Oyuncu giriş, kayıt ve profil (Avatar) yönetimi
    ├── factory/     # Fabrika inşa ve üretim yönetimi
    ├── farm/        # Çiftlik yönetimi
    ├── field/       # Tarla (Ekim/Biçim) yönetimi
    ├── home/        # Ana Dashboard ekranı
    ├── logistics/   # Lojistik, Araç filosu, kiralama ve bakım
    ├── market/      # Global pazar yeri
    ├── mine/        # Maden ocakları yönetimi
    ├── splash/      # Yükleme ve veri indirme ekranı
    ├── store/       # Mağaza yönetimi, satış slotları ve şehir seçim haritası
    ├── transfer_map/# Lojistik rotaları, canlı transfer haritası ve lojistik geçmişi
    └── warehouse/   # Depo inşa, stok ve kapasite yönetimi
```

## ✅ Tamamlananlar
### 1. Temel Altyapı ve Backend
- [x] Proje kurulumu, `flutter_riverpod` ve `go_router` entegrasyonları tamamlandı.
- [x] Supabase entegrasyonu, Realtime veritabanı bağlantıları (`StreamProvider` + `.autoDispose`) kuruldu.
- [x] Storage (Bucket) bağlantıları yapıldı, AssetManager ile görsel önbellekleme (Caching) aktifleştirildi.
- [x] Performans ve güvenlik iyileştirmeleri (RLS politikaları, `SECURITY DEFINER` kısıtlamaları) uygulandı.

### 2. UI/UX ve Tasarım Dili (Tycoon Teması)
- [x] "Glassmorphism" odaklı, şeffaf kartlar (`AppColors.cardBg`), altın renkli kenarlıklar ve blur efektleri tüm arayüze işlendi.
- [x] Global arka plan yapısı (`HomeScreen` vb.) her ekrana yansıtıldı.
- [x] Gelişmiş veri görselleştirmeleri: Canlı dolum barları, durum bildiren badge'ler ve premium diyalog (AlertDialog) pencereleri tasarlandı.

### 3. Modül Geliştirmeleri
- **Oyuncu (Player):** Gerçek zamanlı bakiye, altın, XP takibi ve dinamik avatar seçimi.
- **Tesisler (Binalar):** Mağaza, Depo, Tarla, Çiftlik, Fabrika ve Maden modüllerinin veri modelleri ve state provider'ları yazıldı.
- **İnşaat Sistemi:** İstemci tarafında çalışan yüksek performanslı zamanlayıcılar eklendi. Supabase RPC tetiklemeleriyle ("Altınla Hızlandır" vb.) inşaatlar bağlandı.
- **Lojistik ve Araçlar:** Yakıt durumu, kondisyon ve operasyonel kapasite takip göstergeleri eklendi. Filo alımı, onarımı ve kiralama sistemi tamamlandı.
- **Harita Sistemleri (Map & Rota):**
  - İnşaat alanı seçimi için Türkiye lokasyon bazlı interaktif harita (`CitySelectionScreen`) yapıldı.
  - Sabit En/Boy oranı (`AspectRatio`) ve kalibre edilmiş koordinatlar (`minLat, maxLat` padding sistemi) ile `assets/backmap.webp` arka planı oturtuldu.
  - Klasik ikonlar yerine altın renkli, parlayan (glowing) interaktif "Node" tasarımı uygulandı.
  - Araç hareketlerini canlı izlemek için interpolasyonlu (`lerp`) Transfer Takip Haritası ve detaylı lojistik geçmişi (History) kodlandı.
  - Gerçek dünya koordinatlarına sahip yeni şehirler (Sivas, Malatya, Kayseri, Denizli, Düzce, Rize) veritabanına entegre edildi.

## 🚀 Bekleyen Görevler ve Gelecek Adımlar
- [ ] **Market ve Ekonomi Dengesi:**
  - [ ] Global pazar fiyatlarının dalgalanma mantığının (Supply/Demand) backend tarafında `pg_cron` veya Edge Functions ile otomatikleştirilmesi.
- [ ] **Optimizasyon:**
  - [ ] Çok fazla transfer olduğunda harita (`TransferMapPainter`) üzerindeki performansın `RepaintBoundary` ile optimize edilmesi.
- [ ] **Bildirim Sistemi:**
  - [ ] İnşaat bittiğinde veya nakliye aracı hedefe ulaştığında oyuncuya Push Notification (FCM) veya oyun içi bildirim (Snackbar/Toast) yollanması.
- [ ] **Yeni İçerikler:**
  - [ ] Yeni endüstri zincirlerinin ve ürün türlerinin (Level sistemine göre kilit açılması) veritabanına eklenmesi.
