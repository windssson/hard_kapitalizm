# Oyun Backend Güncel Fonksiyon Raporu

Bu rapor, mevcut backend geliştirme sürecinde yazılan / güncellenen fonksiyonları, alınan son kararları, fonksiyonların amaçlarını, parametrelerini, davranışlarını ve test durumlarını içerir.

Geçerli kaynak kabul edilen yapı:

- `codex_oyun_backend_veritabani_dokumani.md`
- `oyun_backend_fonksiyon_raporu(1).md`
- `yapi(1).md`
- Bu rapordaki güncel kararlar

> Not: Eski kararlarla çelişen durumlarda bu rapordaki kararlar geçerlidir.

---

# 1. Genel Güncel Kararlar

## 1.1 Kalite Sistemi Güncel Kararı

Eski karar değiştirildi.

Eski karar:

```text
AR-GE sonrası üretim birimlerinin product_id / quality_level ayarları otomatik güncelleniyordu.
Oyuncu üretimde kalite seçmiyordu.
```

Yeni karar:

```text
AR-GE sadece oyuncunun ilgili ürün için erişebildiği maksimum kalite seviyesini artırır.
Üretim birimlerinin mevcut product_id / quality_level ayarları otomatik değişmez.
Oyuncu üretim ekranına girip kaliteyi kendisi seçer.
```

Sonuç:

```text
- Oyuncu kaliteyi üretim ayar fonksiyonlarında seçer.
- Seçilen kalite, player_product_quality_levels.max_quality_level değerini geçemez.
- Kayıt yoksa oyuncunun o ürün için kalite seviyesi 1 kabul edilir.
```

---

## 1.2 Ürün / Kalite Değiştirme Kararı

Üretim birimlerinde eski ürün veya eski kalite stokları üretim birimi içinde bırakılmayacak.

Yeni karar:

```text
Ürün veya kalite değiştirilmeden önce üretim birimindeki mevcut stoklar depoya aktarılmalıdır.
```

Genel kural:

```text
Eğer ilgili üretim biriminde production_inventory.quantity > 0 olan input/output stok varsa:
- Ürün değiştirilemez.
- Kalite değiştirilemez.
- Oyuncuya önce stokları depoya aktarması söylenir.
```

`pending_quantity` kararı:

```text
quantity = 0 ama pending_quantity > 0 ise ürün/kalite değişiminde pending_quantity sıfırlanabilir.
Çünkü pending_quantity küsüratlı üretim/tüketim birikimidir ve depoya aktarılamaz.
```

---

## 1.3 Cron Üretim Zamanı Kararı

Tüm üretim cron’ları 10 dakikada bir çalışacak.

```text
products.uretim_adedi = saatlik üretim miktarıdır.
Cron 10 dakikada bir çalıştığı için her çalışmada:
products.uretim_adedi / 6
üretim hesabı yapılır.
```

Cron zamanları:

```text
Maden:
00, 10, 20, 30, 40, 50

Fabrika:
01, 11, 21, 31, 41, 51

Tarla / Çiftlik:
02, 12, 22, 32, 42, 52
```

Amaç:

```text
Üretim cron’larının aynı anda veritabanına yük bindirmesini engellemek.
```

---

## 1.4 Maliyet Kararları

### Maden

```text
Maden girdisiz üretim yapar.
Maden output cost değeri output inventory oluşturulurken belirlenir.
Maden cron cost hesaplamaz.
```

Maden maliyeti:

```text
products.baz_satis_fiyati * 0.10
```

### Fabrika

```text
Fabrika input tüketimli üretim yapar.
Output maliyeti tüketilen inputların cost değerinden hesaplanır.
```

### Tarla / Çiftlik

Güncel karar:

```text
Tarla ve çiftlik ürünlerinin tamamında en az 1 hammadde olmalıdır.
Tarla / çiftlik üretimi hammaddesiz olamaz.
Output maliyeti her zaman tüketilen input maliyetinden hesaplanır.
```

---

## 1.5 Tarla / Çiftlik Kapasite Kararı

Eski karar iptal edildi:

```text
output_capacity aktif slotlara eşit bölünmeyecek.
```

Yeni karar:

```text
Tarla / çiftlik output_capacity yapı bazında ortak havuzdur.
Pasif veya boş slotlar kapasiteyi bloke etmez.
Aktif üretim yapan slotlar ortak kapasiteyi kullanır.
Birden fazla slot üretim yapıyorsa kapasite slot_index sırasına göre kullanılır.
```

Örnek:

```text
Tarla output_capacity = 1000
4 slot var
Sadece 1 slot üretim yapıyor

Bu slot 1000 kapasiteyi tek başına doldurabilir.
```

---

# 2. İnşaat Fonksiyonları

## 2.1 `start_building_construction`

### Amaç

Oyuncunun yeni yapı inşaatı başlatmasını sağlar.

### Parametreler

```sql
p_player_id uuid
p_building_kind text
p_type_id uuid
p_city_id uuid
p_name text
```

### Desteklenen Yapılar

```text
store
warehouse
factory
field
farm
mine
logistics_company
```

### Davranış

```text
- Oyuncuyu kontrol eder.
- Şehri kontrol eder.
- building_kind değerini kontrol eder.
- Oyuncunun aktif inşaatı var mı kontrol eder.
- İlgili type tablosundan maliyet, gerekli seviye ve inşaat süresini alır.
- Oyuncunun seviyesi yeterli mi kontrol eder.
- Oyuncunun cash değeri yeterli mi kontrol eder.
- İnşaat maliyetini oyuncudan düşer.
- building_constructions tablosuna in_progress kayıt açar.
- params içine yapı bilgilerini ve snapshot değerleri yazar.
```

