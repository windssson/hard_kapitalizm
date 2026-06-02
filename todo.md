# Modul TODO Durumu ve Proje Ozeti

Bu dosya aktif gelistirme durumunu ozetler. Yuzdeler "ozellik kapsami + entegrasyon olgunlugu + cihaz testi guveni" bazli muhendislik tahminidir.

## Genel Durum
- Istemci (Flutter UI): ~%98
- Veritabani / RPC (Supabase): ~%95
- Performans refactor fazi: Ana hedefler tamamlandi
- UX / UI iyilestirme fazi: Ilk tur tamamlandi, test geri bildirimleri bekleniyor

---

## Modul Durumu

- [x] Splash - %99
  - `bootstrap_game_session()` ile acilis akisi tekles tirildi.
  - Oyuncu girisi, due islemler ve ilk yuklemeler daha dar sorgu akisina cekildi.
  - Sabit katalog cache preload eklendi.

- [x] Auth / Profil - %95
  - Cihaz tabanli otomatik giris akisi calisiyor.
  - `ensure_player_record_exists` tekrarsiz akisa indirildi.

- [x] Home - %92
  - Giris sonrasi ozet ekranlari calisiyor.
  - Lojistik giris karari tek RPC akisina baglandi.

- [x] Market - %97
  - Satin alma, filtreleme, hedef odakli alim akisi calisiyor.
  - Hedef ozeti ve alim modu UX iyilestirildi.
  - Miktar popup'larinda sistem klavyesi yerine ozel numpad kullaniliyor.
  - Kalan is: cihaz testiyle son UX ayarlari.

- [x] Logistics - %96
  - Sirket kurulumu, arac yonetimi, yakit ve kiralama akislari calisiyor.
  - Bircok gereksiz invalidate daraltildi.
  - Sabit kataloglar cache'ten okunuyor.
  - Miktar girislerinde ozel numpad aktif.
  - Kalan is: testte cikacak runtime / state buglari.

- [x] Transfer Map - %96
  - Aktif ve gecmis transfer takibi calisiyor.
  - Backend `affected targets` sozlesmesi ile hedefli refresh akisi kuruldu.
  - Filtre/siralama akislari ve ust ozet kartlari iyilestirildi.
  - Kalan is: gercek cihaz testinde son UX duzeltmeleri.

- [x] Warehouse - %97
  - Liste ve detay state'i notifier tabanli hale getirildi.
  - Kucuk slot islemleri lokal patch ile akiyor.
  - Route donusu hard refresh kaldirildi.
  - Depo tipi seciminde kabul edilen urunler gosteriliyor.
  - Miktar girislerinde ozel numpad ve hizli miktar kisayollari aktif.
  - Kalan is: testte gorulecek son davranis farklari.

- [x] Store - %97
  - Liste ekrani tek page-data akisina indirildi.
  - Detail acilisi `open_store_detail_page()` ile tek akisa cekildi.
  - History / performance ekranlari dirty-flag mantigina baglandi.
  - Cok sayida invalidate zinciri daraltildi.
  - Magaza tipi seciminde satilabilen urunler gosteriliyor.
  - Miktar girislerinde ozel numpad ve hizli miktar kisayollari aktif.
  - Kalan is: testte gorulecek runtime / state buglari.

- [x] Field - %97
  - Uretim, slot, boost ve transfer akislari yeni performans desenine yaklastirildi.
  - Cron yerine oyuncu girisi / ilgili akis bazli uretim hesaplama aktif.
  - Tur secim ekraninda uretebildigi urunler gosteriliyor.
  - Miktar girisleri numpad ile calisiyor.
  - Kalan is: cihaz testi ve son refresh ince ayarlari.

- [x] Farm - %97
  - Field ile benzer performans ve uretim refactoru uygulandi.
  - Tur secim ekraninda uretebildigi urunler gosteriliyor.
  - Miktar girisleri numpad ile calisiyor.
  - Kalan is: cihaz testi ve son refresh ince ayarlari.

- [x] Factory - %97
  - Uretim hesaplama giriste / ilgili akis bazli calisiyor.
  - Boost sistemi yeni uretim modeline uyarlandi.
  - Tur secim ekraninda uretebildigi urunler gosteriliyor.
  - Miktar girisleri numpad ile calisiyor.
  - Kalan is: cihaz testi ve son refresh ince ayarlari.

