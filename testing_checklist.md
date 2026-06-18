# Hard Kapitalizm Test Checklist

Bu liste, oyunu tamamen sifirlanmis durumdan baslayarak bastan sona test etmek icin hazirlandi.

## 1. Hesap ve baslangic

- [+] Yeni kullanici kaydi olustur
- [+] Oyuna ilk giris yap
- [+] `player` kaydi otomatik olusuyor mu kontrol et
- [+] Baslangic para / altin / seviye dogru mu kontrol et
- [+] Ana ekran sorunsuz aciliyor mu
- [+] Bottom navigation uzerindeki ana sayfalar sorunsuz aciliyor mu

## 2. Temel veri ve navigasyon

- [+] Sehir listeleri geliyor mu
- [+] Urun gorselleri yukleniyor mu
- [+] Depo tipleri listeleniyor mu
- [ ] Magaza tipleri listeleniyor mu
- [+] Uretim bina tipleri listeleniyor mu
- [ ] Market ekranina giris sorunsuz mu

## 3. Depo kurulum

- [+] Yeni depo kur
- [+] Construction kaydi olusuyor mu
- [+] Insaat bitince depo aktif oluyor mu
- [+] Depo kapasitesi dogru geliyor mu
- [ ] Depo detail ekrani aciliyor mu
- [ ] Bos slot gorunumu duzgun mu
- [ ] Depo history ekrani aciliyor mu

## 4. Magaza kurulum

- [ ] Yeni magaza kur
- [ ] Construction akisi dogru calisiyor mu
- [ ] Magaza acilinca bagli magaza deposu olusuyor mu
- [ ] Magaza deposu tipi dogru mu
- [ ] Magaza deposu kapasitesi `store_type.slot_capacity * 10` olarak geliyor mu
- [ ] Magaza detail ekrani aciliyor mu
- [ ] Magaza deposu ekrani aciliyor mu

## 5. Magaza deposu -> magaza slot akisi

- [ ] Magaza deposuna test urunu ekle
- [ ] Slot urun secim ekraninda sadece magaza deposundaki urunler listeleniyor mu
- [ ] Ayni `product + quality + brand` baska slottaysa secim ekraninda gizleniyor mu
- [ ] Secilen urun dogru slota ataniyor mu
- [ ] `brand_id` slota dogru geliyor mu
- [ ] `clear slot` sonrasi `brand_id` default degere donuyor mu
- [ ] Magaza slotundaki branded gorsel dogru mu

## 6. Magaza satis akisi

- [ ] Slot fiyati ayarla
- [ ] Satisa ac / kapat akisi calisiyor mu
- [ ] Satis sonrasi stok duzgun dusuyor mu
- [ ] Brand varsa satis katsayisi etkiliyor mu
- [ ] Default brand icin katsayi 1 kaliyor mu
- [ ] Stok 0 olduktan sonra yeniden stok girilince restock mantigi calisiyor mu

## 7. Depo -> depo transfer

- [ ] Ayni sehirde transfer baslat
- [ ] Kaynak depodan stok hemen dusuyor mu
- [ ] Hedef depoda rezerv / pending alan ayriliyor mu
- [ ] Kalite korunuyor mu
- [ ] Brand korunuyor mu
- [ ] Maliyet dogru tasiniyor mu
- [ ] Transfer bitince hedef stoga dogru isleniyor mu
- [ ] Transfer map kaydi olusuyor mu
- [ ] Transfer history kaydi olusuyor mu

## 8. Market akisi

- [ ] Bottom nav uzerinden markete gir
- [ ] Hedef depo sec
- [ ] Secilen deponun kabul ettigi urunleri filtreliyor mu
- [ ] Urun sec
- [ ] Satici listesi geliyor mu
- [ ] NPC satici gorunuyor mu
- [ ] Oyuncu satici gorunuyor mu
- [ ] NPC + oyuncu karisik sepet kurulabiliyor mu
- [ ] Sepete birden fazla urun eklenebiliyor mu
- [ ] Sehir kilidi dogru calisiyor mu
- [ ] Alisverise devam et akisi dogru mu
- [ ] Ayni sehirde farkli urunler listeleniyor mu
- [ ] Arac secimi aciliyor mu
- [ ] Satin alma sonrasi transfer olusuyor mu
- [ ] Hedef depoda rezerv dogru ayriliyor mu
- [ ] Urun bazli maliyetler dogru toplanmis mi
- [ ] Nakliye maliyeti urunlere dogru dagitilmis mi