### Yapmadıkları

```text
- Gerçek yapı tablosuna kayıt açmaz.
- Slot oluşturmaz.
- Stok oluşturmaz.
```

### Çıktı Örneği

```json
{
  "success": true,
  "construction_id": "uuid",
  "building_kind": "store",
  "status": "in_progress",
  "started_at": "timestamp",
  "finish_at": "timestamp",
  "cost": 25000,
  "remaining_cash": 75000,
  "params": {}
}
```

### Test Durumu

```text
Test edildi, başarılı.
```

---

## 2.2 `complete_building_construction`

### Amaç

Süresi dolmuş tek bir inşaatı tamamlar ve ilgili gerçek yapı tablosuna kayıt açar.

### Parametreler

```sql
p_player_id uuid
p_construction_id uuid
```

### Davranış

```text
- İnşaat kaydını bulur ve kilitler.
- İnşaat oyuncuya ait mi kontrol eder.
- status = in_progress mı kontrol eder.
- finish_at zamanı gelmiş mi kontrol eder.
- building_kind değerine göre gerçek tabloya kayıt açar.
- building_constructions.status değerini complete yapar.
- completed_at alanını doldurur.
```

### Kayıt Açtığı Tablolar

```text
store              -> stores
warehouse          -> warehouses
factory            -> factories
field              -> fields
farm               -> farms
mine               -> mines
logistics_company  -> logistics_companies
```

### Yapmadıkları

```text
- Slot oluşturmaz.
- Stok oluşturmaz.
- Araç oluşturmaz.
- Üretim başlatmaz.
- Oyuncudan para düşmez.
```

### Çıktı Örneği

```json
{
  "success": true,
  "construction_id": "uuid",
  "building_kind": "store",
  "created_id": "uuid",
  "status": "complete",
  "completed_at": "timestamp"
}
```

### Test Durumu

```text
Test edildi, başarılı.
```

---

## 2.3 `complete_due_building_constructions`

### Amaç

Süresi dolmuş tüm in_progress inşaatları toplu olarak tamamlar.

### Parametreler

```sql
p_limit integer default 100
```

### Davranış

```text
- finish_at <= now() olan in_progress inşaatları bulur.
- Kayıtları for update skip locked ile kilitler.
- Her kayıt için complete_building_construction fonksiyonunu çağırır.
- Başarılı ve başarısız işlem sayılarını döndürür.
```

### Çıktı Örneği

```json
{
  "success": true,
  "completed_count": 5,
  "failed_count": 0
}
```

### Cron Kararı

```text
Saatte 1 çalışabilir.
Oyuncu oyundayken manuel/tetiklemeli tamamlama da yapılabilir.
```

### Cron SQL

```sql
select cron.schedule(
  'complete_due_building_constructions_hourly',
  '0 * * * *',
  $$
  select public.complete_due_building_constructions();
  $$
);
```

### Test Durumu

```text
Test edildi, başarılı.
```

---

## 2.4 `cancel_building_construction`

### Amaç

Devam eden bir inşaatı iptal eder.

### Parametreler

```sql
p_player_id uuid
p_construction_id uuid
```

### Davranış

```text
- İnşaat kaydını bulur ve kilitler.
- İnşaat oyuncuya ait mi kontrol eder.
- Sadece status = in_progress olan inşaatların iptaline izin verir.
- params içindeki cost değerini okur.
- Kurulum maliyetinin %50’sini oyuncuya iade eder.
- Oyuncunun cash değerini artırır.
- building_constructions.status değerini cancelled yapar.
- completed_at alanına iptal zamanını yazar.
```

### İade Kararı

```text
İptalde kurulum maliyetinin %50’si iade edilir.
```

### Çıktı Örneği

```json
{
  "success": true,
  "construction_id": "uuid",
  "building_kind": "store",
  "status": "cancelled",
  "cancelled_at": "timestamp",
  "original_cost": 25000,
  "refund_rate": 0.50,
  "refund_amount": 12500,
  "current_cash": 87500
}
```

### Test Durumu

```text
Test edildi, başarılı.
```

---

# 3. Mağaza Slot Fonksiyonları

## 3.1 `add_store_slot`

### Amaç

Oyuncunun mağazasına yeni boş satış slotu ekler.

### Parametreler

```sql
p_player_id uuid
p_store_id uuid
```

### Davranış

```text
- Mağazayı bulur ve kilitler.
- Mağazanın oyuncuya ait olduğunu kontrol eder.
- Mağazanın aktif olmasını şart koşmaz.
- current_slot_count < max_slot_count kontrolü yapar.
- Yeni slot_index değerini mevcut en büyük slot_index + 1 olarak belirler.
- store_slots içine boş slot kaydı açar.
- Slot capacity değerini stores.slot_capacity üzerinden kopyalar.
- stores.current_slot_count değerini 1 artırır.
- stores.updated_at değerini günceller.
```

### Oluşturulan Boş Slot Değerleri

```text
product_id = null
quantity = 0
quality_level = 0
price = 0
cost = 0
capacity = stores.slot_capacity
boost_multiplier = 1.00
pending_sale = 0
is_active = true
```

### Çıktı Örneği

```json
{
  "success": true,
  "store_id": "uuid",
  "slot_id": "uuid",
  "slot_index": 1,
  "capacity": 100,
  "current_slot_count": 1,
  "max_slot_count": 5
}
```

### Test Durumu

```text
Test edildi, başarılı.
```

---

## 3.2 `set_store_slot_product`

### Amaç

Mağaza satış slotunda satılacak ürün ve kalite seviyesini seçer.

### Parametreler

```sql
p_player_id uuid
p_store_slot_id uuid
p_product_id text
p_quality_level integer
```

### Davranış

