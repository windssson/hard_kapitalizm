# Hard Kapitalizm — Gerçek Oyun Aksiyonları QA Checklist

> **Ana dal:** `main`  
> **Checklist maddesi:** **647**  
> **Kapsam:** Oyuncunun girişinden başlayarak hesap, merkez şehir, marka, üretim, depo, mağaza, lojistik, market, banka, vergi, ihale, Ar-Ge, görev, başarım, sosyal, premium, bildirim, rapor ve uçtan uca ekonomi akışları.

> Bu liste, repository'deki güncel `main` dalının README'sinde tanımlanan oyun döngüsü, route'lar ve sistemler; `lib/features` modül yapısı; ayrıca mağaza/ürün, reklam/boost, vergi ve diğer ilgili kod/migration aramalarından çıkarılmıştır.

## Test Kullanımı
- `[ ]` Test edilmedi
- `[x]` Başarılı
- `[!]` Hata bulundu
- Her hata için mümkünse ekran görüntüsü, kullanıcı hesabı, işlem öncesi/sonrası bakiye ve ilgili kayıt/ID not edilmelidir.
- Ek olarak her kritik para/stok/ödül işleminde çift tıklama, internet kesintisi ve uygulamayı kapatma testi yapılmalıdır.

## Kaynak Kapsamı
- `README.md`: oyun döngüsü, ana sistemler, route'lar ve özellik kapsamı.
- `lib/features`: achievement, arge, auth, bank, cash_flow, chat, company, factory, farm, field, home, leaderboard, logistics, market, mine, mission ve ilgili modüller.
- Mağaza tarafında slot/fiyat/toplu fiyat/raf doldurma/satış ile ilgili SQL migration'lar.
- Vergi, rewarded ad/boost, marka/patent/fiyat toleransı ve dashboard ile ilgili SQL migration'lar.

## 1. Hesap, Kimlik Doğrulama ve Oturum

- [x] **1.** Uygulamayı ilk kez aç ve splash/yükleme akışını tamamla
- [x] **2.** Yeni hesap oluştur
- [x] **3.** Geçerli e-posta ile kayıt ol
- [x] **4.** Geçersiz e-posta ile kayıt dene
- [x] **5.** Boş e-posta ile kayıt dene
- [x] **6.** Geçersiz/kısa şifre ile kayıt dene
- [x] **7.** Şifre tekrarının eşleşmediği kayıt denemesi yap
- [x] **8.** Mevcut e-posta ile tekrar kayıt dene
- [x] **9.** E-posta doğrulama akışını tamamla
- [x] **10.** Doğrulanmamış hesapla giriş dene
- [x] **11.** E-posta ve şifre ile giriş yap
- [x] **12.** Yanlış şifre ile giriş dene
- [x] **13.** Olmayan hesapla giriş dene
- [x] **14.** Google ile giriş yap
- [x] **15.** İlk Google girişinde profil oluşturma akışını tamamla
- [x] **16.** Mevcut Google hesabıyla tekrar giriş yap
- [x] **17.** Şifremi unuttum akışını başlat
- [x] **18.** Şifre sıfırlama bağlantısını kullan
- [x] **19.** Yeni şifre belirle
- [x] **20.** Yeni şifreyle tekrar giriş yap
- [x] **21.** Oturum açıkken uygulamayı kapatıp aç
- [x] **22.** Logout yap
- [x] **23.** Logout sonrası korumalı ekrana doğrudan gitmeyi dene
- [x] **24.** İnternet yokken giriş yapmayı dene
- [x] **25.** İnternet geri geldikten sonra oturumu yenile
- [x] **26.** İki cihazdan aynı hesapla oturum aç

## 2. İlk Kurulum, Merkez Şehir ve Tutorial

- [x] **27.** Yeni oyuncu için merkez şehir seçim ekranını aç
- [x] **28.** 81 ilden bir merkez şehir seç
- [x] **29.** Merkez şehir seçimini kaydet
- [x] **30.** Merkez şehir seçmeden devam etmeyi dene
- [x] **31.** Farklı bir merkez şehir seç
- [x] **32.** Profil üzerinden merkez şehri değiştir
- [x] **33.** Şehir nüfusunu görüntüle
- [x] **34.** Şehir vergi oranını görüntüle
- [x] **35.** İlk kurulum tutorial'ını başlat
- [x] **36.** Tutorial adımını tamamla
- [x] **37.** Tutorial sonraki adımına geç
- [x] **38.** Tutorial'ı kapat
- [x] **39.** Tutorial kapatıldıktan sonra tekrar açılmasını kontrol et
- [x] **40.** Tutorial spotlight'ının doğru hedefe yöneldiğini kontrol et

## 3. Ana Panel, Navigasyon ve Genel UI

- [x] **41.** Ana paneli aç
- [x] **42.** Alt navigasyondan her ana bölüme git
- [x] **43.** Top bar üzerinden ilgili ekranlara git
- [x] **44.** Geri navigasyonunu kullan
- [x] **45.** Bir detay ekranından liste ekranına dön
- [x] **46.** Derin link ile bir detay ekranını aç
- [x] **47.** Bildirimden ilgili içeriğe git
- [x] **48.** Sayfayı yenile
- [x] **49.** Boş liste durumlarını kontrol et
- [x] **50.** Yükleniyor durumunu kontrol et
- [x] **51.** Hata durumunu kontrol et
- [x] **52.** Snackbar/uyarı mesajlarını kontrol et
- [x] **53.** Para bakiyesinin top bar'da güncellenmesini kontrol et
- [x] **54.** Gold bakiyesinin güncellenmesini kontrol et
- [x] **55.** XP/level göstergesinin güncellenmesini kontrol et

