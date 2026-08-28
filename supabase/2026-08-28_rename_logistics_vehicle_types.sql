-- Rename logistics vehicle types to clean, descriptive names

update public.logistics_vehicle_types
set name = 'Ekspres Kamyonet'
where name = 'Hızlı Kurye 250';

update public.logistics_vehicle_types
set name = 'Elektrikli Dağıtım Aracı'
where name = 'VoltExpress E-Truck';

update public.logistics_vehicle_types
set name = 'Ağır Yük Kamyonu'
where name = 'Anadolu Aslanı';

update public.logistics_vehicle_types
set name = 'Uzun Yol TIR''ı'
where name = 'Kıtalararası Trans';

-- Update game_settings for NPC rental prices
insert into public.game_settings (key, value_text, description, updated_at)
values
  ('npc_rental_price_Ekspres Kamyonet', '4.0', 'NPC Kiralama Bedeli (₺/km)', timezone('utc'::text, now())),
  ('npc_rental_price_Elektrikli Dağıtım Aracı', '8.0', 'NPC Kiralama Bedeli (₺/km)', timezone('utc'::text, now())),
  ('npc_rental_price_Ağır Yük Kamyonu', '14.0', 'NPC Kiralama Bedeli (₺/km)', timezone('utc'::text, now())),
  ('npc_rental_price_Uzun Yol TIR''ı', '22.0', 'NPC Kiralama Bedeli (₺/km)', timezone('utc'::text, now()))
on conflict (key) do update
set
  value_text = excluded.value_text,
  updated_at = timezone('utc'::text, now());

-- Clean up old settings keys
delete from public.game_settings
where key in (
  'npc_rental_price_Hızlı Kurye 250',
  'npc_rental_price_VoltExpress E-Truck',
  'npc_rental_price_Anadolu Aslanı',
  'npc_rental_price_Kıtalararası Trans'
);