```text
- Slotu ve bağlı mağazayı kontrol eder.
- Slotun oyuncuya ait olduğunu kontrol eder.
- Ürün var mı kontrol eder.
- quality_level 1 ile 5 arasında mı kontrol eder.
- Slotta quantity > 0 ise ürün/kalite değişimine izin vermez.
- product_id ve quality_level alanlarını günceller.
```

### Yapmadıkları

```text
- Stok eklemez.
- Fiyat belirlemez.
- Cost değiştirmez.
- Capacity değiştirmez.
```

### Çıktı Örneği

```json
{
  "success": true,
  "store_slot_id": "uuid",
  "store_id": "uuid",
  "product_id": "DOMATES",
  "quality_level": 1
}
```

### Test Durumu

```text
Test edildi, başarılı.
```

---

## 3.3 `clear_store_slot_product`

### Amaç

Mağaza satış slotundaki ürün seçimini temizler.

### Parametreler

```sql
p_player_id uuid
p_store_slot_id uuid
```

### Davranış

```text
- Slotu ve bağlı mağazayı kontrol eder.
- Slotun oyuncuya ait olduğunu kontrol eder.
- quantity > 0 ise slot boşaltmaya izin vermez.
- product_id = null yapar.
- quality_level = 0 yapar.
- price = 0 yapar.
- cost = 0 yapar.
- pending_sale = 0 yapar.
```

### Çıktı Örneği

```json
{
  "success": true,
  "store_slot_id": "uuid",
  "store_id": "uuid",
  "product_id": null,
  "quality_level": 0,
  "quantity": 0,
  "price": 0,
  "cost": 0,
  "pending_sale": 0
}
```

### Test Durumu

```text
Test edildi, başarılı.
```

---

## 3.4 `set_store_slot_price`

### Amaç

Mağaza slotundaki seçili ürün için satış fiyatı belirler.

### Parametreler

```sql
p_player_id uuid
p_store_slot_id uuid
p_price numeric
```

### Davranış

```text
- Slotu ve bağlı mağazayı kontrol eder.
- Slotun oyuncuya ait olduğunu kontrol eder.
- Slotta ürün ve kalite seçilmiş olmalı.
- p_price > 0 olmalı.
- Stok olmasını şart koşmaz.
- Slot aktif olmak zorunda değildir.
- price alanını günceller.
```

### Çıktı Örneği

```json
{
  "success": true,
  "store_slot_id": "uuid",
  "store_id": "uuid",
  "product_id": "DOMATES",
  "quality_level": 1,
  "price": 25
}
```

### Test Durumu

```text
Test edildi, başarılı.
```

---

## 3.5 `set_store_slot_active`

### Amaç

Mağaza slotunu aktif veya pasif yapar.

### Parametreler

```sql
p_player_id uuid
p_store_slot_id uuid
p_is_active boolean
```

### Davranış

```text
- Slotu ve bağlı mağazayı kontrol eder.
- Slotun oyuncuya ait olduğunu kontrol eder.
- is_active değerini günceller.
```

### Çıktı Örneği

```json
{
  "success": true,
  "store_slot_id": "uuid",
  "store_id": "uuid",
  "is_active": true
}
```

### Test Durumu

```text
Test edildi, başarılı.
```

---

## 3.6 `transfer_warehouse_slot_to_store_slot`

### Amaç

Depo slotundaki ürünü mağaza satış slotuna aktarır.

### Parametreler

```sql
p_player_id uuid
p_warehouse_slot_id uuid
p_store_slot_id uuid
p_quantity integer
```

### Davranış

```text
- Depo slotunu ve depo sahipliğini kontrol eder.
- Mağaza slotunu ve mağaza sahipliğini kontrol eder.
- Depo ve mağaza aynı şehirde olmalı.
- Depo slotunda ürün ve kalite seçili olmalı.
- Mağaza slotunda ürün ve kalite seçili olmalı.
- Depo slotundaki product_id + quality_level ile mağaza slotundaki product_id + quality_level aynı olmalı.
- Depoda yeterli quantity olmalı.
- Mağaza slot kapasitesi yeterli olmalı.
- Depodan quantity düşer.
- Mağaza slotuna quantity ekler.
- Mağaza cost değerini ağırlıklı ortalama ile günceller.
```

### Depo Slotu Sıfıra Düşünce

```text
Depo slotu silinmez.
product_id, quality_level ve cost korunur.
Sadece quantity 0 olur.
```

### Test Durumu

```text
Henüz test edilmedi.
```

---

# 4. Depo Fonksiyonları

## 4.1 `add_product_to_warehouse`

### Amaç

Depoya gelen ürünü doğru depo slotuna ekler.

Bu fonksiyon oyuncunun doğrudan bastığı bir “ürün ekle” butonu değildir. Pazar satın alma, üretim, lojistik transfer veya başka sistemler tarafından kullanılacak ortak yardımcı fonksiyondur.

### Parametreler

```sql
p_player_id uuid
p_warehouse_id uuid
p_product_id text
p_quality_level integer
p_quantity integer
p_cost numeric
p_transport_cost numeric default 0
p_release_reserved_capacity boolean default false
```

### Davranış

```text
- Depoyu bulur ve oyuncuya ait olduğunu kontrol eder.
- Ürünü kontrol eder.
- quality_level 1-5 arasında mı kontrol eder.
- quantity > 0 mı kontrol eder.
- cost >= 0 mı kontrol eder.
- transport_cost >= 0 mı kontrol eder.
- Ürünün birim_hacim değerini okur.
- Eklenecek hacmi quantity * birim_hacim olarak hesaplar.
- Depodaki kullanılan kapasiteyi warehouse_slots üzerinden hesaplar.
- reserved_capacity değerini dikkate alır.
- Aynı warehouse_id + product_id + quality_level slotu varsa mevcut slota ekler.
- Yoksa yeni warehouse_slots kaydı oluşturur.
- Cost değerini ağırlıklı ortalama ile günceller.
- Transferden geliyorsa reserved_capacity değerini eklenen hacim kadar düşürür.
```

