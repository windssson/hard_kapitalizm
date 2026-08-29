-- ============================================================================
-- Migration: Enhance achievement and mission reward claim RPCs to return
-- player snapshot and standard changed block for client-side state patching
-- ============================================================================

-- 1. ENHANCE claim_player_achievement_reward
CREATE OR REPLACE FUNCTION public.claim_player_achievement_reward(p_achievement_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_player_id uuid := auth.uid();
  v_def public.achievement_definitions%rowtype;
  v_row public.player_achievements%rowtype;
  v_now timestamptz := timezone('utc', now());
  v_exp_result jsonb := null;
  v_balance_before numeric;
  v_reward_cash numeric;
  v_reward_gold integer;
  v_reward_xp integer;
  v_player jsonb;
begin
  if v_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  perform public.ensure_player_achievement_rows(v_player_id);
  perform public.sync_player_achievement_snapshot(v_player_id);

  select * into v_def
  from public.achievement_definitions
  where id = p_achievement_id and is_active = true;

  if not found then
    return jsonb_build_object('success', false, 'message', 'Basari bulunamadi.');
  end if;

  select * into v_row
  from public.player_achievements
  where player_id = v_player_id and achievement_id = p_achievement_id
  for update;

  if not found then
    return jsonb_build_object('success', false, 'message', 'Oyuncu basarisi bulunamadi.');
  end if;

  if v_row.is_unlocked = false then
    return jsonb_build_object('success', false, 'message', 'Bu basarim henuz acilmadi.');
  end if;

  if v_row.reward_granted_at is not null then
    return jsonb_build_object('success', false, 'already_claimed', true, 'message', 'Bu basarim odulu zaten alindi.');
  end if;

  v_reward_cash := coalesce(v_def.reward_cash, 0);
  v_reward_gold := coalesce(v_def.reward_gold, 0);
  v_reward_xp := coalesce(v_def.reward_xp, 0);

  if v_reward_cash > 0 or v_reward_gold > 0 then
    select cash into v_balance_before from public.players where id = v_player_id;
    update public.players
    set
      cash = cash + v_reward_cash,
      gold = gold + v_reward_gold
    where id = v_player_id;

    if v_reward_cash > 0 then
      perform public.log_player_cash_change(
        v_player_id, v_reward_cash, v_balance_before,
        'achievement_reward',
        format('Basarim odulu: %s', v_def.title),
        null, null
      );
    end if;
  end if;

  if v_reward_xp > 0 then
    v_exp_result := public.grant_player_experience(
      v_player_id, v_reward_xp, 'achievement_reward_claimed',
      jsonb_build_object('achievement_id', v_def.id, 'title', v_def.title, 'category', v_def.category)
    );
  end if;

  update public.player_achievements
  set
    reward_granted_at = v_now,
    updated_at = v_now
  where player_id = v_player_id and achievement_id = p_achievement_id;

  v_player := public.get_player_profile(v_player_id);

  return jsonb_build_object(
    'success', true,
    'message', 'Basarim odulu basariyla alindi.',
    'achievement_id', v_def.id,
    'reward', jsonb_build_object('xp', v_reward_xp, 'cash', v_reward_cash, 'gold', v_reward_gold),
    'experience', v_exp_result,
    'player', v_player,
    'changed', jsonb_build_object(
      'player', v_player,
      'dashboard_dirty', true
    )
  );
end;
$function$;


-- 2. ENHANCE claim_player_mission_reward
CREATE OR REPLACE FUNCTION public.claim_player_mission_reward(p_mission_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_player_id uuid := auth.uid();
  v_now timestamptz := timezone('utc', now());
  v_mission record;
  v_exp_result jsonb := null;
  v_player jsonb;
  v_balance_before numeric;
  v_reward_cash numeric;
begin
  if v_player_id is null then raise exception 'Oturum acilmamis.'; end if;

  perform public.ensure_player_mission_rows(v_player_id);
  perform public.reset_player_daily_missions(v_player_id);
  perform public.reset_player_weekly_missions(v_player_id);
  perform public.sync_player_mission_snapshot(v_player_id);

  select pm.player_id, pm.mission_id, pm.progress_count, pm.is_completed, pm.is_claimed,
         md.title, md.reward_xp, md.reward_cash, md.reward_gold
  into v_mission
  from public.player_missions pm
  join public.mission_definitions md on md.id = pm.mission_id
  where pm.player_id = v_player_id and pm.mission_id = p_mission_id and md.is_active = true
  for update of pm;

  if not found then return jsonb_build_object('success', false, 'message', 'Gorev bulunamadi.'); end if;
  if v_mission.is_claimed then return jsonb_build_object('success', false, 'message', 'Bu gorevin odulu zaten alindi.'); end if;
  if v_mission.is_completed = false then return jsonb_build_object('success', false, 'message', 'Bu gorev henuz tamamlanmadi.'); end if;

  update public.player_missions
  set is_claimed = true, claimed_at = v_now, updated_at = v_now
  where player_id = v_player_id and mission_id = p_mission_id;

  v_reward_cash := coalesce(v_mission.reward_cash, 0);
  if v_reward_cash > 0 or coalesce(v_mission.reward_gold, 0) > 0 then
    select cash into v_balance_before from public.players where id = v_player_id;
    update public.players
    set cash = cash + v_reward_cash, gold = gold + coalesce(v_mission.reward_gold, 0)
    where id = v_player_id;
    if v_reward_cash > 0 then
      perform public.log_player_cash_change(
        v_player_id, v_reward_cash, v_balance_before,
        'mission_reward',
        format('Gorev odulu: %s', v_mission.title),
        null, null
      );
    end if;
  end if;

  if coalesce(v_mission.reward_xp, 0) > 0 then
    v_exp_result := public.grant_player_experience(
      v_player_id, v_mission.reward_xp, 'mission_reward_claimed',
      jsonb_build_object('mission_id', p_mission_id, 'mission_title', v_mission.title)
    );
  end if;

  v_player := public.get_player_profile(v_player_id);

  return jsonb_build_object(
    'success', true,
    'message', 'Gorev odulu alindi.',
    'mission', public.build_player_mission_payload(v_player_id, p_mission_id),
    'reward', jsonb_build_object('xp', coalesce(v_mission.reward_xp, 0), 'cash', v_reward_cash, 'gold', coalesce(v_mission.reward_gold, 0)),
    'experience', v_exp_result,
    'player', v_player,
    'changed', jsonb_build_object(
      'player', v_player,
      'dashboard_dirty', true
    )
  );
end;
$function$;
