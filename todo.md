# Hard Kapitalizm Progress Snapshot

Tarih: 2026-06-28

Not:
- Bu yüzdeler kesin teknik metrik değil, planlama için çıkarılmış güncel durum tahminidir.
- Değerlendirme kriteri:
  - Rota/screen var mı
  - Data/provider/RPC zinciri çalışıyor mu
  - Ana gameplay döngüsünde kullanılabilir mi
  - Geçici, kapalı veya eksik akış var mı
  - Raporlama/polish/test borcu ne kadar

## Genel Durum

- Tahmini genel tamamlanma: `%84` (Son yapılan büyük redesign ve stabilizasyon çalışmalarıyla yükseldi)
- Oynanabilir çekirdek durum: `çok iyi`
- En kritik iyileştirme alanı:
  - Late-game dengesi ve pazar fiyat mekanizmaları
  - Logistics edge-case stabilizasyonları
  - AR-GE modülünün oyun içi etkisinin artırılması

## Modül Bazlı Yüzdeler

| Modül | Durum | Tahmini Tamamlanma | Not |
|---|---:|---:|---|
| `splash` | Çalışıyor | `90%` | Giriş esnasında aktif ürünlerin önbelleğe alınması entegre edildi. |
| `auth` | Çalışıyor | `75%` | Profil ve session tarafı stabil. |
| `home` | Güçlü | `88%` | Aktif üretimlerin (fabrika ve maden) birleştirilerek gösterilmesi sağlandı. |
| `company` | Güçlü | `88%` | Marka (Brand) sistemi genişletildi: Özel logolar/renkler, Marka XP takibi ve filigran sistemleri eklendi. |
| `warehouse` | Güçlü | `86%` | Depo hedefleri, kapasite ve transfer entegrasyonu stabil. |
| `store` | Çok Güçlü | `87%` | Performans ekranı 3 tab ile tamamen yenilendi. Rezerve alanı kaldırıldı; stok/kapasite gösterimi ve progress bar iyileştirildi. |
| `market` | Güçlü | `80%` | Sepet, mağaza deposuna sevkiyat ve ürün seçim akışları stabilize edildi. |
| `logistics` | Güçlü | `80%` | Rota filtreleri optimize edildi; transfer bitişine yıldızlı performans değerlendirmesi eklendi. |
| `transfer_map` | Orta-iyi | `75%` | Harita entegrasyonu ve araç görselleştirmeleri iyileştirildi. |
| `field` | Çok Güçlü | `86%` | Detay ekranı tamamen yeniden tasarlandı, zamanlanmış görev çalışma zamanı refaktör edildi. |
| `farm` | Çok Güçlü | `86%` | Detay ekranı tamamen yeniden tasarlandı, tarla modülü ile ortak standartlar kuruldu. |
| `factory` | Çok Güçlü | `88%` | Detay ekranları yenilendi, hammadde girdileri ve çıktı envanter geçiş kuralları standardize edildi. |
| `mine` | Çok Güçlü | `86%` | Detay ekranı yenilendi, maden çıkarma akışı stabil hale getirildi. |
| `arge` | Orta | `72%` | Sayfa tasarımı ve akışlar iyileştirildi, ancak oyun içi formüllerle daha derin entegrasyon bekliyor. |
| `mission` | Çok Güçlü | `88%` | Arayüz tamamen yenilendi. Haftalık görevler, haftalık sıfırlama mekanizması ve üretim görevleri (`product_produced` trigger'ı) backend entegrasyonuyla eklendi. |
| `notification` | İyi | `75%` | Lojistik ve bina inşaat bildirimleri stabil. |
| `achievement` | Güçlü | `80%` | Başarımların otomatik tetikleyicileri (üretim, satış vb.) veritabanına bağlandı. |
| `leaderboard` | Güçlü | `85%` | Leaderboard özelliği arayüze eklendi; Supabase RPC ve cron düzeltmeleri yapıldı. |
| `cash_flow` | Çok Güçlü | `85%` | Segment sekmeleri, trend çizgi grafiği ve kategori bazlı gelir-gider dökümleri eklenerek ekran tamamen yenilendi. |
| `production_report` | Orta | `72%` | Üretim verim ve maliyet raporları genel dashboard ile entegre edildi. |

## Planlama Önerisi

- Kısa vade hedefi: `%84 -> %88`
  - odak: `arge` derinliği, `market` stabilizasyonu ve lojistik edge-caseler.
- Orta vade hedefi: `%88 -> %92`
  - odak: late-game ekonomi dengesi ve çoklu şehir vergileri.
- Uzun vade hedefi: `%92+`
  - odak: parlatma (polish), sesler/müzikler ve live-ops optimizasyonları.