### Nakliye Maliyeti Kararı

```text
p_transport_cost toplam nakliye maliyetidir.
Bu değer p_quantity değerine bölünür.
Birim nakliye maliyeti ürün birim maliyetine eklenir.
```

### Test Durumu

```text
Henüz test edilmedi.
```

---

## 4.2 `reserve_warehouse_capacity`

### Amaç

Transfer başlamadan önce hedef depoda ürün hacmi kadar yer ayırır.

### Parametreler

```sql
p_player_id uuid
p_warehouse_id uuid
p_product_id text
p_quantity integer
```

### Davranış

```text
- Depoyu bulur ve oyuncuya ait olduğunu kontrol eder.
- Ürünü kontrol eder.
- Ürünün birim_hacim değerini okur.
- Rezerve edilecek hacmi p_quantity * birim_hacim olarak hesaplar.
- Mevcut kullanılan kapasiteyi warehouse_slots üzerinden hesaplar.
- warehouses.reserved_capacity değerini dikkate alır.
- Depoda yeterli boş kapasite varsa reserved_capacity değerini artırır.
- Yeterli kapasite yoksa hata verir.
```

### Test Durumu

```text
Test edilecek.
```

---

## 4.3 `set_warehouse_slot_sale_status`

### Amaç

Depo slotunu satışa açık veya kapalı hale getirir.

### Parametreler

```sql
p_player_id uuid
p_warehouse_slot_id uuid
p_is_available_for_sale boolean
```

### Davranış

```text
- Depo slotunu ve bağlı depoyu kontrol eder.
- Depo slotunun oyuncuya ait olduğunu kontrol eder.
- Satışa açılacaksa product_id dolu olmalı.
- Satışa açılacaksa quality_level 1-5 arasında olmalı.
- quantity şartı yoktur.
- Stok 0 olsa bile satışa açık olarak işaretlenebilir.
- is_available_for_sale alanını günceller.
```

### Test Durumu

```text
Test edilecek.
```

---

## 4.4 `transfer_store_slot_to_warehouse`

### Amaç

Mağaza satış slotundaki ürünü aynı şehirde bulunan oyuncuya ait bir depoya geri aktarır.

### Parametreler

```sql
p_player_id uuid
p_store_slot_id uuid
p_warehouse_id uuid
p_quantity integer
```

### Davranış

```text
- Mağaza slotu var mı kontrol eder.
- Mağaza slotu oyuncuya ait mi kontrol eder.
- Hedef depo var mı kontrol eder.
- Hedef depo oyuncuya ait mi kontrol eder.
- Mağaza ve depo aynı şehirde olmalı.
- Mağaza slotunda yeterli quantity olmalı.
- Depoda yeterli kapasite olmalı.
- Aynı product_id + quality_level depo slotu varsa ona ekler.
- Yoksa yeni warehouse_slots kaydı oluşturur.
- Depo cost değerini ağırlıklı ortalama ile günceller.
- Mağaza slotundan quantity düşer.
- Mağaza slotunda quantity 0 olsa bile product_id, quality_level, price ve cost korunur.
```

### Test Durumu

```text
Henüz test edilmedi.
```

---

# 5. Üretim / Kalite Fonksiyonları

## 5.1 `upgrade_player_product_quality`

### Amaç

Oyuncunun belirli bir ürün için maksimum üretilebilir kalite seviyesini 1 artırır.

### Parametreler

```sql
p_player_id uuid
p_product_id text
```

### Güncel Davranış

```text
- Oyuncu var mı kontrol eder.
- Ürün var mı kontrol eder.
- Oyuncunun mevcut max kalite seviyesini bulur.
- Kayıt yoksa kalite 1 kabul eder.
- Kalite 5 ise hata verir.
- Kaliteyi 1 artırır.
- player_product_quality_levels kaydını oluşturur veya günceller.
```

### Artık Yapmadıkları

```text
- factories.quality_level güncellemez.
- mines.quality_level güncellemez.
- production_slots.quality_level güncellemez.
- production_inventory oluşturmaz.
- Eski stoklara dokunmaz.
```

### Çıktı Örneği

```json
{
  "success": true,
  "player_id": "uuid",
  "product_id": "DOMATES",
  "product_name": "Domates",
  "previous_quality_level": 1,
  "new_quality_level": 2,
  "production_settings_updated": false
}
```

### Test Durumu

```text
Yeni karara göre tekrar test edilmeli.
```

---

## 5.2 `set_mine_product`

### Amaç

Oyuncunun madeninde üretilecek ürün ve kaliteyi seçer veya değiştirir.

### Parametreler

```sql
p_player_id uuid
p_mine_id uuid
p_product_id text
p_quality_level integer
```

### Güncel Davranış

```text
- Maden ve mine_type bilgisini kontrol eder.
- Madenin oyuncuya ait olduğunu kontrol eder.
- Ürün var mı kontrol eder.
- Ürün maden ürünü mü kontrol eder.
- mine_types.accepted_product_ids içinde ürün var mı kontrol eder.
- p_quality_level 1-5 arasında mı kontrol eder.
- Oyuncunun bu ürün için max kalite seviyesi yeterli mi kontrol eder.
- Madenin output inventory kayıtlarında quantity > 0 stok varsa ürün/kalite değişimini engeller.
- quantity = 0 ama pending_quantity > 0 varsa pending_quantity sıfırlanır.
- mines.product_id ve mines.quality_level güncellenir.
- Yeni ürün/kalite için output inventory kaydı oluşturulur veya varsa kullanılır.
```

