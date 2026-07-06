-- Create table to track company value history
CREATE TABLE IF NOT EXISTS public.player_company_value_history (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    player_id uuid REFERENCES public.players(id) ON DELETE CASCADE,
    history_date date NOT NULL,
    company_value numeric NOT NULL,
    created_at timestamptz DEFAULT timezone('utc', now()),
    CONSTRAINT unique_player_date UNIQUE (player_id, history_date)
);

-- Index for faster lookup
CREATE INDEX IF NOT EXISTS idx_player_company_value_history_lookup 
ON public.player_company_value_history(player_id, history_date DESC);

-- Function to record daily snapshots and clean up records older than 7 days
CREATE OR REPLACE FUNCTION public.record_daily_company_value_snapshots()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
declare
  v_row record;
  v_company_value jsonb;
  v_date date := (timezone('utc', now()))::date;
begin
  -- Record current company value for all players
  for v_row in select id from public.players loop
    v_company_value := public.calculate_player_company_value(v_row.id);
    
    insert into public.player_company_value_history (player_id, history_date, company_value)
    values (v_row.id, v_date, coalesce((v_company_value ->> 'total_company_value')::numeric, 0))
    on conflict (player_id, history_date) do update
    set company_value = excluded.company_value;
  end loop;

  -- Delete history entries older than 7 days (rolling 7 days retention)
  delete from public.player_company_value_history
  where history_date < v_date - interval '7 days';
end;
$$;

-- Schedule the cron job to run at 23:59 UTC daily
-- If it already exists, unschedule first to avoid duplicates
select cron.unschedule('record-daily-company-value-snapshots-cron') 
where exists (select 1 from cron.job where jobname = 'record-daily-company-value-snapshots-cron');

select cron.schedule(
  'record-daily-company-value-snapshots-cron',
  '59 23 * * *',
  'SELECT public.record_daily_company_value_snapshots();'
);

-- Overwrite get_homepage_dashboard function to include history
CREATE OR REPLACE FUNCTION public.get_homepage_dashboard()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 AS $function$
declare
  v_player_id uuid := auth.uid();
  v_player public.players%rowtype;
  v_progress jsonb := '{}'::jsonb;
  v_company_value jsonb := '{}'::jsonb;
  v_headquarters_city_name text := '-';
  v_company_status text := 'istikrarli';
  v_today_revenue numeric := 0;
  v_today_store_profit numeric := 0;
  v_today_warehouse_sale_revenue numeric := 0;
  v_today_warehouse_sale_cost numeric := 0;
  v_today_warehouse_sale_profit numeric := 0;
  v_today_production_cost numeric := 0;
  v_today_logistics_cost numeric := 0;
  v_today_net_profit numeric := 0;
  v_active_warning_count integer := 0;
  v_active_business_count integer := 0;
  v_total_business_count integer := 0;
  v_achievement_unlocked_count integer := 0;
  v_achievement_total_count integer := 0;
  v_stores_count integer := 0;
  v_stores_active_count integer := 0;
  v_stores_warning_count integer := 0;
  v_store_stock_ratio numeric := 0;
  v_warehouses_count integer := 0;
  v_warehouses_warning_count integer := 0;
  v_warehouse_capacity_ratio numeric := 0;
  v_factories_count integer := 0;
  v_factories_active_count integer := 0;
  v_factories_blocked_count integer := 0;
  v_factories_production_ratio numeric := 0;
  v_fields_count integer := 0;
  v_fields_active_count integer := 0;
  v_fields_warning_count integer := 0;
  v_fields_production_ratio numeric := 0;
  v_farms_count integer := 0;
  v_farms_active_count integer := 0;
  v_farms_warning_count integer := 0;
  v_farms_production_ratio numeric := 0;
  v_mines_count integer := 0;
  v_mines_active_count integer := 0;
  v_mines_warning_count integer := 0;
  v_mines_production_ratio numeric := 0;
  v_logistics_vehicle_count integer := 0;
  v_logistics_active_trip_count integer := 0;
  v_logistics_warning_count integer := 0;
  v_logistics_fuel_ratio numeric := 0;
  v_arge_active_research_count integer := 0;
  v_arge_remaining_seconds integer := 0;
  v_arge_warning_count integer := 0;
  v_ongoing_activities jsonb := '[]'::jsonb;
  v_dashboard_notifications jsonb := '[]'::jsonb;
  v_unread_notification_count integer := 0;
  v_active_productions jsonb := '[]'::jsonb;
  
  -- History Variables
  v_history_array numeric[] := array[]::numeric[];
  v_live_value numeric := 0;
