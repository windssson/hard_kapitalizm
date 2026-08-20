-- Fix Homepage Daily Net Profit Calculation
-- Problem: Production cost of unsold inventory (factory, field, farm, mine) was deducted directly from today's profit.
-- Since produced items remain in player inventory as assets (and their cost is already deducted as COGS when sold),
-- deducting total production cost caused active producers to always show a massive loss (Bugunku Zarar).
-- Solution: Daily Net Profit = Realized Store Profit + Realized Wholesale Market Profit - Logistics Expenses.

CREATE OR REPLACE FUNCTION public.get_homepage_dashboard()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_player_id uuid := auth.uid();
  v_player public.players%rowtype;
  v_today date := timezone('Europe/Istanbul', now())::date;
  v_progress jsonb := '{}'::jsonb;
  v_company_value_data jsonb := '{}'::jsonb;
  v_company_value_num numeric := 0;
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
  v_dashboard_summary jsonb := '{}'::jsonb;
  v_history_array numeric[] := array[]::numeric[];
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

  -- 1. Canlı ve Net Şirket Değeri Hesaplaması
  v_company_value_data := public.calculate_player_company_value(v_player_id);
  v_company_value_num := coalesce((v_company_value_data ->> 'total_company_value')::numeric, 0);

  -- Başarımları getir
  select
    coalesce(count(*) filter (where pa.is_unlocked = true), 0),
    coalesce(count(*), 0)
  into
    v_achievement_unlocked_count,
    v_achievement_total_count
  from public.player_achievements pa
  join public.achievement_definitions ad on ad.id = pa.achievement_id
  where pa.player_id = v_player_id
    and ad.is_active = true;

  -- 7 Günlük Şirket Değeri Geçmişini Topla (Sparkline için)
  select coalesce(array_agg(company_val), array[]::numeric[])
  into v_history_array
  from (
    select company_value as company_val, history_date
    from (
      select company_value, history_date
      from public.player_company_value_history
      where player_id = v_player_id
      order by history_date desc
      limit 6
    ) sub_h
    union all
    select v_company_value_num as company_val, v_today as history_date
    order by history_date asc
  ) hist_ordered;

  -- Dashboard bildirimlerini oluştur
  perform public.build_player_attention_notifications(v_player_id);

  v_progress := public.build_level_progress_payload(
    coalesce(v_player.level, 1),
    coalesce(v_player.experience, 0)
  );

  -- Headquarters şehri bul
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
    join public.cities c on c.id = f.city_id
    where f.player_id = v_player_id
    union all
    select c.name as city_name, m.created_at
    from public.mines m
    join public.cities c on c.id = m.city_id
    where m.player_id = v_player_id
    union all
    select c.name as city_name, lc.created_at
    from public.logistics_companies lc
    join public.cities c on c.id = lc.city_id
    where lc.player_id = v_player_id
  ) city_pick
  order by created_at asc
  limit 1;

  -- 2. Mağaza Satış Gelir ve Kârı (Europe/Istanbul gününe göre)
  select
    coalesce(sum(sdp.revenue), 0),
    coalesce(sum(sdp.profit), 0)
  into
    v_today_revenue,
    v_today_store_profit
  from public.store_daily_performance sdp
  where sdp.player_id = v_player_id
    and sdp.performance_date = v_today;

  -- Toptan Depo Satış Gelir ve Kârı
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
    and lt.started_at >= date_trunc('day', timezone('Europe/Istanbul', now()))
    and lt.started_at < date_trunc('day', timezone('Europe/Istanbul', now())) + interval '1 day';

  v_today_warehouse_sale_profit :=
    v_today_warehouse_sale_revenue - v_today_warehouse_sale_cost;

  v_today_revenue := v_today_revenue + v_today_warehouse_sale_revenue;

  -- Üretim Maliyetleri (Europe/Istanbul gününe göre - İstatistik & Raporlama için)
  select coalesce(sum(total_cost), 0)
  into v_today_production_cost
  from public.player_daily_production_stats
  where player_id = v_player_id
    and production_date = v_today;

  -- Lojistik Giderleri
  select coalesce(sum(abs(lfe.amount)), 0)
  into v_today_logistics_cost
  from public.logistics_finance_entries lfe
  where lfe.player_id = v_player_id
    and lfe.entry_type = 'expense'
    and lfe.created_at >= date_trunc('day', timezone('Europe/Istanbul', now()))
    and lfe.created_at < date_trunc('day', timezone('Europe/Istanbul', now())) + interval '1 day';

  -- 3. Net Kâr = Gerçekleşen Satış Kârı (Mağaza Kârı + Depo Toptan Satış Kârı) - Operasyonel Giderler (Lojistik)
  -- NOT: Üretim maliyeti (v_today_production_cost), satılmamış envanter mallarının varlık üretimidir (nakit -> stok dönüşümü).
  -- Satılan ürünlerin maliyeti (COGS) zaten mağaza ve toptan satış kârlarının içinde düşülmüştür.
  v_today_net_profit :=
    v_today_store_profit + v_today_warehouse_sale_profit - v_today_logistics_cost;

  v_dashboard_summary := public.get_homepage_dashboard_summary(v_player_id);

  v_active_warning_count := coalesce((v_dashboard_summary ->> 'active_warning_count')::integer, 0);
  v_unread_notification_count := coalesce((v_dashboard_summary ->> 'unread_notification_count')::integer, 0);
  v_active_business_count := coalesce((v_dashboard_summary ->> 'active_business_count')::integer, 0);
  v_total_business_count := coalesce((v_dashboard_summary ->> 'total_business_count')::integer, 0);
  v_stores_count := coalesce((v_dashboard_summary ->> 'stores_count')::integer, 0);
  v_stores_active_count := coalesce((v_dashboard_summary ->> 'stores_active_count')::integer, 0);
  v_stores_warning_count := coalesce((v_dashboard_summary ->> 'stores_warning_count')::integer, 0);
  v_store_stock_ratio := coalesce((v_dashboard_summary ->> 'store_stock_ratio')::numeric, 0);
  v_warehouses_count := coalesce((v_dashboard_summary ->> 'warehouses_count')::integer, 0);
  v_warehouses_warning_count := coalesce((v_dashboard_summary ->> 'warehouses_warning_count')::integer, 0);
  v_warehouse_capacity_ratio := coalesce((v_dashboard_summary ->> 'warehouse_capacity_ratio')::numeric, 0);
  v_factories_count := coalesce((v_dashboard_summary ->> 'factories_count')::integer, 0);
  v_factories_active_count := coalesce((v_dashboard_summary ->> 'factories_active_count')::integer, 0);
  v_factories_blocked_count := coalesce((v_dashboard_summary ->> 'factories_blocked_count')::integer, 0);
  v_factories_production_ratio := coalesce((v_dashboard_summary ->> 'factories_production_ratio')::numeric, 0);
  v_fields_count := coalesce((v_dashboard_summary ->> 'fields_count')::integer, 0);
  v_fields_active_count := coalesce((v_dashboard_summary ->> 'fields_active_count')::integer, 0);
  v_fields_warning_count := coalesce((v_dashboard_summary ->> 'fields_warning_count')::integer, 0);
  v_fields_production_ratio := coalesce((v_dashboard_summary ->> 'fields_production_ratio')::numeric, 0);
  v_farms_count := coalesce((v_dashboard_summary ->> 'farms_count')::integer, 0);
  v_farms_active_count := coalesce((v_dashboard_summary ->> 'farms_active_count')::integer, 0);
  v_farms_warning_count := coalesce((v_dashboard_summary ->> 'farms_warning_count')::integer, 0);
  v_farms_production_ratio := coalesce((v_dashboard_summary ->> 'farms_production_ratio')::numeric, 0);
  v_mines_count := coalesce((v_dashboard_summary ->> 'mines_count')::integer, 0);
  v_mines_active_count := coalesce((v_dashboard_summary ->> 'mines_active_count')::integer, 0);
  v_mines_warning_count := coalesce((v_dashboard_summary ->> 'mines_warning_count')::integer, 0);
  v_mines_production_ratio := coalesce((v_dashboard_summary ->> 'mines_production_ratio')::numeric, 0);
  v_logistics_vehicle_count := coalesce((v_dashboard_summary ->> 'logistics_vehicle_count')::integer, 0);
  v_logistics_active_trip_count := coalesce((v_dashboard_summary ->> 'logistics_active_trip_count')::integer, 0);
  v_logistics_warning_count := coalesce((v_dashboard_summary ->> 'logistics_warning_count')::integer, 0);
  v_logistics_fuel_ratio := coalesce((v_dashboard_summary ->> 'logistics_fuel_ratio')::numeric, 0);
  v_arge_active_research_count := coalesce((v_dashboard_summary ->> 'arge_active_research_count')::integer, 0);
  v_arge_remaining_seconds := coalesce((v_dashboard_summary ->> 'arge_remaining_seconds')::integer, 0);
  v_arge_warning_count := coalesce((v_dashboard_summary ->> 'arge_warning_count')::integer, 0);

  if v_active_warning_count >= 5 then
    v_company_status := 'kritik';
  elsif v_active_warning_count >= 2 then
    v_company_status := 'dikkat';
  else
    v_company_status := 'istikrarli';
  end if;

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
      'kind', bu.target_entity_kind,
      'title', coalesce(bu.params->>'name', bu.target_entity_kind, 'Yukseltme'),
      'subtitle', 'Yukseltme',
      'started_at', bu.started_at,
      'finish_at', bu.finish_at
    ) as activity_row
    from public.building_upgrades bu
    where bu.player_id = v_player_id
      and bu.status = 'in_progress'
      and bu.finish_at > timezone('utc', now())

    union all

    select jsonb_build_object(
      'id', lt.id,
      'type', 'logistics',
      'kind', 'transfer',
      'title', coalesce(lt.driver_name, 'Sevkiyat'),
      'subtitle', 'Lojistik',
      'started_at', lt.started_at,
      'finish_at', lt.finish_at
    ) as activity_row
    from public.logistics_transfers lt
    where (lt.player_id = v_player_id or lt.seller_player_id = v_player_id)
      and lt.status = 'in_transit'
      and lt.finish_at > timezone('utc', now())
  ) combined_activities;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', pan.id,
        'notification_type', pan.notification_type,
        'title', pan.title,
        'message', pan.message,
        'priority', pan.priority,
        'action_route', pan.action_route,
        'is_read', pan.is_read,
        'created_at', pan.created_at
      )
      order by
        case pan.priority
          when 'critical' then 1
          when 'warning' then 2
          else 3
        end asc,
        pan.created_at desc
    ),
    '[]'::jsonb
  )
  into v_dashboard_notifications
  from public.player_attention_notifications pan
  where pan.player_id = v_player_id
    and pan.is_dismissed = false
    and pan.created_at >= (timezone('utc', now()) - interval '7 days');

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', prod.id,
        'facility_kind', prod.facility_kind,
        'facility_name', prod.facility_name,
        'product_id', prod.product_id,
        'product_name', prod.product_name,
        'icon', prod.icon,
        'started_at', prod.started_at,
        'finish_at', prod.finish_at,
        'remaining_seconds', greatest(0, floor(extract(epoch from (prod.finish_at - timezone('utc', now()))))::integer)
      )
      order by prod.finish_at asc
    ),
    '[]'::jsonb
  )
  into v_active_productions
  from (
    select
      f.id,
      'factory' as facility_kind,
      f.name as facility_name,
      f.active_recipe_id as product_id,
      p.name as product_name,
      p.icon,
      f.production_started_at as started_at,
      f.production_finish_at as finish_at
    from public.factories f
    left join public.products p on p.id = f.active_recipe_id
    where f.player_id = v_player_id
      and f.production_finish_at is not null
      and f.production_finish_at > timezone('utc', now())

    union all

    select
      fl.id,
      'field' as facility_kind,
      fl.name as facility_name,
      fl.crop_product_id as product_id,
      p.name as product_name,
      p.icon,
      fl.planted_at as started_at,
      fl.harvest_at as finish_at
    from public.fields fl
    left join public.products p on p.id = fl.crop_product_id
    where fl.player_id = v_player_id
      and fl.harvest_at is not null
      and fl.harvest_at > timezone('utc', now())

    union all

    select
      fm.id,
      'farm' as facility_kind,
      fm.name as facility_name,
      fm.animal_product_id as product_id,
      p.name as product_name,
      p.icon,
      fm.cycle_started_at as started_at,
      fm.cycle_finish_at as finish_at
    from public.farms fm
    left join public.products p on p.id = fm.animal_product_id
    where fm.player_id = v_player_id
      and fm.cycle_finish_at is not null
      and fm.cycle_finish_at > timezone('utc', now())

    union all

    select
      m.id,
      'mine' as facility_kind,
      m.name as facility_name,
      m.resource_product_id as product_id,
      p.name as product_name,
      p.icon,
      m.extraction_started_at as started_at,
      m.extraction_finish_at as finish_at
    from public.mines m
    left join public.products p on p.id = m.resource_product_id
    where m.player_id = v_player_id
      and m.extraction_finish_at is not null
      and m.extraction_finish_at > timezone('utc', now())
  ) prod;

  return jsonb_build_object(
    'success', true,
    'player', jsonb_build_object(
      'id', v_player.id,
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
      'company_value', v_company_value_num,
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
