-- =========================================================================================
-- MIGRATION: 2026-09-01_optimize_bulk_production_cron.sql
-- Toplu Üretim (process_all_players_production) ve İlgili Üretim Fonksiyonları Performans Optimizasyonu:
-- 1. Hedefe yönelik kısmi (partial) ve bileşik indeksler eklendi.
-- 2. process_all_players_production:
--    - Milyonlarca boş/inaktif oyuncuyu tarayan 'SELECT id FROM players' yerine
--      yalnızca aktif üretimi olan oyuncuları getiren indeksli EXISTS filtresi eklendi.
--    - Döngü içindeki BEGIN...EXCEPTION (PostgreSQL Savepoint/Subtransaction) kaldırıldı.
-- 3. process_player_production_core:
--    - Oyuncunun aktif fabrikası/tarlası/madeni yoksa ilgili alt fonksiyonları çağırmayan
--      hızlı EXISTS guard'ları eklendi.
-- 4. process_field_farm_production_entry:
--    - Tüm veritabanındaki slotları tarayan OR filtreli join yerine, doğrudan oyuncunun
--      aktif tarla/çiftliklerinden başlayan indeksli owners alt sorgusu kuruldu.
-- =========================================================================================

-- 1. İNDEKS OPTİMİZASYONLARI
CREATE INDEX IF NOT EXISTS idx_factories_player_active_prod 
  ON public.factories (player_id) 
  WHERE is_active = true AND product_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_mines_player_active_prod 
  ON public.mines (player_id) 
  WHERE is_active = true AND product_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_fields_player_active 
  ON public.fields (player_id, id) 
  WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_farms_player_active 
  ON public.farms (player_id, id) 
  WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_production_slots_active_by_owner 
  ON public.production_slots (owner_kind, owner_id) 
  WHERE is_active = true AND product_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_building_boosts_active_lookup 
  ON public.building_boosts (player_id, building_kind, entity_id, started_at, finish_at);

