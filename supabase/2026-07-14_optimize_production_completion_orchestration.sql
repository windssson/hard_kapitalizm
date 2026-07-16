-- Complete global building timers once per batch while keeping login processing player-scoped.

CREATE INDEX IF NOT EXISTS idx_building_boosts_due
ON public.building_boosts (finish_at, id)
WHERE status = 'in_progress';

CREATE INDEX IF NOT EXISTS idx_building_boosts_player_due
ON public.building_boosts (player_id, finish_at, id)
WHERE status = 'in_progress';

CREATE INDEX IF NOT EXISTS idx_building_upgrades_due
ON public.building_upgrades (finish_at, id)
WHERE status = 'in_progress';

CREATE INDEX IF NOT EXISTS idx_building_upgrades_player_due
ON public.building_upgrades (player_id, finish_at, id)
WHERE status = 'in_progress';

CREATE OR REPLACE FUNCTION public.complete_due_player_building_boosts(
  p_player_id uuid,
  p_limit integer DEFAULT 100
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_row record;
  v_completed_count integer := 0;
  v_failed_count integer := 0;
  v_result jsonb;
BEGIN
  IF p_player_id IS NULL THEN
    RAISE EXCEPTION 'Oyuncu kimligi gerekli.';
  END IF;

  FOR v_row IN
    SELECT id
    FROM public.building_boosts
    WHERE player_id = p_player_id
      AND status = 'in_progress'
      AND finish_at <= timezone('utc'::text, now())
    ORDER BY finish_at, id
    LIMIT greatest(coalesce(p_limit, 100), 1)
    FOR UPDATE SKIP LOCKED
  LOOP
    BEGIN
      SELECT public.finish_building_boost(p_player_id, v_row.id)
      INTO v_result;
      v_completed_count := v_completed_count + 1;
    EXCEPTION WHEN OTHERS THEN
      v_failed_count := v_failed_count + 1;
    END;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'completed_count', v_completed_count,
    'failed_count', v_failed_count
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.complete_due_player_building_upgrades(
  p_player_id uuid,
  p_limit integer DEFAULT 100,
  p_building_kind text DEFAULT NULL,
  p_entity_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_row record;
  v_completed_count integer := 0;
  v_failed_count integer := 0;
  v_result jsonb;
BEGIN
  IF p_player_id IS NULL THEN
    RAISE EXCEPTION 'Oyuncu kimligi gerekli.';
  END IF;

  FOR v_row IN
    SELECT id
    FROM public.building_upgrades
    WHERE player_id = p_player_id
      AND status = 'in_progress'
      AND finish_at <= timezone('utc'::text, now())
      AND (p_building_kind IS NULL OR building_kind = p_building_kind)
      AND (p_entity_id IS NULL OR entity_id = p_entity_id)
    ORDER BY finish_at, id
    LIMIT greatest(coalesce(p_limit, 100), 1)
    FOR UPDATE SKIP LOCKED
  LOOP
    BEGIN
      SELECT public.complete_building_upgrade(p_player_id, v_row.id)
      INTO v_result;
      v_completed_count := v_completed_count + 1;
    EXCEPTION WHEN OTHERS THEN
      v_failed_count := v_failed_count + 1;
    END;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'completed_count', v_completed_count,
    'failed_count', v_failed_count
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.process_player_production_core(
  p_player_id uuid,
  p_owner_kind text DEFAULT NULL,
  p_owner_id uuid DEFAULT NULL
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

  IF p_owner_kind IS NULL OR p_owner_kind = 'factory' THEN
    v_factory_result := public.process_factory_production_entry(
      p_player_id,
      CASE WHEN p_owner_kind = 'factory' THEN p_owner_id ELSE NULL END
    );
  END IF;

  IF p_owner_kind IS NULL OR p_owner_kind IN ('field', 'farm') THEN
    v_field_farm_result := public.process_field_farm_production_entry(
      p_player_id,
      CASE WHEN p_owner_kind IN ('field', 'farm') THEN p_owner_kind ELSE NULL END,
      CASE WHEN p_owner_kind IN ('field', 'farm') THEN p_owner_id ELSE NULL END
    );
  END IF;

  IF p_owner_kind IS NULL OR p_owner_kind = 'mine' THEN
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

CREATE OR REPLACE FUNCTION public.process_player_production_entry(
  p_player_id uuid DEFAULT auth.uid(),
  p_owner_kind text DEFAULT NULL,
  p_owner_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_boosts_result jsonb := jsonb_build_object('success', true, 'completed_count', 0);
  v_upgrades_result jsonb := jsonb_build_object('success', true, 'completed_count', 0);
  v_production_result jsonb;
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

  IF p_owner_kind IS NULL THEN
    v_boosts_result := public.complete_due_player_building_boosts(p_player_id, 100);
    v_upgrades_result := public.complete_due_player_building_upgrades(p_player_id, 100);
  ELSIF p_owner_id IS NOT NULL THEN
    v_upgrades_result := public.complete_due_player_building_upgrades(
      p_player_id,
      100,
      p_owner_kind,
      p_owner_id
    );
  END IF;

  v_production_result := public.process_player_production_core(
    p_player_id,
    p_owner_kind,
    p_owner_id
  );

  RETURN jsonb_build_object(
    'completed_due_building_boosts', CASE
      WHEN p_owner_kind IS NULL THEN v_boosts_result
      ELSE jsonb_build_object('success', true, 'completed_count', 0, 'skipped', true)
    END,
    'completed_due_building_upgrades', v_upgrades_result
  ) || v_production_result;
END;
$function$;

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
  -- These functions scan all players, so execute them once before the player loop.
  v_boosts_result := public.complete_due_building_boosts(1000);
  v_upgrades_result := public.complete_due_building_upgrades(1000);

  FOR v_player_row IN
    SELECT id
    FROM public.players
  LOOP
    BEGIN
      PERFORM public.process_player_production_core(v_player_row.id);
      PERFORM public.build_player_attention_notifications(v_player_row.id);
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

REVOKE ALL ON FUNCTION public.complete_due_player_building_boosts(uuid, integer)
FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.complete_due_player_building_upgrades(uuid, integer, text, uuid)
FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.process_player_production_core(uuid, text, uuid)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.complete_due_player_building_boosts(uuid, integer)
TO service_role;
GRANT EXECUTE ON FUNCTION public.complete_due_player_building_upgrades(uuid, integer, text, uuid)
TO service_role;
GRANT EXECUTE ON FUNCTION public.process_player_production_core(uuid, text, uuid)
TO service_role;
