create or replace function public.get_market_listings_for_product(
  p_product_id text
) returns table(
  slot_id uuid,
  product_id text,
  product_name text,
  product_icon text,
  brand_id uuid,
  brand_name text,
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
  quantity integer,
  quality_level integer,
  price numeric,
  cost numeric,
  is_available_for_sale boolean
)
language sql
security definer
set search_path = public
as $$
  select
    ws.id as slot_id,
    ws.product_id,
    coalesce(pr.urun_adi, 'Urun') as product_name,
    coalesce(pr.urun_iconu, 'default.webp') as product_icon,
    coalesce(ws.brand_id, '00000000-0000-0000-0000-000000000000'::uuid) as brand_id,
    bc.brand_name,
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
    ws.quantity,
    ws.quality_level,
    ws.price,
    ws.cost,
    ws.is_available_for_sale
  from public.warehouse_slots ws
  join public.products pr on pr.id = ws.product_id
  join public.warehouses w on w.id = ws.warehouse_id
  join public.players p on p.id = w.player_id
  left join public.brand_companies bc on bc.id = ws.brand_id and bc.is_active = true
  left join public.warehouse_types wt on wt.id = w.warehouse_type_id
  left join public.cities c on c.id = w.city_id
  where ws.product_id = p_product_id
    and ws.is_available_for_sale = true
    and ws.quantity > 0
    and coalesce(ws.price, 0) > 0
    and w.is_active = true
    and w.player_id <> auth.uid()
  order by ws.price asc, ws.quality_level desc, ws.quantity desc, ws.updated_at desc;
$$;

create or replace function public.get_market_listings_for_city(
  p_city_id uuid
) returns table(
  slot_id uuid,
  product_id text,
  product_name text,
  product_icon text,
  brand_id uuid,
  brand_name text,
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
  quantity integer,
  quality_level integer,
  price numeric,
  cost numeric,
  is_available_for_sale boolean
)
language sql
security definer
set search_path = public
as $$
  select
    ws.id as slot_id,
    ws.product_id,
    coalesce(pr.urun_adi, 'Urun') as product_name,
    coalesce(pr.urun_iconu, 'default.webp') as product_icon,
    coalesce(ws.brand_id, '00000000-0000-0000-0000-000000000000'::uuid) as brand_id,
    bc.brand_name,
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
  left join public.brand_companies bc on bc.id = ws.brand_id and bc.is_active = true
  left join public.warehouse_types wt on wt.id = w.warehouse_type_id
  where w.city_id = p_city_id
    and ws.is_available_for_sale = true
    and ws.quantity > 0
    and coalesce(ws.price, 0) > 0
    and w.is_active = true
    and w.player_id <> auth.uid()
  order by ws.price asc, pr.urun_adi asc, ws.quality_level desc, ws.quantity desc, ws.updated_at desc;
$$;

