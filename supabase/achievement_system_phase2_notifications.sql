create or replace function public.grant_player_achievement_reward(
  p_player_id uuid,
  p_achievement_id text
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_def public.achievement_definitions%rowtype;
  v_player public.players%rowtype;
  v_row public.player_achievements%rowtype;
  v_now timestamptz := timezone('utc', now());
  v_exp_result jsonb := null;
begin
  select * into v_def
  from public.achievement_definitions
  where id = p_achievement_id
    and is_active = true;

  if not found then
    return jsonb_build_object('success', false, 'message', 'Basari bulunamadi.');
  end if;

  select * into v_row
  from public.player_achievements
  where player_id = p_player_id
    and achievement_id = p_achievement_id;

  if not found then
    return jsonb_build_object('success', false, 'message', 'Oyuncu basarisi bulunamadi.');
  end if;

  if v_row.reward_granted_at is not null then
    return jsonb_build_object('success', true, 'already_granted', true);
  end if;

  if v_row.is_unlocked = false then
    return jsonb_build_object('success', false, 'message', 'Basari henuz acilmadi.');
  end if;

  if coalesce(v_def.reward_cash, 0) > 0 or coalesce(v_def.reward_gold, 0) > 0 then
    update public.players
    set
      cash = cash + coalesce(v_def.reward_cash, 0),
      gold = gold + coalesce(v_def.reward_gold, 0)
    where id = p_player_id
    returning * into v_player;
  end if;

  if coalesce(v_def.reward_xp, 0) > 0 then
    v_exp_result := public.grant_player_experience(
      p_player_id,
      v_def.reward_xp,
      'achievement_reward',
      jsonb_build_object(
        'achievement_id', v_def.id,
        'title', v_def.title,
        'category', v_def.category
      )
    );
  end if;

  update public.player_achievements
  set reward_granted_at = v_now, updated_at = v_now
  where player_id = p_player_id
    and achievement_id = p_achievement_id;

  insert into public.player_notifications (
    player_id,
    kind,
    category,
    title,
    message,
    entity_kind,
    entity_id,
    severity,
    status,
    meta,
    dedupe_key,
    created_at,
    updated_at
  )
  values (
    p_player_id,
    'event',
    'achievement_unlocked',
    'Yeni Rozet Acildi',
    format('%s rozeti acildi. %s', v_def.title, v_def.description),
    'achievement',
    null,
    'success',
    'unread',
    jsonb_build_object(
      'achievement_id', v_def.id,
      'title', v_def.title,
      'category', v_def.category,
      'badge_key', v_def.badge_key,
      'badge_color', v_def.badge_color
    ),
    format('achievement_unlocked:%s:%s', p_player_id, v_def.id),
    v_now,
    v_now
  )
  on conflict do nothing;

  return jsonb_build_object(
    'success', true,
    'achievement_id', v_def.id,
    'reward', jsonb_build_object(
      'xp', v_def.reward_xp,
      'cash', v_def.reward_cash,
      'gold', v_def.reward_gold
    ),
    'experience', v_exp_result
  );
end;
$$;

insert into public.player_notifications (
  player_id,
  kind,
  category,
  title,
  message,
  entity_kind,
  entity_id,
  severity,
  status,
  meta,
  dedupe_key,
  created_at,
  updated_at,
  read_at
)
select
  pa.player_id,
  'event',
  'achievement_unlocked',
  'Yeni Rozet Acildi',
  format('%s rozeti acildi. %s', ad.title, ad.description),
  'achievement',
  null,
  'success',
  'read',
  jsonb_build_object(
    'achievement_id', ad.id,
    'title', ad.title,
    'category', ad.category,
    'badge_key', ad.badge_key,
    'badge_color', ad.badge_color
  ),
  format('achievement_unlocked:%s:%s', pa.player_id, ad.id),
  coalesce(pa.reward_granted_at, pa.unlocked_at, timezone('utc', now())),
  timezone('utc', now()),
  timezone('utc', now())
from public.player_achievements pa
join public.achievement_definitions ad on ad.id = pa.achievement_id
where pa.is_unlocked = true
  and not exists (
    select 1
    from public.player_notifications pn
    where pn.dedupe_key = format('achievement_unlocked:%s:%s', pa.player_id, ad.id)
  );
