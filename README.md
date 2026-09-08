# Hard Kapitalizm

Hard Kapitalizm, Flutter ve Supabase ile geliştirilen; üretim, lojistik, perakende, serbest pazar, finans, vergi, ihale, marka ve rekabet sistemlerini bir araya getiren mobil tycoon / holding yönetimi oyunudur.

> **Güncel mimari kaynağı:** `main` branch ve canlı Supabase backend (`kapitalizm`). Backend sözleşmesi için `HARD_KAPITALIZM_BACKEND_CONTRACT_2026-09-08.md` dosyası source of truth kabul edilir.

## Oyun Döngüsü

```text
Oyuncu 81 il arasından holding merkez şehrini seçer
→ Başlangıç paketini alır: şehirde Genel Depo + Manav + başlangıç stoğu
→ Marka şirketi kurar, logo/tema belirler ve ürünleri patentler
→ Tarla, çiftlik, fabrika ve maden kurarak üretim zinciri oluşturur
→ Şehir bazlı Genel Depolar üzerinden stok yönetir
→ Lojistik araçlarıyla şehirler arası ürün transferi yapar
→ Mağazalarda perakende satış yapar
→ Serbest pazarda diğer oyuncularla alım-satım yapar
→ İhalelere teklif verir ve teslimatları tamamlar
→ Banka, vergi ve nakit akışını yönetir
→ Ar-Ge ile ürün kalitesini artırır
→ Görevler, günlük seri ve liderlik tablosuyla ilerler
```

## Güncel Ana Sistemler

- **81 İl & Merkez Şehir Sistemi:** Oyuncu holding merkezini 81 ilden biri olarak seçer. Şehir nüfusu, vergi oranı ve uzmanlık bonusları ekonomik kararları etkiler.
- **Native Google Sign-In & Oturum:** Supabase Auth ile yerel Google giriş akışı ve profil senkronizasyonu.
- **Başlangıç Paketi:** Yeni oyuncuya merkez şehirde 1 Genel Depo, 1 Manav ve başlangıç ürün stoğu tanımlanır. Paket yalnızca bir kez alınabilir.
- **Marka Şirketi Sistemi:** Marka oluşturma, logo/tema, marka XP, ürün patentleri ve pazarlama kampanyaları.
- **Üretim Tesisleri:** Tarla, çiftlik, fabrika ve maden; slot, kalite, marka, input/output envanteri ve üretim kapasitesi yönetimi.
- **Şehir Bazlı Genel Depo Sistemi:** Eski mağazaya bağlı depo modeli kaldırılmıştır. Oyuncu başına şehirde en fazla 1 aktif Genel Depo bulunur.
- **İşletme Kurulum Önkoşulu:** Depo dışındaki ticari işletmeler kurulmadan önce ilgili şehirde aktif Genel Depo bulunmalıdır.
- **Mağaza & Perakende:** Slot yönetimi, fiyatlandırma, şehir deposundan raf doldurma ve pull-based satış işleme.
- **Lojistik & Transfer:** Şehirler arası araçlı transfer, rota kısıtları, yakıt/kondisyon, kiralık araç ve NPC fallback desteği.
- **Şehir İçi Transfer:** Aynı şehirde depo/işletme arasındaki uygun transferler araç gerektirmeden anlık tamamlanabilir.
- **Serbest Pazar:** Depo slotlarını satışa açma, şehir bazlı listeleme, çoklu ürün satın alma, satıcı bildirimi ve fiyat geçmişi.
- **Ar-Ge & Kalite:** Ürün kalitesini Q1-Q5 aralığında yükseltme; mevcut üretimin kalite/marka tercihi ayrıca yönetilir.
- **Banka & Finans:** Kredi, taksit, mevduat, erken çekim ve nakit hareketleri.
- **Vergi Sistemi:** Şehir bazlı vergi borcu, vergi ledger'ı ve borç limiti aşıldığında operasyonel blokaj.
- **İhale Merkezi:** Teklif, kazanan belirleme, teslimat, kalite şartı ve lojistik araç seçimi.
- **Liderlik Tablosu:** Şirket değeri, ciro ve üretim odaklı oyuncu sıralaması.
- **Görev & Günlük Seri:** Birleştirilmiş görev/başarım modeli, günlük ve haftalık görevler, ödül talepleri.
- **Canlı Sohbet & DM:** Global/şehir sohbeti, ürün bağlantısı, doğrudan mesaj ve raporlama.
- **Push Bildirimleri:** FCM + Supabase tabanlı operasyonel uyarılar, transfer/pazar/ihale/üretim bildirimleri.
- **Interactive Tutorial:** Yeni oyuncuyu temel ekonomi ve üretim döngüsüne yönlendiren spotlight/overlay sistemi.

