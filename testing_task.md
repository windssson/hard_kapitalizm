# Oyun Uctan Uca Test Plani - testing_task.md

Amac: Oyunu sifirlanmis veritabanindan baslayarak en bastan sona kadar test etmek, ana sistemlerin birbiriyle uyumlu calistigini dogrulamak ve kritik crash / veri bozulmasi risklerini erken yakalamak.

---

## 0. Test Baslangic Karari

- [ ] Testler sifirlanmis canli veride yapilacak.
- [ ] Master data tablolarina dokunulmayacak.
- [ ] Tum oyun state verisi temiz baslangictan dogrulanacak.
- [ ] Testler tek oyuncu ile baslayacak.
- [ ] Gerekirse ikinci oyuncu / NPC ile market ve transfer senaryolari ayrica test edilecek.

Master data kapsaminda korunmus kabul edilenler:

```text
cities
products
warehouse_types
store_types
factory_types
farm_types
field_types
mine_types
logistics_company_types
logistics_vehicle_types
game_settings
mission_definitions
achievement_definitions
```

---

## 1. Test Onkosullari

### 1.1 Teknik onkosullar

- [ ] Veritabani resetlenmis olmali.
- [ ] `players = 0` dogrulanmis olmali.
- [ ] `auth.users = 0` dogrulanmis olmali.
- [ ] Tum state tablolarinin bos oldugu dogrulanmis olmali.
- [ ] Uygulama en son guncel branch ile aciliyor olmali.

### 1.2 Isletim onkosullari

- [ ] Yeni test kullanicisi olusturulacak.
- [ ] Test boyunca bulunan her hata not alinacak.
- [ ] Her faz bitince kritik veri kontrolu yapilacak.

---

## 2. Faz 1 - Hesap ve baslangic akisi

### Hedef

Oyuncunun sifirdan oyuna girip temel state'inin dogru olustugunu dogrulamak.

### Test adimlari

- [ ] Yeni kullanici kaydi olustur
- [ ] Ilk girisi yap
- [ ] `player` kaydi otomatik olusuyor mu kontrol et
- [ ] Baslangic para dogru mu
- [ ] Baslangic altin dogru mu
- [ ] Baslangic seviye dogru mu
- [ ] Ana ekran sorunsuz aciliyor mu
- [ ] Bottom navigation ekranlari tek tek aciliyor mu

### Beklenen sonuc

- [ ] Oyuncu state'i eksiksiz olusur
- [ ] Ilk giriste crash olmaz
- [ ] Navigasyon temel ekranlarda sorunsuz calisir

---

## 3. Faz 2 - Temel veri ve katalog testi

### Hedef

Master data baglantilarinin ve temel UI veri akisinin saglam oldugunu dogrulamak.

### Test adimlari

- [ ] Sehir listeleri geliyor mu
- [ ] Urunler listeleniyor mu
- [ ] Urun ikonlari yukleniyor mu
- [ ] Depo tipleri geliyor mu
- [ ] Magaza tipleri geliyor mu
- [ ] Uretim bina tipleri geliyor mu
- [ ] Market sayfasi aciliyor mu

### Beklenen sonuc

- [ ] Master data kaynakli bos / kirik ekran olmamali
- [ ] Ikon ve isim eslesmeleri dogru olmali

---

## 4. Faz 3 - Depo sistemi testi

### Hedef

Depo kurulum, kapasite, detail ve history akislarini dogrulamak.

### Test adimlari

- [ ] Yeni depo kur
- [ ] Construction kaydi olusuyor mu
- [ ] Insaat bitince depo aktif oluyor mu
- [ ] Depo kapasitesi dogru geliyor mu
- [ ] Depo detail ekrani aciliyor mu
- [ ] Bos slot gorunumu dogru mu
- [ ] Depo history sayfasi aciliyor mu

### Beklenen sonuc

- [ ] Depo kaydi ve ilgili UI eksiksiz calisir
- [ ] Detail ekraninda sonsuz loading / crash olmaz

---

## 5. Faz 4 - Magaza ve magaza deposu testi

### Hedef

Magaza kurulumundan sonra bagli magaza deposunun dogru olustugunu ve store akislarinin yeni mimariye uydugunu dogrulamak.

### Test adimlari

- [ ] Yeni magaza kur
- [ ] Construction akisi tamamlaninca magaza aktif oluyor mu
- [ ] Bagli magaza deposu otomatik olusuyor mu
- [ ] Magaza deposu tipi dogru mu
- [ ] Magaza deposu kapasitesi `store_type.slot_capacity * 10` mi
- [ ] Magaza detail ekrani aciliyor mu
- [ ] Magaza deposu ekrani aciliyor mu

### Beklenen sonuc

- [ ] Her magazanin tek aktif magaza deposu olmali
- [ ] Magaza deposu kapasite ve sehir baglantisi dogru olmali

---

## 6. Faz 5 - Magaza slot ve satis rafı testi

### Hedef

Magaza slotlarinin sadece vitrin / satis rafi gibi davrandigini dogrulamak.

