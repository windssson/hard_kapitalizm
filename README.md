# Hard Kapitalizm

Hard Kapitalizm, Flutter ve Supabase ile geliştirilen, derin ekonomi simülasyonu ve zengin strateji mekaniklerine sahip bir mobil tycoon / holding yönetimi oyunudur. Oyuncu; 81 ilde holding merkezini kurar, marka şirketi açar, üretim tesisleri ve depolar inşa eder, mağaza zincirleri yönetir, lojistik filoları yönlendirir, serbest pazarda ticaret yapar, bankacılık ve vergi operasyonlarını yürütür, ihalelere katılır ve liderlik tablosunda zirveye yükselir.

Bu README, aktif `redesign` branch'inin en güncel mimarisini ve geliştirme durumunu özetler.

## Oyun Döngüsü

```text
Oyuncu 81 il arasından Holding Merkez Şehrini seçer & kayıt olur
→ Marka şirketini kurar, logo/tema belirler ve ürünleri patentler
→ Tarlalar, çiftlikler, madenler veya fabrikalar kurarak üretim başlatır
→ Depo ve lojistik araçlarıyla ürünleri şehirlerarası taşır
→ Mağazalar açarak halka perakende satış yapar ve ciro/marka XP kazanır
→ Serbest pazarda diğer oyuncularla alım-satım yapar, ihalelere teklif verir
→ Banka mevduat/kredi işlemlerini ve şehir vergilerini yönetir
→ Ar-Ge ile ürün kalite seviyelerini yükseltip holding değerini ve lig sıralamasını artırır
```

## Güncel Ana Sistemler

- **81 İl & Merkez Şehir Sistemi:** Oyuncunun holding ana merkez üssünü belirlediği ve şehir nüfus/vergi dinamiklerine göre strateji geliştirdiği yapı.
- **Native Google Sign-In & Oturum:** Google Play Services / iOS yerel kimlik doğrulama, tek tıkla şifresiz giriş ve profil senkronizasyonu.
- **Marka Şirketi Sistemi:** Oyunun ana ilerleme omurgasıdır. Oyuncu kendi markasını kurar, logo/tema seçer, marka seviyesi ve marka XP kazanır, ürünleri portföyüne patentler ve pazarlama kampanyaları yürütür.
- **İnteraktif Oyun Öğreticisi (Tutorial):** Yeni başlayan oyunculara rehberlik eden, asistan karakteri ve spotlight vurgularıyla adım adım fabrikatörlük temellerini öğreten overlay sistemi.
- **Banka & Finans Sistemi (`/bank`):** Nakit ihtiyacı için farklı vadelerde ticari kredi çekme, boşta duran parayı vadeli mevduata yatırıp faiz geliri elde etme ve erken çekim cezası hesaplamaları.
- **Vergi & Maliye Sistemi (`/tax`):** Şehir bazlı yerel hasılat vergileri, vergi borcu takibi, ödenmeyen vergilerde temerrüt ve operasyonel bloke mekanizması.
- **İhale Merkezi (`/tenders`):** Düzenli aralıklarla açılan kamu/belediye ihalelerine teklif verme, kazanılan ihalelerin ürün teslimatlarını lojistikle tamamlama ve yüksek prestij/nakit ödülleri.
- **Liderlik Tablosu (`/leaderboard`):** Şirket piyasa değeri, günlük ciro ve üretim hacmine göre tüm holdinglerin canlı sıralandığı rekabet tablosu.
- **Canlı Sohbet & İletişim (`/chat`):** Global ticaret sohbeti, oyuncular arası anlık mesajlaşma ve mesaj raporlama sistemi.
- **Üretim Tesisleri:** Tarla, çiftlik, fabrika ve maden modülleri; input/output hammadde ve mamul ürün envanteri, slot yönetimi, kalite seviyesi ve marka tercihi.
- **Depo Sistemi:** Tüm genel ve mağaza depolarının tek ekranda toplandığı, m³ hacim ve kalite/maliyet takipli akıllı stok yönetimi.
- **Mağaza & Perakende:** Mağaza zincirleri, slot yönetimi, dinamik fiyatlandırma, mağaza deposu, pull-based satış işleme ve günlük ciro/kâr raporları.
- **Lojistik & Multi Transfer:** Şehirden şehre rota bazlı araç seçimi, tek seferde çoklu ürün (multi-item) transferi, yakıt/kondisyon yönetimi ve transfer haritası.
- **Serbest Pazar (Market):** Oyuncuların kendi ürettikleri markalı/markasız malları satışa sunduğu, fiyat grafiği ve satıcı satış bildirimli canlı pazar yeri.
- **Ar-Ge & Kalite:** Ürünlerin kalite yıldızlarını (Q1-Q5) yükselten teknoloji araştırmaları ve hızlandırma seçenekleri.
- **Görev & Başarım Sistemi:** Ana/yan görevler, günlük seri (daily streak), ödül talepli başarımlar ve XP ilerlemesi.
- **Push Bildirim & Uyarılar:** Firebase (FCM) ve Supabase Realtime destekli anlık transfer, pazar satışı, ihale ve üretim bildirimleri.

