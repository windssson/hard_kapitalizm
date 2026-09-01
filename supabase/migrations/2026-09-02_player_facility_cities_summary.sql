-- ============================================================================
-- RPC: Harita Üzerinde Oyuncunun İşletmeleri Olan Şehirlerin Özeti
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_player_facility_cities_summary(p_player_id uuid DEFAULT NULL::uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_player_id uuid;
  v_result jsonb;
BEGIN
  v_player_id := coalesce(p_player_id, auth.uid());
  IF v_player_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz erişim.');
  END IF;

  WITH player_facs AS (
    -- Depolar
    SELECT 'warehouse' as kind, 'Depo' as kind_display, w.id, w.name, w.city_id, c.name as city_name,
           w.capacity as total_capacity,
           coalesce((SELECT sum(ws.quantity) FROM public.warehouse_slots ws WHERE ws.warehouse_id = w.id), 0)::integer as total_stock
    FROM public.warehouses w
    JOIN public.cities c ON c.id = w.city_id
    WHERE w.player_id = v_player_id AND w.is_active = true

    UNION ALL

    -- Fabrikalar
    SELECT 'factory' as kind, 'Fabrika' as kind_display, f.id, coalesce(f.name, p.urun_adi, 'Fabrika') as name, f.city_id, c.name as city_name,
           f.output_capacity as total_capacity,
           coalesce((SELECT sum(pi.quantity) FROM public.production_inventory pi WHERE pi.owner_kind = 'factory' AND pi.owner_id = f.id AND pi.inventory_type = 'output'), 0)::integer as total_stock
    FROM public.factories f
    JOIN public.cities c ON c.id = f.city_id
    LEFT JOIN public.products p ON p.id = f.product_id
    WHERE f.player_id = v_player_id AND f.is_active = true

    UNION ALL

    -- Tarlalar
    SELECT 'farm' as kind, 'Tarla' as kind_display, fa.id, fa.name, fa.city_id, c.name as city_name,
           fa.output_capacity as total_capacity,
           coalesce((SELECT sum(pi.quantity) FROM public.production_inventory pi WHERE pi.owner_kind = 'farm' AND pi.owner_id = fa.id AND pi.inventory_type = 'output'), 0)::integer as total_stock
    FROM public.farms fa
    JOIN public.cities c ON c.id = fa.city_id
    WHERE fa.player_id = v_player_id AND fa.is_active = true

    UNION ALL

    -- Çiftlikler
    SELECT 'field' as kind, 'Çiftlik' as kind_display, fi.id, fi.name, fi.city_id, c.name as city_name,
           fi.output_capacity as total_capacity,
           coalesce((SELECT sum(pi.quantity) FROM public.production_inventory pi WHERE pi.owner_kind = 'field' AND pi.owner_id = fi.id AND pi.inventory_type = 'output'), 0)::integer as total_stock
    FROM public.fields fi
    JOIN public.cities c ON c.id = fi.city_id
    WHERE fi.player_id = v_player_id AND fi.is_active = true

    UNION ALL

    -- Madenler
    SELECT 'mine' as kind, 'Maden' as kind_display, m.id, coalesce(m.name, p.urun_adi, 'Maden') as name, m.city_id, c.name as city_name,
           m.output_capacity as total_capacity,
           coalesce((SELECT sum(pi.quantity) FROM public.production_inventory pi WHERE pi.owner_kind = 'mine' and pi.owner_id = m.id and pi.inventory_type = 'output'), 0)::integer as total_stock
    FROM public.mines m
    JOIN public.cities c ON c.id = m.city_id
    LEFT JOIN public.products p ON p.id = m.product_id
    WHERE m.player_id = v_player_id AND m.is_active = true

    UNION ALL

    -- Mağazalar
    SELECT 'store' as kind, 'Mağaza' as kind_display, s.id, s.name, s.city_id, c.name as city_name,
           (s.slot_capacity * coalesce(s.current_slot_count, 1)) as total_capacity,
           coalesce((SELECT sum(ss.quantity) FROM public.store_slots ss WHERE ss.store_id = s.id AND ss.is_active = true), 0)::integer as total_stock
    FROM public.stores s
    JOIN public.cities c ON c.id = s.city_id
    WHERE s.player_id = v_player_id AND s.is_active = true
  ),
  city_grouped AS (
    SELECT
      city_id,
      city_name,
      count(*)::integer as facility_count,
      sum(total_stock)::integer as total_city_stock,
      jsonb_agg(
        jsonb_build_object(
          'id', id,
          'name', name,
          'kind', kind,
          'kind_display', kind_display,
          'total_capacity', total_capacity,
          'total_stock', total_stock
        ) ORDER BY total_stock DESC, kind, name
      ) as facilities
    FROM player_facs
    GROUP BY city_id, city_name
  )
  SELECT jsonb_agg(
    jsonb_build_object(
      'city_id', city_id,
      'city_name', city_name,
      'facility_count', facility_count,
      'total_city_stock', total_city_stock,
      'facilities', facilities
    ) ORDER BY total_city_stock DESC, facility_count DESC
  ) INTO v_result
  FROM city_grouped;

  RETURN jsonb_build_object(
    'success', true,
    'cities', coalesce(v_result, '[]'::jsonb)
  );
END;
$$;