### Maden Output Cost Kararı

```text
Output inventory cost = products.baz_satis_fiyati * 0.10
Cron sırasında cost hesaplanmaz.
```

### Çıktı Örneği

```json
{
  "success": true,
  "mine_id": "uuid",
  "mine_type_id": "uuid",
  "product_id": "DEMIR",
  "product_name": "Demir",
  "quality_level": 1,
  "player_max_quality_level": 1,
  "same_setting": false,
  "cleared_pending_quantity": 0,
  "baz_satis_fiyati": 100,
  "output_cost": 10,
  "output_inventory_id": "uuid",
  "output_row_count": 1
}
```

### Test Durumu

```text
Fonksiyon yazıldı.
Uygulamalı test ayrıca yapılabilir.
```

---

## 5.3 `set_factory_product`

### Amaç

Oyuncunun fabrikasında üretilecek ürün ve kaliteyi seçer veya değiştirir.

### Parametreler

```sql
p_player_id uuid
p_factory_id uuid
p_product_id text
p_quality_level integer
```

### Güncel Davranış

```text
- Fabrika ve factory_type bilgisini kontrol eder.
- Fabrikanın oyuncuya ait olduğunu kontrol eder.
- Ürün var mı kontrol eder.
- Ürün fabrika ürünü mü kontrol eder.
- factory_types.accepted_product_ids içinde ürün var mı kontrol eder.
- p_quality_level 1-5 arasında mı kontrol eder.
- Oyuncunun bu ürün için max kalite seviyesi yeterli mi kontrol eder.
- Fabrikada quantity > 0 olan input/output inventory varsa ürün/kalite değişimini engeller.
- quantity = 0 ama pending_quantity > 0 varsa pending_quantity sıfırlanır.
- factories.product_id ve factories.quality_level güncellenir.
- Ürünün hammaddeleri için input inventory kayıtları oluşturulur.
- Ürün için output inventory kaydı oluşturulur.
```

### Input Kalite Kararı

```text
Şimdilik input inventory kalite seviyesi output kalite seviyesiyle aynı kabul edilir.
```

### Output Cost Kararı

```text
Output cost = 0 başlar.
Gerçek output maliyeti process_factory_production sırasında input maliyetlerinden hesaplanır.
```

### Çıktı Örneği

```json
{
  "success": true,
  "factory_id": "uuid",
  "factory_type_id": "uuid",
  "product_id": "SALCA",
  "product_name": "Salça",
  "quality_level": 1,
  "player_max_quality_level": 1,
  "same_setting": false,
  "cleared_pending_quantity": 0,
  "created_input_count": 1,
  "created_output_count": 1,
  "output_inventory_id": "uuid"
}
```

### Test Durumu

```text
Fonksiyon yazıldı.
Cron doğruluk testleri başarılı.
set_factory_product özel testi ayrıca yapılabilir.
```

---

## 5.4 `set_production_slot_product`

### Amaç

Tarla veya çiftlik üretim slotunda üretilecek ürün ve kaliteyi seçer/değiştirir.

### Parametreler

```sql
p_player_id uuid
p_production_slot_id uuid
p_product_id text
p_quality_level integer
```

### Desteklenen Owner Türleri

```text
field
farm
```

### Güncel Davranış

```text
- Production slot kaydını kontrol eder.
- owner_kind field veya farm mı kontrol eder.
- Slotun bağlı olduğu tarla/çiftlik oyuncuya ait mi kontrol eder.
- Ürün var mı kontrol eder.
- owner_kind = field ise ürün tarla ürünü mü kontrol eder.
- owner_kind = farm ise ürün çiftlik ürünü mü kontrol eder.
- İlgili field_types/farm_types.accepted_product_ids içinde ürün var mı kontrol eder.
- Tarla/çiftlik ürününde en az 1 hammadde var mı kontrol eder.
- p_quality_level 1-5 arasında mı kontrol eder.
- Oyuncunun bu ürün için max kalite seviyesi yeterli mi kontrol eder.
- production_inventory slot bazlı değil owner bazlı tutulduğu için owner üzerinde quantity > 0 input/output stok varsa ürün/kalite değişimini engeller.
- quantity = 0 ama pending_quantity > 0 varsa pending_quantity sıfırlanır.
- production_slots.product_id ve production_slots.quality_level güncellenir.
- Ürünün hammaddeleri için input inventory kayıtları oluşturulur.
- Ürün için output inventory kaydı oluşturulur.
```

### Önemli Stok Kararı

```text
production_inventory slot bazlı değil, owner bazlı tutulur.
Bu yüzden aynı tarla/çiftlik içindeki herhangi bir stok, slot ürün/kalite değişimini engeller.
Oyuncu önce stokları depoya aktarmalıdır.
```

### Çıktı Örneği

```json
{
  "success": true,
  "production_slot_id": "uuid",
  "owner_kind": "field",
  "owner_id": "uuid",
  "owner_type_id": "uuid",
  "product_id": "DOMATES",
  "product_name": "Domates",
  "quality_level": 1,
  "player_max_quality_level": 1,
  "same_setting": false,
  "cleared_pending_quantity": 0,
  "created_input_count": 1,
  "created_output_count": 1,
  "output_inventory_id": "uuid"
}
```

### Test Durumu

```text
Fonksiyon yazıldı.
Cron doğruluk testleri başarılı.
set_production_slot_product özel testi ayrıca yapılabilir.
```

---

## 5.5 `add_production_slot`

### Amaç

Oyuncunun sahip olduğu tarla veya çiftlik için yeni üretim slotu açar.

