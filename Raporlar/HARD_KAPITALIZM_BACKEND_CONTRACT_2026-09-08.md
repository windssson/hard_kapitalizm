# HARD KAPİTALİZM — BACKEND CONTRACT & FRONTEND INTEGRATION MAP
**Kaynak:** Canlı Supabase backend (`lpiixtfxldhoyyppavyn`)  
**Tarih:** 2026-09-08  
**Amaç:** Flutter/Codex frontend geliştirmesinde backend'i **source of truth** kabul etmek.

---

# ⛔ CODEX İÇİN ZORUNLU BACKEND KURALLARI

## 1. BACKEND'E DOKUNMA SINIRI

**GET / READ fonksiyonları hariç hiçbir backend değişikliği yapma.**

Kesinlikle yasak:
- Supabase migration oluşturmak
- tablo/kolon/constraint/index/trigger/RLS değiştirmek
- mutation RPC imzasını veya davranışını değiştirmek
- cron job değiştirmek
- production/transfer/market/sale/tax/bank/tender/construction/upgrade/boost mantığını değiştirmek
- Edge Function değiştirmek
- frontend'den DB tablolarına doğrudan INSERT / UPDATE / DELETE yapmak

Frontend mevcut backend sözleşmesine uyarlanacaktır.

## 2. GETTER DEĞİŞİKLİĞİ İÇİN DE ONAY ŞARTI

UI için gereken veri mevcut getter RPC'de yoksa:
1. Önce diğer mevcut getter'larda veriyi ara.
2. Frontend tarafında mevcut response'lardan türetilebiliyorsa backend değişikliği isteme.
3. Gerçekten getter değişikliği gerekiyorsa **kod yazmadan önce kullanıcıya sor.**
4. Kullanıcı açıkça onay vermeden getter RPC'ye dahi dokunma.

Örnek:
> “Bu ekran için `warehouse.city_name` gerekiyor fakat mevcut getter yalnız `city_id` döndürüyor. `get_player_warehouse_detail()` response'una `city_name` eklememi ister misin?”

## 3. MUTATION RPC RESPONSE'LARINI SOURCE OF TRUTH KABUL ET

Mutation sonrası mümkün olduğunca response içindeki `changed` payload'ı ile patch yap.

Öncelik sırası:
1. response patch
2. gerekli küçük getter refresh
3. son çare geniş invalidate

## 4. DB TABLOLARINA FRONTEND'DEN DOĞRUDAN WRITE YAPMA

Authenticated direct table write backend'de kapalıdır.

Doğru:
```dart
supabase.rpc('set_store_slot_price', params: {...});
```

Yanlış:
```dart
supabase.from('store_slots').update(...);
```

## 5. İSİMLENDİRME KONVANSİYONU — ÇOK ÖNEMLİ

| Backend | UI |
|---|---|
| `farm`, `farms`, `farm_types` | **Tarla** |
| `field`, `fields`, `field_types` | **Çiftlik** |
| `factory` | Fabrika |
| `mine` | Maden |
| `store` | Mağaza |
| `warehouse` | Depo |

**farm/field kesinlikle ters çevrilmeyecek.**

---

# 1. GENEL BACKEND MİMARİSİ

- Supabase/PostgreSQL
- Oyuncu kimliği: `auth.uid()`
- Ana player state: `players`
- RPC-first mimari
- Mutating işlemler RPC üzerinden
- Para hareketleri: `player_cash_ledger`
- Vergi: `player_tax_ledger` + `player_taxes`
- Üretim: detail-open + hourly worker
- Mağaza satışı: store detail açılışında işlenir
- Şehir içi transfer: araçsız/anlık
- Şehirler arası transfer: araçlı
- İşletme kurulacak şehirde Genel Depo şartı
- Oyuncu/şehir başına tek aktif Genel Depo
- Oyuncu başına tek aktif building construction
- Oyuncu başına tek aktif building upgrade
- entity başına tek aktif boost

---

# 2. OYUNCU / PROFİL

## `players`

| Kolon | Tip | Not |
|---|---|---|
| `id` | uuid | auth user id |
| `company_name` | text | şirket adı |
| `avatar_id` | text | ör. `ae1.webp` |
| `level` | integer | seviye |
| `experience` | integer | exp |
| `cash` | numeric | negatif olamaz |
| `gold` | numeric | premium para |
| `player_name` | text | oyuncu adı |
| `google_email` | text? | server-derived |
| `google_avatar_url` | text? | server-derived |
| `last_seen_at` | timestamptz? | |
| `headquarters_city_id` | uuid? | canonical merkez şehir |
| `starter_pack_claimed` | boolean | starter durumu |
| `created_at` | timestamptz | |

### Getter'lar

```text
get_player_profile(p_player_id uuid) -> jsonb
get_public_player_profile(p_player_id uuid) -> jsonb
get_homepage_dashboard() -> jsonb
get_homepage_dashboard_summary(p_player_id uuid) -> jsonb
```

Başka oyuncunun public profile'ında `cash/gold` bekleme.

### `get_homepage_dashboard()` ana shape

```json
{
  "success": true,
  "player": {
    "id": "...",
    "player_name": "...",
    "company_name": "...",
    "avatar_id": "...",
    "level": 1,
    "cash": 0,
    "gold": 0,
    "current_level_experience": 0,
    "next_level_required_experience": 0,
    "exp_progress_ratio": 0,
    "achievement_unlocked_count": 0,
    "achievement_total_count": 0
  },
  "company": {
    "company_value": 0,
    "today_profit": 0,
    "active_business_count": 0,
    "total_business_count": 0,
    "headquarters_city_name": "Van",
    "company_status": "istikrarli",
    "company_value_history": []
  },
  "hourly_income_estimate": {},
  "finance_today": {
    "revenue": 0,
    "production_cost": 0,
    "logistics_cost": 0,
    "net_profit": 0
  },
  "notification_summary": {
    "unread_count": 0,
    "active_warning_count": 0
  },
  "operational_alerts": [],
  "ongoing_activities": [],
  "active_productions": [],
  "modules": {
    "stores": {},
    "warehouses": {},
    "factories": {},
    "fields": {},
    "farms": {},
    "mines": {},
    "logistics": {},
    "arge": {}
  }
}
```

