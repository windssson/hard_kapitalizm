# Hard Kapitalizm — Codex Proje Bağlamı

> Son doğrulama: 11 Eylül 2026  
> Repo: `windssson/hard_kapitalizm`  
> Aktif geliştirme kaynağı: `main` branch + canlı Supabase projesi (`kapitalizm`)

Bu dosya Codex ve projede çalışan diğer yapay zekâ araçları için kalıcı bağlam ve çalışma talimatıdır. Yeni bir göreve başlamadan önce bu dosya okunmalı; yapılan anlamlı mimari değişikliklerden sonra güncellenmelidir.

## 1. Kaynakların Öncelik Sırası

Kaynaklar çelişirse aşağıdaki sıra kullanılır:

1. Kullanıcının mevcut görevde açıkça verdiği talimat
2. Canlı Supabase şeması, RPC tanımları, cronlar ve gerçek veriler
3. `main` branch üzerindeki çalışan kod ve testler
4. `Raporlar/HARD_KAPITALIZM_BACKEND_CONTRACT_2026-09-08.md`
5. Bu dosya
6. `README.md` ve tarihli raporlar

Eski sohbet kayıtları ve tarihli raporlar tek başına güncel gerçek kabul edilmez. Backend davranışı tahmin edilmemeli; canlı Supabase veya güncel sözleşme doğrulanmalıdır.

## 2. Projenin Kimliği

Hard Kapitalizm; üretim, stok, lojistik, perakende, serbest pazar, finans, vergi, ihale, marka ve rekabet sistemlerini bir araya getiren mobil holding/tycoon oyunudur.

Oyunun hedefi basit bir idle oyun olmak değil; oyuncuya anlaşılır arayüz içinde gerçek kararlar aldıran, derin fakat yönetilebilir bir ekonomi simülasyonu sunmaktır.

Temel oyun döngüsü:

```text
Kaynak üretimi
→ şehir deposu
→ fabrika girdisi
→ işlenmiş ürün
→ şehir deposu
→ mağaza / pazar / ihale
→ gelir
→ yeni yatırım, kapasite, kalite ve lojistik
```

Ürünlerin nerede bulunduğu, transferde/rezerve/üretimde/satışta ne kadar olduğu uzun vadede oyuncuya açıkça gösterilmelidir. “Ürün/Stok Merkezi” yaklaşımı bu görünürlük ihtiyacının aday çözümüdür.

## 3. Ürün ve Tasarım Vizyonu

- Mobil önceliklidir; akıcılık ve düşük gereksiz ağ trafiği kritik önemdedir.
- Oyunun ana kimliği detaylı Flutter yönetim ekranlarıdır.
- Flame tabanlı 2D izometrik şehir merkezi, oyunun tamamının yerine geçmez.
- İzometrik merkez; görsel canlılık, hızlı durum görme, bina seçme ve ilgili yönetim ekranına yönlenme katmanıdır.
- Derin üretim, stok, transfer, fiyat ve işletme işlemleri Flutter ekranlarında kalır.
- Yeni özellik eklemekten önce mevcut sistemin güvenilir, anlaşılır ve ölçülebilir olması tercih edilir.
- UI/UX çalışmalarında “oyunda bir şeyler oluyor” hissi; yaklaşan işler, üretim durumu, transferler, uyarılar ve ekonomik sonuçlarla verilmelidir.

## 4. Teknoloji ve Mimari

| Katman | Teknoloji / karar |
| --- | --- |
| Mobil istemci | Flutter / Dart |
| State yönetimi | Riverpod |
| Navigasyon | GoRouter |
| Backend | Supabase |
| Veritabanı | PostgreSQL, RPC-first |
| Kimlik | Supabase Auth + native Google Sign-In |
| Push | Firebase Cloud Messaging + Supabase Edge Function |
| İzometrik sahne | Flame |
| Responsive UI | flutter_screenutil |

Backend server-authoritative'tir. Ekonomi kuralları frontend'de tekrar uygulanmaz.

Frontend oyun state'ini doğrudan tablo yazarak değiştirmemelidir:

```dart
// Doğru
await supabase.rpc('rpc_name', params: {...});

// Yanlış
await supabase.from('table').update({...});
```

