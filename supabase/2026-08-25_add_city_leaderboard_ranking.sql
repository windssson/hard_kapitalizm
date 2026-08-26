-- 1. player_leaderboard_stats tablosuna sehir alanlarini ekle
alter table public.player_leaderboard_stats
add column if not exists headquarters_city_id uuid references public.cities(id) on delete set null,
add column if not exists headquarters_city_name text;

create index if not exists player_leaderboard_stats_city_idx
on public.player_leaderboard_stats (headquarters_city_id);

-- 2. refresh_player_leaderboard_stats fonksiyonunu sehir alanlariyla guncelle
create or replace function public.refresh_player_leaderboard_stats(p_player_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_player public.players%rowtype;
  v_city_name text;
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

  -- NPC Lojistik kontrolü: Liderlik tablosuna eklenmesini engelle ve varsa sil
  if p_player_id = public.get_npc_logistics_player_id() then
    delete from public.player_leaderboard_stats where player_id = p_player_id;
    return jsonb_build_object(
      'success', true,
      'player_id', p_player_id,
      'message', 'NPC Lojistik liderlik tablosunda takip edilmez.',
      'company_value', 0
    );
  end if;

  if v_player.headquarters_city_id is not null then
    select name into v_city_name
    from public.cities
    where id = v_player.headquarters_city_id;
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
    headquarters_city_id,
    headquarters_city_name,
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
    v_player.headquarters_city_id,
    v_city_name,
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
    headquarters_city_id = excluded.headquarters_city_id,
    headquarters_city_name = excluded.headquarters_city_name,
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
$function$;

-- 3. get_leaderboard fonksiyonunu sehir filtresi destegiyle guncelle
create or replace function public.get_leaderboard(
  p_sort_by_field text default 'company_value'::text,
  p_limit integer default 100,
  p_city_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_sql text;
  v_sort_col text;
  v_where_clause text := '';
  v_result jsonb;
begin
  v_sort_col := case lower(trim(coalesce(p_sort_by_field, 'company_value')))
    when 'company_value' then 'company_value'
    when 'level' then 'level'
    when 'achievement_unlocked_count' then 'achievement_unlocked_count'
    when 'cash' then 'cash'
    when 'gold' then 'gold'
    when 'experience' then 'experience'
    when 'business_value' then 'business_value'
    when 'inventory_value' then 'inventory_value'
    when 'vehicle_value' then 'vehicle_value'
    else 'company_value'
  end;

  if p_city_id is not null then
    v_where_clause := format('WHERE headquarters_city_id = %L', p_city_id);
  end if;

  v_sql := format(
    'SELECT coalesce(jsonb_agg(to_jsonb(t)), ''[]''::jsonb)
     FROM (
       SELECT 
         player_id,
         player_name,
         company_name,
         avatar_id,
         headquarters_city_id,
         headquarters_city_name,
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
         created_at,
         updated_at
       FROM public.player_leaderboard_stats
       %s
       ORDER BY %I DESC NULLS LAST, level DESC, player_name ASC
       LIMIT %L
     ) t',
    v_where_clause,
    v_sort_col,
    coalesce(p_limit, 100)
  );

  execute v_sql into v_result;

  return coalesce(v_result, '[]'::jsonb);
end;
$function$;

-- 4. get_player_leaderboard_rank_info fonksiyonunu sehir filtresi destegiyle guncelle
create or replace function public.get_player_leaderboard_rank_info(
  p_player_id uuid,
  p_sort_by_field text default 'company_value'::text,
  p_city_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_sort_col text;
  v_where_clause text := '';
  v_sql text;
  v_rank bigint;
  v_entry jsonb;
begin
  -- Önce oyuncunun güncel istatistiğini yenile
  perform public.refresh_player_leaderboard_stats(p_player_id);

  v_sort_col := case lower(trim(coalesce(p_sort_by_field, 'company_value')))
    when 'company_value' then 'company_value'
    when 'level' then 'level'
    when 'achievement_unlocked_count' then 'achievement_unlocked_count'
    when 'cash' then 'cash'
    when 'gold' then 'gold'
    when 'experience' then 'experience'
    when 'business_value' then 'business_value'
    when 'inventory_value' then 'inventory_value'
    when 'vehicle_value' then 'vehicle_value'
    else 'company_value'
  end;

  if p_city_id is not null then
    v_where_clause := format('WHERE headquarters_city_id = %L', p_city_id);
  end if;

  v_sql := format(
    'WITH ranked AS (
       SELECT 
         player_id,
         row_number() OVER (ORDER BY %I DESC NULLS LAST, level DESC, player_name ASC) as rank_pos,
         to_jsonb(pls) as entry_data
       FROM public.player_leaderboard_stats pls
       %s
     )
     SELECT rank_pos, entry_data
     FROM ranked
     WHERE player_id = %L',
    v_sort_col,
    v_where_clause,
    p_player_id
  );

  execute v_sql into v_rank, v_entry;

  if v_rank is null then
    return null;
  end if;

  return jsonb_build_object(
    'rank', v_rank,
    'entry', v_entry
  );
end;
$function$;