-- 2. process_player_production_core OPTİMİZASYONU
CREATE OR REPLACE FUNCTION public.process_player_production_core(
  p_player_id uuid, 
  p_owner_kind text DEFAULT NULL::text, 
  p_owner_id uuid DEFAULT NULL::uuid
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_factory_result jsonb := jsonb_build_object('success', true, 'processed_count', 0, 'produced_count', 0, 'pending_only_count', 0, 'skipped_count', 0, 'total_produced', 0);
  v_field_farm_result jsonb := jsonb_build_object('success', true, 'processed_count', 0, 'produced_count', 0, 'pending_only_count', 0, 'skipped_count', 0, 'total_produced', 0);
  v_mine_result jsonb := jsonb_build_object('success', true, 'processed_count', 0, 'produced_count', 0, 'pending_only_count', 0, 'skipped_count', 0, 'total_produced', 0);
BEGIN
  IF p_player_id IS NULL THEN
    RAISE EXCEPTION 'Oturum acilmamis.';
  END IF;

  IF public.is_player_tax_blocked(p_player_id) THEN
    RETURN jsonb_build_object(
      'success', false,
      'tax_blocked', true,
      'message', 'Vergi borcu limiti asildigi icin uretim donduruldu.'
    );
  END IF;

  -- 1. Fabrika Kontrolü: Sadece aktif fabrikası olanlar için çalıştır
  IF (p_owner_kind IS NULL OR p_owner_kind = 'factory') AND EXISTS (
    SELECT 1 FROM public.factories 
    WHERE player_id = p_player_id 
      AND (p_owner_id IS NULL OR id = p_owner_id)
      AND is_active = true 
      AND product_id IS NOT NULL
  ) THEN
    v_factory_result := public.process_factory_production_entry(
      p_player_id,
      CASE WHEN p_owner_kind = 'factory' THEN p_owner_id ELSE NULL END
    );
  END IF;

  -- 2. Tarla / Çiftlik Kontrolü: Sadece aktif tarlası/çiftliği ve üretim slotu olanlar için çalıştır
  IF (p_owner_kind IS NULL OR p_owner_kind IN ('field', 'farm')) AND (
    EXISTS (
      SELECT 1 FROM public.fields f
      JOIN public.production_slots ps ON ps.owner_kind = 'field' AND ps.owner_id = f.id
      WHERE f.player_id = p_player_id 
        AND (p_owner_id IS NULL OR f.id = p_owner_id)
        AND f.is_active = true 
        AND ps.is_active = true 
        AND ps.product_id IS NOT NULL
    ) OR EXISTS (
      SELECT 1 FROM public.farms fa
      JOIN public.production_slots ps ON ps.owner_kind = 'farm' AND ps.owner_id = fa.id
      WHERE fa.player_id = p_player_id 
        AND (p_owner_id IS NULL OR fa.id = p_owner_id)
        AND fa.is_active = true 
        AND ps.is_active = true 
        AND ps.product_id IS NOT NULL
    )
  ) THEN
    v_field_farm_result := public.process_field_farm_production_entry(
      p_player_id,
      CASE WHEN p_owner_kind IN ('field', 'farm') THEN p_owner_kind ELSE NULL END,
      CASE WHEN p_owner_kind IN ('field', 'farm') THEN p_owner_id ELSE NULL END
    );
  END IF;

  -- 3. Maden Kontrolü: Sadece aktif madeni olanlar için çalıştır
  IF (p_owner_kind IS NULL OR p_owner_kind = 'mine') AND EXISTS (
    SELECT 1 FROM public.mines 
    WHERE player_id = p_player_id 
      AND (p_owner_id IS NULL OR id = p_owner_id)
      AND is_active = true 
      AND product_id IS NOT NULL
  ) THEN
    v_mine_result := public.process_mine_production_entry(
      p_player_id,
      CASE WHEN p_owner_kind = 'mine' THEN p_owner_id ELSE NULL END
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'factory', v_factory_result,
    'field_farm', v_field_farm_result,
    'mine', v_mine_result
  );
END;
$function$;

-- 3. process_field_farm_production_entry OPTİMİZASYONU
CREATE OR REPLACE FUNCTION public.process_field_farm_production_entry(
    p_player_id uuid,
    p_owner_kind text DEFAULT NULL::text,
    p_owner_id uuid DEFAULT NULL::uuid,
    p_tick_minutes integer DEFAULT 10,
    p_max_ticks integer DEFAULT 6
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
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
  v_available_output_capacity integer;
  v_owner_total_output integer;
  v_output_to_produce integer;
  v_tentative_output integer;
  v_pending_after numeric;
  v_h1_required integer;
  v_h2_required integer;
  v_h3_required integer;
  v_h1_quantity integer;
  v_h2_quantity integer;
  v_h3_quantity integer;
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
  v_stat_date date := timezone('Europe/Istanbul'::text, now())::date;
begin
  if p_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  perform pg_advisory_xact_lock(hashtext('field_farm_production_entry:' || p_player_id::text));

  for v_row in
    select
      ps.id as production_slot_id,
      ps.owner_kind,
      ps.owner_id,
      ps.slot_index,
      ps.product_id,
      ps.quality_level,
      ps.brand_id,
      ps.last_production_at,
      owners.output_capacity as owner_output_capacity,
      p.uretim_adedi,
      coalesce(p.iscilik_maliyeti, 0) as iscilik_maliyeti,
      nullif(p.hammadde_1_id, '') as h1_id,
      coalesce(p.hammadde_1_miktar, 0) as h1_per_unit,
      nullif(p.hammadde_2_id, '') as h2_id,
      coalesce(p.hammadde_2_miktar, 0) as h2_per_unit,
      nullif(p.hammadde_3_id, '') as h3_id,
      coalesce(p.hammadde_3_miktar, 0) as h3_per_unit,
      out_pi.id as output_inventory_id,
      out_pi.quantity as output_quantity,
      coalesce(out_pi.pending_quantity, 0) as output_pending_quantity,
      coalesce(out_pi.cost, 0) as output_cost,
      coalesce(
        (to_jsonb(c) ->> ('bonus_' || lower(replace(replace(replace(replace(replace(replace(p.kategori, ' ', '_'), 'ı', 'i'), 'ğ', 'g'), 'ş', 's'), 'ü', 'u'), 'ö', 'o'))))::numeric,
        1.0
      ) as city_bonus
    from (
      select 'field'::text as owner_kind, id as owner_id, city_id, output_capacity
      from public.fields
      where player_id = p_player_id
        and is_active = true
        and (p_owner_kind is null or p_owner_kind = 'field')
        and (p_owner_id is null or id = p_owner_id)
      union all
      select 'farm'::text as owner_kind, id as owner_id, city_id, output_capacity
      from public.farms
      where player_id = p_player_id
        and is_active = true
        and (p_owner_kind is null or p_owner_kind = 'farm')
        and (p_owner_id is null or id = p_owner_id)
    ) owners
    join public.production_slots ps
      on ps.owner_kind = owners.owner_kind
     and ps.owner_id = owners.owner_id
    join public.products p
      on p.id = ps.product_id
    left join public.cities c
      on c.id = owners.city_id
    join public.production_inventory out_pi
      on out_pi.owner_kind = ps.owner_kind
     and out_pi.owner_id = ps.owner_id
     and out_pi.inventory_type = 'output'
     and out_pi.product_id = ps.product_id
     and out_pi.quality_level = ps.quality_level
     and out_pi.brand_id = coalesce(ps.brand_id, '00000000-0000-0000-0000-000000000000'::uuid)
    where ps.is_active = true
      and ps.owner_kind in ('field', 'farm')
      and ps.product_id is not null
      and ps.quality_level between 1 and 5
      and coalesce(p.uretim_adedi, 0) > 0
    order by ps.owner_kind, ps.owner_id, ps.slot_index, ps.id
  loop
    v_ticks := floor(extract(epoch from (v_now - coalesce(v_row.last_production_at, v_now))) / greatest(p_tick_minutes * 60, 60))::integer;
    v_ticks := greatest(least(v_ticks, coalesce(p_max_ticks, v_ticks)), 0);

    if v_ticks <= 0 then
      continue;
    end if;

    v_processed_count := v_processed_count + 1;
    v_processed_until := coalesce(v_row.last_production_at, v_now) + make_interval(mins => p_tick_minutes * v_ticks);

    select coalesce(sum(quantity), 0)::integer
    into v_owner_total_output
    from public.production_inventory
    where owner_kind = v_row.owner_kind
      and owner_id = v_row.owner_id
      and inventory_type = 'output';

    v_available_output_capacity := greatest(coalesce(v_row.owner_output_capacity, 0) - coalesce(v_owner_total_output, 0), 0);

    if v_available_output_capacity <= 0 then
      update public.production_slots
      set last_production_at = v_processed_until,
          updated_at = timezone('utc'::text, now())
      where id = v_row.production_slot_id;

      v_skipped_count := v_skipped_count + 1;
      continue;
    end if;

    select coalesce(sum(greatest(extract(epoch from least(coalesce(bb.completed_at, bb.finish_at, v_processed_until), v_processed_until) - greatest(bb.started_at, v_row.last_production_at)) / 60.0, 0) * greatest(coalesce(bb.multiplier, 1) - 1, 0)), 0)
    into v_boost_bonus_minutes
    from public.building_boosts bb
    where bb.player_id = p_player_id
      and bb.building_kind = v_row.owner_kind
      and bb.entity_id = v_row.owner_id
      and bb.started_at < v_processed_until
      and coalesce(bb.completed_at, bb.finish_at, v_processed_until) > v_row.last_production_at;

    v_effective_ticks := greatest(0, (((p_tick_minutes * v_ticks)::numeric + coalesce(v_boost_bonus_minutes, 0)) / greatest(p_tick_minutes, 1)::numeric));

    v_rate_per_tick := (coalesce(v_row.uretim_adedi, 0)::numeric / 6) * (1.0 + (v_row.quality_level - 1) * 0.20) * coalesce(v_row.city_bonus, 1.0);
    v_raw_output := coalesce(v_row.output_pending_quantity, 0) + (v_rate_per_tick * v_effective_ticks);
    v_whole_output := floor(v_raw_output)::integer;

    if v_whole_output <= 0 then
      update public.production_inventory
      set pending_quantity = v_raw_output
      where id = v_row.output_inventory_id;

      update public.production_slots
      set last_production_at = v_processed_until,
          updated_at = timezone('utc'::text, now())
      where id = v_row.production_slot_id;

      v_pending_only_count := v_pending_only_count + 1;
      continue;
    end if;

    v_tentative_output := least(v_whole_output, v_available_output_capacity);

    with locked_inputs as materialized (
      select product_id, quantity, cost
      from public.production_inventory
      where owner_kind = v_row.owner_kind
        and owner_id = v_row.owner_id
        and inventory_type = 'input'
        and quality_level = greatest(v_row.quality_level - 1, 1)
        and product_id = any (array_remove(array[v_row.h1_id, v_row.h2_id, v_row.h3_id], null))
      order by product_id, quality_level, id
      for update
    )
    select
      coalesce(max(quantity) filter (where product_id = v_row.h1_id), 0)::integer,
      coalesce(max(cost) filter (where product_id = v_row.h1_id), 0),
      coalesce(max(quantity) filter (where product_id = v_row.h2_id), 0)::integer,
      coalesce(max(cost) filter (where product_id = v_row.h2_id), 0),
      coalesce(max(quantity) filter (where product_id = v_row.h3_id), 0)::integer,
      coalesce(max(cost) filter (where product_id = v_row.h3_id), 0)
    into
      v_h1_quantity,
      v_h1_cost,
      v_h2_quantity,
      v_h2_cost,
      v_h3_quantity,
      v_h3_cost
    from locked_inputs;

    v_output_to_produce := v_tentative_output;

    if v_row.h1_id is not null and v_row.h1_per_unit > 0 then
      v_output_to_produce := least(v_output_to_produce, floor(v_h1_quantity::numeric / v_row.h1_per_unit)::integer);
    end if;

    if v_row.h2_id is not null and v_row.h2_per_unit > 0 then
      v_output_to_produce := least(v_output_to_produce, floor(v_h2_quantity::numeric / v_row.h2_per_unit)::integer);
    end if;

    if v_row.h3_id is not null and v_row.h3_per_unit > 0 then
      v_output_to_produce := least(v_output_to_produce, floor(v_h3_quantity::numeric / v_row.h3_per_unit)::integer);
    end if;

    if v_output_to_produce <= 0 then
      update public.production_inventory
      set pending_quantity = v_raw_output
      where id = v_row.output_inventory_id;

      update public.production_slots
      set last_production_at = v_processed_until,
          updated_at = timezone('utc'::text, now())
      where id = v_row.production_slot_id;

      v_skipped_count := v_skipped_count + 1;
      continue;
    end if;

    v_h1_required := case when v_row.h1_id is not null then v_output_to_produce * v_row.h1_per_unit else 0 end;
    v_h2_required := case when v_row.h2_id is not null then v_output_to_produce * v_row.h2_per_unit else 0 end;
    v_h3_required := case when v_row.h3_id is not null then v_output_to_produce * v_row.h3_per_unit else 0 end;

    if v_row.h1_id is not null and v_h1_required > 0 then
      update public.production_inventory
      set quantity = greatest(quantity - v_h1_required, 0)
      where owner_kind = v_row.owner_kind
        and owner_id = v_row.owner_id
        and inventory_type = 'input'
        and product_id = v_row.h1_id
        and quality_level = greatest(v_row.quality_level - 1, 1);
    end if;

    if v_row.h2_id is not null and v_h2_required > 0 then
      update public.production_inventory
      set quantity = greatest(quantity - v_h2_required, 0)
      where owner_kind = v_row.owner_kind
        and owner_id = v_row.owner_id
        and inventory_type = 'input'
        and product_id = v_row.h2_id
        and quality_level = greatest(v_row.quality_level - 1, 1);
    end if;

    if v_row.h3_id is not null and v_h3_required > 0 then
      update public.production_inventory
      set quantity = greatest(quantity - v_h3_required, 0)
      where owner_kind = v_row.owner_kind
        and owner_id = v_row.owner_id
        and inventory_type = 'input'
        and product_id = v_row.h3_id
        and quality_level = greatest(v_row.quality_level - 1, 1);
    end if;

    v_total_input_cost := (v_h1_required * v_h1_cost) + (v_h2_required * v_h2_cost) + (v_h3_required * v_h3_cost);
    v_total_labor_cost := v_output_to_produce * v_row.iscilik_maliyeti;
    v_total_production_cost := v_total_input_cost + v_total_labor_cost;

    v_pending_after := case
      when v_output_to_produce < v_whole_output then 0
      else v_raw_output - v_whole_output
    end;

    v_output_quantity_after := v_row.output_quantity + v_output_to_produce;
    v_output_cost_after := case
      when v_output_quantity_after > 0 then
        ((v_row.output_quantity * v_row.output_cost) + v_total_production_cost) / v_output_quantity_after
      else
        0
    end;

    update public.production_inventory
    set quantity = v_output_quantity_after,
        cost = v_output_cost_after,
        pending_quantity = v_pending_after
    where id = v_row.output_inventory_id;

    update public.production_slots
    set last_production_at = v_processed_until,
        updated_at = timezone('utc'::text, now())
    where id = v_row.production_slot_id;

    perform public.upsert_player_daily_production_stat(
      p_player_id,
      v_row.owner_kind,
      v_row.owner_id,
      v_row.product_id,
      v_output_to_produce,
      v_total_production_cost,
      v_stat_date
    );

    v_produced_count := v_produced_count + 1;
    v_total_produced := v_total_produced + v_output_to_produce;
  end loop;

  return jsonb_build_object(
    'success', true,
    'processed_count', v_processed_count,
    'produced_count', v_produced_count,
    'pending_only_count', v_pending_only_count,
    'skipped_count', v_skipped_count,
    'total_produced', v_total_produced
  );
end;
$function$;

-- 4. process_all_players_production OPTİMİZASYONU
CREATE OR REPLACE FUNCTION public.process_all_players_production()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_player_row record;
  v_processed_count integer := 0;
  v_boosts_result jsonb;
  v_upgrades_result jsonb;
BEGIN
  v_boosts_result := public.complete_due_building_boosts(1000);
  v_upgrades_result := public.complete_due_building_upgrades(1000);

  -- YALNIZCA aktif üretimi olan oyuncuları hedefle
  FOR v_player_row IN
    SELECT DISTINCT p.id
    FROM public.players p
    WHERE EXISTS (
      SELECT 1 FROM public.factories f
      WHERE f.player_id = p.id AND f.is_active = true AND f.product_id IS NOT NULL
    )
    OR EXISTS (
      SELECT 1 FROM public.mines m
      WHERE m.player_id = p.id AND m.is_active = true AND m.product_id IS NOT NULL
    )
    OR EXISTS (
      SELECT 1 FROM public.fields fi
      JOIN public.production_slots ps ON ps.owner_kind = 'field' AND ps.owner_id = fi.id
      WHERE fi.player_id = p.id AND fi.is_active = true AND ps.is_active = true AND ps.product_id IS NOT NULL
    )
    OR EXISTS (
      SELECT 1 FROM public.farms fa
      JOIN public.production_slots ps ON ps.owner_kind = 'farm' AND ps.owner_id = fa.id
      WHERE fa.player_id = p.id AND fa.is_active = true AND ps.is_active = true AND ps.product_id IS NOT NULL
    )
  LOOP
    IF NOT public.is_player_tax_blocked(v_player_row.id) THEN
      PERFORM public.process_player_production_core(v_player_row.id);
      v_processed_count := v_processed_count + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'processed_players_count', v_processed_count,
    'completed_due_building_boosts', v_boosts_result,
    'completed_due_building_upgrades', v_upgrades_result
  );
END;
$function$;
