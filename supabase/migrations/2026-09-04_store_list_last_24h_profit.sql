-- Migration: 2026-09-04_store_list_last_24h_profit.sql
-- Description: Add last 24h actual profit and revenue metrics to store list page RPC

CREATE OR REPLACE FUNCTION public.get_store_list_page_data()
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  with live_rows as (
    select
      s.id,
      s.created_at as sort_time,
      s.name as sort_name,
      false as is_under_construction,
      s.is_active,
      coalesce(slot_summary.total_capacity, 0) as total_capacity,
      jsonb_build_object(
        'id', s.id,
        'name', s.name,
        'city_id', s.city_id,
        'city_name', c.name,
        'level', s.level,
        'is_active', s.is_active,
        'current_slot_count', s.current_slot_count,
        'max_slot_count', s.max_slot_count,
        'slot_capacity', s.slot_capacity,
        'store_type', jsonb_build_object(
          'id', st.id,
          'name', st.name,
          'icon', st.icon,
          'cost', st.cost,
          'required_level', st.required_level,
          'construction_time_minutes', st.construction_time_minutes
        ),
        'summary', jsonb_build_object(
          'total_quantity', coalesce(slot_summary.total_quantity, 0),
          'total_capacity', coalesce(slot_summary.total_capacity, 0),
          'pending_quantity', coalesce(slot_summary.pending_quantity, 0),
          'available_capacity', greatest(
            coalesce(slot_summary.total_capacity, 0)
            - coalesce(slot_summary.total_quantity, 0)
            - coalesce(slot_summary.pending_quantity, 0),
            0
          ),
          'used_capacity_ratio', case
            when coalesce(slot_summary.total_capacity, 0) > 0 then
              round(
                (
                  coalesce(slot_summary.total_quantity, 0)
                  + coalesce(slot_summary.pending_quantity, 0)
                )::numeric / slot_summary.total_capacity::numeric,
                4
              )
            else 0
          end,
          'pending_sale_total', coalesce(slot_summary.pending_sale_total, 0),
          'total_stock_cost_value', coalesce(slot_summary.total_stock_cost_value, 0),
          'total_stock_sale_value', coalesce(slot_summary.total_stock_sale_value, 0),
          'last_24h_profit', coalesce(daily_perf.last_24h_profit, 0),
          'last_24h_revenue', coalesce(daily_perf.last_24h_revenue, 0),
          'last_24h_sold_quantity', coalesce(daily_perf.last_24h_sold_quantity, 0)
        ),
        'slots', coalesce(slot_summary.slots, '[]'::jsonb),
        'is_under_construction', false
      ) as payload
    from public.stores s
    join public.cities c on c.id = s.city_id
    join public.store_types st on st.id = s.store_type_id
    left join lateral (
      select
        coalesce(sum(ss.quantity), 0) as total_quantity,
        coalesce(sum(ss.capacity), 0) as total_capacity,
        coalesce(sum(ss.pending_quantity), 0) as pending_quantity,
        coalesce(sum(ss.pending_sale), 0) as pending_sale_total,
        coalesce(sum(ss.quantity * ss.cost), 0) as total_stock_cost_value,
        coalesce(sum(ss.quantity * ss.price), 0) as total_stock_sale_value,
        coalesce(
          jsonb_agg(
            jsonb_build_object(
              'slot_id', ss.id,
              'id', ss.id,
              'store_id', ss.store_id,
              'slot_index', ss.slot_index,
              'brand_id', ss.brand_id,
              'product_id', ss.product_id,
              'product_name', p.urun_adi,
              'product_icon', p.urun_iconu,
              'quality_level', ss.quality_level,
              'quantity', ss.quantity,
              'capacity', ss.capacity,
              'pending_quantity', ss.pending_quantity,
              'price', ss.price,
              'cost', ss.cost,
              'pending_sale', ss.pending_sale,
              'is_active', ss.is_active,
              'is_empty', case
                when ss.product_id is null or ss.quality_level = 0 then true
                else false
              end,
              'used_capacity_ratio', case
                when ss.capacity > 0 then
                  round((ss.quantity + ss.pending_quantity)::numeric / ss.capacity::numeric, 4)
                else 0
              end
            )
            order by ss.slot_index asc
          ),
          '[]'::jsonb
        ) as slots
      from public.store_slots ss
      left join public.products p on p.id = ss.product_id
      where ss.store_id = s.id
    ) slot_summary on true
    left join lateral (
      select
        coalesce(sum(sdp.profit), 0) as last_24h_profit,
        coalesce(sum(sdp.revenue), 0) as last_24h_revenue,
        coalesce(sum(sdp.sold_quantity), 0) as last_24h_sold_quantity
      from public.store_daily_performance sdp
      where sdp.store_id = s.id
        and sdp.performance_date >= (timezone('Europe/Istanbul', now())::date - 1)
        and (sdp.last_sale_at is null or sdp.last_sale_at >= (timezone('utc', now()) - interval '24 hours'))
    ) daily_perf on true
    where s.player_id = auth.uid()
  ),
  construction_rows as (
    select
      bc.id,
      bc.started_at as sort_time,
      coalesce(nullif(bc.params ->> 'name', ''), st.name, 'Magaza') as sort_name,
      true as is_under_construction,
      false as is_active,
      coalesce((bc.params ->> 'slot_capacity')::integer, 0) as total_capacity,
      jsonb_build_object(
        'id', bc.id,
        'name', coalesce(nullif(bc.params ->> 'name', ''), st.name, 'Magaza'),
        'city_id', bc.params ->> 'city_id',
        'city_name', c.name,
        'level', coalesce((bc.params ->> 'level')::integer, 1),
        'is_active', false,
        'current_slot_count', coalesce((bc.params ->> 'current_slot_count')::integer, 0),
        'max_slot_count', coalesce((bc.params ->> 'max_slot_count')::integer, 0),
        'slot_capacity', coalesce((bc.params ->> 'slot_capacity')::integer, 0),
        'store_type', jsonb_build_object(
          'id', st.id,
          'name', st.name,
          'icon', st.icon,
          'cost', st.cost,
          'required_level', st.required_level,
          'construction_time_minutes', st.construction_time_minutes
        ),
        'summary', jsonb_build_object(
          'total_quantity', 0,
          'total_capacity', coalesce((bc.params ->> 'slot_capacity')::integer, 0),
          'pending_quantity', 0,
          'available_capacity', coalesce((bc.params ->> 'slot_capacity')::integer, 0),
          'used_capacity_ratio', 0,
          'last_24h_profit', 0,
          'last_24h_revenue', 0,
          'last_24h_sold_quantity', 0
        ),
        'slots', '[]'::jsonb,
        'is_under_construction', true,
        'started_at', bc.started_at,
        'finish_at', bc.finish_at,
        'construction_progress', case
          when bc.finish_at <= bc.started_at then 0
          else least(
            greatest(
              extract(epoch from (timezone('utc', now()) - bc.started_at))
              / nullif(extract(epoch from (bc.finish_at - bc.started_at)), 0),
              0
            ),
            1
          )
        end
      ) as payload
    from public.building_constructions bc
    left join public.store_types st
      on st.id = nullif(bc.params ->> 'store_type_id', '')::uuid
    left join public.cities c
      on c.id = nullif(bc.params ->> 'city_id', '')::uuid
    where bc.player_id = auth.uid()
      and bc.building_kind = 'store'
      and bc.status = 'in_progress'
  ),
  combined as (
    select * from live_rows
    union all
    select * from construction_rows
  )
  select jsonb_build_object(
    'success', true,
    'stores', coalesce(
      (
        select jsonb_agg(payload order by sort_time asc, sort_name asc)
        from combined
      ),
      '[]'::jsonb
    ),
    'summary', jsonb_build_object(
      'total_count', coalesce((select count(*) from combined), 0),
      'active_count', coalesce((select count(*) from live_rows where is_active is true), 0),
      'construction_count', coalesce((select count(*) from construction_rows), 0),
      'total_capacity', coalesce((select sum(total_capacity) from live_rows), 0),
      'total_last_24h_profit', coalesce((select sum((payload->'summary'->>'last_24h_profit')::numeric) from live_rows), 0),
      'total_last_24h_revenue', coalesce((select sum((payload->'summary'->>'last_24h_revenue')::numeric) from live_rows), 0)
    )
  );
$function$;
