create table if not exists public.achievement_definitions (
  id text primary key,
  category text not null,
  title text not null,
  description text not null,
  event_key text not null,
  target_count integer not null,
  badge_key text,
  badge_color text default 'gold' not null,
  reward_xp integer default 0 not null,
  reward_cash numeric(15,2) default 0 not null,
  reward_gold integer default 0 not null,
  display_order integer default 0 not null,
  is_active boolean default true not null,
  created_at timestamptz default timezone('utc', now()) not null,
  updated_at timestamptz default timezone('utc', now()) not null,
  constraint achievement_definitions_category_check check (
    category = any (array['expansion'::text, 'trade'::text, 'logistics'::text, 'research'::text, 'mastery'::text])
  ),
  constraint achievement_definitions_reward_gold_check check (reward_gold >= 0),
  constraint achievement_definitions_reward_xp_check check (reward_xp >= 0),
  constraint achievement_definitions_target_count_check check (target_count > 0)
);

create table if not exists public.player_achievements (
  player_id uuid not null references public.players(id) on delete cascade,
  achievement_id text not null references public.achievement_definitions(id) on delete cascade,
  progress_count integer default 0 not null,
  is_unlocked boolean default false not null,
  unlocked_at timestamptz,
  reward_granted_at timestamptz,
  last_progress_at timestamptz,
  created_at timestamptz default timezone('utc', now()) not null,
  updated_at timestamptz default timezone('utc', now()) not null,
  primary key (player_id, achievement_id),
  constraint player_achievements_progress_count_check check (progress_count >= 0)
);

create index if not exists idx_achievement_definitions_active_order
  on public.achievement_definitions (is_active, category, display_order);

create index if not exists idx_player_achievements_player_unlock
  on public.player_achievements (player_id, is_unlocked, reward_granted_at);

alter table public.achievement_definitions enable row level security;
alter table public.player_achievements enable row level security;

drop policy if exists achievement_definitions_read_authenticated on public.achievement_definitions;
create policy achievement_definitions_read_authenticated
  on public.achievement_definitions
  for select
  to authenticated
  using (true);

drop policy if exists player_achievements_read_own on public.player_achievements;
create policy player_achievements_read_own
  on public.player_achievements
  for select
  to authenticated
  using (player_id = auth.uid());

drop policy if exists player_achievements_insert_own on public.player_achievements;
create policy player_achievements_insert_own
  on public.player_achievements
  for insert
  to authenticated
  with check (player_id = auth.uid());

drop policy if exists player_achievements_update_own on public.player_achievements;
create policy player_achievements_update_own
  on public.player_achievements
  for update
  to authenticated
  using (player_id = auth.uid())
  with check (player_id = auth.uid());

create or replace function public.ensure_player_achievement_rows(p_player_id uuid)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if p_player_id is null then
    return;
  end if;

  insert into public.player_achievements (player_id, achievement_id)
  select p_player_id, ad.id
  from public.achievement_definitions ad
  where ad.is_active = true
  on conflict (player_id, achievement_id) do nothing;
end;
$$;

create or replace function public.build_player_achievement_payload(
  p_player_id uuid,
  p_achievement_id text
)
returns jsonb
language sql
stable
set search_path to 'public'
as $$
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
$$;