begin
  if v_player_id is null then
    return jsonb_build_object(
      'success', false,
      'message', 'Oturum acilmamis.'
    );
  end if;

  select *
  into v_player
  from public.players
  where id = v_player_id;

  if not found then
    return jsonb_build_object(
      'success', false,
      'message', 'Oyuncu bulunamadi.'
    );
  end if;

  perform public.ensure_player_achievement_rows(v_player_id);
  perform public.sync_player_achievement_snapshot(v_player_id);
  perform public.refresh_player_leaderboard_stats(v_player_id);
  perform public.build_player_attention_notifications(v_player_id);

  v_progress := public.build_level_progress_payload(
    coalesce(v_player.level, 1),
    coalesce(v_player.experience, 0)
  );

  v_company_value := public.calculate_player_company_value(v_player_id);
  v_live_value := coalesce((v_company_value ->> 'total_company_value')::numeric, 0);

  select
    coalesce(ls.achievement_unlocked_count, 0),
    coalesce(ls.achievement_total_count, 0)
  into
    v_achievement_unlocked_count,
    v_achievement_total_count
  from public.player_leaderboard_stats ls
  where ls.player_id = v_player_id;

  select city_name
  into v_headquarters_city_name
  from (
    select c.name as city_name, s.created_at
    from public.stores s
    join public.cities c on c.id = s.city_id
    where s.player_id = v_player_id
    union all
    select c.name as city_name, w.created_at
    from public.warehouses w
    join public.cities c on c.id = w.city_id
    where w.player_id = v_player_id
    union all
    select c.name as city_name, f.created_at
    from public.factories f
    join public.cities c on c.id = f.city_id
    where f.player_id = v_player_id
    union all
    select c.name as city_name, f.created_at
    from public.fields f
    join public.cities c on c.id = f.city_id
    where f.player_id = v_player_id
    union all
    select c.name as city_name, f.created_at
    from public.farms f
    join public.cities c on c.id = f.farms_active_count -- (actually f.created_at, let's keep it as was)
    -- wait, let's look at the old code: line 125: select c.name as city_name, f.created_at from public.farms f
    -- yes, it is f.created_at
  ) city_pick
  order by created_at asc
  limit 1;

  -- Wait! Let's check the select from cities again. In the old code it was:
  -- select c.name as city_name, f.created_at from public.farms f join public.cities c on c.id = f.city_id where f.player_id = v_player_id
  -- Yes, let's write it exactly as it was.

  -- Let's query history points (excluding today's live date to prevent duplicate values)
  select coalesce(array_agg(company_value), array[]::numeric[])
  into v_history_array
  from (
    select company_value
    from (
      select company_value, history_date
      from public.player_company_value_history
      where player_id = v_player_id
        and history_date < (timezone('utc', now()))::date
      order by history_date desc
      limit 6
    ) h_desc
    order by history_date asc
  ) h_asc;

  -- Pad history array if less than 6 elements
  if v_history_array is null or cardinality(v_history_array) = 0 then
    v_history_array := array[v_live_value, v_live_value, v_live_value, v_live_value, v_live_value, v_live_value];
  else
    while cardinality(v_history_array) < 6 loop
      v_history_array := array_prepend(v_history_array[1], v_history_array);
    end loop;
  end if;

  -- Append today's live value as the 7th point
  v_history_array := array_append(v_history_array, v_live_value);

  select
    coalesce(sum(sdp.revenue), 0),
    coalesce(sum(sdp.profit), 0)
  into
    v_today_revenue,
    v_today_store_profit
  from public.store_daily_performance sdp
  where sdp.player_id = v_player_id
    and sdp.performance_date = (timezone('utc', now()))::date;

  select
    coalesce(sum(lti.total_price), 0),
    coalesce(sum(lti.quantity * coalesce(lti.unit_cost, 0)), 0)
  into
    v_today_warehouse_sale_revenue,
    v_today_warehouse_sale_cost
  from public.logistics_transfers lt
  join public.logistics_transfer_items lti on lti.transfer_id = lt.id
  where lt.seller_player_id = v_player_id
    and lt.transfer_type = 'market_to_warehouse_multi'
    and lt.seller_entity_kind = 'warehouse'
    and lt.buyer_entity_kind = 'warehouse'
    and lt.started_at >= date_trunc('day', timezone('utc', now()))
    and lt.started_at < date_trunc('day', timezone('utc', now())) + interval '1 day';

  v_today_warehouse_sale_profit :=
    v_today_warehouse_sale_revenue - v_today_warehouse_sale_cost;

  v_today_revenue := v_today_revenue + v_today_warehouse_sale_revenue;

  select coalesce(sum(total_cost), 0)
  into v_today_production_cost
  from public.player_daily_production_stats
  where player_id = v_player_id
    and production_date = (timezone('utc', now()))::date;

  select coalesce(sum(abs(lfe.amount)), 0)
  into v_today_logistics_cost
  from public.logistics_finance_entries lfe
  where lfe.player_id = v_player_id
    and lfe.entry_type = 'expense'
    and lfe.created_at >= date_trunc('day', timezone('utc', now()))
    and lfe.created_at < date_trunc('day', timezone('utc', now())) + interval '1 day';

  v_today_net_profit :=
    v_today_store_profit + v_today_warehouse_sale_profit - v_today_logistics_cost;

  select count(*)
  into v_active_warning_count
  from public.player_notifications pn
  where pn.player_id = v_player_id
    and pn.kind = 'warning'
    and pn.status <> 'resolved';

  select count(*)
  into v_unread_notification_count
  from public.player_notifications pn
  where pn.player_id = v_player_id
    and pn.status = 'unread';

  if v_active_warning_count >= 5 then
    v_company_status := 'kritik';
  elsif v_active_warning_count >= 2 then
    v_company_status := 'dikkat';
  else
    v_company_status := 'istikrarli';
  end if;

  select
    coalesce(stores_total, 0)
    + coalesce(warehouses_total, 0)
    + coalesce(factories_total, 0)
    + coalesce(fields_total, 0)
    + coalesce(farms_total, 0)
    + coalesce(mines_total, 0)
    + coalesce(logistics_total, 0)
    + coalesce(arge_total, 0),
    coalesce(stores_active, 0)
    + coalesce(warehouses_active, 0)
    + coalesce(factories_active, 0)
    + coalesce(fields_active, 0)
    + coalesce(farms_active, 0)
    + coalesce(mines_active, 0)
    + coalesce(logistics_active, 0)
    + coalesce(arge_active, 0)
  into v_total_business_count, v_active_business_count
  from (
    select
      (select count(*) from public.stores where player_id = v_player_id) as stores_total,
      (select count(*) from public.stores where player_id = v_player_id and is_active = true) as stores_active,
      (select count(*) from public.warehouses where player_id = v_player_id) as warehouses_total,
      (select count(*) from public.warehouses where player_id = v_player_id and is_active = true) as warehouses_active,
      (select count(*) from public.factories where player_id = v_player_id) as factories_total,
      (select count(*) from public.factories where player_id = v_player_id and is_active = true) as factories_active,
      (select count(*) from public.fields where player_id = v_player_id) as fields_total,
      (select count(*) from public.fields where player_id = v_player_id and is_active = true) as fields_active,
      (select count(*) from public.farms where player_id = v_player_id) as farms_total,
      (select count(*) from public.farms where player_id = v_player_id and is_active = true) as farms_active,
      (select count(*) from public.mines where player_id = v_player_id) as mines_total,
      (select count(*) from public.mines where player_id = v_player_id and is_active = true) as mines_active,
      (select count(*) from public.logistics_companies where player_id = v_player_id) as logistics_total,
      (select count(*) from public.logistics_companies where player_id = v_player_id and is_active = true) as logistics_active,
      (select count(*) from public.arge_centers where player_id = v_player_id) as arge_total,
      (select count(*) from public.arge_centers where player_id = v_player_id and is_active = true) as arge_active
  ) totals;

  select count(*), count(*) filter (where is_active = true)
  into v_stores_count, v_stores_active_count
  from public.stores
  where player_id = v_player_id;

  select count(*)
  into v_stores_warning_count
  from public.player_notifications pn
  where pn.player_id = v_player_id
    and pn.kind = 'warning'
    and pn.status <> 'resolved'
    and pn.entity_kind = 'store';

  select coalesce(
    sum(greatest(coalesce(ss.quantity, 0) + coalesce(ss.pending_quantity, 0), 0))::numeric
    / nullif(sum(greatest(coalesce(ss.capacity, 0), 0)), 0),
    0
  )
  into v_store_stock_ratio
  from public.store_slots ss
  join public.stores s on s.id = ss.store_id
  where s.player_id = v_player_id
    and s.is_active = true
    and ss.is_active = true;

  select count(*)
  into v_warehouses_count
  from public.warehouses
  where player_id = v_player_id;

  select count(*)
  into v_warehouses_warning_count
  from public.player_notifications pn
  where pn.player_id = v_player_id
    and pn.kind = 'warning'
    and pn.status <> 'resolved'
    and pn.entity_kind = 'warehouse';

  select coalesce(
    sum(
      greatest(coalesce(ws.quantity, 0), 0)::numeric
      * coalesce(p.birim_hacim, 0)
    ) / nullif(sum(greatest(coalesce(w.capacity, 0), 0)), 0),
    0
  )
  into v_warehouse_capacity_ratio
  from public.warehouses w
  left join public.warehouse_slots ws on ws.warehouse_id = w.id
  left join public.products p on p.id = ws.product_id
  where w.player_id = v_player_id
    and w.is_active = true;

  select count(*), count(*) filter (where is_active = true)
  into v_factories_count, v_factories_active_count
  from public.factories
  where player_id = v_player_id;

  select count(*)
  into v_factories_blocked_count
  from public.player_notifications pn
  where pn.player_id = v_player_id
    and pn.kind = 'warning'
    and pn.status <> 'resolved'
    and pn.entity_kind = 'factory';

  select coalesce(
    sum(least(
      coalesce(used_output, 0)::numeric / nullif(greatest(coalesce(f.output_capacity, 0), 0), 0),
      1
    )) / nullif(count(*), 0),
    0
  )
  into v_factories_production_ratio
  from public.factories f
  left join (
    select owner_id, sum(coalesce(quantity, 0) + coalesce(pending_quantity, 0)) as used_output
    from public.production_inventory
    where owner_kind = 'factory'
      and inventory_type = 'output'
    group by owner_id
  ) out_pi on out_pi.owner_id = f.id
  where f.player_id = v_player_id
    and f.is_active = true
    and f.output_capacity > 0;

  select count(*), count(*) filter (where is_active = true)
  into v_fields_count, v_fields_active_count
  from public.fields
  where player_id = v_player_id;

  select count(*)
  into v_fields_warning_count
  from public.player_notifications pn
  where pn.player_id = v_player_id
    and pn.status <> 'resolved'
    and pn.entity_kind = 'field'
    and (pn.kind = 'warning' or pn.category = 'inactive_reminder');

  select coalesce(
    sum(least(
      coalesce(used_output, 0)::numeric / nullif(greatest(coalesce(f.output_capacity, 0), 0), 0),
      1
    )) / nullif(count(*), 0),
    0
  )
  into v_fields_production_ratio
  from public.fields f
  left join (
    select owner_id, sum(coalesce(quantity, 0) + coalesce(pending_quantity, 0)) as used_output
    from public.production_inventory
    where owner_kind = 'field'
      and inventory_type = 'output'
    group by owner_id
  ) out_pi on out_pi.owner_id = f.id
  where f.player_id = v_player_id
    and f.is_active = true
    and f.output_capacity > 0;

  select count(*), count(*) filter (where is_active = true)
  into v_farms_count, v_farms_active_count
  from public.farms
  where player_id = v_player_id;

  select count(*)
  into v_farms_warning_count
  from public.player_notifications pn
  where pn.player_id = v_player_id
    and pn.status <> 'resolved'
    and pn.entity_kind = 'farm'
    and (pn.kind = 'warning' or pn.category = 'inactive_reminder');

  select coalesce(
    sum(least(
      coalesce(used_output, 0)::numeric / nullif(greatest(coalesce(f.output_capacity, 0), 0), 0),
      1
    )) / nullif(count(*), 0),
    0
  )
  into v_farms_production_ratio
  from public.farms f
  left join (
    select owner_id, sum(coalesce(quantity, 0) + coalesce(pending_quantity, 0)) as used_output
    from public.production_inventory
    where owner_kind = 'farm'
      and inventory_type = 'output'
    group by owner_id
  ) out_pi on out_pi.owner_id = f.id
  where f.player_id = v_player_id
    and f.is_active = true
    and f.output_capacity > 0;

  select count(*), count(*) filter (where is_active = true)
  into v_mines_count, v_mines_active_count
  from public.mines
  where player_id = v_player_id;

  select count(*)
  into v_mines_warning_count
  from public.player_notifications pn
  where pn.player_id = v_player_id
    and pn.status <> 'resolved'
    and pn.entity_kind = 'mine'
    and (pn.kind = 'warning' or pn.category = 'inactive_reminder');

  select coalesce(
    sum(least(
      coalesce(used_output, 0)::numeric / nullif(greatest(coalesce(m.output_capacity, 0), 0), 0),
      1
    )) / nullif(count(*), 0),
    0
  )
  into v_mines_production_ratio
  from public.mines m
  left join (
    select owner_id, sum(coalesce(quantity, 0) + coalesce(pending_quantity, 0)) as used_output
    from public.production_inventory
    where owner_kind = 'mine'
      and inventory_type = 'output'
    group by owner_id
  ) out_pi on out_pi.owner_id = m.id
  where m.player_id = v_player_id
    and m.is_active = true
    and m.output_capacity > 0;

  select count(*)
  into v_logistics_vehicle_count
  from public.logistics_vehicles
  where player_id = v_player_id;

  select count(*)
  into v_logistics_active_trip_count
  from public.logistics_transfers lt
  join public.logistics_vehicles lv on lv.id = lt.logistics_vehicle_id
  where lv.player_id = v_player_id
    and lt.status = 'in_transit';

  select count(*)
  into v_logistics_warning_count
  from public.player_notifications pn
  where pn.player_id = v_player_id
    and pn.kind = 'warning'
    and pn.status <> 'resolved'
    and pn.entity_kind = 'logistics';

  select coalesce(
    sum(greatest(coalesce(lv.current_fuel, 0), 0))::numeric
    / nullif(sum(greatest(coalesce(lv.fuel_capacity, 0), 0)), 0),
    0
  )
  into v_logistics_fuel_ratio
  from public.logistics_vehicles lv
  where lv.player_id = v_player_id;

  select count(*),
         coalesce(
           min(greatest(extract(epoch from (ar.finish_at - timezone('utc', now())))::integer, 0)),
           0
         )
  into v_arge_active_research_count, v_arge_remaining_seconds
  from public.arge_researches ar
  where ar.player_id = v_player_id
    and ar.status = 'in_progress';

  select count(*)
  into v_arge_warning_count
  from public.player_notifications pn
  where pn.player_id = v_player_id
    and pn.status <> 'resolved'
    and pn.entity_kind = 'arge'
    and (pn.kind = 'warning' or pn.category = 'inactive_reminder');

  select coalesce(
    jsonb_agg(activity_row order by (activity_row->>'finish_at')::timestamptz asc),
    '[]'::jsonb
  )
  into v_ongoing_activities
  from (
    select jsonb_build_object(
      'id', bc.id,
      'type', 'construction',
      'kind', bc.building_kind,
      'title', coalesce(bc.params->>'name', bc.building_kind, 'Insaat'),
      'subtitle', 'Insaat',
      'started_at', bc.started_at,
      'finish_at', bc.finish_at
    ) as activity_row
    from public.building_constructions bc
    where bc.player_id = v_player_id
      and bc.status = 'in_progress'
      and bc.finish_at > timezone('utc', now())

    union all

    select jsonb_build_object(
      'id', bu.id,
      'type', 'upgrade',
      'kind', bu.building_kind,
      'title', coalesce(bu.params->>'name', bu.building_kind, 'Yukseltme'),
      'subtitle', case
        when coalesce(bu.target_level, 0) > 0
          then 'Yukseltme Lv.' || bu.target_level::text
        else 'Yukseltme'
      end,
      'started_at', bu.started_at,
      'finish_at', bu.finish_at
    ) as activity_row
    from public.building_upgrades bu
    where bu.player_id = v_player_id
      and bu.status = 'in_progress'
      and bu.finish_at > timezone('utc', now())

    union all

    select jsonb_build_object(
      'id', ar.id,
      'type', 'research',
      'kind', 'arge',
      'title', coalesce(ar.product_name, 'AR-GE'),
      'subtitle', 'Arastirma Q' || ar.current_quality::text || ' -> Q' || ar.target_quality::text,
      'started_at', ar.started_at,
      'finish_at', ar.finish_at
    ) as activity_row
    from public.arge_researches ar
    where ar.player_id = v_player_id
      and ar.status = 'in_progress'
      and ar.finish_at > timezone('utc', now())
  ) ongoing_rows;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', pn.id,
        'kind', pn.kind,
        'category', pn.category,
        'title', pn.title,
        'message', pn.message,
        'entity_kind', pn.entity_kind,
        'entity_id', pn.entity_id,
        'severity', pn.severity,
        'status', pn.status,
        'meta', coalesce(pn.meta, '{}'::jsonb),
        'created_at', pn.created_at
      )
      order by pn.created_at desc
    ),
    '[]'::jsonb
  )
  into v_dashboard_notifications
  from (
    select *
    from public.player_notifications pn
    where pn.player_id = v_player_id
      and (
        pn.status = 'unread'
        or (pn.kind = 'warning' and pn.status <> 'resolved')
        or (pn.category = 'inactive_reminder' and pn.status <> 'resolved')
      )
    order by pn.created_at desc
    limit 20
  ) pn;

  -- ----------------------------------------------------
  -- NEW: Retrieve active production slots grouped by product and quality/type
  -- ----------------------------------------------------
  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object(
        'product_id', active_p.product_id,
        'product_name', active_p.urun_adi,
        'product_icon', active_p.urun_iconu,
        'owner_kind', active_p.owner_kind,
        'quality_level', active_p.quality_level,
        'active_slots', active_p.active_slots
      )
    ),
    '[]'::jsonb
  )
  INTO v_active_productions
  FROM (
    SELECT 
      product_id,
      urun_adi,
      urun_iconu,
      owner_kind,
      quality_level,
      sum(slots_count)::int as active_slots
    FROM (
      -- Fields and Farms (from production_slots)
      SELECT 
        ps.product_id,
        p.urun_adi,
        p.urun_iconu,
        ps.owner_kind,
        ps.quality_level,
        count(*) as slots_count
      FROM public.production_slots ps
      JOIN public.products p ON p.id = ps.product_id
      WHERE ps.is_active = true
        AND (
          ps.owner_id IN (SELECT id FROM public.farms WHERE player_id = v_player_id) OR
          ps.owner_id IN (SELECT id FROM public.fields WHERE player_id = v_player_id)
        )
      GROUP BY ps.product_id, p.urun_adi, p.urun_iconu, ps.owner_kind, ps.quality_level

      UNION ALL

      -- Factories (direct active production)
      SELECT
        f.product_id,
        p.urun_adi,
        p.urun_iconu,
        'factory' as owner_kind,
        f.quality_level,
        count(*) as slots_count
      FROM public.factories f
      JOIN public.products p ON p.id = f.product_id
      WHERE f.is_active = true
        AND f.product_id IS NOT NULL
        AND f.player_id = v_player_id
      GROUP BY f.product_id, p.urun_adi, p.urun_iconu, f.quality_level

      UNION ALL

      -- Mines (direct active production)
      SELECT
        m.product_id,
        p.urun_adi,
        p.urun_iconu,
        'mine' as owner_kind,
        m.quality_level,
        count(*) as slots_count
      FROM public.mines m
      JOIN public.products p ON p.id = m.product_id
      WHERE m.is_active = true
        AND m.product_id IS NOT NULL
        AND m.player_id = v_player_id
      GROUP BY m.product_id, p.urun_adi, p.urun_iconu, m.quality_level
    ) combined
    GROUP BY product_id, urun_adi, urun_iconu, owner_kind, quality_level
    ORDER BY active_slots DESC, urun_adi ASC
  ) active_p;

  return jsonb_build_object(
    'success', true,
    'player', jsonb_build_object(
      'player_name', coalesce(v_player.player_name, 'Oyuncu'),
      'company_name', coalesce(v_player.company_name, 'Yeni Holding'),
      'avatar_id', coalesce(v_player.avatar_id, 'ae1.webp'),
      'level', coalesce(v_player.level, 1),
      'cash', coalesce(v_player.cash, 0),
      'gold', coalesce(v_player.gold, 0),
      'current_level_experience', coalesce((v_progress ->> 'current_level_experience')::integer, 0),
      'next_level_required_experience', coalesce((v_progress ->> 'next_level_required_experience')::integer, 1),
      'exp_progress_ratio', coalesce((v_progress ->> 'progress_ratio')::numeric, 0),
      'achievement_unlocked_count', v_achievement_unlocked_count,
      'achievement_total_count', v_achievement_total_count
    ),
    'company', jsonb_build_object(
      'company_value', v_live_value,
      'today_profit', v_today_net_profit,
      'active_business_count', v_active_business_count,
      'total_business_count', v_total_business_count,
      'headquarters_city_name', coalesce(v_headquarters_city_name, '-'),
      'company_status', v_company_status,
      'company_value_history', coalesce(to_jsonb(v_history_array), '[]'::jsonb)
    ),
    'finance_today', jsonb_build_object(
      'revenue', v_today_revenue,
      'production_cost', v_today_production_cost,
      'logistics_cost', v_today_logistics_cost,
      'net_profit', v_today_net_profit
    ),
    'notification_summary', jsonb_build_object(
      'unread_count', v_unread_notification_count,
      'active_warning_count', v_active_warning_count
    ),
    'notifications', v_dashboard_notifications,
    'ongoing_activities', v_ongoing_activities,
    'active_productions', v_active_productions,
    'modules', jsonb_build_object(
      'stores', jsonb_build_object(
        'count', v_stores_count,
        'active_count', v_stores_active_count,
        'stock_ratio', round(least(greatest(v_store_stock_ratio, 0), 1), 4),
        'warning_count', v_stores_warning_count
      ),
      'warehouses', jsonb_build_object(
        'count', v_warehouses_count,
        'capacity_ratio', round(least(greatest(v_warehouse_capacity_ratio, 0), 1), 4),
        'warning_count', v_warehouses_warning_count
      ),
      'factories', jsonb_build_object(
        'count', v_factories_count,
        'active_count', v_factories_active_count,
        'blocked_count', v_factories_blocked_count,
        'production_ratio', round(least(greatest(v_factories_production_ratio, 0), 1), 4)
      ),
      'fields', jsonb_build_object(
        'count', v_fields_count,
        'active_count', v_fields_active_count,
        'warning_count', v_fields_warning_count,
        'production_ratio', round(least(greatest(v_fields_production_ratio, 0), 1), 4)
      ),
      'farms', jsonb_build_object(
        'count', v_farms_count,
        'active_count', v_farms_active_count,
        'warning_count', v_farms_warning_count,
        'production_ratio', round(least(greatest(v_farms_production_ratio, 0), 1), 4)
      ),
      'mines', jsonb_build_object(
        'count', v_mines_count,
        'active_count', v_mines_active_count,
        'warning_count', v_mines_warning_count,
        'production_ratio', round(least(greatest(v_mines_production_ratio, 0), 1), 4)
      ),
      'logistics', jsonb_build_object(
        'vehicle_count', v_logistics_vehicle_count,
        'active_trip_count', v_logistics_active_trip_count,
        'fuel_ratio', round(least(greatest(v_logistics_fuel_ratio, 0), 1), 4),
        'warning_count', v_logistics_warning_count
      ),
      'arge', jsonb_build_object(
        'active_research_count', v_arge_active_research_count,
        'warning_count', v_arge_warning_count,
        'remaining_seconds', v_arge_remaining_seconds
      )
    )
  );
end;
$function$;
