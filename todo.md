# Hard Kapitalizm Progress Snapshot

Tarih: 2026-06-26

Not:
- Bu yuzdeler kesin teknik metrik degil, planlama icin cikarilmis yaklasik durum tahminidir.
- Degerlendirme kriteri:
  - rota/screen var mi
  - data/provider/RPC zinciri calisiyor mu
  - ana gameplay dongusunde kullanilabilir mi
  - gecici, kapali veya eksik akis var mi
  - raporlama/polish/test borcu ne kadar

## Genel Durum

- Tahmini genel tamamlanma: `%74`
- Oynanabilir cekirdek durum: `iyi`
- En kritik iyilestirme alani:
  - store polish ve fiyat/stok otomasyonu
  - market akisinin UX temizligi
  - logistics/transfer edge-case kontrolu
  - late-game management/reporting dengesi

## Modul Bazli Yuzdeler

| Modul | Durum | Tahmini Tamamlanma | Not |
|---|---:|---:|---|
| `splash` | Calisiyor | `90%` | Basit giris/yonlendirme akisi var, dusuk riskli. |
| `auth` | Calisiyor | `75%` | Profil ve session tarafi var, ama tam auth lifecycle ve hesap yonetimi daha sinirli gorunuyor. |
| `home` | Guclu | `82%` | Ana dashboard ve yonlendirme omurgasi oturmus, fakat ileride veri yogunlugu ve polish ister. |
| `company` | Guclu | `78%` | Sirket/brand/product design akisleri var, ama denge ve yonetsel derinlik halen gelistirilebilir. |
| `warehouse` | Guclu | `84%` | Liste, detay, gecmis, kapasite, transfer ve market entegrasyonu iyi seviyede. |
| `store` | Guclu ama hareketli | `80%` | Liste, detay, performans, tarihce, magaza deposu, raf doldurma ve toplu fiyat var; yine de UX ve kural kenar durumlari halen aktif gelisiyor. |
| `market` | Guclu ama revizyonda | `76%` | Global pazar, sepet, magaza depo hedefi, yatay urun secimi var; ancak akista son donemde cok degisiklik yapildigi icin stabilizasyon gerekli. |
| `logistics` | Guclu | `73%` | Kurulum, yonetim, finans ve rota secimi var; ama cok sayida edge-case ve denge borcu olma ihtimali yuksek. |
| `transfer_map` | Orta-iyi | `70%` | Harita akisi var ve sistemin merkezi bir parcasi, ama daha cok gorunurluk ve operasyonel detay isteyebilir. |
| `field` | Guclu | `77%` | Liste/detay/type secim var, temel uretim dongusu oturmus gorunuyor. |
| `farm` | Guclu | `77%` | Field ile benzer olgunlukta, uretim akisi calisir durumda. |
| `factory` | Guclu | `79%` | Uretim sistemi daha kompleks ve son migrationlardan anlasildigi kadariyla aktif sekilde iyilestirilmis. |
| `mine` | Guclu | `76%` | Liste/detay/type var, fakat factory kadar oturmamis olabilir. |
| `arge` | Orta | `68%` | Ekran var ama sistem derinligi ve oyun icindeki etkisi acisindan daha fazla olgunlasma gerekir. |
| `mission` | Orta | `62%` | Gorev ekrani var, ama oyunun uzun sureli dongusune etkisi muhtemelen halen gelisim asamasinda. |
| `notification` | Iyi | `72%` | Bildirim ve alert ayri akislarda var; faydali ama hala kalite/polish gerektirebilir. |
| `achievement` | Iyi | `70%` | Ekran ve temel baglanti var; uzun vadeli hedefleme ve odul dengesi tarafinda is olabilir. |
| `leaderboard` | Iyi | `71%` | Leaderboard ekran ve cron destekleri var; veri kalitesi ve filtreleme tarafi sonra gelisebilir. |
| `cash_flow` | Orta | `66%` | Nakit gecmisi var ama finans analizi daha da derinlesebilir. |
| `production_report` | Orta | `61%` | Tek ekranli ama faydali bir rapor modulu; veri kapsami ve UX daha da buyuyebilir. |

## Oyun Cekirdegi Ozet

- Temel ekonomi dongusu:
  - `warehouse -> market -> store -> sales` zinciri artik belirgin sekilde oynanabilir.
  - Tahmini olgunluk: `%82`

- Uretim dongusu:
  - `field/farm/factory/mine` tarafi genel olarak var ve sistemsel olarak bagli.
  - Tahmini olgunluk: `%78`

- Destek sistemleri:
  - `logistics + transfer_map + reports + notifications`
  - Tahmini olgunluk: `%71`

- Meta/progression sistemleri:
  - `missions + achievements + arge + leaderboard`
  - Tahmini olgunluk: `%68`

## Oncelikli Sonraki Asamalar

### 1. Store + Market Stabilizasyonu
- Magaza slot/depo/market hedef kurallarini tamamen netlestir.
- Fiyat guncelleme, raf doldurma, urun secme ve satis etiketi akislarini tek tutarli kurala bagla.
- Bu alan su an hizli gelistigi icin regression riski en yuksek bolge.

### 2. Logistics ve Transfer Guvenilirligi
- Transfer edge-case testleri eklenmeli:
  - kapasite
  - pending stok
  - ayni urun farkli kalite/brand
  - marketten toplu alim senaryolari
- Gecikme, maliyet ve arac secim UX'i sadeleştirilmeli.

### 3. Uretim Modulleri Denge ve Raporlama
- Field/farm/factory/mine tarafinda ortak davranislar standardize edilmeli.
- Rapor ekranlari netlestirilmeli:
  - verim
  - maliyet
  - darboğaz
  - bekleyen transfer

### 4. Meta Sistemleri
- Mission, achievement, arge ve leaderboard tek bir uzun vadeli ilerleme omurgasina baglanmali.
- Oyuncunun “neden bunu yapiyorum?” hissini guclendirecek hedef zinciri gerekli.

## Planlama Onerisi

- Kisa vade hedefi: `%74 -> %80`
  - odak: `store`, `market`, `logistics`

- Orta vade hedefi: `%80 -> %86`
  - odak: `production reports`, `missions`, `arge`, `notification quality`

- Uzun vade hedefi: `%86+`
  - odak: denge, polish, live-ops benzeri ilerleme sistemleri

## Kisa Sonuc

- Proje “prototip” asamasini gecmis durumda.
- “Core gameplay playable” seviyesinde.
- En mantikli plan, yeni modul eklemekten cok mevcut ekonomik donguyu sertlestirmek ve kurallari sabitlemek.
