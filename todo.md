# Modul TODO Durumu ve Proje Ozeti

Bu dosya aktif gelistirme durumunu ozetler. Yuzdeler "ozellik kapsami + entegrasyon olgunlugu + cihaz testi guveni" bazli tahmini muhendislik notudur.

## Genel Durum

- Istemci (Flutter UI): ~%97
- Veritabani / RPC (Supabase): ~%96
- Performans refactor fazi: ~%96
- UX / UI iyilestirme fazi: ~%90
- Progression sistemleri (EXP + Gorev + Rozet): ~%86
- Bildirim sistemi: ~%82
- Gercek cihaz test guveni: ~%74

---

## Ana Moduller

- [x] Splash / Oyun Acilisi - %98
  - Oyuncu girisi, due islemler ve sabit katalog preload akisi kuruldu.
  - Sabit tablolar oyun basinda cekilip cache'ten kullaniliyor.
  - Kalan is: release cihaz testinde acilis bekleme / hata durumlarini izlemek.

- [x] Auth / Profil - %93
  - Cihaz tabanli otomatik giris calisiyor.
  - Profil ekranina EXP ve rozet ozeti eklendi.
  - Kalan is: profil UX son parlatma ve avatar akisi testi.

- [x] Home / AppBar - %90
  - Ust bar sadeletildi, gorev ve bildirim ikon/badge akisi eklendi.
  - Home kartlarinda bildirim/gorev alani daha kompakt hale getirildi.
  - Kalan is: dar ekran tasma testi ve badge sayac senaryolari.

- [x] Market - %94
  - Satin alma, hedef secimi, store/warehouse teslimat akisi calisiyor.
  - PGRST uuid hatasi icin bos `listingId` senaryosu duzeltildi.
  - Satin alma popup'i sadelestirildi, numpad kullaniliyor.
  - Debug loglar release'te sessiz kalacak sekilde `kDebugMode` arkasina alindi.
  - Kalan is: store satin alma, warehouse satin alma ve transferli alim cihaz testi.

- [x] Logistics - %94
  - Lojistik sirket, arac, yakit, kiralama ve transfer secim akislari calisiyor.
  - Gereksiz invalidate zincirleri daraltildi.
  - Kalan is: arac secim popup'i, transfer baslatma ve refresh senaryolari testi.

- [x] Transfer Map - %95
  - Aktif/gecmis transfer takibi calisiyor.
  - Etkilenen hedeflere gore refresh mantigi kuruldu.
  - Kalan is: transfer tamamlaninca hedef ekranlarin dogru guncellenmesini cihazda test etmek.

- [x] Warehouse - %100 KILITLI
  - Liste/detail state akisi notifier tabanli hale getirildi.
  - Depo tipi seciminde kabul edilen urunler gosteriliyor.
  - Miktar girislerinde ozel numpad ve hizli miktar kisayollari aktif.
  - Liste kartlari, detay kapasite ozeti ve slot kartlari cihaz testiyle sadelestirildi.
  - Kapasite dagilimi `m3` cinsinden gosteriliyor; stok/yolda/bos alan ayrimi netlestirildi.
  - Depodan depoya transfer hedefleri artik urunu kabul eden aktif depolara filtreleniyor.
  - Cihaz testi tamamlandi; bu modul yeni bug disinda kilitli kabul ediliyor.

- [x] Store - %100 KILITLI
  - Liste ve detay sorgulari tekillestirildi.
  - History/performance ekranlari dirty-flag mantigina baglandi.
  - Magaza tipi seciminde satilabilen urunler gosteriliyor.
  - Pazardan store'a alim akisi duzeltildi.
  - Satis hesaplama, kaliteye gore fiyat etkisi, merkezi aktif/pasif ve magaza satis/silme akisi tamamlandi.
  - Cihaz testi tamamlandi; bu modul yeni bug disinda kilitli kabul ediliyor.

- [x] Field - %94
  - Cron yerine oyuncu girisi / ilgili akis bazli uretim hesaplama aktif.
  - Tur secim ekraninda uretilebilen urunler gosteriliyor.
  - Output kapasitesi ve bildirim senaryolari eklendi.
  - Kalan is: output dolu, hammadde yok, pasif durum testleri.

- [x] Farm - %94
  - Field ile benzer uretim/refactor modeli uygulandi.
  - Tur secim ekraninda uretilebilen urunler gosteriliyor.
  - Transfer popup intrinsic layout hatasi numpad tarafinda duzeltildi.
  - Kalan is: kapasite/pending ve transfer senaryolari testi.

- [x] Factory - %94
  - Uretim hesaplama on-entry modele tasindi.
  - Boost sistemi yeni uretim hesaplama mantigina uyarlandi.
  - Pasif fabrika ve engel bildirimleri icin bilgi bildirimi akisi eklendi.
  - Kalan is: hammadde eksik, output dolu, boost aktif/pasif testi.

- [x] Mine - %94
  - Uretim ve boost akisi yeni modele uyarlandi.
  - Tur secim ekraninda uretilebilen urunler gosteriliyor.
  - Kalan is: transfer, kapasite ve refresh senaryolari testi.

- [x] Arge - %90
  - Ana arastirma akislari calisiyor.
  - Tamamlanma bildirimleri sistemine dahil edildi.
  - Kalan is: arastirma tamamlaninca bildirim/deep-link davranisini test etmek.

---