## Teknolojiler

| Alan | Teknoloji | Açıklama |
| --- | --- | --- |
| Mobil Framework | Flutter (3.x) | Çoklu platform mobil mimarisi |
| Programlama Dili | Dart | Güçlü tip güvenliği ve asenkron yapı |
| State Management | Riverpod (2.x) | Reaktif, test edilebilir ve scoped durum yönetimi |
| Routing | GoRouter | Deklaratif rota yönetimi ve derin bağlantılar |
| Backend & Auth | Supabase | PostgreSQL tabanlı BaaS, Native Google OAuth |
| Push Bildirimleri | Firebase (FCM) + Supabase Realtime | Anlık arka plan ve ön plan bildirimleri |
| Veritabanı | PostgreSQL (PLpgSQL) | ACID uyumlu, RPC saklı yordamlar ve tetikleyiciler |
| Depolama (Storage) | Supabase Storage | Oyun asset'leri ve görsel barındırma |
| Yerel Depolama | Shared Preferences / Secure Storage | Güvenli token ve ayar önbelleği |
| Reklam Altyapısı | Google Mobile Ads | Ödüllü transfer hızlandırma reklamları |
| Ekran Ölçekleme | flutter_screenutil | Farklı ekran boyutlarına uyumlu responsive UI |
| Haptic Feedback | flutter/services | Premium dokunsal geri bildirim motoru |

## Proje Yapısı

```text
lib/
  core/
    constants/        # Supabase, asset ve oyun sabitleri
    data/             # Katalog, lojistik ve ortak servisler
    managers/         # Auth, asset ve session yöneticileri
    models/           # Ortak veri modelleri (Şehir, Ürün vb.)
    navigation/       # Rota gözlemcileri ve yardımcıları
    providers/        # Genel uygulama provider'ları
    theme/            # Renkler, tipografi ve oyun tema sistemi
    utils/            # Para, haptic, snackbar ve tarih formatlayıcıları
    widgets/          # BottomNav, TopBar, TutorialOverlay ve ortak bileşenler
  features/
    achievement/      # Başarım listesi, ilerleme ve ödül talebi
    arge/             # Ürün kalite yükseltme araştırmaları
    auth/             # Giriş/Kayıt, Google Auth ve Profil yönetimi
    bank/             # Kredi çekme, vadeli mevduat ve faiz motoru
    cash_flow/        # Kasa defteri ve gelir-gider geçmişi
    chat/             # Canlı global ticaret sohbeti ve raporlama
    company/          # Marka şirketi, logo, patent ve pazarlama
    factory/          # Fabrika inşa, reçeteli üretim ve envanter
    farm/             # Çiftlik inşa, besleme ve hayvansal üretim
    field/            # Tarla inşa, ekim, gübreleme ve hasat
    home/             # Ana kontrol paneli, şirket özeti ve bildirimler
    leaderboard/      # Şirket değeri ve ciro bazlı canlı sıralama
    logistics/        # Filo yönetimi, araç kiralama ve transferler
    market/           # Serbest pazar, anlık alım-satım ve fiyat grafiği
    mine/             # Maden çıkarma, kapasite ve sevkiyat
    mission/          # Ana/günlük görevler ve günlük seri ödülleri
    notification/     # Sistem bildirimleri, uyarılar ve push logları
    premium/          # Altın mağazası ve özel avantajlar
    production_report/# Tesis bazlı detaylı üretim ve maliyet raporu
    splash/           # Başlangıç önbellekleme ve oturum yönlendirme
    store/            # Perakende mağazalar, slotlar ve satış motoru
    tax/              # Şehir hasılat vergileri ve temerrüt yönetimi
    tender/           # Kamu ihaleleri, teklif verme ve teslimat
    transfer_map/     # Canlı lojistik haritası ve araç takibi
    warehouse/        # Birleşik depo ağı, m³ hacim ve stok slotları
  main.dart

assets/
  icons/
  images/
  theme/

supabase/
  *.sql               # Veritabanı migration ve RPC fonksiyonları
```