---

# 3. ŞEHİRLER

## `cities`

Temel kolonlar:
```text
id uuid
name text
population integer
tax_rate numeric
map_position_x numeric
map_position_y numeric
is_active boolean
created_at timestamptz
bonus_* numeric
```

Şehir bonus category key'i frontend'de türetilmemeli.
Canonical helper:
```text
city_bonus_json_key(p_category text) -> text
```

Getter'lar:
```text
get_active_cities() -> jsonb
get_cities_catalog(p_only_active boolean) -> jsonb
get_city_map_detail(p_city_id uuid) -> jsonb
get_city_store_saturations(p_city_id uuid) -> jsonb
get_player_facility_cities_summary(p_player_id uuid) -> jsonb
```

---

# 4. ÜRÜNLER

## `products`

```text
id text
urun_adi text
urun_iconu text
birim_hacim numeric
birim_agirlik numeric
hammadde_1_id text?
hammadde_1_miktar numeric?
hammadde_2_id text?
hammadde_2_miktar numeric?
hammadde_3_id text?
hammadde_3_miktar numeric?
uretim_birimi text
baz_satis_fiyati numeric
uretim_adedi integer
satis_adedi integer
en_dusuk_fiyat numeric
en_yuksek_fiyat numeric
ortalama_fiyat numeric
satici_sayisi integer
piyasadaki_stok integer
iscilik_maliyeti numeric
kategori text
```

Getter'lar:
```text
get_all_products_catalog() -> jsonb
get_static_catalogs_bundle() -> jsonb
get_product_price_history(p_product_id text) -> jsonb
get_producible_products_for_owner_type(p_player_id uuid, p_owner_kind text, p_type_id uuid)
  -> TABLE(id, urun_adi, urun_iconu, birim_hacim, birim_agirlik,
           hammadde_1_id, hammadde_1_miktar,
           hammadde_2_id, hammadde_2_miktar,
           hammadde_3_id, hammadde_3_miktar,
           uretim_birimi, baz_satis_fiyati, uretim_adedi, satis_adedi,
           en_dusuk_fiyat, en_yuksek_fiyat, ortalama_fiyat,
           satici_sayisi, piyasadaki_stok, created_at,
           max_quality_level, preferred_brand_id)
```

---

# 5. GENEL DEPO

## Kurallar
- Store-linked depo sistemi kaldırıldı.
- `warehouses.store_id` YOK.
- Her şehirde oyuncu başına max 1 Genel Depo.
- İşletme kurulmadan önce şehirde Genel Depo olmalı.
- Mağaza satışı depoyu satmaz.

## `warehouses`
```text
id uuid
player_id uuid
warehouse_type_id uuid
city_id uuid
name text
level integer
capacity numeric
is_active boolean
reserved_capacity numeric
warehouse_kind text
created_at/updated_at
```

## `warehouse_slots`
```text
id uuid
warehouse_id uuid
slot_index integer
product_id text?
quality_level integer
quantity integer
cost numeric
is_available_for_sale boolean
price numeric
brand_id uuid
pending_quantity integer
created_at/updated_at
```

Kapasite:
```text
sum((quantity + pending_quantity) * product.birim_hacim)
+ warehouses.reserved_capacity
```

Getter'lar:
```text
get_warehouse_types_catalog() -> jsonb
get_warehouse_type_detail(p_type_id uuid) -> jsonb
get_warehouse_list_page_data() -> jsonb
get_player_warehouses_raw() -> jsonb
get_player_active_warehouses_basic() -> jsonb
get_player_active_warehouses_with_slots(p_city_id uuid) -> jsonb
get_player_warehouse_detail(p_warehouse_id uuid) -> jsonb
get_market_buyer_warehouse_detail(p_warehouse_id uuid) -> jsonb
get_warehouse_capacity_status(p_warehouse_id uuid)
  -> TABLE(warehouse_id, total_capacity, used_capacity, reserved_capacity, available_capacity)
get_warehouse_history_items(p_warehouse_id uuid)
  -> TABLE(id, direction, transfer_type, status, happened_at, started_at, finish_at,
           completed_at, product_id, product_name, product_icon, quality_level,
           brand_id, quantity, total_price, transport_cost, rental_cost, is_rental,
           source_name, source_kind, source_city_name,
           target_name, target_kind, target_city_name)
```

Mutation:
```text
delete_warehouse_slot(p_player_id uuid, p_warehouse_slot_id uuid) -> jsonb
discard_warehouse_slot(p_player_id uuid, p_warehouse_slot_id uuid) -> jsonb
set_warehouse_slot_price(p_player_id uuid, p_warehouse_slot_id uuid, p_price numeric) -> jsonb
set_warehouse_slot_sale_status(p_player_id uuid, p_warehouse_slot_id uuid, p_is_available_for_sale boolean) -> jsonb
```

---

# 6. MAĞAZA

## `stores`
```text
id uuid
player_id uuid
store_type_id uuid
city_id uuid
name text
level integer
current_slot_count integer
max_slot_count integer
slot_capacity integer
is_active boolean
created_at/updated_at
```

## `store_types`
```text
id
name
icon
accepted_product_ids
cost
required_level
base_slot_count
construction_time_minutes
max_slot_count
slot_capacity
warehouse_type_id (legacy alan; linked-depot modeli için kullanma)
```

