-- Reduce per-slot inventory round trips without changing production formulas or slot order.

CREATE OR REPLACE FUNCTION public.process_field_farm_production_entry(
  p_player_id uuid,
  p_owner_kind text,
  p_owner_id uuid,
  p_tick_minutes integer DEFAULT 10,
  p_max_ticks integer DEFAULT 6
)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path TO 'public'
AS $function$
DECLARE
  v_now timestamptz := timezone('utc'::text, now());
  v_processed_count integer := 0;
  v_produced_count integer := 0;
  v_pending_only_count integer := 0;
  v_skipped_count integer := 0;
  v_total_produced integer := 0;
  v_ticks integer;
  v_processed_until timestamptz;
  v_rate_per_tick numeric;
  v_raw_output numeric;
  v_whole_output integer;
  v_owner_total_output integer;
  v_available_output_capacity integer;
  v_tentative_output integer;
  v_actual_output integer;
  v_pending_after numeric;
  v_h1_max integer;
  v_h2_max integer;
  v_h3_max integer;
  v_h1_required integer;
  v_h2_required integer;
  v_h3_required integer;
  v_h1_cost numeric;
  v_h2_cost numeric;
  v_h3_cost numeric;
  v_total_input_cost numeric;
  v_total_labor_cost numeric;
  v_total_production_cost numeric;
  v_output_cost_after numeric;
  v_output_quantity_after integer;
  v_boost_bonus_minutes numeric;
  v_effective_ticks numeric;
  v_row record;
