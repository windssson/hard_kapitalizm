-- Migration: Purge Legacy Notification Tables and All References
-- Date: 2026-09-01
-- Description: Removes all lingering INSERT/DELETE references to player_notifications and drops the 3 legacy tables.

-- 1. Drop obsolete triggers
DROP TRIGGER IF EXISTS trg_building_constructions_notifications ON public.building_constructions;
DROP TRIGGER IF EXISTS trg_building_upgrades_notifications ON public.building_upgrades;
DROP TRIGGER IF EXISTS trg_arge_researches_notifications ON public.arge_researches;
DROP TRIGGER IF EXISTS trg_logistics_transfers_notifications ON public.logistics_transfers;
DROP TRIGGER IF EXISTS trg_send_push_notification_on_log_insert ON public.push_notification_logs;

-- 2. Drop obsolete trigger functions
DROP FUNCTION IF EXISTS public.handle_building_construction_notification();
DROP FUNCTION IF EXISTS public.handle_building_upgrade_notification();
DROP FUNCTION IF EXISTS public.handle_arge_research_notification();
DROP FUNCTION IF EXISTS public.handle_logistics_transfer_notification();
DROP FUNCTION IF EXISTS public.trg_send_push_notification_on_log_insert_func();

-- 3. Drop obsolete RPCs
DROP FUNCTION IF EXISTS public.mark_notification_read(uuid);
DROP FUNCTION IF EXISTS public.mark_all_notifications_read();
DROP FUNCTION IF EXISTS public.create_player_notification;
DROP FUNCTION IF EXISTS public.get_player_notifications;
DROP FUNCTION IF EXISTS public.refresh_player_attention_notifications();

-- 4. Update get_homepage_dashboard_summary without player_notifications table
CREATE OR REPLACE FUNCTION public.get_homepage_dashboard_summary(p_player_id uuid)
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  WITH notification_metrics AS (
    SELECT
      0::integer AS active_warning_count,
      0::integer AS unread_count,
      0::integer AS stores_warning_count,
      0::integer AS warehouses_warning_count,
      0::integer AS factories_blocked_count,
      0::integer AS fields_warning_count,
      0::integer AS farms_warning_count,
      0::integer AS mines_warning_count,
      0::integer AS logistics_warning_count,
      0::integer AS arge_warning_count
  ),
  business_rows AS MATERIALIZED (
    SELECT 'store'::text AS kind, is_active FROM public.stores WHERE player_id = p_player_id
    UNION ALL
    SELECT 'warehouse', is_active FROM public.warehouses WHERE player_id = p_player_id
    UNION ALL
    SELECT 'factory', is_active FROM public.factories WHERE player_id = p_player_id
    UNION ALL
    SELECT 'field', is_active FROM public.fields WHERE player_id = p_player_id
    UNION ALL
    SELECT 'farm', is_active FROM public.farms WHERE player_id = p_player_id
    UNION ALL
    SELECT 'mine', is_active FROM public.mines WHERE player_id = p_player_id
    UNION ALL
    SELECT 'logistics', is_active FROM public.logistics_companies WHERE player_id = p_player_id
    UNION ALL
    SELECT 'arge', is_active FROM public.arge_centers WHERE player_id = p_player_id
  ),
  business_metrics AS MATERIALIZED (
    SELECT
      count(*)::integer AS total_business_count,
      count(*) FILTER (WHERE is_active = true)::integer AS active_business_count,
      count(*) FILTER (WHERE kind = 'store')::integer AS stores_count,
      count(*) FILTER (WHERE kind = 'store' AND is_active = true)::integer AS stores_active_count,
      count(*) FILTER (WHERE kind = 'warehouse')::integer AS warehouses_count,
      count(*) FILTER (WHERE kind = 'factory')::integer AS factories_count,
      count(*) FILTER (WHERE kind = 'factory' AND is_active = true)::integer AS factories_active_count,
      count(*) FILTER (WHERE kind = 'field')::integer AS fields_count,
      count(*) FILTER (WHERE kind = 'field' AND is_active = true)::integer AS fields_active_count,
      count(*) FILTER (WHERE kind = 'farm')::integer AS farms_count,
      count(*) FILTER (WHERE kind = 'farm' AND is_active = true)::integer AS farms_active_count,
      count(*) FILTER (WHERE kind = 'mine')::integer AS mines_count,
      count(*) FILTER (WHERE kind = 'mine' AND is_active = true)::integer AS mines_active_count
    FROM business_rows
  ),
  inventory_output AS MATERIALIZED (
    SELECT
      owner_kind,
      owner_id,
      sum(coalesce(quantity, 0) + coalesce(pending_quantity, 0)) AS used_output
    FROM public.production_inventory
    WHERE inventory_type = 'output'
      AND owner_kind IN ('factory', 'field', 'farm', 'mine')
    GROUP BY owner_kind, owner_id
  ),
  store_metrics AS MATERIALIZED (
    SELECT coalesce(
      sum(greatest(coalesce(ss.quantity, 0) + coalesce(ss.pending_quantity, 0), 0))::numeric
        / nullif(sum(greatest(coalesce(ss.capacity, 0), 0)), 0),
      0
    ) AS stock_ratio
    FROM public.store_slots ss
    JOIN public.stores s ON s.id = ss.store_id
    WHERE s.player_id = p_player_id
      AND s.is_active = true
      AND ss.is_active = true
  ),
  warehouse_metrics AS MATERIALIZED (
    SELECT coalesce(
      sum(greatest(coalesce(ws.quantity, 0), 0)::numeric * coalesce(p.birim_hacim, 0))
        / nullif(sum(greatest(coalesce(w.capacity, 0), 0)), 0),
      0
    ) AS capacity_ratio
    FROM public.warehouses w
    LEFT JOIN public.warehouse_slots ws ON ws.warehouse_id = w.id
    LEFT JOIN public.products p ON p.id = ws.product_id
    WHERE w.player_id = p_player_id
      AND w.is_active = true
  ),
  factory_metrics AS MATERIALIZED (
    SELECT coalesce(
      sum(least(
        coalesce(io.used_output, 0)::numeric
          / nullif(greatest(coalesce(f.output_capacity, 0), 0), 0),
        1
      )) / nullif(count(*), 0),
      0
    ) AS production_ratio
    FROM public.factories f
    LEFT JOIN inventory_output io
      ON io.owner_kind = 'factory' AND io.owner_id = f.id
    WHERE f.player_id = p_player_id
      AND f.is_active = true
      AND f.output_capacity > 0
  ),
  field_metrics AS MATERIALIZED (
    SELECT coalesce(
      sum(least(
        coalesce(io.used_output, 0)::numeric
          / nullif(greatest(coalesce(f.output_capacity, 0), 0), 0),
        1
      )) / nullif(count(*), 0),
      0
    ) AS production_ratio
    FROM public.fields f
    LEFT JOIN inventory_output io
      ON io.owner_kind = 'field' AND io.owner_id = f.id
    WHERE f.player_id = p_player_id
      AND f.is_active = true
      AND f.output_capacity > 0
  ),
  farm_metrics AS MATERIALIZED (
    SELECT coalesce(
      sum(least(
        coalesce(io.used_output, 0)::numeric
          / nullif(greatest(coalesce(f.output_capacity, 0), 0), 0),
        1
      )) / nullif(count(*), 0),
      0
    ) AS production_ratio
    FROM public.farms f
    LEFT JOIN inventory_output io
      ON io.owner_kind = 'farm' AND io.owner_id = f.id
    WHERE f.player_id = p_player_id
      AND f.is_active = true
      AND f.output_capacity > 0
  ),
  mine_metrics AS MATERIALIZED (
    SELECT coalesce(
      sum(least(
        coalesce(io.used_output, 0)::numeric
          / nullif(greatest(coalesce(m.output_capacity, 0), 0), 0),
        1
      )) / nullif(count(*), 0),
      0
    ) AS production_ratio
    FROM public.mines m
    LEFT JOIN inventory_output io
      ON io.owner_kind = 'mine' AND io.owner_id = m.id
    WHERE m.player_id = p_player_id
      AND m.is_active = true
      AND m.output_capacity > 0
  ),
  logistics_metrics AS MATERIALIZED (
    SELECT
      count(*)::integer AS vehicle_count,
      coalesce(
        sum(greatest(coalesce(current_fuel, 0), 0))::numeric
          / nullif(sum(greatest(coalesce(fuel_capacity, 0), 0)), 0),
        0
      ) AS fuel_ratio
    FROM public.logistics_vehicles
    WHERE player_id = p_player_id
  ),
  trip_metrics AS MATERIALIZED (
    SELECT count(*)::integer AS active_trip_count
    FROM public.logistics_transfers lt
    JOIN public.logistics_vehicles lv ON lv.id = lt.logistics_vehicle_id
    WHERE lv.player_id = p_player_id
      AND lt.status = 'in_transit'
  ),
  arge_metrics AS MATERIALIZED (
    SELECT
      count(*)::integer AS active_research_count,
      coalesce(
        min(greatest(
          extract(epoch FROM (finish_at - timezone('utc', now())))::integer,
          0
        )),
        0
      ) AS remaining_seconds
    FROM public.arge_researches
    WHERE player_id = p_player_id
      AND status = 'in_progress'
  )
  SELECT jsonb_build_object(
    'active_warning_count', n.active_warning_count,
    'unread_notification_count', n.unread_count,
    'active_business_count', b.active_business_count,
    'total_business_count', b.total_business_count,
    'stores_count', b.stores_count,
    'stores_active_count', b.stores_active_count,
    'stores_warning_count', n.stores_warning_count,
    'store_stock_ratio', s.stock_ratio,
    'warehouses_count', b.warehouses_count,
    'warehouses_warning_count', n.warehouses_warning_count,
    'warehouse_capacity_ratio', w.capacity_ratio,
    'factories_count', b.factories_count,
    'factories_active_count', b.factories_active_count,
    'factories_blocked_count', n.factories_blocked_count,
    'factories_production_ratio', fx.production_ratio,
    'fields_count', b.fields_count,
    'fields_active_count', b.fields_active_count,
    'fields_warning_count', n.fields_warning_count,
    'fields_production_ratio', fld.production_ratio,
    'farms_count', b.farms_count,
    'farms_active_count', b.farms_active_count,
    'farms_warning_count', n.farms_warning_count,
    'farms_production_ratio', frm.production_ratio,
    'mines_count', b.mines_count,
    'mines_active_count', b.mines_active_count,
    'mines_warning_count', n.mines_warning_count,
    'mines_production_ratio', mn.production_ratio,
    'logistics_vehicle_count', l.vehicle_count,
    'logistics_active_trip_count', t.active_trip_count,
    'logistics_warning_count', n.logistics_warning_count,
    'logistics_fuel_ratio', l.fuel_ratio,
    'arge_active_research_count', a.active_research_count,
    'arge_remaining_seconds', a.remaining_seconds,
    'arge_warning_count', n.arge_warning_count
  )
  FROM notification_metrics n
  CROSS JOIN business_metrics b
  CROSS JOIN store_metrics s
  CROSS JOIN warehouse_metrics w
  CROSS JOIN factory_metrics fx
  CROSS JOIN field_metrics fld
  CROSS JOIN farm_metrics frm
  CROSS JOIN mine_metrics mn
  CROSS JOIN logistics_metrics l
  CROSS JOIN trip_metrics t
  CROSS JOIN arge_metrics a;