### Parametreler

```sql
p_player_id uuid
p_owner_kind text
p_owner_id uuid
```

### Desteklenen Owner Türleri

```text
field
farm
```

### Davranış

```text
- owner_kind field/farm mı kontrol eder.
- İlgili tarla veya çiftliği bulur.
- Yapının oyuncuya ait olduğunu kontrol eder.
- Yapının aktif olmasını şart koşmaz.
- current_slot_count < max_slot_count kontrolü yapar.
- Yeni slot_index değerini hesaplar.
- production_slots içine boş slot oluşturur.
- fields veya farms current_slot_count değerini 1 artırır.
- updated_at alanını günceller.
```

### Boş Slot Değerleri

```text
product_id = null
quality_level = 0
boost_multiplier = 1.00
is_active = true
```

### Çıktı Örneği

```json
{
  "success": true,
  "production_slot_id": "uuid",
  "owner_kind": "field",
  "owner_id": "uuid",
  "slot_index": 1,
  "current_slot_count": 1,
  "max_slot_count": 5
}
```

### Test Durumu

```text
Tamamlandı.
```

---

## 5.6 `set_production_slot_active`

### Amaç

Tarla/çiftlik üretim slotunu aktif veya pasif yapar.

### Parametreler

```sql
p_player_id uuid
p_production_slot_id uuid
p_is_active boolean
```

### Davranış

```text
- production_slots kaydını bulur ve kilitler.
- owner_kind field veya farm mı kontrol eder.
- Field ise fields tablosundan oyuncu sahipliği kontrol eder.
- Farm ise farms tablosundan oyuncu sahipliği kontrol eder.
- is_active değerini günceller.
- updated_at alanını günceller.
```

### Kullanım Amacı

```text
UI toggle dışında, üretim cron’u veya backend mantığı tarafından hammadde eksikliği,
üretimi durdurma veya yeniden başlatma için kullanılabilir.
```

### Test Durumu

```text
Test edilecek.
```

---

# 6. Üretim / Transfer Fonksiyonları

## 6.1 `transfer_warehouse_slot_to_production_inventory`

### Amaç

Depo slotundaki ürünü üretim biriminin input inventory kaydına aktarır.

### Desteklenen Hedefler

```text
factory
field
farm
```

### Parametreler

```sql
p_player_id uuid
p_warehouse_slot_id uuid
p_production_inventory_id uuid
p_quantity integer
```

### Davranış

```text
- Depo slotunu ve depo sahipliğini kontrol eder.
- Production inventory kaydını kontrol eder.
- Sadece inventory_type = input kayıtlarına aktarım yapar.
- owner_kind factory / field / farm olabilir.
- Hedef üretim birimi oyuncuya ait olmalı.
- Depo ve üretim birimi aynı şehirde olmalı.
- Ürün ve kalite eşleşmeli.
- Depoda yeterli quantity olmalı.
- Depodan quantity düşer.
- Input inventory quantity artar.
- Input inventory cost ağırlıklı ortalama ile güncellenir.
- Depo slotu quantity 0 olsa bile silinmez.
```

### Test Durumu

```text
Test edilecek.
```

---

## 6.2 `transfer_production_inventory_to_warehouse`

### Amaç

Üretim biriminin production_inventory kaydındaki input veya output ürünü aynı şehirdeki oyuncuya ait depoya aktarır.

Bu fonksiyon yeni ürün/kalite değiştirme akışında kritik hale gelmiştir. Oyuncu üretim biriminde ürün veya kalite değiştirmek istiyorsa önce buradaki stokları depoya aktarmalıdır.

### Parametreler

```sql
p_player_id uuid
p_production_inventory_id uuid
p_warehouse_id uuid
p_quantity integer
```

### Desteklenen Owner Türleri

```text
factory
field
farm
mine
```

### Desteklenen Inventory Türleri

```text
input
output
```

### Davranış

```text
- production_inventory kaydını kilitler.
- owner_kind factory / field / farm / mine mı kontrol eder.
- inventory_type input / output mu kontrol eder.
- Üretim biriminin oyuncuya ait olduğunu kontrol eder.
- Hedef deponun oyuncuya ait olduğunu kontrol eder.
- Üretim birimi ve depo aynı şehirde olmalı.
- Ürün birim_hacim değerine göre depo kapasitesi hesaplar.
- warehouses.reserved_capacity değerini boş kapasite hesabında düşer.
- Aynı product_id + quality_level depo slotu varsa ona ekler.
- Yoksa yeni warehouse_slots kaydı oluşturur.
- Depo slot cost değerini ağırlıklı ortalama ile günceller.
- production_inventory.quantity değerini düşürür.
- production_inventory satırını silmez.
- production_inventory.pending_quantity değerine dokunmaz.
```

### Çıktı Örneği

```json
{
  "success": true,
  "production_inventory_id": "uuid",
  "warehouse_id": "uuid",
  "warehouse_slot_id": "uuid",
  "owner_kind": "factory",
  "owner_id": "uuid",
  "inventory_type": "output",
  "city_id": "uuid",
  "product_id": "SALCA",
  "quality_level": 1,
  "transferred_quantity": 10,
  "unit_volume": 1,
  "transferred_capacity": 10,
  "warehouse_used_capacity_before": 100,
  "warehouse_reserved_capacity": 0,
  "warehouse_available_capacity_before": 900,
  "inventory_quantity_after": 0,
  "inventory_pending_quantity": 0,
  "warehouse_slot_quantity_after": 10,
  "warehouse_slot_cost_after": 12.5
}
```

### Test Durumu

```text
Fonksiyon yazıldı.
Yeni ürün/kalite akışı için tekrar test edilmeli.
```

---

