-- 2026-08-21: Add seller_google_avatar_url to market listings RPCs
-- Ensures that Google profile avatars of sellers are properly returned in market listings

DROP FUNCTION IF EXISTS public.get_market_listings_for_product(text);
DROP FUNCTION IF EXISTS public.get_market_listings_for_city(uuid);
DROP FUNCTION IF EXISTS public.get_market_listings_for_player(uuid);

-- 1. get_market_listings_for_product
CREATE OR REPLACE FUNCTION public.get_market_listings_for_product(p_product_id text)
RETURNS TABLE(
  slot_id uuid,
  product_id text,
  product_name text,
  product_icon text,
  brand_id uuid,
  unit_volume numeric,
  warehouse_id uuid,
  warehouse_name text,
  warehouse_icon text,
  city_id uuid,
  city_name text,
  city_x numeric,
  city_y numeric,
  seller_player_id uuid,
  seller_player_name text,
  seller_avatar_id text,
  seller_google_avatar_url text,
  quantity integer,
  quality_level integer,
  price numeric,
  cost numeric,
  is_available_for_sale boolean
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  select
    ws.id as slot_id,
    ws.product_id,
    coalesce(pr.urun_adi, 'Urun') as product_name,
    coalesce(pr.urun_iconu, 'default.webp') as product_icon,
    coalesce(ws.brand_id, '00000000-0000-0000-0000-000000000000'::uuid) as brand_id,
    coalesce(pr.birim_hacim, 0) as unit_volume,
    w.id as warehouse_id,
    w.name as warehouse_name,
    wt.icon as warehouse_icon,
    c.id as city_id,
    c.name as city_name,
    c.map_position_x as city_x,
    c.map_position_y as city_y,
    w.player_id as seller_player_id,
    coalesce(p.player_name, 'Oyuncu') as seller_player_name,
    coalesce(p.avatar_id, 'ae1.webp') as seller_avatar_id,
    p.google_avatar_url as seller_google_avatar_url,
    ws.quantity,
    ws.quality_level,
    ws.price,
    ws.cost,
    ws.is_available_for_sale
  from public.warehouse_slots ws
  join public.products pr on pr.id = ws.product_id
  join public.warehouses w on w.id = ws.warehouse_id
  join public.players p on p.id = w.player_id
  left join public.warehouse_types wt on wt.id = w.warehouse_type_id
  left join public.cities c on c.id = w.city_id
  where ws.product_id = p_product_id
    and ws.is_available_for_sale = true
    and ws.quantity > 0
    and coalesce(ws.price, 0) > 0
    and w.is_active = true
    and w.player_id <> auth.uid()
  order by ws.price asc, ws.quality_level desc, ws.quantity desc, ws.updated_at desc;
$function$;

-- 2. get_market_listings_for_city
CREATE OR REPLACE FUNCTION public.get_market_listings_for_city(p_city_id uuid)
RETURNS TABLE(
  slot_id uuid,
  product_id text,
  product_name text,
  product_icon text,
  brand_id uuid,
  unit_volume numeric,
  warehouse_id uuid,
  warehouse_name text,
  warehouse_icon text,
  city_id uuid,
  city_name text,
  city_x numeric,
  city_y numeric,
  seller_player_id uuid,
  seller_player_name text,
  seller_avatar_id text,
  seller_google_avatar_url text,
  quantity integer,
  quality_level integer,
  price numeric,
  cost numeric,
  is_available_for_sale boolean
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  select
    ws.id as slot_id,
    ws.product_id,
    coalesce(pr.urun_adi, 'Urun') as product_name,
    coalesce(pr.urun_iconu, 'default.webp') as product_icon,
    coalesce(ws.brand_id, '00000000-0000-0000-0000-000000000000'::uuid) as brand_id,
    coalesce(pr.birim_hacim, 0) as unit_volume,
    w.id as warehouse_id,
    w.name as warehouse_name,
    wt.icon as warehouse_icon,
    c.id as city_id,
    c.name as city_name,
    c.map_position_x as city_x,
    c.map_position_y as city_y,
    w.player_id as seller_player_id,
    coalesce(pl.player_name, 'Oyuncu') as seller_player_name,
    coalesce(pl.avatar_id, 'ae1.webp') as seller_avatar_id,
    pl.google_avatar_url as seller_google_avatar_url,
    ws.quantity,
    ws.quality_level,
    ws.price,
    ws.cost,
    ws.is_available_for_sale
  from public.warehouse_slots ws
  join public.products pr on pr.id = ws.product_id
  join public.warehouses w on w.id = ws.warehouse_id
  join public.players pl on pl.id = w.player_id
  join public.cities c on c.id = w.city_id
  left join public.warehouse_types wt on wt.id = w.warehouse_type_id
  where w.city_id = p_city_id
    and ws.is_available_for_sale = true
    and ws.quantity > 0
    and coalesce(ws.price, 0) > 0
    and w.is_active = true
    and w.player_id <> auth.uid()
  order by ws.price asc, pr.urun_adi asc, ws.quality_level desc, ws.quantity desc, ws.updated_at desc;
$function$;

-- 3. get_market_listings_for_player
CREATE OR REPLACE FUNCTION public.get_market_listings_for_player(p_player_id uuid)
RETURNS TABLE(
  slot_id uuid,
  product_id text,
  product_name text,
  product_icon text,
  brand_id uuid,
  unit_volume numeric,
  warehouse_id uuid,
  warehouse_name text,
  warehouse_icon text,
  city_id uuid,
  city_name text,
  city_x numeric,
  city_y numeric,
  seller_player_id uuid,
  seller_player_name text,
  seller_avatar_id text,
  seller_google_avatar_url text,
  quantity integer,
  quality_level integer,
  price numeric,
  cost numeric,
  is_available_for_sale boolean
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  select
    ws.id as slot_id,
    ws.product_id,
    coalesce(pr.urun_adi, 'Urun') as product_name,
    coalesce(pr.urun_iconu, 'default.webp') as product_icon,
    coalesce(ws.brand_id, '00000000-0000-0000-0000-000000000000'::uuid) as brand_id,
    coalesce(pr.birim_hacim, 0) as unit_volume,
    w.id as warehouse_id,
    w.name as warehouse_name,
    wt.icon as warehouse_icon,
    c.id as city_id,
    c.name as city_name,
    c.map_position_x as city_x,
    c.map_position_y as city_y,
    w.player_id as seller_player_id,
    coalesce(p.player_name, 'Oyuncu') as seller_player_name,
    coalesce(p.avatar_id, 'ae1.webp') as seller_avatar_id,
    p.google_avatar_url as seller_google_avatar_url,
    ws.quantity,
    ws.quality_level,
    ws.price,
    ws.cost,
    ws.is_available_for_sale
  from public.warehouse_slots ws
  join public.products pr on pr.id = ws.product_id
  join public.warehouses w on w.id = ws.warehouse_id
  join public.players p on p.id = w.player_id
  left join public.warehouse_types wt on wt.id = w.warehouse_type_id
  left join public.cities c on c.id = w.city_id
  where w.player_id = p_player_id
    and ws.is_available_for_sale = true
    and ws.quantity > 0
    and coalesce(ws.price, 0) > 0
    and w.is_active = true
  order by ws.price asc, ws.quality_level desc, ws.quantity desc, ws.updated_at desc;
$function$;