## 4. Profil ve CEO

- [x] **56.** Profil ekranını aç
- [x] **57.** Kullanıcı adını görüntüle
- [x] **58.** Kullanıcı adını değiştir
- [x] **59.** Geçersiz kullanıcı adı gir
- [x] **60.** Avatarı görüntüle
- [x] **61.** Avatarı değiştir
- [x] **62.** Profil bilgilerini kaydet
- [x] **63.** Değişiklik sonrası profili yeniden aç
- [x] **64.** Public profile ekranını aç
- [x] **65.** Başka oyuncunun public profilini aç
- [x] **66.** Public profilden oyuncunun şirket bilgilerini görüntüle
- [x] **67.** Public profilden oyuncunun istatistiklerini görüntüle
- [x] **68.** Profilde merkez şehir bilgisini görüntüle
- [x] **69.** Profil üzerinden merkez şehir değiştir

## 5. Marka Şirketi

- [x] **70.** Şirket ekranını aç
- [x] **71.** Marka şirketi oluştur
- [x] **72.** Geçersiz marka adıyla oluşturmayı dene
- [x] **73.** Marka adını görüntüle
- [x] **74.** Marka bilgilerini kaydet
- [x] **75.** Marka seviyesini görüntüle
- [x] **76.** Marka XP'sini görüntüle
- [x] **77.** XP kazan ve seviyenin güncellenmesini kontrol et
- [x] **78.** Marka logosunu seç
- [x] **79.** Marka temasını seç
- [x] **80.** Marka tasarımını kaydet
- [x] **81.** Marka tasarımını yeniden aç
- [x] **82.** Patentlenebilir ürün listesini görüntüle
- [x] **83.** Bir ürünü patentle
- [x] **84.** Patent için yetersiz bakiye ile dene
- [x] **85.** Patentli ürün listesini görüntüle
- [x] **86.** Patent maliyetinin düşüldüğünü kontrol et
- [x] **87.** Patent sonrası ürünün marka portföyüne girdiğini kontrol et
- [x] **88.** Yerel pazarlama kampanyası başlat
- [x] **89.** Ulusal pazarlama kampanyası başlat
- [x] **90.** Global pazarlama kampanyası başlat
- [x] **91.** Yetersiz bakiye ile pazarlama kampanyası başlatmayı dene
- [x] **92.** Aktif pazarlama kampanyasını görüntüle
- [x] **93.** Kampanya etkisinin satış/marka gücüne yansımasını kontrol et
- [x] **94.** Marka değerinin güncellenmesini kontrol et
- [x] **95.** Şirket değer geçmişini görüntüle

## 6. Mağaza — Oluşturma ve Yönetim

- [x] **96.** Mağaza listesini aç
- [x] **97.** Yeni mağaza şehir seçim ekranını aç
- [x] **98.** Mağaza için şehir seç
- [x] **99.** Mağaza tipi seçim ekranını aç
- [x] **100.** Mağaza tipini seç
- [x] **101.** Mağaza satın al/oluştur
- [x] **102.** Yetersiz bakiye ile mağaza oluşturmayı dene
- [x] **103.** Geçersiz şehir seçimiyle mağaza oluşturmayı dene
- [x] **104.** Mağaza detayını aç
- [x] **105.** Mağaza adını görüntüle
- [x] **106.** Mağaza adını değiştir
- [x] **107.** Mağaza seviyesini görüntüle
- [x] **108.** Mağaza yükseltmesi başlat
- [x] **109.** Yetersiz bakiye ile yükseltme dene
- [x] **110.** Yükseltme tamamlanmasını kontrol et
- [x] **111.** Yükseltme sonrası kapasiteyi kontrol et
- [x] **112.** Mağaza günlük ciro bilgisini görüntüle
- [x] **113.** Mağaza kâr bilgisini görüntüle
- [x] **114.** Mağaza satış geçmişini aç
- [x] **115.** Mağaza günlük performans raporunu aç
- [x] **116.** Mağaza ek deposunu aç
- [x] **117.** Mağazanın kapatılabilir/erişilebilir durumunu test et

## 7. Mağaza — Raflar, Ürünler ve Fiyatlandırma

- [x] **118.** Mağazada boş slotları görüntüle
- [x] **119.** Yeni raf/slot aç
- [x] **120.** Yetersiz bakiye ile slot açmayı dene
- [x] **121.** Maksimum slot sayısına ulaşıldığında slot açmayı dene
- [x] **122.** Rafa ürün seç
- [x] **123.** Ürün seçim sheet'ini aç
- [x] **124.** Markalı ürün seç
- [x] **125.** Markasız ürün seç
- [x] **126.** Rafa ürünü ekle
- [x] **127.** Rafa aynı ürünü tekrar eklemeyi dene
- [x] **128.** Raf ürün miktarını değiştir
- [x] **129.** Rafı doldur
- [x] **130.** Rafı boşalt
- [x] **131.** Ürünü raftan kaldır
- [x] **132.** Ürün satış fiyatını gir
- [x] **133.** Geçersiz fiyat gir
- [x] **134.** 0 fiyat gir
- [x] **135.** Negatif fiyat gir
- [x] **136.** Toplu ürün fiyatlarını güncelle
- [x] **137.** Ürün fiyatını değiştir
- [x] **138.** Fiyat değişikliğinin kaydedildiğini kontrol et
- [x] **139.** Marka fiyat toleransını test et
- [x] **140.** Satışa açık ürünü görüntüle
- [x] **141.** Satışı başlat
- [x] **142.** Satışı durdur
- [x] **143.** Stok tükenmesi durumunu test et
- [x] **144.** Satış gerçekleşmesini kontrol et
- [x] **145.** Satış gelirini kontrol et
- [x] **146.** Satış vergisini kontrol et
- [x] **147.** Satış sonrası stok düşüşünü kontrol et
- [x] **148.** Satış sonrası marka XP'sini kontrol et
- [x] **149.** Mağaza deposundan satış için stok çekilmesini kontrol et