# 7. Üretim Cron Fonksiyonları

## 7.1 `process_mine_production`

### Amaç

Aktif madenlerin üretimini hesaplar ve output production_inventory kaydına ürün ekler.

### Parametreler

```sql
Yok
```

### Çalışma Aralığı

```text
10 dakikada bir.
```

### Cron SQL

```sql
select cron.schedule(
  'process_mine_production_every_10_minutes',
  '*/10 * * * *',
  $$
  select public.process_mine_production();
  $$
);
```

### Davranış

```text
- Aktif ve ürüne ayarlı madenleri işler.
- products.uretim_adedi saatlik üretim kabul edilir.
- Her cron çalışmasında:
  (products.uretim_adedi / 6) * mines.boost_multiplier
  üretim yapılır.
- Output inventory kaydının quantity değerini artırır.
- Küsürat üretim pending_quantity olarak tutulur.
- output_capacity doluysa üretim yapmaz.
- Cost hesaplamaz.
- Inventory oluşturmaz.
- Ürün doğrulaması yapmaz.
```

### Maliyet Kararı

```text
Maden output cost değeri set_mine_product sırasında output inventory kaydına yazılır.
Cron cost alanına dokunmaz.
```

### Performans Testleri

```text
500 maden:
- total_produced: 5000
- elapsed_ms: 72.808 ms

10.000 maden:
- total_produced: 100.000
- elapsed_ms: 545.236 ms
- elapsed_seconds: 0.545236 sn
```

### Test Durumu

```text
Doğruluk ve performans testleri başarılı.
```

---

## 7.2 `process_factory_production`

### Amaç

Aktif fabrikaların input inventory stoklarını tüketerek output inventory üretmesini sağlar.

### Parametreler

```sql
Yok
```

### Çalışma Aralığı

```text
10 dakikada bir.
Maden cron’undan 1 dakika sonra çalışır.
```

### Cron SQL

```sql
select cron.schedule(
  'process_factory_production_every_10_minutes_offset_1',
  '1-59/10 * * * *',
  $$
  select public.process_factory_production();
  $$
);
```

### Davranış

```text
- Aktif ve ürüne ayarlı fabrikaları işler.
- products.uretim_adedi saatlik üretim kabul edilir.
- Her cron çalışmasında:
  (products.uretim_adedi / 6) * factories.boost_multiplier
  üretim yapılır.
- Output kapasitesi yeterliyse üretim yapar.
- Gerekli input stokları yeterliyse inputları tüketir.
- Output inventory quantity değerini artırır.
- Output pending_quantity küsürat üretimi tutar.
- Output cost değerini tüketilen input maliyetinden hesaplar.
- Mevcut output stoğu varsa ağırlıklı ortalama uygular.
- Input eksikse fabrika o tur atlanır.
- Input eksik diye fabrika otomatik pasif yapılmaz.
```

### Maliyet Kararı

```text
Output maliyeti tüketilen input cost değerlerinden hesaplanır.
```

### Performans Testleri

```text
500 fabrika:
- total_produced: 5000
- elapsed_ms: 90.442 ms

10.000 fabrika:
- total_produced: 100.000
- elapsed_ms: 1112.402 ms
- elapsed_seconds: 1.112402 sn
```

### Doğruluk Testleri

```text
Küçük doğruluk testi:
- 1 fabrika
- 10 output üretildi.
- 20 input tüketildi.
- Output cost = 10
- Başarılı.

Yetersiz input testi:
- Input yetersiz olduğunda üretim yapılmadı.
- Input/output değişmedi.
- Başarılı.
```

### Test Durumu

```text
Doğruluk ve performans testleri başarılı.
```

---

## 7.3 `process_field_farm_production`

### Amaç

Aktif tarla ve çiftlik üretim slotlarını işler, gerekli inputları tüketir ve output inventory üretir.

### Parametreler

```sql
Yok
```

### Çalışma Aralığı

```text
10 dakikada bir.
Maden ve fabrika cron’larından sonra çalışır.
```

### Cron SQL

```sql
select cron.schedule(
  'process_field_farm_production_every_10_minutes_offset_2',
  '2-59/10 * * * *',
  $$
  select public.process_field_farm_production();
  $$
);
```

### Güncel Davranış

```text
- Aktif production_slots kayıtlarını işler.
- Sadece owner_kind field / farm olan slotları işler.
- Slotun bağlı olduğu field/farm aktif olmalı.
- Slotta product_id dolu olmalı.
- quality_level 1-5 arasında olmalı.
- Ürün en az 1 hammaddeye sahip olmalı.
- products.uretim_adedi saatlik üretim kabul edilir.
- Her cron çalışmasında:
  (products.uretim_adedi / 6) * production_slots.boost_multiplier
  üretim yapılır.
- Output capacity yapı bazında ortak havuz olarak kullanılır.
- Ortak kapasite slot_index sırasına göre tüketilir.
- Gerekli input stokları varsa üretim yapılır.
- Input stokları tüketilir.
- Output inventory quantity artırılır.
- Output cost tüketilen input maliyetinden hesaplanır.
- Input eksikse ilgili slot o tur atlanır.
```

### Kapasite Kararı

```text
output_capacity slotlara eşit bölünmez.
Pasif/boş slotlar kapasiteyi bloke etmez.
Üretim yapan slotlar ortak kapasiteyi kullanır.
Birden fazla slot üretim yapıyorsa kapasite slot_index sırasına göre kullanılır.
```

### Maliyet Kararı

```text
Tarla/çiftlik ürünleri hammaddesiz olamaz.
Output maliyeti her zaman tüketilen input maliyetinden hesaplanır.
```

### Performans Testleri

