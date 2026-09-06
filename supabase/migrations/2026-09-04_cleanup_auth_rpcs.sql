-- Migration: 2026-09-04_cleanup_auth_rpcs.sql
-- Description: Drop unused legacy tutorial RPC and refine/optimize auth & player RPCs

-- 1. Kullanılmayan eski tutorial RPC'sini kaldır
DROP FUNCTION IF EXISTS public.trigger_tutorial_first_sale(uuid);

-- 2. ensure_player_record_exists fonksiyonunu arındır ve optimize et
CREATE OR REPLACE FUNCTION public.ensure_player_record_exists(p_user_id uuid, p_city_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_player public.players%rowtype;
  v_created boolean := false;
  v_assigned_city_id uuid := p_city_id;
BEGIN
  IF auth.uid() IS NULL OR auth.uid() <> p_user_id THEN
    RAISE EXCEPTION 'Yetkisiz istek.';
  END IF;

  SELECT *
  INTO v_player
  FROM public.players
  WHERE id = p_user_id;

  IF NOT FOUND THEN
    IF v_assigned_city_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.cities WHERE id = v_assigned_city_id) THEN
      v_assigned_city_id := NULL;
    END IF;

    INSERT INTO public.players (
      id,
      player_name,
      company_name,
      avatar_id,
      level,
      experience,
      cash,
      gold,
      headquarters_city_id,
      starter_pack_claimed
    )
    VALUES (
      p_user_id,
      'Oyuncu_' || left(p_user_id::text, 4),
      'Yeni Holding',
      'ae1.webp',
      1,
      0,
      20000,
      50,
      v_assigned_city_id,
      false
    )
    RETURNING *
    INTO v_player;

    v_created := true;
  ELSIF p_city_id IS NOT NULL AND v_player.headquarters_city_id IS NULL THEN
    IF EXISTS (SELECT 1 FROM public.cities WHERE id = p_city_id) THEN
      UPDATE public.players
      SET headquarters_city_id = p_city_id
      WHERE id = p_user_id
      RETURNING *
      INTO v_player;
    END IF;
  END IF;

  -- Eğer merkez şehir belirlenmişse ve başlangıç paketi verilmemişse tanımla
  IF v_player.headquarters_city_id IS NOT NULL AND coalesce(v_player.starter_pack_claimed, false) = false THEN
    PERFORM public.grant_starter_package(p_user_id, v_player.headquarters_city_id);
    SELECT * INTO v_player FROM public.players WHERE id = p_user_id;
  END IF;

  RETURN jsonb_build_object(
    'created', v_created,
    'player', to_jsonb(v_player)
  );
END;
$function$;