create or replace function public.sync_player_achievement_snapshot(p_player_id uuid)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_now timestamptz := timezone('utc', now());
begin
  if p_player_id is null then
    return;
  end if;

  perform public.ensure_player_achievement_rows(p_player_id);

  with achievement_counts as (
    select 'building_construction_completed'::text as event_key, count(*)::int as current_count
    from public.building_constructions
    where player_id = p_player_id
      and status = 'complete'
    union all
    select 'building_upgrade_completed'::text, count(*)::int
    from public.building_upgrades
    where player_id = p_player_id
      and status = 'completed'
    union all
    select 'store_sale_completed'::text, coalesce(sum(sold_quantity), 0)::int
    from public.store_daily_performance
    where player_id = p_player_id
    union all
    select 'logistics_transfer_completed'::text, count(*)::int
    from public.logistics_transfers
    where status = 'completed'
      and (buyer_player_id = p_player_id or seller_player_id = p_player_id)
    union all
    select 'arge_research_completed'::text, count(*)::int
    from public.arge_researches
    where player_id = p_player_id
      and status = 'completed'
    union all
    select 'building_construction_completed_' || building_kind, count(*)::int
    from public.building_constructions
    where player_id = p_player_id
      and status = 'complete'
    group by building_kind
  )
  update public.player_achievements pa
  set
    progress_count = greatest(pa.progress_count, least(ad.target_count, ac.current_count)),
    is_unlocked = pa.is_unlocked or ac.current_count >= ad.target_count,
    unlocked_at = case
      when (pa.is_unlocked = false and ac.current_count >= ad.target_count and pa.unlocked_at is null) then v_now
      else pa.unlocked_at
    end,
    updated_at = case
      when greatest(pa.progress_count, least(ad.target_count, ac.current_count)) <> pa.progress_count
        or (pa.is_unlocked = false and ac.current_count >= ad.target_count)
      then v_now
      else pa.updated_at
    end
  from public.achievement_definitions ad
  join achievement_counts ac on ac.event_key = ad.event_key
  where pa.player_id = p_player_id
    and pa.achievement_id = ad.id
    and ad.is_active = true;
end;
$$;

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

create or replace function public.increment_player_achievement_progress(
  p_player_id uuid,
  p_event_key text,
  p_amount integer default 1,
  p_meta jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_now timestamptz := timezone('utc', now());
  v_achievement_id text;
begin
  if p_player_id is null or coalesce(p_event_key, '') = '' or coalesce(p_amount, 0) <= 0 then
    return;
  end if;

  perform public.ensure_player_achievement_rows(p_player_id);

  for v_achievement_id in
    with updated as (
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
        and pa.is_unlocked = false
      returning pa.achievement_id, pa.reward_granted_at, pa.unlocked_at, (pa.progress_count + p_amount) >= ad.target_count as just_unlocked
    )
    select achievement_id
    from updated
    where just_unlocked = true
      and reward_granted_at is null
  loop
    perform public.grant_player_achievement_reward(p_player_id, v_achievement_id);
  end loop;
end;
$$;

create or replace function public.get_player_achievement_dashboard()
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_player_id uuid := auth.uid();
  v_featured_badges jsonb := '[]'::jsonb;
  v_active_achievements jsonb := '[]'::jsonb;
  v_unlocked_achievements jsonb := '[]'::jsonb;
  v_unlocked_count integer := 0;
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
    order by pa.unlocked_at desc nulls last, ad.display_order asc
    limit 6
  ) featured_pick;

  select coalesce(
    jsonb_agg(public.build_player_achievement_payload(v_player_id, achievement_id) order by sort_ratio desc, display_order asc),
    '[]'::jsonb
  )
  into v_active_achievements
  from (
    select
      pa.achievement_id,
      ad.display_order,
      least(1.0, greatest(pa.progress_count, 0)::numeric / greatest(ad.target_count, 1)::numeric) as sort_ratio
    from public.player_achievements pa
    join public.achievement_definitions ad on ad.id = pa.achievement_id
    where pa.player_id = v_player_id
      and ad.is_active = true
      and pa.is_unlocked = false
    order by sort_ratio desc, ad.display_order asc
    limit 8
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
    order by pa.unlocked_at desc nulls last, ad.display_order asc
  ) unlocked_pick;

  select
    count(*) filter (where pa.is_unlocked = true),
    count(*)
  into v_unlocked_count, v_total_count
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
      'total_count', coalesce(v_total_count, 0)
    )
  );
end;
$$;

