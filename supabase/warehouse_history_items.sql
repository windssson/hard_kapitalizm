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
    coalesce(
      tr.brand_id,
      '00000000-0000-0000-0000-000000000000'::uuid
    ) as brand_id,
    coalesce(tr.quantity, 0)::integer as quantity,
    coalesce(tr.total_price, 0) as total_price,
    coalesce(tr.transport_cost, 0) as transport_cost,
    coalesce(tr.rental_cost, 0) as rental_cost,
    (
      coalesce(tr.is_rental, false)
      or coalesce(tr.rental_cost, 0) > 0
    ) as is_rental,
    case
      when tr.seller_entity_kind = 'npc_market' then 'Pazar'
      when tr.seller_entity_kind in ('store', 'store_slot') then coalesce(ss.name, 'Magaza')
      when tr.seller_entity_kind in ('production', 'production_inventory') then
        coalesce(sf.name, sfd.name, sfa.name, sm.name, 'Uretim')
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
      when tr.seller_entity_kind in ('production', 'production_inventory') then
        coalesce(sfc.name, sfdc.name, sfac.name, smc.name, '-')
      else coalesce(swc.name, '-')
    end::text as source_city_name,
    case
      when tr.buyer_entity_kind = 'npc_market' then 'Pazar'
      when tr.buyer_entity_kind in ('store', 'store_slot') then coalesce(bs.name, 'Magaza')
      when tr.buyer_entity_kind in ('production', 'production_inventory') then
        coalesce(bf.name, bfd.name, bfa.name, bm.name, 'Uretim')
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
      when tr.buyer_entity_kind in ('production', 'production_inventory') then
        coalesce(bfc.name, bfdc.name, bfac.name, bmc.name, '-')
      else coalesce(bwc.name, '-')
    end::text as target_city_name
  from transfer_rows tr
  left join public.products p on p.id = tr.product_id
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

grant execute on function public.get_warehouse_history_items(uuid) to authenticated;