create or replace function public.get_warehouse_history_items(
  p_warehouse_id uuid
)
returns table (
  id uuid,
  direction text,
  transfer_type text,
  status text,
  happened_at timestamptz,
  started_at timestamptz,
  finish_at timestamptz,
  completed_at timestamptz,
  product_id text,
  product_name text,
  product_icon text,
  quality_level integer,
  brand_id uuid,
  brand_name text,
  quantity integer,
  total_price numeric,
  transport_cost numeric,
  rental_cost numeric,
  is_rental boolean,
  source_name text,
  source_kind text,
  source_city_name text,
  target_name text,
  target_kind text,
  target_city_name text
)
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_player_id uuid := auth.uid();
begin
  if v_player_id is null then
    raise exception 'Oturum bulunamadi.';
  end if;

  if not exists (
    select 1
    from public.warehouses w
    where w.id = p_warehouse_id
      and w.player_id = v_player_id
  ) then
    raise exception 'Depo bulunamadi veya size ait degil.';
  end if;

  return query
  with transfer_rows as (
    select
      lt.*,
      case
        when lt.buyer_warehouse_id = p_warehouse_id then 'incoming'
        else 'outgoing'
      end as movement_direction,
      coalesce(lt.completed_at, lt.finish_at, lt.started_at) as movement_at
    from public.logistics_transfers lt
    where lt.seller_warehouse_id = p_warehouse_id
       or lt.buyer_warehouse_id = p_warehouse_id
  )
  select
    tr.id,
    tr.movement_direction::text as direction,
    coalesce(tr.transfer_type, 'warehouse_transfer')::text as transfer_type,
    coalesce(tr.status, 'completed')::text as status,
    tr.movement_at as happened_at,
    tr.started_at,
    tr.finish_at,
    tr.completed_at,
    tr.product_id,
    coalesce(p.urun_adi, 'Urun')::text as product_name,
    coalesce(p.urun_iconu, 'default.webp')::text as product_icon,
    greatest(coalesce(tr.quality_level, 1), 1)::integer as quality_level,
    coalesce(tr.brand_id, '00000000-0000-0000-0000-000000000000'::uuid) as brand_id,
    bc.brand_name,
    coalesce(tr.quantity, 0)::integer as quantity,
    coalesce(tr.total_price, 0) as total_price,
    coalesce(tr.transport_cost, 0) as transport_cost,
    coalesce(tr.rental_cost, 0) as rental_cost,
    (coalesce(tr.is_rental, false) or coalesce(tr.rental_cost, 0) > 0) as is_rental,
    case
      when tr.seller_entity_kind = 'npc_market' then 'Pazar'
      when tr.seller_entity_kind in ('store', 'store_slot') then coalesce(ss.name, 'Magaza')
      when tr.seller_entity_kind in ('production', 'production_inventory') then coalesce(sf.name, sfd.name, sfa.name, sm.name, 'Uretim')
      else coalesce(sw.name, 'Depo')
    end::text as source_name,
    case
      when tr.seller_entity_kind = 'npc_market' then 'market'
      when tr.seller_entity_kind in ('store', 'store_slot') then 'store'
      when tr.seller_entity_kind in ('production', 'production_inventory') then 'production'
      else 'warehouse'
    end::text as source_kind,
    case
      when tr.seller_entity_kind = 'npc_market' then coalesce(bwc.name, swc.name, ssc.name, sfc.name, sfdc.name, sfac.name, smc.name, '-')
      when tr.seller_entity_kind in ('store', 'store_slot') then coalesce(ssc.name, '-')
      when tr.seller_entity_kind in ('production', 'production_inventory') then coalesce(sfc.name, sfdc.name, sfac.name, smc.name, '-')
      else coalesce(swc.name, '-')
    end::text as source_city_name,
    case
      when tr.buyer_entity_kind = 'npc_market' then 'Pazar'
      when tr.buyer_entity_kind in ('store', 'store_slot') then coalesce(bs.name, 'Magaza')
      when tr.buyer_entity_kind in ('production', 'production_inventory') then coalesce(bf.name, bfd.name, bfa.name, bm.name, 'Uretim')
      else coalesce(bw.name, 'Depo')
    end::text as target_name,
    case
      when tr.buyer_entity_kind = 'npc_market' then 'market'
      when tr.buyer_entity_kind in ('store', 'store_slot') then 'store'
      when tr.buyer_entity_kind in ('production', 'production_inventory') then 'production'
      else 'warehouse'
    end::text as target_kind,
    case
      when tr.buyer_entity_kind = 'npc_market' then coalesce(swc.name, bwc.name, bsc.name, bfc.name, bfdc.name, bfac.name, bmc.name, '-')
      when tr.buyer_entity_kind in ('store', 'store_slot') then coalesce(bsc.name, '-')
      when tr.buyer_entity_kind in ('production', 'production_inventory') then coalesce(bfc.name, bfdc.name, bfac.name, bmc.name, '-')
      else coalesce(bwc.name, '-')
    end::text as target_city_name
  from transfer_rows tr
  left join public.products p on p.id = tr.product_id
  left join public.brand_companies bc on bc.id = tr.brand_id and bc.is_active = true
  left join public.warehouses sw on sw.id = tr.seller_warehouse_id
  left join public.cities swc on swc.id = sw.city_id
  left join public.warehouses bw on bw.id = tr.buyer_warehouse_id
  left join public.cities bwc on bwc.id = bw.city_id
  left join public.stores ss on ss.id = tr.seller_store_id
  left join public.cities ssc on ssc.id = ss.city_id
  left join public.stores bs on bs.id = tr.buyer_store_id
  left join public.cities bsc on bsc.id = bs.city_id
  left join public.production_inventory spi on spi.id = tr.seller_production_inventory_id
  left join public.factories sf on sf.id = spi.owner_id and spi.owner_kind = 'factory'
  left join public.cities sfc on sfc.id = sf.city_id
  left join public.fields sfd on sfd.id = spi.owner_id and spi.owner_kind = 'field'
  left join public.cities sfdc on sfdc.id = sfd.city_id
  left join public.farms sfa on sfa.id = spi.owner_id and spi.owner_kind = 'farm'
  left join public.cities sfac on sfac.id = sfa.city_id
  left join public.mines sm on sm.id = spi.owner_id and spi.owner_kind = 'mine'
  left join public.cities smc on smc.id = sm.city_id
  left join public.production_inventory bpi on bpi.id = tr.buyer_production_inventory_id
  left join public.factories bf on bf.id = bpi.owner_id and bpi.owner_kind = 'factory'
  left join public.cities bfc on bfc.id = bf.city_id
  left join public.fields bfd on bfd.id = bpi.owner_id and bpi.owner_kind = 'field'
  left join public.cities bfdc on bfdc.id = bfd.city_id
  left join public.farms bfa on bfa.id = bpi.owner_id and bpi.owner_kind = 'farm'
  left join public.cities bfac on bfac.id = bfa.city_id
  left join public.mines bm on bm.id = bpi.owner_id and bpi.owner_kind = 'mine'
  left join public.cities bmc on bmc.id = bm.city_id
  order by tr.movement_at desc, tr.started_at desc;
