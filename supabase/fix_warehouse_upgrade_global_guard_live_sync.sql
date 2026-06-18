create or replace function public.start_warehouse_upgrade(
  p_player_id uuid,
  p_warehouse_id uuid
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
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
  perform public.complete_due_building_upgrades(100);

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
    where bu.player_id = p_player_id
      and bu.status = 'in_progress'
      and coalesce(bu.finish_at, v_now) > v_now
  ) then
    return jsonb_build_object(
      'success', false,
      'message', 'Ayni anda sadece tek yukseltme baslatabilirsin.'
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
$function$;