## 8. Mağaza — Depo

- [x] **150.** Mağaza depo ekranını aç
- [x] **151.** Mağaza depo kapasitesini görüntüle
- [x] **152.** Mağaza deposuna ürün ekle
- [x] **153.** Mağaza deposundan ürün çıkar
- [x] **154.** Mağaza depo slotunu aç
- [x] **155.** Mağaza depo slotunu kapat
- [x] **156.** Depo kapasitesini doldur
- [x] **157.** Kapasite aşımı yapmayı dene
- [x] **158.** Ürün hacminin kapasiteyi doğru tükettiğini kontrol et
- [x] **159.** Ürün maliyet bilgisini görüntüle
- [x] **160.** Ürün kalite bilgisini görüntüle
- [x] **161.** Mağaza deposundan rafa ürün aktar
- [x] **162.** Raftan mağaza deposuna ürün aktar
- [x] **163.** Mağaza deposu giriş/çıkış geçmişini görüntüle
- [x] **164.** Mağaza deposunda aynı ürünü tekrar eklemeyi dene

## 9. Tarla

- [x] **165.** Tarla listesini aç
- [x] **166.** Yeni tarla şehir seçimini aç
- [x] **167.** Tarla şehri seç
- [x] **168.** Tarla tipi seç
- [x] **169.** Tarla oluştur
- [x] **170.** Yetersiz bakiye ile tarla oluşturmayı dene
- [x] **171.** Tarla detayını aç
- [x] **172.** Tarla seviyesini görüntüle
- [x] **173.** Tarla yükselt
- [x] **174.** Yetersiz bakiye ile tarla yükseltmeyi dene
- [x] **175.** Tarla ürün/ekim seçimini aç
- [x] **176.** Ürün seç
- [x] **177.** Ekim başlat
- [x] **178.** Yetersiz tohum/hammadde ile ekim dene
- [x] **179.** Gübre seç
- [x] **180.** Gübreleme yap
- [x] **181.** Gübre etkisini kontrol et
- [x] **182.** İşçi ekle
- [x] **183.** İşçi çıkar
- [x] **184.** İşçi kapasitesini aşmayı dene
- [x] **185.** Üretim süresini görüntüle
- [x] **186.** Üretim devam ederken ekranı kapatıp aç
- [x] **187.** Üretim tamamlanmasını kontrol et
- [x] **188.** Hasat yap
- [x] **189.** Hasat öncesi hasat dene
- [x] **190.** Hasat sonrası stok artışını kontrol et
- [x] **191.** Depo doluyken hasat dene
- [x] **192.** Üretim maliyetini kontrol et
- [x] **193.** Üretim raporunu aç

## 10. Çiftlik

- [x] **194.** Çiftlik listesini aç
- [x] **195.** Yeni çiftlik şehir seçimini aç
- [x] **196.** Çiftlik şehri seç
- [x] **197.** Çiftlik tipi seç
- [x] **198.** Çiftlik oluştur
- [x] **199.** Yetersiz bakiye ile çiftlik oluşturmayı dene
- [x] **200.** Çiftlik detayını aç
- [x] **201.** Çiftlik seviyesini görüntüle
- [x] **202.** Çiftlik yükselt
- [x] **203.** Yetersiz bakiye ile yükseltme dene
- [x] **204.** Hayvan/üretim türünü görüntüle
- [x] **205.** Hayvan sayısını artır
- [x] **206.** Hayvan sayısını azalt
- [x] **207.** Yem ihtiyacını görüntüle
- [x] **208.** Yem seç
- [x] **209.** Yemleme yap
- [x] **210.** Yetersiz yem ile yemleme dene
- [x] **211.** Yem tüketimini kontrol et
- [x] **212.** İşçi ekle
- [x] **213.** İşçi çıkar
- [x] **214.** Üretimi başlat
- [x] **215.** Üretim tamamlanmasını kontrol et
- [x] **216.** Hayvansal ürünün stoğa girmesini kontrol et
- [x] **217.** Depo doluyken üretimi test et
- [x] **218.** Üretim maliyetini kontrol et
- [x] **219.** Üretim raporunu aç

## 11. Maden

- [x] **220.** Maden listesini aç
- [x] **221.** Yeni maden şehir seçimini aç
- [x] **222.** Maden şehri seç
- [x] **223.** Maden tipi seç
- [x] **224.** Maden oluştur
- [x] **225.** Yetersiz bakiye ile maden oluşturmayı dene
- [x] **226.** Maden detayını aç
- [x] **227.** Maden seviyesini görüntüle
- [x] **228.** Maden yükselt
- [x] **229.** Yetersiz bakiye ile yükseltme dene
- [x] **230.** Cevher/ürün türünü görüntüle
- [x] **231.** Çıkarma kapasitesini görüntüle
- [x] **232.** Üretimi başlat
- [x] **233.** Saatlik üretimi görüntüle
- [x] **234.** Üretim devam ederken ekranı kapatıp aç
- [x] **235.** Üretimin stoğa aktarılmasını kontrol et
- [x] **236.** Depo kapasitesi doluyken üretimi test et
- [x] **237.** İşçi ekle
- [x] **238.** İşçi çıkar
- [x] **239.** Üretim raporunu aç
- [x] **240.** Üretim maliyetini kontrol et
- [x] **241.** Sevkiyat için üretilen stokla transfer başlat

