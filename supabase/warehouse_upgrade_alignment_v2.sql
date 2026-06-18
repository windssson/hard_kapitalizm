create or replace function public.get_player_active_warehouse_upgrade(
  p_warehouse_id uuid
)
returns public.building_upgrades
language sql
security definer
set search_path = public
as $$
  select bu.*
  from public.building_upgrades bu
  join public.warehouses w on w.id = bu.entity_id
  where bu.building_kind = 'warehouse'
    and bu.entity_id = p_warehouse_id
    and bu.status = 'in_progress'
    and coalesce(bu.finish_at, timezone('utc', now())) > timezone('utc', now())
    and w.player_id = auth.uid()
  order by bu.started_at desc
  limit 1;
$$;

create or replace function public.get_player_any_active_warehouse_upgrade()
returns public.building_upgrades
language sql
security definer
set search_path = public
as $$
  select bu.*
  from public.building_upgrades bu
  where bu.player_id = auth.uid()
    and bu.building_kind = 'warehouse'
    and bu.status = 'in_progress'
    and coalesce(bu.finish_at, timezone('utc', now())) > timezone('utc', now())
  order by bu.started_at desc
  limit 1;
$$;

create or replace function public.start_warehouse_upgrade(
  p_player_id uuid,
  p_warehouse_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_now timestamptz := timezone('utc', now());
  v_player public.players%rowtype;
  v_warehouse record;
  v_upgrade_id uuid;
  v_target_level integer;
  v_duration_minutes integer;
  v_capacity_increase numeric;
  v_upgrade_cost numeric(18,2);
begin
  if auth.uid() is null or auth.uid() <> p_player_id then
    raise exception 'Yetkisiz islem.';
  end if;

  perform public.complete_due_warehouse_upgrades(100);

  select *
  into v_player
  from public.players
  where id = p_player_id
  for update;

  if not found then
    raise exception 'Oyuncu bulunamadi.';
  end if;

  select
    w.*,
    wt.name as warehouse_type_name,
    wt.construction_time_minutes,
    wt.cost as warehouse_type_cost,
    wt.base_capacity
  into v_warehouse
  from public.warehouses w
  join public.warehouse_types wt on wt.id = w.warehouse_type_id
  where w.id = p_warehouse_id
    and w.player_id = p_player_id
  for update;

  if not found then
    raise exception 'Depo bulunamadi veya size ait degil.';
  end if;

  if coalesce(v_warehouse.is_active, false) = false then
    raise exception 'Pasif depoda yukseltme baslatilamaz.';
  end if;

  if exists (
    select 1
    from public.building_upgrades bu
    where bu.building_kind = 'warehouse'
      and bu.player_id = p_player_id
      and bu.status = 'in_progress'
      and coalesce(bu.finish_at, v_now) > v_now
  ) then
    return jsonb_build_object(
      'success', false,
      'message', 'Once devam eden depo yukseltmesini tamamlamalisin.'
    );
  end if;

  v_target_level := greatest(coalesce(v_warehouse.level, 1), 1) + 1;
  v_duration_minutes := greatest(
    1,
    coalesce(v_warehouse.construction_time_minutes, 0) * v_target_level
  );
  v_capacity_increase := greatest(coalesce(v_warehouse.base_capacity, 0), 0);
  v_upgrade_cost := ceil(
    (coalesce(v_warehouse.warehouse_type_cost, 0) * 0.30) *
    power(1.10::numeric, greatest(coalesce(v_warehouse.level, 1) - 1, 0))
  );

  if coalesce(v_player.cash, 0) < v_upgrade_cost then
    return jsonb_build_object(
      'success', false,
      'message', 'Yetersiz bakiye.',
      'required_cash', v_upgrade_cost,
      'current_cash', coalesce(v_player.cash, 0)
    );
  end if;

  update public.players
  set cash = cash - v_upgrade_cost
  where id = p_player_id;

  insert into public.building_upgrades (
    player_id,
    building_kind,
    entity_id,
    current_level,
    target_level,
    params,
    status,
    started_at,
    finish_at,
    created_at,
    updated_at
  ) values (
    p_player_id,
    'warehouse',
    p_warehouse_id,
    v_warehouse.level,
    v_target_level,
    jsonb_build_object(
      'name', v_warehouse.name,
      'warehouse_type_id', v_warehouse.warehouse_type_id,
      'warehouse_type_name', v_warehouse.warehouse_type_name,
      'base_duration_minutes', coalesce(v_warehouse.construction_time_minutes, 0),
      'duration_minutes', v_duration_minutes,
      'upgrade_cost', v_upgrade_cost,
      'capacity_increase', v_capacity_increase,
      'previous_capacity', coalesce(v_warehouse.capacity, 0),
      'next_capacity', coalesce(v_warehouse.capacity, 0) + v_capacity_increase
    ),
    'in_progress',
    v_now,
    v_now + make_interval(mins => v_duration_minutes),
    v_now,
    v_now
  )
  returning id into v_upgrade_id;

  return jsonb_build_object(
    'success', true,
    'upgrade_id', v_upgrade_id,
    'entity_id', p_warehouse_id,
    'current_level', v_warehouse.level,
    'target_level', v_target_level,
    'duration_minutes', v_duration_minutes,
    'upgrade_cost', v_upgrade_cost,
    'capacity_increase', v_capacity_increase,
    'finish_at', v_now + make_interval(mins => v_duration_minutes)
  );
end;
$$;

create or replace function public.complete_due_warehouse_upgrades(
  p_limit integer default 100
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_now timestamptz := timezone('utc', now());
  v_row record;
  v_completed_count integer := 0;
  v_failed_count integer := 0;
begin
  for v_row in
    select
      bu.id,
      bu.player_id,
      bu.entity_id,
      bu.target_level,
      coalesce((bu.params ->> 'capacity_increase')::numeric, 0) as capacity_increase
    from public.building_upgrades bu
    where bu.building_kind = 'warehouse'
      and bu.status = 'in_progress'
      and bu.finish_at <= v_now
    order by bu.finish_at asc
    limit greatest(coalesce(p_limit, 100), 1)
    for update skip locked
  loop
    begin
      update public.warehouses
      set
        level = v_row.target_level,
        capacity = capacity + v_row.capacity_increase,
        updated_at = v_now
      where id = v_row.entity_id
        and player_id = v_row.player_id;

      update public.building_upgrades
      set
        status = 'completed',
        completed_at = v_now,
        updated_at = v_now
      where id = v_row.id;

      v_completed_count := v_completed_count + 1;
    exception when others then
      v_failed_count := v_failed_count + 1;
    end;
  end loop;

  return jsonb_build_object(
    'success', true,
    'completed_count', v_completed_count,
    'failed_count', v_failed_count
  );
end;
$$;

create or replace function public.finish_warehouse_upgrade_with_gold(
  p_player_id uuid,
  p_upgrade_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_now timestamptz := timezone('utc', now());
  v_player_gold numeric;
  v_upgrade public.building_upgrades%rowtype;
  v_star_cost integer;
  v_remaining_minutes numeric;
  v_capacity_increase numeric;
begin
  if auth.uid() is null or auth.uid() <> p_player_id then
    raise exception 'Yetkisiz islem.';
  end if;

  select *
  into v_upgrade
  from public.building_upgrades
  where id = p_upgrade_id
    and player_id = p_player_id
    and building_kind = 'warehouse'
  for update;

  if not found then
    return jsonb_build_object(
      'success', false,
      'message', 'Yukseltme bulunamadi.'
    );
  end if;

  if v_upgrade.status <> 'in_progress' then
    return jsonb_build_object(
      'success', false,
      'message', 'Bu yukseltme zaten tamamlanmis veya gecersiz.'
    );
  end if;

  v_remaining_minutes := extract(epoch from (v_upgrade.finish_at - v_now)) / 60.0;

  if v_remaining_minutes > 0 then
    v_star_cost := greatest(ceil(v_remaining_minutes / 10.0)::integer, 1);

    select gold
    into v_player_gold
    from public.players
    where id = p_player_id
    for update;

    if coalesce(v_player_gold, 0) < v_star_cost then
      return jsonb_build_object(
        'success', false,
        'message', 'Yetersiz yildiz.',
        'required_gold', v_star_cost,
        'current_gold', coalesce(v_player_gold, 0)
      );
    end if;

    update public.players
    set gold = gold - v_star_cost
    where id = p_player_id;
  else
    v_star_cost := 0;
  end if;

  v_capacity_increase := coalesce((v_upgrade.params ->> 'capacity_increase')::numeric, 0);

  update public.warehouses
  set
    level = v_upgrade.target_level,
    capacity = capacity + v_capacity_increase,
    updated_at = v_now
  where id = v_upgrade.entity_id
    and player_id = p_player_id;

  update public.building_upgrades
  set
    status = 'completed',
    completed_at = v_now,
    finish_at = v_now,
    updated_at = v_now
  where id = p_upgrade_id;

  return jsonb_build_object(
    'success', true,
    'entity_id', v_upgrade.entity_id,
    'target_level', v_upgrade.target_level,
    'capacity_increase', v_capacity_increase,
    'gold_spent', v_star_cost,
    'completed_at', v_now
  );
end;
$$;