- [x] Mine - %97
  - Uretim ve boost akisi yeni modele uyarlandi.
  - Tur secim ekraninda uretebildigi urunler gosteriliyor.
  - Miktar girisleri numpad ile calisiyor.
  - Kalan is: cihaz testi ve son refresh ince ayarlari.

- [x] Arge - %95
  - Ana arastirma akislari calisiyor.
  - Bazi gereksiz refresh zincirleri daraltildi.
  - Kalan is: son UX ve test duzeltmeleri.

---

## Backend / Supabase Durumu

### Tamamlananlar
- Oyuncu girisine dayali `bootstrap_game_session()` akisi kuruldu.
- Sabit katalog kullanimina uygun istemci cache mimarisi hazirlandi.
- Store icin yeni RPC katmani:
  - `get_store_list_page_data()`
  - `open_store_detail_page()`
- Warehouse liste verisi daha dar sorgu akisina cekildi.
- Uretim cron mantigi oyuncu girisi ve ilgili akis bazli hesaplamaya tasindi.
- Eski production cron kayitlari ve kullanilmayan legacy RPC'lerin buyuk kismi temizlendi.
- Boost sistemi `building_boosts` kaydini dogruluk kaynagi kabul edecek sekilde uretim hesabina uyarlandi.
- Transfer tamamlama sonuclarinda etkilenen hedefleri donduren backend sozlesmeleri eklendi.

### Bilincli Olarak Kalanlar
- Gercek global etkiye sahip bazi refresh / due islemler hala genis kapsamli.
- Warehouse icin store seviyesinde tam `page model + patch contract` standardi henuz son noktaya tasinmadi.

### Takip Edilecek Temizlikler
1. Testte ortaya cikacak kalan RPC / state / parsing hatalarini kapatmak
2. Gerekirse warehouse backend response'larini daha da patch-dostu hale getirmek
3. Analyzer / build tarafinda tekrar eden sorunlari uygun ortamda temiz raporla dogrulamak

---

## Performans Fazinda Yapilan Ana Isler

- Splash acilis sorgulari ciddi sekilde azaltildi.
- Store liste ve detail akislari tekilleştirildi.
- Warehouse liste / detail refresh fan-out'u daraltildi.
- Cron tabanli uretim kaldirildi, on-entry hesaplama modeline gecildi.
- Boost sistemi yeni uretim zaman modeliyle hizalandi.
- Store, warehouse, production, logistics, market ve transfer map tarafinda gereksiz invalidate zincirleri temizlendi.
- Sabit kataloglar acilista bir kez yuklenip oyun boyunca cache'ten kullanilir hale getirildi:
  - cities
  - products
  - store types
  - warehouse types
  - factory / farm / field / mine types
  - logistics company / vehicle types

---

## UX / UI Fazinda Yapilan Ana Isler

- Store detail satis ozeti modal yerine inline karta donusturuldu.
- Warehouse detail ust bilgi hiyerarsisi iyilestirildi.
- Market ekranina alim hedefi ve teslimat modu baglami eklendi.
- Transfer map ust ozet kartlari ve filtre deneyimi iyilestirildi.
- Kurulum / tip secim ekranlarinda urun onizlemeleri eklendi:
  - magaza tipleri icin satilabilen urunler
  - depo tipleri icin kabul edilen urunler
  - uretim birimi tipleri icin uretilebilen urunler
- Miktar girilen popup'larda cihaz klavyesi kapatildi, ozel numpad kullanima alindi.
- Numpad'e hizli miktar kisayollari eklendi:
  - `1/4`
  - `Yari`
  - `Tamami`

---

## Siradaki En Mantikli Faz

1. Gercek cihaz test turu
   - Store
   - Warehouse
   - Market
   - Transfer Map
   - Logistics
   - Production detail ekranlari

2. Testten gelen bugfix turu
   - Runtime hatalari
   - Eksik refresh senaryolari
   - UX akisi tutarsizliklari

3. Ikinci tur UX parlatma
   - Bos durumlar
   - Kart spacing / buton dili
   - Mobil okunabilirlik

4. Gerekirse warehouse backend mimari tamamlama

---

## Kisa Notlar

- `flutter analyze` bu ortamda duzenli olarak timeout verdigi icin tam temiz analyzer raporu alinmis degil.
- Bu nedenle mevcut odak "gercek cihaz testi + hedefli bugfix" olmali.
- `Todo.md` tekrar aktif takip dosyasi olarak kullanilacaksa her buyuk faz sonunda guncellenmeli.