## Teknolojiler

| Alan | Teknoloji | Açıklama |
| --- | --- | --- |
| Mobil Framework | Flutter | Android/iOS uygulama katmanı |
| Dil | Dart | İstemci uygulama dili |
| State Management | Riverpod | Reaktif state ve provider yönetimi |
| Routing | GoRouter | Deklaratif navigasyon ve deep-link desteği |
| Backend | Supabase | Auth, PostgreSQL, Storage, Realtime ve Edge Functions |
| Veritabanı | PostgreSQL | RPC-first oyun mantığı, transactional mutation'lar |
| Push | Firebase Cloud Messaging | Arka plan ve cihaz push bildirimleri |
| Storage | Supabase Storage | Uygulama ve oyun asset'leri |
| Reklam | Google Mobile Ads | Ödüllü reklam akışları |
| Responsive UI | flutter_screenutil | Ekran ölçekleme |
| Haptic | Flutter services | Dokunsal geri bildirim |

## Mimari İlkeler

### Backend Source of Truth

Canlı Supabase backend oyun kurallarının ve ekonomik state'in source of truth'udur. Frontend backend davranışını yeniden üretmez; RPC sözleşmesine uyum sağlar.

### RPC-First Mutation

Frontend'den doğrudan tablo `INSERT / UPDATE / DELETE` yapılmaz. Oyun state'ini değiştiren işlemler backend RPC'leri üzerinden yürütülür.

Doğru:

```dart
await supabase.rpc('set_store_slot_price', params: {...});
```

Yanlış:

```dart
await supabase.from('store_slots').update({...});
```

### Patch-First State Sync

Mutation RPC response'larında mümkün olduğunca `changed` payload'ı döndürülür. Frontend state güncelleme önceliği:

```text
1. response içindeki changed payload ile patch
2. küçük ve hedefli getter refresh
3. son çare provider invalidate
```

Ortak mutation senkronizasyonu `lib/core/data/mutation_sync_service.dart` üzerinden yürütülür. Geçiş tamamlanmamıştır; bazı feature provider'larında hâlâ hedefli invalidate kullanımı vardır.

### Güvenlik

- Oyuncu kimliği `auth.uid()` üzerinden doğrulanır.
- Kritik mutation RPC'leri `SECURITY DEFINER` olsa dahi ownership/auth kontrolü yapar.
- Public tablolarda RLS aktiftir.
- Frontend doğrudan authenticated table write yapmaz.
- Para ve premium para hareketleri ledger tablolarında izlenir.

## Üretim Mimarisi

Üretim iki yoldan işlenir:

```text
Detay ekranına giriş
→ process_player_production_entry(...)
→ ilgili oyuncu/tesis için geçen süreyi işler
```

ve offline ilerleme/uyarı desteği için:

```text
Saatlik cron
→ process_all_players_production()
```

Temel üretim state'i:

```text
production_slots
production_inventory
player_daily_production_stats
```

Üretim envanteri input/output ayrımı, kalite ve marka bilgisi taşır. Üretim sistemi advisory lock ve transactional işlemlerle aynı oyuncu için çakışan işlemleri sınırlar.

## Depo Mimarisi