```text
500 tarla, hammaddesiz eski test:
- total_produced: 5000
- elapsed_ms: 92.545 ms
- Not: Bu test artık gerçek oyun senaryosunu temsil etmiyor.

10.000 tarla, inputlu gerçekçi test:
- total_produced: 100.000
- elapsed_ms: 1267.163 ms
- elapsed_seconds: 1.267163 sn
```

### Doğruluk Testleri

```text
Ortak kapasite testi:
- 1 tarla
- output_capacity = 15
- 2 aktif slot
- Slot 1 toplam 10 üretti.
- Slot 2 kalan kapasite kadar 5 üretti.
- Toplam üretim 15 oldu.
- Başarılı.
```

### Test Durumu

```text
Doğruluk ve performans testleri başarılı.
```

---

# 8. Önerilen Kalıcı Indexler

Aşağıdaki indexler üretim cron performansı için önerilir.

## 8.1 Production Slots Field/Farm Active Index

```sql
create index if not exists idx_production_slots_field_farm_active
on production_slots (
  owner_kind,
  owner_id,
  product_id,
  quality_level,
  slot_index
)
where owner_kind in ('field', 'farm')
  and is_active = true
  and product_id is not null;
```

## 8.2 Production Inventory Field/Farm Output Index

```sql
create index if not exists idx_production_inventory_field_farm_output
on production_inventory (
  owner_kind,
  owner_id,
  product_id,
  quality_level
)
where owner_kind in ('field', 'farm')
  and inventory_type = 'output';
```

## 8.3 Production Inventory Field/Farm Input Index

```sql
create index if not exists idx_production_inventory_field_farm_input
on production_inventory (
  owner_kind,
  owner_id,
  product_id,
  quality_level
)
where owner_kind in ('field', 'farm')
  and inventory_type = 'input';
```

## 8.4 Production Inventory Owner / Type Index

```sql
create index if not exists idx_production_inventory_owner_inventory_type
on production_inventory (
  owner_kind,
  owner_id,
  inventory_type
);
```

## 8.5 Production Inventory Mine Output Index

```sql
create index if not exists idx_production_inventory_mine_output_active
on production_inventory (
  owner_id,
  product_id,
  quality_level
)
where owner_kind = 'mine'
  and inventory_type = 'output';
```

## 8.6 Mines Active Product Index

```sql
create index if not exists idx_mines_active_product
on mines (
  id,
  product_id,
  quality_level
)
where is_active = true
  and product_id is not null;
```

---

# 9. Cron Schedule Özet SQL

## 9.1 Maden Cron

```sql
select cron.schedule(
  'process_mine_production_every_10_minutes',
  '*/10 * * * *',
  $$
  select public.process_mine_production();
  $$
);
```

## 9.2 Fabrika Cron

```sql
select cron.schedule(
  'process_factory_production_every_10_minutes_offset_1',
  '1-59/10 * * * *',
  $$
  select public.process_factory_production();
  $$
);
```

## 9.3 Tarla / Çiftlik Cron

```sql
select cron.schedule(
  'process_field_farm_production_every_10_minutes_offset_2',
  '2-59/10 * * * *',
  $$
  select public.process_field_farm_production();
  $$
);
```

## 9.4 İnşaat Tamamlama Cron

```sql
select cron.schedule(
  'complete_due_building_constructions_hourly',
  '0 * * * *',
  $$
  select public.complete_due_building_constructions();
  $$
);
```

---

# 10. Henüz Yapılmayacak / UI Sonrasına Bırakılanlar

Aşağıdaki işler UI geliştirmeden sonra ele alınacak.

## 10.1 Transfer Fonksiyonlarının Son Testleri

```text
- transfer_production_inventory_to_warehouse tekrar test edilecek.
- transfer_warehouse_slot_to_production_inventory test edilecek.
- transfer_warehouse_slot_to_store_slot test edilecek.
- transfer_store_slot_to_warehouse test edilecek.
```

## 10.2 Satış Cron Fonksiyonu

```text
Mağaza satış sistemi ve satış cron’u UI akışından sonra tasarlanacak.
```

## 10.3 Cleanup Fonksiyonu

En sona bırakılan konu.

Temizlenebilecek production_inventory kayıtları:

```text
quantity = 0
pending_quantity = 0
aktif üretim ayarıyla eşleşmiyor
```

Ancak bu fonksiyon transfer ve satış sistemleri tamamen oturmadan yazılmayacak.

## 10.4 Lojistik / Araç Fonksiyonları

```text
- Araç satın alma
- Yakıt yönetimi
- Sevkiyat sistemi
- Kiralama sistemi
```

Bu alanlar henüz detaylandırılmadı.

---

# 11. Genel Durum Özeti

Backend üretim sistemi ilk faz tamamlandı.

Tamamlanan ana sistemler:

```text
- İnşaat başlatma / tamamlama / iptal
- Mağaza slot yönetimi
- Ürün kalite seviyesi açma
- Maden ürün/kalite ayarı
- Fabrika ürün/kalite ayarı
- Tarla/çiftlik slot ürün/kalite ayarı
- Maden üretim cron’u
- Fabrika üretim cron’u
- Tarla/çiftlik üretim cron’u
```

Performans durumu:

```text
10.000 maden:
~0.545 sn

10.000 fabrika:
~1.112 sn

10.000 tarla/çiftlik slotu:
~1.267 sn
```

Genel değerlendirme:

```text
Üretim cron performansları 10 dakikalık çalışma aralığı için başarılıdır.
Set-based SQL yaklaşımı korunacaktır.
Ürün/kalite değişiminden önce stokların depoya aktarılması kararı korunacaktır.
UI geliştirmeden sonra transfer, satış ve cleanup fonksiyonlarına devam edilecektir.
```
