create or replace function public.get_logistics_entry_state()
returns jsonb
language sql
security definer
set search_path = public
as $$
  with company as (
    select to_jsonb(lc) as data
    from public.logistics_companies lc
    where lc.player_id = auth.uid()
    order by lc.created_at
    limit 1
  ),
  construction as (
    select jsonb_build_object(
      'id', bc.id,
      'player_id', bc.player_id,
      'building_kind', bc.building_kind,
      'status', bc.status,
      'params', bc.params,
      'started_at', bc.started_at,
      'finish_at', bc.finish_at,
      'completed_at', bc.completed_at
    ) as data
    from public.building_constructions bc
    where bc.player_id = auth.uid()
      and bc.building_kind = 'logistics_company'
      and bc.status = 'in_progress'
    order by bc.started_at desc
    limit 1
  )
  select jsonb_build_object(
    'success', true,
    'has_company', exists(select 1 from company),
    'has_construction', exists(select 1 from construction),
    'company', (select data from company),
    'construction', (select data from construction),
    'route', case
      when exists(select 1 from company) or exists(select 1 from construction)
        then '/logistics'
      else '/logistics/setup'
    end
  );
$$;

create or replace function public.bootstrap_game_session()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_player_id uuid := auth.uid();
  v_player jsonb;
  v_logistics_state jsonb;
  v_upgrades_result jsonb;
  v_transfers_result jsonb;
begin
  if v_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  perform public.ensure_player_record_exists(v_player_id);

  v_upgrades_result := public.complete_due_building_upgrades(100);
  v_transfers_result := public.complete_due_market_transfers(v_player_id, 100);
  v_player := public.get_player_profile(v_player_id);
  v_logistics_state := public.get_logistics_entry_state();

  return jsonb_build_object(
    'success', true,
    'player', v_player,
    'logistics_entry_state', v_logistics_state,
    'completed_due_building_upgrades', v_upgrades_result,
    'completed_due_market_transfers', v_transfers_result
  );
end;
$$;

create or replace function public.get_store_list_page_data()
returns jsonb
language sql
security definer
set search_path = public
as $$
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
          'total_stock_sale_value', coalesce(slot_summary.total_stock_sale_value, 0)
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
          'used_capacity_ratio', 0
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
      'total_capacity', coalesce((select sum(total_capacity) from live_rows), 0)
    )
  );
$$;

create or replace function public.get_warehouse_list_page_data()
returns jsonb
language sql
security definer
set search_path = public
as $$
  with live_rows as (
    select
      w.id,
      w.created_at as sort_time,
      w.name as sort_name,
      false as is_under_construction,
      w.is_active,
      coalesce(w.capacity, 0) as total_capacity,
      jsonb_build_object(
        'id', w.id,
        'player_id', w.player_id,
        'warehouse_type_id', w.warehouse_type_id,
        'city_id', w.city_id,
        'name', w.name,
        'level', w.level,
        'capacity', w.capacity,
        'reserved_capacity', w.reserved_capacity,
        'is_active', w.is_active,
        'created_at', w.created_at,
        'updated_at', w.updated_at,
        'city', jsonb_build_object('name', c.name),
        'warehouse_type', jsonb_build_object(
          'id', wt.id,
          'name', wt.name,
          'icon', wt.icon,
          'base_capacity', wt.base_capacity,
          'cost', wt.cost,
          'required_level', wt.required_level,
          'construction_time_minutes', wt.construction_time_minutes
        ),
        'warehouse_slots', coalesce(slot_rows.slots, '[]'::jsonb),
        'is_under_construction', false
      ) as payload
    from public.warehouses w
    join public.cities c on c.id = w.city_id
    left join public.warehouse_types wt on wt.id = w.warehouse_type_id
    left join lateral (
      select coalesce(
        jsonb_agg(
          jsonb_build_object(
            'id', ws.id,
            'product_id', ws.product_id,
            'product_name', p.urun_adi,
            'quantity', ws.quantity,
            'quality_level', ws.quality_level,
            'price', ws.price,
            'cost', ws.cost,
            'is_available_for_sale', ws.is_available_for_sale,
            'product', case
              when p.id is null then null
              else jsonb_build_object(
                'id', p.id,
                'urun_adi', p.urun_adi,
                'urun_iconu', p.urun_iconu,
                'birim_hacim', p.birim_hacim
              )
            end
          )
          order by ws.created_at
        ),
        '[]'::jsonb
      ) as slots
      from public.warehouse_slots ws
      left join public.products p on p.id = ws.product_id
      where ws.warehouse_id = w.id
    ) slot_rows on true
    where w.player_id = auth.uid()
  ),
  construction_rows as (
    select
      bc.id,
      bc.started_at as sort_time,
      coalesce(nullif(bc.params ->> 'name', ''), wt.name, 'Depo') as sort_name,
      true as is_under_construction,
      false as is_active,
      coalesce((bc.params ->> 'capacity')::numeric, 0) as total_capacity,
      jsonb_build_object(
        'id', bc.id,
        'player_id', bc.player_id,
        'warehouse_type_id', bc.params ->> 'warehouse_type_id',
        'city_id', bc.params ->> 'city_id',
        'name', coalesce(nullif(bc.params ->> 'name', ''), wt.name, 'Depo'),
        'level', coalesce((bc.params ->> 'level')::integer, 1),
        'capacity', coalesce((bc.params ->> 'capacity')::numeric, 0),
        'reserved_capacity', coalesce((bc.params ->> 'reserved_capacity')::numeric, 0),
        'is_active', false,
        'created_at', bc.started_at,
        'updated_at', bc.started_at,
        'city', jsonb_build_object('name', c.name),
        'warehouse_type', jsonb_build_object(
          'id', wt.id,
          'name', wt.name,
          'icon', wt.icon,
          'base_capacity', wt.base_capacity,
          'cost', wt.cost,
          'required_level', wt.required_level,
          'construction_time_minutes', wt.construction_time_minutes
        ),
        'warehouse_slots', '[]'::jsonb,
        'is_under_construction', true,
        'finish_at', bc.finish_at
      ) as payload
    from public.building_constructions bc
    left join public.warehouse_types wt
      on wt.id = nullif(bc.params ->> 'warehouse_type_id', '')::uuid
    left join public.cities c
      on c.id = nullif(bc.params ->> 'city_id', '')::uuid
    where bc.player_id = auth.uid()
      and bc.building_kind = 'warehouse'
      and bc.status = 'in_progress'
  ),
  combined as (
    select * from live_rows
    union all
    select * from construction_rows
  )
  select jsonb_build_object(
    'success', true,
    'warehouses', coalesce(
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
      'total_capacity', coalesce((select sum(total_capacity) from live_rows), 0)
    )
  );
$$;
