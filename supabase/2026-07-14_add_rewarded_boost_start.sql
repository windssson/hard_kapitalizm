CREATE OR REPLACE FUNCTION public.start_building_boost_with_ad_reward(
  p_player_id uuid,
  p_building_kind text,
  p_entity_id uuid,
  p_duration_minutes integer DEFAULT 30
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_now timestamptz := timezone('utc', now());
  v_finish_at timestamptz;
  v_boost_id uuid;
  v_multiplier numeric := 2.00;
  v_duration_minutes integer := GREATEST(coalesce(p_duration_minutes, 30), 1);
BEGIN
  IF public.is_player_tax_blocked(p_player_id) THEN
    RAISE EXCEPTION 'Vergi borcu limiti asildigi icin boost baslatilamaz.';
  END IF;

  IF p_player_id IS NULL OR p_player_id <> auth.uid() THEN
    RAISE EXCEPTION 'Gecersiz oyuncu.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.building_boosts bb
    WHERE bb.player_id = p_player_id
      AND bb.building_kind = p_building_kind
      AND bb.entity_id = p_entity_id
      AND bb.status = 'in_progress'
      AND coalesce(bb.finish_at, v_now) > v_now
  ) THEN
    RAISE EXCEPTION 'Bu isletme icin zaten aktif bir boost var.';
  END IF;

  IF p_building_kind = 'store' THEN
    IF NOT EXISTS (
      SELECT 1
      FROM public.stores s
      WHERE s.id = p_entity_id
        AND s.player_id = p_player_id
        AND s.is_active = true
    ) THEN
      RAISE EXCEPTION 'Magaza bulunamadi veya aktif degil.';
    END IF;

    UPDATE public.store_slots
    SET
      boost_multiplier = v_multiplier,
      updated_at = v_now
    WHERE store_id = p_entity_id;
  ELSIF p_building_kind IN ('field', 'farm') THEN
    IF NOT EXISTS (
      SELECT 1
      FROM public.production_slots ps
      WHERE ps.owner_kind = p_building_kind
        AND ps.owner_id = p_entity_id
    ) THEN
      RAISE EXCEPTION 'Uretim slotlari bulunamadi.';
    END IF;

    UPDATE public.production_slots
    SET
      boost_multiplier = v_multiplier,
      updated_at = v_now
    WHERE owner_kind = p_building_kind
      AND owner_id = p_entity_id;
  ELSIF p_building_kind = 'factory' THEN
    UPDATE public.factories
    SET
      boost_multiplier = v_multiplier,
      updated_at = v_now
    WHERE id = p_entity_id
      AND player_id = p_player_id
      AND is_active = true;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Fabrika bulunamadi veya aktif degil.';
    END IF;
  ELSIF p_building_kind = 'mine' THEN
    UPDATE public.mines
    SET
      boost_multiplier = v_multiplier,
      updated_at = v_now
    WHERE id = p_entity_id
      AND player_id = p_player_id
      AND is_active = true;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Maden bulunamadi veya aktif degil.';
    END IF;
  ELSE
    RAISE EXCEPTION 'Bu building_kind icin boost destegi henuz yok: %', p_building_kind;
  END IF;

  v_finish_at := v_now + make_interval(mins => v_duration_minutes);

  INSERT INTO public.building_boosts (
    player_id,
    building_kind,
    entity_id,
    duration_hours,
    star_cost,
    multiplier,
    params,
    status,
    started_at,
    finish_at,
    created_at,
    updated_at
  )
  VALUES (
    p_player_id,
    p_building_kind,
    p_entity_id,
    0,
    0,
    v_multiplier,
    jsonb_build_object(
      'duration_hours', 0,
      'duration_minutes', v_duration_minutes,
      'star_cost', 0,
      'reward_source', 'ad',
      'multiplier', v_multiplier
    ),
    'in_progress',
    v_now,
    v_finish_at,
    v_now,
    v_now
  )
  RETURNING id INTO v_boost_id;

  RETURN jsonb_build_object(
    'success', true,
    'boost_id', v_boost_id,
    'building_kind', p_building_kind,
    'entity_id', p_entity_id,
    'duration_minutes', v_duration_minutes,
    'duration_hours', 0,
    'star_cost', 0,
    'multiplier', v_multiplier,
    'finish_at', v_finish_at
  );
END;
$function$;