$function$;

-- 5. Update cleanup_database_bloat
CREATE OR REPLACE FUNCTION public.cleanup_database_bloat()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_deleted_cron integer := 0;
  v_deleted_expired_tenders integer := 0;
BEGIN
  -- A. 3 günden eski pg_cron çalıştırma loglarını temizle
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    BEGIN
      DELETE FROM cron.job_run_details
      WHERE start_time < timezone('utc'::text, now()) - interval '3 days';
      GET DIAGNOSTICS v_deleted_cron = ROW_COUNT;
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END IF;

  -- B. Teklifsiz ve sahipsiz 24 saatten eski süresi dolmuş ihaleleri temizle
  DELETE FROM public.tenders t
  WHERE t.status = 'expired'
    AND t.updated_at < timezone('utc'::text, now()) - interval '24 hours'
    AND NOT EXISTS (
      SELECT 1 FROM public.tender_bids tb WHERE tb.tender_id = t.id
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.player_tenders pt WHERE pt.tender_id = t.id
    );
  GET DIAGNOSTICS v_deleted_expired_tenders = ROW_COUNT;

  RETURN jsonb_build_object(
    'success', true,
    'deleted_cron_logs', v_deleted_cron,
    'deleted_expired_tenders', v_deleted_expired_tenders,
    'cleaned_at', timezone('utc'::text, now())
  );
END;
$function$;

-- 6. Update delete_own_account
CREATE OR REPLACE FUNCTION public.delete_own_account()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $function$
DECLARE
  v_user_id uuid;
  v_npc_id uuid;
BEGIN
  -- 1. Get authenticated user ID
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Oturum açılmamış.');
  END IF;

  -- 2. Ensure NPC logistics account exists for transfer handoff
  v_npc_id := public.get_npc_logistics_player_id();

  -- 3. Clean up personal push tokens
  DELETE FROM public.player_push_tokens WHERE player_id = v_user_id;

  -- 4. Hand off in-transit transfers to NPC to protect buyer's cargo & economy integrity
  UPDATE public.logistics_transfers
  SET seller_player_id = v_npc_id
  WHERE seller_player_id = v_user_id AND status = 'in_transit';

  UPDATE public.logistics_transfers
  SET vehicle_owner_player_id = v_npc_id
  WHERE vehicle_owner_player_id = v_user_id AND status = 'in_transit';

  -- 5. Close market listings (prevent ghost purchases)
  UPDATE public.warehouse_slots
  SET is_available_for_sale = false, price = 0
  WHERE warehouse_id IN (SELECT id FROM public.warehouses WHERE player_id = v_user_id);

  -- 6. Decommission player-owned facilities & free city real estate
  UPDATE public.factories SET is_active = false WHERE player_id = v_user_id;
  UPDATE public.fields SET is_active = false WHERE player_id = v_user_id;
  UPDATE public.farms SET is_active = false WHERE player_id = v_user_id;
  UPDATE public.mines SET is_active = false WHERE player_id = v_user_id;
  UPDATE public.warehouses SET is_active = false WHERE player_id = v_user_id;
  UPDATE public.stores SET is_active = false WHERE player_id = v_user_id;
  UPDATE public.logistics_companies SET is_active = false WHERE player_id = v_user_id;
  UPDATE public.logistics_vehicles SET status = 'decommissioned', is_available_for_rent = false WHERE player_id = v_user_id;
  UPDATE public.arge_centers SET is_active = false WHERE player_id = v_user_id;
  UPDATE public.brand_companies SET is_active = false WHERE player_id = v_user_id;

  -- 7. Liquidate ongoing constructions, upgrades and active bank products
  DELETE FROM public.building_boosts WHERE player_id = v_user_id;
  DELETE FROM public.building_upgrades WHERE player_id = v_user_id;
  DELETE FROM public.building_constructions WHERE player_id = v_user_id;
  DELETE FROM public.tender_bids WHERE player_id = v_user_id;

  UPDATE public.player_loans
  SET status = 'liquidated'
  WHERE player_id = v_user_id;

  UPDATE public.player_deposits
  SET status = 'liquidated'
  WHERE player_id = v_user_id;

  -- 8. Anonymize world player profile
  UPDATE public.players
  SET
    player_name = 'Eski Oyuncu',
    company_name = 'Tasfiye Edilmiş Holding',
    google_email = NULL,
    google_avatar_url = NULL,
    avatar_id = 'ae1.webp',
    cash = 0,
    gold = 0,
    last_seen_at = NULL
  WHERE id = v_user_id;

  -- 9. Permanently delete auth.users identity record
  DELETE FROM auth.users WHERE id = v_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Hesabınız ve kişisel verileriniz başarıyla silindi. Şirketiniz tasfiye edildi.'
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'message', format('Hesap silinirken hata oluştu: %s', SQLERRM));
END;
$function$;

-- 7. Update process_all_players_production (remove build_player_attention_notifications)
CREATE OR REPLACE FUNCTION public.process_all_players_production()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_player_row record;
  v_processed_count integer := 0;
  v_failed_count integer := 0;
  v_boosts_result jsonb;
  v_upgrades_result jsonb;
BEGIN
  v_boosts_result := public.complete_due_building_boosts(1000);
  v_upgrades_result := public.complete_due_building_upgrades(1000);

  FOR v_player_row IN
    SELECT id
    FROM public.players
  LOOP
    BEGIN
      PERFORM public.process_player_production_core(v_player_row.id);
      v_processed_count := v_processed_count + 1;
    EXCEPTION WHEN OTHERS THEN
      v_failed_count := v_failed_count + 1;
    END;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'processed_players_count', v_processed_count,
    'failed_players_count', v_failed_count,
    'completed_due_building_boosts', v_boosts_result,
    'completed_due_building_upgrades', v_upgrades_result
  );
END;
$function$;

-- 8. Update process_logistics_vehicle_rental_payout (remove player_notifications insert)
CREATE OR REPLACE FUNCTION public.process_logistics_vehicle_rental_payout(p_vehicle_id uuid, p_transfer_id uuid, p_renter_player_id uuid, p_rental_cost numeric, p_distance_km numeric)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_vehicle record;
  v_npc_player_id uuid;
  v_owner_cash numeric;
BEGIN
  IF p_rental_cost IS NULL OR p_rental_cost <= 0 OR p_vehicle_id IS NULL THEN
    RETURN;
  END IF;

  v_npc_player_id := public.get_npc_logistics_player_id();

  SELECT *
  INTO v_vehicle
  FROM public.logistics_vehicles
  WHERE id = p_vehicle_id;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  IF v_vehicle.player_id IS NULL OR v_vehicle.player_id = v_npc_player_id THEN
    RETURN;
  END IF;

  IF v_vehicle.player_id = p_renter_player_id THEN
    RETURN;
  END IF;

  SELECT cash INTO v_owner_cash
  FROM public.players
  WHERE id = v_vehicle.player_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  -- 1. Araç sahibine kazancı aktar
  UPDATE public.players
  SET cash = cash + p_rental_cost
  WHERE id = v_vehicle.player_id;

  -- 2. Kasa hareketini kaydet
  PERFORM public.log_player_cash_change(
    v_vehicle.player_id,
    p_rental_cost,
    v_owner_cash,
    'vehicle_rental_income',
    format('Araç kiralama geliri: %s TL', p_rental_cost::bigint),
    v_vehicle.id,
    'logistics_vehicle'
  );

  -- 3. Lojistik şirketi finans kaydı oluştur
  IF v_vehicle.logistics_company_id IS NOT NULL THEN
    INSERT INTO public.logistics_finance_entries (
      player_id,
      logistics_company_id,
      vehicle_id,
      entry_type,
      category,
      amount,
      description,
      metadata
    ) VALUES (
      v_vehicle.player_id,
      v_vehicle.logistics_company_id,
      v_vehicle.id,
      'income',
      'rental_income',
      p_rental_cost,
      'Kiralama geliri',
      jsonb_build_object(
        'transfer_id', p_transfer_id,
        'renter_player_id', p_renter_player_id,
        'distance_km', p_distance_km,
        'rental_price', v_vehicle.rental_price
      )
    );
  END IF;
END;
$function$;