Kritik değişiklikler transaction içinde yapılmalı; oyuncu kimliği `auth.uid()` ile doğrulanmalı; ownership kontrolü RPC içinde yapılmalıdır.

## 5. Patch-First State Senkronizasyonu

Proje geniş `ref.invalidate(...)` ve tam yeniden-fetch bağımlılığından patch-first yapıya geçirilmektedir.

Standart mutation cevabı:

```json
{
  "success": true,
  "changed": {
    "player": {},
    "patches": []
  }
}
```

Frontend uygulama sırası:

1. `changed.player`
2. `changed.patches[]`
3. Gerekiyorsa küçük ve hedefli getter refresh
4. Yalnızca güvenli patch mümkün değilse hedefli invalidate
5. Broad/global invalidate son çaredir

Ortak senkronizasyon `lib/core/data/mutation_sync_service.dart` üzerinden yürür. Entity patch dağıtımı ve özel local patch servisleri `lib/core/data/` altındadır.

Temel amaçlar:

- Mutation sonrası gereksiz API çağrılarını azaltmak
- UI'ı anında güncellemek
- Provider zincirleme reload'larını önlemek
- TimedTaskRuntime'ın gereksiz yeniden planlanmasını azaltmak
- Patch uygulanamayan durumda sessizce yanlış state üretmek yerine authoritative targeted refresh kullanmak

11 Eylül 2026 itibarıyla production building insert akışlarında factory/mine placeholder üretimi kaldırılmış; field/farm ve ilk production slot local state'e eklenebilir hale getirilmiştir. Static metadata yoksa sahte model oluşturulmaz, hedefli refresh yapılır.

## 6. TimedTaskRuntime — Güncel Yön ve Neden

TimedTaskRuntime, süreli işleri polling ile sürekli sorgulamak yerine sunucudan görev snapshot'ı alır ve en yakın `finish_at` zamanına tek timer kurar.

İlgili dosyalar:

- `lib/core/widgets/timed_task_runtime.dart`
- `lib/core/data/timed_task_runtime_service.dart`
- `lib/core/models/timed_task_runtime_model.dart`
- `lib/core/data/timed_task_runtime_revision.dart`

Backend girişleri:

- `get_timed_task_runtime_state`
- `complete_timed_task_runtime_due`

Mevcut davranış:

- Sunucu zamanı snapshot alındığında anchor edilir; cihaz saati doğrudan güven kaynağı değildir.
- Runtime yalnızca foreground'da timer çalıştırır.
- Oturum değişiminde clock, event cursor ve local origin kayıtları sıfırlanır.
- Vadesi gelen işler toplu olarak tamamlanır.
- Completion sonucu standart `changed` zarfıyla bir kez patch edilir.
- Her completion denemesinden sonra authoritative snapshot yeniden okunur.
- Client/cron yarışı idempotent ve yakınsayan davranmalıdır.
- Dışarıda tamamlanan işler terminal event cursor ile uzlaştırılır.
- Aynı client'ın kendi uyguladığı event, `origin_token` ile tekrar uygulanmaz.
- Hata durumunda runtime kapanmaz; 10 saniye sonra yeniden dener.
- Event sayfası doluysa uyumadan önce kalan event sayfaları tüketilir.
- En yakın yeni görev değiştiğinde revision tetiklenerek plan yeniden hesaplanır.

Korunması gereken invariantlar:

- Aynı task iki kere ekonomik sonuç üretmemeli.
- Client ve cron aynı anda tamamlasa bile sonuç tek olmalı.
- Başarısız tek görev diğer görevlerin state'ini bozmamalı.
- Eksik veya bozuk event bütün runtime'ı durdurmamalı.
- Tamamlanan görev UI'da broad invalidate olmadan görünmelidir.
- Runtime global provider snapshot'larına yeniden bağımlı hale getirilmemelidir.

## 7. Üretim Sistemi

Üretim iki yoldan işlenir:

```text
İşletme detayına giriş
→ process_player_production_entry(...)
→ geçen süreye göre ilgili üretimi işle
```

ve offline ilerleme/uyarı desteği için:

```text
Saatlik cron
→ process_all_players_production()
```

Ana tablolar:

- `production_slots`
- `production_inventory`
- `player_daily_production_stats`
- `factories`, `fields`, `farms`, `mines`

Kurallar:

- Input/output envanteri ortak `production_inventory` modelindedir.
- Ürün, kalite, marka, miktar, pending miktar ve ağırlıklı maliyet korunur.
- Kalite Q1–Q5'tir.
- Ar-Ge kalitesi yükselse bile devam eden üretim tercihi otomatik değişmez; oyuncu üretim ayarını değiştirir.
- Boost üretim ve girdi tüketimini birlikte etkiler.
- Üretim gerçek geçen süreyi esas almalıdır; eski keyfi tick/süre cap'leri geri getirilmemelidir.
- Marka seçilmiş üretimde ayrıca markasız duplicate output oluşmamalıdır.
- Aynı oyuncunun çakışan üretim işlemleri advisory lock/transaction yaklaşımıyla güvenli tutulmalıdır.

Backend ile UI adlandırması tarihsel olarak farklıdır ve ters çevrilmemelidir:

| Backend | UI |
| --- | --- |
| `farm`, `farms`, `farm_types` | Tarla |
| `field`, `fields`, `field_types` | Çiftlik |
| `factory` | Fabrika |
| `mine` | Maden |

Fabrika metadata yönü: çok sayıdaki fabrika tipi beş mantıklı ürün grubunda sadeleştirilecektir. Tip isimleri ve ürün eşlemesi değiştirilmeden önce canlı `factory_types` ve `products` verileri doğrulanmalıdır; sohbet hafızasına dayanarak ID üretilmemelidir.

## 8. Depo, İşletme ve Başlangıç Paketi

Eski mağazaya bağlı depo modeli kaldırılmıştır.

Güncel model:

```text
Oyuncu
└── Şehir
    └── en fazla 1 aktif Genel Depo
```

Kurallar:

- Depo dışındaki işletmeleri kurmak için o şehirde aktif Genel Depo bulunmalıdır.
- Depo, şehirdeki merkezi stok noktasıdır.
- Kapasite ürünlerin birim hacmine göre hesaplanır.
- Pending/reserved kapasite toplam kapasite hesabına dahildir.
- İşletme silinmesi şehir deposunu otomatik silmemelidir.
- Yeni oyuncuya merkez şehirde 1 Genel Depo + 1 Manav + başlangıç stoğu verilir.
- Başlangıç paketi yalnızca bir kez alınabilir.
- Başlangıç paketi RPC'sinde auth/ownership ve idempotency zorunludur.

## 9. Lojistik ve Transfer

Desteklenen ana akışlar:

- warehouse → warehouse
- warehouse → production
- production → warehouse
- market → warehouse
- warehouse → tender delivery

Kurallar:

- Aynı şehirde uygun transfer araçsız ve anlık tamamlanabilir.
- Şehirler arası transferde araç gerekir.
- Araç yalnızca atanmış rota/şehir çiftiyle uyumlu seferde kullanılabilir.
- Oyuncunun uygun aracı yoksa kiralık/NPC fallback kullanılabilir.
- Kapasite ürün hacmine göre hesaplanır.
- Yakıt, kondisyon, kira ve taşıma maliyeti anlamları birbirine karıştırılmamalıdır.
- Multi-item ve çoklu kaynak transferleri desteklenirken her kaynak için ownership doğrulanmalıdır.
- Rezervasyon transfer başında yapılmalı; başarı, iptal ve hata yollarında tam ve idempotent çözülmelidir.
- Transfer RPC overload'ları isim/imza belirsizliği yaratmamalıdır.

## 10. Mağaza ve Satış

Mağaza satışları sürekli satış cron'u yerine pull-based işlenir:

```text
Mağaza detay ekranı açılır
→ open_store_detail_page(...)
→ geçen satış periyotları işlenir
→ slot, gelir ve performans değişiklikleri döner
```

Güncel backend sözleşmesinde satış periyodu 5 dakikadır. Fiyat, kalite, stok, pending sale ve maliyet bilgileri aynı ürün/kalite slot bütünlüğünü korumalıdır.