## `store_slots`
```text
id
store_id
slot_index
product_id?
quantity
quality_level
price
cost
boost_multiplier
pending_sale
is_active
capacity
last_sale_processed_at
pending_quantity
brand_id
created_at/updated_at
```

## Satış motoru

```text
open_store_detail_page(p_store_id uuid) -> jsonb
```

**Pure GET değildir.** Side-effect:
- satış hesaplar
- cash ekler
- ledger yazar
- vergi accrue eder
- XP verebilir
- store_daily_performance günceller

Aynı ekran lifecycle'ında paralel/tekrarlı çağrı yapma.

Önemli response alanları:
```text
success
store
active_boost
active_upgrade
sale_result
performance
changed.player
changed.history_dirty
changed.performance_dirty
changed.tax_dirty
```

Getter'lar:
```text
get_store_types_catalog() -> jsonb
get_store_list_page_data() -> jsonb
get_available_products_for_store(p_store_id uuid) -> jsonb
get_store_daily_performance(p_player_id uuid, p_store_id uuid, p_days integer) -> jsonb
```

Mutation:
```text
add_store_slot(p_player_id uuid, p_store_id uuid) -> jsonb
set_store_active(p_store_id uuid, p_is_active boolean) -> jsonb
set_store_slot_active(p_player_id uuid, p_store_slot_id uuid, p_is_active boolean) -> jsonb
set_store_slot_price(p_player_id uuid, p_store_slot_id uuid, p_price numeric) -> jsonb
bulk_update_store_slot_prices(p_player_id uuid, p_store_id uuid, p_markup_percent numeric) -> jsonb
set_store_slot_product_from_warehouse_slot(p_player_id uuid, p_store_slot_id uuid, p_warehouse_slot_id uuid) -> jsonb
clear_store_slot_product(p_player_id uuid, p_store_slot_id uuid) -> jsonb
fill_store_shelves(p_player_id uuid, p_store_id uuid) -> jsonb
transfer_city_warehouse_to_store_slot(p_player_id uuid, p_warehouse_slot_id uuid, p_store_slot_id uuid, p_quantity integer) -> jsonb
transfer_store_slot_to_city_warehouse(p_player_id uuid, p_store_slot_id uuid, p_quantity integer) -> jsonb
sell_store(p_store_id uuid, p_confirm boolean) -> jsonb
```

---

# 7. ÜRETİM ORTAK MODELİ

Backend/UI:
```text
factory = Fabrika
farm    = Tarla
field   = Çiftlik
mine    = Maden
```

## `production_inventory`
```text
id uuid
owner_kind text
owner_id uuid
inventory_type text   # input/output
product_id text
quality_level integer
quantity integer
pending_quantity numeric
cost numeric
brand_id uuid
created_at/updated_at
```

## `production_slots`
Canlı modelde Tarla/Çiftlik slotları:
```text
id uuid
owner_kind text       # farm/field
owner_id uuid
slot_index integer
product_id text?
quality_level integer
boost_multiplier numeric
is_active boolean
last_production_at timestamptz
brand_id uuid
created_at/updated_at
```

---

# 8. FABRİKA

## `factories`
```text
id
player_id
factory_type_id
city_id
name
level
product_id?
quality_level
input_capacity
output_capacity
boost_multiplier
is_active
last_production_at
brand_id
created_at/updated_at
```

Getter:
```text
get_factory_types_catalog() -> jsonb
get_factory_list_items() -> jsonb
get_factory_detail_data(p_factory_id uuid) -> jsonb
```

Canonical mutation:
```text
set_factory_product(p_player_id uuid, p_factory_id uuid, p_product_id text, p_quality_level integer, p_brand_id uuid) -> jsonb
set_factory_active(p_factory_id uuid, p_is_active boolean) -> jsonb
```

Compatibility 4-param `set_factory_product` vardır; yeni frontend brand destekli imzayı tercih etsin.

---

# 9. TARLA — BACKEND `farm`

## `farms`
```text
id
player_id
farm_type_id
city_id
name
level
current_slot_count
max_slot_count
input_capacity
output_capacity
is_active
created_at/updated_at
```

Getter:
```text
get_farm_types_catalog() -> jsonb
get_farm_list_items() -> jsonb
get_farm_detail(p_player_id uuid, p_farm_id uuid) -> jsonb
```

Mutation slot API:
```text
add_production_slot(p_player_id uuid, p_owner_kind text, p_owner_id uuid) -> jsonb
assign_production_slot_product(p_player_id uuid, p_production_slot_id uuid, p_product_id text, p_quality_level integer, p_brand_id uuid) -> jsonb
change_production_slot_product(p_player_id uuid, p_production_slot_id uuid, p_product_id text, p_quality_level integer, p_brand_id uuid) -> jsonb
set_production_slot_active(p_player_id uuid, p_production_slot_id uuid, p_is_active boolean) -> jsonb
```

`p_owner_kind='farm'` = Tarla.

---

# 10. ÇİFTLİK — BACKEND `field`

## `fields`
```text
id
player_id
field_type_id
city_id
name
level
current_slot_count
max_slot_count
input_capacity
output_capacity
is_active
created_at/updated_at
```

Getter:
```text
get_field_types_catalog() -> jsonb
get_field_list_items() -> jsonb
get_field_detail_data(p_field_id uuid) -> jsonb
```

Slot mutation'ları Tarla ile aynı; `owner_kind='field'`.

---

# 11. MADEN

## `mines`
```text
id
player_id
mine_type_id
city_id
name
level
product_id?
quality_level
output_capacity
boost_multiplier
is_active
last_production_at
brand_id
created_at/updated_at
```

Getter:
```text
get_mine_types_catalog() -> jsonb
get_mine_list_items() -> jsonb
get_mine_detail_data(p_mine_id uuid) -> jsonb
```

Canonical mutation:
```text
set_mine_product(p_player_id uuid, p_mine_id uuid, p_product_id text, p_quality_level integer, p_brand_id uuid) -> jsonb
set_mine_active(p_mine_id uuid, p_is_active boolean) -> jsonb
```