## 12. Fabrika

- [x] **242.** Fabrika listesini aç
- [x] **243.** Yeni fabrika şehir seçimini aç
- [x] **244.** Fabrika şehri seç
- [x] **245.** Fabrika tipi seç
- [x] **246.** Fabrika oluştur
- [x] **247.** Yetersiz bakiye ile fabrika oluşturmayı dene
- [x] **248.** Fabrika detayını aç
- [x] **249.** Fabrika seviyesini görüntüle
- [x] **250.** Fabrika yükselt
- [x] **251.** Yetersiz bakiye ile yükseltme dene
- [x] **252.** Üretim slotlarını görüntüle
- [x] **253.** Yeni üretim slotu aç
- [x] **254.** Yetersiz bakiye ile üretim slotu açmayı dene
- [x] **255.** Maksimum üretim slotuna ulaşıldığında slot açmayı dene
- [x] **256.** Ürün/reçete seç
- [x] **257.** Reçeteyi görüntüle
- [x] **258.** Gerekli hammaddeleri görüntüle
- [x] **259.** Hammadde yeterliyken üretim başlat
- [x] **260.** Hammadde yetersizken üretim başlatmayı dene
- [x] **261.** Üretim slotunu durdur
- [x] **262.** Üretim slotunu tekrar başlat
- [x] **263.** Farklı ürün için üretim slotu değiştir
- [x] **264.** Üretim tamamlanmasını kontrol et
- [x] **265.** Üretilen ürünün stoğa girmesini kontrol et
- [x] **266.** Üretim maliyetini kontrol et
- [x] **267.** Ürün kalite seviyesini kontrol et
- [x] **268.** Marka tercihini kontrol et
- [x] **269.** Depo doluyken üretim tamamlanmasını test et
- [x] **270.** Üretim raporunu aç

## 13. Depo Ağı

- [x] **271.** Depo listesini aç
- [x] **272.** Yeni depo şehir seçimini aç
- [x] **273.** Depo şehri seç
- [x] **274.** Depo tipi seç
- [x] **275.** Depo oluştur
- [x] **276.** Yetersiz bakiye ile depo oluşturmayı dene
- [x] **277.** Depo detayını aç
- [x] **278.** Depo seviyesini görüntüle
- [x] **279.** Depo yükselt
- [x] **280.** Yetersiz bakiye ile depo yükseltmeyi dene
- [x] **281.** Depo kapasitesini görüntüle
- [x] **282.** Depo slotlarını görüntüle
- [x] **283.** Depo slotu aç
- [x] **284.** Depo slotu kapat
- [x] **285.** Ürün ekle
- [x] **286.** Ürün miktarını değiştir
- [x] **287.** Ürün çıkar
- [x] **288.** Ürün seçim sheet'ini kullan
- [x] **289.** Depo kapasitesini tamamen doldur
- [x] **290.** Kapasite aşımı yapmayı dene
- [x] **291.** Ürün hacmi bazlı kapasite hesabını kontrol et
- [x] **292.** Ürün ağırlığını görüntüle
- [x] **293.** Ürün kalite bilgisini görüntüle
- [x] **294.** Ürün maliyetini görüntüle
- [x] **295.** Depo giriş/çıkış geçmişini aç
- [x] **296.** Depodan transfer için ürün seç
- [x] **297.** Transfer için miktar belirle
- [x] **298.** Depodan mağazaya stok gönder
- [x] **299.** Depodan fabrikaya hammadde gönder

## 14. Lojistik Şirketi ve Filo

- [x] **300.** Lojistik ekranını aç
- [x] **301.** Lojistik şirketi kurulumunu aç
- [x] **302.** Lojistik şirketini oluştur
- [x] **303.** Yetersiz bakiye ile lojistik şirketi oluşturmayı dene
- [x] **304.** Lojistik finans raporunu aç
- [x] **305.** Filo listesini görüntüle
- [x] **306.** Araç kirala
- [x] **307.** Araç satın al/kiralanabilir araç seç
- [x] **308.** Yetersiz bakiye ile araç işlemi dene
- [x] **309.** Araç tipini seç
- [x] **310.** Araç kapasitesini görüntüle
- [x] **311.** Araç hızını görüntüle
- [x] **312.** Araç yakıt durumunu görüntüle
- [x] **313.** Araç kondisyonunu görüntüle
- [x] **314.** Kullanımdaki aracı tekrar transferde seçmeyi dene
- [x] **315.** Araç durumunu görüntüle
- [x] **316.** Filo gelir-gider geçmişini görüntüle

## 15. Lojistik Transfer