BEGIN
  IF p_player_id IS NULL THEN
    RAISE EXCEPTION 'Oturum acilmamis.';
  END IF;

  PERFORM pg_advisory_xact_lock(
    hashtext('field_farm_production_entry:' || p_player_id::text)
  );

  FOR v_row IN
    SELECT
      ps.id AS production_slot_id,
      ps.owner_kind,
      ps.owner_id,
      ps.slot_index,
      ps.product_id,
      ps.quality_level,
      ps.last_production_at,
      CASE
        WHEN ps.owner_kind = 'field' THEN f.output_capacity
        WHEN ps.owner_kind = 'farm' THEN fa.output_capacity
      END AS owner_output_capacity,
      p.uretim_adedi,
      coalesce(p.iscilik_maliyeti, 0) AS iscilik_maliyeti,
      nullif(p.hammadde_1_id, '') AS h1_id,
      coalesce(p.hammadde_1_miktar, 0) AS h1_per_unit,
      nullif(p.hammadde_2_id, '') AS h2_id,
      coalesce(p.hammadde_2_miktar, 0) AS h2_per_unit,
      nullif(p.hammadde_3_id, '') AS h3_id,
      coalesce(p.hammadde_3_miktar, 0) AS h3_per_unit,
      out_pi.id AS output_inventory_id,
      out_pi.quantity AS output_quantity,
      coalesce(out_pi.pending_quantity, 0) AS output_pending_quantity,
      coalesce(out_pi.cost, 0) AS output_cost,
      coalesce(
        (
          to_jsonb(c) ->> (
            'bonus_' || lower(
              replace(
                replace(
                  replace(
                    replace(
                      replace(
                        replace(p.kategori, ' ', '_'),
                        'ı', 'i'
                      ),
                      'ğ', 'g'
                    ),
                    'ş', 's'
                  ),
                  'ü', 'u'
                ),
                'ö', 'o'
              )
            )
          )
        )::numeric,
        1.0
      ) AS city_bonus
    FROM public.production_slots ps
    JOIN public.products p ON p.id = ps.product_id
    LEFT JOIN public.fields f
      ON ps.owner_kind = 'field' AND f.id = ps.owner_id
    LEFT JOIN public.farms fa
      ON ps.owner_kind = 'farm' AND fa.id = ps.owner_id
    LEFT JOIN public.cities c
      ON c.id = CASE
        WHEN ps.owner_kind = 'field' THEN f.city_id
        WHEN ps.owner_kind = 'farm' THEN fa.city_id
      END
    JOIN public.production_inventory out_pi
      ON out_pi.owner_kind = ps.owner_kind
      AND out_pi.owner_id = ps.owner_id
      AND out_pi.inventory_type = 'output'
      AND out_pi.product_id = ps.product_id
      AND out_pi.quality_level = ps.quality_level
    WHERE ps.is_active = true
      AND ps.owner_kind IN ('field', 'farm')
      AND ps.product_id IS NOT NULL
      AND ps.quality_level BETWEEN 1 AND 5
      AND coalesce(p.uretim_adedi, 0) > 0
      AND (
        (ps.owner_kind = 'field' AND f.player_id = p_player_id AND f.is_active = true)
        OR
        (ps.owner_kind = 'farm' AND fa.player_id = p_player_id AND fa.is_active = true)
      )
      AND (p_owner_kind IS NULL OR ps.owner_kind = p_owner_kind)
      AND (p_owner_id IS NULL OR ps.owner_id = p_owner_id)
    ORDER BY ps.owner_kind, ps.owner_id, ps.slot_index, ps.id
  LOOP
    v_ticks := floor(
      extract(epoch FROM (v_now - coalesce(v_row.last_production_at, v_now)))
      / greatest(p_tick_minutes * 60, 60)
    )::integer;
    v_ticks := greatest(least(v_ticks, p_max_ticks), 0);

    IF v_ticks <= 0 THEN
      CONTINUE;
    END IF;

    v_processed_count := v_processed_count + 1;
    v_processed_until := coalesce(v_row.last_production_at, v_now)
      + make_interval(mins => p_tick_minutes * v_ticks);

    SELECT coalesce(sum(quantity), 0)::integer
    INTO v_owner_total_output
    FROM public.production_inventory
    WHERE owner_kind = v_row.owner_kind
      AND owner_id = v_row.owner_id
      AND inventory_type = 'output';

    v_available_output_capacity := greatest(
      coalesce(v_row.owner_output_capacity, 0) - coalesce(v_owner_total_output, 0),
      0
    );

    IF v_available_output_capacity <= 0 THEN
      UPDATE public.production_slots
      SET last_production_at = v_processed_until,
          updated_at = timezone('utc'::text, now())
      WHERE id = v_row.production_slot_id;

      v_skipped_count := v_skipped_count + 1;
      CONTINUE;
    END IF;

    SELECT coalesce(
      sum(
        greatest(
          extract(
            epoch FROM least(
              coalesce(bb.completed_at, bb.finish_at, v_processed_until),
              v_processed_until
            ) - greatest(bb.started_at, v_row.last_production_at)
          ) / 60.0,
          0
        ) * greatest(coalesce(bb.multiplier, 1) - 1, 0)
      ),
      0
    )
    INTO v_boost_bonus_minutes
    FROM public.building_boosts bb
    WHERE bb.player_id = p_player_id
      AND bb.building_kind = v_row.owner_kind
      AND bb.entity_id = v_row.owner_id
      AND bb.started_at < v_processed_until
      AND coalesce(bb.completed_at, bb.finish_at, v_processed_until)
        > v_row.last_production_at;

    v_effective_ticks := greatest(
      0,
      (
        (p_tick_minutes * v_ticks)::numeric + coalesce(v_boost_bonus_minutes, 0)
      ) / greatest(p_tick_minutes, 1)::numeric
    );

    v_rate_per_tick := (coalesce(v_row.uretim_adedi, 0)::numeric / 6)
      * (1.0 + (v_row.quality_level - 1) * 0.20)
      * coalesce(v_row.city_bonus, 1.0);
    v_raw_output := coalesce(v_row.output_pending_quantity, 0)
      + (v_rate_per_tick * v_effective_ticks);
    v_whole_output := floor(v_raw_output)::integer;

    IF v_whole_output <= 0 THEN
      UPDATE public.production_inventory
      SET pending_quantity = v_raw_output
      WHERE id = v_row.output_inventory_id;

      UPDATE public.production_slots
      SET last_production_at = v_processed_until,
          updated_at = timezone('utc'::text, now())
      WHERE id = v_row.production_slot_id;

      v_pending_only_count := v_pending_only_count + 1;
      CONTINUE;
    END IF;

    v_tentative_output := least(v_whole_output, v_available_output_capacity);

    -- Lock all input rows in one deterministic pass, then read their values together.
    WITH locked_inputs AS MATERIALIZED (
      SELECT product_id, quantity, cost
      FROM public.production_inventory
      WHERE owner_kind = v_row.owner_kind
        AND owner_id = v_row.owner_id
        AND inventory_type = 'input'
        AND quality_level = greatest(v_row.quality_level - 1, 1)
        AND product_id = ANY (
          array_remove(
            ARRAY[v_row.h1_id, v_row.h2_id, v_row.h3_id],
            NULL
          )
        )
      ORDER BY product_id, quality_level, id
      FOR UPDATE
    )
    SELECT
      coalesce(max(quantity) FILTER (WHERE product_id = v_row.h1_id), 0)::integer,
      coalesce(max(cost) FILTER (WHERE product_id = v_row.h1_id), 0),
      coalesce(max(quantity) FILTER (WHERE product_id = v_row.h2_id), 0)::integer,
      coalesce(max(cost) FILTER (WHERE product_id = v_row.h2_id), 0),
      coalesce(max(quantity) FILTER (WHERE product_id = v_row.h3_id), 0)::integer,
      coalesce(max(cost) FILTER (WHERE product_id = v_row.h3_id), 0)
    INTO
      v_h1_max,
      v_h1_cost,
      v_h2_max,
      v_h2_cost,
      v_h3_max,
      v_h3_cost
    FROM locked_inputs;

    v_h1_max := CASE
      WHEN v_row.h1_id IS NOT NULL AND v_row.h1_per_unit > 0
        THEN floor(coalesce(v_h1_max, 0) / v_row.h1_per_unit)::integer
      ELSE v_tentative_output
    END;
    v_h2_max := CASE
      WHEN v_row.h2_id IS NOT NULL AND v_row.h2_per_unit > 0
        THEN floor(coalesce(v_h2_max, 0) / v_row.h2_per_unit)::integer
      ELSE v_tentative_output
    END;
    v_h3_max := CASE
      WHEN v_row.h3_id IS NOT NULL AND v_row.h3_per_unit > 0
        THEN floor(coalesce(v_h3_max, 0) / v_row.h3_per_unit)::integer
      ELSE v_tentative_output
    END;

    v_actual_output := greatest(
      least(v_tentative_output, v_h1_max, v_h2_max, v_h3_max),
      0
    );

    IF v_actual_output <= 0 THEN
      UPDATE public.production_slots
      SET last_production_at = v_processed_until,
          updated_at = timezone('utc'::text, now())
      WHERE id = v_row.production_slot_id;

      v_skipped_count := v_skipped_count + 1;
      CONTINUE;
    END IF;

    v_h1_required := CASE
      WHEN v_row.h1_id IS NOT NULL AND v_row.h1_per_unit > 0
        THEN ceil(v_actual_output * v_row.h1_per_unit)::integer
      ELSE 0
    END;
    v_h2_required := CASE
      WHEN v_row.h2_id IS NOT NULL AND v_row.h2_per_unit > 0
        THEN ceil(v_actual_output * v_row.h2_per_unit)::integer
      ELSE 0
    END;
    v_h3_required := CASE
      WHEN v_row.h3_id IS NOT NULL AND v_row.h3_per_unit > 0
        THEN ceil(v_actual_output * v_row.h3_per_unit)::integer
      ELSE 0
    END;

    -- Preserve the same total consumption while updating all input rows once.
    WITH input_requirements(product_id, required_quantity) AS (
      VALUES
        (v_row.h1_id, v_h1_required),
        (v_row.h2_id, v_h2_required),
        (v_row.h3_id, v_h3_required)
    ), grouped_requirements AS (
      SELECT product_id, sum(required_quantity)::integer AS required_quantity
      FROM input_requirements
      WHERE product_id IS NOT NULL
        AND required_quantity > 0
      GROUP BY product_id
    )
    UPDATE public.production_inventory pi
    SET quantity = pi.quantity - requirement.required_quantity
    FROM grouped_requirements requirement
    WHERE pi.owner_kind = v_row.owner_kind
      AND pi.owner_id = v_row.owner_id
      AND pi.inventory_type = 'input'
      AND pi.product_id = requirement.product_id
      AND pi.quality_level = greatest(v_row.quality_level - 1, 1);

    v_total_input_cost :=
      (v_h1_required * coalesce(v_h1_cost, 0))
      + (v_h2_required * coalesce(v_h2_cost, 0))
      + (v_h3_required * coalesce(v_h3_cost, 0));
    v_total_labor_cost := v_actual_output * v_row.iscilik_maliyeti;
    v_total_production_cost := (v_total_input_cost * 1.05) + v_total_labor_cost;
    v_pending_after := CASE
      WHEN v_actual_output < v_whole_output THEN 0
      ELSE v_raw_output - v_whole_output
    END;
    v_output_quantity_after := v_row.output_quantity + v_actual_output;
    v_output_cost_after := CASE
      WHEN v_output_quantity_after > 0 THEN (
        (v_row.output_quantity * coalesce(v_row.output_cost, 0))
        + v_total_production_cost
      ) / v_output_quantity_after
      ELSE v_row.output_cost
    END;

    UPDATE public.production_inventory
    SET quantity = v_output_quantity_after,
        pending_quantity = v_pending_after,
        cost = v_output_cost_after
    WHERE id = v_row.output_inventory_id;

    UPDATE public.production_slots
    SET last_production_at = v_processed_until,
        updated_at = timezone('utc'::text, now())
    WHERE id = v_row.production_slot_id;

    IF v_actual_output > 0 THEN
      PERFORM public.upsert_player_daily_production_stat(
        p_player_id,
        v_row.owner_kind,
        v_row.owner_id,
        v_row.product_id,
        v_actual_output,
        v_total_production_cost
      );
    END IF;

    v_produced_count := v_produced_count + 1;
    v_total_produced := v_total_produced + v_actual_output;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'processed_count', v_processed_count,
    'produced_count', v_produced_count,
    'pending_only_count', v_pending_only_count,
    'skipped_count', v_skipped_count,
    'total_produced', v_total_produced
  );
END;
$function$;
