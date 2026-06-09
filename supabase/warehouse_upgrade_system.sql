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
    and w.player_id = auth.uid()
  order by bu.created_at desc
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
  v_player public.players%rowtype;
  v_warehouse public.warehouses%rowtype;
  v_type public.warehouse_types%rowtype;
  v_upgrade_id uuid;
  v_target_level integer;
  v_duration_minutes integer;
  v_capacity_increase integer;
  v_upgrade_cost numeric(18,2);
begin
  if auth.uid() is null or auth.uid() <> p_player_id then
    raise exception 'Yetkisiz islem.';
  end if;

  select * into v_player
  from public.players
  where id = p_player_id;

  if not found then
    raise exception 'Oyuncu bulunamadi.';
  end if;

  select * into v_warehouse
  from public.warehouses
  where id = p_warehouse_id
    and player_id = p_player_id;

  if not found then
    raise exception 'Depo bulunamadi veya size ait degil.';
  end if;

  if exists (
    select 1
    from public.building_upgrades
    where building_kind = 'warehouse'
      and entity_id = p_warehouse_id
      and status = 'in_progress'
  ) then
    return jsonb_build_object(
      'success', false,
      'message', 'Bu depo icin zaten aktif bir yukseltme var.'
    );
  end if;

  select * into v_type
  from public.warehouse_types
  where id = v_warehouse.warehouse_type_id;

  if not found then
    raise exception 'Depo tipi bulunamadi.';
  end if;

  v_target_level := greatest(v_warehouse.level, 1) + 1;
  v_duration_minutes := greatest(coalesce(v_type.construction_time_minutes, 0), 1) * v_target_level;
  v_capacity_increase := greatest(coalesce(v_type.base_capacity, 0), 0);
  v_upgrade_cost := ceil((coalesce(v_type.cost, 0) * 0.30) * power(1.10::numeric, greatest(v_warehouse.level - 1, 0)));

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
    finish_at
  ) values (
    p_player_id,
    'warehouse',
    p_warehouse_id,
    v_warehouse.level,
    v_target_level,
    jsonb_build_object(
      'name', v_warehouse.name,
      'duration_minutes', v_duration_minutes,
      'upgrade_cost', v_upgrade_cost,
      'capacity_increase', v_capacity_increase,
      'previous_capacity', v_warehouse.capacity,
      'next_capacity', v_warehouse.capacity + v_capacity_increase
    ),
    'in_progress',
    timezone('utc', now()),
    timezone('utc', now()) + make_interval(mins => v_duration_minutes)
  )
  returning id into v_upgrade_id;

  return jsonb_build_object(
    'success', true,
    'upgrade_id', v_upgrade_id,
    'entity_id', p_warehouse_id,
    'target_level', v_target_level,
    'upgrade_cost', v_upgrade_cost,
    'capacity_increase', v_capacity_increase
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
  v_row record;
  v_completed_count integer := 0;
  v_entity_ids uuid[] := '{}';
begin
  for v_row in
    select
      bu.id,
      bu.entity_id,
      bu.target_level,
      coalesce((bu.params ->> 'next_capacity')::numeric, 0) as next_capacity
    from public.building_upgrades bu
    where bu.building_kind = 'warehouse'
      and bu.status = 'in_progress'
      and bu.finish_at <= timezone('utc', now())
    order by bu.finish_at asc
    limit greatest(coalesce(p_limit, 100), 1)
  loop
    update public.warehouses
    set
      level = v_row.target_level,
      capacity = v_row.next_capacity,
      updated_at = timezone('utc', now())
    where id = v_row.entity_id;

    update public.building_upgrades
    set
      status = 'completed',
      completed_at = timezone('utc', now()),
      updated_at = timezone('utc', now())
    where id = v_row.id;

    v_completed_count := v_completed_count + 1;
    v_entity_ids := array_append(v_entity_ids, v_row.entity_id);
  end loop;

  return jsonb_build_object(
    'success', true,
    'completed_count', v_completed_count,
    'warehouse_ids', coalesce(to_jsonb(v_entity_ids), '[]'::jsonb)
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
  v_player public.players%rowtype;
  v_upgrade public.building_upgrades%rowtype;
  v_star_cost integer;
  v_remaining_minutes integer;
  v_next_capacity numeric;
begin
  if auth.uid() is null or auth.uid() <> p_player_id then
    raise exception 'Yetkisiz islem.';
  end if;

  select * into v_player
  from public.players
  where id = p_player_id;

  if not found then
    raise exception 'Oyuncu bulunamadi.';
  end if;

  select * into v_upgrade
  from public.building_upgrades
  where id = p_upgrade_id
    and player_id = p_player_id
    and building_kind = 'warehouse'
    and status = 'in_progress';

  if not found then
    return jsonb_build_object(
      'success', false,
      'message', 'Aktif depo yukseltmesi bulunamadi.'
    );
  end if;

  v_remaining_minutes := greatest(
    ceil(extract(epoch from (v_upgrade.finish_at - timezone('utc', now()))) / 60.0)::integer,
    0
  );
  v_star_cost := case
    when v_remaining_minutes <= 0 then 0
    else greatest(ceil(v_remaining_minutes / 10.0)::integer, 1)
  end;

  if coalesce(v_player.gold, 0) < v_star_cost then
    return jsonb_build_object(
      'success', false,
      'message', 'Yetersiz yildiz.',
      'required_gold', v_star_cost,
      'current_gold', coalesce(v_player.gold, 0)
    );
  end if;

  if v_star_cost > 0 then
    update public.players
    set gold = gold - v_star_cost
    where id = p_player_id;
  end if;

  v_next_capacity := coalesce((v_upgrade.params ->> 'next_capacity')::numeric, 0);

  update public.warehouses
  set
    level = v_upgrade.target_level,
    capacity = v_next_capacity,
    updated_at = timezone('utc', now())
  where id = v_upgrade.entity_id
    and player_id = p_player_id;

  update public.building_upgrades
  set
    status = 'completed',
    completed_at = timezone('utc', now()),
    finish_at = timezone('utc', now()),
    updated_at = timezone('utc', now())
  where id = p_upgrade_id;

  return jsonb_build_object(
    'success', true,
    'entity_id', v_upgrade.entity_id,
    'star_cost', v_star_cost,
    'target_level', v_upgrade.target_level,
    'next_capacity', v_next_capacity
  );
end;
$$;

grant execute on function public.get_player_active_warehouse_upgrade(uuid) to authenticated;
grant execute on function public.start_warehouse_upgrade(uuid, uuid) to authenticated;
grant execute on function public.complete_due_warehouse_upgrades(integer) to authenticated;
grant execute on function public.finish_warehouse_upgrade_with_gold(uuid, uuid) to authenticated;
