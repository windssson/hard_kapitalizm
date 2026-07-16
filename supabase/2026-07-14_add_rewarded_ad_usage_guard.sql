CREATE TABLE IF NOT EXISTS public.player_rewarded_ad_usages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id uuid NOT NULL REFERENCES public.players(id) ON DELETE CASCADE,
  reward_kind text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now()),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

ALTER TABLE public.player_rewarded_ad_usages ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.player_rewarded_ad_usages FROM anon, authenticated;

CREATE INDEX IF NOT EXISTS idx_player_rewarded_ad_usages_lookup
ON public.player_rewarded_ad_usages (player_id, reward_kind, created_at DESC);

CREATE OR REPLACE FUNCTION public.consume_rewarded_ad_usage(
  p_player_id uuid,
  p_reward_kind text,
  p_cooldown_seconds integer DEFAULT 5,
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_now timestamptz := timezone('utc'::text, now());
  v_last_used_at timestamptz;
  v_cooldown_seconds integer := GREATEST(coalesce(p_cooldown_seconds, 5), 0);
BEGIN
  IF p_player_id IS NULL OR p_player_id <> auth.uid() THEN
    RAISE EXCEPTION 'Gecersiz oyuncu.';
  END IF;

  SELECT created_at
  INTO v_last_used_at
  FROM public.player_rewarded_ad_usages
  WHERE player_id = p_player_id
    AND reward_kind = p_reward_kind
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_last_used_at IS NOT NULL
     AND EXTRACT(EPOCH FROM (v_now - v_last_used_at)) < v_cooldown_seconds THEN
    RAISE EXCEPTION 'Reklam odulu cok hizli tekrar kullanilamaz. Lutfen birkaç saniye bekleyin.';
  END IF;

  INSERT INTO public.player_rewarded_ad_usages (
    player_id,
    reward_kind,
    metadata
  )
  VALUES (
    p_player_id,
    p_reward_kind,
    coalesce(p_metadata, '{}'::jsonb)
  );
END;
$function$;

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
BEGIN
  IF v_player_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Oturum acilmamis.');
  END IF;

  SELECT *
  INTO v_transfer
  FROM public.logistics_transfers
  WHERE id = p_transfer_id
    AND buyer_player_id = v_player_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Transfer kaydi bulunamadi.');
  END IF;

  IF v_transfer.status = 'completed' THEN
    RETURN jsonb_build_object('success', false, 'message', 'Bu transfer zaten tamamlanmis.');
  END IF;

  IF v_transfer.status <> 'in_transit' THEN
    RETURN jsonb_build_object(
      'success',
      false,
      'message',
      'Bu transfer reklam odulu ile tamamlanabilir durumda degil.'
    );
  END IF;

  v_remaining_seconds := GREATEST(
    CEIL(EXTRACT(EPOCH FROM (v_transfer.finish_at - timezone('utc'::text, now()))))::integer,
    0
  );

  IF v_remaining_seconds > 600 THEN
    RETURN jsonb_build_object(
      'success',
      false,
      'message',
      'Reklamla hizli tamamlama sadece son 10 dakika icindeki transferlerde kullanilabilir.'
    );
  END IF;

  PERFORM public.consume_rewarded_ad_usage(
    v_player_id,
    'transfer_finish',
    5,
    jsonb_build_object('transfer_id', p_transfer_id)
  );

  UPDATE public.logistics_transfers
  SET finish_at = timezone('utc'::text, now()) - interval '1 second'
  WHERE id = p_transfer_id;

  RETURN public.complete_logistics_transfer(p_transfer_id);
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

  PERFORM public.consume_rewarded_ad_usage(
    p_player_id,
    'construction_time_reduce',
    5,
    jsonb_build_object('construction_id', p_construction_id)
  );

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

  PERFORM public.consume_rewarded_ad_usage(
    p_player_id,
    'upgrade_time_reduce',
    5,
    jsonb_build_object('upgrade_id', p_upgrade_id)
  );

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

  PERFORM public.consume_rewarded_ad_usage(
    p_player_id,
    'building_boost_start',
    5,
    jsonb_build_object(
      'building_kind', p_building_kind,
      'entity_id', p_entity_id,
      'duration_minutes', v_duration_minutes
    )
  );

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
