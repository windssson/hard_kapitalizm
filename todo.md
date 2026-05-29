# Modül TODO Durumu ve Proje Analizi

Bu liste geliştirme takibi için tutulur. Yüzdeler "Feature Coverage (Özellik Kapsamı) + Entegrasyon Olgunluğu" bazlı mühendislik tahminidir.

## Genel Durum
- **İstemci (UI / Flutter) Tamamlanma Oranı:** ~%98
- **Veritabanı (Supabase PostgreSQL + RPC) Tamamlanma Oranı:** ~%90

---

## Modül Listesi & Tamamlanma Oranları

- [x] **Splash** - %98
  - *Yapılanlar:* Cihaz kimliği ile otomatik anonim giriş, varlıkların önceden indirilmesi (prefetch), gecikmiş inşaat ve market transferlerinin otomatik tetiklenerek tamamlanması.
- [x] **Auth (Profil)** - %95
  - *Yapılanlar:* Supabase üzerinden cihaz UUID tabanlı e-posta/şifre ile arka planda sorunsuz giriş/kayıt, veritabanında `ensure_player_record_exists` ile oyuncu kaydının otomatik oluşturulması, profil ekranı.
- [x] **Home (Anasayfa)** - %90
  - *Yapılanlar:* CEO paneli, seviye ve deneyim göstergeleri, kasa/altın bilgileri, modül navigasyon ızgarası, finansal özetler ve haber akışı.
- [x] **Market (Pazar)** - %100
  - *Yapılanlar:* Alış/satış listelemeleri, filtreleme, satın alma işlemleri ve veritabanı entegrasyonu.
- [x] **Logistics (Lojistik)** - %100
  - *Yapılanlar:* Araç listesi, şirket kurulumu, araç kapasiteleri ve sevkiyat/lojistik yönetimi.
- [x] **Transfer Map (Transfer Haritası)** - %95
  - *Yapılanlar:* Aktif ve geçmiş lojistik transferlerin takibi, teslimat süreleri, kullanılmayan kodların ve static analiz uyarılarının temizlenmesi.
- [x] **Warehouse (Depo)** - %100
  - *Yapılanlar:* Doluluk ve rezerve kapasite gösterimleri (2 ayrı bar), slot yönetimi, ürün detayları ve diğer birimlerle görsel standartlaştırma.
- [x] **Store (Mağaza)** - %100
  - *Yapılanlar:* Satış slotu ekleme/çıkarma, fiyat belirleme, depodan mağazaya stok aktarımı, mağaza performans raporları ve geçmiş veriler.
- [x] **Field (Tarla)** - %100
  - *Yapılanlar:* Çoklu slot yönetimi, tohum ekimi, aktif/pasif durumu, hammadde ve üretilen ürün maliyet gösterimleri.
- [x] **Farm (Çiftlik)** - %100
  - *Yapılanlar:* Hayvan/ürün üretimi, slot yönetimi, seviye yükseltme, hammadde ve ürün maliyet entegrasyonu.
- [x] **Factory (Fabrika)** - %100
  - *Yapılanlar:* Giriş hammaddeleri ve çıkış ürünlerinin yönetimi, hammadde ve ürün maliyet gösterimleri, boost sistemi, üretim hızlandırmaları.
- [x] **Mine (Maden)** - %100
  - *Yapılanlar:* Hammaddesiz üretim yönetimi, üretilen maden maliyet gösterimi, seviye yükseltme.
- [x] **Arge (Araştırma & Geliştirme)** - %95
  - *Yapılanlar:* AR-GE merkezi seviye yükseltme, eşzamanlı araştırma slotları, araştırma süre azaltma bonusları, altınla anında tamamlama, ürün kalite kilidi açma.

---

## Veritabanı ve Backend Durumu (Supabase)

### Tamamlanan Altyapı
- Tüm tablolar (32 adet) oluşturulmuş ve RLS (Row Level Security) kuralları aktif hale getirilmiştir.
- **İnşaat Sistemi:** İnşaat başlatma, tamamlama, iptal etme ve iade (%50 cash) fonksiyonları.
- **Üretim Döngüleri (Cron):** 10 dakikalık kaydırmalı (offset) cron’lar ile Maden, Fabrika, Tarla ve Çiftlik üretim işlemleri veritabanı düzeyinde optimize edilmiştir.
- **Maliyet Hesaplama:** Hammadde girdi maliyetleri üzerinden ağırlıklı ortalama birim maliyet hesaplaması ve Madenler için baz satış fiyatının %10'u oranında otomatik maliyet ataması.

### Kalan / Eksik Backend İşleri (UI Akışları Sonrası Planlananlar)
1. **Mağaza Satış Cron Sistemi:**
   - Müşteri ziyareti, satış hızları ve stok eritme işlemlerini yürütecek backend satış cron'u ve algoritması henüz detaylandırılmadı.
2. **Lojistik Detay İşlemleri:**
   - Şirket dışı araç kiralama, yakıt yönetimi ve araç satın alma fonksiyonlarının backend entegrasyonu.
3. **Veritabanı Temizliği (Cleanup):**
   - Miktarı ve bekleyen miktarı sıfır (quantity = 0, pending_quantity = 0) olan atıl `production_inventory` kayıtlarını temizleyecek periodik fonksiyon.

---

## Önerilen Sonraki Odak Noktası

1. **Mağaza Satış Altyapısı (Backend/Cron):**
   - Mağazalarda stokların otomatik satılması ve oyuncuya gelir getirmesi için veritabanında satış cron'unun kurulması.
2. **Lojistik Detayları (Kiralama & Satın Alma):**
   - Lojistik araçlarının kiralama ve satın alma işlemlerinin entegrasyonunun tamamlanması.