## Uygulama Rotaları

Ana route'lar `lib/main.dart` içindeki GoRouter yapılandırmasında tutulur:

```text
/                                   → Splash & Ön Yükleme Ekranı
/auth                               → Giriş & Kayıt (E-posta + Native Google)
/home                               → Ana Yönetim Paneli
/profile                            → CEO Profili & Hesap Güvenlik Ayarları
/company                            → Marka Şirketi & Patentli Ürünler

/bank                               → Bankacılık, Krediler & Vadeli Mevduat
/tax                                → Vergi Dairesi & Şehir Vergileri
/tenders                            → İhale Merkezi
/tenders/:id                        → İhale Detayı, Teklif Verme & Teslimat
/leaderboard                        → Canlı Liderlik Tablosu & Lig Sıralaması
/chat                               → Canlı Global Ticaret Sohbeti
/premium                            → VIP & Altın Mağazası

/store                              → Mağaza Zinciri Listesi
/store/new/city                     → Yeni Mağaza Şehir Seçimi
/store/new/type                     → Mağaza Tipi & Konsept Seçimi
/store/:id                          → Mağaza Detayı, Slotlar & Satış Paneli
/store/:id/history                  → Mağaza Satış Geçmişi
/store/:id/report                   → Günlük Perakende Performans Raporu
/store/:id/warehouse                → Mağaza Ek Depo Yönetimi

/warehouses                         → Birleşik Depo Ağı Listesi
/warehouses/new/city                → Depo Şehir Seçimi
/warehouses/new/type                → Depo Tipi Seçimi
/warehouses/:id                     → Depo Detayı, Stok Slotları & Satışa Açma
/warehouses/:id/history             → Depo Giriş/Çıkış Hareket Geçmişi

/fields                             → Tarla Tesisleri Listesi
/fields/new/city                    → Tarla Şehir Seçimi
/fields/new/type                    → Tarla Tipi Seçimi
/fields/:id                         → Tarla Detayı, Ekim & Hasat Yönetimi

/farms                              → Hayvancılık Çiftlikleri Listesi
/farms/new/city                     → Çiftlik Şehir Seçimi
/farms/new/type                     → Çiftlik Tipi Seçimi
/farms/:id                          → Çiftlik Detayı, Yemleme & Üretim

/factories                          → Sanayi Fabrikaları Listesi
/factories/new/city                 → Fabrika Şehir Seçimi
/factories/new/type                 → Fabrika Tipi Seçimi
/factories/:id                      → Fabrika Detayı, Hammadde & Üretim Slotları

/mines                              → Maden Ocakları Listesi
/mines/new/city                     → Maden Şehir Seçimi
/mines/new/type                     → Maden Tipi Seçimi
/mines/:id                          → Maden Detayı & Cevher Çıkarma

/logistics                          → Lojistik Şirketi & Filo Yönetimi
/logistics/setup                    → Lojistik Şirketi Kurulumu
/logistics/finance                  → Filo Gelir-Gider Finans Raporu
/transfer-map                       → Canlı Lojistik Haritası & Rota Takibi

/market                             → Serbest Pazar Yeri
/market/:productId                  → Ürün Bazlı Pazar Tezgâhları & Fiyat Grafiği

/arge                               → Ar-Ge Teknoloji & Kalite Geliştirme
/missions                           → Görev Merkezi & Günlük Seri
/notifications                      → Olay Bildirimleri
/alerts                             → Kritik Şirket Uyarıları
/achievements                       → Başarımlar & Kupa Ödülleri
/cash-history                       → Detaylı Kasa Hareketi (Cash Flow)
/production-report/:ownerKind/:id   → Tesis Üretim & Maliyet Raporu
```

## Ana Modüller

### 81 İl & Holding Merkez Şehri
Oyuncunun holding ana merkez üssünü belirlediği ve ticaretini konumlandırdığı coğrafi sistemdir.
- **Merkez Şehir Seçimi:** Yeni kayıt ve Google ile girişte otomatik açılan modal ile 81 ilden biri merkez seçilir.
- **Profil Yönetimi:** Profil ekranındaki "Merkez Şehir" alanından dilediği zaman merkez şehir güncellenebilir.
- **Şehir Nüfusu & Dinamikleri:** Perakende satış hacmi, pazar büyüklüğü ve şehir vergi oranları merkez ve hedef şehirlere göre dinamik hesaplanır.