- [x] **317.** Transfer oluşturma ekranını aç
- [x] **318.** Kaynak şehir seç
- [x] **319.** Hedef şehir seç
- [x] **320.** Kaynak depo seç
- [x] **321.** Hedef depo seç
- [x] **322.** Kaynak mağaza seç
- [x] **323.** Hedef mağaza seç
- [x] **324.** Kaynak üretim tesisi seç
- [x] **325.** Hedef üretim tesisi seç
- [x] **326.** Ürün seçim sheet'ini aç
- [x] **327.** Tek ürün seç
- [x] **328.** Birden fazla ürün seç
- [x] **329.** Transfer miktarı gir
- [x] **330.** 0 miktar gir
- [x] **331.** Negatif miktar gir
- [x] **332.** Stoktan fazla miktar gir
- [x] **333.** Araç seç
- [x] **334.** Araç kapasitesini aşan yük oluştur
- [x] **335.** Kapasite sınırında transfer oluştur
- [x] **336.** Transfer maliyetini görüntüle
- [x] **337.** Transfer süresini görüntüle
- [x] **338.** Transferi başlat
- [x] **339.** Transfer onayı olmadan çıkmayı dene
- [x] **340.** Transfer devam ederken haritayı aç
- [x] **341.** Transfer devam ederken detayını aç
- [x] **342.** Transfer tamamlanmasını kontrol et
- [x] **343.** Kaynak stoktan düşüşü kontrol et
- [x] **344.** Hedef stok artışını kontrol et
- [x] **345.** Aracın tekrar boş hale gelmesini kontrol et
- [x] **346.** Yakıt/kondisyon etkisini kontrol et
- [x] **347.** Çoklu ürün transferinin tüm kalemlerini kontrol et
- [x] **348.** Transfer geçmişini kontrol et
- [x] **349.** Transfer bildiriminin gelmesini kontrol et

## 16. Transfer Haritası

- [x] **350.** Transfer haritasını aç
- [x] **351.** Aktif araçları görüntüle
- [x] **352.** Aktif transferi seç
- [x] **353.** Aracın rotasını görüntüle
- [x] **354.** Transfer başlangıç noktasını görüntüle
- [x] **355.** Transfer hedefini görüntüle
- [x] **356.** Transfer ilerlemesini görüntüle
- [x] **357.** Tamamlanan transferi görüntüle
- [x] **358.** Harita ekranından transfer detayına git
- [x] **359.** Harita verisi yenile

## 17. Serbest Pazar

- [x] **360.** Market ekranını aç
- [x] **361.** Ürün listesini görüntüle
- [x] **362.** Ürün bazlı pazar detayını aç
- [x] **363.** Ürün fiyat grafiğini aç
- [x] **364.** Satıcı listesini görüntüle
- [x] **365.** Markalı ürünleri görüntüle
- [x] **366.** Markasız ürünleri görüntüle
- [x] **367.** Satış ilanlarını görüntüle
- [x] **368.** Ürün satın al
- [x] **369.** Satın alınacak miktarı belirle
- [x] **370.** Toplu alım yap
- [x] **371.** Yetersiz bakiye ile alım dene
- [x] **372.** Mevcut stoktan satışa ürün çıkar
- [x] **373.** Satış miktarı belirle
- [x] **374.** Ürünü pazarda satışa sun
- [x] **375.** Satış fiyatı belirle
- [x] **376.** Geçersiz satış fiyatı dene
- [x] **377.** İlan/satışın aktif olduğunu kontrol et
- [x] **378.** Ürün satışı gerçekleşmesini kontrol et
- [x] **379.** Satış sonrası stok düşüşünü kontrol et
- [x] **380.** Satış sonrası para artışını kontrol et
- [x] **381.** Satıcı satış bildirimini kontrol et
- [x] **382.** Fiyat grafiğinin satış sonrası güncellenmesini kontrol et
- [x] **383.** Rakip fiyatlarını görüntüle
- [x] **384.** Marka fiyat toleransının satışa etkisini kontrol et

## 18. Banka — Mevduat

- [x] **385.** Bankayı aç
- [x] **386.** Nakit bakiyeyi görüntüle
- [x] **387.** Vadeli mevduat ekranını aç
- [x] **388.** Mevduat vadesi seç
- [x] **389.** Mevduat faiz oranını görüntüle
- [x] **390.** Mevduat aç
- [x] **391.** Mevduata para yatır
- [x] **392.** Yetersiz nakitle mevduat yatırmayı dene
- [x] **393.** Mevduat bakiyesini görüntüle
- [x] **394.** Mevduat vade tarihini görüntüle
- [x] **395.** Vade dolmasını bekle
- [x] **396.** Faiz gelirinin eklenmesini kontrol et
- [x] **397.** Vade sonunda ana paranın durumunu kontrol et
- [x] **398.** Erken mevduat çekimi yap
- [x] **399.** Erken çekim cezasını kontrol et
- [x] **400.** Mevduatı kapat

## 19. Banka — Kredi

- [x] **401.** Kredi ekranını aç
- [x] **402.** Kredi seçeneklerini görüntüle
- [x] **403.** Kredi tutarı seç
- [x] **404.** Kredi vadesi seç
- [x] **405.** Kredi faizini görüntüle
- [x] **406.** Aylık taksit tutarını görüntüle
- [x] **407.** Kredi başvurusu yap
- [x] **408.** Uygun olmayan kredi tutarıyla başvurmayı dene
- [x] **409.** Kredi onayını kontrol et
- [x] **410.** Kredi tutarının hesaba geçmesini kontrol et
- [x] **411.** Kredi borcunu görüntüle
- [x] **412.** İlk taksiti görüntüle
- [x] **413.** Taksit ödeme işlemini yap
- [x] **414.** Yeterli bakiye ile taksit öde
- [x] **415.** Yetersiz bakiye ile taksit ödemeyi dene
- [x] **416.** Taksit gecikmesini test et
- [x] **417.** Vadesi gelen taksitin doğru hesaplandığını kontrol et
- [x] **418.** Anapara/faiz ayrımını kontrol et
- [x] **419.** Kredinin son taksitini öde
- [x] **420.** Kredinin kapanmasını kontrol et

## 20. Vergi ve Maliye