Compatibility overload'ları da vardır; yeni frontend 5-param canonical imzayı kullansın.

---

# 12. PRODUCTION PROCESSING — FRONTEND DİKKAT

Normal detail processing giriş noktası:
```text
process_player_production_entry(p_player_id uuid, p_owner_kind text, p_owner_id uuid) -> jsonb
```

Frontend internal/core fonksiyonları çağırmamalı:
```text
process_player_production_core(...)
process_factory_production_entry(...)
process_field_farm_production_entry(...)
process_mine_production_entry(...)
process_all_players_production()
```

Hourly cron da üretimi işler.

---

# 13. İNŞAAT

## `building_constructions`
```text
id
player_id
building_kind
params jsonb
status
started_at
finish_at
completed_at
updated_at
```

Oyuncu başına tek aktif construction.

Generic:
```text
start_building_construction(p_player_id uuid, p_city_id uuid, p_building_kind text, p_type_id uuid, p_name text) -> jsonb
```
Destek: store, warehouse, factory, field, farm, mine.

Lojistik canonical:
```text
start_logistics_company_construction(p_player_id uuid, p_type_id uuid, p_city_id uuid, p_name text) -> jsonb
```

Legacy overload:
```text
start_logistics_company_construction(p_player_id uuid, p_type_id uuid, p_name text) -> jsonb
```
Legacy HQ city kullanır. Yeni frontend canonical 4-param imzayı kullansın.

Ar-Ge:
```text
start_arge_center_construction(p_player_id uuid, p_name text) -> jsonb
```

Getter:
```text
get_player_building_constructions(p_building_kind text, p_status text) -> jsonb
```

Speedup:
```text
finish_construction_with_gold(p_player_id uuid, p_construction_id uuid) -> jsonb
reduce_construction_time_with_ad(p_player_id uuid, p_construction_id uuid, p_minutes integer) -> jsonb
```

---

# 14. UPGRADE

## `building_upgrades`
```text
id
player_id
building_kind
entity_id
current_level
target_level
params jsonb
status
started_at
finish_at
completed_at
created_at/updated_at
```

Oyuncu başına tek aktif upgrade.

Getter:
```text
get_building_upgrade_quote(p_building_kind text, p_entity_id uuid) -> jsonb
get_player_active_building_upgrade(p_building_kind text, p_entity_id uuid) -> jsonb
get_player_any_active_building_upgrade() -> building_upgrades
get_player_active_warehouse_upgrade(p_warehouse_id uuid) -> building_upgrades
```

Mutation:
```text
start_building_upgrade(p_player_id uuid, p_building_kind text, p_entity_id uuid) -> jsonb
finish_building_upgrade_with_gold(p_player_id uuid, p_upgrade_id uuid) -> jsonb
reduce_building_upgrade_time_with_ad(p_player_id uuid, p_upgrade_id uuid, p_minutes integer) -> jsonb
```

Internal completion frontend'den çağrılmamalı.

---

# 15. BOOST

## `building_boosts`
```text
id
player_id
building_kind
entity_id
duration_hours
star_cost
multiplier
params
status
started_at
finish_at
completed_at
created_at/updated_at
```

Aynı entity için tek aktif boost.

Tarife:
```text
6 saat  = 3 gold
12 saat = 6 gold
24 saat = 12 gold
```

Getter:
```text
get_player_active_building_boost(p_building_kind text, p_entity_id uuid) -> jsonb
```

Mutation:
```text
start_building_boost(p_player_id uuid, p_building_kind text, p_entity_id uuid, p_duration_hours integer, p_star_cost integer) -> jsonb
start_building_boost_with_ad_reward(p_player_id uuid, p_building_kind text, p_entity_id uuid, p_duration_minutes integer) -> jsonb
```

`p_star_cost` client input olsa da canonical fiyatı backend hesaplar.

---

# 16. BİNA SATIŞI

```text
sell_building(p_building_id uuid, p_building_kind text, p_confirm boolean) -> jsonb
```

Destek:
- warehouse
- factory
- farm (Tarla)
- field (Çiftlik)
- mine
- store => `sell_store`

Refund:
- base cost %70
- completed upgrade costs %70
- mevcut gerçek stok weighted cost %100

Aktif transfer / upgrade / boost guard'ları vardır.

`p_confirm=false`: teklif/preview  
`p_confirm=true`: gerçek satış

---

# 17. LOJİSTİK ŞİRKETİ / ARAÇLAR

## `logistics_companies`
```text
id
player_id
city_id
name
level
current_vehicle_count
max_vehicle_count
fuel_capacity
current_fuel
fuel_cost
is_active
logistics_company_type_id
created_at/updated_at
```

## `logistics_vehicles`
```text
id
player_id
logistics_company_id
logistics_vehicle_type_id
capacity
speed_kmh
fuel_capacity
current_fuel
fuel_rate
condition
status
is_available_for_rent
rental_price
route_city_a_id
route_city_b_id
fuel_cost
is_npc_fallback
created_at/updated_at
```

Şehir içi:
- araç yok
- fuel yok
- condition loss yok
- fee yok
- instant

Şehirler arası:
- route-compatible araç gerekir

Getter:
```text
get_logistics_company_types_catalog() -> jsonb
get_logistics_vehicle_types_catalog() -> jsonb
get_player_logistics_company() -> jsonb
get_player_logistics_vehicles(p_player_id uuid) -> jsonb
get_logistics_entry_state() -> jsonb
get_player_logistics_finance_entries(p_limit integer) -> jsonb
get_player_logistics_finance_summary() -> jsonb
get_player_logistics_vehicle_performance() -> jsonb
get_route_transfer_vehicle_options(p_source_city_id uuid, p_target_city_id uuid, p_total_volume numeric)
  -> TABLE(vehicle_id, vehicle_owner_player_id, vehicle_name, is_rental,
           capacity, speed_kmh, current_fuel, fuel_capacity, fuel_rate,
           condition, rental_price, distance_km, fuel_needed, condition_needed,
           rental_cost, fuel_cost, total_price, estimated_duration_seconds,
           can_select, disabled_reason)
```

