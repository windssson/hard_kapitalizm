create table if not exists public.player_leaderboard_stats (
  player_id uuid primary key references public.players(id) on delete cascade,
  player_name text not null,
  company_name text not null,
  avatar_id text,
  level integer not null default 1,
  experience integer not null default 0,
  cash numeric(18,2) not null default 0,
  gold numeric(18,2) not null default 0,
  company_value numeric(18,2) not null default 0,
  business_value numeric(18,2) not null default 0,
  inventory_value numeric(18,2) not null default 0,
  vehicle_value numeric(18,2) not null default 0,
  building_base_value numeric(18,2) not null default 0,
  building_upgrade_value numeric(18,2) not null default 0,
  warehouse_inventory_value numeric(18,2) not null default 0,
  store_inventory_value numeric(18,2) not null default 0,
  production_inventory_value numeric(18,2) not null default 0,
  achievement_unlocked_count integer not null default 0,
  achievement_total_count integer not null default 0,
  created_at timestamptz default timezone('utc', now()) not null,
  updated_at timestamptz default timezone('utc', now()) not null
);

create index if not exists idx_player_leaderboard_stats_company_value
  on public.player_leaderboard_stats (company_value desc, updated_at desc);

create index if not exists idx_player_leaderboard_stats_level_experience
  on public.player_leaderboard_stats (level desc, experience desc);

alter table public.player_leaderboard_stats enable row level security;

drop policy if exists player_leaderboard_stats_read_authenticated on public.player_leaderboard_stats;
create policy player_leaderboard_stats_read_authenticated
  on public.player_leaderboard_stats
  for select
  to authenticated
  using (true);

drop policy if exists player_leaderboard_stats_update_own on public.player_leaderboard_stats;
create policy player_leaderboard_stats_update_own
  on public.player_leaderboard_stats
  for update
  to authenticated
  using (player_id = auth.uid())
  with check (player_id = auth.uid());

drop policy if exists player_leaderboard_stats_insert_own on public.player_leaderboard_stats;
create policy player_leaderboard_stats_insert_own
  on public.player_leaderboard_stats
  for insert
  to authenticated
  with check (player_id = auth.uid());

create or replace function public.refresh_player_leaderboard_stats(
  p_player_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_player public.players%rowtype;
  v_company_value jsonb := '{}'::jsonb;
  v_unlocked_count integer := 0;
  v_total_count integer := 0;
begin
  select * into v_player
  from public.players
  where id = p_player_id;

  if not found then
    return jsonb_build_object(
      'success', false,
      'message', 'Oyuncu bulunamadi.'
    );
  end if;

  perform public.ensure_player_achievement_rows(p_player_id);
  perform public.sync_player_achievement_snapshot(p_player_id);

  v_company_value := public.calculate_player_company_value(p_player_id);

  select
    count(*) filter (where pa.is_unlocked = true),
    count(*)
  into v_unlocked_count, v_total_count
  from public.player_achievements pa
  join public.achievement_definitions ad on ad.id = pa.achievement_id
  where pa.player_id = p_player_id
    and ad.is_active = true;

  insert into public.player_leaderboard_stats (
    player_id,
    player_name,
    company_name,
    avatar_id,
    level,
    experience,
    cash,
    gold,
    company_value,
    business_value,
    inventory_value,
    vehicle_value,
    building_base_value,
    building_upgrade_value,
    warehouse_inventory_value,
    store_inventory_value,
    production_inventory_value,
    achievement_unlocked_count,
    achievement_total_count,
    updated_at
  )
  values (
    v_player.id,
    coalesce(v_player.player_name, 'Oyuncu'),
    coalesce(v_player.company_name, 'Yeni Holding'),
    v_player.avatar_id,
    coalesce(v_player.level, 1),
    coalesce(v_player.experience, 0),
    coalesce(v_player.cash, 0),
    coalesce(v_player.gold, 0),
    coalesce((v_company_value ->> 'total_company_value')::numeric, 0),
    coalesce((v_company_value ->> 'business_value')::numeric, 0),
    coalesce((v_company_value ->> 'inventory_value')::numeric, 0),
    coalesce((v_company_value ->> 'vehicle_value')::numeric, 0),
    coalesce((v_company_value ->> 'building_base_value')::numeric, 0),
    coalesce((v_company_value ->> 'building_upgrade_value')::numeric, 0),
    coalesce((v_company_value ->> 'warehouse_inventory_value')::numeric, 0),
    coalesce((v_company_value ->> 'store_inventory_value')::numeric, 0),
    coalesce((v_company_value ->> 'production_inventory_value')::numeric, 0),
    coalesce(v_unlocked_count, 0),
    coalesce(v_total_count, 0),
    timezone('utc', now())
  )
  on conflict (player_id) do update
  set
    player_name = excluded.player_name,
    company_name = excluded.company_name,
    avatar_id = excluded.avatar_id,
    level = excluded.level,
    experience = excluded.experience,
    cash = excluded.cash,
    gold = excluded.gold,
    company_value = excluded.company_value,
    business_value = excluded.business_value,
    inventory_value = excluded.inventory_value,
    vehicle_value = excluded.vehicle_value,
    building_base_value = excluded.building_base_value,
    building_upgrade_value = excluded.building_upgrade_value,
    warehouse_inventory_value = excluded.warehouse_inventory_value,
    store_inventory_value = excluded.store_inventory_value,
    production_inventory_value = excluded.production_inventory_value,
    achievement_unlocked_count = excluded.achievement_unlocked_count,
    achievement_total_count = excluded.achievement_total_count,
    updated_at = timezone('utc', now());

  return jsonb_build_object(
    'success', true,
    'player_id', p_player_id,
    'company_value', coalesce((v_company_value ->> 'total_company_value')::numeric, 0)
  );
end;
$$;

create or replace function public.refresh_all_leaderboard_stats()
returns integer
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_player_id uuid;
  v_count integer := 0;
begin
  for v_player_id in
    select id
    from public.players
  loop
    perform public.refresh_player_leaderboard_stats(v_player_id);
    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

revoke all on function public.refresh_player_leaderboard_stats(uuid) from public;
grant execute on function public.refresh_player_leaderboard_stats(uuid) to authenticated;
grant execute on function public.refresh_player_leaderboard_stats(uuid) to service_role;

revoke all on function public.refresh_all_leaderboard_stats() from public;
grant execute on function public.refresh_all_leaderboard_stats() to service_role;

select public.refresh_all_leaderboard_stats();
