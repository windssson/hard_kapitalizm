-- Migration: Remove Legacy Notification System
-- Date: 2026-09-01
-- Description: Drops legacy 14-loop alert functions, triggers, and crons while preserving player_push_tokens and register_push_token RPCs.

-- 1. Unschedule cron job if exists
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.unschedule(jobid)
    FROM cron.job
    WHERE command ILIKE '%process_push_notification_queue%';
  END IF;
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;

-- 2. Drop triggers and functions
DROP TRIGGER IF EXISTS trg_push_notification_on_insert ON public.player_notifications;
DROP FUNCTION IF EXISTS public.trg_push_notification_on_insert_func();
DROP FUNCTION IF EXISTS public.process_push_notification_queue();
DROP FUNCTION IF EXISTS public.build_player_attention_notifications(uuid);

-- 3. Truncate legacy tables
TRUNCATE TABLE public.push_notification_logs, public.push_notification_queue, public.player_notifications CASCADE;

-- 4. Update get_homepage_dashboard() without 14-loop attention builder
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
  v_today_net_profit :=
    v_today_store_profit + v_today_warehouse_sale_profit - v_today_logistics_cost;

  v_dashboard_summary := public.get_homepage_dashboard_summary(v_player_id);

  v_active_warning_count := coalesce((v_dashboard_summary ->> 'active_warning_count')::integer, 0);
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
      'title', coalesce(bc.params->>'name', bc.building_kind, 'İnşaat'),
      'subtitle', 'İnşaat',
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
      'title', coalesce(bu.params->>'name', bu.building_kind, 'Yükseltme'),
      'subtitle', case
        when coalesce(bu.target_level, 0) > 0
          then 'Yükseltme Lv.' || bu.target_level::text
        else 'Yükseltme'
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
      'subtitle', 'Araştırma Q' || ar.current_quality::text || ' -> Q' || ar.target_quality::text,
      'started_at', ar.started_at,
      'finish_at', ar.finish_at
    ) as activity_row
    from public.arge_researches ar
    where ar.player_id = v_player_id
      and ar.status = 'in_progress'
      and ar.finish_at > timezone('utc', now())

    union all

    select jsonb_build_object(
      'id', lt.id,
      'type', 'logistics',
      'kind', 'transfer',
      'title', coalesce(p.urun_adi, 'Sevkiyat'),
      'subtitle', 'Lojistik',
      'started_at', lt.started_at,
      'finish_at', lt.finish_at
    ) as activity_row
    from public.logistics_transfers lt
    left join public.products p on p.id = lt.product_id
    where (lt.buyer_player_id = v_player_id or lt.seller_player_id = v_player_id)
      and lt.status = 'in_transit'
      and lt.finish_at > timezone('utc', now())
  ) combined_activities;

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
        1 as quality_level,
        count(*) as slots_count
      FROM public.mines m
      JOIN public.products p ON p.id = m.product_id
      WHERE m.is_active = true
        AND m.product_id IS NOT NULL
        AND m.player_id = v_player_id
      GROUP BY m.product_id, p.urun_adi, p.urun_iconu
    ) sub_active
    GROUP BY product_id, urun_adi, urun_iconu, owner_kind, quality_level
  ) active_p;

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
      'unread_count', 0,
      'active_warning_count', 0
    ),
    'notifications', '[]'::jsonb,
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