- [x] **421.** Vergi ekranını aç
- [x] **422.** Şehir bazlı vergi oranını görüntüle
- [x] **423.** Vergi borcunu görüntüle
- [x] **424.** Vergi detayını aç
- [x] **425.** Vergi hesaplamasını kontrol et
- [x] **426.** Satış hasılatı vergisini kontrol et
- [x] **427.** Vergi borcunun oluşmasını kontrol et
- [x] **428.** Vergi ödeme işlemini başlat
- [x] **429.** Vergi borcunun tamamını öde
- [x] **430.** Yetersiz bakiye ile vergi ödeme dene
- [x] **431.** Vergi ödeme sonrası borcun sıfırlanmasını kontrol et
- [x] **432.** Ödenmeyen verginin temerrüde düşmesini test et
- [x] **433.** Temerrüt tutarını kontrol et
- [x] **434.** Vergi kaynaklı operasyonel blokeyi test et
- [x] **435.** Blokeli işlem yapmayı dene
- [x] **436.** Vergi borcu kapatıldıktan sonra operasyonların açılmasını kontrol et
- [x] **437.** Vergi dönem yenilenmesini kontrol et

## 21. İhale Merkezi

- [x] **438.** İhale listesini aç
- [x] **439.** Aktif ihaleleri görüntüle
- [x] **440.** İhale detayını aç
- [x] **441.** İhale ürününü görüntüle
- [x] **442.** İhale miktarını görüntüle
- [x] **443.** İhale bitiş zamanını görüntüle
- [x] **444.** Teklif verme ekranını aç
- [x] **445.** Teklif miktarı gir
- [x] **446.** Geçersiz teklif gir
- [x] **447.** Minimum teklifin altında teklif ver
- [x] **448.** Geçerli teklif ver
- [x] **449.** Mevcut teklifin üzerine teklif ver
- [x] **450.** Yetersiz bakiye ile teklif ver
- [x] **451.** Teklifin kaydedildiğini kontrol et
- [x] **452.** Teklifini değiştirmeyi dene
- [x] **453.** İhale süresinin dolmasını kontrol et
- [x] **454.** İhaleyi kazan
- [x] **455.** İhaleyi kaybet
- [x] **456.** Kazanılan ihalenin ödülünü kontrol et
- [x] **457.** Kazanılan ihalenin ürün teslimatını görüntüle
- [x] **458.** İhale teslimatı için lojistik transfer başlat
- [x] **459.** Teslimat durumunu görüntüle
- [x] **460.** Teslimat tamamlanmasını kontrol et
- [x] **461.** İhale prestij/nakit ödülünü kontrol et

## 22. Ar-Ge ve Ürün Kalitesi

- [x] **462.** Ar-Ge ekranını aç
- [x] **463.** Teknoloji listesini görüntüle
- [x] **464.** Teknoloji ağacını görüntüle
- [x] **465.** Ürün kalite seviyesini görüntüle
- [x] **466.** Kilitli araştırmayı görüntüle
- [x] **467.** Ön koşulları görüntüle
- [x] **468.** Uygun araştırmayı başlat
- [x] **469.** Yetersiz kaynakla araştırma başlatmayı dene
- [x] **470.** Ön koşulu karşılamadan araştırma başlatmayı dene
- [x] **471.** Araştırma ilerlemesini görüntüle
- [x] **472.** Araştırmanın tamamlanmasını kontrol et
- [x] **473.** Ürün kalite seviyesinin artmasını kontrol et
- [x] **474.** Q1 ürününü görüntüle
- [x] **475.** Q2 ürününü görüntüle
- [x] **476.** Q3 ürününü görüntüle
- [x] **477.** Q4 ürününü görüntüle
- [x] **478.** Q5 ürününü görüntüle
- [x] **479.** Kalite artışının üretime etkisini kontrol et
- [x] **480.** Yeni araştırma açıldıktan sonra kilitlerin güncellenmesini kontrol et
- [x] **481.** Kalite araştırması sonrası mevcut stok kalitesinin değişmediğini kontrol et
- [x] **482.** Yeni üretimin yeni kaliteyle oluştuğunu kontrol et

## 23. Görevler ve Daily Streak

- [x] **483.** Görev merkezini aç
- [x] **484.** Ana görevleri görüntüle
- [x] **485.** Günlük görevleri görüntüle
- [x] **486.** Görev detayını aç
- [x] **487.** Görev ilerlemesini görüntüle
- [x] **488.** Görev şartını gerçekleştir
- [x] **489.** Görev ilerlemesinin artmasını kontrol et
- [x] **490.** Görevi tamamla
- [x] **491.** Görev ödülünü talep et
- [x] **492.** Ödülün yalnızca bir kez alınabildiğini kontrol et
- [x] **493.** XP ödülünü kontrol et
- [x] **494.** Gold/para ödülünü kontrol et
- [x] **495.** Günlük seri ekranını aç
- [x] **496.** Günlük giriş ödülünü al
- [x] **497.** Streak'i artır
- [x] **498.** Streak'in sonraki gün doğru görünmesini kontrol et
- [x] **499.** Streak kaçırma durumunu test et
- [x] **500.** Streak'in sıfırlanmasını kontrol et
- [x] **501.** Görev yenilenmesini kontrol et

## 24. Başarımlar

- [x] **502.** Başarımlar ekranını aç
- [x] **503.** Başarım listesini görüntüle
- [x] **504.** Kilitli başarımı görüntüle
- [x] **505.** Başarım ilerlemesini görüntüle
- [x] **506.** Başarım şartını gerçekleştir
- [x] **507.** Başarımın açılmasını kontrol et
- [x] **508.** Başarım ödülünü görüntüle
- [x] **509.** Başarım ödülünü talep et
- [x] **510.** Ödülün bakiyeye/XP'ye yansımasını kontrol et
- [x] **511.** Aynı başarım ödülünü ikinci kez talep etmeyi dene
- [x] **512.** Başarım bildirimini kontrol et