### Marka Şirketi
Marka şirketi, Hard Kapitalizm'in ana kimlik ve ilerleme omurgasıdır.
- Marka şirketi oluşturma, marka adı, logo ve tema rengi seçimi.
- Marka seviyesi ve marka XP kazanımı.
- Ürün patentleme ve marka ürün portföyü genişletme.
- Aktif pazarlama kampanyaları (Yerel, Ulusal, Global) ile satış ve marka gücü artırma.
- Üretim, pazar, depo ve mağaza zincirinde marka/kalite yıldızı (Q1-Q5) takibi.

### Bankacılık & Finans (`/bank`)
Holdingin nakit akışını ve likiditesini yönettiği finansal merkezdir.
- **Ticari Krediler:** Farklı vade ve faiz oranlarıyla anlık kredi çekme; kalan anapara, faiz ve taksit takibi.
- **Vadeli Mevduat:** Boşta duran parayı vadeli hesaba bağlayarak vade sonunda yüksek bileşik faiz getirisi kazanma.
- **Erken Çekim Cezası:** Vadesi dolmadan çekilen mevduatlarda biriken faizden feragat ve anapara ceza mekanizması.

### Vergi & Maliye Sistemi (`/tax`)
Şirketlerin yasal yükümlülüklerini simüle eden dinamik vergi motoru.
- **Şehir Bazlı Hasılat Vergisi:** Mağaza ve pazar satışlarından şehir vergi oranına göre otomatik tahakkuk eden vergi.
- **Vergi Borcu & Temerrüt:** Zamanında ödenmeyen vergilerde gecikme zammı ve operasyonel bloke (yeni bina, transfer veya ticaret kısıtı).

### İhale Merkezi (`/tenders`)
Kamu ve belediyelerin düzenlediği büyük ölçekli mal tedarik ihaleleri.
- **İhale Listeleme:** Belirli periyotlarla yenilenen kamu ihaleleri (talep edilen ürün, miktar, tavan fiyat ve son teklif süresi).
- **Teklif Verme:** Stratejik birim maliyet belirleyerek en avantajlı teklifi verme.
- **Lojistik Teslimat:** İhale kazanıldığında depolardan kamu teslimat noktasına lojistik sevkiyat yaparak yüklü nakit ve prestij kazanma.

### Canlı Liderlik Tablosu (`/leaderboard`)
Tüm oyuncuların holdinglerini kıyaslayabildiği rekabet ligi.
- **Şirket Piyasa Değeri:** Binalar, depolar, araç filosu, nakit ve envanter toplamıyla hesaplanan holding değeri.
- **Günlük Ciro & Üretim Sıralaması:** En yüksek satış yapan ve en çok üretim gerçekleştiren sanayiciler.

### Canlı Sohbet & Ticaret Ağı (`/chat`)
Oyuncuların anlık iletişim kurduğu canlı sosyal platform.
- **Global Ticaret Kanalı:** Supabase Realtime ile anlık mesajlaşma.
- **Oyuncu Kimliği:** Holding adı, avatarı ve seviyesiyle mesaj gönderimi.
- **Güvenlik & Raporlama:** Uygunsuz mesajları anında şikayet etme mekanizması.

### İnteraktif Oyun Öğreticisi (Tutorial)
Oyuna yeni başlayan fabrika sahipleri için adım adım onboarding rehberi.
- **Asistan Karakteri:** Samimi ve yönlendirici diyaloglar sunan akıllı oyun asistanı.
- **Spotlight Vurgulama:** İlgili butonları ve kartları ekranda aydınlatarak oyuncuyu hedefe yönlendiren overlay sistemi.

### Mağaza (Store)
- Mağaza açma, slot yönetimi, ürün atama ve fiyatlandırma.
- Mağazaya bağlı özel mağaza deposu.
- Pull-based çalışan mağaza detayına girildiğinde otomatik satış motoru.
- Günlük ciro, kâr ve geçmiş satış kayıtları.

### Depo (Warehouse)
- Tüm genel depoların ve mağaza depolarının tek ekranda toplandığı sekmelerden arındırılmış birleşik liste.
- m³ hacim kapasitesi ve rezerve kapasite mantığı.
- Depo slotları, kalite seviyesi, birim maliyet ve satışa açılabilirlik kontrolleri.

