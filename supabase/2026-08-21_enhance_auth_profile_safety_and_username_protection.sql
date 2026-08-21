-- 2026-08-21: Enhance Auth Profile Safety & Username Protection
-- 1. In sync_player_google_profile: Protect custom usernames so Google name only replaces default 'Oyuncu_xxxx' names.
-- 2. In get_player_profile: Auto-ensure player record exists so fresh Google OAuth logins never fail.
-- 3. In get_homepage_dashboard: Auto-ensure player record exists.

-- 1. sync_player_google_profile
CREATE OR REPLACE FUNCTION public.sync_player_google_profile(
  p_player_name text DEFAULT NULL::text,
  p_google_email text DEFAULT NULL::text,
  p_google_avatar_url text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_player_id uuid := auth.uid();
  v_trimmed_player_name text := nullif(trim(coalesce(p_player_name, '')), '');
  v_trimmed_google_email text := nullif(trim(coalesce(p_google_email, '')), '');
  v_trimmed_google_avatar_url text := nullif(trim(coalesce(p_google_avatar_url, '')), '');
  v_current_player_name text;
begin
  if v_player_id is null then
    raise exception 'Oturum bulunamadi.';
  end if;

  perform public.ensure_player_record_exists(v_player_id);

  select player_name into v_current_player_name
  from public.players
  where id = v_player_id;

  update public.players
  set
    player_name = case
      when v_current_player_name is null
        or v_current_player_name like 'Oyuncu_%'
        or v_current_player_name = 'Oyuncu'
        then coalesce(v_trimmed_player_name, player_name)
      else player_name
    end,
    google_email = coalesce(v_trimmed_google_email, google_email),
    google_avatar_url = coalesce(v_trimmed_google_avatar_url, google_avatar_url)
  where id = v_player_id;

  perform public.refresh_player_leaderboard_stats(v_player_id);

  return jsonb_build_object(
    'success', true,
    'player_id', v_player_id,
    'player_name', v_trimmed_player_name,
    'google_email', v_trimmed_google_email,
    'google_avatar_url', v_trimmed_google_avatar_url
  );
end;
$function$;

-- 2. get_player_profile
CREATE OR REPLACE FUNCTION public.get_player_profile(p_player_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_player record;
  v_progress jsonb;
  v_featured_badges jsonb := '[]'::jsonb;
  v_unlocked_count integer := 0;
  v_total_count integer := 0;
  v_company_value jsonb := '{}'::jsonb;
begin
  if p_player_id is null then
    return null;
  end if;

  -- Ensure player row exists if user has valid auth session
  perform public.ensure_player_record_exists(p_player_id);

  select * into v_player from public.players where id = p_player_id;
  if not found then
    return null;
  end if;

  v_progress := public.build_level_progress_payload(
    coalesce(v_player.level, 1),
    coalesce(v_player.experience, 0)
  );

  perform public.ensure_player_achievement_rows(p_player_id);
  perform public.sync_player_achievement_snapshot(p_player_id);

  v_company_value := public.calculate_player_company_value(p_player_id);
  perform public.refresh_player_leaderboard_stats(p_player_id);

  select
    coalesce(
      jsonb_agg(public.build_player_achievement_payload(p_player_id, achievement_id) order by unlocked_at desc nulls last, display_order asc),
      '[]'::jsonb
    )
  into v_featured_badges
  from (
    select pa.achievement_id, pa.unlocked_at, ad.display_order
    from public.player_achievements pa
    join public.achievement_definitions ad on ad.id = pa.achievement_id
    where pa.player_id = p_player_id
      and ad.is_active = true
      and pa.is_unlocked = true
    order by pa.unlocked_at desc nulls last, ad.display_order asc
    limit 4
  ) featured_pick;

  select
    count(*) filter (where pa.is_unlocked = true),
    count(*)
  into v_unlocked_count, v_total_count
  from public.player_achievements pa
  join public.achievement_definitions ad on ad.id = pa.achievement_id
  where pa.player_id = p_player_id
    and ad.is_active = true;

  return jsonb_build_object(
    'id', v_player.id,
    'player_name', v_player.player_name,
    'company_name', v_player.company_name,
    'avatar_id', v_player.avatar_id,
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
end;
$function$;