### Test adimlari

- [ ] Magaza deposuna test urunu ekle
- [ ] Slot urun secim ekraninda sadece magaza deposundaki urunler geliyor mu
- [ ] Ayni `product + quality + brand` zaten varsa listeden gizleniyor mu
- [ ] Urun secimi sonrasi slota dogru urun atanıyor mu
- [ ] `brand_id` dogru set ediliyor mu
- [ ] `clear slot` sonrasi `brand_id` default'a donuyor mu
- [ ] Slot aktif / pasif akisi calisiyor mu
- [ ] Slot branded gorseli dogru mu

### Beklenen sonuc

- [ ] Slotlar lojistik hedef gibi davranmiyor olmali
- [ ] Slot sadece vitrin mantiginda calismali

---

## 7. Faz 6 - Magaza satis testi

### Hedef

Satis katsayisi, fiyatlama ve stok dusum akislarini dogrulamak.

### Test adimlari

- [ ] Slot fiyati ayarla
- [ ] Satisa ac / kapat testi yap
- [ ] Satis sonrasi stok duzgun dusuyor mu
- [ ] Brand varsa satis bonusu etkiliyor mu
- [ ] Default brand icin katsayi 1 kaliyor mu
- [ ] Stok 0 olduktan sonra yeniden stok girisinde restock mantigi calisiyor mu

### Beklenen sonuc

- [ ] Satis sonrasi negatif stok olmamali
- [ ] Bonus hesaplarinda default brand ayrimi korunmali

---

## 8. Faz 7 - Depo -> depo transfer testi

### Hedef

Coklu transfer altyapisinin temel depo akisini bozmadigini dogrulamak.

### Test adimlari

- [ ] Ayni sehir depo -> depo transfer baslat
- [ ] Kaynak stok hemen dusuyor mu
- [ ] Hedefte rezerv / pending alan ayriliyor mu
- [ ] Kalite korunuyor mu
- [ ] Brand korunuyor mu
- [ ] Maliyet dogru tasiniyor mu
- [ ] Transfer bitince hedef stoga dogru isleniyor mu
- [ ] Transfer map kaydi olusuyor mu
- [ ] Transfer history kaydi olusuyor mu

### Beklenen sonuc

- [ ] Kaynak ve hedef state tutarli olmali
- [ ] Transfer bitiminde rezervler temizlenmeli

---

## 9. Faz 8 - Market testi

### Hedef

Yeni market UX'i ile hedef depo secimi, urun secimi, coklu sepet ve transfer olusumunu dogrulamak.

### Test adimlari

- [ ] Bottom nav uzerinden markete gir
- [ ] Hedef depo sec
- [ ] Sadece deponun kabul ettigi urunler listeleniyor mu
- [ ] Urun sec
- [ ] Satici listesi geliyor mu
- [ ] NPC satici gorunuyor mu
- [ ] Oyuncu satici gorunuyor mu
- [ ] NPC + oyuncu karisik sepet kurulabiliyor mu
- [ ] Sepete birden fazla urun eklenebiliyor mu
- [ ] Sehir kilidi dogru calisiyor mu
- [ ] Alisverise devam et akisi dogru mu
- [ ] Ayni sehirde farkli urunler gorunuyor mu
- [ ] Arac secimi aciliyor mu
- [ ] Satin alma sonrasi transfer olusuyor mu
- [ ] Hedef depoda rezerv dogru ayriliyor mu
- [ ] Urun bazli maliyet dogru mu
- [ ] Nakliye maliyeti urunlere dagitiliyor mu

### Beklenen sonuc

- [ ] Market akisi hedef depo bazli stabil calismali
- [ ] Coklu urun alimi veri bozmamali

---

## 10. Faz 9 - Transfer map ve transfer gecmisi

### Hedef

Aktif ve tamamlanmis transferlerin oyuncuya dogru ozetle gosterildigini dogrulamak.

### Test adimlari

- [ ] Aktif transfer kartlari aciliyor mu
- [ ] Coklu transfer ozeti dogru mu
- [ ] Branded urun overlay gorunuyor mu
- [ ] Tamamlanan transfer history'ye dusuyor mu
- [ ] Kaynak isimleri dogru mu
- [ ] Hedef isimleri dogru mu
- [ ] Sehirler dogru mu

### Beklenen sonuc

- [ ] Transfer map ve history verileri ayni transferi tutarli anlatmali

---

## 11. Faz 10 - Uretim bina kurulumu

### Hedef

Tum uretim bina tiplerinin sifirdan kurulup detay ekranlarinin stabil acildigini dogrulamak.

### Test adimlari

- [ ] Factory kur
- [ ] Farm kur
- [ ] Field kur
- [ ] Mine kur
- [ ] Her biri icin construction akisi dogru mu
- [ ] Her detail ekran sorunsuz aciliyor mu

### Beklenen sonuc

- [ ] Kurulumdan detaya kadar tum binalar ayaga kalkmali

---

## 12. Faz 11 - Uretim kalite kurali testi

### Hedef