## 25. Kasa / Cash Flow

- [x] **513.** Kasa hareketleri ekranını aç
- [x] **514.** Gelir hareketlerini görüntüle
- [x] **515.** Gider hareketlerini görüntüle
- [x] **516.** Transfer hareketlerini görüntüle
- [x] **517.** Üretim giderlerini görüntüle
- [x] **518.** Mağaza satış gelirini görüntüle
- [x] **519.** Vergi giderini görüntüle
- [x] **520.** Kredi hareketlerini görüntüle
- [x] **521.** Faiz gelirini görüntüle
- [x] **522.** Filtreleme seçeneklerini kullan
- [x] **523.** Tarih aralığı seç
- [x] **524.** Hareket detayını aç
- [x] **525.** Toplam gelir değerini kontrol et
- [x] **526.** Toplam gider değerini kontrol et
- [x] **527.** Net nakit akışını kontrol et
- [x] **528.** Yeni işlem sonrası kasa geçmişinin güncellenmesini kontrol et

## 26. Liderlik Tablosu

- [x] **529.** Liderlik tablosunu aç
- [x] **530.** Şirket piyasa değeri sıralamasını görüntüle
- [x] **531.** Günlük ciro sıralamasını görüntüle
- [x] **532.** Üretim hacmi sıralamasını görüntüle
- [x] **533.** Kendi oyuncunu bul
- [x] **534.** Sıralamadaki şirket detayını aç
- [x] **535.** Başka oyuncunun public profilini aç
- [x] **536.** Sıralamanın işlem sonrası güncellenmesini kontrol et
- [x] **537.** Canlı veri yenilenmesini kontrol et

## 27. Chat ve Oyuncu İletişimi

- [x] **538.** Global chat'i aç
- [x] **539.** Mesaj listesini görüntüle
- [x] **540.** Mesaj gönder
- [x] **541.** Boş mesaj göndermeyi dene
- [x] **542.** Çok uzun mesaj göndermeyi dene
- [x] **543.** Özel karakter gönder
- [x] **544.** Emoji gönder
- [x] **545.** Mesajın anlık görünmesini kontrol et
- [x] **546.** Yeni mesaj geldiğinde listeyi güncelle
- [x] **547.** Başka oyuncunun profiline mesajdan git
- [x] **548.** Mesajı raporla
- [x] **549.** Geçersiz rapor göndermeyi dene
- [x] **550.** Mesaj raporunun kaydedildiğini kontrol et
- [x] **551.** Chat bağlantısı kesildiğinde davranışı kontrol et
- [x] **552.** Chat tekrar bağlandığında mesaj akışını kontrol et

## 28. Bildirimler ve Uyarılar

- [x] **553.** Bildirim ekranını aç
- [x] **554.** Bildirim listesini görüntüle
- [x] **555.** Bildirim detayını aç
- [x] **556.** Okunmamış bildirim göstergesini kontrol et
- [x] **557.** Bildirimden ilgili ekrana git
- [x] **558.** Transfer tamamlanma bildirimi al
- [x] **559.** Pazar satış bildirimi al
- [x] **560.** İhale bildirimi al
- [x] **561.** Üretim bildirimi al
- [x] **562.** Kritik şirket uyarısını aç
- [x] **563.** Alert ekranını aç
- [x] **564.** Uyarı detayını görüntüle
- [x] **565.** Bildirim/uyarı yenilenmesini kontrol et
- [x] **566.** Push bildiriminin uygulama kapalıyken davranışını kontrol et

## 29. Premium / Gold

- [x] **567.** Premium ekranını aç
- [x] **568.** Gold bakiyesini görüntüle
- [x] **569.** Gold ürünlerini görüntüle
- [x] **570.** Premium ürün detayını aç
- [x] **571.** Gold ile ürün satın al
- [x] **572.** Yetersiz Gold ile satın alma dene
- [x] **573.** Satın alma sonrası Gold düşüşünü kontrol et
- [x] **574.** Satın alınan avantajın hesaba tanımlanmasını kontrol et
- [x] **575.** Premium avantajının aktifleşmesini kontrol et
- [x] **576.** Premium süresini görüntüle
- [x] **577.** Premium süresi bitişini kontrol et
- [x] **578.** Tek kullanımlık premium ürünün ikinci kez kullanımını dene

## 30. Reklam ve Hızlandırma

- [x] **579.** Ödüllü reklamı başlat
- [x] **580.** Reklam tamamlanmasını bekle
- [x] **581.** Reklam ödülünü al
- [x] **582.** Transfer hızlandırma reklamını kullan
- [x] **583.** Transfer süresinin azaldığını kontrol et
- [x] **584.** Üretim/işlem için mevcut boost'u kullan
- [x] **585.** Boost başlangıcını kontrol et
- [x] **586.** Reklam kullanım sayacını kontrol et
- [x] **587.** Günlük reklam limitine ulaş
- [x] **588.** Limit doluyken tekrar reklam ödülü almaya çalış
- [x] **589.** Reklam tamamlanmadan uygulamayı kapat
- [x] **590.** Reklam sonrası ödülün yalnızca bir kez verildiğini kontrol et
- [x] **591.** Çoklu hızlı reklam tetiklemeyi dene

## 31. Üretim Raporları ve Analitik

