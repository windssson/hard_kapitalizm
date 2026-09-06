# HARD KAPİTALİZM — OYUN MİMARİSİ VE TEKNİK REFERANS BELGESİ (GDD & TDD)

> **Sürüm:** 1.0.0  
> **Tarih:** 2026-09-03  
> **Durum:** Canlı / Üretim Mimarisi  
> **Kapsam:** Tüm İstemci (Flutter) ve Sunucu (Supabase PostgreSQL, Edge Functions, pg_cron, FCM) Modülleri

---

## 1. YÖNETİCİ ÖZETİ VE TEKNOLOJİ YIĞINI (TECH STACK)

**Hard Kapitalizm**, oyuncuların Türkiye'nin 81 ilinde şirket kurarak hammadde üretiminden lojistiğe, fabrikasyon işleme zincirinden perakende mağazacılığa, marka patentlemeden bankacılık ve devlet ihalelerine kadar uzanan derin ve gerçekçi bir serbest piyasa ekonomisi simülasyonudur.

### 1.1. Teknoloji Bileşenleri
* **Mobil İstemci:** Flutter SDK (Dart ^3.11.5)
  * **Durum Yönetimi:** `flutter_riverpod: ^3.3.1` (StateProvider, FutureProvider, NotifierProvider)
  * **Navigasyon & Yönlendirme:** `go_router: ^17.2.3` (Hiyerarşik rotalar, parametrik geçişler, observer)
  * **Responsive UI:** `flutter_screenutil: ^5.9.3` (390x844 baz tasarım boyutu)
  * **Veri İletişimi:** `supabase_flutter: ^2.12.4` (PostgREST, RPC, Realtime, Auth)
  * **Güvenli Depolama:** `flutter_secure_storage: ^10.3.1`, `shared_preferences`
  * **Bildirimler:** `firebase_core: ^3.2.0`, `firebase_messaging: ^15.0.3` (FCM)
  * **Monetizasyon / Reklam:** `google_mobile_ads: ^9.0.0` (Rewarded Ads ile süre kısaltma ve boost)
  * **Tipografi & Tasarım:** Inter Google Font, dinamik dark tema, özel endüstriyel ikonlar

* **Arka Plan (Backend) & Veritabanı:** Supabase Enterprise (PostgreSQL 17)
  * **İş Mantığı İzolasyonu:** PostgreSQL PL/pgSQL fonksiyonları (RPC - `SECURITY DEFINER`)
  * **Zamanlanmış Görevler:** `pg_cron` (14 aktif cron döngüsü: üretim, faiz, pazar dalgalanması, ihaleler, push bildirimler)
  * **Veri Güvenliği:** Row Level Security (RLS) politikaları; doğrudan tablo mutasyonları engellenmiş, tüm kritik işlemler RPC seviyesinde `FOR UPDATE` kilitleriyle atomik hale getirilmiştir.
  * **Sunucusuz Fonksiyonlar (Edge Functions):** Deno TypeScript (`send-push` servisi ile FCM v1 HTTP API entegrasyonu).

---

## 2. VERİTABANI TOPOLOJİSİ VE ÇEKİRDEK TABLOLAR

Sistem, ilişkisel bütünlüğü yüksek 40'tan fazla ana tablo üzerinde çalışır:

| Modül Grubu | Tablolar | Temel Sorumluluk |
|---|---|---|
| **Oyuncu & Profil** | `players`, `player_push_tokens`, `player_cash_ledger`, `player_company_value_history` | Oyuncu bakiyeleri (Nakit/Altın), seviye, XP, HQ şehir, anlık şirket değeri ve defter kayıtları. |
| **Statik Kataloglar** | `cities`, `products`, `game_settings`, `store_types`, `warehouse_types`, `factory_types`, `mine_types`, `farm_types`, `field_types`, `logistics_vehicle_types`, `logistics_company_types` | Oyunun parametrik tanımları, 81 il koordinat ve nüfusları, 194 ürün reçetesi, bina ve araç limitleri. |
| **Tesisler & Üretim** | `fields`, `farms`, `mines`, `factories`, `production_slots`, `production_inventory`, `building_constructions`, `building_upgrades`, `building_boosts`, `player_daily_production_stats` | Üretim birimleri, slotlar, giriş/çıkış hammadde siloları, inşaat, seviye yükseltme ve verim boostları. |
| **Depo & Perakende** | `warehouses`, `warehouse_slots`, `stores`, `store_slots`, `store_daily_performance` | Genel ve mağaza depoları, raf yönetimi, satış fiyatları, saatlik satış geçmişi ve doygunluk verileri. |
| **Lojistik & Filo** | `logistics_companies`, `logistics_vehicles`, `logistics_transfers`, `logistics_transfer_items`, `logistics_finance_entries` | Araç satın alımı, yakıt, yıpranma/tamir, seyahat süreleri, transfer manifestoları ve lojistik maliyet defteri. |
| **Pazar & B2B** | `product_price_history`, `player_product_quality_levels` | Depolardan satışa açılan slotlar, serbest pazar, günlük fiyat dalgalanması istatistikleri. |
| **Marka & Pazarlama** | `brand_companies`, `brand_company_products`, `brand_marketing_campaigns`, `player_product_brands` | Marka adı, logo, filigran, patent hakları, yerel/bölgesel/global reklam kampanyaları. |
| **İhale (Tender)** | `tenders`, `player_tenders`, `tender_bids`, `tender_deliveries` | Kamu/Özel sektör toplu tedarik ihaleleri, açık eksiltme teklifleri, çoklu nakliye ve teslimat takibi. |
| **Bankacılık & Vergi** | `player_loans`, `player_deposits`, `player_taxes` | Banka kredileri, taksit kesintileri, vadeli mevduat kilitleri, satış vergisi (KDV) ve haciz kilidi. |
| **Ar-Ge & Kalite** | `arge_centers`, `arge_researches` | Ar-Ge laboratuvarı, Q1'den Q5'e ürün kalite yükseltme araştırmaları ve süreleri. |
| **Sosyal & İletişim** | `chat_messages`, `direct_messages`, `chat_message_reports`, `player_notifications`, `player_alert_push_logs`, `player_leaderboard_stats` | Global sohbet, DM, ürün linkleme, operasyonel uyarılar ve genel/şehir liderlik sıralamaları. |
| **Görev & Başarım** | `mission_definitions`, `player_missions`, `achievement_definitions`, `player_achievements`, `player_experience_logs` | Ana/Günlük/Haftalık görevler, akıllı ilerleme tetikleyicileri, başarım kilitleri ve ödül teslimleri. |