-- 9. Update start_multi_market_transfer (remove player_notifications insert)
CREATE OR REPLACE FUNCTION public.start_multi_market_transfer(p_buyer_warehouse_id uuid, p_source_city_id uuid, p_items jsonb, p_vehicle_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_default_brand uuid := '00000000-0000-0000-0000-000000000000'::uuid;
  v_player_id uuid := auth.uid();
  v_npc_logistics_player_id uuid;
  v_now timestamptz := timezone('utc', now());
  v_target_warehouse record;
  v_source_city public.cities;
  v_vehicle public.logistics_vehicles;
  v_transfer_id uuid;
  v_header_item jsonb;
  v_header_slot record;
  v_header_product public.products;
  v_header_source_kind text;
  v_header_product_id text;
  v_header_quality_level integer;
  v_header_brand_id uuid;
  v_header_seller_player_id uuid;
  v_header_seller_warehouse_id uuid;
  v_item jsonb;
  v_seller_slot record;
  v_seller_slot_id uuid;
  v_product public.products;
  v_item_source_kind text;
  v_item_product_id text;
  v_item_quality_level integer := 1;
  v_item_brand_id uuid;
  v_item_unit_price numeric := 0;
  v_item_unit_cost numeric := 0;
  v_item_unit_volume numeric := 0;
  v_item_city_id uuid;
  v_item_quantity integer := 0;
  v_item_reserved_capacity numeric := 0;
  v_target_used_capacity numeric := 0;
  v_total_volume numeric := 0;
  v_total_quantity integer := 0;
  v_total_price numeric := 0;
  v_distance_km numeric := 0;
  v_fuel_used numeric := 0;
  v_condition_loss numeric := 0;
  v_transport_cost numeric := 0;
  v_rental_cost numeric := 0;
  v_duration_seconds integer := 0;
  v_finish_at timestamptz := v_now;
  v_item_count integer := 0;
  v_same_city boolean := false;
  v_mode text := 'instant';
  v_is_rental boolean := false;
  v_buyer_cash numeric := 0;
  v_total_payment numeric := 0;
  v_buyer_name text := 'Bir Oyuncu';
begin
  if v_player_id is null then raise exception 'Oturum acilmamis.'; end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'Transfer sepeti bos olamaz.';
  end if;

  v_npc_logistics_player_id := public.get_npc_logistics_player_id();

  select coalesce(p.company_name, p.player_name, 'Bir Oyuncu')
  into v_buyer_name
  from public.players p where p.id = v_player_id;

  CREATE TEMP TABLE temp_seller_totals ON COMMIT DROP AS
  select
    case when coalesce(v_item.value ->> 'source_kind', 'warehouse_slot') = 'npc_market' then v_npc_logistics_player_id
         else w.player_id end as seller_player_id,
    sum(
      greatest(coalesce((v_item.value ->> 'quantity')::integer, 0), 0)
      * greatest(coalesce(case when coalesce(v_item.value ->> 'source_kind', 'warehouse_slot') = 'npc_market'
          then (v_item.value ->> 'unit_price')::numeric else ws.price end, 0), 0)
    ) as seller_amount
  from jsonb_array_elements(p_items) v_item(value)
  left join public.warehouse_slots ws
    on coalesce(v_item.value ->> 'source_kind', 'warehouse_slot') <> 'npc_market'
   and ws.id = (case when coalesce(v_item.value ->> 'source_kind', 'warehouse_slot') = 'npc_market' then null
                     else nullif(v_item.value ->> 'seller_slot_id', '')::uuid end)
  left join public.warehouses w on w.id = ws.warehouse_id
  group by 1;

  select w.*, c.map_position_x, c.map_position_y
  into v_target_warehouse
  from public.warehouses w join public.cities c on c.id = w.city_id
  where w.id = p_buyer_warehouse_id and w.player_id = v_player_id and w.is_active = true
  for update;
  if not found then raise exception 'Hedef depo bulunamadi.'; end if;

  v_header_item := p_items -> 0;
  v_header_source_kind := coalesce(v_header_item ->> 'source_kind', 'warehouse_slot');

  if v_header_source_kind = 'npc_market' then
    v_header_product_id := coalesce(v_header_item ->> 'product_id', '');
    v_header_quality_level := greatest(coalesce((v_header_item ->> 'quality_level')::integer, 1), 1);
    v_header_brand_id := coalesce(nullif(v_header_item ->> 'brand_id', '')::uuid, v_default_brand);
    v_header_seller_player_id := v_npc_logistics_player_id;
    v_header_seller_warehouse_id := null;
    if coalesce(v_header_item ->> 'city_id', '') <> p_source_city_id::text then
      raise exception 'Transfer sehir kilidi ilk secilen sehir ile eslesmiyor.';
    end if;
    select * into v_header_product from public.products where id = v_header_product_id;
    if not found then raise exception 'Ilk NPC ilan urunu bulunamadi.'; end if;
  else
    select ws.*, w.id as seller_warehouse_id, w.name as seller_warehouse_name,
           w.player_id as seller_player_id, w.city_id, c.map_position_x, c.map_position_y
    into v_header_slot
    from public.warehouse_slots ws join public.warehouses w on w.id = ws.warehouse_id join public.cities c on c.id = w.city_id
    where ws.id = (v_header_item ->> 'seller_slot_id')::uuid for update;
    if not found then raise exception 'Ilk satici slotu bulunamadi.'; end if;
    if v_header_slot.seller_player_id = v_player_id then raise exception 'Kendi market ilaninizi satin alamazsiniz.'; end if;
    if v_header_slot.city_id <> p_source_city_id then raise exception 'Transfer sehir kilidi ilk secilen sehir ile eslesmiyor.'; end if;
    if coalesce(v_header_slot.product_id, '') = '' then raise exception 'Ilk ilanda urun bulunamadi.'; end if;
    select * into v_header_product from public.products where id = v_header_slot.product_id;
    if not found then raise exception 'Ilk ilan urunu bulunamadi.'; end if;
    v_header_product_id := v_header_slot.product_id;
    v_header_quality_level := greatest(coalesce(v_header_slot.quality_level, 1), 1);
    v_header_brand_id := coalesce(v_header_slot.brand_id, v_default_brand);
    v_header_seller_player_id := v_header_slot.seller_player_id;
    v_header_seller_warehouse_id := v_header_slot.seller_warehouse_id;
  end if;

  select * into v_source_city from public.cities where id = p_source_city_id;
  if not found then raise exception 'Kaynak sehir bulunamadi.'; end if;

  v_same_city := v_target_warehouse.city_id = p_source_city_id;
  if not v_same_city then v_mode := 'in_transit'; end if;

  insert into public.logistics_transfers (
    buyer_player_id, seller_player_id, buyer_warehouse_id, seller_warehouse_id,
    logistics_vehicle_id, vehicle_owner_player_id, is_rental, product_id, quality_level, quantity,
    unit_price, total_price, product_unit_volume, reserved_capacity_amount, distance_km,
    fuel_used, condition_loss, rental_cost, transport_cost, started_at, finish_at, status,
    transfer_type, seller_entity_kind, buyer_entity_kind, item_count, total_quantity, brand_id, created_at, updated_at
  ) values (
    v_player_id, v_header_seller_player_id, v_target_warehouse.id, v_header_seller_warehouse_id,
    p_vehicle_id, null, false, v_header_product_id, v_header_quality_level, 1,
    0, 0, 1, 0, 0, 0, 0, 0, 0, v_now, v_now, 'in_transit',
    'market_to_warehouse_multi',
    case when v_header_source_kind = 'npc_market' then 'npc_market' else 'warehouse' end,
    'warehouse', 1, 0, v_header_brand_id, v_now, v_now
  ) returning id into v_transfer_id;

  select coalesce(sum((ws.quantity + coalesce(ws.pending_quantity, 0)) * coalesce(p.birim_hacim, 0)), 0)
  into v_target_used_capacity
  from public.warehouse_slots ws left join public.products p on p.id = ws.product_id
  where ws.warehouse_id = v_target_warehouse.id;

  for v_item in select value from jsonb_array_elements(p_items) loop
    v_seller_slot_id := null;
    v_item_quantity := greatest(coalesce((v_item ->> 'quantity')::integer, 0), 0);
    if v_item_quantity <= 0 then raise exception 'Transfer miktari 0 dan buyuk olmalidir.'; end if;
    v_item_source_kind := coalesce(v_item ->> 'source_kind', 'warehouse_slot');
    v_item_city_id := nullif(v_item ->> 'city_id', '')::uuid;
    if v_item_city_id is null or v_item_city_id <> p_source_city_id then
      raise exception 'Sepetteki tum ilanlar ayni sehirde olmalidir.';
    end if;

    if v_item_source_kind = 'npc_market' then
      v_item_product_id := coalesce(v_item ->> 'product_id', '');
      v_item_quality_level := greatest(coalesce((v_item ->> 'quality_level')::integer, 1), 1);
      v_item_brand_id := coalesce(nullif(v_item ->> 'brand_id', '')::uuid, v_default_brand);
      v_item_unit_price := greatest(coalesce((v_item ->> 'unit_price')::numeric, 0), 0);
      v_item_unit_cost := v_item_unit_price;
      select * into v_product from public.products where id = v_item_product_id;
      if not found then raise exception 'NPC urunu bulunamadi.'; end if;
      v_item_unit_volume := coalesce((v_item ->> 'unit_volume')::numeric, coalesce(v_product.birim_hacim, 0));
      v_item_reserved_capacity := v_item_quantity * v_item_unit_volume;
    else
      select ws.*, w.id as seller_warehouse_id, w.name as seller_warehouse_name, w.player_id as seller_player_id, w.city_id
      into v_seller_slot
      from public.warehouse_slots ws join public.warehouses w on w.id = ws.warehouse_id
      where ws.id = (v_item ->> 'seller_slot_id')::uuid for update;
      if not found then raise exception 'Satici slotu bulunamadi.'; end if;
      if v_seller_slot.seller_player_id = v_player_id then raise exception 'Kendi market ilaninizi satin alamazsiniz.'; end if;
      if v_seller_slot.city_id <> p_source_city_id then raise exception 'Sepetteki tum ilanlar ayni sehirde olmalidir.'; end if;
      if coalesce(v_seller_slot.is_available_for_sale, false) = false or coalesce(v_seller_slot.price, 0) <= 0 then
        raise exception 'Secilen slot satisa uygun degil.';
      end if;
      if coalesce(v_seller_slot.quantity, 0) < v_item_quantity then raise exception 'Satici stokunda yeterli urun yok.'; end if;
      select * into v_product from public.products where id = v_seller_slot.product_id;
      if not found then raise exception 'Urun bulunamadi.'; end if;
      v_item_product_id := v_seller_slot.product_id;
      v_item_quality_level := v_seller_slot.quality_level;
      v_item_brand_id := coalesce(v_seller_slot.brand_id, v_default_brand);
      v_item_unit_price := coalesce(v_seller_slot.price, 0);
      v_item_unit_cost := v_item_unit_price;
      v_item_unit_volume := coalesce(v_product.birim_hacim, 0);
      v_item_reserved_capacity := v_item_quantity * v_item_unit_volume;
    end if;

    if v_target_used_capacity + coalesce(v_target_warehouse.reserved_capacity, 0) + v_total_volume + v_item_reserved_capacity > coalesce(v_target_warehouse.capacity, 0) then
      raise exception 'Hedef depoda yeterli kapasite yok.';
    end if;

    insert into public.logistics_transfer_items (
      transfer_id, source_warehouse_slot_id, target_warehouse_slot_id, product_id, quality_level, brand_id,
      quantity, unit_cost, unit_price, total_cost, total_price, product_unit_volume, reserved_capacity_amount,
      status, created_at, updated_at
    ) values (
      v_transfer_id, v_seller_slot_id, null, v_item_product_id, v_item_quality_level, v_item_brand_id,
      v_item_quantity, v_item_unit_cost, v_item_unit_price,
      v_item_quantity * v_item_unit_cost, v_item_quantity * v_item_unit_price,
      v_item_unit_volume, v_item_reserved_capacity, 'in_transit', v_now, v_now
    );

    if v_item_source_kind <> 'npc_market' then
      update public.warehouse_slots set quantity = quantity - v_item_quantity, updated_at = v_now where id = v_seller_slot_id;
      if coalesce(v_seller_slot.quantity, 0) - v_item_quantity <= 0 and coalesce(v_seller_slot.pending_quantity, 0) <= 0 then
        delete from public.warehouse_slots where id = v_seller_slot_id;
      end if;
    end if;

    v_item_count := v_item_count + 1;
    v_total_quantity := v_total_quantity + v_item_quantity;
    v_total_volume := v_total_volume + v_item_reserved_capacity;
    v_total_price := v_total_price + (v_item_quantity * v_item_unit_price);
  end loop;

  if v_item_count <= 0 then raise exception 'Transfer icin kalem bulunamadi.'; end if;

  if not v_same_city then
    if p_vehicle_id is null then raise exception 'Sehirler arasi transfer icin arac secilmelidir.'; end if;
    select * into v_vehicle
    from public.logistics_vehicles
    where id = p_vehicle_id 
      and (player_id = v_player_id or (coalesce(is_available_for_rent, false) = true and (player_id = v_npc_logistics_player_id or public.logistics_vehicle_matches_route(route_city_a_id, route_city_b_id, p_source_city_id, v_target_warehouse.city_id))))
      and status = 'idle'
    for update;
    if not found then raise exception 'Secilen arac kullanima uygun degil.'; end if;
    v_distance_km := round(
      (6371 * 2 * asin(sqrt(power(sin(radians(coalesce(v_target_warehouse.map_position_x, 0) - coalesce(v_source_city.map_position_x, 0)) / 2), 2) + cos(radians(coalesce(v_source_city.map_position_x, 0))) * cos(radians(coalesce(v_target_warehouse.map_position_x, 0))) * power(sin(radians(coalesce(v_target_warehouse.map_position_y, 0) - coalesce(v_source_city.map_position_y, 0)) / 2), 2))))::numeric, 2
    );
    if coalesce(v_vehicle.capacity, 0) < ceil(v_total_volume) then raise exception 'Secilen aracin kapasitesi bu transfer icin yetersiz.'; end if;
    if coalesce(v_vehicle.speed_kmh, 0) <= 0 then raise exception 'Secilen aracin hizi gecersiz.'; end if;
    v_is_rental := v_vehicle.player_id <> v_player_id;
    v_duration_seconds := greatest(60, ceil((greatest(v_distance_km, 1) / v_vehicle.speed_kmh) * 120)::integer);
    v_finish_at := v_now + make_interval(secs => v_duration_seconds);
    v_fuel_used := round(v_distance_km * coalesce(v_vehicle.fuel_rate, 0), 2);
    v_condition_loss := greatest(1, ceil(v_distance_km / 200.0));
    v_transport_cost := case when v_is_rental then round(v_distance_km * coalesce(v_vehicle.rental_price, 0), 2) else round(v_fuel_used * coalesce(v_vehicle.fuel_cost, 0), 2) end;
    v_rental_cost := case when v_is_rental then v_transport_cost else 0 end;
    if coalesce(v_vehicle.current_fuel, 0) < ceil(v_fuel_used) then raise exception 'Aracta yeterli yakit yok.'; end if;
    if coalesce(v_vehicle.condition, 0) <= 0 then raise exception 'Aracin bakimi yetersiz.'; end if;
    update public.logistics_vehicles
    set status = 'on_route', current_fuel = greatest(current_fuel - ceil(v_fuel_used), 0),
        condition = greatest(condition - ceil(v_condition_loss), 0), updated_at = v_now
    where id = v_vehicle.id;
  end if;

  v_total_payment := v_total_price + v_rental_cost;

  select cash into v_buyer_cash from public.players where id = v_player_id for update;
  if coalesce(v_buyer_cash, 0) < v_total_payment then raise exception 'Yeterli nakit yok.'; end if;

  update public.players set cash = cash - v_total_payment where id = v_player_id;
  perform public.log_player_cash_change(
    v_player_id, -v_total_payment, v_buyer_cash, 'market_purchase',
    format('Pazar alimi: %s kalem, %s adet (nakliye: %s TL)', v_item_count, v_total_quantity, round(v_rental_cost + v_transport_cost, 0)),
    v_transfer_id, 'logistics_transfer'
  );

  update public.players p
  set cash = cash + st.seller_amount
  from temp_seller_totals st
  where p.id = st.seller_player_id and st.seller_player_id is not null and coalesce(st.seller_amount, 0) > 0;

  perform public.log_player_cash_change(
    st.seller_player_id, st.seller_amount,
    (select cash - st.seller_amount from public.players where id = st.seller_player_id),
    'market_sale', format('Pazar satisi: %s TL', round(st.seller_amount, 0)), v_transfer_id, 'logistics_transfer'
  )
  from temp_seller_totals st
  where st.seller_player_id is not null and st.seller_player_id <> v_npc_logistics_player_id and coalesce(st.seller_amount, 0) > 0;

  if v_is_rental and v_rental_cost > 0 then
    perform public.process_logistics_vehicle_rental_payout(p_vehicle_id, v_transfer_id, v_player_id, v_rental_cost, v_distance_km);
  end if;

  update public.warehouses set reserved_capacity = coalesce(reserved_capacity, 0) + v_total_volume, updated_at = v_now where id = v_target_warehouse.id;

  update public.logistics_transfers
  set logistics_vehicle_id = p_vehicle_id,
      vehicle_owner_player_id = case when p_vehicle_id is not null then v_vehicle.player_id else null end,
      is_rental = v_is_rental, quantity = greatest(v_total_quantity, 1), total_price = v_total_price,
      product_unit_volume = greatest(v_total_volume, 0.0001), reserved_capacity_amount = v_total_volume,
      distance_km = v_distance_km, fuel_used = v_fuel_used, condition_loss = v_condition_loss,
      rental_cost = v_rental_cost, transport_cost = v_transport_cost, finish_at = v_finish_at,
      item_count = v_item_count, total_quantity = v_total_quantity, updated_at = v_now
  where id = v_transfer_id;

  if v_same_city then perform public.complete_logistics_transfer(v_transfer_id); end if;

  return jsonb_build_object(
    'success', true, 'transfer_id', v_transfer_id, 'mode', v_mode, 'item_count', v_item_count, 'total_quantity', v_total_quantity,
    'reserved_capacity_amount', v_total_volume, 'transport_cost', v_transport_cost, 'finish_at', v_finish_at,
    'changed', jsonb_build_object('player', public.get_player_profile(v_player_id))
  );
end;
$function$;

-- 10. Update start_multi_market_transfer (overload 2, remove player_notifications insert)
CREATE OR REPLACE FUNCTION public.start_multi_market_transfer(p_seller_player_id uuid, p_seller_warehouse_id uuid, p_buyer_warehouse_id uuid, p_items jsonb, p_vehicle_id uuid DEFAULT NULL::uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_default_brand uuid := '00000000-0000-0000-0000-000000000000'::uuid;
  v_buyer_player_id uuid := auth.uid();
  v_npc_logistics_player_id uuid;
  v_now timestamptz := timezone('utc', now());
  v_seller_warehouse record;
  v_buyer_warehouse record;
  v_vehicle public.logistics_vehicles%rowtype;
  v_transfer_id uuid;
  v_item jsonb;
  v_seller_slot record;
  v_product public.products%rowtype;
  v_item_count integer := 0;
  v_total_quantity integer := 0;
  v_total_volume numeric := 0;
  v_total_price numeric := 0;
  v_transport_cost numeric := 0;
  v_rental_cost numeric := 0;
  v_distance_km numeric := 0;
  v_fuel_used numeric := 0;
  v_condition_loss numeric := 0;
  v_duration_seconds integer := 0;
  v_finish_at timestamptz;
  v_same_city boolean := false;
  v_mode text := 'instant';
  v_is_rental boolean := false;
  v_item_quantity integer;
  v_item_total_price numeric;
  v_item_reserved_capacity numeric;
  v_buyer_cash numeric := 0;
  v_seller_cash numeric := 0;
  v_header_product_id text;
  v_header_quality_level integer;
  v_header_brand_id uuid;
  v_buyer_used_capacity numeric := 0;
begin
  if v_buyer_player_id is null then raise exception 'Oturum acilmamis.'; end if;
  if p_seller_player_id is null then raise exception 'Satici oyuncu secilmelidir.'; end if;
  if p_seller_warehouse_id is null or p_buyer_warehouse_id is null then raise exception 'Satici ve alici depo secilmelidir.'; end if;
  if p_seller_warehouse_id = p_buyer_warehouse_id then raise exception 'Satici ve alici ayni depo olamaz.'; end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then raise exception 'Transfer kalemleri bos olamaz.'; end if;

  select w.*, c.map_position_x, c.map_position_y
  into v_seller_warehouse
  from public.warehouses w join public.cities c on c.id = w.city_id
  where w.id = p_seller_warehouse_id and w.player_id = p_seller_player_id for update;
  if not found then raise exception 'Satici depo bulunamadi.'; end if;

  select w.*, c.map_position_x, c.map_position_y
  into v_buyer_warehouse
  from public.warehouses w join public.cities c on c.id = w.city_id
  where w.id = p_buyer_warehouse_id and w.player_id = v_buyer_player_id for update;
  if not found then raise exception 'Alici depo bulunamadi.'; end if;

  v_item := p_items -> 0;
  if v_item is null then raise exception 'Transfer kalemleri bos olamaz.'; end if;

  select ws.product_id, ws.quality_level, coalesce(ws.brand_id, v_default_brand)
  into v_header_product_id, v_header_quality_level, v_header_brand_id
  from public.warehouse_slots ws join public.warehouses w on w.id = ws.warehouse_id
  where ws.id = (v_item ->> 'source_warehouse_slot_id')::uuid and w.id = v_seller_warehouse.id;
  if coalesce(v_header_product_id, '') = '' then raise exception 'Ilk transfer kalemi icin satici slotu bulunamadi.'; end if;

  v_same_city := v_seller_warehouse.city_id = v_buyer_warehouse.city_id;
  if v_same_city then
    v_mode := 'instant'; v_finish_at := v_now;
  else
    v_mode := 'in_transit';
    if p_vehicle_id is null then raise exception 'Sehirler arasi transfer icin arac secilmelidir.'; end if;
    v_npc_logistics_player_id := public.get_npc_logistics_player_id();
    select * into v_vehicle from public.logistics_vehicles
    where id = p_vehicle_id and status = 'idle'
      and (player_id = v_buyer_player_id or (coalesce(is_available_for_rent, false) = true and (player_id = v_npc_logistics_player_id or public.logistics_vehicle_matches_route(route_city_a_id, route_city_b_id, v_seller_warehouse.city_id, v_buyer_warehouse.city_id))))
    for update;
    if not found then raise exception 'Secilen arac kullanima uygun degil.'; end if;
    v_is_rental := v_vehicle.player_id <> v_buyer_player_id;
    
    v_distance_km := round(
      (6371 * 2 * asin(sqrt(power(sin(radians(coalesce(v_buyer_warehouse.map_position_x, 0) - coalesce(v_seller_warehouse.map_position_x, 0)) / 2), 2) + cos(radians(coalesce(v_seller_warehouse.map_position_x, 0))) * cos(radians(coalesce(v_buyer_warehouse.map_position_x, 0))) * power(sin(radians(coalesce(v_buyer_warehouse.map_position_y, 0) - coalesce(v_seller_warehouse.map_position_y, 0)) / 2), 2))))::numeric, 2
    );

    if coalesce(v_vehicle.speed_kmh, 0) <= 0 then raise exception 'Secilen aracin hizi gecersiz.'; end if;
    v_duration_seconds := greatest(60, ceil((greatest(v_distance_km, 1) / v_vehicle.speed_kmh) * 120)::integer);
    v_finish_at := v_now + make_interval(secs => v_duration_seconds);
  end if;

  insert into public.logistics_transfers (
    buyer_player_id, seller_player_id, buyer_warehouse_id, seller_warehouse_id, logistics_vehicle_id, vehicle_owner_player_id,
    is_rental, product_id, quality_level, quantity, unit_price, total_price, product_unit_volume, reserved_capacity_amount,
    distance_km, fuel_used, condition_loss, rental_cost, transport_cost, started_at, finish_at, status, transfer_type,
    seller_entity_kind, buyer_entity_kind, item_count, total_quantity, brand_id, created_at, updated_at
  ) values (
    v_buyer_player_id, p_seller_player_id, v_buyer_warehouse.id, v_seller_warehouse.id, p_vehicle_id,
    case when p_vehicle_id is not null then v_vehicle.player_id else null end,
    v_is_rental, v_header_product_id, greatest(coalesce(v_header_quality_level, 1), 1), 1, 0, 0, 1, 0,
    v_distance_km, 0, 0, 0, 0, v_now, v_finish_at, 'in_transit', 'market_purchase_multi',
    'warehouse', 'warehouse', 1, 0, coalesce(v_header_brand_id, v_default_brand), v_now, v_now
  ) returning id into v_transfer_id;

  for v_item in select value from jsonb_array_elements(p_items) loop
    v_item_quantity := greatest(coalesce((v_item ->> 'quantity')::integer, 0), 0);
    if v_item_quantity <= 0 then raise exception 'Transfer miktari 0 dan buyuk olmalidir.'; end if;

    select ws.*, w.player_id, w.city_id
    into v_seller_slot
    from public.warehouse_slots ws join public.warehouses w on w.id = ws.warehouse_id
    where ws.id = (v_item ->> 'source_warehouse_slot_id')::uuid for update;

    if not found then raise exception 'Satici depo slotu bulunamadi.'; end if;
    if v_seller_slot.player_id <> p_seller_player_id then raise exception 'Satici depo slotu saticiya ait degil.'; end if;
    if v_seller_slot.warehouse_id <> v_seller_warehouse.id then raise exception 'Tum kalemler secilen satici depoya ait olmalidir.'; end if;
    if coalesce(v_seller_slot.is_available_for_sale, false) = false then raise exception 'Satici slotu satisa acik degil.'; end if;
    if coalesce(v_seller_slot.product_id, '') = '' then raise exception 'Satici slotunda urun bulunamadi.'; end if;
    if coalesce(v_seller_slot.quantity, 0) < v_item_quantity then raise exception 'Satici slotunda yeterli stok yok.'; end if;

    select * into v_product from public.products where id = v_seller_slot.product_id;
    if not found then raise exception 'Urun bulunamadi.'; end if;

    v_item_total_price := v_item_quantity * coalesce(v_seller_slot.price, 0);
    v_item_reserved_capacity := v_item_quantity * coalesce(v_product.birim_hacim, 0);

    select coalesce(sum((ws.quantity + coalesce(ws.pending_quantity, 0)) * coalesce(p.birim_hacim, 0)), 0)
    into v_buyer_used_capacity from public.warehouse_slots ws left join public.products p on p.id = ws.product_id where ws.warehouse_id = v_buyer_warehouse.id;
    if v_buyer_used_capacity + coalesce(v_buyer_warehouse.reserved_capacity, 0) + v_item_reserved_capacity > coalesce(v_buyer_warehouse.capacity, 0) then
      raise exception 'Alici depoda yeterli rezerve kapasite yok.';
    end if;

    update public.warehouses set reserved_capacity = coalesce(reserved_capacity, 0) + v_item_reserved_capacity, updated_at = v_now where id = v_buyer_warehouse.id;
    v_buyer_warehouse.reserved_capacity := coalesce(v_buyer_warehouse.reserved_capacity, 0) + v_item_reserved_capacity;

    insert into public.logistics_transfer_items (
      transfer_id, source_warehouse_slot_id, target_warehouse_slot_id, product_id, quality_level, brand_id, quantity, unit_cost, unit_price, total_cost, total_price, product_unit_volume, reserved_capacity_amount, status, created_at, updated_at
    ) values (
      v_transfer_id, v_seller_slot.id, null, v_seller_slot.product_id, v_seller_slot.quality_level, coalesce(v_seller_slot.brand_id, v_default_brand), v_item_quantity, coalesce(v_seller_slot.cost, 0), coalesce(v_seller_slot.price, 0), v_item_quantity * coalesce(v_seller_slot.cost, 0), v_item_total_price, coalesce(v_product.birim_hacim, 0), v_item_reserved_capacity, 'in_transit', v_now, v_now
    );

    update public.warehouse_slots set quantity = quantity - v_item_quantity, updated_at = v_now where id = v_seller_slot.id;
    if coalesce(v_seller_slot.quantity, 0) - v_item_quantity <= 0 and coalesce(v_seller_slot.pending_quantity, 0) <= 0 then
      delete from public.warehouse_slots where id = v_seller_slot.id;
    end if;

    v_item_count := v_item_count + 1;
    v_total_quantity := v_total_quantity + v_item_quantity;
    v_total_volume := v_total_volume + v_item_reserved_capacity;
    v_total_price := v_total_price + v_item_total_price;
  end loop;

  if v_item_count <= 0 then raise exception 'Transfer icin gecerli kalem bulunamadi.'; end if;

  if not v_same_city then
    if v_is_rental and v_vehicle.player_id = v_npc_logistics_player_id then
      v_vehicle.capacity := greatest(coalesce(v_vehicle.capacity, 0), ceil(v_total_volume));
      update public.logistics_vehicles set capacity = v_vehicle.capacity where id = v_vehicle.id;
    end if;

    if coalesce(v_vehicle.capacity, 0) < ceil(v_total_volume) then raise exception 'Secilen aracin kapasitesi bu transfer icin yetersiz.'; end if;
    v_fuel_used := round(v_distance_km * coalesce(v_vehicle.fuel_rate, 0), 2);
    v_condition_loss := greatest(1, ceil(v_distance_km / 200.0));
    v_transport_cost := case when v_is_rental then round(v_distance_km * coalesce(v_vehicle.rental_price, 0), 2) else round(v_fuel_used * coalesce(v_vehicle.fuel_cost, 0), 2) end;
    v_rental_cost := case when v_is_rental then v_transport_cost else 0 end;

    if coalesce(v_vehicle.current_fuel, 0) < ceil(v_fuel_used) then raise exception 'Aracta yeterli yakit yok.'; end if;
    if coalesce(v_vehicle.condition, 0) <= 0 then raise exception 'Aracin bakimi yetersiz.'; end if;
  end if;

  select cash into v_buyer_cash from public.players where id = v_buyer_player_id for update;
  if coalesce(v_buyer_cash, 0) < (v_total_price + v_transport_cost) then
    raise exception 'Yetersiz bakiye. Gerekli: % TL, Mevcut: % TL', (v_total_price + v_transport_cost), coalesce(v_buyer_cash, 0);
  end if;

  update public.players set cash = cash - (v_total_price + v_transport_cost) where id = v_buyer_player_id;
  perform public.log_player_cash_change(v_buyer_player_id, -v_total_price, v_buyer_cash, 'market_purchase', format('Pazardan urun alimi (Transfer: %s)', v_transfer_id), v_transfer_id, 'logistics_transfer');

  if v_transport_cost > 0 then
    perform public.log_player_cash_change(v_buyer_player_id, -v_transport_cost, v_buyer_cash - v_total_price, case when v_is_rental then 'vehicle_rental_paid' else 'fuel_cost_paid' end, format('Lojistik maliyeti odendi (Transfer: %s)', v_transfer_id), v_transfer_id, 'logistics_transfer');
  end if;

  select cash into v_seller_cash from public.players where id = p_seller_player_id for update;
  update public.players set cash = coalesce(cash, 0) + v_total_price where id = p_seller_player_id;
  perform public.log_player_cash_change(p_seller_player_id, v_total_price, coalesce(v_seller_cash, 0), 'market_sale', format('Pazarda urun satisi (Transfer: %s)', v_transfer_id), v_transfer_id, 'logistics_transfer');

  if not v_same_city then
    if v_is_rental and v_rental_cost > 0 then
      perform public.process_logistics_vehicle_rental_payout(p_vehicle_id, v_transfer_id, v_buyer_player_id, v_rental_cost, v_distance_km);
    end if;

    update public.logistics_vehicles
    set status = 'on_route', current_fuel = greatest(current_fuel - ceil(v_fuel_used), 0), condition = greatest(condition - ceil(v_condition_loss), 0), updated_at = v_now
    where id = v_vehicle.id;
  end if;

  update public.logistics_transfers
  set product_id = v_header_product_id, quality_level = greatest(coalesce(v_header_quality_level, 1), 1), quantity = greatest(v_total_quantity, 1), unit_price = 0, total_price = v_total_price,
      product_unit_volume = greatest(v_total_volume, 0.0001), reserved_capacity_amount = v_total_volume, distance_km = v_distance_km, fuel_used = v_fuel_used, condition_loss = v_condition_loss,
      rental_cost = v_rental_cost, transport_cost = v_transport_cost, finish_at = v_finish_at, item_count = v_item_count, total_quantity = v_total_quantity, brand_id = coalesce(v_header_brand_id, v_default_brand), updated_at = v_now
  where id = v_transfer_id;

  if v_same_city then perform public.complete_logistics_transfer(v_transfer_id); end if;

  return jsonb_build_object(
    'success', true, 'transfer_id', v_transfer_id, 'mode', v_mode, 'item_count', v_item_count, 'total_quantity', v_total_quantity, 'total_price', v_total_price, 'transport_cost', v_transport_cost, 'finish_at', v_finish_at
  );
end;
$function$;

-- 11. Update accept_tender (remove player_notifications insert)
CREATE OR REPLACE FUNCTION public.accept_tender(p_tender_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_player_id uuid := auth.uid();
  v_player public.players%rowtype;
  v_tender public.tenders%rowtype;
  v_player_tender_id uuid;
  v_deadline_at timestamptz;
begin
  if v_player_id is null then
    return jsonb_build_object('success', false, 'message', 'Oturum acilmamis.');
  end if;

  perform public.ensure_open_tenders();

  select * into v_player from public.players where id = v_player_id for update;
  if not found then
    return jsonb_build_object('success', false, 'message', 'Oyuncu bulunamadi.');
  end if;

  select * into v_tender from public.tenders where id = p_tender_id for update;
  if not found then
    return jsonb_build_object('success', false, 'message', 'Ihale bulunamadi.');
  end if;

  if v_tender.award_type <> 'first_claim' then
    return jsonb_build_object('success', false, 'message', 'Bu ihale teklif usulu ile calisiyor.');
  end if;

  if v_tender.status <> 'open' then
    return jsonb_build_object('success', false, 'message', 'Ihale artik uygun degil.');
  end if;

  if v_tender.accept_until <= timezone('utc'::text, now()) then
    return jsonb_build_object('success', false, 'message', 'Ihaleye katilim suresi doldu.');
  end if;

  if coalesce(v_player.level, 1) < v_tender.min_player_level then
    return jsonb_build_object('success', false, 'message', 'Oyuncu seviyesi yeterli degil.');
  end if;

  if exists (
    select 1 from public.player_tenders pt
    where pt.player_id = v_player_id and pt.tender_id = v_tender.id
  ) then
    return jsonb_build_object('success', false, 'message', 'Bu ihaleye zaten katildin.');
  end if;

  if coalesce(v_player.level, 1) < v_tender.min_player_level or coalesce(v_player.cash, 0) < v_tender.bond_amount then
    return jsonb_build_object('success', false, 'message', 'Teminat icin yeterli nakit yok.');
  end if;

  update public.players set cash = cash - v_tender.bond_amount where id = v_player_id;

  v_deadline_at := timezone('utc'::text, now()) + make_interval(mins => v_tender.delivery_duration_minutes);

  insert into public.player_tenders (
    player_id, tender_id, accepted_at, deadline_at, bond_paid, required_quantity,
    delivered_quantity, reward_cash, product_id, quality_level, city_id, status
  )
  values (
    v_player_id, v_tender.id, timezone('utc'::text, now()), v_deadline_at, v_tender.bond_amount,
    v_tender.required_quantity, 0, v_tender.reward_cash, v_tender.product_id, v_tender.quality_level,
    v_tender.city_id, 'active'
  )
  returning id into v_player_tender_id;

  update public.tenders set status = 'closed', updated_at = timezone('utc'::text, now()) where id = v_tender.id;

  perform public.log_player_cash_change(
    v_player_id,
    -v_tender.bond_amount,
    v_player.cash,
    'tender_bond_paid',
    format('Ihale teminati odendi. Tender: %s', v_tender.id),
    v_player_tender_id,
    'player_tender'
  );

  return jsonb_build_object(
    'success', true,
    'player_tender_id', v_player_tender_id,
    'deadline_at', v_deadline_at,
    'message', 'Ihale kabul edildi ve sana atandi.',
    'changed', jsonb_build_object(
      'player', public.get_player_profile(v_player_id)
    )
  );
end;
$function$;

-- 12. Update cancel_player_tender (remove player_notifications insert)
CREATE OR REPLACE FUNCTION public.cancel_player_tender(p_player_tender_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_player_id uuid := auth.uid();
  v_now timestamptz := timezone('utc'::text, now());
  v_player_tender public.player_tenders%rowtype;
  v_tender_title text := 'Ihale';
  v_cancelled_delivery_count integer := 0;
  v_cancelled_quantity integer := 0;
begin
  if v_player_id is null then
    return jsonb_build_object('success', false, 'message', 'Oturum acilmamis.');
  end if;

  select *
  into v_player_tender
  from public.player_tenders
  where id = p_player_tender_id
    and player_id = v_player_id
  for update;

  if not found then
    return jsonb_build_object('success', false, 'message', 'Oyuncu ihalesi bulunamadi.');
  end if;

  if v_player_tender.status <> 'active' then
    return jsonb_build_object('success', false, 'message', 'Sadece aktif ihale iptal edilebilir.');
  end if;

  select coalesce(t.title, 'Ihale')
  into v_tender_title
  from public.tenders t
  where t.id = v_player_tender.tender_id;

  select
    count(*)::integer,
    coalesce(sum(td.quantity), 0)::integer
  into v_cancelled_delivery_count, v_cancelled_quantity
  from public.tender_deliveries td
  where td.player_tender_id = v_player_tender.id
    and td.status = 'in_transit';

  update public.tender_deliveries
  set status = 'cancelled',
      updated_at = v_now
  where player_tender_id = v_player_tender.id
    and status = 'in_transit';

  update public.logistics_vehicles lv
  set status = 'idle',
      updated_at = v_now
  where exists (
    select 1
    from public.tender_deliveries td
    where td.player_tender_id = v_player_tender.id
      and td.vehicle_id = lv.id
      and td.status = 'cancelled'
  );

  update public.player_tenders
  set status = 'cancelled',
      updated_at = v_now
  where id = v_player_tender.id;

  return jsonb_build_object(
    'success', true,
    'player_tender_id', v_player_tender.id,
    'status', 'cancelled',
    'cancelled_delivery_count', v_cancelled_delivery_count,
    'cancelled_quantity', v_cancelled_quantity,
    'message', 'Ihale iptal edildi. Teminat ve yoldaki sevkiyat yandi.'
  );
end;
$function$;

-- 13. Update complete_player_tender (remove player_notifications insert)
CREATE OR REPLACE FUNCTION public.complete_player_tender(p_player_tender_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_player_tender public.player_tenders%rowtype;
  v_player_cash numeric := 0;
  v_payout numeric := 0;
  v_tender_title text := 'Ihale';
  v_tender_exp integer := 0;
begin
  select *
  into v_player_tender
  from public.player_tenders
  where id = p_player_tender_id
  for update;

  if not found then
    return jsonb_build_object('success', false, 'message', 'Oyuncu ihalesi bulunamadi.');
  end if;

  if v_player_tender.status <> 'active' then
    return jsonb_build_object('success', false, 'message', 'Ihale aktif degil.');
  end if;

  if v_player_tender.delivered_quantity < v_player_tender.required_quantity then
    return jsonb_build_object('success', false, 'message', 'Teslim miktari henuz yeterli degil.');
  end if;

  select cash
  into v_player_cash
  from public.players
  where id = v_player_tender.player_id
  for update;

  select coalesce(t.title, 'Ihale')
  into v_tender_title
  from public.tenders t
  where t.id = v_player_tender.tender_id;

  v_payout := v_player_tender.reward_cash + v_player_tender.bond_paid;

  update public.player_tenders
  set status = 'completed',
      completed_at = timezone('utc'::text, now()),
      updated_at = timezone('utc'::text, now())
  where id = v_player_tender.id;

  update public.players
  set cash = cash + v_payout
  where id = v_player_tender.player_id;

  perform public.log_player_cash_change(
    v_player_tender.player_id,
    v_player_tender.reward_cash,
    v_player_cash,
    'tender_reward_paid',
    format('Ihale odulu kazanildi. Tender: %s', v_player_tender.tender_id),
    v_player_tender.id,
    'player_tender'
  );

  perform public.log_player_cash_change(
    v_player_tender.player_id,
    v_player_tender.bond_paid,
    v_player_cash + v_player_tender.reward_cash,
    'tender_bond_refunded',
    format('Ihale teminati iade edildi. Tender: %s', v_player_tender.tender_id),
    v_player_tender.id,
    'player_tender'
  );

  v_tender_exp := greatest(200, least(1500, 200 + floor(v_player_tender.reward_cash / 10000)::integer + floor(v_player_tender.required_quantity / 10)::integer));
  perform public.grant_player_experience(
    v_player_tender.player_id,
    v_tender_exp,
    'tender_completed',
    jsonb_build_object(
      'tender_id', v_player_tender.tender_id,
      'player_tender_id', v_player_tender.id,
      'reward_cash', v_player_tender.reward_cash,
      'required_quantity', v_player_tender.required_quantity
    )
  );

  return jsonb_build_object(
    'success', true,
    'player_tender_id', v_player_tender.id,
    'status', 'completed',
    'payout', v_payout,
    'exp_gained', v_tender_exp,
    'message', 'Ihale tamamlandi.'
  );
end;
$function$;

-- 14. Update ensure_open_tenders (remove player_notifications insert)
CREATE OR REPLACE FUNCTION public.ensure_open_tenders()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_now timestamptz := timezone('utc'::text, now());
  v_expired_count integer := 0;
  v_closed_count integer := 0;
  v_tender public.tenders%rowtype;
  v_winning_bid public.tender_bids%rowtype;
  v_losing_bid public.tender_bids%rowtype;
  v_player_tender_id uuid;
  v_deadline_at timestamptz;
  v_player_cash numeric;
begin
  for v_tender in
    select * from public.tenders
    where status = 'open' and accept_until <= v_now
    order by accept_until asc
    for update
  loop
    if v_tender.award_type = 'first_claim' then
      update public.tenders
      set status = 'expired', updated_at = v_now
      where id = v_tender.id;
      v_expired_count := v_expired_count + 1;
      continue;
    end if;

    select * into v_winning_bid
    from public.tender_bids tb
    where tb.tender_id = v_tender.id
      and tb.status = 'active'
    order by tb.bid_amount asc, tb.submitted_at asc, tb.created_at asc
    limit 1
    for update;

    if not found then
      update public.tenders
      set status = 'expired', updated_at = v_now
      where id = v_tender.id;
      v_expired_count := v_expired_count + 1;
      continue;
    end if;

    v_deadline_at := v_now + make_interval(mins => v_tender.delivery_duration_minutes);

    insert into public.player_tenders (
      player_id, tender_id, accepted_at, deadline_at, bond_paid, required_quantity,
      delivered_quantity, reward_cash, product_id, quality_level, city_id, status
    )
    values (
      v_winning_bid.player_id, v_tender.id, v_now, v_deadline_at, v_winning_bid.bond_paid,
      v_tender.required_quantity, 0, v_winning_bid.bid_amount, v_tender.product_id,
      v_tender.quality_level, v_tender.city_id, 'active'
    )
    returning id into v_player_tender_id;

    update public.tender_bids
    set status = 'won', resolved_at = v_now, updated_at = v_now
    where id = v_winning_bid.id;

    update public.tenders
    set status = 'closed', updated_at = v_now
    where id = v_tender.id;

    for v_losing_bid in
      select * from public.tender_bids tb
      where tb.tender_id = v_tender.id
        and tb.status = 'active'
        and tb.id <> v_winning_bid.id
      for update
    loop
      select cash into v_player_cash from public.players where id = v_losing_bid.player_id for update;
      update public.players set cash = cash + v_losing_bid.bond_paid where id = v_losing_bid.player_id;
      update public.tender_bids
      set status = 'lost', resolved_at = v_now, updated_at = v_now
      where id = v_losing_bid.id;
      perform public.log_player_cash_change(
        v_losing_bid.player_id,
        v_losing_bid.bond_paid,
        v_player_cash,
        'tender_bid_bond_refunded',
        format('Ihale teklif teminati iade edildi. Tender: %s', v_tender.id),
        v_losing_bid.id,
        'tender_bid'
      );
    end loop;

    v_closed_count := v_closed_count + 1;
  end loop;

  return jsonb_build_object(
    'success', true,
    'expired_count', v_expired_count,
    'closed_count', v_closed_count
  );
end;
$function$;

-- 15. Update process_player_tenders (remove player_notifications insert)
CREATE OR REPLACE FUNCTION public.process_player_tenders(p_player_id uuid DEFAULT NULL::uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_target_player_id uuid := coalesce(p_player_id, auth.uid());
  v_failed_count integer := 0;
  v_failed record;
begin
  if v_target_player_id is null then
    return jsonb_build_object('success', false, 'message', 'Oturum acilmamis.');
  end if;

  for v_failed in
    update public.player_tenders pt
    set status = 'failed',
        failed_at = timezone('utc'::text, now()),
        updated_at = timezone('utc'::text, now())
    from public.tenders t
    where pt.player_id = v_target_player_id
      and pt.status = 'active'
      and pt.deadline_at <= timezone('utc'::text, now())
      and pt.delivered_quantity < pt.required_quantity
      and t.id = pt.tender_id
    returning pt.id,
      pt.player_id,
      pt.tender_id,
      pt.required_quantity,
      pt.delivered_quantity,
      t.title
  loop
    v_failed_count := v_failed_count + 1;
  end loop;

  return jsonb_build_object(
    'success', true,
    'failed_count', v_failed_count
  );
end;
$function$;

-- 16. Update process_tender_deliveries (remove player_notifications insert)
CREATE OR REPLACE FUNCTION public.process_tender_deliveries(p_player_id uuid DEFAULT NULL::uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_target_player_id uuid := coalesce(p_player_id, auth.uid());
  v_delivery record;
  v_player_tender public.player_tenders%rowtype;
  v_completed_count integer := 0;
  v_completion_result jsonb;
  v_tender_title text := 'Ihale';
BEGIN
  FOR v_delivery IN
    SELECT td.*, t.title as tender_title
    FROM public.tender_deliveries td
    JOIN public.player_tenders pt ON pt.id = td.player_tender_id
    JOIN public.tenders t ON t.id = pt.tender_id
    WHERE (v_target_player_id IS NULL OR td.player_id = v_target_player_id)
      AND td.status = 'in_transit'
      AND td.finish_at IS NOT NULL
      AND td.finish_at <= timezone('utc'::text, now())
    ORDER BY td.finish_at ASC
    FOR UPDATE OF td SKIP LOCKED
  LOOP
    v_tender_title := coalesce(v_delivery.tender_title, 'Ihale');

    SELECT *
    INTO v_player_tender
    FROM public.player_tenders
    WHERE id = v_delivery.player_tender_id
    FOR UPDATE;

    IF NOT FOUND THEN
      UPDATE public.tender_deliveries
      SET status = 'failed',
          updated_at = timezone('utc'::text, now())
      WHERE id = v_delivery.id;
      IF v_delivery.vehicle_id IS NOT NULL THEN
        UPDATE public.logistics_vehicles
        SET status = 'idle',
            updated_at = timezone('utc'::text, now())
        WHERE id = v_delivery.vehicle_id;
      END IF;
      CONTINUE;
    END IF;

    IF v_player_tender.status <> 'active' THEN
      UPDATE public.tender_deliveries
      SET status = 'failed',
          updated_at = timezone('utc'::text, now())
      WHERE id = v_delivery.id;
      IF v_delivery.vehicle_id IS NOT NULL THEN
        UPDATE public.logistics_vehicles
        SET status = 'idle',
            updated_at = timezone('utc'::text, now())
        WHERE id = v_delivery.vehicle_id;
      END IF;
      CONTINUE;
    END IF;

    IF v_player_tender.deadline_at < timezone('utc'::text, now()) THEN
      UPDATE public.tender_deliveries
      SET status = 'failed_late',
          updated_at = timezone('utc'::text, now())
      WHERE id = v_delivery.id;

      IF v_delivery.vehicle_id IS NOT NULL THEN
        UPDATE public.logistics_vehicles
        SET status = 'idle',
            updated_at = timezone('utc'::text, now())
        WHERE id = v_delivery.vehicle_id;
      END IF;
      CONTINUE;
    END IF;

    UPDATE public.tender_deliveries
    SET status = 'completed',
        completed_at = timezone('utc'::text, now()),
        updated_at = timezone('utc'::text, now())
    WHERE id = v_delivery.id;

    IF v_delivery.vehicle_id IS NOT NULL THEN
      UPDATE public.logistics_vehicles
      SET status = 'idle',
          updated_at = timezone('utc'::text, now())
      WHERE id = v_delivery.vehicle_id;
    END IF;

    UPDATE public.player_tenders
    SET delivered_quantity = least(required_quantity, delivered_quantity + v_delivery.quantity),
        updated_at = timezone('utc'::text, now())
    WHERE id = v_player_tender.id;

    v_completed_count := v_completed_count + 1;

    SELECT *
    INTO v_player_tender
    FROM public.player_tenders
    WHERE id = v_player_tender.id;

    IF v_player_tender.delivered_quantity >= v_player_tender.required_quantity THEN
      v_completion_result := public.complete_player_tender(v_player_tender.id);
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'completed_delivery_count', v_completed_count
  );
END;
$function$;

-- 17. Update start_tender_delivery (remove player_notifications insert)
CREATE OR REPLACE FUNCTION public.start_tender_delivery(p_player_tender_id uuid, p_warehouse_id uuid, p_vehicle_id uuid, p_quantity integer)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_default_vehicle_id constant uuid := '00000000-0000-0000-0000-000000000000'::uuid;
  v_player_id uuid := auth.uid();
  v_now timestamptz := timezone('utc'::text, now());
  v_player_tender public.player_tenders%rowtype;
  v_warehouse public.warehouses%rowtype;
  v_slot record;
  v_same_city boolean := false;
  v_remaining_quantity integer := 0;
  v_selected_quantity integer := 0;
  v_in_transit_quantity integer := 0;
  v_delivery_id uuid;
  v_finish_at timestamptz;
  v_tender_title text := 'Ihale';
  v_distance_km numeric := 0;
  v_estimated_duration_minutes integer := 5;
  v_transport_cost numeric := 0;
  v_product_unit_volume numeric := 0;
  v_total_volume numeric := 0;
  v_cash_before numeric := 0;
  v_vehicle_option record;
begin
  if v_player_id is null then
    return jsonb_build_object('success', false, 'message', 'Oturum acilmamis.');
  end if;

  if coalesce(p_quantity, 0) <= 0 then
    return jsonb_build_object('success', false, 'message', 'Teslim miktari sifirdan buyuk olmali.');
  end if;

  select *
  into v_player_tender
  from public.player_tenders
  where id = p_player_tender_id
    and player_id = v_player_id
  for update;

  if not found then
    return jsonb_build_object('success', false, 'message', 'Oyuncu ihalesi bulunamadi.');
  end if;

  if v_player_tender.status <> 'active' then
    return jsonb_build_object('success', false, 'message', 'Ihale aktif degil.');
  end if;

  if v_player_tender.deadline_at <= v_now then
    return jsonb_build_object('success', false, 'message', 'Ihale suresi dolmus.');
  end if;

  select *
  into v_warehouse
  from public.warehouses
  where id = p_warehouse_id
    and player_id = v_player_id
    and is_active = true
  for update;

  if not found then
    return jsonb_build_object('success', false, 'message', 'Depo bulunamadi.');
  end if;

  select coalesce(t.title, 'Ihale')
  into v_tender_title
  from public.tenders t
  where t.id = v_player_tender.tender_id;

  select coalesce(sum(td.quantity), 0)::integer
  into v_in_transit_quantity
  from public.tender_deliveries td
  where td.player_tender_id = v_player_tender.id
    and td.status = 'in_transit';

  v_same_city := v_warehouse.city_id = v_player_tender.city_id;

  v_remaining_quantity := greatest(
    v_player_tender.required_quantity - v_player_tender.delivered_quantity - v_in_transit_quantity,
    0
  );
  if v_remaining_quantity <= 0 then
    return jsonb_build_object('success', false, 'message', 'Ihale icin bekleyen ihtiyac kalmadi.');
  end if;

  v_selected_quantity := least(p_quantity, v_remaining_quantity);

  select
    ws.id,
    ws.quantity,
    ws.quality_level
  into v_slot
  from public.warehouse_slots ws
  where ws.warehouse_id = v_warehouse.id
    and ws.product_id = v_player_tender.product_id
    and ws.quality_level >= v_player_tender.quality_level
    and coalesce(ws.quantity, 0) > 0
  order by ws.quality_level asc, ws.id asc
  for update;

  if not found then
    return jsonb_build_object('success', false, 'message', 'Depoda uygun kalite stok bulunamadi.');
  end if;

  if coalesce(v_slot.quantity, 0) <= 0 then
    return jsonb_build_object('success', false, 'message', 'Depoda kullanilabilir stok yok.');
  end if;

  v_selected_quantity := least(v_selected_quantity, v_slot.quantity);

  select coalesce(p.birim_hacim, 0)
  into v_product_unit_volume
  from public.products p
  where p.id = v_player_tender.product_id;

  v_total_volume := greatest(v_selected_quantity * greatest(v_product_unit_volume, 0), 0.0001);

  if v_same_city then
    v_distance_km := 0;
    v_estimated_duration_minutes := 5;
    v_transport_cost := 0;
  else
    if p_vehicle_id is null or p_vehicle_id = v_default_vehicle_id then
      return jsonb_build_object(
        'success', false,
        'message', 'Sehirler arasi teslimatta arac secmelisin.'
      );
    end if;

    select *
    into v_vehicle_option
    from public.get_route_transfer_vehicle_options(
      v_warehouse.city_id,
      v_player_tender.city_id,
      v_total_volume
    ) opt
    where opt.vehicle_id = p_vehicle_id
      and opt.can_select = true
    limit 1;

    if not found then
      return jsonb_build_object(
        'success', false,
        'message', 'Secilen arac bu teslimat icin artik uygun degil.'
      );
    end if;

    v_distance_km := coalesce(v_vehicle_option.distance_km, 0);
    v_estimated_duration_minutes := greatest(
      1,
      ceil(coalesce(v_vehicle_option.estimated_duration_seconds, 0) / 60.0)
    )::integer;
    v_transport_cost := coalesce(v_vehicle_option.total_price, 0);
  end if;

  v_finish_at := v_now + make_interval(mins => v_estimated_duration_minutes);

  if v_finish_at > v_player_tender.deadline_at then
    return jsonb_build_object(
      'success', false,
      'message', 'Bu depodan cikacak teslimat son tarihe yetismiyor.'
    );
  end if;

  if not v_same_city then
    select coalesce(cash, 0)
    into v_cash_before
    from public.players
    where id = v_player_id
    for update;

    if v_cash_before < v_transport_cost then
      return jsonb_build_object(
        'success', false,
        'message', 'Secilen arac icin yeterli nakit yok.'
      );
    end if;

    if v_transport_cost > 0 then
      update public.players
      set cash = cash - v_transport_cost
      where id = v_player_id;

      perform public.log_player_cash_change(
        v_player_id,
        -v_transport_cost,
        v_cash_before,
        'tender_delivery_transport_paid',
        format('Ihale teslimati nakliye bedeli odendi. Tender: %s', v_player_tender.tender_id),
        v_player_tender.id,
        'player_tender'
      );

      if coalesce(v_vehicle_option.is_rental, false) = true then
        perform public.process_logistics_vehicle_rental_payout(p_vehicle_id, null, v_player_id, v_transport_cost, v_distance_km);
      end if;
    end if;

    update public.logistics_vehicles
    set status = 'on_route',
        current_fuel = greatest(current_fuel - ceil(coalesce(v_vehicle_option.fuel_needed, 0)), 0),
        condition = greatest(condition - ceil(coalesce(v_vehicle_option.condition_needed, 0)), 0),
        updated_at = v_now
    where id = p_vehicle_id;
  end if;

  update public.warehouse_slots
  set quantity = quantity - v_selected_quantity,
      updated_at = v_now
  where id = v_slot.id;

  insert into public.tender_deliveries (
    player_tender_id,
    player_id,
    source_warehouse_id,
    vehicle_id,
    quantity,
    status,
    same_city,
    started_at,
    finish_at,
    cost
  )
  values (
    v_player_tender.id,
    v_player_id,
    v_warehouse.id,
    case when v_same_city then null else p_vehicle_id end,
    v_selected_quantity,
    'in_transit',
    v_same_city,
    v_now,
    v_finish_at,
    v_transport_cost
  )
  returning id into v_delivery_id;

  update public.player_tenders
  set updated_at = v_now
  where id = v_player_tender.id;

  return jsonb_build_object(
    'success', true,
    'delivery_id', v_delivery_id,
    'player_tender_id', v_player_tender.id,
    'quantity', v_selected_quantity,
    'finish_at', v_finish_at,
    'estimated_duration_minutes', v_estimated_duration_minutes,
    'distance_km', v_distance_km,
    'transport_cost', v_transport_cost,
    'message', 'Ihale teslimati yola cikti.',
    'changed', jsonb_build_object(
      'player', public.get_player_profile(v_player_id)
    )
  );
end;
$function$;

-- 18. DROP THE 3 LEGACY NOTIFICATION TABLES COMPLETELY
DROP TABLE IF EXISTS public.push_notification_logs CASCADE;
DROP TABLE IF EXISTS public.push_notification_queue CASCADE;
DROP TABLE IF EXISTS public.player_notifications CASCADE;
