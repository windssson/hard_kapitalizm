-- Migration: Fix get_store_history_items to include transfers to/from store warehouses
-- Date: 2026-07-11

CREATE OR REPLACE FUNCTION public.get_store_history_items(p_store_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  with transfer_items as (
    select jsonb_build_object(
      'id', 'transfer_' || lt.id::text,
      'type',
        case when (lt.buyer_store_id = p_store_id or lt.buyer_warehouse_id in (select id from public.warehouses where store_id = p_store_id)) then 'incoming_transfer' else 'outgoing_transfer' end,
      'happened_at', coalesce(lt.completed_at, lt.finish_at, lt.started_at),
      'title',
        case
          when (lt.buyer_store_id = p_store_id or lt.buyer_warehouse_id in (select id from public.warehouses where store_id = p_store_id)) then
            case
              when lt.status = 'in_transit' then
                case when coalesce(lt.total_price, 0) > 0 then 'Pazardan Geliyor' else 'Depodan Geliyor' end
              else
                case when coalesce(lt.total_price, 0) > 0 then 'Pazardan Geldi' else 'Depodan Geldi' end
            end
          else
            case
              when lt.status = 'in_transit' then 'Depoya Gonderiliyor'
              else 'Depoya Gonderildi'
            end
        end,
      'subtitle',
        case
          when (lt.buyer_store_id = p_store_id or lt.buyer_warehouse_id in (select id from public.warehouses where store_id = p_store_id)) then
            coalesce(sw.name, 'Depo') || ' | ' || coalesce(sc.name, 'Sehir')
          else
            coalesce(bw.name, 'Depo') || ' | ' || coalesce(bc.name, 'Sehir')
        end,
      'product_name', coalesce(p.urun_adi, 'Urun'),
      'quantity', coalesce(lt.quantity, 0),
      'amount', coalesce(lt.total_price, 0),
      'secondary_amount', lt.rental_cost,
      'quality_level', lt.quality_level,
      'status', coalesce(lt.status, 'completed')
    ) as item
    from public.logistics_transfers lt
    left join public.warehouses sw on sw.id = lt.seller_warehouse_id
    left join public.cities sc on sc.id = sw.city_id
    left join public.warehouses bw on bw.id = lt.buyer_warehouse_id
    left join public.cities bc on bc.id = bw.city_id
    left join public.products p on p.id = lt.product_id
    join public.stores s on s.id = p_store_id and s.player_id = auth.uid()
    where (
      lt.buyer_store_id = p_store_id 
      or lt.seller_store_id = p_store_id
      or lt.buyer_warehouse_id in (select id from public.warehouses where store_id = p_store_id)
      or lt.seller_warehouse_id in (select id from public.warehouses where store_id = p_store_id)
    )
  ),
  sale_items as (
    select jsonb_build_object(
      'id', 'sale_' || sdp.id::text,
      'type', 'sale',
      'happened_at', coalesce(sdp.last_sale_at, sdp.performance_date::timestamp),
      'title', 'Satis Ozeti',
      'subtitle', coalesce(sdp.sale_event_count, 0)::text || ' satis islemi',
      'product_name', coalesce(sdp.product_name, 'Urun'),
      'quantity', coalesce(sdp.sold_quantity, 0),
      'amount', coalesce(sdp.revenue, 0),
      'secondary_amount', sdp.profit,
      'quality_level', sdp.quality_level,
      'status', 'completed'
    ) as item
    from public.store_daily_performance sdp
    join public.stores s on s.id = sdp.store_id and s.player_id = auth.uid()
    where sdp.store_id = p_store_id
      and sdp.sold_quantity > 0
  ),
  all_items as (
    select item from transfer_items
    union all
    select item from sale_items
  )
  select coalesce(
    jsonb_agg(item order by (item->>'happened_at')::timestamptz desc),
    '[]'::jsonb
  )
  from (
    select item
    from all_items
    order by (item->>'happened_at')::timestamptz desc
    limit 100
  ) ranked;
$function$;
