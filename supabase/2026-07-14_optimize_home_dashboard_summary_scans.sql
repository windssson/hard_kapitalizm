-- Consolidate repeated dashboard notification, business, and inventory scans.

CREATE OR REPLACE FUNCTION public.get_homepage_dashboard_summary(
  p_player_id uuid
)
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  WITH notification_metrics AS MATERIALIZED (
    SELECT
      count(*) FILTER (
        WHERE kind = 'warning' AND status <> 'resolved'
      )::integer AS active_warning_count,
      count(*) FILTER (WHERE status = 'unread')::integer AS unread_count,
      count(*) FILTER (
        WHERE kind = 'warning' AND status <> 'resolved' AND entity_kind = 'store'
      )::integer AS stores_warning_count,
      count(*) FILTER (
        WHERE kind = 'warning' AND status <> 'resolved' AND entity_kind = 'warehouse'
      )::integer AS warehouses_warning_count,
      count(*) FILTER (
        WHERE kind = 'warning' AND status <> 'resolved' AND entity_kind = 'factory'
      )::integer AS factories_blocked_count,
      count(*) FILTER (
        WHERE status <> 'resolved' AND entity_kind = 'field'
          AND (kind = 'warning' OR category = 'inactive_reminder')
      )::integer AS fields_warning_count,
      count(*) FILTER (
        WHERE status <> 'resolved' AND entity_kind = 'farm'
          AND (kind = 'warning' OR category = 'inactive_reminder')
      )::integer AS farms_warning_count,
      count(*) FILTER (
        WHERE status <> 'resolved' AND entity_kind = 'mine'
          AND (kind = 'warning' OR category = 'inactive_reminder')
      )::integer AS mines_warning_count,
      count(*) FILTER (
        WHERE kind = 'warning' AND status <> 'resolved' AND entity_kind = 'logistics'
      )::integer AS logistics_warning_count,
      count(*) FILTER (
        WHERE status <> 'resolved' AND entity_kind = 'arge'
          AND (kind = 'warning' OR category = 'inactive_reminder')
      )::integer AS arge_warning_count
    FROM public.player_notifications
    WHERE player_id = p_player_id
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

DO $migration$
DECLARE
  v_definition text;
  v_start_marker text := E'  select count(*)\n  into v_active_warning_count\n  from public.player_notifications pn';
  v_end_marker text := E'  select coalesce(\n    jsonb_agg(activity_row';
  v_start integer;
  v_end integer;
  v_assignment_block text := E'  v_dashboard_summary := public.get_homepage_dashboard_summary(v_player_id);\n\n'
    || E'  v_active_warning_count := coalesce((v_dashboard_summary ->> ''active_warning_count'')::integer, 0);\n'
    || E'  v_unread_notification_count := coalesce((v_dashboard_summary ->> ''unread_notification_count'')::integer, 0);\n'
    || E'  v_active_business_count := coalesce((v_dashboard_summary ->> ''active_business_count'')::integer, 0);\n'
    || E'  v_total_business_count := coalesce((v_dashboard_summary ->> ''total_business_count'')::integer, 0);\n'
    || E'  v_stores_count := coalesce((v_dashboard_summary ->> ''stores_count'')::integer, 0);\n'
    || E'  v_stores_active_count := coalesce((v_dashboard_summary ->> ''stores_active_count'')::integer, 0);\n'
    || E'  v_stores_warning_count := coalesce((v_dashboard_summary ->> ''stores_warning_count'')::integer, 0);\n'
    || E'  v_store_stock_ratio := coalesce((v_dashboard_summary ->> ''store_stock_ratio'')::numeric, 0);\n'
    || E'  v_warehouses_count := coalesce((v_dashboard_summary ->> ''warehouses_count'')::integer, 0);\n'
    || E'  v_warehouses_warning_count := coalesce((v_dashboard_summary ->> ''warehouses_warning_count'')::integer, 0);\n'
    || E'  v_warehouse_capacity_ratio := coalesce((v_dashboard_summary ->> ''warehouse_capacity_ratio'')::numeric, 0);\n'
    || E'  v_factories_count := coalesce((v_dashboard_summary ->> ''factories_count'')::integer, 0);\n'
    || E'  v_factories_active_count := coalesce((v_dashboard_summary ->> ''factories_active_count'')::integer, 0);\n'
    || E'  v_factories_blocked_count := coalesce((v_dashboard_summary ->> ''factories_blocked_count'')::integer, 0);\n'
    || E'  v_factories_production_ratio := coalesce((v_dashboard_summary ->> ''factories_production_ratio'')::numeric, 0);\n'
    || E'  v_fields_count := coalesce((v_dashboard_summary ->> ''fields_count'')::integer, 0);\n'
    || E'  v_fields_active_count := coalesce((v_dashboard_summary ->> ''fields_active_count'')::integer, 0);\n'
    || E'  v_fields_warning_count := coalesce((v_dashboard_summary ->> ''fields_warning_count'')::integer, 0);\n'
    || E'  v_fields_production_ratio := coalesce((v_dashboard_summary ->> ''fields_production_ratio'')::numeric, 0);\n'
    || E'  v_farms_count := coalesce((v_dashboard_summary ->> ''farms_count'')::integer, 0);\n'
    || E'  v_farms_active_count := coalesce((v_dashboard_summary ->> ''farms_active_count'')::integer, 0);\n'
    || E'  v_farms_warning_count := coalesce((v_dashboard_summary ->> ''farms_warning_count'')::integer, 0);\n'
    || E'  v_farms_production_ratio := coalesce((v_dashboard_summary ->> ''farms_production_ratio'')::numeric, 0);\n'
    || E'  v_mines_count := coalesce((v_dashboard_summary ->> ''mines_count'')::integer, 0);\n'
    || E'  v_mines_active_count := coalesce((v_dashboard_summary ->> ''mines_active_count'')::integer, 0);\n'
    || E'  v_mines_warning_count := coalesce((v_dashboard_summary ->> ''mines_warning_count'')::integer, 0);\n'
    || E'  v_mines_production_ratio := coalesce((v_dashboard_summary ->> ''mines_production_ratio'')::numeric, 0);\n'
    || E'  v_logistics_vehicle_count := coalesce((v_dashboard_summary ->> ''logistics_vehicle_count'')::integer, 0);\n'
    || E'  v_logistics_active_trip_count := coalesce((v_dashboard_summary ->> ''logistics_active_trip_count'')::integer, 0);\n'
    || E'  v_logistics_warning_count := coalesce((v_dashboard_summary ->> ''logistics_warning_count'')::integer, 0);\n'
    || E'  v_logistics_fuel_ratio := coalesce((v_dashboard_summary ->> ''logistics_fuel_ratio'')::numeric, 0);\n'
    || E'  v_arge_active_research_count := coalesce((v_dashboard_summary ->> ''arge_active_research_count'')::integer, 0);\n'
    || E'  v_arge_remaining_seconds := coalesce((v_dashboard_summary ->> ''arge_remaining_seconds'')::integer, 0);\n'
    || E'  v_arge_warning_count := coalesce((v_dashboard_summary ->> ''arge_warning_count'')::integer, 0);\n\n'
    || E'  if v_active_warning_count >= 5 then\n'
    || E'    v_company_status := ''kritik'';\n'
    || E'  elsif v_active_warning_count >= 2 then\n'
    || E'    v_company_status := ''dikkat'';\n'
    || E'  else\n'
    || E'    v_company_status := ''istikrarli'';\n'
    || E'  end if;\n\n';
BEGIN
  SELECT pg_get_functiondef(p.oid)
  INTO v_definition
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname = 'get_homepage_dashboard'
    AND pg_get_function_identity_arguments(p.oid) = '';

  IF v_definition IS NULL THEN
    RAISE EXCEPTION 'public.get_homepage_dashboard() not found';
  END IF;

  IF position('v_dashboard_summary jsonb' IN v_definition) = 0 THEN
    IF position('  v_stats_exist boolean := false;' IN v_definition) = 0 THEN
      RAISE EXCEPTION 'Dashboard declaration marker not found';
    END IF;

    v_definition := replace(
      v_definition,
      '  v_stats_exist boolean := false;',
      E'  v_stats_exist boolean := false;\n  v_dashboard_summary jsonb := ''{}''::jsonb;'
    );
  END IF;

  v_start := position(v_start_marker IN v_definition);
  v_end := position(v_end_marker IN v_definition);

  IF v_start = 0 OR v_end = 0 OR v_end <= v_start THEN
    RAISE EXCEPTION 'Dashboard summary block markers not found';
  END IF;

  v_definition := substring(v_definition FROM 1 FOR v_start - 1)
    || v_assignment_block
    || substring(v_definition FROM v_end);

  EXECUTE v_definition;
END;
$migration$;

REVOKE ALL ON FUNCTION public.get_homepage_dashboard_summary(uuid)
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_homepage_dashboard_summary(uuid)
TO service_role;