---

## 3. ZAMANLANMIŞ ARKA PLAN MOTORU (PG_CRON ZAMANLAMA ÇİZELGESİ)

Oyunun yaşayan dünyası, PostgreSQL içerisinde çalışan cron işleri ile yönetilir:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                 PG_CRON GÖREV DAĞILIMI                                 │
├─────────────────────┬───────────────────┬──────────────────────────────────────────────┤
│ Program             │ Görev (Fonksiyon) │ Fonksiyonel Amacı                            │
├─────────────────────┼───────────────────┼──────────────────────────────────────────────┤
│ Her 15 Dakikada     │ complete_due_     │ Tamamlanma süresi dolan bina inşaatlarını    │
│ (*/15 * * * *)      │ building_         │ aktif hale getirir ve binaları teslim eder.  │
│                     │ constructions()   │                                              │
├─────────────────────┼───────────────────┼──────────────────────────────────────────────┤
│ Her 15 Dakikada     │ complete_due_     │ Yoldaki pazar ve konsolide lojistik          │
│ (*/15 * * * *)      │ market_transfers()│ transferlerini hedefe teslim eder, stok yazar│
├─────────────────────┼───────────────────┼──────────────────────────────────────────────┤
│ Her 30 Dakikada     │ complete_due_     │ Süresi dolan bina ve depo yükseltmelerini    │
│ (*/30 * * * *)      │ building_         │ tamamlar, kapasite ve çarpanları günceller.  │
│                     │ upgrades()        │                                              │
├─────────────────────┼───────────────────┼──────────────────────────────────────────────┤
│ Her 30 Dakikada     │ maintain_open_    │ Açık ihaleleri denetler, süresi dolanları    │
│ (*/30 * * * *)      │ tenders()         │ sonuçlandırır, eksikse yeni ihale üretir.    │
├─────────────────────┼───────────────────┼──────────────────────────────────────────────┤
│ Her 30 Dakikada     │ process_          │ Kritik durumdaki oyunculara (düşük yakıt,    │
│ (*/30 * * * *)      │ operational_      │ vergi riski, boşta üretim) push gönderir.    │
│                     │ alerts_push_      │                                              │
│                     │ notifications()   │                                              │
├─────────────────────┼───────────────────┼──────────────────────────────────────────────┤
│ Her Saat Başı       │ process_all_      │ Aktif üretim birimleri olan oyuncuların      │
│ (0 * * * *)         │ players_          │ hammadde tüketim ve çıktı üretimini işletir. │
│                     │ production()      │                                              │
├─────────────────────┼───────────────────┼──────────────────────────────────────────────┤
│ Her Saat Başı       │ complete_due_     │ Süresi dolan Ar-Ge araştırmalarını tamamlar, │
│ (0 * * * *)         │ arge_researches() │ oyuncunun ürün kalite seviyesini yükseltir.  │
├─────────────────────┼───────────────────┼──────────────────────────────────────────────┤
│ Her 4 Saatte        │ process_bank_     │ Banka kredi taksitlerini tahsil eder, vadesi │
│ (0 */4 * * *)       │ ticks()           │ dolan mevduatların ödemelerini serbest bırakır│
├─────────────────────┼───────────────────┼──────────────────────────────────────────────┤
│ Her 4 Saatte        │ update_product_   │ Pazardaki ürünlerin min/max/ort fiyat ve     │
│ (0 */4 * * *)       │ market_stats()    │ stok hacimlerini yeniden hesaplar.           │
├─────────────────────┼───────────────────┼──────────────────────────────────────────────┤
│ Her 12 Saatte       │ refresh_all_      │ Şirket değerleri üzerinden genel ve şehir    │
│ (0 */12 * * *)      │ leaderboard_      │ bazlı liderlik sıralama tablolarını yeniler. │
│                     │ stats()           │                                              │
├─────────────────────┼───────────────────┼──────────────────────────────────────────────┤
│ Her Gece 23:59      │ shift_daily_      │ Günlük pazar dalgalanması uygular (arz/talep │
│ (59 23 * * *)       │ product_prices()  │ bazlı fiyat kaymaları, geçmiş tablosuna yazım│
├─────────────────────┼───────────────────┼──────────────────────────────────────────────┤
│ Her Gece 23:59      │ record_daily_     │ Liderlik ve grafikler için günlük net şirket │
│ (59 23 * * *)       │ company_value_    │ değeri anlık görüntüsünü (snapshot) kaydeder.│
│                     │ snapshots()       │                                              │
├─────────────────────┼───────────────────┼──────────────────────────────────────────────┤
│ Her Gece 03:30      │ cleanup_          │ Eski bildirimleri, süresi geçmiş logları     │
│ (30 3 * * *)        │ database_bloat()  │ ve yetim kayıtları temizler.                 │
└─────────────────────┴───────────────────┴──────────────────────────────────────────────┘
```

---

## 4. OYUN DÖNGÜSÜ VE OYUNCU İLERLEME MEKANİKLERİ

### 4.1. Oturum Başlatma ve Bootstrap (`bootstrap_game_session`)
1. Kullanıcı Google veya E-posta ile giriş yapar.
2. `bootstrap_game_session` RPC çağrılır:
   * Oyuncu kaydı yoksa varsayılan değerlerle (`cash: 50,000 TL`, `gold: 50`, `level: 1`) oluşturulur.
   * Şehir seçimi (Headquarters) yapılmamışsa oyuncudan HQ şehir seçmesi istenir.
   * Görev ve başarım satırları senkronize edilir (`ensure_player_mission_rows`, `ensure_player_achievement_rows`).
   * Gecikmiş üretimler ve mağaza satışları anlık hesaplanır (Catch-up hesaplaması).

### 4.2. Seviye ve Deneyim (XP) Sistemi
* Seviye atlama formülü:
  $$\text{RequiredXP}(L) = \text{round}(100 \times L^{1.85})$$
* **XP Kazandıran Eylemler:**
  * Mağaza satışı gerçekleşmesi (satış hasılatına oranlı XP)
  * Fabrika/Tarla/Maden üretimi tamamlanması
  * Başarılı lojistik transfer tamamlama
  * Bina inşaatı ve yükseltmesi bitirme
  * Ar-Ge araştırması sonuçlandırma
  * İhale teslimatını başarıyla tamamlama

### 4.3. Şirket Değeri Değerleme Formülü (`calculate_player_company_value`)
Bir şirketin toplam net değeri 8 temel varlık kaleminin toplamı ile hesaplanır:
$$\text{Şirket Değeri} = \text{Nakit} + \text{Altın Değeri} + \text{Bina Baz Değerleri} + \text{Bina Yükseltme Harcamaları} + \text{Filo Değeri} + \text{Depo Stokları} + \text{Mağaza Stokları} + \text{Üretim Tesis Stokları}$$

* **Filo Değeri:** Aracın alış fiyatı ile mevcut kondisyon yüzdesinin çarpımıdır:
  $$\text{Araç Değeri} = \text{purchase\_price} \times \frac{\text{condition}}{100}$$
* **Stok Değerlemesi:** Mevcut adet $\times$ Ürünün baz satış fiyatı $\times$ Kalite çarpanı:
  $$\text{Stok Değeri} = \text{Adet} \times \text{baz\_satis\_fiyati} \times \text{store\_quality\_price\_multiplier}(\text{quality\_level})$$

---

## 5. MODÜL BAZINDA ÇALIŞMA PRENSİPLERİ VE KURALLAR

### 5.1. Tarla ve Çiftlik Modülü (Fields & Farms)
* **Veritabanı Karşılığı:**
  * `farm_types`: Bitkisel tarım alanları (Tahıl Tarlası, Sebze Tarlası, Meyve Bahçesi, Endüstriyel Tarım Alanı).
  * `field_types`: Hayvancılık tesisleri (Kümes Hayvancılığı, Küçükbaş Hayvan Çiftliği, Mandıra, Arıcılık, Su Ürünleri).
* **Mekanikler:**
  * Her tarla/çiftlikte slotlar bulunur (`production_slots`).
  * Slotlara tohum veya hayvan cinsi atanır (`assign_production_slot_product`).
  * Slotlar için saatlik üretim hacmi vardır.
  * Üretilen ürünler doğrudan tesisin çıkış envanterine (`production_inventory`) aktarılır.
  * Çıkış envanteri dolarsa üretim bloke olur (`warning_count` / `blocked_count`). Ürünler depoya transfer edilene kadar üretim durur.

### 5.2. Maden Modülü (Mines)
* **Maden Tipleri:** İnşaat & Taş Ocağı, Metal Maden Ocağı, Enerji & Kimya Kaynakları, Değerli & Stratejik Madenler.
* **Mekanikler:**
  * Şehir Rezerv Bonusu: Türkiye'deki her ilin maden türlerine göre özel verim çarpanı vardır (`cities.bonus_multiplier`). Örneğin Zonguldak'ta Kömür, Batman'da Petrol, Artvin'de Bakır rezerv bonusu sağlar.
  * Madende üretilen cevherler (Demir, Bakır, Kömür, Boksit, Lityum vb.) maden çıkış ambarına birikir.
  * Tıkanma Kuralı: Ambar dolduğunda maden çıkarma işlemi durur.

### 5.3. Fabrika ve İmalat Modülü (Factories)
* **Fabrika Tipleri:** Gıda İşleme, Fırın & Atıştırmalık, Tekstil, Mobilya & Kağıt, Kimya & Kozmetik, Ağır Sanayi & Metal, Beyaz Eşya, Elektronik & Yüksek Teknoloji, Otomotiv, Lüks & Aksesuar Atölyesi.
* **Girdi - Çıktı Zinciri (Reçeteler):**
  * Her ürün 0 ile 3 arasında farklı hammadde girdisine (`hammadde_1`, `hammadde_2`, `hammadde_3`) ve işçilik maliyetine (`iscilik_maliyeti`) sahiptir.
  * Fabrikanın iki ayrı ambarı vardır: **Girdi Ambarı (`input_capacity`)** ve **Çıktı Ambarı (`output_capacity`)**.
  * Üretimin başlayabilmesi için reçetedeki tüm girdilerin girdi ambarında bulunması şarttır.
  * Yetersiz girdi durumunda fabrika "Hammadde Bekleniyor" durumuna geçer; operasyonel bildirim üretilir.
  * Şehir Sanayi Bonusu: İlgili ilde teşvik veya sanayi altyapısı varsa üretim süresi kısalır ve verim artar.

### 5.4. Depolama Modülü (Warehouses)
* **Şehir Genel Depo Mimarisi:**
  * Eski sistemdeki yapay "Mağaza Özel Depoları" tamamen kaldırılmıştır.
  * Her ilde oyuncunun bir **Genel Depo**'su yer alır (15.000 m³ temel kapasite).
  * **Tek Depo Kuralı:** Bir şehirde en fazla **1 adet Genel Depo** bulunabilir (`start_building_construction`). İkinci depo inşası engellenmiştir; oyuncu kapasiteyi mevcut Genel Depo'yu yükselterek artırır.
  * **İşletme Ön Şartı:** Bir şehirde mağaza, fabrika veya tarımsal tesis kurabilmek için o şehirde aktif bir Genel Depo bulunması **zorunludur** (`GENEL_DEPO_GEREKLI`).
  * **Satış Koruma Kilidi:** Bir şehirde aktif işletmesi (mağaza, fabrika, tarla vb.) bulunan oyuncu, o ildeki son Genel Deposu'nu satamaz (`sell_building`). Önce işletmelerin tasfiyesi gerekir.
  * Şehirdeki tüm mağazalar, fabrikalar, tarlalar, çiftlikler ve madenler ürün giriş ve çıkışlarını doğrudan bu yerel Genel Depo üzerinden yürütür.
* **Kapasite ve Birim Hacim:**
  * Her ürünün metreküp cinsinden birim hacmi (`birim_hacim`) ve ağırlığı (`birim_agirlik`) vardır.
  * Depodaki toplam doluluk: $\sum (\text{Adet} \times \text{birim\_hacim})$.
  * Depo kapasitesi aşılacak şekilde transfer başlatılamaz.
* **Depo Kataloğu:**
  * İnşaat kataloğunda sadece **Genel Depo** (15.000 m³, 20.000 TL) listelenir; eski 0 TL'lik mağaza depoları filtrelenmiştir (`get_warehouse_types_catalog`).
* **Satışa Açma Mekanizması:**
  * Oyuncu genel depodaki slotları "Pazara Aç" olarak işaretleyip birim satış fiyatı belirleyebilir (`set_warehouse_slot_sale_status`, `set_warehouse_slot_price`).
  * Bu slotlar Pazar Yerinde diğer oyuncuların satın alabileceği B2B ilanlarına dönüşür.

### 5.5. Perakende Mağazacılık Modülü (Stores)
* **Mağaza Tipleri:** Büfe, Manav, Market, Fırın, Kasap, Kuruyemişçi, Süpermarket, Tekstil, Mobilya, Kozmetik, İnşaat Malzemeleri, Beyaz Eşya, Teknoloji, Kuyumcu, Oto Galeri.
* **Şehir Genel Depo Entegrasyonu:**
  * Mağazaların kendisine ait bağımsız fiziksel deposu yoktur; mağazanın bulunduğu şehirdeki **Genel Depo** kullanılır.
  * Mağaza inşaatı için o şehirde aktif bir Genel Depo'nun bulunması ön şarttır (`start_building_construction`).
* **Raf Yönetimi (`store_slots`):**
  * Raflar doğrudan o ildeki Genel Depo slotlarından beslenir (`fill_store_shelves`, `transfer_store_warehouse_slot_to_store_slot`).
  * Raftan kaldırılan veya satışı iptal edilen ürünler anında şehrin Genel Deposu'na iade edilir (`transfer_store_slot_to_store_warehouse`).
  * Raftaki ürünün birim perakende satış fiyatı belirlenir.
* **Şehir Doygunluk Mekaniği (`calculate_store_saturation_multiplier`):**
  * İlin nüfusu (`population`) ve mağaza türüne göre ideal mağaza kapasitesi hesaplanır (Örn: Büfe için her 50.000 kişiye 1 büfe, Oto Galeri için her 500.000 kişiye 1 galeri).
  * $\text{Doygunluk Oranı} = \frac{\text{Şehirdeki Aktif Mağaza Sayısı}}{\text{İdeal Kapasite}}$
  * **Doygunluk Eğrisi:**
    * Oran $\le 0.0$: **1.30x** (%30 Bakir Pazar Satış Bonusu)
    * Oran 0.0 - 0.5: **1.30x $\to$ 1.15x** (Fırsat Bölgesi)
    * Oran 0.5 - 1.0: **1.15x $\to$ 1.00x** (Dengeli Piyasa)
    * Oran 1.0 - 2.0: **1.00x $\to$ 0.60x** (Yüksek Rekabet / Satış Yavaşlaması)
    * Oran $> 2.0$: **0.50x** (Aşırı Doygunluk Tabanı)
* **Talep ve Fiyat Esnekliği Formülü:**
  * Ürünün baz fiyatı, kalite çarpanı ve marka toleransı ile karşılaştırılır:
    $$\text{Price Ratio} = \frac{\text{Oyuncunun Belirlediği Fiyat}}{\text{baz\_satis\_fiyati} \times \text{store\_quality\_price\_multiplier} \times \text{brand\_tolerance}}$$
  * Fiyat baz fiyattan yüksekse satış hızı düşer; düşükse satış hızlanır.
* **Satış Vergisi (KDV):** Mağazada gerçekleşen her perakende satıştan vergi borcu tahakkuk eder ve `player_taxes` tablosuna eklenir.

### 5.6. Lojistik, Filo ve Transfer Haritası (Logistics)
* **Model A Mimarisi (Katı Depo Merkezli Lojistik):**
  * **Şehirler Arası Sevkiyat Kuralı:** Araçlı ve sefer bazlı şehirler arası lojistik transferler **YALNIZCA Genel Depo $\leftrightarrow$ Genel Depo** arasında yürütülür.
  * **Üretim Birimleri Yerel Depo Kuralı:** Bir üretim tesisi (Fabrika, Tarla, Çiftlik, Maden) yalnızca bulunduğu şehirdeki Genel Depo ile doğrudan transfer yapabilir. Başka şehirdeki bir depoya doğrudan ürün göndermesi veya uzak bir depodan hammadde çekmesi sistem tarafından engellenmiştir.
  * **Şehir İçi Anında Transfer:** Bir şehirdeki üretim birimi ile o şehrin Genel Deposu arasındaki tüm hammadde ve nihai ürün transferleri araç gerektirmez ve anında (`instant`) tamamlanır.
  * **Mağaza Lojistiği:** Mağazalar şehirler arası kargo kabul etmez; raflar yalnızca aynı şehirdeki Genel Depo'dan beslenir. Başka şehirden gelen ürünler önce ilin Genel Deposu'na indirilir.
* **Araç Tipleri ve Teknik Özellikleri:**
  | Araç Adı | Kapasite | Hız | Yakıt Deposu | Tüketim (L/km) | Fiyat (TL) | NPC Kiralama (TL/km) |
  |---|---|---|---|---|---|---|
  | **Ekspres Kamyonet** | 12 | 120 km/s | 80 L | 0.03 L | 150.000 | 3.0 TL |
  | **Elektrikli Dağıtım**| 22 | 100 km/s | 180 kWh| 0.01 kW| 450.000 | 5.0 TL |
  | **Ağır Yük Kamyonu** | 35 | 90 km/s | 250 L | 0.07 L | 650.000 | 9.0 TL |
  | **Uzun Yol TIR'ı** | 55 | 80 km/s | 450 L | 0.11 L | 1.200.000 | 15.0 TL |
* **Konsolide Şehir Transferi (`start_city_consolidated_transfer`):**
  * Bir ildeki birden fazla tesisten (Fabrika, Tarla, Çiftlik, Depo) farklı ürünleri tek bir araca yükleyip hedef tesise (Genel Depo veya Fabrika Girdi Deposu) toplu taşıma imkanı sağlar.
  * Mesafe Formülü: 81 ilin enlem-boylam koordinatları üzerinden Haversine mesafe algoritması kullanılır.
  * Süre: $\text{duration\_seconds} = \text{round}\left(\frac{\text{Mesafe (km)}}{\text{Hız (km/s)}} \times 3600\right)$ (Şehir içi transferler anında teslim edilir).
  * Yakıt & Aşınma: Transfer tamamlandığında araç yakıtı tüketilir ve araç kondisyonu belirli oranda düşer. Kondisyonu %20'nin altına inen araç arızalanır ve tamir edilmeden sefere çıkamaz.
* **Kiralık Filo Mekanizması:** Oyuncular kendi araçlarını sisteme kiralık olarak tahsis edebilir. Diğer oyuncular transfer yaptığında araç sahibine kiralama bedeli ödenir.

### 5.7. B2B Pazar Yeri Modülü (Marketplace)
* **Çalışma Prensibi:**
  * Oyuncular ve NPC şirketleri, Genel Depolarındaki ürün slotlarını satışa açarak (`set_warehouse_slot_sale_status`, `set_warehouse_slot_price`) pazara sunarlar.
  * Alıcı oyuncu, ilan listesinden ürünü seçip kendi şehrindeki **Genel Depo**'ya teslim edilmek üzere satın alır (`start_multi_market_transfer`).
  * Şehir içi alımlarda transfer anında (`instant`) tamamlanır; şehirler arası alımlarda ise rota araç seçenekleri (`get_route_transfer_vehicle_options`) ile nakliye aracı seçilerek transfer başlatılır (`in_transit`).
  * Ücret anında alıcının kasasından kesilir; nakliye aracı teslimatı gerçekleştirdiğinde ürünler alıcının Genel Depo slotlarına eklenir ve satıcı oyuncunun kasasına satış bedeli aktarılır.
* **Teslimat Hedefi Kuralları:**
  * Pazardan yapılan tüm satın alımlar yalnızca oyuncunun aktif **Genel Depolarına** yapılabilir.
  * Mağaza depoları kaldırıldığı için arayüzde mağaza deposu seçimi ve filtre çipleri yer almaz.
  * İhtiyaç hesaplamalarında (`_calculateStoreNeeds`), seçili Genel Deponun bulunduğu şehirdeki tüm aktif mağazaların raf eksikleri otomatik toplanır.
* **Piyasa Fiyat Kayması (`shift_daily_product_prices`):**
  * Her gece 23:59'da pazar istatistiklerine göre ürünlerin min, max ve taban fiyatları arz/talep dengesine göre güncellenir.

### 5.8. Marka, Patent ve Pazarlama Modülü (Brand & Marketing)
* **Marka Şirketi:** Oyuncu belirli bir seviyeye ulaştığında kendi marka şirketini kurabilir (`create_brand_company`). Marka adı, amblem ve logo rengi seçilir.
* **Ürün Patenti:** Markaya bağlanan ürünler için patent harcı ödenir (`patent_brand_company_product`).
* **Pazarlama Kampanyaları:**
  * **Yerel Kampanya:** Satış hızı +%15, fiyat toleransı +%5.
  * **Bölgesel Kampanya:** Satış hızı +%30, fiyat toleransı +%10.
  * **Ulusal/Global Kampanya:** Satış hızı +%50, fiyat toleransı +%20.
* **Marka Fiyat Toleransı (Tüketici Sadakati):** Markalı ürünlerde tüketici toleransı **1.25x** çarpanına yükselir. Yani oyuncu ürünü baz fiyattan %25 daha pahalıya satsa bile talep düşüşü yaşamaz.

### 5.9. Ar-Ge ve Kalite Seviyesi Modülü (R&D & Quality)
* **Ar-Ge Merkezi:** Kurulum maliyeti 25.000 TL olan özel araştırma laboratuvarı.
* **Kalite Seviyeleri (Q1 $\to$ Q5):**
  * **Q1:** 1.00x Çarpan (Standart)
  * **Q2:** 1.10x Çarpan (%10 Değer Artışı)
  * **Q3:** 1.22x Çarpan (%22 Değer Artışı)
  * **Q4:** 1.35x Çarpan (%35 Değer Artışı)
  * **Q5:** 1.50x Çarpan (%50 Maksimum Değer ve İtibar)
* **Hammadde Kalite Kuralı:** Yüksek kaliteli bir ürün üretebilmek için kullanılan hammaddelerin de en az o kalite seviyesinde olması gerekir. Kalitesiz hammadde ile yüksek kalite nihai ürün üretilemez.

### 5.10. Bankacılık ve Vergi Modülü (Banking & Taxation)
* **Banka Kredisi (`take_loan`):**
  * Kredi Limiti: $\text{Oyuncu Seviyesi} \times 25.000\text{ TL}$.
  * Vade ve Faiz Seçenekleri:
    * 6 Taksit: %5 Faiz
    * 12 Taksit: %12 Faiz
    * 24 Taksit: %28 Faiz
    * 36 Taksit: %45 Faiz
  * Her 4 saatte bir taksit miktarı otomatik olarak oyuncunun nakit bakiyesinden tahsil edilir.
* **Vadeli Mevduat (`create_deposit`):**
  * Belirli bir süre kilitlenen mevduata vade bitiminde faiz getirisi ödenir. Erken çekim durumunda faiz hakkı kaybedilir.
* **Vergi Borcu ve Haciz Kilidi (`is_player_tax_blocked`):**
  * Oyuncu seviyesine göre vergi borcu üst limitleri belirlenmiştir:
    * Seviye 1: 10.000 TL
    * Seviye 2: 25.000 TL
    * Seviye 3: 50.000 TL
    * Seviye 4: 100.000 TL
    * Seviye 5: 250.000 TL
    * Seviye 6: 500.000 TL
    * Seviye 7+: $\text{Seviye} \times 200.000\text{ TL}$
  * **Haciz Kilidi Kuralı:** Eğer oyuncunun vergi borcu limitini aşarsa `is_player_tax_blocked = true` olur. Oyuncunun tüm fabrikaları, tarlaları, madenleri ve transferleri durdurulur (dondurulur). Vergi dairesine borç ödenene kadar şirket faaliyette bulunamaz.

### 5.11. İhale Modülü (Tender System - B2G & B2B)
* **İhale Türleri:** Kamu kurumları (Hastaneler, Belediyeler, Devlet Demiryolları vb.) veya özel holdingler tarafından açılan yüksek hacimli ürün tedarik ihaleleri.
* **Açık Eksiltme (Lowest Bid):** İhaleye teklif veren oyuncular arasında en düşük birim fiyatı teklif eden oyuncu ihale süresi bittiğinde ihaleyi kazanır.
* **Teslimat Süreci:**
  * İhale kazanıldığında teslimat süresi başlar.
  * Oyuncu kendi depolarından araçlarla teslimat adresine nakliye başlatır (`start_tender_delivery`).
  * Teslimat parçalı yapılabilir. Süre dolduğunda taahhüt edilen miktarın tamamı teslim edilmemişse teminat yanar ve ceza kesilir.

### 5.12. İnşaat, Yükseltme ve Boost Kataloğu (Upgrades & Boosts)
* **Merkezi Yükseltme Kataloğu:**
  * `building_upgrade_definitions` ve `building_upgrade_effects` üzerinden yönetilir.
  * Etki Metrikleri:
    * `output_capacity` (Çıkış ambarını çarpımsal artırma)
    * `input_capacity` (Girdi ambarını çarpımsal artırma)
    * `store_max_slot_count` (Mağaza raf sayısını artırma)
    * `store_slot_capacity` (Raf ürün limitini artırma)
    * `warehouse_capacity` (Depo metreküp kapasitesini artırma)
* **Tekil Global Yükseltme Kuralı (Single Global Upgrade Lock):** Bir oyuncunun aynı anda sadece 1 adet aktif bina yükseltmesi devam edebilir. Başka bir yükseltme başlatabilmek için mevcut olanın bitmesi veya hızlandırılması gerekir.
* **Bina Boostları:** Belirli süre boyunca bina üretim hızını %25-%50 artıran geçici verimlilik dopingleri.

### 5.13. Bildirim ve Operasyonel Uyarı Sistemi (Alerts & Notifications)
* **Operasyonel Uyarı Mantığı:**
  * Sistem oyuncunun şirketini tarar:
    1. Yakıtı azalan araçlar (%15 altı)
    2. Girdisi bittiği için duran fabrikalar
    3. Çıkış ambarı dolduğu için tıkanan tarlalar/madenler
    4. Vadesi yaklaşan kredi ve vergi haciz riski
  * Bu durumlar hem oyun içi bildirim merkezinde gösterilir hem de `pg_cron` aracılığıyla her 30 dakikada bir filtrelenerek FCM Push Bildirimi olarak kullanıcının telefonuna iletilir.

### 5.14. Sosyal, Chat ve Liderlik Modülü (Social)
* **Global Sohbet:** 1000 karaktere kadar mesajlaşma, küfür ve argo filtreleme (`filter_profanity_text`).
* **Ürün Linkleme:** Mesaj içerisinde `[p:urun_id]` formatında ürün etiketi eklendiğinde mesaj kartında tıklanabilir ürün önizlemesi belirir, tıklandığında doğrudan pazar yerine yönlendirir.
* **Liderlik Tablosu:** Şirket net değeri baz alınarak Genel Türkiye Sıralaması ve İller Bazında Şehir Şampiyonları listelenir.

---

## 6. FLUTTER İSTEMCİ (CLIENT) MİMARİSİ VE STANDARTLARI

### 6.1. Dizin ve Katman Yapısı
Proje, her biri kendi veri, model ve arayüz mantığını barındıran Feature-First mimarisiyle yapılandırılmıştır:
```
lib/
├── core/
│   ├── ads/              # Reklam servisleri (Rewarded Ads)
│   ├── constants/        # Sabitler (Supabase URL, Anon Key, Renk kodları)
│   ├── managers/         # AssetManager, AuthManager, SessionManager
│   ├── models/           # Ortak modeller (CityModel, ProductModel vb.)
│   ├── navigation/       # AppRouteObserver, Route yönlendiricileri
│   ├── providers/        # Genel Riverpod provider'ları (TimeProvider vb.)
│   ├── theme/            # AppTheme, AppColors, TextStyle tanımları
│   └── widgets/          # Ortak UI bileşenleri (BuildingTypeSelection, TutorialOverlay, TimedTaskRuntime)
└── features/
    ├── home/             # Ana sayfa paneli, özet kartlar, hızlı butonlar
    ├── store/            # Mağazalar, mağaza detayı, performans grafikleri, raf yönetimi
    ├── warehouse/        # Depolar, depo slotları, kapasite barları, pazar satış ayarları
    ├── factory/          # Fabrika listesi, üretim hatları, reçeteler, ambarlar
    ├── field/            # Hayvancılık tesisleri, slotlar, hayvan bakımı
    ├── farm/             # Tarım alanları, mahsul ekimi, hasat
    ├── mine/             # Maden ocakları, cevher çıkarımı, şehir rezerv bonusları
    ├── logistics/        # Filo listesi, araç satın alımı, yakıt ikmali, tamir, kiralama
    ├── transfer_map/     # Transfer haritası, konsolide transfer bottom sheet, rota planlama
    ├── market/           # B2B pazar yeri, filtreleme, satın alma akışı, fiyat geçmişi
    ├── company/          # Şirket profili, marka şirketi kurma, logo tasarımı, kampanyalar
    ├── arge/             # Ar-Ge merkezi, araştırma ağacı, kalite seviyeleri
    ├── bank/             # Kredi çekme/ödeme, vadeli mevduat açma
    ├── tax/              # Vergi dairesi, borç sorgulama, borç ödeme
    ├── tender/           # İhale merkezi, teklif verme, teslimat lojistiği
    ├── mission/          # Günlük ve ana görevler, ödül toplama
    ├── achievement/      # Başarımlar vitrini, kupa ve ödüller
    ├── leaderboard/      # Genel ve şehir bazlı holding sıralamaları
    ├── chat/             # Genel sohbet odası, DM, ürün linkleme, şikayet
    ├── notification/     # Oyun içi bildirimler ve operasyonel uyarı merkezi
    ├── cash_flow/        # Kasa defteri, gelir-gider dökümleri
    ├── production_report/# Tesis bazlı günlük üretim raporları
    ├── premium/          # Altın mağazası, destek paketleri
    ├── auth/             # Giriş yapma, kayıt olma, Google Sign-in, profil düzenleme
    └── splash/           # Başlangıç ekranı, versiyon kontrolü, bootstrap
```

### 6.2. Durum Yönetimi (Riverpod) Kuralları
1. **İzolasyon:** Her feature kendi data dizini altında provider'larını barındırır (Örn: `home_dashboard_provider.dart`, `store_detail_provider.dart`).
2. **Mutasyon Sonrası Yenileme:** Bir işlem yapıldığında (örneğin konsolide transfer başlatıldığında veya raf fiyatı güncellendiğinde) ilgili provider `ref.invalidate()` veya `ref.refresh()` edilerek yerel state arka plan ile anında eşitlenir.
3. **TimedTaskRuntime Entegrasyonu:** Zaman sayaçları (inşaat, yükseltme, lojistik transfer) `TimedTaskRuntime` ve `timeProvider` üzerinden merkezi bir kalp atışı (heartbeat) ile saniye saniye güncellenir; her widget için ayrı periyodik timer başlatılmaz.

---

## 7. YENİ ÖZELLİK EKLEME VE GELİŞTİRME KILAVUZU

Gelecekte projeye yeni bir mekanik, modül veya güncelleme ekleneceğinde aşağıdaki akış izlenmelidir:

```
┌────────────────────────────────────────────────────────────────────────┐
│               YENİ ÖZELLİK GELİŞTİRME KONTROL LİSTESİ                  │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Veritabanı Değişikliği (Supabase Migration):                        │
│    - Tablo veya kolon eklemesi yap.                                    │
│    - RLS politikalarını tanımla (public doğrudan mutasyona kapalı).    │
│    - İş mantığını atomik PL/pgSQL RPC fonksiyonu olarak yaz.           │
│    - Gerekli yerlerde 'FOR UPDATE' kilidi kullan.                      │
│    - Varsa ilgili 'pg_cron' işini kaydet veya güncelle.               │
│                                                                        │
│ 2. Flutter Veri Modeli (Dart Model):                                   │
│    - 'lib/features/<modul>/models/' altında model sınıfını oluştur.     │
│    - 'fromJson' ve 'toJson' metotlarında null-safety ve tip güvenliğini│
│      sağla.                                                            │
│                                                                        │
│ 3. State & Provider Tanımı:                                            │
│    - 'lib/features/<modul>/data/' altında Riverpod provider'ını tanımla│
│    - Supabase RPC çağrısını gerçekleştir.                              │
│                                                                        │
│ 4. Kullanıcı Arayüzü (UI Screens & Widgets):                           │
│    - 'AppTheme', 'AppColors' ve 'ScreenUtil' standartlarına uy.        │
│    - Hata, yükleme ve boş durum (empty state) ekranlarını eksiksiz yaz.│
│    - GoRouter yönlendirmesini 'lib/main.dart' içine kaydet.            │
│                                                                        │
│ 5. Şirket Değeri / Görev / Bildirim Senkronizasyonu:                   │
│    - Yeni varlık/gelir şirkete değer katıyorsa                         │
│      'calculate_player_company_value' fonksiyonunu güncelle.           │
│    - Görev ilerlemesi sağlıyorsa görev tetikleyicisini bağla.          │
│    - Kritik bir durum oluşturuyorsa operasyonel uyarı ekle.            │
│                                                                        │
│ 6. Dokümantasyon Güncellemesi:                                         │
│    - Bu mimari dosyasındaki ilgili bölümleri güncelle.                 │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 8. SIKI PROJE VE GİTHUB KURALLARI

1. **GitHub Push Kuralı:** Kullanıcı açıkça talep etmedikçe veya onay vermedikçe kesinlikle GitHub'a (`git push` / yedekleme) işlem yapılmaz. Her zaman kullanıcının net onayı beklenir.
2. **Canlı Veritabanı Saygısı:** Veritabanında yapılacak tüm şema değişiklikleri geriye dönük uyumlu olmalı ve aktif oyun oturumlarını bozmayacak şekilde migrasyon dosyaları halinde uygulanmalıdır.