## 11. Şehir Merkezi / Flame İzometrik Sistem

Konum: `lib/features/city_center/`

Amaç: mevcut işletmeleri 2D izometrik şehirde göstermek, seçmek ve yönetim ekranına geçmek. Bu alan ana ekonomi mantığını kopyalamaz.

Güncel teknik standart:

- 2:1 dimetrik grid
- Tile: 64×32
- Ortografik/sabit görsel dil
- Varsayılan grid: 16×16
- Hedef footprint'ler: 1×1, 2×2, 3×2, 2×3, 4×3
- Yerleşim sınırı: `col + cols <= gridSize`, `row + rows <= gridSize`
- Random yerleşim son geçerli koordinatı dahil etmelidir.
- Derinlik tabanı: `(col + row) * 100`
- Bina priority: taban derinliği + 50
- Sprite tabanı footprint'in güney anchor noktasına oturmalıdır.
- Non-square footprint (3×2 / 2×3) hizası özellikle regresyon testleriyle korunmalıdır.
- Yerleşim, depth/layer ve kamera değişiklikleri birbirine karıştırılmadan küçük adımlarla yapılmalıdır.

Sprite standardı:

- 2:1 dimetrik açı
- Transparan arka plan
- Perspektif yok denecek kadar az
- Binalar aynı yöne bakmalı
- Footprint görselin alt-orta bölümünde net olmalı
- Asset altında gereksiz transparan boşluk olmamalı

## 12. Push ve Arka Plan İşleri

Push zinciri:

```text
PostgreSQL event/worker
→ internal HTTP
→ Supabase Edge Function: send-push
→ FCM HTTP v1
→ cihaz
```

Android küçük ikon yolu:

`android/app/src/main/res/drawable/ic_notification.png`

Bildirim ve cron tasarımında toplu işleme, dedupe ve yalnızca anlamlı oyuncu olayları hedeflenir. Üretim cron'u yalnızca UI güncellemesi için sıklaştırılmamalıdır; offline ilerleme ve hammadde bitti uyarısı gibi backend sorumluluklarını taşır.

## 13. Güvenlik ve Veri Bütünlüğü Öncelikleri

Bilinen yüksek öncelikli riskler:

- Transfer kaynak sahipliği doğrulaması bütün RPC yollarında garanti edilmelidir.
- Public `SECURITY DEFINER` yüzeyi daraltılmalı ve her kritik fonksiyonda auth/ownership kontrolü doğrulanmalıdır.
- `grant_starter_package` auth, ownership ve tek-sefer invariantı test edilmelidir.
- Para, altın, vergi, kredi ve pazar hareketleri ledger ve transaction bütünlüğünü korumalıdır.
- RPC'ler tekrar çağrıldığında çift ödeme, çift ürün veya çift tamamlama üretmemelidir.

## 14. Test Beklentisi

Değişiklikte uygun olan zincir uçtan uca düşünülmelidir:

```text
Flutter action
→ RPC
→ DB mutation
→ changed response
→ MutationSyncService
→ Riverpod local patch / targeted refresh
→ UI
```

Özellikle test edilmesi gerekenler:

- Patch parser ve entity dispatcher
- Insert/update/delete patch'leri
- Timed task completion, client/cron yarışı ve event reconciliation
- Production elapsed-time ve duplicate output
- Transfer rezervasyon/kapasite/ownership/idempotency
- Store sales idempotency
- 3×2 ve 2×3 izometrik sprite hizası
- Grid sınırında son geçerli placement
- Oturum değişimi ve foreground/resume davranışı

## 15. Güncel Yol Haritası

### Aşama 1 — State senkronizasyonunu sağlamlaştır

- Kalan broad invalidate noktalarını envanterle.
- Güvenli alanlarda patch veya hedefli refresh'e geçir.
- Patch uygulanamadığında authoritative fallback davranışını standardize et.
- Provider reload → runtime reschedule zincirlerini kaldır.
- Patch bütünlük/regresyon testlerini genişlet.

### Aşama 2 — TimedTaskRuntime'ı tamamla

