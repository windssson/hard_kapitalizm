CREATE OR REPLACE FUNCTION public.reduce_construction_time_with_ad(
  p_player_id uuid,
  p_construction_id uuid,
  p_minutes integer DEFAULT 10
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_construction public.building_constructions%ROWTYPE;
  v_now timestamptz := timezone('utc'::text, now());
  v_new_finish_at timestamptz;
BEGIN
  IF p_player_id IS NULL OR p_player_id <> auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'message', 'Gecersiz oyuncu.');
  END IF;

  SELECT *
  INTO v_construction
  FROM public.building_constructions
  WHERE id = p_construction_id
    AND player_id = p_player_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Insaat kaydi bulunamadi.');
  END IF;

  IF v_construction.status <> 'in_progress' THEN
    RETURN jsonb_build_object(
      'success',
      false,
      'message',
      'Bu insaat reklam odulu ile kisaltilabilir durumda degil.'
    );
  END IF;

  v_new_finish_at := v_construction.finish_at - make_interval(mins => GREATEST(p_minutes, 1));

  IF v_new_finish_at <= v_now THEN
    UPDATE public.building_constructions
    SET finish_at = v_now - interval '1 second'
    WHERE id = p_construction_id;

    RETURN public.complete_building_construction(p_player_id, p_construction_id)
      || jsonb_build_object('time_reduced_minutes', GREATEST(p_minutes, 1));
  END IF;

  UPDATE public.building_constructions
  SET finish_at = v_new_finish_at
  WHERE id = p_construction_id;

  RETURN jsonb_build_object(
    'success', true,
    'construction_id', p_construction_id,
    'time_reduced_minutes', GREATEST(p_minutes, 1),
    'new_finish_at', v_new_finish_at
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.reduce_building_upgrade_time_with_ad(
  p_player_id uuid,
  p_upgrade_id uuid,
  p_minutes integer DEFAULT 10
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_upgrade public.building_upgrades%ROWTYPE;
  v_now timestamptz := timezone('utc'::text, now());
  v_new_finish_at timestamptz;
  v_result jsonb;
BEGIN
  IF p_player_id IS NULL OR p_player_id <> auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'message', 'Gecersiz oyuncu.');
  END IF;

  SELECT *
  INTO v_upgrade
  FROM public.building_upgrades
  WHERE id = p_upgrade_id
    AND player_id = p_player_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Yukseltme bulunamadi.');
  END IF;

  IF v_upgrade.status <> 'in_progress' THEN
    RETURN jsonb_build_object(
      'success',
      false,
      'message',
      'Bu yukseltme reklam odulu ile kisaltilabilir durumda degil.'
    );
  END IF;

  v_new_finish_at := v_upgrade.finish_at - make_interval(mins => GREATEST(p_minutes, 1));

  IF v_new_finish_at <= v_now THEN
    UPDATE public.building_upgrades
    SET
      finish_at = v_now,
      updated_at = v_now
    WHERE id = p_upgrade_id;

    v_result := public.complete_building_upgrade(p_player_id, p_upgrade_id);
    RETURN v_result || jsonb_build_object('time_reduced_minutes', GREATEST(p_minutes, 1));
  END IF;

  UPDATE public.building_upgrades
  SET
    finish_at = v_new_finish_at,
    updated_at = v_now
  WHERE id = p_upgrade_id;

  RETURN jsonb_build_object(
    'success', true,
    'upgrade_id', p_upgrade_id,
    'entity_id', v_upgrade.entity_id,
    'time_reduced_minutes', GREATEST(p_minutes, 1),
    'new_finish_at', v_new_finish_at
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.reduce_warehouse_upgrade_time_with_ad(
  p_player_id uuid,
  p_upgrade_id uuid,
  p_minutes integer DEFAULT 10
)
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT public.reduce_building_upgrade_time_with_ad(
    p_player_id,
    p_upgrade_id,
    p_minutes
  );
$function$;
