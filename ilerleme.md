# Hard Kapitalizm - Geliştirme Rehberi ve İlerleme Durumu

## 🎯 Proje Özeti
- **Adı:** Hard Kapitalizm
- **Tür:** Tycoon Ekonomi Simülasyonu
- **State Management:** Riverpod
- **Routing:** GoRouter
- **Mimari:** Feature-based (Her modül `lib/features` altında yer alacak. Alt klasörler: `model`, `repository`, `ui`, `widget`)

## 📂 Klasör Yapısı
```text
lib/
└── features/
    └── [modül_adı]/
        ├── model/       # Veri modelleri (DTO, Entities)
        ├── repository/  # Veri kaynağı işlemleri (Supabase, Firebase, Local db vb.)
        ├── ui/          # Ekranlar (Screens, Pages)
        └── widget/      # Modüle özel tekrar kullanılabilir widget'lar
```

## ✅ Tamamlananlar
- [x] Temel Flutter projesi yapılandırıldı.
- [x] `flutter_riverpod` ve `go_router` paketleri projeye eklendi.
- [x] `main.dart` Riverpod (`ProviderScope`) ve `GoRouter` ile güncellendi.
- [x] Feature tabanlı modüler mimari için klasör yapısı kuralı belirlendi.
- [x] İlk modül olan `auth` (Kimlik Doğrulama) için gerekli dizinler oluşturuldu (`lib/features/auth/...`).
- [x] Supabase paketi eklendi, URL/Key yapılandırması (`.env` ve `lib/core/constants/supabase_constants.dart`) yapıldı ve `main.dart` üzerinden başlatıldı.
- [x] Görsel kaynak yönetim sistemi (`AssetManager`) ve `CachedAssetImage` widget'ı yazıldı (Supabase assets bucket'ı üzerinden dinamik indirme ve lokal önbellekleme).
- [x] Oyun başlangıcı için dinamik indirmeyi takip eden animasyonlu Yükleme Ekranı (Splash Screen) yapıldı.

## 🚀 Bekleyen Görevler
- [ ] **Auth Modülü:**
  - [ ] `ui` altında temel `LoginScreen` (Giriş Ekranı) oluşturulması.
  - [ ] Tycoon atmosferine uygun koyu tema, glassmorphism veya endüstriyel esintili giriş tasarımı.
  - [ ] `model` altında kullanıcı veri modelinin oluşturulması.
  - [ ] `repository` altında kimlik doğrulama işlemlerinin (Login, Register, Logout) simüle edilmesi/yazılması.
  - [ ] Riverpod ile auth durumunun dinlenip GoRouter üzerinden giriş yapılıp yapılmadığına göre yönlendirme mantığının (`redirect`) kurulması.
- [ ] **Dashboard Modülü:**
  - [ ] Auth sonrasında gidilecek ana merkez ekranının detaylandırılması.
