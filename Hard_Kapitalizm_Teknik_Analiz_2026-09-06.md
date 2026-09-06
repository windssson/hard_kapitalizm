# Hard Kapitalizm — Teknik inceleme raporu

**İnceleme tarihi:** 6 Eylül 2026. İlk canlı veritabanı ölçümü: 23:18 Türkiye saati.  
**Frontend:** `windssson/hard_kapitalizm`, `origin/dashboarddesign`.  
**Sabitlenen commit:** [`07f8804dcfe7e72dbbdfd1a3212880397dee7863`](https://github.com/windssson/hard_kapitalizm/commit/07f8804dcfe7e72dbbdfd1a3212880397dee7863).  
**Canlı backend:** `kapitalizm`, proje referansı `lpiixtfxldhoyyppavyn`, PostgreSQL 17.6, `ap-northeast-1`.

## 1. Genel değerlendirme

**Bu sürüm için ilk öncelik performans değil, oyun ekonomisinin sunucu tarafında korunması ve veri tutarlılığıdır.** Oyuncunun kendi para/altın satırını doğrudan değiştirebilmesi, günlük ödül miktarını istemcinin belirlemesi ve bazı yetkili RPC’lerin gönderilen oyuncu kimliğine güvenmesi yayın öncesinde kapatılması gereken açıklar oluşturuyor.

Yeni genel depo ve marka dönüşümleri ilerlemiş; ancak raf iadesi, patent sonrası üretim ve satış geçmişinin ürün/markaya yazılması arasında somut uyumsuzluklar var. Bildirim cronunun başarılı görünmesi de bütün uyarıların gönderildiği anlamına gelmiyor: ihale uyarısındaki yanlış parametre tipi hata oluşturuyor ve fonksiyon bu hatayı gizliyor.

Mimariyi bütünüyle yeniden yazmak gerektiğine dair bir kanıt yok. Mevcut Flutter/Riverpod + PostgreSQL RPC düzeni korunabilir. Önce yetki sınırları, ardından stok/para işlemlerinin ortak kuralları, sonra veri senkronizasyonu ve ölçülmüş darboğazlar düzeltilmeli.

### Kapsam ve kanıt sınırı

- 201 uygulama Dart dosyasının envanteri ve statik taraması; kritik provider, oturum, bildirim, reklam, mağaza ve marka yollarının ayrıntılı okunması.
- 274 sabit RPC çağrı noktası, 182 farklı RPC adı ve parametre adlarının statik karşılaştırması.
- Canlı `public` şemasında 64 tablo, 259 fonksiyon tanımı, RLS politikaları, kısıtlar, tetikleyiciler ve indeksler.
- 14 aktif cron, son 24 saatin cron çalışma kayıtları, birikimli veritabanı/sorgu istatistikleri.
- Canlı `send-push` Edge Function v5 kaynak kodu ve dağıtım ayarı.
- 180 SQL dosyası, migration düzeni, 8 uygulama test dosyası ve Android release yapılandırması.

**Kod, veri, cron veya yetki değiştirilmedi.** Gerçek kullanıcıya bildirim gönderilmedi ve ekonomi açığını kullanarak para/stok üretilmedi. SQL incelemeleri salt okunurdu; ihale bildirimi imza hatası `EXPLAIN` ile, fonksiyon çalıştırılmadan doğrulandı. Flutter/Dart bu çalışma ortamında bulunmadığı için derleme, `flutter analyze`, cihaz testi veya Flutter test koşusu yapılmadı. Bulgular bütün dosyaların bütün davranışlarının eksiksiz test edildiği anlamına gelmez.

Kanıt etiketleri:

- **Doğrulandı:** canlı tanım/yetki/şema ya da kaynak kod doğrudan gösteriyor. Kullanıcı verisinde kötüye kullanım gerçekleştiği iddiası değildir.
- **Koşullu hata:** belirtilen girdide kod ve şema çelişiyor; canlı kullanıcı üzerinde tetiklenmedi.
- **Risk:** eşzamanlılık, ölçek veya ürün tercihine bağlı; hedefli test gerekir.

## 2. Öncelik tablosu

P0: ekonomi veya yetkilendirme sınırı aşılabilir; yayın engeli olarak ele alınmalı. P1: temel oyun akışı, veri doğruluğu veya yayın güvenilirliği etkileniyor. P2: performans, bakım ve kullanıcı deneyimi iyileştirmesi.

| Kimlik | Öncelik | Bulgu | Kanıt |
|---|---|---|---|
| K01 | P0 | Oyuncu para/altın, üretim ve ilerleme alanlarını doğrudan değiştirebilir | Canlı RLS + sütun yetkileri |
| K02 | P0 | Bazı RPC’ler oturum yerine istemcinin oyuncu ID’sine güveniyor | Canlı fonksiyon + EXECUTE |
| K03 | P0 | Günlük ödül miktarı ve tekrar kontrolü sunucuda korunmuyor | Canlı RPC + Flutter |
| K04 | P0 | İç stok ekleme yardımcıları istemciye açık | Canlı fonksiyon + EXECUTE |
| K05 | P0 | Fiyat ne kadar yükselirse yükselsin asgari talep kalıyor | Canlı satış formülü |
| K06 | P1 | Push gönderme servisi kimlik doğrulamasız; bildirim RPC’si de fazla açık | Canlı Edge + RPC |
| H01 | P1 | Raf iadesinde yeni depo satırı `slot_index` eksikliğiyle hata verir | Canlı kod + NOT NULL |
| H02 | P1 | Raf iadesi kapasite ve ağırlıklı maliyet kurallarını atlıyor | Canlı kod |
| H03 | P1 | Patent sonrası yeni marka çıkış kaydı yoksa üretim durur | Canlı kod + tetikleyiciler |
| H04 | P1 | Günlük satış kaydı ürün/marka/kalite değişimini karıştırıyor | Canlı UPSERT + UNIQUE |
| H05 | P1 | İhale push uyarısı yanlış tip nedeniyle sessizce başarısız | EXPLAIN ile 42883 |
| H06 | P1 | Üretim ve transfer eşzamanlılığında stok üzerine yazılabilir | Koddan yarış riski |
| H07 | P2 | Girdi yok uyarısı reçetenin gerçek ihtiyacını değerlendirmiyor | Canlı sorgu |
| H08 | P1 | Reklam ödülünde sunucu tarafı izleme doğrulaması yok | RPC + Flutter + Edge envanteri |
| P01 | P2 | Profil okuma, pahalı yazma ve hesaplama zinciri çalıştırıyor | Canlı çağrı zinciri |
| P02 | P2 | Üretim cronu bütün oyuncuları tek işlemde dolaşıyor | Canlı fonksiyon |
| P03 | P2 | Patch yanıtlarında sürüm/sıralama koruması yok | Flutter kodu |
| P04 | P2 | Hesap değişiminde yeni marka performansı önbelleği temizlenmiyor | Provider + SessionManager |
| P05 | P2 | Mağaza yenilemesi görünürlükten bağımsız çalışabilir | Timer kodu |
| O01 | P1 | Migration dosyaları ve canlı migration kaydı güvenilir eşleşmiyor | Repo + canlı geçmiş |
| O02 | P1 | Testler kritik RPC davranışlarını korumuyor; CI yok | Test kaynakları + repo |
| O03 | P1 | Android release debug anahtarıyla imzalanıyor | Gradle |
| O04 | P2 | Push dinleyicileri temizlenmiyor, bildirim tıklama akışı eksik | Flutter kodu |
| O05 | P2 | Sessiz hata yakalama yanlış boş ekran/başarı görünümü üretiyor | Flutter + SQL |
| O06 | P2 | İki fonksiyonda sabit search_path yok; diğer advisor sonuçları ayrıştırılmalı | Advisor + pg_proc |

## 3. Ekonomi ve yetkilendirme

### K01 — RLS var, ekonomik alan koruması yok

64 tablonun tamamında RLS etkin. Ancak `players` tablosunun kendi satırını güncelleme politikası yalnızca `auth.uid() = id` kontrolü yapıyor. `authenticated` rolü `cash`, `gold`, `level`, `experience`, `starter_pack_claimed` dahil 14 sütunda UPDATE yetkisine sahip. `players` üzerinde bu ekonomik değişiklikleri engelleyen bir uygulama tetikleyicisi de bulunmuyor.

Benzer şekilde kendi `production_inventory` satırlarının miktar/maliyeti, `building_constructions` zaman/params alanları, `building_boosts`, `player_product_quality_levels`, `player_missions` ve `player_achievements` alanları için yazma izinleri var.

**Etki:** başka oyuncuya erişmeden bile kendi parasını, stoğunu veya ilerlemesini değiştirme yolu açılıyor. RLS’nin sahiplik kontrolü oyunun işlem kurallarını uygulamıyor. `starter_pack_claimed` alanının geri alınabilmesi başlangıç paketinin tek kullanımlık kontrolünü de zayıflatıyor.

**Düzeltme:** ekonomik tablolarda istemci INSERT/UPDATE/DELETE yetkilerini daralt; yazmaları kuralları uygulayan RPC’lere taşı. Gerçekten düzenlenebilir profil alanlarına gerekiyorsa sütun düzeyinde yetki ver. Önce frontend’in doğrudan yazma noktalarını çıkart; izinleri körlemesine kapatma.

**Kabul testi:** gerçek `authenticated` rolündeki A oyuncusu kendi para/altın/stoğunu doğrudan değiştirememeli; izin verilen profil düzenlemesi ve normal satın alma RPC’si çalışmalı. [Supabase sütun güvenliği](https://supabase.com/docs/guides/database/postgres/column-level-security).

### K02 — Oyuncu parametresi gerçek oturum kimliğiyle eşleştirilmiyor

Canlı `set_store_slot_price` yalnızca `slot.player_id <> p_player_id` kontrolü yapıyor. İki değer de hedef oyuncuyu gösterebilir; `auth.uid()` doğrulaması yok. Fonksiyon `SECURITY DEFINER` ve `authenticated` tarafından çalıştırılabiliyor. `start_building_construction`, `set_store_slot_active`, bazı lojistik/üretim yardımcıları ve raf işlemlerinde benzer örüntüler var.

`process_player_production_entry` parametresinin varsayılanının `auth.uid()` olması da yeterli değil: açıkça gönderilen başka ID’yi karşılaştırmıyor. `get_player_operational_alerts` ise `coalesce(p_player_id, auth.uid())` kullanıyor ve `anon` rolüne açık; bir ID sağlanınca operasyon durumunu oturumsuz okuyabiliyor.

**Etki:** hedef kimlikler bilindiğinde başka oyuncunun oyun durumuna müdahale veya durumunu okuma. Her yetkili fonksiyonun açık olduğu söylenemez; çağrı zinciri bazında doğrulama gerekir.

**Düzeltme:** dış RPC sınırında oturumdan kimlik türet, parametre gerekiyorsa `IS DISTINCT FROM auth.uid()` ile doğrula. Cron/iç yardımcıları ayrı yetki grubuna veya API’ye açık olmayan şemaya ayır. İç çağrılar için gerekli yetkiyi koru.

**Kabul testi:** A oturumu B oyuncusunun mağaza fiyatını, inşaatını ve üretimini değiştirememeli; `anon` özel operasyon verisini okuyamamalı.

### K03 — Günlük ödül tekrar tekrar ve farklı tutarla alınabilir

`claim_daily_streak_reward(p_reward_cash, p_reward_gold)` tutarları doğrudan oyuncunun bakiyesine ekliyor. Sunucuda gün, ödül planı, önceki talep veya tekillik kontrolü yok. Flutter `DailyStreakNotifier` son talebi `SharedPreferences` içinde `daily_streak_count` ve `daily_streak_last_claimed` anahtarlarında saklıyor; anahtarlar oyuncuya özel değil.

**Etki:** istemci değişikliği veya doğrudan RPC çağrısıyla ödül miktarı/tekrarı manipüle edilebilir. Normal kullanımda başka cihaz, yeniden kurulum veya aynı cihazda hesap değiştirme de tutarsızlık yaratır.

**Düzeltme:** RPC tutar kabul etmesin. Ödül ve seri sunucuda belirlensin; oyuncu+oyun günü için UNIQUE kayıt ve oyuncu kilidiyle tek işlemde ödeme yapılsın. Yerel kayıt yalnızca görüntüleme önbelleği olsun.

**Kabul testi:** aynı gün iki cihazdan eşzamanlı talebin yalnızca biri ödeme üretmeli; tekrar aynı sonucu güvenle dönmeli. [Frontend kaynağı](https://github.com/windssson/hard_kapitalizm/blob/07f8804dcfe7e72dbbdfd1a3212880397dee7863/lib/features/mission/data/daily_streak_provider.dart).

### K04 — Stok ekleme yardımcıları dışarıdan çağrılabiliyor

`add_product_to_warehouse` ve `add_product_to_warehouse_with_brand` canlıda `authenticated` için çalıştırılabilir `SECURITY DEFINER` fonksiyonlar. Markalı yardımcı, gönderilen ürün/miktar/maliyeti depoya ekliyor; alışveriş veya tamamlanmış transfer kanıtı aramıyor. `p_release_reserved_capacity = true` yolunda normal kapasite kontrolü de atlanıyor.

**Etki:** bunlar güvenilir iç yardımcı olması gerekirken istemci API’si gibi kullanılabilir; karşılığında kaynak düşmeden stok ekleme yolu açılır. K01 düzeltilse bile bu yol ayrıca kapatılmalı.

**Düzeltme:** istemci EXECUTE yetkisini kaldır; stok eklemeyi yalnızca doğrulanmış alım, üretim veya transfer işleminden çağır. Rezervasyon çözme işlemini transfer kimliği ve gerçek rezervasyonla bağla.

**Kabul testi:** oturum açmış kullanıcı yardımcıyı doğrudan çağıramamalı; normal transfer tamamlanınca kaynak+hedef toplamı korunmalı.

### K05 — Satış talebine taban koymak sınırsız fiyatı kârlı yapıyor

`open_store_detail_page` şu formülü kullanıyor:

```sql
v_price_multiplier := greatest(0.05, 1.0 / (v_price_ratio ^ 1.5));
```

Fiyat belirleyen canlı RPC yalnızca fiyatın pozitif olmasını şart koşuyor. Böylece fiyat çok yüksek olsa da taban talep sıfıra inmiyor; yeterli süre geçince bir ürün satılabiliyor ve gelir gönderilen yüksek fiyatla hesaplanıyor. Sayısal veri tipinin sınırları dışında ekonomik bir üst sınır yok.

**Etki:** yetkilendirme düzeltildikten sonra bile yasal fiyat belirleme akışıyla oyunun para dengesi bozulabilir.

**Düzeltme:** gerçekçi fiyat aralığını sunucuda uygula veya aşırı fiyatlarda talebi sıfıra indirebilen talep modeli kullan. Fiyat değişikliği öncesi biriken satışı eski fiyatla kapat; mevcut fiyat RPC’si bunu yapmadığından geçmiş süre yeni fiyatla hesaplanabilir.

**Kabul testi:** baz fiyatın 1, 10 ve 1.000 katındaki beklenen gelir/saati karşılaştır; aşırı fiyat artırmak geliri sınırsız büyütmemeli. [Satış fonksiyonunu içeren son değişiklik](https://github.com/windssson/hard_kapitalizm/blob/07f8804dcfe7e72dbbdfd1a3212880397dee7863/supabase/migrations/2026-09-06_fix_brand_backend_and_performance.sql).

### K06 — Push gönderme sınırı korunmuyor

Canlı `send-push` v5 için `verify_jwt=false`. Handler içinde alternatif imza, paylaşılan sır, kullanıcı doğrulaması veya yetki denetimi yok. İstek gövdesindeki token/başlık/mesaj doğrudan FCM’e gönderiliyor. Ayrıca `send_game_notification` herhangi bir `p_player_id` alıyor ve `authenticated` tarafından çalıştırılabiliyor.

**Etki:** bilinen cihaz tokenına yetkisiz içerik gönderme ve servis kaynaklarını tüketme riski. RPC yolu, kullanıcı ID’siyle onun kayıtlı tokenlarına gönderimi de mümkün kılıyor.

**Düzeltme:** servisler arası doğrulanmış çağrı kur; göndereni sunucuda yetkilendir. Kullanıcılar keyfî bildirim üretmemeli. OAuth erişim tokenını geçerlilik süresince yeniden kullanmak, her bildirime ayrı Google token isteğini de azaltır.

**Kabul testi:** kimliksiz ve sıradan kullanıcı isteği reddedilmeli; yetkili olaydan üretilmiş bildirim test cihazına ulaşmalı. Kimlik doğrulamasını tek başına açmak mevcut başlıksız `pg_net` çağrılarını keser; iki uç birlikte değişmeli. [Edge kaynak kodu](https://github.com/windssson/hard_kapitalizm/blob/07f8804dcfe7e72dbbdfd1a3212880397dee7863/supabase/functions/send-push/index.ts), [Supabase Edge güvenliği](https://supabase.com/docs/guides/functions/auth).

## 4. Oyun akışı ve veri doğruluğu

### H01 — Dolu raftan iade, yeni depo satırında hata verir

`clear_store_slot_product` ve `set_store_slot_product_from_warehouse_slot`, rafta eski stok varsa aynı şehirdeki depoya geri koyuyor. Eşleşen depo satırı bulunamazsa INSERT yapıyorlar; fakat sütun listesinde `slot_index` yok. Canlı `warehouse_slots.slot_index` NOT NULL ve varsayılanı yok; bu değeri tamamlayan tetikleyici de yok.

**Koşullu hata:** rafta stok + depoda aynı ürün/kalite/marka satırı yok ⇒ NOT NULL ihlali, işlem geri alınır. Bu bulgu veri kaybının gerçekleştiği iddiası değildir; normalde işlem hata vererek rollback olur.

**Düzeltme:** depo satırı bulma/oluşturmayı tek bir güvenilir yardımcıda birleştir; kilit altında geçerli slot numarası üret. **Test:** dolu raftaki ürünü, depoda eski ürünün satırı silindikten sonra değiştir ve temizle. [Raf temizleme](https://github.com/windssson/hard_kapitalizm/blob/07f8804dcfe7e72dbbdfd1a3212880397dee7863/supabase/migrations/2026-09-03_store_cleanup_and_sell_alignment.sql), [ürün değiştirme](https://github.com/windssson/hard_kapitalizm/blob/07f8804dcfe7e72dbbdfd1a3212880397dee7863/supabase/migrations/2026-09-06_fix_store_slot_cost_return.sql).

### H02 — Aynı iade yolları kapasite ve maliyet kurallarını atlıyor

Eşleşen depo satırı varsa yalnızca `quantity = quantity + v_slot.quantity` yapılıyor; kapasite kontrolü ve birleşen stokların ağırlıklı maliyet hesabı yok. Aktif genel depo bulunamazsa kod iade yapmadan raftaki miktarı sıfırlayan kısma ilerliyor.

**Etki:** dolu depoya kapasite üstü iade, yanlış stok maliyeti/kâr; genel depo yokluğu halinde stok kaybı. Son koşulun mevcut veride oluştuğu gösterilmedi.

**Düzeltme:** iade edilecek depoyu ve kapasiteyi doğrulamadan rafı temizleme. Miktar ve toplam maliyeti birlikte taşı. **Test:** dolu depo; farklı birim maliyetli aynı ürün; aktif depo bulunmaması. H01’in slot numarası düzeltmesi tek başına yeterli değil.

### H03 — Patent, aktif üretimin eşleşen çıkış kaydını oluşturmayabiliyor

`patent_brand_company_product` aktif üretim slotları, fabrikalar ve madenlerde `brand_id` değiştiriyor. `production_inventory` için yeni markalı çıkış kaydı oluşturmuyor. Üretim fonksiyonlarının INNER JOIN koşulu ise ürün/kalite yanında marka eşitliği arıyor. Üretim marka tetikleyicileri `UPDATE OF product_id` için bağlı; yalnızca `brand_id` değişmesi onları çalıştırmıyor.

**Koşullu hata:** daha önce markasız üretim yapan tesiste sadece eski çıkış kaydı varsa patentten sonra eşleşme bulunmaz; tesis döngüye hiç girmediğinden üretim sessizce atlanır. Canlıda şu anda üretim tesisi olmadığı için etkilenmiş oyuncu örneği sayılmadı.

**Düzeltme:** patent işlemi yeni üretim markası için boş çıkış kaydını güvenle oluştursun. Eski markasız stoğu yeni markaya dönüştürmesin. **Test:** stoklu Q2 tesisinde patent al; eski stok aynı kalsın, sonraki üretim yeni markalı satıra yazılsın. [Patent değişikliği](https://github.com/windssson/hard_kapitalizm/blob/07f8804dcfe7e72dbbdfd1a3212880397dee7863/supabase/migrations/2026-09-06_fix_brand_backend_and_performance.sql).

### H04 — Aynı rafta farklı ürünlerin günlük satışları birleşiyor

Canlı UNIQUE anahtarı `(performance_date, store_slot_id)`. UPSERT toplam adet/ciro/kârı artırıyor, `product_name` ve `brand_id` alanlarını son satışla güncelliyor; `product_id` ve `quality_level` eski kayıttan kalabiliyor.

**Örnek:** sabah aynı rafta markasız domates, akşam markalı biber satışı. Tek günlük satırda toplamlar birleşir; eski ürün ID’si, yeni isim ve yeni marka birlikte bulunabilir. `get_player_brand_performance` bu tabloyu marka bazında topladığından önceki satışlar son markaya mal edilebilir.

**Düzeltme:** raporun ayrım anahtarına ürün/kalite/markayı kat veya değişmez satış hareketlerinden günlük özet üret. Mevcut birleştirilmiş geçmişi tam ayrıştırmak kaynak hareket kaydı olmadan mümkün olmayabilir. **Test:** aynı gün aynı rafta iki ürün ve iki marka; ürün/marka toplamları satışlarla birebir eşleşmeli.

### H05 — İhale uyarısında doğrulanmış imza hatası

`process_operational_alerts_push_notifications` ihale döngüsünde `send_game_notification` altıncı parametresine `jsonb_build_object(...)` gönderiyor. Canlıda tek imza var ve altıncı parametre `uuid`. Fonksiyonu çalıştırmayan EXPLAIN denemesi şu hatayı verdi:

```text
42883: function public.send_game_notification(uuid, text, text, text, text, jsonb, boolean) does not exist
```

Bu çağrı `EXCEPTION WHEN OTHERS THEN NULL` içinde. Dolayısıyla uygun ihale bulunduğunda bildirim ve cooldown kaydı üretilmeden hata gizlenir; üst işlem yine başarılı dönebilir.

**Düzeltme:** doğru entity ID ve tipini gönder veya açık, tutarlı bir payload sözleşmesi tanımla. İşlem özeti başarılı/başarısız gönderim sayılarını ayırsın. **Test:** bitmesine iki saatten az kalmış teslim edilmemiş ihale, bir bildirim ve bir cooldown kaydı üretmeli. [Çağrı kaynağı](https://github.com/windssson/hard_kapitalizm/blob/07f8804dcfe7e72dbbdfd1a3212880397dee7863/supabase/migrations/2026-09-01_operational_alerts_push_scheduler.sql).

### H06 — Üretim/transfer arasında kayıp güncelleme riski

Üretim fonksiyonları oyuncu bazlı advisory lock alıyor; bu üretim çağrılarını birbirine karşı koruyor. Ancak çıkış miktarı döngünün SELECT sonucundan okunuyor ve sonradan `quantity = v_output_quantity_after` olarak yazılıyor. Çıkış satırı ilk okuma anında `FOR UPDATE` ile korunmuyor. Transfer yolu çıkış stokunu satır kilidiyle düşürüyor, fakat aynı üretim advisory lock’unu kullanmıyor.

**Risk senaryosu:** üretim 100 stok okur; transfer 20 düşürür ve commit eder; üretim eski 100 üzerine 10 ekleyip 110 yazar. Beklenen 90 yerine 110 olabilir. Bu interleaving canlıda çalıştırılmadı; tarihî 9 deadlock bu özel senaryonun kanıtı değildir.

**Düzeltme:** üretim ve transferde ortak kilit sırası; miktar/maliyeti kilit altında yeniden oku ve hesapla. Paylaşılan çıkış kaydına yazan birden fazla slot da aynı test grubunda ele alınmalı. **Test:** iki bağlantıyla kontrollü üretim+transfer eşzamanlılığı; stok ve toplam maliyet korunmalı.

### H07 — Hammadde uyarısı üretim engelini doğru temsil etmiyor

Uyarı sorgusu herhangi bir input satırında pozitif miktar varsa “hammadde yok” demiyor. Reçetedeki diğer girdinin bitmesi, gereken kalitede olmaması veya bir üretime yetmemesi değerlendirilmemiş. `pending_quantity` de kullanılabilir stok gibi toplanıyor.

**Etki:** üretim durmuşken uyarı çıkmayabilir. **Düzeltme:** üretim fonksiyonunun kullandığı reçete/kalite/miktar koşullarından ortak bir `blocked_reason` üret. **Test:** iki girdili reçetede yalnızca bir girdi mevcutken uyarı görünmeli. Kullanıcıya görünen tarla/çiftlik isimleri için projedeki mevcut `farm/field` eşlemesi esas alınmalı; İngilizce isimlerden tek başına hata çıkarılmamalı.

### H08 — Ödüllü reklam sunucuda doğrulanmıyor

Flutter `onUserEarnedReward` sonrası RPC çağırıyor. Backend kullanım limiti ve cooldown tutuyor; ancak tamamlanmış reklamı kanıtlayan doğrulanmış işlem/receipt aramıyor. İncelenen tek Edge Function push gönderimi; reklam doğrulama endpoint’i yok.

**Etki:** reklam izlenmeden günlük sınırlar içinde ödül alınabilir. Mevcut limitler yararlı fakat izleme kanıtı değildir. **Düzeltme:** AdMob SSV doğrulaması ve tek kullanımlık ödül işlemi ekle. **Test:** doğrulanmış callback olmadan ödül yok; aynı callback iki kez ödül üretmez. [Google SSV](https://developers.google.com/admob/flutter/ssv), [istemci reklam akışı](https://github.com/windssson/hard_kapitalizm/blob/07f8804dcfe7e72dbbdfd1a3212880397dee7863/lib/core/ads/rewarded_ad_action_flow.dart).

## 5. Performans ve istemci durum yönetimi

### Ölçümlerin doğru yorumu

İnceleme anında canlıda **4 oyuncu, 3 mağaza, 3 depo; 0 fabrika, 0 maden, 0 field, 0 farm, 0 üretim envanteri satırı** vardı. Bu nedenle mevcut hızlı cron süreleri gerçek üretim yükünü temsil etmiyor.

Son 24 saatte mevcut cronlar için **449 çalışma, tamamı succeeded**. Örnekler:

| İş | Sıklık | Çalışma | Ortalama toplam süre | En yüksek |
|---|---|---:|---:|---:|
| Üretim | Saatlik | 24 | 109 ms | 153 ms |
| Operasyon push taraması | 30 dk | 48 | 176 ms | 281 ms |
| Transfer tamamlama | 15 dk | 96 | 114 ms | 227 ms |
| İhale sürdürme | 30 dk | 48 | 174 ms | 258 ms |
| İnşaat tamamlama | 15 dk | 96 | 61 ms | 112 ms |

`pg_stat_statements` sıfırlanma zamanı 5 Mayıs 2026; aşağıdaki değerler **son sürüme veya son 24 saate ait değildir**:

| Sorgu | Çağrı | Ortalama | Tarihî en yüksek |
|---|---:|---:|---:|
| get_player_profile RPC | 6.019 | 43,8 ms | 2.107 ms |
| open_store_detail_page RPC | 2.269 | 74,6 ms | 1.461 ms |
| get_homepage_dashboard RPC | 1.305 | 85,2 ms | 688 ms |
| bootstrap_game_session RPC | 1.010 | 146,9 ms | 677 ms |

`pg_stat_database` 9 deadlock ve yaklaşık 1,46 TB birikimli temp yazımı gösteriyor; sıfırlama zamanı 30 Nisan. Eski testler, yönetim sorguları ve önceki sürümler bu sayaçlarda var. **Bunları mevcut oyunun günlük tüketimi veya bugünkü darboğazı olarak sunmak yanlış olur.** `production_inventory.idx_scan` yaklaşık 30,76 milyon; bu da birikimli tarama sayısı, yeni 24 saatlik RPC sayısı değil.

### P01 — Profil getter’ı yazma ve pahalı hesaplama yapıyor

`get_player_profile`, başarı satırlarını hazırlıyor/senkronize ediyor, şirket değeri hesaplıyor ve leaderboard yeniliyor. Canlı fonksiyon tanımlarının 37’sinde `get_player_profile(` referansı var; bu sayı getter’ın kendi tanımını da içerir. `changed.player` için tam profil üretmek küçük aksiyonların maliyetini büyütüyor.

**Düzeltme:** salt okunur hafif oyuncu payload’ını ayır; para/altın/XP patch’i yalnızca değişen alanları dönsün. Başarım/leaderboard hesaplaması ilgili olaylarda veya kontrollü periyotta yapılsın. **Ölçüm:** bir raf aksiyonunda DB yazma sayısı, süre ve yanıt byte’ı; önce/sonra aynı veri setinde karşılaştır. [Profil tanımı](https://github.com/windssson/hard_kapitalizm/blob/07f8804dcfe7e72dbbdfd1a3212880397dee7863/supabase/migrations/2026-09-04_cleanup_auth_rpcs.sql).

### P02 — Üretim cronunda tek işlem ve oyuncu döngüsü

Aktif üretimi olmayan oyuncuları elemek ve bitmiş boost/yükseltmeleri bir kez işlemek iyi. Ancak tüm uygun oyuncular tek fonksiyon çağrısı/transaction içinde dolaşılıyor; bir oyuncudaki hata tüm çalışmayı geri alabilir, kilitler işlem sonuna kadar birikebilir.

**Düzeltme:** yeterli veriyle ölçümden sonra sınırlı oyuncu grupları ve kaldığı yeri izleyen işlemleme kullan. Tesis/oyuncu bazında hata görünürlüğü ekle. Bazı tamamlama görevleri hem kendi cronundan hem üretim cronundan çağrılıyor; yinelenen iş maliyetini ölç. Saat başında birçok cron çakışıyor; gerekirse dakikalara yay.

### P03 — Patch yanıtları eski sonuçları ayırt etmiyor

`PlayerNotifier.applyChanges`, `fullPlayer` varsa doğrudan değiştiriyor; sürüm kontrolü yok. Farklı ekranlardan eşzamanlı aksiyonların yanıtları ters sırada gelirse eski bakiye son durumu örtebilir. Kısmi patch, henüz state yoksa düşürülüyor. `PlayerChanges`, `id` içeren payload’ı tam oyuncu olarak yorumlayabildiği için gelecekte ID’li kısmi payload göndermek de alanların varsayılanlarla değişmesi riskini doğurur.

**Düzeltme:** sunucu oyuncu/entity sürümü veya sıralanabilir mutation numarası; eski yanıtı uygulamama; ilk yüklemeyle patch’in uzlaştırılması. Tam snapshot ve delta sözleşmelerini açıkça ayır. **Test:** geciktirilen eski yanıt yeni bakiyeyi geri alamamalı. [Player provider](https://github.com/windssson/hard_kapitalizm/blob/07f8804dcfe7e72dbbdfd1a3212880397dee7863/lib/features/auth/data/player_provider.dart), [patch ayrıştırıcı](https://github.com/windssson/hard_kapitalizm/blob/07f8804dcfe7e72dbbdfd1a3212880397dee7863/lib/core/models/mutation/player_changes.dart).

### P04 — Yeni marka performansı provider’ı hesap değişiminden kopuk

`playerBrandPerformanceProvider` oturum kimliğini `watch` etmiyor ve `SessionManager.invalidateAllGameProviders` içinde yok. Provider uygulama kapsamındayken A’dan B’ye geçildiğinde önceki performans elle yenilenene kadar kalabilir. Bu backend veri sızıntısı değil, cihazdaki eski state’in gösterilmesi riskidir.

**Düzeltme:** oturum kimliğine bağımlı provider veya kullanıcı ID’siyle family; merkezi oturum temizliğine ekleme. **Test:** aynı uygulama sürecinde iki hesap arasında geçiş. [SessionManager](https://github.com/windssson/hard_kapitalizm/blob/07f8804dcfe7e72dbbdfd1a3212880397dee7863/lib/core/managers/session_manager.dart).

### P05 — Mağaza timer’ı ekran görünürlüğünü denetlemiyor

Store detail her dakika yeniliyor. `mounted` ve devam eden yenileme kontrolü var, dispose’da iptal de var; fakat alttaki route hâlâ mounted iken görünür olup olmadığını kontrol etmiyor. Uygulama lifecycle kontrolü yalnızca resumed olayında ekstra çağrı yapıyor.

**Düzeltme:** route görünürlüğü ve aktif uygulama durumu ile sınırla; mümkünse sunucunun `next_check_at` bilgisini kullan. **Test:** mağazadan alt sayfaya geçince ve uygulama arka plana alınınca gereksiz çağrı sayısını ölç. [Timer kaynağı](https://github.com/windssson/hard_kapitalizm/blob/07f8804dcfe7e72dbbdfd1a3212880397dee7863/lib/features/store/ui/store_detail_screen.dart).

### Bölge ve gerçek kullanıcı gecikmesi

Backend `ap-northeast-1` bölgesinde. Türkiye’den mobil erişimde ağ gidiş-dönüş süresi, yukarıdaki DB sürelerine eklenir; cihazdan ölçülmedi. SQL’i hızlandırmadan önce açılış ve ana aksiyonların ağ+DB+render sürelerini ayrı ölçmek gerekir. Ölçmeden proje bölgesi değiştirmek önerilmiyor.

## 6. Bakım, test ve yayın

### O01 — Migration geçmişi yeniden kurulum için yeterince güvenilir değil

Repo içinde SQL’ler hem `supabase/` kökünde hem `supabase/migrations/` altında. Migration dizininde tarihleri aynı olan `2026-09-04_...` benzeri dosyalar var; benzersiz standart timestamp sürümleri kullanılmıyor. Canlı migration tablosunun en yeni kaydı 3 Eylül; buna rağmen 4–6 Eylül işlevleri canlıda mevcut. Bu, son değişikliklerin hiç uygulanmadığını değil, uygulanmış durumun migration kaydıyla izlenemediğini gösteriyor. `supabase/config.toml` da yok.

**Düzeltme:** canlı şemayı esas alan doğrulanmış başlangıç sürümü ve benzersiz sıralı migration zinciri oluştur. Eski yama dosyalarını uygulanabilir zincir ile arşiv olarak ayır. Temiz ortamda baştan kurulum ve schema diff doğrulaması yap. [Migration klasörü](https://github.com/windssson/hard_kapitalizm/tree/07f8804dcfe7e72dbbdfd1a3212880397dee7863/supabase/migrations).

### O02 — Test adları geniş, gerçek koruma dar

8 test dosyasında 41 `test/testWidgets` bildirimi bulundu. Altı aksiyon testi uygulama kodunu import etmiyor; kendi yerel hesaplamalarını/örneklerini test ediyor. Örneğin banka testi 12 taksit için %10 varsayıyor, canlı `take_loan` %12 kullanıyor. Testin geçmesi backend ile uyumu kanıtlamıyor. Model testleri gerçek model kodunu kullanıyor; bu olumlu. Repo içinde `.github` workflow dizini yok ve incelenen branch koruması kapalı.

**Düzeltme:** önce bu rapordaki P0/P1 senaryolarını gerçek fonksiyonlara karşı izole veritabanında test et. İki oturumlu yetki, eşzamanlı transfer/üretim, günlük tek ödeme ve RPC yanıt modeli sözleşmeleri öncelikli. Ardından `flutter analyze`, test ve build için CI kapısı. Mevcut testleri silmek gerekmiyor; entegrasyon kapsamı eklenmeli.

### O03 — Release yapılandırması geliştirme ayarlarında

Android `release` bloğunda `signingConfig = signingConfigs.getByName("debug")` var. Reklam servisi Android/iOS için test reklam ID’lerini sabit döndürüyor. `pubspec.yaml` sürümü `1.0.0+1`; build sırasında override edilip edilmediği bu incelemede bilinmiyor.

**Düzeltme:** güvenli release/upload signing yapılandırması; geliştirme/üretim reklam ayrımı; otomatik versionCode. Test ID’leri test aşamasında doğrudur, gelir üreten yayın yapılandırması değildir. [Gradle](https://github.com/windssson/hard_kapitalizm/blob/07f8804dcfe7e72dbbdfd1a3212880397dee7863/android/app/build.gradle.kts).

### O04 — Push yaşam döngüsü ve tıklama yönlendirmesi eksik

`onMessage` ve `onTokenRefresh` subscription’ları tutulmuyor; `stopTracking()` boş. Yeniden initialize döngüleri dinleyici biriktirebilir. Token önbelleği kullanıcı ID’siyle anahtarlanmıyor. Uygulama kodunda `onMessageOpenedApp` veya `getInitialMessage` kullanımı bulunmadı; Edge payload’ı yalnızca `click_action` ve `player_id` içeriyor.

**Düzeltme:** subscription’ları iptal et; kullanıcı+token eşleşmesini izle; bildirim entity/route payload’ını tanımla ve soğuk/sıcak açılış yönlendirmesini işle. **Test:** çıkış/giriş döngüsünde tek dinleyici, tek kayıt; bildirime basınca ilgili ekran. [Push servisi](https://github.com/windssson/hard_kapitalizm/blob/07f8804dcfe7e72dbbdfd1a3212880397dee7863/lib/features/notification/data/push_notification_service.dart).

### O05 — Hata görünürlüğü zayıf

Mağaza listesi hata alınca boş liste dönüyor; marka performansı hatada sıfır model dönüyor; oturum bootstrap bazı hataları yutuyor. Kullanıcı “işletmem kayboldu/cirom sıfır” görebilir. Push SQL’inde HTTP istek ID’si izlenmiyor; durable retry/teslimat durumu yok. `net._http_response` incelemesinde son 24 saat filtresinde kayıt çıkmadı; bu tablonun saklama davranışı nedeniyle “hiç bildirim gönderilmedi” sonucu çıkarılmadı.

**Düzeltme:** boş veri ile hata durumunu ayır; request/mutation ID ve yapılandırılmış hata kaydı; kritik gönderimlerde sınırlı retry ve teslimat durumunu izleme. **Test:** ağı kesince önceki veriyi koruyan hata durumu; FCM geçici hatasında izlenebilir yeniden deneme.

### O06 — Advisor sonuçları ve search_path

| Advisor | Sayı | Yorum |
|---|---:|---|
| anon SECURITY DEFINER EXECUTE | 22 | Kataloglar kasıtlı olabilir; özel/helper fonksiyonlar incelenmeli |
| authenticated SECURITY DEFINER EXECUTE | 190 | Tek başına açık sayısı değildir; sahiplik ve iş kuralı kontrolü gerekir |
| Değişebilir search_path | 2 | patent_brand_company_product, get_player_brand_performance |
| RLS etkin, politika yok | 1 | player_alert_push_logs; yalnızca backend kullanıyorsa doğru olabilir |
| RLS auth initplan | 3 | player_notifications politikaları; satır başı çağrıyı azaltma fırsatı |
| Kullanılmayan indeks | 15 | Küçük/sıfırlanmış test verisiyle otomatik silme gerekçesi değil |
| Sızmış parola koruması kapalı | 1 | Parola tabanlı giriş etkinse anlamlı; auth yöntemine göre değerlendirilmeli |

İki fonksiyon için sabit, güvenilir `search_path` kullan. Çoğu nesne zaten şema nitelikli olduğundan bu uyarıyı tek başına kanıtlanmış exploit olarak değerlendirmedim. Bildirim RLS politikalarında `(select auth.uid())` kullanımı ölçülebilir bir optimizasyon adayıdır. `store_daily_performance` üzerinde aynı günlük slot tekilliğini kapsayan iki UNIQUE kısıt var; FK bağımlılıkları incelenerek gereksiz indeks maliyeti azaltılabilir.

[Search path açıklaması](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable), [anon fonksiyon erişimi](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable), [authenticated fonksiyon erişimi](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable), [RLS initplan](https://supabase.com/docs/guides/database/database-linter?lint=0003_auth_rls_initplan), [politikasız RLS](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy), [parola koruması](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection), [kullanılmayan indeks](https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index).

## 7. Sağlam taraflar ve bulunmayan problemler

- 182 sabit RPC adının tamamı canlıda var ve `authenticated` için EXECUTE mevcut. Statik çıkarılabilen `p_...` parametre adlarında uyumsuzluk çıkmadı. Dinamik payload/yanıt tipleri için bu tam sözleşme testi değildir.
- Canlı 259 fonksiyonda aynı isimli overload yok. Önceki overload türü hatanın şu anda sürdüğüne dair bulgu yok.
- Bütün public tablolarında RLS açık; public view/materialized view bulunmadı.
- Son 24 saat cron durumlarında başarısız çalışma yok; içeride yutulan hatalar bundan ayrı.
- İncelenen canlı veride negatif oyuncu bakiyesi, negatif depo miktarı/maliyeti veya aynı şehirde mükerrer aktif genel depo bulunmadı.
- Üretim fonksiyonlarında advisory lock, input satırlarında sıralı kilit ve stok/maliyet için veritabanı kısıtları var. Bunlar yararlı; bütün yazma yolları aynı kurallara bağlanmalı.
- Yeni transfer yollarında üretim birimi sahipliği ve aynı şehirde genel depo kuralı uygulanıyor.
- `pubspec.lock` var. Bağımlılıklar tamamen yeniden çözülmek zorunda değil.
- Kaynakta hedefli özel anahtar/sb_secret taramasında anahtar materyali bulunmadı. Bu tam git geçmişi/tedarik zinciri güvenlik taraması değildir. İstemci publishable/anon anahtarını tek başına sır sızıntısı saymadım.

## 8. Önerilen uygulama sırası

1. **Ekonomi güvenliği:** K01–K05. İstemci yazma ve helper EXECUTE envanteri; gerçek oturum kontrolü; sunucu günlük ödülü; güvenli fiyat modeli. Her değişiklikten sonra normal oyun aksiyonları ve A/B oyuncu izolasyon testi.
2. **Stok ve marka doğruluğu:** H01–H04 ve H06. Tek iade/stok yardımcısı, atomik kapasite+maliyet, patent sonrası yeni çıkış satırı, ürün/marka ayrımlı satış kayıtları, ortak kilit sırası.
3. **Bildirim ve reklam:** K06, H05, H07, H08, O04–O05. Doğrulanmış iç gönderim, doğru payload, görünür hata/teslimat durumu, SSV.
4. **Tekrarlanabilir yayın:** O01–O03. Canlı şemadan doğrulanmış migration zinciri, gerçek entegrasyon testleri, CI ve release signing.
5. **Ölçülmüş performans:** P01–P05. Hafif profil/patch, state sürümü, oturum temelli cache, görünür ekranda yenileme, sonra gerçekçi üretim yükünde cron gruplama.

Öncelikli regresyon paketi: iki oyuncu arasında yetki; aynı gün iki ödül talebi; aynı ürünün farklı markaları; dolu depoya raf iadesi; yeni depo slotu oluşturma; patent sonrası üretim; aynı gün raf ürün değişimi; eşzamanlı üretim/transfer; yanlış sırada dönen patch; hesap değişimi; tek ihale uyarısı; temiz ortamdan migration kurulumu.

## 9. Bu raporun cevaplamadığı alanlar

- Gerçek cihaz FPS, bellek, açılış süresi, küçük ekran ve büyük yazı boyutu davranışı ölçülmedi.
- Auth panelindeki bütün sağlayıcı/rate-limit ayarları, yedek/PITR ve felaket kurtarma erişilebilir kaynaklarla doğrulanmadı.
- Postgres/Auth/Edge ham servis logları için bu oturumda log aracı sunulmadı; cron kayıtları ve SQL istatistikleri incelendi.
- Ödeme/mağaza onay akışı, uygulama içi satın alma fiş doğrulaması ve mağazaya gönderilmiş gerçek binary incelenmedi.
- Gerçek üretim tesisleri olmayan bu canlı veri setinden 1.000–10.000 oyuncu kapasitesi çıkarılamaz. İzole yük testi gerekir.
- 6.510 satırlık market ekranı ve 5.000 satırı aşan detay ekranları bakım riskini büyütüyor; salt dosya uzunluğu performans hatası kanıtı değildir. Parçalama, davranış testleri kurulduktan sonra yapılmalı.

**Karar önerisi:** yayını genişletmeden önce P0 bulgularını ve stok/marka P1 hatalarını kapat. Mimariyi baştan yazmak yerine mevcut işlem sınırlarını güvenli, tutarlı ve test edilebilir hale getir.
