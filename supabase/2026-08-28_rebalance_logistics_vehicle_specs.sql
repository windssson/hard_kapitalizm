-- Rebalance logistics vehicle specs, fuel capacities, purchase prices, and NPC rental rates

-- 1. Update logistics_vehicle_types
update public.logistics_vehicle_types
set
  capacity = 12,
  speed_kmh = 120,
  fuel_capacity = 80,
  fuel_rate = 0.03,
  purchase_price = 150000
where name = 'Hızlı Kurye 250';

update public.logistics_vehicle_types
set
  capacity = 22,
  speed_kmh = 100,
  fuel_capacity = 180,
  fuel_rate = 0.01,
  purchase_price = 450000
where name = 'VoltExpress E-Truck';

update public.logistics_vehicle_types
set
  capacity = 35,
  speed_kmh = 90,
  fuel_capacity = 250,
  fuel_rate = 0.07,
  purchase_price = 650000
where name = 'Anadolu Aslanı';

update public.logistics_vehicle_types
set
  capacity = 55,
  speed_kmh = 80,
  fuel_capacity = 450,
  fuel_rate = 0.11,
  purchase_price = 1200000
where name = 'Kıtalararası Trans';

-- 2. Update game_settings for NPC rental prices
insert into public.game_settings (key, value_text, description, updated_at)
values
  ('npc_rental_price_Hızlı Kurye 250', '4.0', 'NPC Kiralama Bedeli (₺/km)', timezone('utc'::text, now())),
  ('npc_rental_price_VoltExpress E-Truck', '8.0', 'NPC Kiralama Bedeli (₺/km)', timezone('utc'::text, now())),
  ('npc_rental_price_Anadolu Aslanı', '14.0', 'NPC Kiralama Bedeli (₺/km)', timezone('utc'::text, now())),
  ('npc_rental_price_Kıtalararası Trans', '22.0', 'NPC Kiralama Bedeli (₺/km)', timezone('utc'::text, now()))
on conflict (key) do update
set
  value_text = excluded.value_text,
  updated_at = timezone('utc'::text, now());

-- 3. Sync existing vehicles in logistics_vehicles to match the updated type definitions
update public.logistics_vehicles lv
set
  capacity = lvt.capacity,
  speed_kmh = lvt.speed_kmh,
  fuel_capacity = lvt.fuel_capacity,
  current_fuel = least(lv.current_fuel, lvt.fuel_capacity),
  fuel_rate = lvt.fuel_rate,
  updated_at = timezone('utc'::text, now())
from public.logistics_vehicle_types lvt
where lv.logistics_vehicle_type_id = lvt.id;

-- 4. Update NPC rental vehicle prices specifically
update public.logistics_vehicles lv
set
  rental_price = case
    when lvt.name = 'Hızlı Kurye 250' then 4.0
    when lvt.name = 'VoltExpress E-Truck' then 8.0
    when lvt.name = 'Anadolu Aslanı' then 14.0
    when lvt.name = 'Kıtalararası Trans' then 22.0
    else lv.rental_price
  end,
  updated_at = timezone('utc'::text, now())
from public.logistics_vehicle_types lvt
where lv.logistics_vehicle_type_id = lvt.id
  and lv.player_id = public.get_npc_logistics_player_id();