- [x] **592.** Üretim raporu ekranını aç
- [x] **593.** Tesis bazlı üretim miktarını görüntüle
- [x] **594.** Üretim maliyetini görüntüle
- [x] **595.** Üretim gelirini görüntüle
- [x] **596.** Üretim verimliliğini görüntüle
- [x] **597.** Ürün bazlı üretim geçmişini görüntüle
- [x] **598.** Üretim raporunu farklı tesislerde aç
- [x] **599.** Yeni üretim sonrası raporun güncellenmesini kontrol et
- [x] **600.** Üretim durduğunda raporun doğru kalmasını kontrol et

## 32. Uçtan Uca Ekonomi Akışları

- [x] **601.** Tarla → depo akışını tamamla
- [x] **602.** Tarla → lojistik → mağaza akışını tamamla
- [x] **603.** Çiftlik → depo → mağaza akışını tamamla
- [x] **604.** Maden → depo → fabrika akışını tamamla
- [x] **605.** Fabrika → depo → mağaza akışını tamamla
- [x] **606.** Fabrika → doğrudan transfer akışını test et
- [x] **607.** Depo → fabrika hammadde akışını tamamla
- [x] **608.** Depo → mağaza stok yenileme akışını tamamla
- [x] **609.** Mağaza → satış → vergi → kasa akışını tamamla
- [x] **610.** Market → satın alma → stok akışını tamamla
- [x] **611.** Market → satış → kasa akışını tamamla
- [x] **612.** İhale → kazanım → lojistik → teslimat akışını tamamla
- [x] **613.** Ar-Ge → kalite → yeni üretim akışını tamamla
- [x] **614.** Patent → markalı üretim → mağaza satışı akışını tamamla
- [x] **615.** Pazarlama → marka → satış etkisini uçtan uca kontrol et
- [x] **616.** Banka kredisi → yatırım → üretim → satış → kredi ödeme akışını tamamla
- [x] **617.** Vergi borcu → bloke → ödeme → yeniden aktifleşme akışını tamamla

## 33. Genel Negatif / Dayanıklılık Testleri

- [x] **618.** Yetersiz bakiye ile her satın alma aksiyonunu dene
- [x] **619.** Tam bakiye ile işlem yap
- [x] **620.** Bakiyeden 1 TL eksikken işlem yap
- [x] **621.** 0 bakiye ile işlem yap
- [x] **622.** Negatif bakiye oluşturmayı dene
- [x] **623.** Negatif miktar gönder
- [x] **624.** 0 miktar gönder
- [x] **625.** Çok büyük miktar gönder
- [x] **626.** Ondalıklı miktar gönder
- [x] **627.** Çok uzun metin gönder
- [x] **628.** Boş metin gönder
- [x] **629.** Özel karakterli metin gönder
- [x] **630.** Emoji içeren metin gönder
- [x] **631.** Aynı butona arka arkaya iki kez bas
- [x] **632.** Aynı butona 5–10 kez hızlı bas
- [x] **633.** İşlem sırasında geri dön
- [x] **634.** İşlem sırasında başka ekrana geç
- [x] **635.** İşlem sırasında logout yap
- [x] **636.** İşlem sırasında uygulamayı öldür
- [x] **637.** İşlem sırasında interneti kes
- [x] **638.** İnterneti geri aç ve işlemin sonucunu kontrol et
- [x] **639.** Ağ gecikmesi altında aynı işlemi dene
- [x] **640.** Aynı hesabı iki cihazda aynı anda kullan
- [x] **641.** İşlem sonrası uygulamayı yeniden başlat
- [x] **642.** İşlem sonrası Supabase verisi ile UI verisini karşılaştır
- [x] **643.** Başarısız işlemde para/stok değişmemesini kontrol et
- [x] **644.** Başarılı işlemde yalnızca bir kez para/stok değişmesini kontrol et
- [x] **645.** İptal edilen işlemde ara durum kaydının temizlenmesini kontrol et
- [x] **646.** Çift transfer/çift satış/çift ödül oluşmadığını kontrol et
- [x] **647.** İşlem tamamlandıktan sonra tekrar gönderim yapmayı dene

## Kritik Kabul Kriterleri

- Para harcayan hiçbir aksiyon yetersiz bakiyeyle başarılı olmamalı.
- Başarısız işlemde para, stok, slot, araç, ödül veya XP kısmen düşmemeli.
- Aynı aksiyonun hızlı tekrarında duplicate kayıt/ödül/harcama oluşmamalı.
- Transferlerde kaynak stoktan düşüş ve hedef stok artışı tam olarak eşleşmeli.
- Üretimde girdi tüketimi ile çıktı miktarı reçeteye uygun olmalı.
- Mağaza satışında stok, brüt satış, vergi ve net gelir birbirini tutmalı.
- Vergi borcu, ödeme, temerrüt ve operasyonel bloke durumları tutarlı olmalı.
- Ar-Ge kalite yükseltmesi yeni üretime uygulanmalı; mevcut stokların kalitesi geriye dönük değişmemeli.
- İhale kazanımı, ürün teslimatı ve lojistik tamamlanması tek bir tutarlı akış oluşturmalı.
- Uygulama yeniden açıldığında devam eden zaman bazlı işlemler doğru durumdan devam etmeli.
- UI'daki kritik bakiye/stok/XP değerleri backend ile uyuşmalı.

## Kod Kapsamı Notu

Bu dosya manuel QA checklist'idir; her madde kullanıcı açısından gözlemlenebilir bir aksiyonu veya o aksiyonun zorunlu negatif senaryosunu temsil eder. Salt UI navigasyonları, veri sorguları ve backend içindeki kullanıcı tarafından tetiklenmeyen cron/RPC ayrıntıları ayrı test maddesi olarak çoğaltılmamıştır; bunların etkileri ilgili kullanıcı aksiyonlarında doğrulanır.
