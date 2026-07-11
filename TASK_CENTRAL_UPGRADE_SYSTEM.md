# Merkezi Yukseltme Sistemi Gorev Plani

## 1. Amac

Magaza, depo, tarla (`field`), ciftlik (`farm`), fabrika ve maden yukseltmelerini tek bir merkezi katalogdan yonetmek.

Bu calisma tamamlandiginda:

- Her birim en fazla seviye 5 olacak.
- Her birim tipi icin `1 -> 2`, `2 -> 3`, `3 -> 4` ve `4 -> 5` kayitlari bulunacak.
- Maliyet, sure, zorunlu oyuncu seviyesi ve kazanimlar veritabaninda tutulacak.
- Flutter ekranlari maliyet veya kazanim hesaplamayacak.
- Baslatma ve tamamlama RPC'leri ayni katalog kaydini kullanacak.
- Devam eden yukseltmeler katalog degisikliklerinden etkilenmeyecek.

## 2. Kapsam

| Uygulama birimi | `building_kind` | Tip tablosu | Varlik tablosu |
|---|---|---|---|
| Magaza | `store` | `store_types` | `stores` |
| Depo | `warehouse` | `warehouse_types` | `warehouses` |
| Tarla | `field` | `field_types` | `fields` |
| Ciftlik | `farm` | `farm_types` | `farms` |
| Fabrika | `factory` | `factory_types` | `factories` |
| Maden | `mine` | `mine_types` | `mines` |

AR-GE, lojistik sirketi ve diger birimler bu gorevin disindadir.

## 3. Degismez Is Kurallari

### 3.1 Seviye kurallari

- Minimum varlik seviyesi: `1`
- Maksimum varlik seviyesi: `5`
- Bir yukseltme yalnizca bir sonraki seviyeye gecebilir.
- Seviye 5 bir varlik icin teklif uretilmez ve yukseltme baslatilamaz.
- Her tip icin toplam dort yukseltme tanimi olmalidir.
- Bir oyuncunun oyun genelinde ayni anda yalnizca bir aktif bina yukseltmesi olabilir.

### 3.2 Zorunlu oyuncu seviyesi

Mevcut sistemde bina yukseltmelerine ozel yeni bir oyuncu seviyesi formulu yoktur. Davranis degisikligi olusturmamak icin tum yukseltmelerde:

```text
required_player_level = ilgili tip tablosundaki required_level
```

Bu alan tabloda acik olarak saklanacak ve ileride oyun dengesi icin seviye bazinda degistirilebilecektir.

### 3.3 Mevcut maliyet ve sure kurallari

Magaza, tarla, ciftlik, fabrika ve maden:

```text
cash_cost       = tip.cost * target_level
duration_seconds = tip.construction_time_minutes * target_level * 60
```

Depo:

```text
cash_cost = ceil((tip.cost * 0.30) * power(1.10, from_level - 1))
duration_seconds = tip.construction_time_minutes * target_level * 60
```

Tum hesaplar migration seed asamasinda yapilacak ve sonuc degerleri katalog tablosuna yazilacak. Runtime sirasinda bu formuller tekrar hesaplanmayacak.

### 3.4 Mevcut kazanim kurallari

| Birim | Kazanim |
|---|---|
| Magaza | Slot kapasitesi `+ store_types.slot_capacity`, maksimum slot `+2` |
| Depo | Kapasite `+ warehouse_types.base_capacity` |
| Tarla | Mevcut girdi kapasitesi `x2`, mevcut cikti kapasitesi `x2` |
| Ciftlik | Mevcut girdi kapasitesi `x2`, mevcut cikti kapasitesi `x2` |
| Fabrika | Mevcut girdi kapasitesi `x2`, mevcut cikti kapasitesi `x2` |
| Maden | Mevcut cikti kapasitesi `x2` |

Carpma etkileri katalogda `multiply = 2` olarak saklanacak. Baslatma anindaki gercek onceki ve sonraki degerler `building_upgrades.params` snapshot'ina yazilacak.

## 4. Veritabani Tasarimi

### 4.1 `building_upgrade_definitions`

Merkezi maliyet, sure ve gereksinim tablosu:

| Alan | Tip | Kural |
|---|---|---|
| `id` | `uuid` | Primary key, `gen_random_uuid()` |
| `building_kind` | `text` | Alti izinli birimden biri |
| `building_type_id` | `uuid` | Ilgili tip kaydi |
| `from_level` | `integer` | `1..4` |
| `target_level` | `integer` | `2..5`, `from_level + 1` |
| `required_player_level` | `integer` | En az `1` |
| `cash_cost` | `numeric` | Negatif olamaz |
| `duration_seconds` | `integer` | Sifirdan buyuk olmali |
| `instant_finish_enabled` | `boolean` | Varsayilan `true` |
| `is_active` | `boolean` | Varsayilan `true` |
| `created_at` | `timestamptz` | UTC |
| `updated_at` | `timestamptz` | UTC |

Zorunlu constraint ve indeksler:

- `check (building_kind in ('store','warehouse','field','farm','factory','mine'))`
- `check (from_level between 1 and 4)`
- `check (target_level between 2 and 5)`
- `check (target_level = from_level + 1)`
- `check (required_player_level >= 1)`
- `check (cash_cost >= 0)`
- `check (duration_seconds > 0)`
- `unique (building_kind, building_type_id, from_level)`
- Aktif katalog sorgusu icin `(building_kind, building_type_id, from_level) where is_active` partial index

`building_type_id` polimorfik oldugu icin dogrudan tek bir foreign key ile alti tip tablosuna baglanamaz. Gecerlilik seed ve RPC icinde kontrol edilecek; migration ayrica yetim tip kimligi testi calistiracak.

### 4.2 `building_upgrade_effects`

Kazanimlari normalize eden alt tablo:

| Alan | Tip | Kural |
|---|---|---|
| `id` | `uuid` | Primary key |
| `upgrade_definition_id` | `uuid` | Definition FK, silmede cascade |
| `metric_key` | `text` | Izinli metriklerden biri |
| `operation` | `text` | `add`, `multiply` veya `set` |
| `value` | `numeric` | Pozitif olmali |
| `display_order` | `smallint` | Arayuz sirasi |

Izinli `metric_key` degerleri:

- `store_slot_capacity`
- `store_max_slot_count`
- `warehouse_capacity`
- `input_capacity`
- `output_capacity`

Zorunlu constraint:

```text
unique (upgrade_definition_id, metric_key)
```

## 5. Seed Matrisi

Migration, her tip tablosundaki her satir icin dort definition uretmeli:

| Mevcut seviye | Hedef seviye |
|---:|---:|
| 1 | 2 |
| 2 | 3 |
| 3 | 4 |
| 4 | 5 |

Seed islemi idempotent olmali. `ON CONFLICT (building_kind, building_type_id, from_level) DO UPDATE` kullanilarak maliyet, sure, gereksinim ve aktiflik kontrollu bicimde guncellenmeli.

Effect seed kurallari:

- Magaza definition basina iki effect: `store_slot_capacity/add`, `store_max_slot_count/add`.
- Depo definition basina bir effect: `warehouse_capacity/add`.
- Tarla, ciftlik ve fabrika definition basina iki effect: `input_capacity/multiply`, `output_capacity/multiply`.
- Maden definition basina bir effect: `output_capacity/multiply`.

Beklenen definition sayisi:

```text
4 * (store_type_count + warehouse_type_count + field_type_count +
     farm_type_count + factory_type_count + mine_type_count)
```

## 6. RPC Tasarimi

### 6.1 `get_building_upgrade_quote`

Girdi:

```text
p_building_kind text
p_entity_id uuid
```

Donus:

- Varlik ve tip bilgisi
- Mevcut ve hedef seviye
- Zorunlu oyuncu seviyesi
- Nakit maliyeti
- Sure ve tahmini bitis zamani
- Onceki ve sonraki kapasite/slot degerleri
- Effect listesi
- Yukseltilebilirlik durumu ve engel mesaji

Bu RPC salt okunur teklif kaynagidir. Flutter yalnizca bu sonucu gostermelidir.

### 6.2 `start_building_upgrade`

Tek ortak baslatma RPC'si su kontrolleri transaction icinde yapmali:

1. `auth.uid()` ile oyuncuyu dogrula.
2. Vergi kilidini kontrol et.
3. Varligi `FOR UPDATE` ile kilitle ve sahipligi dogrula.
4. Varligin aktif oldugunu dogrula.
5. Mevcut seviyenin 5'ten kucuk oldugunu dogrula.
6. Tam olarak mevcut seviye icin aktif katalog kaydini bul.
7. Oyuncu seviyesini ve nakit bakiyesini kontrol et.
8. Oyuncunun oyun genelinde devam eden baska bir bina yukseltmesi olmadigini kontrol et.
9. Bakiyeyi atomik olarak dus ve cash ledger kaydi olustur.
10. Definition ve effect sonuclarini `building_upgrades.params` icine snapshot olarak yaz.

Istemciden maliyet, sure, hedef seviye veya kazanim kabul edilmemeli.

### 6.3 Tamamlama

`complete_building_upgrade` ve `complete_due_building_upgrades` katalogdaki guncel degerleri degil, baslatma aninda olusturulan snapshot'i uygulamali.

- Seviye `target_level` yapilmali.
- Etkiler yalnizca bir kez uygulanmali.
- Islem tamamlaninca durum `completed` ve `completed_at` atomik guncellenmeli.
- Magaza slot kapasiteleri ilgili tum mevcut slotlara uygulanmali.
- Seviye 5 tamamlandiktan sonra yeni teklif donmemeli.

### 6.4 Depo birlestirmesi

Depodaki ayri RPC zinciri kontrollu bicimde ortak sisteme alinmali:

- `start_warehouse_upgrade` gecici uyumluluk wrapper'i olabilir.
- Wrapper ortak `start_building_upgrade(..., 'warehouse', ...)` akisini cagirmali.
- Eski ve yeni depo upgrade tablolarinda cift kayit olusmasi engellenmeli.
- Mevcut devam eden depo yukseltmeleri tamamlanmadan eski tablo kaldirilmamali.
- Gecis bittikten sonra eski depo RPC ve tablo kullanimi ayri migration ile temizlenmeli.

## 7. Flutter Degisiklikleri

- Ortak `BuildingUpgradeQuoteModel` olustur.
- Ortak quote provider/repository olustur.
- Alti detay ekranindaki yerel maliyet, sure ve kazanim formullerini kaldir.
- Tum ekranlar RPC'nin `effects` ve onceki/sonraki degerlerini gostersin.
- Seviye 5'te buton yerine `Maksimum Seviye` durumu gosterilsin.
- Baslatma sonrasi gosterilen nakit efekti RPC sonucundaki gercek `cash_cost` degerini kullansin.
- Yildizla bitirme hesabi sunucu tarafinda yeniden dogrulansin; istemci degeri otorite olmasin.

Etkilenecek ana ekranlar:

- `lib/features/store/ui/store_detail_screen.dart`
- `lib/features/warehouse/ui/warehouse_detail_screen.dart`
- `lib/features/field/ui/field_detail_screen.dart`
- `lib/features/farm/ui/farm_detail_screen.dart`
- `lib/features/factory/ui/factory_detail_screen.dart`
- `lib/features/mine/ui/mine_detail_screen.dart`

## 8. Guvenlik

- Yeni public tablolarda RLS etkinlestirilmeli.
- `authenticated` rolu katalog icin yalnizca `SELECT` yapabilmeli.
- `INSERT`, `UPDATE` ve `DELETE` istemci rollerine verilmemeli.
- `SECURITY DEFINER` RPC'lerde `SET search_path = public` bulunmali.
- Fonksiyonlar varsayilan `PUBLIC EXECUTE` yetkisinden arindirilmali.
- Yalnizca gerekli RPC'lere `authenticated` execute yetkisi verilmeli.
- Her mutasyon RPC'si `auth.uid()` sahiplik kontrolu yapmali.

## 9. Uygulama Sirasi

