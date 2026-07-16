-- Move the read-only hourly income estimate into the home dashboard response.

CREATE OR REPLACE FUNCTION public.get_player_hourly_income_estimate(
  p_player_id uuid
)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  WITH inventory_totals AS (
    SELECT
      owner_kind,
      owner_id,
      coalesce(sum(quantity) FILTER (WHERE inventory_type = 'input'), 0)::numeric
        AS input_quantity,
      coalesce(sum(quantity) FILTER (WHERE inventory_type = 'output'), 0)::numeric
        AS output_quantity
    FROM public.production_inventory
    GROUP BY owner_kind, owner_id
  ),
  active_boosts AS (
    SELECT DISTINCT ON (building_kind, entity_id)
      building_kind,
      entity_id,
      multiplier
    FROM public.building_boosts
    WHERE player_id = p_player_id
      AND status = 'in_progress'
      AND coalesce(finish_at, timezone('utc'::text, now()))
        > timezone('utc'::text, now())
    ORDER BY building_kind, entity_id, started_at DESC, id DESC
  ),
  store_rows AS (
    SELECT
      ss.quantity::numeric AS available_quantity,
      ss.price,
      greatest(coalesce(p.satis_adedi, 0), 0)::numeric
        * (1 + ((greatest(least(ss.quality_level, 5), 1) - 1) * 0.10))
        * CASE
            WHEN ss.brand_id IS NULL
              OR ss.brand_id = '00000000-0000-0000-0000-000000000000'::uuid
              THEN 1.0
            ELSE 1.10
          END
        * CASE
            WHEN coalesce(p.baz_satis_fiyati, 0) <= 0 THEN 1.0
            WHEN ss.price / (
              p.baz_satis_fiyati
              * CASE greatest(least(ss.quality_level, 5), 1)
                  WHEN 2 THEN 1.10
                  WHEN 3 THEN 1.22
                  WHEN 4 THEN 1.35
                  WHEN 5 THEN 1.50
                  ELSE 1.00
                END
            ) <= 1 THEN greatest(
              least(
                1 + (
                  1 - ss.price / (
                    p.baz_satis_fiyati
                    * CASE greatest(least(ss.quality_level, 5), 1)
                        WHEN 2 THEN 1.10
                        WHEN 3 THEN 1.22
                        WHEN 4 THEN 1.35
                        WHEN 5 THEN 1.50
                        ELSE 1.00
                      END
                  )
                ) * 0.75,
                1.75
              ),
              0.05
            )
            ELSE greatest(
              least(
                1 - (
                  ss.price / (
                    p.baz_satis_fiyati
                    * CASE greatest(least(ss.quality_level, 5), 1)
                        WHEN 2 THEN 1.10
                        WHEN 3 THEN 1.22
                        WHEN 4 THEN 1.35
                        WHEN 5 THEN 1.50
                        ELSE 1.00
                      END
                  ) - 1
                ) * 0.95,
                1.75
              ),
              0.05
            )
          END
        * CASE
            WHEN coalesce(ab.multiplier, ss.boost_multiplier, 1) <= 0 THEN 1.0
            ELSE coalesce(ab.multiplier, ss.boost_multiplier, 1)
          END AS estimated_units
    FROM public.stores s
    JOIN public.store_slots ss ON ss.store_id = s.id
    JOIN public.products p ON p.id = ss.product_id
    LEFT JOIN active_boosts ab
      ON ab.building_kind = 'store' AND ab.entity_id = s.id
    WHERE s.player_id = p_player_id
      AND s.is_active = true
      AND ss.is_active = true
      AND ss.product_id IS NOT NULL
      AND ss.quantity > 0
      AND coalesce(ss.price, 0) > 0
      AND coalesce(p.satis_adedi, 0) > 0
  ),
  store_value AS (
    SELECT coalesce(
      sum(least(greatest(estimated_units, 0), available_quantity) * price),
      0
    ) AS value
    FROM store_rows
  ),
  production_rows AS (
    SELECT
      greatest(coalesce(p.uretim_adedi, 0), 0)::numeric AS hourly_units,
      CASE
        WHEN coalesce(p.ortalama_fiyat, 0) > 0 THEN p.ortalama_fiyat
        WHEN coalesce(p.baz_satis_fiyati, 0) > 0 THEN p.baz_satis_fiyati
        ELSE 0
      END AS unit_value,
      CASE
        WHEN coalesce(ab.multiplier, f.boost_multiplier, 1) <= 0 THEN 1.0
        ELSE coalesce(ab.multiplier, f.boost_multiplier, 1)
      END AS multiplier,
      CASE
        WHEN coalesce(f.output_capacity, 0) <= 0 THEN 0
        ELSE least(
          greatest(coalesce(inv.output_quantity, 0) / f.output_capacity, 0),
          1
        )
      END AS output_ratio,
      coalesce(inv.input_quantity, 0) AS input_quantity,
      (
        nullif(p.hammadde_1_id, '') IS NOT NULL
        OR nullif(p.hammadde_2_id, '') IS NOT NULL
        OR nullif(p.hammadde_3_id, '') IS NOT NULL
      ) AS requires_input
    FROM public.factories f
    JOIN public.products p ON p.id = f.product_id
    LEFT JOIN inventory_totals inv
      ON inv.owner_kind = 'factory' AND inv.owner_id = f.id
    LEFT JOIN active_boosts ab
      ON ab.building_kind = 'factory' AND ab.entity_id = f.id
    WHERE f.player_id = p_player_id
      AND f.is_active = true
      AND f.product_id IS NOT NULL

    UNION ALL

    SELECT
      greatest(coalesce(p.uretim_adedi, 0), 0)::numeric,
      CASE
        WHEN coalesce(p.ortalama_fiyat, 0) > 0 THEN p.ortalama_fiyat
        WHEN coalesce(p.baz_satis_fiyati, 0) > 0 THEN p.baz_satis_fiyati
        ELSE 0
      END,
      CASE
        WHEN coalesce(ab.multiplier, m.boost_multiplier, 1) <= 0 THEN 1.0
        ELSE coalesce(ab.multiplier, m.boost_multiplier, 1)
      END,
      CASE
        WHEN coalesce(m.output_capacity, 0) <= 0 THEN 0
        ELSE least(
          greatest(coalesce(inv.output_quantity, 0) / m.output_capacity, 0),
          1
        )
      END,
      0::numeric,
      false
    FROM public.mines m
    JOIN public.products p ON p.id = m.product_id
    LEFT JOIN inventory_totals inv
      ON inv.owner_kind = 'mine' AND inv.owner_id = m.id
    LEFT JOIN active_boosts ab
      ON ab.building_kind = 'mine' AND ab.entity_id = m.id
    WHERE m.player_id = p_player_id
      AND m.is_active = true
      AND m.product_id IS NOT NULL

    UNION ALL

    SELECT
      greatest(coalesce(p.uretim_adedi, 0), 0)::numeric,
      CASE
        WHEN coalesce(p.ortalama_fiyat, 0) > 0 THEN p.ortalama_fiyat
        WHEN coalesce(p.baz_satis_fiyati, 0) > 0 THEN p.baz_satis_fiyati
        ELSE 0
      END,
      1.0::numeric,
      CASE
        WHEN coalesce(f.output_capacity, 0) <= 0 THEN 0
        ELSE least(
          greatest(coalesce(inv.output_quantity, 0) / f.output_capacity, 0),
          1
        )
      END,
      coalesce(inv.input_quantity, 0),
      (
        nullif(p.hammadde_1_id, '') IS NOT NULL
        OR nullif(p.hammadde_2_id, '') IS NOT NULL
        OR nullif(p.hammadde_3_id, '') IS NOT NULL
      )
    FROM public.fields f
    JOIN public.production_slots ps
      ON ps.owner_kind = 'field' AND ps.owner_id = f.id
    JOIN public.products p ON p.id = ps.product_id
    LEFT JOIN inventory_totals inv
      ON inv.owner_kind = 'field' AND inv.owner_id = f.id
    WHERE f.player_id = p_player_id
      AND f.is_active = true
      AND ps.is_active = true
      AND ps.product_id IS NOT NULL

    UNION ALL

    SELECT
      greatest(coalesce(p.uretim_adedi, 0), 0)::numeric,
      CASE
        WHEN coalesce(p.ortalama_fiyat, 0) > 0 THEN p.ortalama_fiyat
        WHEN coalesce(p.baz_satis_fiyati, 0) > 0 THEN p.baz_satis_fiyati
        ELSE 0
      END,
      1.0::numeric,
      CASE
        WHEN coalesce(f.output_capacity, 0) <= 0 THEN 0
        ELSE least(
          greatest(coalesce(inv.output_quantity, 0) / f.output_capacity, 0),
          1
        )
      END,
      coalesce(inv.input_quantity, 0),
      (
        nullif(p.hammadde_1_id, '') IS NOT NULL
        OR nullif(p.hammadde_2_id, '') IS NOT NULL
        OR nullif(p.hammadde_3_id, '') IS NOT NULL
      )
    FROM public.farms f
    JOIN public.production_slots ps
      ON ps.owner_kind = 'farm' AND ps.owner_id = f.id
    JOIN public.products p ON p.id = ps.product_id
    LEFT JOIN inventory_totals inv
      ON inv.owner_kind = 'farm' AND inv.owner_id = f.id
    WHERE f.player_id = p_player_id
      AND f.is_active = true
      AND ps.is_active = true
      AND ps.product_id IS NOT NULL
  ),
  production_value AS (
    SELECT coalesce(sum(
      hourly_units * unit_value * multiplier * (1 - output_ratio)
    ), 0) AS value
    FROM production_rows
    WHERE output_ratio < 0.98
      AND (requires_input = false OR input_quantity > 0)
  )
  SELECT jsonb_build_object(
    'total', store_value.value + production_value.value,
    'store_revenue', store_value.value,
    'production_value', production_value.value
  )
  FROM store_value
  CROSS JOIN production_value;
$function$;

CREATE OR REPLACE FUNCTION public.get_homepage_dashboard_v2()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_player_id uuid := auth.uid();
  v_dashboard jsonb;
BEGIN
  IF v_player_id IS NULL THEN
    RAISE EXCEPTION 'Oturum acilmamis.';
  END IF;

  v_dashboard := public.get_homepage_dashboard();

  RETURN v_dashboard || jsonb_build_object(
    'hourly_income_estimate',
    public.get_player_hourly_income_estimate(v_player_id)
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.get_player_hourly_income_estimate(uuid)
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_player_hourly_income_estimate(uuid)
TO service_role;

REVOKE ALL ON FUNCTION public.get_homepage_dashboard_v2()
FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_homepage_dashboard_v2()
TO authenticated, service_role;
