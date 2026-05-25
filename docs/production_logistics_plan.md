# Production Logistics Plan

Bu belge, uretim birimleri ile depolar arasindaki transferlerin lojistik destekli
hale getirilmesi icin uygulanacak backend ve frontend sozlesmesini tanimlar.

## Problem

Su an:

- `transfer_warehouse_slot_to_production_inventory`
- `transfer_production_inventory_to_warehouse`

fonksiyonlari yalnizca ayni sehir icinde calisir.

Bu nedenle:

- baska sehirdeki depodan `factory/field/farm` input beslenemiyor
- baska sehirdeki depoya `factory/field/farm/mine` output gonderilemiyor

## Hedef

Ayni sehir transferleri hizli/anlik olarak aynen kalsin.

Farkli sehir transferleri ise:

- lojistik araci secimi
- transfer suresi
- kiralik/ozmal maliyet mantigi
- transfer map gorunurlugu

ile `logistics_transfers` tabani ustunden ilerlesin.

## Fazlar

### Faz 1: Backend Sozlesmesi

Yeni RPC ailesi:

1. `get_production_input_transfer_vehicle_options`
2. `start_warehouse_to_production_transfer`
3. `get_production_output_transfer_vehicle_options`
4. `start_production_to_warehouse_transfer`
5. `complete_production_logistics_transfer`

Bu fonksiyonlar mevcut ayni-sehir RPC'lerini degistirmeyecek.

### Faz 2: Generic Transfer Kaynagi/Hedefi

`logistics_transfers` yapisi sadece `warehouse/store` odakli gorunuyor.
Uretim lojistigi icin en guvenli yol:

- `seller_entity_kind`
- `buyer_entity_kind`
- `seller_production_inventory_id`
- `buyer_production_inventory_id`

alanlarini eklemek veya mevcut tabloyu ayni anlami verecek sekilde genellestirmek.

Onerilen `entity_kind` degerleri:

- `warehouse`
- `store_slot`
- `production_inventory`

### Faz 3: Factory Pilot

Ilk pilot modulu `Factory` olmali.

UI karari:

- depo ayni sehirdeyse mevcut anlik transfer butonu calissin
- depo farkli sehirdeyse lojistik secim akisi acilsin

### Faz 4: Transfer Map Genisletmesi

Transfer map yalnizca depo/magaza yerine su kaynaklari da gostermeli:

- `Fabrika Input`
- `Fabrika Output`
- `Tarla Input`
- `Tarla Output`
- `Ciftlik Input`
- `Ciftlik Output`
- `Maden Output`

### Faz 5: Diger Modullere Yayin

Pilot bittikten sonra ayni desen:

- `Farm`
- `Field`
- `Mine`

modullerine yayilacak.

## Onerilen RPC Imzalari

### 1. Vehicle Options - Warehouse -> Production Input

```sql
get_production_input_transfer_vehicle_options(
  p_warehouse_slot_id uuid,
  p_production_inventory_id uuid,
  p_quantity integer
)
```

### 2. Start - Warehouse -> Production Input

```sql
start_warehouse_to_production_transfer(
  p_warehouse_slot_id uuid,
  p_production_inventory_id uuid,
  p_quantity integer,
  p_vehicle_id uuid default null
)
```

Beklenen davranis:

- quantity kaynaktan dusmeli veya reserve edilmeli
- transfer kaydi `logistics_transfers` icine acilmali
- hedef `production_inventory.pending_quantity` artmali

### 3. Vehicle Options - Production Output -> Warehouse

```sql
get_production_output_transfer_vehicle_options(
  p_production_inventory_id uuid,
  p_buyer_warehouse_id uuid,
  p_quantity integer
)
```

### 4. Start - Production Output -> Warehouse

```sql
start_production_to_warehouse_transfer(
  p_production_inventory_id uuid,
  p_buyer_warehouse_id uuid,
  p_quantity integer,
  p_vehicle_id uuid default null
)
```

### 5. Completion

```sql
complete_production_logistics_transfer(
  p_transfer_id uuid
)
```

Beklenen davranis:

- `warehouse -> production` ise hedef inventory quantity artar, pending azalir
- `production -> warehouse` ise hedef warehouse slot quantity artar
- cost/maliyet bilgisi agirlikli ortalama ile guncellenir
- transfer `completed` olur

## Frontend Entegrasyon Kurallari

Her uretim detay ekraninda iki mod olacak:

1. Ayni sehir
   Mevcut RPC ile anlik transfer

2. Farkli sehir
   Yeni lojistik akisi:
   - hedef/kaynak depo sec
   - arac sec
   - transfer baslat
   - transfer map uzerinden izle

## Ilk Kodlama Sirasi

1. Backend migration/sql taslagi
2. Flutter ortak production logistics servis katmani
3. Factory input akisi
4. Factory output akisi
5. Transfer Map model genisletmesi
6. Farm/Field/Mine yayini