Eski mağaza-linked depo yapısı kaldırılmıştır.

Güncel model:

```text
Oyuncu
  └── Şehir
       └── 1 Genel Depo
            └── warehouse_slots
```

Kurallar:

- Oyuncu + şehir başına en fazla 1 aktif Genel Depo.
- Mağaza, tarla, çiftlik, fabrika, maden ve lojistik işletmesi açılacak şehirde önce Genel Depo bulunmalıdır.
- Mağaza satışında veya işletme satışında şehir Genel Deposu otomatik silinmez.
- Kapasite ürünlerin birim hacmi üzerinden hesaplanır.
- Transfer sırasında pending/reserved kapasite hesaba katılır.

## Transfer & Lojistik

### Aynı Şehir

Uygun işletmeler arasında araç gerektirmeden anlık transfer yapılabilir.

### Şehirler Arası

- Araç seçimi gerekir.
- Araç rota çiftiyle uyumlu olmalıdır.
- Kapasite ürün hacmine göre hesaplanır.
- Yakıt, kondisyon ve maliyet transfer kaydına yansır.
- Oyuncunun uygun aracı yoksa NPC/kiralık fallback araçları kullanılabilir.
- Multi-item transferler desteklenir.

Başlıca akışlar:

```text
warehouse → warehouse
warehouse → production
production → warehouse
market → warehouse
warehouse → tender delivery
```

## Mağaza Satış Sistemi

Mağaza satışları sürekli çalışan satış cron'u yerine pull-based işlenir:

```text
Mağaza detay ekranı açılır
→ open_store_detail_page(...)
→ geçen satış periyotları işlenir
→ slot ve performans verileri döndürülür
```

Satış döngüsü güncel backend'de 5 dakikalık periyot mantığı kullanır.

## Push Bildirim Sistemi

Push altyapısı:

```text
PostgreSQL event/worker
→ internal HTTP request
→ Supabase Edge Function: send-push
→ FCM HTTP v1
→ Android/iOS cihaz
```

Aktif Edge Function:

```text
send-push
```

Operasyonel uyarılar 30 dakikalık worker ile; üretim uyarıları saatlik üretim akışıyla ilişkilidir. Tekrarlı push'ları azaltmak için dedupe/log tabloları bulunur.

Android küçük bildirim ikonu için proje içinde:

```text
android/app/src/main/res/drawable/ic_notification.png
```

dosyası bulunmaktadır.

## Cron / Background İşler

Canlı backend'deki temel zamanlanmış işler:

| İş | Sıklık |
| --- | --- |
| Market transfer completion | 15 dk |
| Building construction completion | 15 dk |
| Tender maintenance | 30 dk |
| Building upgrade completion | 30 dk |
| Operational push alerts | 30 dk |
| Production worker | 1 saat |
| Ar-Ge completion | 1 saat |
| Market stats | 4 saat |
| Bank ticks | 4 saat |
| Leaderboard refresh | 12 saat |
| Company value snapshots | Günlük |
| Product price day shift | Günlük |
| Database cleanup | Günlük |

## Backend Veri Alanları

Başlıca tablolar:

```text
players
cities
products

stores
store_slots
store_daily_performance

warehouses
warehouse_slots

factories
fields
farms
mines
production_slots
production_inventory
player_daily_production_stats

logistics_companies
logistics_vehicles
logistics_transfers
logistics_transfer_items
logistics_finance_entries

brand_companies
brand_company_products
brand_marketing_campaigns

player_cash_ledger
player_gold_ledger
player_tax_ledger
player_taxes
player_loans
player_deposits

tenders
player_tenders
tender_bids
tender_deliveries

mission_definitions
player_missions
player_daily_streaks

player_notifications
player_push_tokens
player_alert_push_logs
backend_error_logs

chat_messages
direct_messages
chat_message_reports

player_leaderboard_stats
player_company_value_history
product_price_history
```

## Proje Yapısı