create or replace function public.get_player_profile(p_player_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_player record;
  v_progress jsonb;
  v_featured_badges jsonb := '[]'::jsonb;
  v_unlocked_count integer := 0;
  v_total_count integer := 0;
begin
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
$$;

create or replace function public.handle_arge_research_mission_progress()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if tg_op = 'UPDATE'
     and new.status = 'completed'
     and coalesce(old.status, '') <> 'completed' then
    perform public.increment_player_mission_progress(new.player_id, 'arge_research_completed', 1);
    perform public.increment_player_achievement_progress(new.player_id, 'arge_research_completed', 1);
  end if;

  return new;
end;
$$;

create or replace function public.handle_building_construction_mission_progress()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if tg_op = 'UPDATE'
     and new.status = 'complete'
     and coalesce(old.status, '') <> 'complete' then
    perform public.increment_player_mission_progress(new.player_id, 'building_construction_completed', 1);
    perform public.increment_player_mission_progress(new.player_id, 'building_construction_completed_' || new.building_kind, 1);
    perform public.increment_player_achievement_progress(new.player_id, 'building_construction_completed', 1);
    perform public.increment_player_achievement_progress(new.player_id, 'building_construction_completed_' || new.building_kind, 1);
  end if;

  return new;
end;
$$;

create or replace function public.handle_building_upgrade_mission_progress()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if tg_op = 'UPDATE'
     and new.status = 'completed'
     and coalesce(old.status, '') <> 'completed' then
    perform public.increment_player_mission_progress(new.player_id, 'building_upgrade_completed', 1);
    perform public.increment_player_mission_progress(new.player_id, 'building_upgrade_completed_' || new.building_kind, 1);
    perform public.increment_player_achievement_progress(new.player_id, 'building_upgrade_completed', 1);
    perform public.increment_player_achievement_progress(new.player_id, 'building_upgrade_completed_' || new.building_kind, 1);
  end if;

  return new;
end;
$$;

create or replace function public.handle_logistics_transfer_mission_progress()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_player_id uuid;
begin
  if tg_op = 'UPDATE'
     and new.status = 'completed'
     and coalesce(old.status, '') <> 'completed' then
    v_player_id := coalesce(new.buyer_player_id, new.seller_player_id);
    if v_player_id is not null then
      perform public.increment_player_mission_progress(v_player_id, 'logistics_transfer_completed', 1);
      perform public.increment_player_mission_progress(v_player_id, 'logistics_transfer_completed_' || coalesce(new.transfer_type, 'unknown'), 1);
      perform public.increment_player_achievement_progress(v_player_id, 'logistics_transfer_completed', 1);
      perform public.increment_player_achievement_progress(v_player_id, 'logistics_transfer_completed_' || coalesce(new.transfer_type, 'unknown'), 1);
    end if;
  end if;

  return new;
end;
$$;

create or replace function public.handle_store_sales_mission_progress()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_delta integer := 0;
begin
  if tg_op = 'INSERT' then
    v_delta := coalesce(new.sold_quantity, 0);
  elsif tg_op = 'UPDATE' then
    v_delta := greatest(coalesce(new.sold_quantity, 0) - coalesce(old.sold_quantity, 0), 0);
  end if;

  if v_delta > 0 then
    perform public.increment_player_mission_progress(new.player_id, 'store_sale_completed', v_delta);
    perform public.increment_player_achievement_progress(new.player_id, 'store_sale_completed', v_delta);
  end if;

  return new;
end;
$$;

insert into public.achievement_definitions (
  id, category, title, description, event_key, target_count, badge_key, badge_color, reward_xp, reward_cash, reward_gold, display_order
)
values
  ('first_store', 'expansion', 'Ilk Magaza', 'Ilk magazani kur ve perakende zincirini baslat.', 'building_construction_completed_store', 1, 'store', 'amber', 40, 2500, 0, 10),
  ('first_warehouse', 'expansion', 'Ilk Depo', 'Ilk deponu kur ve stok gucunu artir.', 'building_construction_completed_warehouse', 1, 'warehouse', 'blue', 45, 3000, 0, 20),
  ('first_factory', 'expansion', 'Ilk Fabrika', 'Ilk fabrikani kur ve uretime gec.', 'building_construction_completed_factory', 1, 'factory', 'red', 60, 4000, 1, 30),
  ('first_field', 'expansion', 'Ilk Ciftlik', 'Ilk ciftligini kur ve tarimsal uretime basla.', 'building_construction_completed_field', 1, 'field', 'green', 40, 2500, 0, 40),
  ('first_farm', 'expansion', 'Ilk Tarla', 'Ilk tarlani kur ve urun yetistirmeye basla.', 'building_construction_completed_farm', 1, 'farm', 'lime', 40, 2500, 0, 50),
  ('first_mine', 'expansion', 'Ilk Maden', 'Ilk madenini kur ve kaynak cikarmaya basla.', 'building_construction_completed_mine', 1, 'mine', 'slate', 55, 3500, 1, 60),
  ('builder_10', 'mastery', 'Kurucu', 'Toplam 10 isletme insa et.', 'building_construction_completed', 10, 'builder', 'gold', 120, 10000, 2, 70),
  ('merchant_100', 'trade', 'Satici', 'Toplam 100 urun satisi yap.', 'store_sale_completed', 100, 'trade', 'orange', 80, 6000, 0, 80),
  ('merchant_1000', 'trade', 'Perakende Ustasi', 'Toplam 1000 urun satisi yap.', 'store_sale_completed', 1000, 'crown', 'deepOrange', 180, 18000, 3, 90),
  ('logistics_5', 'logistics', 'Rota Acildi', 'Toplam 5 transfer tamamla.', 'logistics_transfer_completed', 5, 'truck', 'cyan', 70, 5000, 0, 100),
  ('research_1', 'research', 'Arastirmaci', 'Ilk AR-GE calismani tamamla.', 'arge_research_completed', 1, 'science', 'purple', 90, 7000, 1, 110),
  ('upgrader_5', 'mastery', 'Gelisimci', 'Toplam 5 bina yukseltmesi tamamla.', 'building_upgrade_completed', 5, 'upgrade', 'teal', 100, 8000, 1, 120)
on conflict (id) do update
set
  category = excluded.category,
  title = excluded.title,
  description = excluded.description,
  event_key = excluded.event_key,
  target_count = excluded.target_count,
  badge_key = excluded.badge_key,
  badge_color = excluded.badge_color,
  reward_xp = excluded.reward_xp,
  reward_cash = excluded.reward_cash,
  reward_gold = excluded.reward_gold,
  display_order = excluded.display_order,
  is_active = true,
  updated_at = timezone('utc', now());

revoke all on function public.ensure_player_achievement_rows(uuid) from public;
grant all on function public.ensure_player_achievement_rows(uuid) to service_role;

revoke all on function public.build_player_achievement_payload(uuid, text) from public;
grant all on function public.build_player_achievement_payload(uuid, text) to authenticated;
grant all on function public.build_player_achievement_payload(uuid, text) to service_role;

revoke all on function public.sync_player_achievement_snapshot(uuid) from public;
grant all on function public.sync_player_achievement_snapshot(uuid) to service_role;

revoke all on function public.grant_player_achievement_reward(uuid, text) from public;
grant all on function public.grant_player_achievement_reward(uuid, text) to service_role;

revoke all on function public.increment_player_achievement_progress(uuid, text, integer, jsonb) from public;
grant all on function public.increment_player_achievement_progress(uuid, text, integer, jsonb) to service_role;

revoke all on function public.get_player_achievement_dashboard() from public;
grant all on function public.get_player_achievement_dashboard() to authenticated;
grant all on function public.get_player_achievement_dashboard() to service_role;