### Üretim Tesisleri (Tarla / Çiftlik / Fabrika / Maden)
- **Tarla & Çiftlik:** Ekim, hasat, hayvan besleme ve verim artırıcı işçi/boost çarpanları.
- **Fabrika:** Çoklu hammadde girdisi, reçete oranları ve mamul ürün üretim slotları.
- **Maden:** Farklı maden tiplerinde saatlik çıkarma hızı ve cevher envanteri.
- **Tesis Üretim Raporu:** Üretim hacmi, harcanan hammadde ve birim maliyet analizi.

### Lojistik & Multi Transfer
- Şehirden şehre rota ve toplam yük hacmi (m³) bazlı araç seçimi.
- Tek bir transfer emrinde birden fazla ürün kalemini taşıyabilen `logistics_transfers` & `logistics_transfer_items` yapısı.
- Araç yakıt, kondisyon ve amortisman maliyetleri.
- Canlı transfer haritasında yoldaki araçların takibi ve ödüllü reklamla varış hızlandırma.

### Serbest Pazar (Market)
- Oyuncuların kendi ürünlerini listelediği canlı pazar yeri.
- Ürün bazında geçmiş fiyat trend grafiği (7 günlük / 30 günlük hareketler).
- Canlı satıcı satış geçmişi ve anlık push bildirimleri.

### Ar-Ge & Teknoloji
- Ürünlerin kalite yıldızlarını (Q1-Q5) yükselten araştırma ağacı.
- Araştırma süresi, altınla hızlandırma ve marka değerine çarpan katkısı.

### Görev, Bildirim ve Başarımlar
- **Görevler:** Ana ve günlük görevler, günlük oturum serisi (daily streak).
- **Başarımlar:** Kriterleri tamamlandığında altın ve XP kazandıran kupa sistemi.
- **Bildirim Merkezi:** Pazar satışları, transfer varışları, ihale sonuçları ve vergi uyarıları.

## Veritabanı Mimarisi

Veritabanı şeması ve migration dosyaları `database_schema.sql` ile `supabase/` altındaki SQL dosyalarında yönetilmektedir.

### Başlıca Tablo Aileleri

- **Oyuncu & Kimlik:** `players`, `player_cash_ledger`, `player_experience_logs`, `player_company_value_history`
- **Merkez & Şehirler:** `cities`, `game_settings`
- **Marka Şirketi & Patent:** `brand_companies`, `brand_company_products`, `brand_marketing_campaigns`, `player_product_brands`, `player_product_quality_levels`
- **Üretim Tesisleri:** `fields`, `field_types`, `farms`, `farm_types`, `factories`, `factory_types`, `mines`, `mine_types`, `production_slots`, `production_inventory`
- **Depolama & Mağazalar:** `warehouses`, `warehouse_types`, `warehouse_slots`, `stores`, `store_types`, `store_slots`, `store_daily_performance`
- **İnşaat & Geliştirme:** `building_constructions`, `building_upgrades`, `building_upgrade_definitions`, `building_upgrade_effects`, `building_boosts`
- **Lojistik & Filo:** `logistics_companies`, `logistics_company_types`, `logistics_vehicles`, `logistics_vehicle_types`, `logistics_transfers`, `logistics_transfer_items`, `logistics_finance_entries`
- **Bankacılık & Finans:** `player_loans`, `player_deposits`
- **Vergi & Maliye:** `player_taxes`
- **Kamu İhaleleri:** `tenders`, `tender_bids`, `tender_deliveries`
- **Liderlik Tablosu:** `player_leaderboard_stats`
- **Sosyal & Sohbet:** `chat_messages`, `chat_message_reports`
- **Görev & Başarım:** `mission_definitions`, `player_missions`, `achievement_definitions`, `player_achievements`
- **Bildirim & Push:** `player_notifications`, `player_push_tokens`, `push_notification_queue`, `push_notification_logs`
- **Ar-Ge & Pazar:** `arge_centers`, `arge_researches`, `products`, `product_price_history`

### Öne Çıkan RPC Aileleri