- [ ] Mevcut canli tip sayilarini ve tip alanlarini SQL ile dogrula.
- [ ] Supabase CLI surumunu ve migration durumunu kontrol et.
- [ ] `supabase migration new central_building_upgrade_catalog` ile migration olustur.
- [ ] Definition ve effect tablolarini, constraint ve indeksleri ekle.
- [ ] Alti tip icin seviye 2-5 seed kayitlarini ekle.
- [ ] Seed sayisi ve yetim tip kimligi dogrulama sorgularini calistir.
- [ ] Quote RPC'sini ekle ve her birimden en az bir ornekle test et.
- [ ] Ortak start/complete RPC'lerini katalog ve snapshot tabanli hale getir.
- [ ] Depo uyumluluk wrapper'ini ve gecis korumalarini ekle.
- [ ] Flutter ortak quote model/provider katmanini ekle.
- [ ] Alti detay ekranini sirayla merkezi quote sistemine bagla.
- [ ] Maksimum seviye ve yetersiz seviye durumlarini arayuze ekle.
- [ ] Unit, widget ve RPC entegrasyon testlerini calistir.
- [ ] `flutter analyze` sonucunu sifir hata ile tamamla.
- [ ] Supabase database ve security advisor sonuclarini kontrol et.
- [ ] Staging verisiyle uctan uca test tamamlanmadan production'a uygulama.

## 10. Zorunlu Test Matrisi

Her alti birim icin asagidaki senaryolar ayri test edilmelidir:

- Seviye 1, 2, 3 ve 4 icin teklif dogrulugu.
- Seviye 5'te teklif ve baslatma reddi.
- Maliyet, sure ve zorunlu oyuncu seviyesi katalogla birebir uyum.
- Kazanimin tamamlamadan once uygulanmamasi.
- Normal sure sonunda kazanimin tam bir kez uygulanmasi.
- Yildizla bitirmede kazanimin tam bir kez uygulanmasi.
- Yetersiz nakitte bakiye ve upgrade kaydinin degismemesi.
- Yetersiz oyuncu seviyesinde islemin reddedilmesi.
- Pasif veya baskasina ait varlikta islemin reddedilmesi.
- Vergi kilidinde islemin reddedilmesi.
- Ayni veya farkli birimde ikinci aktif yukseltmenin reddedilmesi.
- Katalog degeri degisse bile devam eden snapshot sonucunun degismemesi.
- Eszamanli iki baslatma isteginden yalnizca birinin basarili olmasi.

## 11. Veri Dogrulama Sorgulari

Migration sonrasinda en az su kontroller calistirilmalidir:

```sql
-- Her tip/seviye icin tek kayit bulunmali.
select building_kind, building_type_id, from_level, count(*)
from public.building_upgrade_definitions
group by building_kind, building_type_id, from_level
having count(*) <> 1;

-- Her tip icin dort aktif seviye bulunmali.
select building_kind, building_type_id, count(*)
from public.building_upgrade_definitions
where is_active
group by building_kind, building_type_id
having count(*) <> 4;

-- Seviye zinciri kesinlikle 1->2, 2->3, 3->4, 4->5 olmali.
select *
from public.building_upgrade_definitions
where target_level <> from_level + 1
   or from_level not between 1 and 4
   or target_level not between 2 and 5;

-- Definition kaydi olmayan effect bulunmamali.
select e.*
from public.building_upgrade_effects e
left join public.building_upgrade_definitions d
  on d.id = e.upgrade_definition_id
where d.id is null;
```

Tum sorgular sifir satir dondurmelidir.

## 12. Geri Donus Plani

- Ilk migration mevcut RPC'leri veya tablolari silmemeli.
- Yeni katalog once read-only quote olarak devreye alinmali.
- Mutasyonlar ortak RPC'ye alindiktan sonra eski akisa donus icin uyumluluk wrapper'lari korunmali.
- Eski depo sistemi ancak aktif eski upgrade kalmadigi kanitlandiktan sonra temizlenmeli.
- Production migration geri alinacaksa yeni tablo kayitlari silinmeden once mevcut `building_upgrades.params` snapshot'lari korunmali.

## 13. Tamamlanma Kriteri

Gorev ancak su kosullarin tamami saglandiginda tamamlanmis sayilir:

- Alti birimin tum tipleri icin seviye 2-5 katalog kayitlari vardir.
- Maliyet, sure, zorunlu seviye ve kazanimlar yalnizca merkezi katalogdan gelir.
- Flutter tarafinda bu degerleri hesaplayan tekrar kod kalmamistir.
- Seviye 5 sunucu ve arayuz tarafinda kesin olarak son seviyedir.
- Devam eden yukseltmeler snapshot ile deterministik tamamlanir.
- Normal ve yildizli tamamlama ayni sonucu uretir.
- Tum SQL dogrulamalari, testler, `flutter analyze` ve Supabase advisor kontrolleri basarilidir.
