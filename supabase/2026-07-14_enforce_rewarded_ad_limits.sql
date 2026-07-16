CREATE INDEX IF NOT EXISTS idx_player_rewarded_ad_usages_daily
ON public.player_rewarded_ad_usages (player_id, created_at DESC);

CREATE OR REPLACE FUNCTION public.consume_rewarded_ad_usage_v2(
  p_player_id uuid,
  p_reward_kind text,
  p_cooldown_seconds integer,
  p_daily_limit integer,
  p_metadata jsonb DEFAULT '{}'::jsonb,
  p_resource_key text DEFAULT NULL,
  p_resource_value text DEFAULT NULL,
  p_resource_daily_limit integer DEFAULT NULL
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_now timestamptz := timezone('utc'::text, now());
  v_day_start timestamptz;
  v_day_end timestamptz;
  v_last_used_at timestamptz;
  v_global_count integer;
  v_kind_count integer;
  v_resource_count integer;
BEGIN
  IF p_player_id IS NULL OR p_player_id <> auth.uid() THEN
    RAISE EXCEPTION 'Gecersiz oyuncu.';
  END IF;

  -- Serialize all rewards for one player so parallel requests cannot bypass limits.
  PERFORM pg_advisory_xact_lock(hashtextextended(p_player_id::text, 0));

  v_day_start := date_trunc('day', timezone('Europe/Istanbul', v_now))
    AT TIME ZONE 'Europe/Istanbul';
  v_day_end := v_day_start + interval '1 day';

  SELECT count(*)::integer
  INTO v_global_count
  FROM public.player_rewarded_ad_usages
  WHERE player_id = p_player_id
    AND created_at >= v_day_start
    AND created_at < v_day_end;

  IF v_global_count >= 15 THEN
    RAISE EXCEPTION 'Bugunku toplam 15 reklam odulu limitine ulastin. Yarin tekrar kullanabilirsin.';
  END IF;

  SELECT count(*)::integer, max(created_at)
  INTO v_kind_count, v_last_used_at
  FROM public.player_rewarded_ad_usages
  WHERE player_id = p_player_id
    AND reward_kind = p_reward_kind
    AND created_at >= v_day_start
    AND created_at < v_day_end;

  IF v_kind_count >= GREATEST(p_daily_limit, 0) THEN
    RAISE EXCEPTION 'Bu reklam odulu icin bugunku % kullanim hakkini doldurdun.', p_daily_limit;
  END IF;

  IF p_resource_key IS NOT NULL
     AND p_resource_value IS NOT NULL
     AND p_resource_daily_limit IS NOT NULL THEN
    SELECT count(*)::integer
    INTO v_resource_count
    FROM public.player_rewarded_ad_usages
    WHERE player_id = p_player_id
      AND reward_kind = p_reward_kind
      AND created_at >= v_day_start
      AND created_at < v_day_end
      AND metadata ->> p_resource_key = p_resource_value;

    IF v_resource_count >= GREATEST(p_resource_daily_limit, 0) THEN
      RAISE EXCEPTION 'Bu islem icin bugunku reklam odulu hakkini doldurdun. Baska bir islemde kullanabilir veya yarini bekleyebilirsin.';
    END IF;
  END IF;

  IF v_last_used_at IS NOT NULL
     AND EXTRACT(EPOCH FROM (v_now - v_last_used_at)) < GREATEST(p_cooldown_seconds, 0) THEN
    RAISE EXCEPTION 'Yeni reklam odulu icin % saniye beklemelisin.',
      CEIL(GREATEST(p_cooldown_seconds, 0) - EXTRACT(EPOCH FROM (v_now - v_last_used_at)))::integer;
  END IF;

  INSERT INTO public.player_rewarded_ad_usages (player_id, reward_kind, metadata)
  VALUES (p_player_id, p_reward_kind, coalesce(p_metadata, '{}'::jsonb));

  RETURN v_kind_count + 1;
END;
$function$;

REVOKE ALL ON FUNCTION public.consume_rewarded_ad_usage_v2(
  uuid, text, integer, integer, jsonb, text, text, integer
) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_rewarded_ad_reward_status(
  p_player_id uuid,
  p_reward_kind text,
  p_resource_id text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_now timestamptz := timezone('utc'::text, now());
  v_day_start timestamptz;
  v_day_end timestamptz;
  v_cooldown_seconds integer;
  v_daily_limit integer;
  v_resource_daily_limit integer;
  v_resource_key text;
  v_global_count integer;
  v_kind_count integer;
  v_resource_count integer := 0;
  v_last_used_at timestamptz;
  v_wait_seconds integer := 0;
  v_next_reward_minutes integer;
  v_message text;
BEGIN
  IF p_player_id IS NULL OR p_player_id <> auth.uid() THEN
    RETURN jsonb_build_object('allowed', false, 'message', 'Gecersiz oyuncu.');
  END IF;

  CASE p_reward_kind
    WHEN 'construction_time_reduce' THEN
      v_cooldown_seconds := 45;
      v_daily_limit := 8;
      v_resource_daily_limit := 3;
      v_resource_key := 'construction_id';
    WHEN 'upgrade_time_reduce' THEN
      v_cooldown_seconds := 45;
      v_daily_limit := 8;
      v_resource_daily_limit := 3;
      v_resource_key := 'upgrade_id';
    WHEN 'transfer_finish' THEN
      v_cooldown_seconds := 60;
      v_daily_limit := 4;
    WHEN 'building_boost_start' THEN
      v_cooldown_seconds := 90;
      v_daily_limit := 3;
      v_resource_daily_limit := 1;
      v_resource_key := 'resource_id';
    ELSE
      RETURN jsonb_build_object('allowed', false, 'message', 'Bilinmeyen reklam odulu turu.');
  END CASE;

  v_day_start := date_trunc('day', timezone('Europe/Istanbul', v_now))
    AT TIME ZONE 'Europe/Istanbul';
  v_day_end := v_day_start + interval '1 day';

  SELECT count(*)::integer
  INTO v_global_count
  FROM public.player_rewarded_ad_usages
  WHERE player_id = p_player_id
    AND created_at >= v_day_start
    AND created_at < v_day_end;

  SELECT count(*)::integer, max(created_at)
  INTO v_kind_count, v_last_used_at
  FROM public.player_rewarded_ad_usages
  WHERE player_id = p_player_id
    AND reward_kind = p_reward_kind
    AND created_at >= v_day_start
    AND created_at < v_day_end;

  IF v_resource_key IS NOT NULL AND p_resource_id IS NOT NULL THEN
    SELECT count(*)::integer
    INTO v_resource_count
    FROM public.player_rewarded_ad_usages
    WHERE player_id = p_player_id
      AND reward_kind = p_reward_kind
      AND created_at >= v_day_start
      AND created_at < v_day_end
      AND metadata ->> v_resource_key = p_resource_id;
  END IF;

  IF v_last_used_at IS NOT NULL THEN
    v_wait_seconds := GREATEST(
      CEIL(v_cooldown_seconds - EXTRACT(EPOCH FROM (v_now - v_last_used_at)))::integer,
      0
    );
  END IF;

  IF p_reward_kind IN ('construction_time_reduce', 'upgrade_time_reduce') THEN
    v_next_reward_minutes := CASE
      WHEN v_kind_count < 4 THEN 10
      WHEN v_kind_count < 6 THEN 7
      WHEN v_kind_count < 8 THEN 5
      ELSE 0
    END;
  ELSIF p_reward_kind = 'building_boost_start' THEN
    v_next_reward_minutes := 30;
  END IF;

  v_message := CASE
    WHEN v_global_count >= 15
      THEN 'Bugunku toplam 15 reklam odulu limitine ulastin. Yarin tekrar kullanabilirsin.'
    WHEN v_kind_count >= v_daily_limit
      THEN format('Bu reklam odulu icin bugunku %s kullanim hakkini doldurdun.', v_daily_limit)
    WHEN v_resource_daily_limit IS NOT NULL AND v_resource_count >= v_resource_daily_limit
      THEN 'Bu islem icin bugunku reklam odulu hakkini doldurdun. Baska bir islemde kullanabilir veya yarini bekleyebilirsin.'
    WHEN v_wait_seconds > 0
      THEN format('Yeni reklam odulu icin %s saniye beklemelisin.', v_wait_seconds)
    ELSE 'Reklam odulu kullanilabilir.'
  END;

  RETURN jsonb_build_object(
    'allowed', v_global_count < 15
      AND v_kind_count < v_daily_limit
      AND (v_resource_daily_limit IS NULL OR v_resource_count < v_resource_daily_limit)
      AND v_wait_seconds = 0,
    'message', v_message,
    'daily_used', v_kind_count,
    'daily_limit', v_daily_limit,
    'global_daily_used', v_global_count,
    'global_daily_limit', 15,
    'resource_daily_used', v_resource_count,
    'resource_daily_limit', v_resource_daily_limit,
    'cooldown_remaining_seconds', v_wait_seconds,
    'next_reward_minutes', v_next_reward_minutes
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.get_rewarded_ad_reward_status(uuid, text, text)
FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_rewarded_ad_reward_status(uuid, text, text)
TO authenticated;

CREATE OR REPLACE FUNCTION public.finish_logistics_transfer_with_ad_reward(
  p_transfer_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_player_id uuid := auth.uid();
  v_transfer public.logistics_transfers%ROWTYPE;
  v_remaining_seconds integer;
  v_usage_number integer;
BEGIN
  IF v_player_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Oturum acilmamis.');
  END IF;

  SELECT * INTO v_transfer
  FROM public.logistics_transfers
  WHERE id = p_transfer_id AND buyer_player_id = v_player_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Transfer kaydi bulunamadi.');
  END IF;
  IF v_transfer.status = 'completed' THEN
    RETURN jsonb_build_object('success', false, 'message', 'Bu transfer zaten tamamlanmis.');
  END IF;
  IF v_transfer.status <> 'in_transit' THEN
    RETURN jsonb_build_object('success', false, 'message', 'Bu transfer reklam odulu ile tamamlanabilir durumda degil.');
  END IF;

  v_remaining_seconds := GREATEST(
    CEIL(EXTRACT(EPOCH FROM (v_transfer.finish_at - timezone('utc'::text, now()))))::integer,
    0
  );
  IF v_remaining_seconds > 600 THEN
    RETURN jsonb_build_object('success', false, 'message', 'Reklamla hizli tamamlama sadece son 10 dakika icindeki transferlerde kullanilabilir.');
  END IF;

  v_usage_number := public.consume_rewarded_ad_usage_v2(
    v_player_id, 'transfer_finish', 60, 4,
    jsonb_build_object('transfer_id', p_transfer_id)
  );

  UPDATE public.logistics_transfers
  SET finish_at = timezone('utc'::text, now()) - interval '1 second'
  WHERE id = p_transfer_id;

  RETURN public.complete_logistics_transfer(p_transfer_id)
    || jsonb_build_object('reward_daily_usage', v_usage_number, 'reward_daily_limit', 4);
END;
$function$;

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
  v_usage_number integer;
  v_reduction_minutes integer;
  v_result jsonb;
BEGIN
  IF p_player_id IS NULL OR p_player_id <> auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'message', 'Gecersiz oyuncu.');
  END IF;

  SELECT * INTO v_construction
  FROM public.building_constructions
  WHERE id = p_construction_id AND player_id = p_player_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Insaat kaydi bulunamadi.');
  END IF;
  IF v_construction.status <> 'in_progress' THEN
    RETURN jsonb_build_object('success', false, 'message', 'Bu insaat reklam odulu ile kisaltilabilir durumda degil.');
  END IF;

  v_usage_number := public.consume_rewarded_ad_usage_v2(
    p_player_id, 'construction_time_reduce', 45, 8,
    jsonb_build_object('construction_id', p_construction_id),
    'construction_id', p_construction_id::text, 3
  );
  v_reduction_minutes := CASE
    WHEN v_usage_number <= 4 THEN 10
    WHEN v_usage_number <= 6 THEN 7
    ELSE 5
  END;
  v_new_finish_at := v_construction.finish_at - make_interval(mins => v_reduction_minutes);

  IF v_new_finish_at <= v_now THEN
    UPDATE public.building_constructions
    SET finish_at = v_now - interval '1 second'
    WHERE id = p_construction_id;
    v_result := public.complete_building_construction(p_player_id, p_construction_id);
  ELSE
    UPDATE public.building_constructions
    SET finish_at = v_new_finish_at
    WHERE id = p_construction_id;
    v_result := jsonb_build_object(
      'success', true,
      'construction_id', p_construction_id,
      'new_finish_at', v_new_finish_at
    );
  END IF;

  RETURN v_result || jsonb_build_object(
    'time_reduced_minutes', v_reduction_minutes,
    'message', format('Insaat suresi %s dakika kisaltildi.', v_reduction_minutes),
    'reward_daily_usage', v_usage_number,
    'reward_daily_limit', 8
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
  v_usage_number integer;
  v_reduction_minutes integer;
BEGIN
  IF p_player_id IS NULL OR p_player_id <> auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'message', 'Gecersiz oyuncu.');
  END IF;

  SELECT * INTO v_upgrade
  FROM public.building_upgrades
  WHERE id = p_upgrade_id AND player_id = p_player_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Yukseltme bulunamadi.');
  END IF;
  IF v_upgrade.status <> 'in_progress' THEN
    RETURN jsonb_build_object('success', false, 'message', 'Bu yukseltme reklam odulu ile kisaltilabilir durumda degil.');
  END IF;

  v_usage_number := public.consume_rewarded_ad_usage_v2(
    p_player_id, 'upgrade_time_reduce', 45, 8,
    jsonb_build_object('upgrade_id', p_upgrade_id),
    'upgrade_id', p_upgrade_id::text, 3
  );
  v_reduction_minutes := CASE
    WHEN v_usage_number <= 4 THEN 10
    WHEN v_usage_number <= 6 THEN 7
    ELSE 5
  END;
  v_new_finish_at := v_upgrade.finish_at - make_interval(mins => v_reduction_minutes);

  IF v_new_finish_at <= v_now THEN
    UPDATE public.building_upgrades
    SET finish_at = v_now, updated_at = v_now
    WHERE id = p_upgrade_id;
    v_result := public.complete_building_upgrade(p_player_id, p_upgrade_id);
  ELSE
    UPDATE public.building_upgrades
    SET finish_at = v_new_finish_at, updated_at = v_now
    WHERE id = p_upgrade_id;
    v_result := jsonb_build_object(
      'success', true,
      'upgrade_id', p_upgrade_id,
      'entity_id', v_upgrade.entity_id,
      'new_finish_at', v_new_finish_at
    );
  END IF;

  RETURN v_result || jsonb_build_object(
    'time_reduced_minutes', v_reduction_minutes,
    'message', format('Yukseltme suresi %s dakika kisaltildi.', v_reduction_minutes),
    'reward_daily_usage', v_usage_number,
    'reward_daily_limit', 8
  );
END;
$function$;

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
  v_duration_minutes integer := 30;
  v_usage_number integer;
  v_resource_id text := p_building_kind || ':' || p_entity_id::text;
BEGIN
  IF p_player_id IS NULL OR p_player_id <> auth.uid() THEN
    RAISE EXCEPTION 'Gecersiz oyuncu.';
  END IF;
  IF public.is_player_tax_blocked(p_player_id) THEN
    RAISE EXCEPTION 'Vergi borcu limiti asildigi icin boost baslatilamaz.';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.building_boosts bb
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
      SELECT 1 FROM public.stores s
      WHERE s.id = p_entity_id AND s.player_id = p_player_id AND s.is_active = true
    ) THEN
      RAISE EXCEPTION 'Magaza bulunamadi veya aktif degil.';
    END IF;
  ELSIF p_building_kind IN ('field', 'farm') THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.production_slots ps
      WHERE ps.owner_kind = p_building_kind AND ps.owner_id = p_entity_id
    ) THEN
      RAISE EXCEPTION 'Uretim slotlari bulunamadi.';
    END IF;
  ELSIF p_building_kind = 'factory' THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.factories f
      WHERE f.id = p_entity_id AND f.player_id = p_player_id AND f.is_active = true
    ) THEN
      RAISE EXCEPTION 'Fabrika bulunamadi veya aktif degil.';
    END IF;
  ELSIF p_building_kind = 'mine' THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.mines m
      WHERE m.id = p_entity_id AND m.player_id = p_player_id AND m.is_active = true
    ) THEN
      RAISE EXCEPTION 'Maden bulunamadi veya aktif degil.';
    END IF;
  ELSE
    RAISE EXCEPTION 'Bu building_kind icin boost destegi henuz yok: %', p_building_kind;
  END IF;

  v_usage_number := public.consume_rewarded_ad_usage_v2(
    p_player_id, 'building_boost_start', 90, 3,
    jsonb_build_object(
      'building_kind', p_building_kind,
      'entity_id', p_entity_id,
      'resource_id', v_resource_id,
      'duration_minutes', v_duration_minutes
    ),
    'resource_id', v_resource_id, 1
  );

  IF p_building_kind = 'store' THEN
    UPDATE public.store_slots
    SET boost_multiplier = v_multiplier, updated_at = v_now
    WHERE store_id = p_entity_id;
  ELSIF p_building_kind IN ('field', 'farm') THEN
    UPDATE public.production_slots
    SET boost_multiplier = v_multiplier, updated_at = v_now
    WHERE owner_kind = p_building_kind AND owner_id = p_entity_id;
  ELSIF p_building_kind = 'factory' THEN
    UPDATE public.factories
    SET boost_multiplier = v_multiplier, updated_at = v_now
    WHERE id = p_entity_id AND player_id = p_player_id;
  ELSIF p_building_kind = 'mine' THEN
    UPDATE public.mines
    SET boost_multiplier = v_multiplier, updated_at = v_now
    WHERE id = p_entity_id AND player_id = p_player_id;
  END IF;

  v_finish_at := v_now + interval '30 minutes';
  INSERT INTO public.building_boosts (
    player_id, building_kind, entity_id, duration_hours, star_cost,
    multiplier, params, status, started_at, finish_at, created_at, updated_at
  ) VALUES (
    p_player_id, p_building_kind, p_entity_id, 0, 0,
    v_multiplier,
    jsonb_build_object(
      'duration_hours', 0,
      'duration_minutes', v_duration_minutes,
      'star_cost', 0,
      'reward_source', 'ad',
      'multiplier', v_multiplier
    ),
    'in_progress', v_now, v_finish_at, v_now, v_now
  ) RETURNING id INTO v_boost_id;

  RETURN jsonb_build_object(
    'success', true,
    'boost_id', v_boost_id,
    'building_kind', p_building_kind,
    'entity_id', p_entity_id,
    'duration_minutes', v_duration_minutes,
    'duration_hours', 0,
    'star_cost', 0,
    'multiplier', v_multiplier,
    'finish_at', v_finish_at,
    'reward_daily_usage', v_usage_number,
    'reward_daily_limit', 3
  );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.finish_logistics_transfer_with_ad_reward(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.reduce_construction_time_with_ad(uuid, uuid, integer) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.reduce_building_upgrade_time_with_ad(uuid, uuid, integer) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.reduce_warehouse_upgrade_time_with_ad(uuid, uuid, integer) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.start_building_boost_with_ad_reward(uuid, text, uuid, integer) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.finish_logistics_transfer_with_ad_reward(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reduce_construction_time_with_ad(uuid, uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reduce_building_upgrade_time_with_ad(uuid, uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reduce_warehouse_upgrade_time_with_ad(uuid, uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.start_building_boost_with_ad_reward(uuid, text, uuid, integer) TO authenticated;

DROP FUNCTION IF EXISTS public.consume_rewarded_ad_usage(uuid, text, integer, jsonb);