-- 3. get_player_profile fonksiyonunu optimize et (mükerrer ensure çağrılarını önle)
CREATE OR REPLACE FUNCTION public.get_player_profile(p_player_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_player record;
  v_progress jsonb;
  v_featured_badges jsonb := '[]'::jsonb;
  v_unlocked_count integer := 0;
  v_total_count integer := 0;
  v_company_value jsonb := '{}'::jsonb;
BEGIN
  IF p_player_id IS NULL THEN
    RETURN null;
  END IF;

  SELECT p.*, c.name as headquarters_city_name
  INTO v_player
  FROM public.players p
  LEFT JOIN public.cities c ON c.id = p.headquarters_city_id
  WHERE p.id = p_player_id;

  -- Kayıt bulunamadıysa ve oturum sahibi kendi profiline bakıyorsa kayıt oluştur
  IF NOT FOUND THEN
    IF auth.uid() IS NOT NULL AND auth.uid() = p_player_id THEN
      PERFORM public.ensure_player_record_exists(p_player_id);
      
      SELECT p.*, c.name as headquarters_city_name
      INTO v_player
      FROM public.players p
      LEFT JOIN public.cities c ON c.id = p.headquarters_city_id
      WHERE p.id = p_player_id;
    END IF;

    IF NOT FOUND THEN
      RETURN null;
    END IF;
  END IF;

  v_progress := public.build_level_progress_payload(
    coalesce(v_player.level, 1),
    coalesce(v_player.experience, 0)
  );

  PERFORM public.ensure_player_achievement_rows(p_player_id);
  PERFORM public.sync_player_achievement_snapshot(p_player_id);

  v_company_value := public.calculate_player_company_value(p_player_id);
  PERFORM public.refresh_player_leaderboard_stats(p_player_id);

  SELECT
    coalesce(
      jsonb_agg(public.build_player_achievement_payload(p_player_id, achievement_id) ORDER BY unlocked_at DESC NULLS LAST, display_order ASC),
      '[]'::jsonb
    )
  INTO v_featured_badges
  FROM (
    SELECT pa.achievement_id, pa.unlocked_at, ad.display_order
    FROM public.player_achievements pa
    JOIN public.achievement_definitions ad ON ad.id = pa.achievement_id
    WHERE pa.player_id = p_player_id
      AND ad.is_active = true
      AND pa.is_unlocked = true
    ORDER BY pa.unlocked_at DESC NULLS LAST, ad.display_order ASC
    LIMIT 4
  ) featured_pick;

  SELECT
    count(*) filter (WHERE pa.is_unlocked = true),
    count(*)
  INTO v_unlocked_count, v_total_count
  FROM public.player_achievements pa
  JOIN public.achievement_definitions ad ON ad.id = pa.achievement_id
  WHERE pa.player_id = p_player_id
    AND ad.is_active = true;

  RETURN jsonb_build_object(
    'id', v_player.id,
    'player_name', v_player.player_name,
    'company_name', v_player.company_name,
    'avatar_id', v_player.avatar_id,
    'headquarters_city_id', v_player.headquarters_city_id,
    'headquarters_city_name', v_player.headquarters_city_name,
    'level', coalesce(v_player.level, 1),
    'experience', v_player.experience,
    'cash', v_player.cash,
    'gold', v_player.gold,
    'company_value', coalesce((v_company_value ->> 'total_company_value')::numeric, 0),
    'company_value_breakdown', v_company_value,
    'created_at', v_player.created_at,
    'current_level_start_experience', coalesce((v_progress ->> 'current_level_start_experience')::integer, 0),
    'next_level_total_experience', coalesce((v_progress ->> 'next_level_total_experience')::integer, 0),
    'current_level_experience', coalesce((v_progress ->> 'current_level_experience')::integer, 0),
    'next_level_required_experience', coalesce((v_progress ->> 'next_level_required_experience')::integer, 1),
    'remaining_experience_to_next_level', coalesce((v_progress ->> 'remaining_experience_to_next_level')::integer, 0),
    'exp_progress_ratio', coalesce((v_progress ->> 'progress_ratio')::numeric, 0),
    'achievement_unlocked_count', coalesce(v_unlocked_count, 0),
    'achievement_total_count', coalesce(v_total_count, 0),
    'featured_badges', v_featured_badges
  );
END;
$function$;

-- 4. bootstrap_game_session fonksiyonunu arındır (mükerrer şehir atama ve çağrıları temizle)
CREATE OR REPLACE FUNCTION public.bootstrap_game_session(p_city_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_player_id uuid := auth.uid();
  v_player jsonb;
  v_logistics_state jsonb;
  v_production_result jsonb;
  v_transfer_result jsonb;
BEGIN
  IF v_player_id IS NULL THEN
    RAISE EXCEPTION 'Oturum acilmamis.';
  END IF;

  -- ensure_player_record_exists şehir yoksa atar ve başlangıç paketini otomatik sağlar
  PERFORM public.ensure_player_record_exists(v_player_id, p_city_id);

  -- 1. Tamamlanma süresi dolmuş transferleri ve ihale teslimatlarını tamamla
  v_transfer_result := public.complete_due_market_transfers(v_player_id, 100);
  PERFORM public.process_tender_deliveries(v_player_id);
  PERFORM public.process_player_tenders(v_player_id);

  -- 2. Liderlik ve şirket değerini güncelle
  PERFORM public.refresh_player_leaderboard_stats(v_player_id);

  -- 3. Üretimleri işle
  v_production_result := public.process_player_production_entry(v_player_id);
  v_player := public.get_player_profile(v_player_id);
  v_logistics_state := public.get_logistics_entry_state();

  RETURN jsonb_build_object(
    'success', true,
    'player', v_player,
    'logistics_entry_state', v_logistics_state,
    'completed_transfers', v_transfer_result,
    'completed_due_building_boosts', v_production_result -> 'completed_due_building_boosts',
    'completed_due_building_upgrades', v_production_result -> 'completed_due_building_upgrades',
    'processed_production', v_production_result
  );
END;
$function$;

-- 5. sync_player_google_profile fonksiyonunu arındır
CREATE OR REPLACE FUNCTION public.sync_player_google_profile(p_player_name text DEFAULT NULL::text, p_google_email text DEFAULT NULL::text, p_google_avatar_url text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_player_id uuid := auth.uid();
  v_trimmed_player_name text := nullif(trim(coalesce(p_player_name, '')), '');
  v_trimmed_google_email text := nullif(trim(coalesce(p_google_email, '')), '');
  v_trimmed_google_avatar_url text := nullif(trim(coalesce(p_google_avatar_url, '')), '');
  v_current_player_name text;
BEGIN
  IF v_player_id IS NULL THEN
    RAISE EXCEPTION 'Oturum bulunamadi.';
  END IF;

  SELECT player_name INTO v_current_player_name
  FROM public.players
  WHERE id = v_player_id;

  IF NOT FOUND THEN
    PERFORM public.ensure_player_record_exists(v_player_id);
    SELECT player_name INTO v_current_player_name
    FROM public.players
    WHERE id = v_player_id;
  END IF;

  UPDATE public.players
  SET
    player_name = CASE
      WHEN v_current_player_name IS NULL
        OR v_current_player_name LIKE 'Oyuncu_%'
        OR v_current_player_name = 'Oyuncu'
        THEN coalesce(v_trimmed_player_name, player_name)
      ELSE player_name
    END,
    google_email = coalesce(v_trimmed_google_email, google_email),
    google_avatar_url = coalesce(v_trimmed_google_avatar_url, google_avatar_url)
  WHERE id = v_player_id;

  PERFORM public.refresh_player_leaderboard_stats(v_player_id);

  RETURN jsonb_build_object(
    'success', true,
    'player_id', v_player_id,
    'player_name', v_trimmed_player_name,
    'google_email', v_trimmed_google_email,
    'google_avatar_url', v_trimmed_google_avatar_url
  );
END;
$function$;