Mutation:
```text
purchase_logistics_vehicle(p_player_id uuid, p_logistics_company_id uuid, p_logistics_vehicle_type_id uuid) -> jsonb
set_logistics_vehicle_active(p_player_id uuid, p_vehicle_id uuid, p_is_active boolean) -> jsonb
set_logistics_vehicle_route(p_player_id uuid, p_vehicle_id uuid, p_route_city_a_id uuid, p_route_city_b_id uuid) -> jsonb
set_logistics_vehicle_rental(p_player_id uuid, p_vehicle_id uuid, p_is_available_for_rent boolean, p_rental_price numeric) -> jsonb
refuel_logistics_vehicle(p_player_id uuid, p_vehicle_id uuid) -> jsonb
refuel_all_logistics_vehicles(p_player_id uuid) -> jsonb
repair_logistics_vehicle(p_player_id uuid, p_vehicle_id uuid) -> jsonb
repair_all_logistics_vehicles(p_player_id uuid) -> jsonb
transfer_warehouse_fuel_to_logistics_company(p_logistics_company_id uuid, p_warehouse_slot_id uuid, p_quantity integer) -> jsonb
```

---

# 18. TRANSFER MODELİ

## `logistics_transfers`
Ana kolonlar:
```text
id
buyer_player_id
seller_player_id
buyer_warehouse_id?
seller_warehouse_id?
seller_warehouse_slot_id?
logistics_vehicle_id?
vehicle_owner_player_id?
is_rental
product_id
quality_level
quantity
unit_price
total_price
product_unit_volume
reserved_capacity_amount
distance_km
fuel_used
condition_loss
rental_cost
transport_cost
started_at
finish_at
completed_at
status
transfer_type
buyer_store_id?
buyer_store_slot_id?
seller_store_id?
seller_store_slot_id?
seller_entity_kind?
buyer_entity_kind?
seller_production_inventory_id?
buyer_production_inventory_id?
item_count
total_quantity
brand_id
```

## `logistics_transfer_items`
```text
id
transfer_id
source_warehouse_slot_id?
target_warehouse_slot_id?
product_id
quality_level
brand_id
quantity
unit_cost
unit_price
total_cost
total_price
product_unit_volume
reserved_capacity_amount
status
completed_at?
target_production_inventory_id?
created_at/updated_at
```

Getter:
```text
get_buyer_transfer_map_items() -> jsonb
get_buyer_transfer_history_items() -> jsonb
get_logistics_transfer_items(p_transfer_id uuid)
  -> TABLE(id, product_id, product_name, product_icon, quality_level,
           brand_id, brand_name, quantity, total_price)
```

Mutation:
```text
start_multi_market_transfer(p_buyer_warehouse_id uuid, p_source_city_id uuid, p_items jsonb, p_vehicle_id uuid) -> jsonb
start_multi_production_to_warehouse_transfer(p_source_owner_kind text, p_source_owner_id uuid, p_buyer_warehouse_id uuid, p_items jsonb, p_vehicle_id uuid) -> jsonb
start_multi_warehouse_to_production_transfer(p_source_warehouse_id uuid, p_items jsonb, p_vehicle_id uuid, p_production_inventory_id uuid) -> jsonb
start_warehouse_to_warehouse_transfer(p_source_warehouse_id uuid, p_buyer_warehouse_id uuid, p_items jsonb, p_vehicle_id uuid) -> jsonb
```

City consolidated:
```text
get_city_consolidated_transfer_source_cities() -> jsonb
get_city_consolidated_transfer_targets() -> jsonb
get_city_consolidated_transfer_candidates(p_source_city_id uuid, p_target_entity_kind text, p_target_entity_id uuid) -> jsonb
start_city_consolidated_transfer(p_source_city_id uuid, p_target_entity_kind text, p_target_entity_id uuid, p_items jsonb, p_vehicle_id uuid) -> jsonb
```

Completion/speedup:
```text
complete_logistics_transfer(p_transfer_id uuid) -> jsonb
finish_logistics_transfer_with_gold(p_transfer_id uuid) -> jsonb
finish_logistics_transfer_with_ad_reward(p_transfer_id uuid) -> jsonb
```

NPC market item server-side Q1 + markasızdır.
Aynı oyuncunun şehir içi kendi stok hareketi XP vermez.

---

# 19. PAZAR

Getter:
```text
get_market_listings_for_city(p_city_id uuid)
  -> TABLE(slot_id, product_id, product_name, product_icon, brand_id, unit_volume,
           warehouse_id, warehouse_name, warehouse_icon,
           city_id, city_name, city_x, city_y,
           seller_player_id, seller_player_name, seller_avatar_id,
           seller_google_avatar_url, quantity, quality_level, price, cost,
           is_available_for_sale)
get_market_listings_for_product(p_product_id text) -> TABLE(...)
get_market_listings_for_player(p_player_id uuid) -> TABLE(...)
get_market_product_detail(p_product_id text) -> jsonb
get_seller_market_sales_history(p_limit integer) -> jsonb
get_npc_market_unit_price(p_product_id text) -> numeric
```

---

# 20. AR-GE / QUALITY

## `arge_centers`
```text
id
player_id
name
level
max_concurrent_researches
duration_reduction_pct
is_active
created_at/updated_at
```

## `arge_researches`
```text
id
player_id
product_id
product_name
current_quality
target_quality
cost_paid
status
started_at
finish_at
completed_at
created_at
```