- **Oturum & Profil:** `bootstrap_game_session`, `ensure_player_record_exists`, `sync_player_google_profile`, `set_player_headquarters_city`, `set_player_avatar`, `update_company_name`, `delete_own_account`
- **Marka & Patent:** `get_player_brand_company`, `create_brand_company`, `patent_brand_company_product`, `start_marketing_campaign`
- **Banka & Kredi:** `take_player_loan`, `pay_player_loan_installment`, `create_player_deposit`, `withdraw_player_deposit`
- **Vergi & Ceza:** `pay_player_taxes`, `get_player_tax_status`, `process_city_tax_accrual`
- **İhale & Teslimat:** `bid_tender`, `deliver_tender_goods`, `generate_daily_tenders`
- **Liderlik & Sıralama:** `get_leaderboard_rankings`, `refresh_player_leaderboard_stats`
- **Üretim & Hasat:** `process_player_production_entry`, `harvest_field_slot`, `feed_farm_slot`, `start_factory_slot_production`
- **Multi Lojistik Transfer:** `start_multi_logistics_transfer`, `start_multi_market_transfer`, `start_multi_warehouse_to_production_transfer`, `start_multi_production_to_warehouse_transfer`, `complete_logistics_transfer`, `get_route_transfer_vehicle_options`
- **Perakende & Satış:** `process_store_sales`, `get_store_detail_overview`, `assign_product_to_store_slot`, `transfer_store_slot_stock`
- **Depo Yönetimi:** `get_warehouses_summary_list`, `transfer_warehouse_stock`
- **Ar-Ge & Kalite:** `start_arge_research`, `speedup_arge_research`
- **Görev & Başarımlar:** `claim_mission_reward`, `claim_achievement_reward`, `check_player_achievements`
- **Push & Bildirim:** `register_push_token`, `unregister_push_token`, `mark_all_notifications_read`

## Kurulum & Çalıştırma

### 1. Bağımlılıkları Yükleme
Flutter SDK'nın (3.x+) kurulu olduğundan emin olun:

```bash
git clone https://github.com/windssson/hard_kapitalizm.git
cd hard_kapitalizm
git checkout redesign
flutter pub get
```

### 2. Ortam Değişkenleri (.env)
Kök dizinde `.env` dosyası oluşturun ve Supabase ile Google OAuth anahtarlarını tanımlayın:

```env
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_ANON_KEY=your_supabase_anon_key
GOOGLE_WEB_CLIENT_ID=your_google_web_client_id.apps.googleusercontent.com
```

> **Güvenlik Notu:** Gerçek API anahtarlarını ve `.env` dosyasını kesinlikle versiyon kontrolüne (git) commit etmeyin.

### 3. Uygulamayı Başlatma

```bash
# Bağlı cihazları listele
flutter devices

# Uygulamayı çalıştır
flutter run
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
- Marka sistemi; üretim, kalite, market, satış ve oyuncu ilerlemesinin ana omurgası olarak korunmalıdır.
- Üretim, mağaza, depo ve lojistik işlemlerinde marka, kalite seviyesi, maliyet bilgisi ve kapasite hesapları korunmalıdır.
- Multi transferlerde tek parent transfer ve birden fazla item satırı mantığı korunmalıdır.
- Aynı şehir transferleri anlık, farklı şehir transferleri araçlı lojistik transfer olarak ilerleyecek şekilde tasarlanmıştır.
- Transfer araç seçimi, multi transferlerde toplam hacim ve rota mantığıyla yapılmalıdır.
- UI tarafında premium/oyunsu tasarım dili korunur; asset tabanlı panel, ikon ve kart yaklaşımı tercih edilir.

## Aktif Geliştirme Durumu

`redesign` branch'inin güncel odağı:

- marka şirketi sistemini ürün, kalite, üretim, market ve satış zincirinin merkezine yerleştirmek,
- ürün patentleme ve pazarlama kampanyası akışlarını oyun döngüsüne bağlamak,
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
→ marka şirketini kur
→ ürün patentle
→ depo kur
→ üretim tesisi kur
→ ürün ve kalite/marka tercihini seç
→ üretim input/output kontrolü
→ üretimi depoya aktar
→ depodan mağazaya aktar
→ mağazaya girince satış işle
→ para artışı, cash-flow, satış geçmişi ve rapor kontrolü
→ marka ürün portföyü, marka XP/seviye ve kampanya etkilerini kontrol et
→ görev/bildirim/başarım tetiklerini kontrol et
→ transfer haritasında aktif/geçmiş transferleri doğrula
```

## Lisans

Bu repoda henüz lisans dosyası bulunmuyor. Kullanım ve dağıtım şartları daha sonra netleştirilmelidir.