```text
lib/
  core/
    constants/
    data/
    managers/
    models/
    navigation/
    providers/
    theme/
    utils/
    widgets/

  features/
    achievement/
    arge/
    auth/
    bank/
    cash_flow/
    chat/
    company/
    factory/
    farm/
    field/
    home/
    leaderboard/
    logistics/
    market/
    mine/
    mission/
    notification/
    premium/
    production_report/
    splash/
    store/
    tax/
    tender/
    transfer_map/
    warehouse/

  main.dart

android/
ios/
assets/
test/
```

## Backend İsimlendirme Notu

Backend'deki tarihsel isimlendirme ile UI isimlendirmesi farklıdır ve bu mapping korunmalıdır:

| Backend | UI |
| --- | --- |
| `farm`, `farms`, `farm_types` | Tarla |
| `field`, `fields`, `field_types` | Çiftlik |
| `factory` | Fabrika |
| `mine` | Maden |
| `store` | Mağaza |
| `warehouse` | Depo |

`farm` ve `field` mapping'i frontend geliştirmesinde ters çevrilmemelidir.

## Ana Rotalar

```text
/                       Splash
/auth                   Giriş / kayıt
/home                   Ana panel
/profile                Oyuncu profili
/company                Marka şirketi

/bank                   Banka
/tax                    Vergi
/tenders                İhaleler
/leaderboard            Liderlik tablosu
/chat                    Sohbet
/premium                 Premium / altın

/store                   Mağazalar
/warehouses              Depolar
/fields                  Üretim tesisi listesi
/farms                   Üretim tesisi listesi
/factories               Fabrikalar
/mines                   Madenler
/logistics               Lojistik
/transfer-map            Transfer haritası
/market                  Serbest pazar
/arge                    Ar-Ge
/missions                Görevler
/notifications           Bildirimler
/alerts                  Operasyonel uyarılar
/cash-history            Nakit geçmişi
```

Detay ve kurulum ekranları entity ID veya şehir/tip seçim parametreleriyle alt route'larda açılır.

## Test Yapısı

Projede Flutter unit/widget testleri bulunmaktadır. Başlıca test alanları:

```text
widget smoke test
core models
bank actions
company / brand actions
mission / Ar-Ge / tax / tender logic
economy / market / store / warehouse logic
production building logic
logistics / transfer logic
```

Yeni mutation geliştirmelerinde sadece hesaplama unit testleri değil, mümkün olduğunca şu zincir doğrulanmalıdır:

```text
Flutter action
→ RPC
→ DB mutation
→ changed response
→ Riverpod patch / refresh
→ UI state
```

## Geliştirme Kuralları

1. Backend davranışını tahmin etme; canlı RPC sözleşmesini kontrol et.
2. Mutation için yeni direct table write ekleme.
3. Yeni RPC eklemeden önce mevcut RPC/getter'ların yeterli olup olmadığını kontrol et.
4. Mutation response `changed` payload'ını frontend'de kullan.
5. Gereksiz geniş `invalidate` yerine hedefli patch/refresh tercih et.
6. `auth.uid()` ile ownership doğrulamasını kritik mutationlarda zorunlu kabul et.
7. Ekonomi, transfer, üretim ve premium para değişikliklerini transactional tut.
8. Yeni backend değişikliklerinde migration + advisor + doğrulama akışını uygula.

## Dokümantasyon

Backend ve frontend entegrasyonu için en güncel sözleşme:

```text
HARD_KAPITALIZM_BACKEND_CONTRACT_2026-09-08.md
```

README proje seviyesinde genel mimariyi açıklar; RPC imzaları, response shape'leri ve backend özel kuralları için backend contract dosyası esas alınmalıdır.

---

**Hard Kapitalizm** aktif geliştirme aşamasındadır. Projenin ana odağı; derin fakat yönetilebilir ekonomi simülasyonu, oyuncular arası ticaret ve rekabet, performans dostu backend işlemleri ve mobil cihazlarda hızlı/akıcı kullanıcı deneyimidir.