## 9. Transfer map ve transfer history

- [ ] Aktif transfer kartlari aciliyor mu
- [ ] Coklu transfer ozeti dogru mu
- [ ] Branded urun overlay gorunuyor mu
- [ ] Tamamlanan transfer history'ye dusuyor mu
- [ ] Kaynak / hedef isimleri dogru mu
- [ ] Kaynak / hedef sehirleri dogru mu

## 10. Uretim bina kurulumlari

- [ ] Factory kur
- [ ] Farm kur
- [ ] Field kur
- [ ] Mine kur
- [ ] Her biri icin construction akisi dogru mu
- [ ] Her detail ekran sorunsuz aciliyor mu

## 11. Uretim urun secimi ve kalite kurali

- [ ] Uretim urunu sec
- [ ] Kalite secimi sorunsuz mu
- [ ] Q1 output icin input kalite 1 geliyor mu
- [ ] Q2 output icin input kalite 1 geliyor mu
- [ ] Q3 output icin input kalite 2 geliyor mu
- [ ] Q4 output icin input kalite 3 geliyor mu
- [ ] Q5 output icin input kalite 4 geliyor mu

## 12. Uretim input/output stok akisi

- [ ] Input warehouse gonderme ekraninda sadece ilgili input urunleri listeleniyor mu
- [ ] Output gonderme ekraninda output ve izinli inputlar listeleniyor mu
- [ ] Input transfer tamamlaninca stok dogru isleniyor mu
- [ ] Uretim baslayinca input stok duzgun dusuyor mu
- [ ] Output stok olusuyor mu
- [ ] Output branded ise overlay dogru gorunuyor mu

## 13. Brand ve sirket sistemi

- [ ] Sirketi olmayan kullanicida sirket kurma ekrani geliyor mu
- [ ] Sirket kurma islemi basarili mi
- [ ] Marka adi dogru kaydoluyor mu
- [ ] Sadece 5. kalite urunler patent ekraninda listeleniyor mu
- [ ] Patent al butonu calisiyor mu
- [ ] Patentli urunler sirket yonetim ekraninda gorunuyor mu
- [ ] Market ekraninda branded urun overlay gorunuyor mu
- [ ] Depo ekraninda branded urun overlay gorunuyor mu
- [ ] Magaza ekraninda branded urun overlay gorunuyor mu
- [ ] Transfer ekraninda branded urun overlay gorunuyor mu

## 14. Lojistik

- [ ] Lojistik sirket kur
- [ ] Arac edin
- [ ] Arac idle durumunda gorunuyor mu
- [ ] Sehirler arasi transfer icin arac secilebiliyor mu
- [ ] Yakit kontrolu dogru mu
- [ ] Kondisyon kontrolu dogru mu
- [ ] Kapasite kontrolu dogru mu
- [ ] Transfer sonunda arac durumu dogru guncelleniyor mu

## 15. Gecmis, performans ve rapor ekranlari

- [ ] Store history ekrani aciliyor mu
- [ ] Store performance ekrani aciliyor mu
- [ ] Production report ekranlari aciliyor mu
- [ ] Warehouse history ekrani aciliyor mu
- [ ] Transfer history ekrani aciliyor mu

## 16. Dayaniklilik ve hata avı

- [ ] Bos state ekranlari crash olmuyor mu
- [ ] Brandsiz urunler branded widget ile bozulmuyor mu
- [ ] Slotu bos urunlerde popup / action menu hatasiz mi
- [ ] Reset sonrasi ilk kullanici akisi tamamen temizden basliyor mu
- [ ] Birden fazla ekran arasi geciste state karismiyor mu
- [ ] Snackbar hata mesajlari beklenmeyen yerde cikmiyor mu

## 17. Onerilen test sirasi

- [ ] Yeni kullanici olustur
- [ ] Depo kur
- [ ] Magaza kur
- [ ] Magaza deposu ve slot akisini test et
- [ ] Marketten alim yap
- [ ] Depo transferlerini test et
- [ ] Uretim binalarini kur ve test et
- [ ] Brand sistemini test et
- [ ] Lojistik ve sehirler arasi tasimayi test et