## `player_product_quality_levels`
```text
id
player_id
product_id
max_quality_level
created_at/updated_at
```

Kalite 1–5 ve monotonic.

Getter:
```text
get_player_arge_center() -> jsonb
get_active_arge_researches(p_player_id uuid) -> jsonb
get_arge_products_with_quality() -> jsonb
```

Mutation:
```text
start_arge_research(p_player_id uuid, p_product_id text) -> jsonb
finish_arge_with_gold(p_player_id uuid, p_research_id uuid) -> jsonb
```

---

# 21. MARKA

Unbranded UUID:
```text
00000000-0000-0000-0000-000000000000
```

## `brand_companies`
```text
id
player_id
brand_name
is_active
brand_level
brand_xp
logo_id
theme_color
created_at/updated_at
```

## `brand_company_products`
```text
id
brand_company_id
player_id
product_id
is_active
watermark_asset_id
created_at/updated_at
```

## `brand_marketing_campaigns`
```text
id
player_id
campaign_type
cost_paid
active_until
sales_speed_multiplier
price_premium_multiplier
created_at
```

Getter:
```text
get_player_brand_company() -> jsonb
get_player_brand_company_products() -> TABLE(product_id, product_name, product_icon, max_quality_level, is_branded, branded_at, watermark_asset_id)
get_player_brand_performance() -> jsonb
get_active_marketing_campaigns() -> jsonb
```

Mutation:
```text
create_brand_company(p_brand_name text, p_logo_id text, p_theme_color text) -> jsonb
update_brand_company(p_logo_id text, p_theme_color text, p_brand_name text) -> jsonb
patent_brand_company_product(p_product_id text) -> jsonb
set_brand_company_product_watermark(p_product_id text, p_watermark_asset_id text) -> jsonb
start_marketing_campaign(p_campaign_type text) -> jsonb
```

---

# 22. BANKA

## `player_loans`
```text
id
player_id
amount
interest_rate
total_due
total_paid
installments_total
installments_paid
installment_amount
next_installment_due_at
status
created_at/updated_at
```

## `player_deposits`
```text
id
player_id
amount
interest_rate
expected_payout
locked_until
status
created_at/updated_at
```

Getter:
```text
get_player_loan_limit(p_player_id uuid) -> numeric
get_player_max_deposit_limit(p_player_id uuid) -> numeric
```

Mutation:
```text
take_loan(p_amount numeric, p_installments integer) -> jsonb
pay_loan_installment(p_loan_id uuid) -> jsonb
pay_full_loan(p_loan_id uuid) -> jsonb
create_deposit(p_amount numeric, p_days integer) -> jsonb
claim_deposit(p_deposit_id uuid) -> jsonb
withdraw_deposit_early(p_deposit_id uuid) -> jsonb
```

Company value: deposits asset; kalan aktif kredi liability.

---

# 23. VERGİ / CASH LEDGER

## `player_taxes`
```text
player_id uuid
tax_debt numeric
created_at/updated_at
```

## `player_tax_ledger`
```text
id
player_id
city_id?
entry_type
source_type
source_id?
cash_ledger_id?
taxable_amount?
tax_rate?
tax_amount
note?
created_at
```

`cash_ledger_id` üzerinden idempotency vardır.

## `player_cash_ledger`
```text
id
player_id
created_at
amount
balance_before
balance_after
category
note?
ref_id?
ref_kind?
```

Getter:
```text
get_player_tax_debt() -> numeric
get_player_tax_limit(p_level integer) -> numeric
get_player_tax_status() -> jsonb
get_player_tax_ledger(p_limit integer) -> jsonb
is_player_tax_blocked(p_player_id uuid) -> boolean
get_player_cash_ledger(p_limit integer, p_offset integer) -> jsonb
```

Mutation:
```text
pay_tax_debt(p_amount numeric) -> jsonb
```

---

# 24. İHALE

Ana tablolar:
```text
tenders
tender_bids
player_tenders
tender_deliveries
```

Exact quality gerekir.

Getter:
```text
get_tender_center() -> jsonb
get_tender_detail(p_tender_id uuid, p_player_tender_id uuid) -> jsonb
```

Mutation:
```text
accept_tender(p_tender_id uuid) -> jsonb
submit_tender_bid(p_tender_id uuid, p_bid_amount numeric) -> jsonb
cancel_player_tender(p_player_tender_id uuid) -> jsonb
start_tender_delivery(p_player_tender_id uuid, p_warehouse_id uuid, p_vehicle_id uuid, p_quantity integer) -> jsonb
```

Şehir içi tender delivery araçsız; şehirler arası route-compatible araç.

---

# 25. MISSION / ACHIEVEMENT

Canonical tablolar:
```text
mission_definitions
player_missions
```

Getter:
```text
get_player_mission_dashboard() -> jsonb
get_player_achievement_dashboard() -> jsonb
```

Mutation:
```text
claim_player_mission_reward(p_mission_id text) -> jsonb
claim_player_achievement_reward(p_achievement_id text) -> jsonb
```

Internal progress helper'larını frontend çağırmamalı.

---

# 26. LEADERBOARD

Raw `player_leaderboard_stats` tabloya frontend bağlanmamalı.
Private internal alanlar içerir: cash, gold, deposit_value, inventory breakdown vb.

Getter:
```text
get_leaderboard(p_sort_by_field text, p_limit integer, p_city_id uuid) -> jsonb
get_player_leaderboard_rank_info(p_player_id uuid, p_sort_by_field text, p_city_id uuid) -> jsonb
```

---

# 27. NOTIFICATION / PUSH

## `player_notifications`
```text
id
player_id
title
message
category
entity_type?
entity_id?
is_read
created_at
```

Canonical naming:
```text
farm  = Tarla
field = Çiftlik
```