Output kalitesine gore input kalite secim kurallarinin dogru calistigini dogrulamak.

### Test adimlari

- [ ] Uretim urunu sec
- [ ] Kalite secimi sorunsuz mu
- [ ] Q1 output -> input kalite 1
- [ ] Q2 output -> input kalite 1
- [ ] Q3 output -> input kalite 2
- [ ] Q4 output -> input kalite 3
- [ ] Q5 output -> input kalite 4

### Beklenen sonuc

- [ ] Input kalite atamasi kurala birebir uymali

---

## 13. Faz 12 - Uretim input / output stok akisi

### Hedef

Uretim envanterine giren ve cikan urunlerin filtre ve stok akislarini dogrulamak.

### Test adimlari

- [ ] Input gonderme ekraninda sadece ilgili input urunler listeleniyor mu
- [ ] Output gonderme ekraninda output ve izinli inputlar listeleniyor mu
- [ ] Input transfer tamamlaninca stok dogru isleniyor mu
- [ ] Uretim baslayinca input stok duzgun dusuyor mu
- [ ] Output stok olusuyor mu
- [ ] Output branded ise overlay dogru gorunuyor mu

### Beklenen sonuc

- [ ] Uretim stok mantigi filtre ve state acisindan tutarli olmali

---

## 14. Faz 13 - Brand ve sirket sistemi testi

### Hedef

Sirket kurulumu, patent akisi ve branded gorsel katmanini uctan uca dogrulamak.

### Test adimlari

- [ ] Sirketi olmayan oyuncuda sirket kurma ekrani geliyor mu
- [ ] Sirket kurma islemi basarili mi
- [ ] Marka adi dogru kaydoluyor mu
- [ ] Sadece 5. kalite urunler patent ekraninda listeleniyor mu
- [ ] Patent al butonu calisiyor mu
- [ ] Patentli urunler sirket yonetim ekraninda gorunuyor mu
- [ ] Market ekraninda branded overlay gorunuyor mu
- [ ] Depo ekraninda branded overlay gorunuyor mu
- [ ] Magaza ekraninda branded overlay gorunuyor mu
- [ ] Transfer ekraninda branded overlay gorunuyor mu

### Beklenen sonuc

- [ ] Brand sistemi veri ve UI tarafinda tutarli olmali

---

## 15. Faz 14 - Lojistik testi

### Hedef

Arac, kapasite, yakit ve sehirler arasi transfer davranislarini dogrulamak.

### Test adimlari

- [ ] Lojistik sirket kur
- [ ] Arac edin
- [ ] Arac idle durumunda gorunuyor mu
- [ ] Sehirler arasi transfer icin arac secilebiliyor mu
- [ ] Yakit kontrolu dogru mu
- [ ] Kondisyon kontrolu dogru mu
- [ ] Kapasite kontrolu dogru mu
- [ ] Transfer sonunda arac durumu guncelleniyor mu

### Beklenen sonuc

- [ ] Arac secimi kapasite ve durum kurallariyla uyumlu olmali

---

## 16. Faz 15 - Gecmis, performans ve rapor ekranlari

### Hedef

Ikincil ekranlarin yeni veri yapisiyla hala calistigini dogrulamak.

### Test adimlari

- [ ] Store history ekrani aciliyor mu
- [ ] Store performance ekrani aciliyor mu
- [ ] Production report ekranlari aciliyor mu
- [ ] Warehouse history ekrani aciliyor mu
- [ ] Transfer history ekrani aciliyor mu

### Beklenen sonuc

- [ ] Rapor ekranlari bos state veya dolu state'te crash olmamali

---

## 17. Faz 16 - Dayaniklilik ve hata avi

### Hedef

Kenar durumlari ve potansiyel crash noktalarini yakalamak.

### Test adimlari

- [ ] Bos state ekranlari crash olmuyor mu
- [ ] Brandsiz urunler branded widget ile bozulmuyor mu
- [ ] Bos slotlarda popup / action menu hatasiz mi
- [ ] Reset sonrasi ilk kullanici akisi temiz basliyor mu
- [ ] Coklu ekran gecislerinde state karismiyor mu
- [ ] Beklenmeyen snackbar hata mesaji geliyor mu

### Beklenen sonuc

- [ ] Kritik crash, kilitlenme veya veri kirilmasi olmamali

---

## 18. Onerilen test sirasi

- [ ] Yeni kullanici olustur
- [ ] Depo kur
- [ ] Magaza kur
- [ ] Magaza deposu ve slot akisini test et
- [ ] Marketten alim yap
- [ ] Depo transferlerini test et
- [ ] Uretim binalarini kur ve test et
- [ ] Brand sistemini test et
- [ ] Lojistik ve sehirler arasi transferleri test et
- [ ] History / report ekranlarini kontrol et

---

## 19. Kapanis kriteri

- [ ] Tum kritik fazlar tamamlandi
- [ ] Crash veren ekran kalmadi
- [ ] Veri tutarsizligi bulunan senaryolar not edildi
- [ ] Duzeltme gerektiren bug listesi ayri cikarildi
