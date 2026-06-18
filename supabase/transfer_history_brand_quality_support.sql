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
      coalesce(
        lt.brand_id,
        '00000000-0000-0000-0000-000000000000'::uuid
      ) as brand_id,
      coalesce(lt.status, 'in_transit') as status,
      coalesce(nullif(lt.transfer_type, ''), 'market_transfer') as transfer_type,
      coalesce(lt.is_rental, false) as is_rental,
      coalesce(lt.total_price, 0)::double precision as total_price,
      coalesce(lt.rental_cost, 0)::double precision as rental_cost,
      coalesce(lt.transport_cost, 0)::double precision as transport_cost,
      lt.started_at,
      lt.finish_at,
      lt.completed_at,
      coalesce(
        nullif(lt.seller_entity_kind, ''),
        case
          when lt.seller_warehouse_id is not null then 'warehouse'
          when lt.seller_store_id is not null then 'store'
          when lt.seller_production_inventory_id is not null then 'production_inventory'
          else 'warehouse'
        end
      ) as seller_entity_kind,
      coalesce(
        nullif(lt.buyer_entity_kind, ''),
        case
          when lt.buyer_warehouse_id is not null then 'warehouse'
          when lt.buyer_store_id is not null then 'store'
          when lt.buyer_production_inventory_id is not null then 'production_inventory'
          else 'warehouse'
        end
      ) as buyer_entity_kind,
      jsonb_build_object(
        'id', coalesce(p.id, ''),
        'urun_adi', coalesce(p.urun_adi, 'Urun'),
        'urun_iconu', coalesce(p.urun_iconu, 'default.webp')
      ) as product,
      case
        when sw.id is null then null
        else jsonb_build_object(
          'id', sw.id,
          'name', coalesce(sw.name, 'Depo'),
          'kind', 'warehouse',
          'city', jsonb_build_object(
            'id', swc.id,
            'name', coalesce(swc.name, 'Sehir'),
            'map_position_x', coalesce(swc.map_position_x, 0),
            'map_position_y', coalesce(swc.map_position_y, 0)
          )
        )
      end as seller_warehouse,
      case
        when bw.id is null then null
        else jsonb_build_object(
          'id', bw.id,
          'name', coalesce(bw.name, 'Depo'),
          'kind', 'warehouse',
          'city', jsonb_build_object(
            'id', bwc.id,
            'name', coalesce(bwc.name, 'Sehir'),
            'map_position_x', coalesce(bwc.map_position_x, 0),
            'map_position_y', coalesce(bwc.map_position_y, 0)
          )
        )
      end as buyer_warehouse,
      case
        when ss.id is null then null
        else jsonb_build_object(
          'id', ss.id,
          'name', coalesce(ss.name, 'Magaza'),
          'kind', 'store',
          'city', jsonb_build_object(
            'id', ssc.id,
            'name', coalesce(ssc.name, 'Sehir'),
            'map_position_x', coalesce(ssc.map_position_x, 0),
            'map_position_y', coalesce(ssc.map_position_y, 0)
          )
        )
      end as seller_store,
      case
        when bs.id is null then null
        else jsonb_build_object(
          'id', bs.id,
          'name', coalesce(bs.name, 'Magaza'),
          'kind', 'store',
          'city', jsonb_build_object(
            'id', bsc.id,
            'name', coalesce(bsc.name, 'Sehir'),
            'map_position_x', coalesce(bsc.map_position_x, 0),
            'map_position_y', coalesce(bsc.map_position_y, 0)
          )
        )
      end as buyer_store,
      case
        when spi.id is null then null
        else jsonb_build_object(
          'id', spi.id,
          'name', coalesce(sf.name, sfa.name, sfi.name, sm.name, 'Uretim'),
          'kind', 'production_inventory',
          'city', jsonb_build_object(
            'id', coalesce(sfc.id, sfac.id, sfic.id, smc.id),
            'name', coalesce(sfc.name, sfac.name, sfic.name, smc.name, 'Sehir'),
            'map_position_x', coalesce(sfc.map_position_x, sfac.map_position_x, sfic.map_position_x, smc.map_position_x, 0),
            'map_position_y', coalesce(sfc.map_position_y, sfac.map_position_y, sfic.map_position_y, smc.map_position_y, 0)
          )
        )
      end as seller_production_inventory,
      case
        when bpi.id is null then null
        else jsonb_build_object(
          'id', bpi.id,
          'name', coalesce(bf.name, bfa.name, bfi.name, bm.name, 'Uretim'),
          'kind', 'production_inventory',
          'city', jsonb_build_object(
            'id', coalesce(bfc.id, bfac.id, bfic.id, bmc.id),
            'name', coalesce(bfc.name, bfac.name, bfic.name, bmc.name, 'Sehir'),
            'map_position_x', coalesce(bfc.map_position_x, bfac.map_position_x, bfic.map_position_x, bmc.map_position_x, 0),
            'map_position_y', coalesce(bfc.map_position_y, bfac.map_position_y, bfic.map_position_y, bmc.map_position_y, 0)
          )
        )
      end as buyer_production_inventory
    from public.logistics_transfers lt
    left join public.products p on p.id = lt.product_id
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
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', id,
        'quantity', quantity,
        'item_count', item_count,
        'total_quantity', total_quantity,
        'quality_level', quality_level,
        'brand_id', brand_id,
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
      )
      order by finish_at asc, started_at asc, id asc
    ),
    '[]'::jsonb
  )
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
      coalesce(
        lt.brand_id,
        '00000000-0000-0000-0000-000000000000'::uuid
      ) as brand_id,
      coalesce(lt.status, 'completed') as status,
      coalesce(nullif(lt.transfer_type, ''), 'market_transfer') as transfer_type,
      coalesce(lt.is_rental, false) as is_rental,
      coalesce(lt.total_price, 0)::double precision as total_price,
      coalesce(lt.rental_cost, 0)::double precision as rental_cost,
      coalesce(lt.transport_cost, 0)::double precision as transport_cost,
      lt.started_at,
      lt.finish_at,
      lt.completed_at,
      coalesce(
        nullif(lt.seller_entity_kind, ''),
        case
          when lt.seller_warehouse_id is not null then 'warehouse'
          when lt.seller_store_id is not null then 'store'
          when lt.seller_production_inventory_id is not null then 'production_inventory'
          else 'warehouse'
        end
      ) as seller_entity_kind,
      coalesce(
        nullif(lt.buyer_entity_kind, ''),
        case
          when lt.buyer_warehouse_id is not null then 'warehouse'
          when lt.buyer_store_id is not null then 'store'
          when lt.buyer_production_inventory_id is not null then 'production_inventory'
          else 'warehouse'
        end
      ) as buyer_entity_kind,
      jsonb_build_object(
        'id', coalesce(p.id, ''),
        'urun_adi', coalesce(p.urun_adi, 'Urun'),
        'urun_iconu', coalesce(p.urun_iconu, 'default.webp')
      ) as product,
      case
        when sw.id is null then null
        else jsonb_build_object(
          'id', sw.id,
          'name', coalesce(sw.name, 'Depo'),
          'kind', 'warehouse',
          'city', jsonb_build_object(
            'id', swc.id,
            'name', coalesce(swc.name, 'Sehir'),
            'map_position_x', coalesce(swc.map_position_x, 0),
            'map_position_y', coalesce(swc.map_position_y, 0)
          )
        )
      end as seller_warehouse,
      case
        when bw.id is null then null
        else jsonb_build_object(
          'id', bw.id,
          'name', coalesce(bw.name, 'Depo'),
          'kind', 'warehouse',
          'city', jsonb_build_object(
            'id', bwc.id,
            'name', coalesce(bwc.name, 'Sehir'),
            'map_position_x', coalesce(bwc.map_position_x, 0),
            'map_position_y', coalesce(bwc.map_position_y, 0)
          )
        )
      end as buyer_warehouse,
      case
        when ss.id is null then null
        else jsonb_build_object(
          'id', ss.id,
          'name', coalesce(ss.name, 'Magaza'),
          'kind', 'store',
          'city', jsonb_build_object(
            'id', ssc.id,
            'name', coalesce(ssc.name, 'Sehir'),
            'map_position_x', coalesce(ssc.map_position_x, 0),
            'map_position_y', coalesce(ssc.map_position_y, 0)
          )
        )
      end as seller_store,
      case
        when bs.id is null then null
        else jsonb_build_object(
          'id', bs.id,
          'name', coalesce(bs.name, 'Magaza'),
          'kind', 'store',
          'city', jsonb_build_object(
            'id', bsc.id,
            'name', coalesce(bsc.name, 'Sehir'),
            'map_position_x', coalesce(bsc.map_position_x, 0),
            'map_position_y', coalesce(bsc.map_position_y, 0)
          )
        )
      end as buyer_store,
      case
        when spi.id is null then null
        else jsonb_build_object(
          'id', spi.id,
          'name', coalesce(sf.name, sfa.name, sfi.name, sm.name, 'Uretim'),
          'kind', 'production_inventory',
          'city', jsonb_build_object(
            'id', coalesce(sfc.id, sfac.id, sfic.id, smc.id),
            'name', coalesce(sfc.name, sfac.name, sfic.name, smc.name, 'Sehir'),
            'map_position_x', coalesce(sfc.map_position_x, sfac.map_position_x, sfic.map_position_x, smc.map_position_x, 0),
            'map_position_y', coalesce(sfc.map_position_y, sfac.map_position_y, sfic.map_position_y, smc.map_position_y, 0)
          )
        )
      end as seller_production_inventory,
      case
        when bpi.id is null then null
        else jsonb_build_object(
          'id', bpi.id,
          'name', coalesce(bf.name, bfa.name, bfi.name, bm.name, 'Uretim'),
          'kind', 'production_inventory',
          'city', jsonb_build_object(
            'id', coalesce(bfc.id, bfac.id, bfic.id, bmc.id),
            'name', coalesce(bfc.name, bfac.name, bfic.name, bmc.name, 'Sehir'),
            'map_position_x', coalesce(bfc.map_position_x, bfac.map_position_x, bfic.map_position_x, bmc.map_position_x, 0),
            'map_position_y', coalesce(bfc.map_position_y, bfac.map_position_y, bfic.map_position_y, bmc.map_position_y, 0)
          )
        )
      end as buyer_production_inventory
    from public.logistics_transfers lt
    left join public.products p on p.id = lt.product_id
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
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', id,
        'quantity', quantity,
        'item_count', item_count,
        'total_quantity', total_quantity,
        'quality_level', quality_level,
        'brand_id', brand_id,
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
      )
      order by completed_at desc nulls last, finish_at desc, started_at desc, id desc
    ),
    '[]'::jsonb
  )
  from base;
$$;

grant execute on function public.get_buyer_transfer_map_items() to authenticated;
grant execute on function public.get_buyer_transfer_history_items() to authenticated;