Getter:
```text
get_player_notifications(p_limit integer, p_offset integer, p_category text)
  -> TABLE(id, player_id, title, message, category, entity_type, entity_id, is_read, created_at)
get_unread_notification_count() -> integer
get_player_operational_alerts(p_player_id uuid) -> jsonb
```

Operational alert shape:
```json
{
  "success": true,
  "alerts": [
    {
      "id": "factory_no_input",
      "severity": "critical",
      "category": "factory",
      "title": "...",
      "description": "...",
      "route": "/factories",
      "count": 1
    }
  ],
  "total_count": 1
}
```

Mutation:
```text
mark_notification_read(p_notification_id uuid) -> boolean
mark_all_notifications_read() -> boolean
clear_player_notifications(p_only_read boolean) -> boolean
register_push_token(p_token text, p_device_id text) -> jsonb
unregister_push_token(p_token text) -> jsonb
```

---

# 28. DAILY STATS

## `player_daily_production_stats`
```text
production_date date
player_id uuid
owner_kind text
owner_id uuid
product_id text
produced_quantity bigint
total_cost numeric
created_at/updated_at
```

Gün sınırı: **Europe/Istanbul**.

Getter:
```text
get_player_daily_production_stats(p_owner_kind text, p_owner_id uuid, p_date_from date, p_date_to date)
  -> TABLE(production_date, owner_kind, owner_id, product_id, product_name,
           product_icon, base_sale_price, produced_quantity, total_cost,
           estimated_revenue, estimated_profit)
```

---

# 29. REWARDED ADS

Getter:
```text
get_rewarded_ad_reward_status(p_player_id uuid, p_reward_kind text, p_resource_id text) -> jsonb
```

Not: public release öncesi AdMob SSV ayrı launch-hardening konusu olarak değerlendirilmiştir.

---

# 30. CHAT / DM

Mutation:
```text
send_chat_message(
  p_content text,
  p_channel text,
  p_linked_listing_slot_id uuid,
  p_linked_product_id text,
  p_linked_product_name text,
  p_linked_product_icon text,
  p_linked_product_quality_level integer,
  p_linked_product_quantity integer,
  p_linked_product_price numeric,
  p_reply_to_message_id uuid
) -> jsonb

send_direct_message(p_receiver_id uuid, p_content text) -> jsonb
report_chat_message(p_message_id uuid, p_reason text, p_details text) -> jsonb
```

Linked product/listing metadata backend server-side derive edilir; client metadata trusted değildir.

---

# 31. PROFİL MUTATION'LARI

```text
sync_player_google_profile(p_player_name text, p_google_email text, p_google_avatar_url text) -> jsonb
update_company_name(p_company_name text) -> jsonb
set_player_avatar(p_avatar_id text) -> jsonb
set_player_headquarters_city(p_city_id uuid) -> jsonb
delete_own_account() -> jsonb
```

`sync_player_google_profile` email/avatar için auth.users'ı source of truth kabul eder.

---

# 32. STARTER / SESSION

```text
bootstrap_game_session(p_city_id uuid) -> jsonb
ensure_player_record_exists(p_user_id uuid, p_city_id uuid) -> jsonb
grant_starter_package(p_player_id uuid, p_city_id uuid) -> jsonb
```

Starter mantığını frontend kendi insert'leriyle kurmamalı.

---

# 33. STATIC CATALOG GETTER'LARI

```text
get_static_catalogs_bundle() -> jsonb
get_active_cities() -> jsonb
get_cities_catalog(p_only_active boolean) -> jsonb
get_all_products_catalog() -> jsonb
get_store_types_catalog() -> jsonb
get_warehouse_types_catalog() -> jsonb
get_factory_types_catalog() -> jsonb
get_farm_types_catalog() -> jsonb
get_field_types_catalog() -> jsonb
get_mine_types_catalog() -> jsonb
get_logistics_company_types_catalog() -> jsonb
get_logistics_vehicle_types_catalog() -> jsonb
```

---

# 34. DİĞER ÖNEMLİ GETTER / READ RPC ENVANTERİ

```text
get_active_marketing_campaigns() -> jsonb
get_arge_products_with_quality() -> jsonb
get_building_sale_capital_refund_rate() -> numeric
get_building_upgrade_quote(...) -> jsonb
get_buyer_transfer_history_items() -> jsonb
get_buyer_transfer_map_items() -> jsonb
get_city_consolidated_transfer_candidates(...) -> jsonb
get_city_consolidated_transfer_source_cities() -> jsonb
get_city_consolidated_transfer_targets() -> jsonb
get_experience_required_for_level(p_level integer) -> integer
get_logistics_transfer_items(...) -> TABLE(...)
get_npc_logistics_player_id() -> uuid
get_npc_market_unit_price(p_product_id text) -> numeric
get_npc_rental_vehicle_option(...) -> TABLE(...)
get_player_active_building_boost(...) -> jsonb
get_player_active_building_upgrade(...) -> jsonb
get_player_active_products_data(p_player_id uuid) -> jsonb
get_player_brand_performance() -> jsonb
get_player_daily_streak() -> jsonb
get_player_hourly_income_estimate(p_player_id uuid) -> jsonb
get_player_logistics_finance_entries(p_limit integer) -> jsonb
get_player_logistics_finance_summary() -> jsonb
get_player_logistics_vehicle_performance() -> jsonb
get_player_operational_alerts(p_player_id uuid) -> jsonb
get_product_price_history(p_product_id text) -> jsonb
get_rewarded_ad_reward_status(...) -> jsonb
get_route_transfer_vehicle_options(...) -> TABLE(...)
get_seller_market_sales_history(p_limit integer) -> jsonb
resolve_logistics_transfer_source_city(p_transfer_id uuid) -> uuid
resolve_player_product_brand(p_player_id uuid, p_product_id text) -> uuid
resolve_production_inventory_brand(...) -> uuid
store_quality_price_multiplier(p_quality_level integer) -> numeric
calculate_player_company_value(p_player_id uuid) -> jsonb
calculate_store_saturation_multiplier(p_city_id uuid, p_store_type_id uuid) -> numeric
```