- Canlı RPC contract'ını frontend modelle birebir doğrula.
- Bütün süreli task türlerinin snapshot ve completion kapsamını doğrula.
- Terminal event'lerin eksiksiz `changed` taşıdığını doğrula.
- Client/cron race, offline resume, pagination ve retry senaryolarını test et.
- Runtime kaynaklı API çağrılarını ölç.

### Aşama 3 — Kritik backend güvenliği

- Transfer ownership açığını kapat.
- `SECURITY DEFINER` RPC audit'i yap.
- Başlangıç paketi auth/idempotency güvenliğini doğrula.
- Ekonomi invariant testleri ekle.

### Aşama 4 — Üretim ve metadata sadeleştirme

- Fabrika tiplerini doğrulanmış beş ürün grubuna indir.
- Ürün ↔ fabrika tipi ↔ accepted product eşleşmelerini migration öncesi raporla.
- Marka/kalite duplicate output regresyonunu kapat.
- Üretim cron ve detail-entry performansını yeniden ölç.

### Aşama 5 — İzometrik şehir merkezi

- Grid/footprint/sprite anchor matematiğini testlerle sabitle.
- Depth/layer sırasını tamamla.
- Kamera hareketi, zoom, seçim ve işletme ekranına yönlendirmeyi geliştir.
- Canlı işletme verisini görsel merkeze bağla.
- Yönetim ekranlarını Flame içine taşımadan hibrit yapıyı koru.

### Aşama 6 — UI/UX ve oyun derinliği

- Ana panelde yaklaşan işler, darboğazlar, transferler ve ekonomik sonuçları görünür yap.
- Şehir ve transfer seçim akışlarını kısalt.
- Ürün/Stok Merkezi ile tedarik zinciri görünürlüğünü artır.
- Yeni ağır mekanik eklemeden karar verme ve sosyal rekabeti güçlendir.
- Depo merkezli modele göre tutorial'ı yeniden düzenle.

## 16. Codex Çalışma Kuralları

1. Göreve başlamadan önce bu dosyayı ve görevle ilgili güncel kod/raporu oku.
2. Kullanıcının istemediği alanlara dokunma; minimum ve hedefli değişiklik yap.
3. Bir görev frontend ise gerekmedikçe Supabase, provider mimarisi, kamera, asset sistemi veya yeni mekanik ekleme.
4. Bir görev backend ise canlı şemayı ve mevcut overload/imzaları doğrulamadan SQL üretme.
5. Varsayım ile doğrulanmış gerçeği ayır; belirsizliği açıkça işaretle.
6. Mevcut testleri bozma; ilgili testleri çalıştır ve sonucu bildir.
7. Kullanıcı açıkça istemedikçe bağımsız refactor yapma.
8. Gizli anahtarları, tokenları ve `.env` içeriğini commit etme veya çıktıya yazma.
9. Kullanıcı açıkça talep etmedikçe GitHub'a push/commit işlemi yapma.
10. GitHub'a yazma izni verildiğinde yalnızca istenen dosya ve kapsamı değiştir.
11. Görev tamamlanınca ne değiştiğini, hangi testlerin çalıştığını ve kalan riski kısa biçimde raporla.
12. Mimari karar veya yol haritası değiştiyse bu dosyayı aynı görev içinde güncel tut.

## 17. Doküman Haritası

- Genel tanıtım ve modüller: `README.md`
- Backend sözleşmesi: `Raporlar/HARD_KAPITALIZM_BACKEND_CONTRACT_2026-09-08.md`
- Patch geçiş raporları: `Raporlar/Hard_Kapitalizm_Patch_Backend_*.md`
- Global frontend patch temizliği: `Raporlar/Hard_Kapitalizm_Global_Patch_Cleanup_Frontend_Duzeltmeleri_2026-09-09.md`
- Production building insert patch: `Raporlar/PATCH_INSERT_LOCAL_SYNC_2026-09-11.md`
- Güncel veritabanı dökümü: `schema.sql` (canlı Supabase daha önceliklidir)

---

Bu belge “her teknik ayrıntının kopyası” değil, projenin neden bu yönde ilerlediğini ve yeni bir Codex oturumunun yanlış varsayımla çalışmasını önleyen yaşayan bağlamdır.
