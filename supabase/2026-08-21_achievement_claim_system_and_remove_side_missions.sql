-- 2026-08-21: Achievement Manual Claim System & Remove Side Missions
-- 1. Remove side missions from mission_definitions.
-- 2. Modify increment_player_achievement_progress to NOT auto-grant rewards, but mark as unlocked.
-- 3. Ensure claim_player_achievement_reward RPC is available to securely claim rewards with feedback.
-- 4. Update build_player_achievement_payload and get_player_achievement_dashboard to support claimable/claimed states.

-- 1. DEACTIVATE SIDE MISSIONS
UPDATE public.mission_definitions
SET is_active = false
WHERE mission_type = 'side';

-- 2. ACHIEVEMENT PROGRESS TRIGGER (UNLOCK WITHOUT AUTO-GRANTING)
CREATE OR REPLACE FUNCTION public.increment_player_achievement_progress(
  p_player_id uuid,
  p_event_key text,
  p_amount integer DEFAULT 1,
  p_meta jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_now timestamptz := timezone('utc', now());
begin
  if p_player_id is null or coalesce(p_event_key, '') = '' or coalesce(p_amount, 0) <= 0 then
    return;
  end if;

  perform public.ensure_player_achievement_rows(p_player_id);

  update public.player_achievements pa
  set
    progress_count = least(ad.target_count, pa.progress_count + p_amount),
    is_unlocked = (pa.progress_count + p_amount) >= ad.target_count,
    unlocked_at = case
      when (pa.progress_count + p_amount) >= ad.target_count and pa.unlocked_at is null then v_now
      else pa.unlocked_at
    end,
    last_progress_at = v_now,
    updated_at = v_now
  from public.achievement_definitions ad
  where pa.player_id = p_player_id
    and pa.achievement_id = ad.id
    and ad.is_active = true
    and ad.event_key = p_event_key
    and pa.is_unlocked = false;
end;
$function$;

-- 3. CLAIM ACHIEVEMENT REWARD RPC
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

  return jsonb_build_object(
    'success', true,
    'message', 'Basarim odulu basariyla alindi.',
    'achievement_id', v_def.id,
    'reward', jsonb_build_object('xp', v_reward_xp, 'cash', v_reward_cash, 'gold', v_reward_gold),
    'experience', v_exp_result
  );
end;
$function$;

-- 4. BUILD PAYLOAD WITH CLAIM STATUS
CREATE OR REPLACE FUNCTION public.build_player_achievement_payload(p_player_id uuid, p_achievement_id text)
RETURNS jsonb
LANGUAGE sql
STABLE
SET search_path TO 'public'
AS $function$
  select jsonb_build_object(
    'id', ad.id,
    'category', ad.category,
    'title', ad.title,
    'description', ad.description,
    'event_key', ad.event_key,
    'target_count', ad.target_count,
    'progress_count', coalesce(pa.progress_count, 0),
    'is_unlocked', coalesce(pa.is_unlocked, false),
    'unlocked_at', pa.unlocked_at,
    'is_claimed', pa.reward_granted_at is not null,
    'is_claimable', coalesce(pa.is_unlocked, false) and pa.reward_granted_at is null,
    'reward_granted_at', pa.reward_granted_at,
    'last_progress_at', pa.last_progress_at,
    'badge_key', ad.badge_key,
    'badge_color', ad.badge_color,
    'reward', jsonb_build_object(
      'xp', ad.reward_xp,
      'cash', ad.reward_cash,
      'gold', ad.reward_gold
    ),
    'progress_ratio',
      least(
        1.0,
        greatest(coalesce(pa.progress_count, 0), 0)::numeric / greatest(ad.target_count, 1)::numeric
      )
  )
  from public.achievement_definitions ad
  left join public.player_achievements pa
    on pa.achievement_id = ad.id
   and pa.player_id = p_player_id
  where ad.id = p_achievement_id;
$function$;

-- 5. DASHBOARD WITH CLAIMABLE COUNT
CREATE OR REPLACE FUNCTION public.get_player_achievement_dashboard()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_player_id uuid := auth.uid();
  v_featured_badges jsonb := '[]'::jsonb;
  v_active_achievements jsonb := '[]'::jsonb;
  v_unlocked_achievements jsonb := '[]'::jsonb;
  v_unlocked_count integer := 0;
  v_claimable_count integer := 0;
  v_total_count integer := 0;
begin
  if v_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  perform public.ensure_player_achievement_rows(v_player_id);
  perform public.sync_player_achievement_snapshot(v_player_id);

  select coalesce(
    jsonb_agg(public.build_player_achievement_payload(v_player_id, achievement_id) order by unlocked_at desc nulls last, display_order asc),
    '[]'::jsonb
  )
  into v_featured_badges
  from (
    select pa.achievement_id, pa.unlocked_at, ad.display_order
    from public.player_achievements pa
    join public.achievement_definitions ad on ad.id = pa.achievement_id
    where pa.player_id = v_player_id
      and pa.is_unlocked = true
      and ad.is_active = true
    order by (pa.reward_granted_at is null) desc, pa.unlocked_at desc nulls last, ad.display_order asc
    limit 6
  ) featured_pick;

  select coalesce(
    jsonb_agg(public.build_player_achievement_payload(v_player_id, achievement_id) order by sort_claimable desc, sort_ratio desc, display_order asc),
    '[]'::jsonb
  )
  into v_active_achievements
  from (
    select
      pa.achievement_id,
      ad.display_order,
      case when (pa.is_unlocked = true and pa.reward_granted_at is null) then 1 else 0 end as sort_claimable,
      least(1.0, greatest(pa.progress_count, 0)::numeric / greatest(ad.target_count, 1)::numeric) as sort_ratio
    from public.player_achievements pa
    join public.achievement_definitions ad on ad.id = pa.achievement_id
    where pa.player_id = v_player_id
      and ad.is_active = true
      and (pa.is_unlocked = false or pa.reward_granted_at is null)
    order by sort_claimable desc, sort_ratio desc, ad.display_order asc
  ) active_pick;

  select coalesce(
    jsonb_agg(public.build_player_achievement_payload(v_player_id, achievement_id) order by unlocked_at desc nulls last, display_order asc),
    '[]'::jsonb
  )
  into v_unlocked_achievements
  from (
    select pa.achievement_id, pa.unlocked_at, ad.display_order
    from public.player_achievements pa
    join public.achievement_definitions ad on ad.id = pa.achievement_id
    where pa.player_id = v_player_id
      and ad.is_active = true
      and pa.is_unlocked = true
      and pa.reward_granted_at is not null
    order by pa.unlocked_at desc nulls last, ad.display_order asc
  ) unlocked_pick;

  select
    count(*) filter (where pa.is_unlocked = true),
    count(*) filter (where pa.is_unlocked = true and pa.reward_granted_at is null),
    count(*)
  into v_unlocked_count, v_claimable_count, v_total_count
  from public.player_achievements pa
  join public.achievement_definitions ad on ad.id = pa.achievement_id
  where pa.player_id = v_player_id
    and ad.is_active = true;

  return jsonb_build_object(
    'success', true,
    'featured_badges', v_featured_badges,
    'active_achievements', v_active_achievements,
    'unlocked_achievements', v_unlocked_achievements,
    'summary', jsonb_build_object(
      'unlocked_count', coalesce(v_unlocked_count, 0),
      'claimable_count', coalesce(v_claimable_count, 0),
      'total_count', coalesce(v_total_count, 0)
    )
  );
end;
$function$;