---

# 35. INTERNAL / FRONTEND'İN ÇAĞIRMAMASI GEREKENLER

Workers / cron:
```text
process_all_players_production()
complete_due_arge_researches()
complete_due_building_constructions(...)
complete_due_building_upgrades(...)
complete_due_building_boosts(...)
complete_due_market_transfers(...)
process_bank_ticks()
maintain_open_tenders()
update_product_market_stats()
refresh_all_leaderboard_stats()
record_daily_company_value_snapshots()
shift_daily_product_prices()
cleanup_database_bloat()
process_operational_alerts_push_notifications()
process_production_alert_push_notifications()
```

Internal completion/core:
```text
complete_building_construction(...)
complete_building_upgrade(...)
finish_building_boost(...)
complete_logistics_transfer_internal(...)
process_factory_production_entry(...)
process_field_farm_production_entry(...)
process_mine_production_entry(...)
process_player_production_core(...)
```

Accounting/helper:
```text
log_player_cash_change(...)
accrue_player_tax(...)
grant_player_experience(...)
increment_player_mission_progress(...)
increment_player_achievement_progress(...)
process_logistics_vehicle_rental_payout(...)
try_send_operational_alert(...)
send_game_notification(...)
```

Trigger/event-trigger fonksiyonları frontend API değildir.

---

# 36. FRONTEND SENKRONİZASYONUNDA İLK TARANACAKLAR

Codex ilk pass'te özellikle bulsun:

1. `warehouses.store_id` kullanan eski kod
2. mağaza açılınca linked warehouse bekleyen kod
3. `farm=Çiftlik`, `field=Tarla` sanan kod
4. 3-parametreli logistics construction kullanan yeni UI
5. eski mine product imzası kullanan kod
6. brand_id göndermeyen production selection akışları
7. raw `player_leaderboard_stats` select eden kod
8. başka oyuncu profilinde `cash/gold` bekleyen model
9. mutation sonrası blanket `invalidateAll()`
10. şehir içi transfer için araç seçtiren UI
11. store-specific warehouse hedefi gösteren eski transfer UI
12. production daily date'i UTC varsayan UI
13. leaderboard private sort seçenekleri
14. push route mapping'de farm/field tersliği
15. `open_store_detail_page`'i aynı lifecycle'da birden fazla çağıran kod
16. direct `.from(...).insert/update/delete` write kullanımları
17. mutation response `changed` payload'ını ignore eden kod
18. public profile modelinde private alanların zorunlu (`required`) olması

---

# 37. PATCH / INVALIDATE STRATEJİSİ

Mutation sonrası:

## Player
Response `changed.player` varsa global player state patch.

## Entity
Örn. fiyat değişikliği:
- ilgili slot patch
- gerekirse küçük detail refresh
- tüm uygulamayı invalidate etme

## Transfer
Patch:
- player cash
- source stock
- target pending/reserved
- vehicle
- transfer map/history gerekli scope

## Construction
Patch:
- player cash
- active construction
- completion sonrası ilgili list refresh

## Sale
Patch:
- player cash
- entity list remove
- ilgili detail cache remove
- homepage/business count küçük refresh

---

# 38. CODEX ÇALIŞMA METODU

Her modülde:

### 1 — Analiz
- ekran
- repository/service
- provider/notifier
- model
- RPC çağrıları

### 2 — Karşılaştır

```text
CURRENT FRONTEND
BACKEND CONTRACT
MISMATCH
PROPOSED FRONTEND FIX
BACKEND CHANGE REQUIRED? yes/no
```

### 3 — Backend değişmiyorsa frontend'i düzelt

### 4 — Getter değişikliği gerekiyorsa DUR
Kullanıcıdan izin iste.

### 5 — Mutation backend değişikliği gerekiyorsa DUR
Backend'e dokunma; problemi raporla.

---

# 39. CODEX'E VERİLECEK BAŞLANGIÇ PROMPT'U

> Hard Kapitalizm Flutter frontend'ini mevcut Supabase backend sözleşmesine uyarlayacaksın.
>
> `HARD_KAPITALIZM_BACKEND_CONTRACT_2026-09-08.md` backend için source of truth'tur.
>
> Backend'e kesinlikle dokunma.
>
> GET/read RPC'ler haricinde Supabase migration, table, function, trigger, RLS, cron veya Edge Function değişikliği yapma.
>
> UI için gereken veri mevcut getter'larda yoksa getter RPC değiştirmeden önce bana sor.
>
> Mutation RPC'lerin imzalarını ve business logic'ini değiştirme.
>
> DB tablolarına frontend'den direct write yapma; mevcut RPC'leri kullan.
>
> Önce projeyi tara ve backend ile uyuşmayan frontend noktalarını modül modül raporla.
>
> Özellikle:
> - farm = Tarla
> - field = Çiftlik
> - store-linked warehouse sistemi kaldırıldı
> - şehirde işletme için Genel Depo şartı var
> - şehir içi transferde araç yok
> - logistics company canonical construction RPC city_id alır
> - public profile başka oyuncunun cash/gold bilgisini dönmez
> - leaderboard raw table kullanılmaz
> - mutation response'lardaki `changed` payload patch için kullanılmalıdır
>
> Her modülde önce analiz et, sonra frontend değişikliği yap. Backend değişikliği gerekiyorsa kod yazmadan dur ve raporla.

---

# 40. SON PRENSİP

**Backend'i değiştirmek yerine frontend'i backend'e uydur.**

Yeni bir backend bug'ı bulursan:
- frontend workaround ile business/security rule bypass etme
- kendin backend patch atma
- problemi raporla
- kullanıcıdan backend değişikliği onayı bekle
