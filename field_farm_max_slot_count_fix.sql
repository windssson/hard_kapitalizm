alter table public.field_types
  add column if not exists max_slot_count integer default 5;

alter table public.farm_types
  add column if not exists max_slot_count integer default 5;

alter table public.farm_types
  drop column if exists slot_capacity;

alter table public.farm_types
  drop column if exists created_at;

update public.field_types
set max_slot_count = 5
where coalesce(max_slot_count, 0) <= 0;

update public.farm_types
set max_slot_count = 5
where coalesce(max_slot_count, 0) <= 0;

create or replace function public.start_building_construction(
  p_player_id uuid,
  p_building_kind text,
  p_type_id uuid,
  p_city_id uuid,
  p_name text
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_player public.players%rowtype;
  v_cost integer;
  v_required_level integer;
  v_construction_time_minutes integer;
  v_construction_id uuid;
  v_finish_at timestamptz;
  v_params jsonb;
  v_clean_name text;
begin
  select * into v_player
  from public.players
  where id = p_player_id
  for update;

  if not found then
    return jsonb_build_object('success', false, 'message', 'Oyuncu bulunamadi.');
  end if;

  if not exists (
    select 1 from public.cities where id = p_city_id and is_active = true
  ) then
    return jsonb_build_object('success', false, 'message', 'Sehir bulunamadi.');
  end if;

  if exists (
    select 1
    from public.building_constructions
    where player_id = p_player_id and status = 'in_progress'
  ) then
    return jsonb_build_object('success', false, 'message', 'Devam eden bir insaat zaten var.');
  end if;

  v_clean_name := nullif(trim(p_name), '');

  if p_building_kind = 'store' then
    select
      coalesce(cost, 0),
      coalesce(required_level, 1),
      coalesce(construction_time_minutes, 0),
      jsonb_build_object(
        'store_type_id', id,
        'city_id', p_city_id,
        'name', v_clean_name,
        'cost', coalesce(cost, 0),
        'required_level', coalesce(required_level, 1),
        'construction_time_minutes', coalesce(construction_time_minutes, 0),
        'level', 1,
        'current_slot_count', 0,
        'max_slot_count', coalesce(max_slot_count, 0),
        'slot_capacity', coalesce(slot_capacity, 0)
      )
    into v_cost, v_required_level, v_construction_time_minutes, v_params
    from public.store_types
    where id = p_type_id;

  elsif p_building_kind = 'warehouse' then
    select
      coalesce(cost, 0),
      coalesce(required_level, 1),
      coalesce(construction_time_minutes, 0),
      jsonb_build_object(
        'warehouse_type_id', id,
        'city_id', p_city_id,
        'name', v_clean_name,
        'cost', coalesce(cost, 0),
        'required_level', coalesce(required_level, 1),
        'construction_time_minutes', coalesce(construction_time_minutes, 0),
        'level', 1,
        'capacity', coalesce(base_capacity, 0),
        'reserved_capacity', 0
      )
    into v_cost, v_required_level, v_construction_time_minutes, v_params
    from public.warehouse_types
    where id = p_type_id;

  elsif p_building_kind = 'factory' then
    select
      coalesce(cost, 0),
      coalesce(required_level, 1),
      coalesce(construction_time_minutes, 0),
      jsonb_build_object(
        'factory_type_id', id,
        'city_id', p_city_id,
        'name', v_clean_name,
        'cost', coalesce(cost, 0),
        'required_level', coalesce(required_level, 1),
        'construction_time_minutes', coalesce(construction_time_minutes, 0),
        'level', 1,
        'current_slot_count', 0,
        'max_slot_count', coalesce(max_slot_count, 0),
        'input_capacity', coalesce(input_capacity, 0),
        'output_capacity', coalesce(output_capacity, 0)
      )
    into v_cost, v_required_level, v_construction_time_minutes, v_params
    from public.factory_types
    where id = p_type_id;

  elsif p_building_kind = 'field' then
    select
      coalesce(cost, 0),
      coalesce(required_level, 1),
      coalesce(construction_time_minutes, 0),
      jsonb_build_object(
        'field_type_id', id,
        'city_id', p_city_id,
        'name', v_clean_name,
        'cost', coalesce(cost, 0),
        'required_level', coalesce(required_level, 1),
        'construction_time_minutes', coalesce(construction_time_minutes, 0),
        'level', 1,
        'current_slot_count', 0,
        'max_slot_count', coalesce(max_slot_count, 5),
        'input_capacity', coalesce(input_capacity, 0),
        'output_capacity', coalesce(output_capacity, 0)
      )
    into v_cost, v_required_level, v_construction_time_minutes, v_params
    from public.field_types
    where id = p_type_id;

  elsif p_building_kind = 'farm' then
    select
      coalesce(cost, 0),
      coalesce(required_level, 1),
      coalesce(construction_time_minutes, 0),
      jsonb_build_object(
        'farm_type_id', id,
        'city_id', p_city_id,
        'name', v_clean_name,
        'cost', coalesce(cost, 0),
        'required_level', coalesce(required_level, 1),
        'construction_time_minutes', coalesce(construction_time_minutes, 0),
        'level', 1,
        'current_slot_count', 0,
        'max_slot_count', coalesce(max_slot_count, 5),
        'input_capacity', coalesce(input_capacity, 0),
        'output_capacity', coalesce(output_capacity, 0)
      )
    into v_cost, v_required_level, v_construction_time_minutes, v_params
    from public.farm_types
    where id = p_type_id;

  elsif p_building_kind = 'mine' then
    select
      coalesce(cost, 0),
      coalesce(required_level, 1),
      coalesce(construction_time_minutes, 0),
      jsonb_build_object(
        'mine_type_id', id,
        'city_id', p_city_id,
        'name', v_clean_name,
        'cost', coalesce(cost, 0),
        'required_level', coalesce(required_level, 1),
        'construction_time_minutes', coalesce(construction_time_minutes, 0),
        'level', 1,
        'output_capacity', coalesce(output_capacity, 0)
      )
    into v_cost, v_required_level, v_construction_time_minutes, v_params
    from public.mine_types
    where id = p_type_id;

  elsif p_building_kind = 'logistics_company' then
    select
      coalesce(cost, 0),
      coalesce(required_level, 1),
      coalesce(construction_time_minutes, 0),
      jsonb_build_object(
        'company_type_id', id,
        'name', v_clean_name,
        'cost', coalesce(cost, 0),
        'required_level', coalesce(required_level, 1),
        'construction_time_minutes', coalesce(construction_time_minutes, 0),
        'level', 1
      )
    into v_cost, v_required_level, v_construction_time_minutes, v_params
    from public.logistics_company_types
    where id = p_type_id;

  else
    return jsonb_build_object('success', false, 'message', 'Desteklenmeyen yapi tipi.');
  end if;

  if v_cost is null then
    return jsonb_build_object('success', false, 'message', 'Yapi tipi bulunamadi.');
  end if;

  if coalesce(v_player.level, 1) < v_required_level then
    return jsonb_build_object('success', false, 'message', 'Seviye yetersiz.');
  end if;

  if coalesce(v_player.cash, 0) < v_cost then
    return jsonb_build_object('success', false, 'message', 'Yetersiz nakit.');
  end if;

  update public.players
  set cash = cash - v_cost
  where id = p_player_id;

  v_finish_at := timezone('utc', now()) + make_interval(mins => v_construction_time_minutes);

  insert into public.building_constructions (
    player_id,
    building_kind,
    params,
    status,
    started_at,
    finish_at,
    completed_at
  )
  values (
    p_player_id,
    p_building_kind,
    v_params,
    'in_progress',
    timezone('utc', now()),
    v_finish_at,
    null
  )
  returning id into v_construction_id;

  return jsonb_build_object(
    'success', true,
    'construction_id', v_construction_id,
    'building_kind', p_building_kind,
    'status', 'in_progress',
    'started_at', timezone('utc', now()),
    'finish_at', v_finish_at,
    'cost', v_cost,
    'remaining_cash', coalesce(v_player.cash, 0) - v_cost,
    'params', v_params
  );
end;
$$;