end;
$$;

create or replace function public.get_buyer_transfer_map_items()
returns jsonb
language sql
security definer
set search_path = public
as $$
  with base as (
    select
      lt.id,
      coalesce(lt.quantity, 0) as quantity,
      greatest(coalesce(lt.item_count, 1), 1) as item_count,
      coalesce(nullif(lt.total_quantity, 0), lt.quantity, 0) as total_quantity,
      greatest(coalesce(lt.quality_level, 1), 1) as quality_level,
      coalesce(lt.brand_id, '00000000-0000-0000-0000-000000000000'::uuid) as brand_id,
      bc.brand_name,
      coalesce(lt.status, 'in_transit') as status,
      coalesce(nullif(lt.transfer_type, ''), 'market_transfer') as transfer_type,
      coalesce(lt.is_rental, false) as is_rental,
      coalesce(lt.total_price, 0)::double precision as total_price,
      coalesce(lt.rental_cost, 0)::double precision as rental_cost,
      coalesce(lt.transport_cost, 0)::double precision as transport_cost,
      lt.started_at,
      lt.finish_at,
      lt.completed_at,
      coalesce(nullif(lt.seller_entity_kind, ''), case
        when lt.seller_warehouse_id is not null then 'warehouse'
        when lt.seller_store_id is not null then 'store'
        when lt.seller_production_inventory_id is not null then 'production_inventory'
        else 'warehouse'
      end) as seller_entity_kind,
      coalesce(nullif(lt.buyer_entity_kind, ''), case
        when lt.buyer_warehouse_id is not null then 'warehouse'
        when lt.buyer_store_id is not null then 'store'
        when lt.buyer_production_inventory_id is not null then 'production_inventory'
        else 'warehouse'
      end) as buyer_entity_kind,
      jsonb_build_object(
        'id', coalesce(p.id, ''),
        'urun_adi', coalesce(p.urun_adi, 'Urun'),
        'urun_iconu', coalesce(p.urun_iconu, 'default.webp')
      ) as product,
      case when sw.id is null then null else jsonb_build_object(
        'id', sw.id,'name', coalesce(sw.name, 'Depo'),'kind', 'warehouse',
        'city', jsonb_build_object('id', swc.id,'name', coalesce(swc.name, 'Sehir'),'map_position_x', coalesce(swc.map_position_x, 0),'map_position_y', coalesce(swc.map_position_y, 0))
      ) end as seller_warehouse,
      case when bw.id is null then null else jsonb_build_object(
        'id', bw.id,'name', coalesce(bw.name, 'Depo'),'kind', 'warehouse',
        'city', jsonb_build_object('id', bwc.id,'name', coalesce(bwc.name, 'Sehir'),'map_position_x', coalesce(bwc.map_position_x, 0),'map_position_y', coalesce(bwc.map_position_y, 0))
      ) end as buyer_warehouse,
      case when ss.id is null then null else jsonb_build_object(
        'id', ss.id,'name', coalesce(ss.name, 'Magaza'),'kind', 'store',
        'city', jsonb_build_object('id', ssc.id,'name', coalesce(ssc.name, 'Sehir'),'map_position_x', coalesce(ssc.map_position_x, 0),'map_position_y', coalesce(ssc.map_position_y, 0))
      ) end as seller_store,
      case when bs.id is null then null else jsonb_build_object(
        'id', bs.id,'name', coalesce(bs.name, 'Magaza'),'kind', 'store',
        'city', jsonb_build_object('id', bsc.id,'name', coalesce(bsc.name, 'Sehir'),'map_position_x', coalesce(bsc.map_position_x, 0),'map_position_y', coalesce(bsc.map_position_y, 0))
      ) end as buyer_store,
      case when spi.id is null then null else jsonb_build_object(
        'id', spi.id,'name', coalesce(sf.name, sfa.name, sfi.name, sm.name, 'Uretim'),'kind', 'production_inventory',
        'city', jsonb_build_object('id', coalesce(sfc.id, sfac.id, sfic.id, smc.id),'name', coalesce(sfc.name, sfac.name, sfic.name, smc.name, 'Sehir'),'map_position_x', coalesce(sfc.map_position_x, sfac.map_position_x, sfic.map_position_x, smc.map_position_x, 0),'map_position_y', coalesce(sfc.map_position_y, sfac.map_position_y, sfic.map_position_y, smc.map_position_y, 0))
      ) end as seller_production_inventory,
      case when bpi.id is null then null else jsonb_build_object(
        'id', bpi.id,'name', coalesce(bf.name, bfa.name, bfi.name, bm.name, 'Uretim'),'kind', 'production_inventory',
        'city', jsonb_build_object('id', coalesce(bfc.id, bfac.id, bfic.id, bmc.id),'name', coalesce(bfc.name, bfac.name, bfic.name, bmc.name, 'Sehir'),'map_position_x', coalesce(bfc.map_position_x, bfac.map_position_x, bfic.map_position_x, bmc.map_position_x, 0),'map_position_y', coalesce(bfc.map_position_y, bfac.map_position_y, bfic.map_position_y, bmc.map_position_y, 0))
      ) end as buyer_production_inventory
    from public.logistics_transfers lt
    left join public.products p on p.id = lt.product_id
    left join public.brand_companies bc on bc.id = lt.brand_id and bc.is_active = true
    left join public.warehouses sw on sw.id = lt.seller_warehouse_id
    left join public.cities swc on swc.id = sw.city_id
    left join public.warehouses bw on bw.id = lt.buyer_warehouse_id
    left join public.cities bwc on bwc.id = bw.city_id
    left join public.stores ss on ss.id = lt.seller_store_id
    left join public.cities ssc on ssc.id = ss.city_id
    left join public.stores bs on bs.id = lt.buyer_store_id
    left join public.cities bsc on bsc.id = bs.city_id
    left join public.production_inventory spi on spi.id = lt.seller_production_inventory_id
    left join public.factories sf on spi.owner_kind = 'factory' and sf.id = spi.owner_id
    left join public.cities sfc on sfc.id = sf.city_id
    left join public.farms sfa on spi.owner_kind = 'farm' and sfa.id = spi.owner_id
    left join public.cities sfac on sfac.id = sfa.city_id
    left join public.fields sfi on spi.owner_kind = 'field' and sfi.id = spi.owner_id
    left join public.cities sfic on sfic.id = sfi.city_id
    left join public.mines sm on spi.owner_kind = 'mine' and sm.id = spi.owner_id
    left join public.cities smc on smc.id = sm.city_id
    left join public.production_inventory bpi on bpi.id = lt.buyer_production_inventory_id
    left join public.factories bf on bpi.owner_kind = 'factory' and bf.id = bpi.owner_id
    left join public.cities bfc on bfc.id = bf.city_id
    left join public.farms bfa on bpi.owner_kind = 'farm' and bfa.id = bpi.owner_id
    left join public.cities bfac on bfac.id = bfa.city_id
    left join public.fields bfi on bpi.owner_kind = 'field' and bfi.id = bpi.owner_id
    left join public.cities bfic on bfic.id = bfi.city_id
    left join public.mines bm on bpi.owner_kind = 'mine' and bm.id = bpi.owner_id
    left join public.cities bmc on bmc.id = bm.city_id
    where lt.buyer_player_id = auth.uid()
      and lt.status = 'in_transit'
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', id,
    'quantity', quantity,
    'item_count', item_count,
    'total_quantity', total_quantity,
    'quality_level', quality_level,
    'brand_id', brand_id,
    'brand_name', brand_name,
    'status', status,
    'transfer_type', transfer_type,
    'is_rental', is_rental,
    'total_price', total_price,
    'rental_cost', rental_cost,
    'transport_cost', transport_cost,
    'started_at', started_at,
    'finish_at', finish_at,
    'completed_at', completed_at,
    'seller_entity_kind', seller_entity_kind,
    'buyer_entity_kind', buyer_entity_kind,
    'product', product,
    'seller_warehouse', seller_warehouse,
    'buyer_warehouse', buyer_warehouse,
    'seller_store', seller_store,
    'buyer_store', buyer_store,
    'seller_production_inventory', seller_production_inventory,
    'buyer_production_inventory', buyer_production_inventory
  ) order by finish_at asc, started_at asc, id asc), '[]'::jsonb)
  from base;
