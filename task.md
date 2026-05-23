# Hard Kapitalizm - Genel Görev Listesi ve Yol Haritası

Bu dosya, projenin sonuna kadar hem backend hem de frontend entegrasyonlarını takip etmek amacıyla kullanılacak genel görev listesidir.

---

## 🗺️ Geliştirme Yol Haritası

### Faz 1: UI Temizlik ve Harita Optimizasyonu 🛠️
- [x] Tüm kullanılmayan elementlerin, değişkenlerin ve `ref.refresh` uyarılarının giderilmesi.
- [x] Canlı transfer haritasında (`TransferMapPainter`) yüksek yoğunlukta araç/transfer çiziminde performansın `RepaintBoundary` ile optimize edilmesi.

### Faz 2: Lojistik, Transfer ve Araç Sistemleri 🚚
- [ ] Transfer fonksiyonlarının veritabanında test edilmesi ve UI entegrasyonlarının tamamlanması:
  - [ ] `transfer_production_inventory_to_warehouse` (Üretimden depoya aktarma)
  - [ ] `transfer_warehouse_slot_to_production_inventory` (Depodan üretime girdi aktarma)
  - [ ] `transfer_warehouse_slot_to_store_slot` (Depodan mağazaya sevkiyat)
  - [ ] `transfer_store_slot_to_warehouse` (Mağazadan depoya iade)
- [ ] Lojistik ve Araç Yönetim Sisteminin geliştirilmesi:
  - [ ] Araç satın alma sistemi UI ve backend entegrasyonu.
  - [ ] Yakıt yönetimi ve istasyonlar.
  - [ ] Araç kiralama ve kondisyon/onarım sistemi.

### Faz 3: Mağaza Satış Sistemi ve Satış Cron'u 🛒
- [ ] Mağaza satış akışlarının ve UI ekranlarının tasarlanması/entegrasyonu.
- [ ] Satış tetikleme cron fonksiyonunun (pg_cron veya Edge Function) backend tarafında yazılması.
- [ ] Mağazalardaki talep durumlarına (Supply/Demand) göre satış fiyatı ve miktar optimizasyonu.

### Faz 4: Global Market ve Ekonomi Dengesi ⚖️
- [ ] Global pazar fiyatlarının dalgalanma mantığının (Supply/Demand) backend tarafında `pg_cron` veya Edge Functions ile otomatikleştirilmesi.
- [ ] Oyuncuların marketten anlık alışveriş yapabilmesi için dinamik fiyatlandırma entegrasyonu.

### Faz 5: Seviye, Kilit Açma ve Bildirim Sistemleri 🎖️
- [ ] İnşaat bittiğinde veya transfer hedefe ulaştığında anlık/oyun içi bildirimlerin tetiklenmesi (Snackbar, Toast veya FCM Push Notifications).
- [ ] Oyuncu seviye (Level) atlama sistemi: Level yükseldikçe yeni endüstri zincirlerinin ve ürün türlerinin kilitlerinin açılması, veritabanı entegrasyonları.

### Faz 6: Veritabanı Optimizasyonu ve Temizlik (Cleanup) 💾
- [x] Önerilen kalıcı indexlerin PostgreSQL tarafında oluşturulması:
  - [x] Production slots active index
  - [x] Production inventory field/farm output index
  - [x] Production inventory field/farm input index
  - [x] Production inventory owner/type index
  - [x] Production inventory mine output index
  - [x] Mines active product index
- [ ] `cleanup` fonksiyonunun yazılması: `quantity = 0` ve `pending_quantity = 0` olan ve aktif üretimle eşleşmeyen eski kayıtların temizlenmesi.

---

## 📈 Durum Takip İpuçları
- Tamamlanan maddeleri `- [ ]` formatından `- [x]` formatına getirin.
- Süreçte olan ve üzerinde çalışılan maddeleri `- [/]` şeklinde işaretleyin.