## Yeni Sistemler

- [x] EXP / Level Sistemi - %88
  - Backend EXP kazanimi ve level hesaplama temeli kuruldu.
  - Profil ekraninda EXP ilerlemesi gosteriliyor.
  - Gorev odulleri EXP sistemine baglandi.
  - Kalan is: tum event kaynaklarinda EXP dengesi, level odulleri ve cihaz testi.

- [x] Gorev Sistemi - %85
  - Ana gorev, gunluk gorev ve yan gorev altyapisi kuruldu.
  - Gorev ilerleme, claim ve odul akisi eklendi.
  - AppBar gorev ikonu ve claim bekleyen gorev badge'i eklendi.
  - Gorev kartlari daha kompakt hale getirildi.
  - Kalan is: kategori rozetleri, daha fazla gorev seed'i, gunluk reset testi.

- [x] Bildirim Sistemi - %82
  - Event bildirimleri: insaat, yukseltme, transfer, arge tamamlanmasi.
  - Attention bildirimleri: pasif uretim birimi, stok/kapasite engelleri, bos store slotu gibi durumlar.
  - Bildirim ekrani, home kartlari ve appbar badge akisi eklendi.
  - Attention refresh ayri RPC'ye alinarak performans dostu hale getirildi.
  - Kalan is: tum engel sebeplerinin dogru onceliklendirilmesi ve gercek veriyle test.

- [x] Rozet / Achievement Sistemi - %80
  - Backend rozet tanimlari, oyuncu rozetleri ve dashboard RPC kuruldu.
  - Rozet kazaninca bildirim uretimi eklendi.
  - Profilde rozet ozeti ve `/achievements` ekrani eklendi.
  - Achievement ekraninda kategori filtresi ve mobil tasma duzeltmeleri yapildi.
  - Kalan is: daha fazla rozet seed'i, rozet odul dengesi, claim/notification testleri.

- [x] Sabit Katalog Cache - %92
  - Sehirler, urunler, store/warehouse/production/logistics type tablolari oyun boyunca cache'ten kullaniliyor.
  - Kurulum ekranlari urun onizlemelerini bu kataloglardan besliyor.
  - Kalan is: cache refresh stratejisi ve versiyonlama ihtiyaci.

- [x] Ozel Numeric Keyboard - %95
  - Miktar popup'larinda cihaz klavyesi kapatildi.
  - Hizli miktar kisayollari eklendi: `1/4`, `Yari`, `Tamami`.
  - AlertDialog icinde viewport intrinsic dimension hatasi duzeltildi.
  - Kalan is: tum popup'larda en/boy son cihaz testi.

---

## Backend / Supabase Durumu

### Tamamlananlar

- `bootstrap_game_session()` ile acilis akisi toparlandi.
- Uretim cron mantigi kaldirildi; uretim oyuncu girisi ve ilgili ekran/akis bazli hesaplaniyor.
- Legacy RPC ve cron temizliklerinin buyuk kismi yapildi.
- Store ve warehouse tarafinda sorgu sayisi azaltildi.
- Transfer tamamlanma sonuclarinda hedefli refresh icin etkilenen hedef sozlesmesi eklendi.
- Boost sistemi yeni uretim modeliyle hizalandi.
- EXP, gorev, bildirim ve rozet tablolarinin ilk fazlari canliya uygulandi.

### Bilincli Kalan Riskler

- `flutter analyze` bu ortamda sik sik timeout verdigi icin tam temiz analyzer raporu alinmis degil.
- Gunluk gorev reset ve attention bildirimleri gercek veriyle uzun oturum testine ihtiyac duyuyor.
- Warehouse/store patch sozlesmeleri iyilesti ama tum ekranlarda tamamen ayni standarda gelmedi.
- Release cihaz test guveni henuz orta seviyede; test turu kritik.

---

## UX / UI Fazinda Yapilanlar

- AppBar alani sadeletildi, gorev/bildirim badge'leri eklendi.
- Store, warehouse, market ve transfer ekranlarinda kart yogunlugu azaltildi.
- Warehouse liste/detail kartlari son cihaz testine gore yeniden duzenlendi.
- Kurulum/tip secim kartlarina urun onizlemeleri eklendi.
- Satin alma ve transfer miktar popup'larinda numpad standardi getirildi.
- Gorev kartlari kompakt hale getirildi.
- Achievement ekraninda kart tasma riski azaltildi.
- Profil ekranina EXP ve rozet bolumu eklendi.

---

## Siradaki En Mantikli Isler

1. Logistics / Transfer Map cihaz testi ve son UX turu
   - Arac secim popup'i
   - Transfer baslatma
   - Transfer tamamlaninca hedef ekran refresh'i
   - Depo/store/farm/factory kaynakli transferlerin ortak davranisi

2. Uretim modulleri cihaz test turu
   - Field/Farm/Factory/Mine uretim engelleri
   - Output dolu, hammadde yok, pasif durumlari
   - Boost aktif/pasif davranisi

3. Testten gelen bugfix turu
   - Runtime hatalari
   - Eksik refresh senaryolari
   - Layout overflow ve popup boyutlari

4. Icerik genisletme
   - Daha fazla gorev
   - Daha fazla rozet
   - EXP/odul dengelemesi

5. Build ve kalite turu
   - Analyzer timeout sorununun temiz ortamda kontrolu
   - Release build
   - GitHub yedegi