$$;

create or replace function public.get_buyer_transfer_history_items()
returns jsonb
language sql
security definer
set search_path = public
as $$
  with base as (
    select
      lt.id,
      coalesce(lt.quantity, 0) as quantity,
      greatest(coalesce(lt.item_count, 1), 1) as item_count,
      coalesce(nullif(lt.total_quantity, 0), lt.quantity, 0) as total_quantity,
      greatest(coalesce(lt.quality_level, 1), 1) as quality_level,
      coalesce(lt.brand_id, '00000000-0000-0000-0000-000000000000'::uuid) as brand_id,
      bc.brand_name,
      coalesce(lt.status, 'completed') as status,
      coalesce(nullif(lt.transfer_type, ''), 'market_transfer') as transfer_type,
      coalesce(lt.is_rental, false) as is_rental,
      coalesce(lt.total_price, 0)::double precision as total_price,
      coalesce(lt.rental_cost, 0)::double precision as rental_cost,
      coalesce(lt.transport_cost, 0)::double precision as transport_cost,
      lt.started_at,
      lt.finish_at,
      lt.completed_at,
      coalesce(nullif(lt.seller_entity_kind, ''), case
        when lt.seller_warehouse_id is not null then 'warehouse'
        when lt.seller_store_id is not null then 'store'
        when lt.seller_production_inventory_id is not null then 'production_inventory'
        else 'warehouse'
      end) as seller_entity_kind,
      coalesce(nullif(lt.buyer_entity_kind, ''), case
        when lt.buyer_warehouse_id is not null then 'warehouse'
        when lt.buyer_store_id is not null then 'store'
        when lt.buyer_production_inventory_id is not null then 'production_inventory'
        else 'warehouse'
      end) as buyer_entity_kind,
      jsonb_build_object(
        'id', coalesce(p.id, ''),
        'urun_adi', coalesce(p.urun_adi, 'Urun'),
        'urun_iconu', coalesce(p.urun_iconu, 'default.webp')
      ) as product,
      case when sw.id is null then null else jsonb_build_object(
        'id', sw.id,'name', coalesce(sw.name, 'Depo'),'kind', 'warehouse',
        'city', jsonb_build_object('id', swc.id,'name', coalesce(swc.name, 'Sehir'),'map_position_x', coalesce(swc.map_position_x, 0),'map_position_y', coalesce(swc.map_position_y, 0))
      ) end as seller_warehouse,
      case when bw.id is null then null else jsonb_build_object(
        'id', bw.id,'name', coalesce(bw.name, 'Depo'),'kind', 'warehouse',
        'city', jsonb_build_object('id', bwc.id,'name', coalesce(bwc.name, 'Sehir'),'map_position_x', coalesce(bwc.map_position_x, 0),'map_position_y', coalesce(bwc.map_position_y, 0))
      ) end as buyer_warehouse,
      case when ss.id is null then null else jsonb_build_object(
        'id', ss.id,'name', coalesce(ss.name, 'Magaza'),'kind', 'store',
        'city', jsonb_build_object('id', ssc.id,'name', coalesce(ssc.name, 'Sehir'),'map_position_x', coalesce(ssc.map_position_x, 0),'map_position_y', coalesce(ssc.map_position_y, 0))
      ) end as seller_store,
      case when bs.id is null then null else jsonb_build_object(
        'id', bs.id,'name', coalesce(bs.name, 'Magaza'),'kind', 'store',
        'city', jsonb_build_object('id', bsc.id,'name', coalesce(bsc.name, 'Sehir'),'map_position_x', coalesce(bsc.map_position_x, 0),'map_position_y', coalesce(bsc.map_position_y, 0))
      ) end as buyer_store,
      case when spi.id is null then null else jsonb_build_object(
        'id', spi.id,'name', coalesce(sf.name, sfa.name, sfi.name, sm.name, 'Uretim'),'kind', 'production_inventory',
        'city', jsonb_build_object('id', coalesce(sfc.id, sfac.id, sfic.id, smc.id),'name', coalesce(sfc.name, sfac.name, sfic.name, smc.name, 'Sehir'),'map_position_x', coalesce(sfc.map_position_x, sfac.map_position_x, sfic.map_position_x, smc.map_position_x, 0),'map_position_y', coalesce(sfc.map_position_y, sfac.map_position_y, sfic.map_position_y, smc.map_position_y, 0))
      ) end as seller_production_inventory,
      case when bpi.id is null then null else jsonb_build_object(
        'id', bpi.id,'name', coalesce(bf.name, bfa.name, bfi.name, bm.name, 'Uretim'),'kind', 'production_inventory',
        'city', jsonb_build_object('id', coalesce(bfc.id, bfac.id, bfic.id, bmc.id),'name', coalesce(bfc.name, bfac.name, bfic.name, bmc.name, 'Sehir'),'map_position_x', coalesce(bfc.map_position_x, bfac.map_position_x, bfic.map_position_x, bmc.map_position_x, 0),'map_position_y', coalesce(bfc.map_position_y, bfac.map_position_y, bfic.map_position_y, bmc.map_position_y, 0))
      ) end as buyer_production_inventory
    from public.logistics_transfers lt
    left join public.products p on p.id = lt.product_id
    left join public.brand_companies bc on bc.id = lt.brand_id and bc.is_active = true
    left join public.warehouses sw on sw.id = lt.seller_warehouse_id
    left join public.cities swc on swc.id = sw.city_id
    left join public.warehouses bw on bw.id = lt.buyer_warehouse_id
    left join public.cities bwc on bwc.id = bw.city_id
    left join public.stores ss on ss.id = lt.seller_store_id
    left join public.cities ssc on ssc.id = ss.city_id
    left join public.stores bs on bs.id = lt.buyer_store_id
    left join public.cities bsc on bsc.id = bs.city_id
    left join public.production_inventory spi on spi.id = lt.seller_production_inventory_id
    left join public.factories sf on spi.owner_kind = 'factory' and sf.id = spi.owner_id
    left join public.cities sfc on sfc.id = sf.city_id
    left join public.farms sfa on spi.owner_kind = 'farm' and sfa.id = spi.owner_id
    left join public.cities sfac on sfac.id = sfa.city_id
    left join public.fields sfi on spi.owner_kind = 'field' and sfi.id = spi.owner_id
    left join public.cities sfic on sfic.id = sfi.city_id
    left join public.mines sm on spi.owner_kind = 'mine' and sm.id = spi.owner_id
    left join public.cities smc on smc.id = sm.city_id
    left join public.production_inventory bpi on bpi.id = lt.buyer_production_inventory_id
    left join public.factories bf on bpi.owner_kind = 'factory' and bf.id = bpi.owner_id
    left join public.cities bfc on bfc.id = bf.city_id
    left join public.farms bfa on bpi.owner_kind = 'farm' and bfa.id = bpi.owner_id
    left join public.cities bfac on bfac.id = bfa.city_id
    left join public.fields bfi on bpi.owner_kind = 'field' and bfi.id = bpi.owner_id
    left join public.cities bfic on bfic.id = bfi.city_id
    left join public.mines bm on bpi.owner_kind = 'mine' and bm.id = bpi.owner_id
    left join public.cities bmc on bmc.id = bm.city_id
    where lt.buyer_player_id = auth.uid()
      and lt.status = 'completed'
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', id,
    'quantity', quantity,
    'item_count', item_count,
    'total_quantity', total_quantity,
    'quality_level', quality_level,
    'brand_id', brand_id,
    'brand_name', brand_name,
    'status', status,
    'transfer_type', transfer_type,
    'is_rental', is_rental,
    'total_price', total_price,
    'rental_cost', rental_cost,
    'transport_cost', transport_cost,
    'started_at', started_at,
    'finish_at', finish_at,
    'completed_at', completed_at,
    'seller_entity_kind', seller_entity_kind,
    'buyer_entity_kind', buyer_entity_kind,
    'product', product,
    'seller_warehouse', seller_warehouse,
    'buyer_warehouse', buyer_warehouse,
    'seller_store', seller_store,
    'buyer_store', buyer_store,
    'seller_production_inventory', seller_production_inventory,
    'buyer_production_inventory', buyer_production_inventory
  ) order by completed_at desc nulls last, finish_at desc, started_at desc, id desc), '[]'::jsonb)
  from base;
$$;

grant execute on function public.get_market_listings_for_product(text) to anon, authenticated, service_role;
grant execute on function public.get_market_listings_for_city(uuid) to anon, authenticated, service_role;
grant execute on function public.get_warehouse_history_items(uuid) to authenticated;
grant execute on function public.get_buyer_transfer_map_items() to authenticated;
grant execute on function public.get_buyer_transfer_history_items() to authenticated;
