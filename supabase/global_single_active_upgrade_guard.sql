create or replace function public.get_player_any_active_building_upgrade()
returns public.building_upgrades
language sql
security definer
set search_path = public
as $$
  select bu.*
  from public.building_upgrades bu
  where bu.player_id = auth.uid()
    and bu.status = 'in_progress'
    and coalesce(bu.finish_at, timezone('utc', now())) > timezone('utc', now())
  order by bu.started_at desc
  limit 1;
$$;

create or replace function public.start_building_upgrade(
  p_player_id uuid,
  p_building_kind text,
  p_entity_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_now timestamptz := timezone('utc', now());
  v_player record;
  v_store record;
  v_arge_center record;
  v_field record;
  v_farm record;
  v_factory record;
  v_mine record;
  v_current_level integer;
  v_target_level integer;
  v_duration_minutes integer;
  v_slot_capacity_increase integer := 0;
  v_max_slot_increase integer := 2;
  v_input_capacity_increase integer := 0;
  v_output_capacity_increase integer := 0;
  v_upgrade_cost numeric := 0;
  v_upgrade_id uuid;
  v_finish_at timestamptz;
begin
  if p_player_id is null or p_player_id <> auth.uid() then
    raise exception 'Gecersiz oyuncu.';
  end if;

  perform public.complete_due_building_upgrades(100);

  select *
  into v_player
  from public.players
  where id = p_player_id
  for update;

  if not found then
    raise exception 'Oyuncu bulunamadi.';
  end if;

  if exists (
    select 1
    from public.building_upgrades bu
    where bu.player_id = p_player_id
      and bu.status = 'in_progress'
      and coalesce(bu.finish_at, v_now) > v_now
  ) then
    raise exception 'Ayni anda sadece tek yukseltme baslatabilirsin.';
  end if;

  if p_building_kind = 'store' then
    select
      s.*,
      st.name as store_type_name,
      st.construction_time_minutes,
      st.cost as store_type_cost,
      st.slot_capacity as base_slot_capacity
    into v_store
    from public.stores s
    join public.store_types st on st.id = s.store_type_id
    where s.id = p_entity_id
      and s.player_id = p_player_id
    for update;

    if not found then
      raise exception 'Magaza bulunamadi veya size ait degil.';
    end if;

    if coalesce(v_store.is_active, false) = false then
      raise exception 'Pasif magazada yukseltme baslatilamaz.';
    end if;

    v_current_level := coalesce(v_store.level, 1);
    v_target_level := v_current_level + 1;
    v_slot_capacity_increase := greatest(0, coalesce(v_store.base_slot_capacity, 0));
    v_duration_minutes := greatest(
      1,
      coalesce(v_store.construction_time_minutes, 0) * v_target_level
    );
    v_upgrade_cost := greatest(
      0,
      coalesce(v_store.store_type_cost, 0) * v_target_level
    );
    v_finish_at := v_now + make_interval(mins => v_duration_minutes);

    if coalesce(v_player.cash, 0) < v_upgrade_cost then
      raise exception 'Yetersiz bakiye. Gerekli: %, Mevcut: %',
        v_upgrade_cost,
        coalesce(v_player.cash, 0);
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
    )
    values (
      p_player_id,
      p_building_kind,
      p_entity_id,
      v_current_level,
      v_target_level,
      jsonb_build_object(
        'name', v_store.name,
        'store_type_id', v_store.store_type_id,
        'store_type_name', v_store.store_type_name,
        'base_duration_minutes', coalesce(v_store.construction_time_minutes, 0),
        'duration_minutes', v_duration_minutes,
        'upgrade_cost', v_upgrade_cost,
        'slot_capacity_increase', v_slot_capacity_increase,
        'max_slot_increase', v_max_slot_increase,
        'previous_slot_capacity', coalesce(v_store.slot_capacity, 0),
        'next_slot_capacity', coalesce(v_store.slot_capacity, 0) + v_slot_capacity_increase,
        'previous_max_slot_count', coalesce(v_store.max_slot_count, 0),
        'next_max_slot_count', coalesce(v_store.max_slot_count, 0) + v_max_slot_increase
      ),
      'in_progress',
      v_now,
      v_finish_at,
      v_now,
      v_now
    )
    returning id into v_upgrade_id;

    return jsonb_build_object(
      'success', true,
      'upgrade_id', v_upgrade_id,
      'building_kind', p_building_kind,
      'entity_id', p_entity_id,
      'current_level', v_current_level,
      'target_level', v_target_level,
      'duration_minutes', v_duration_minutes,
      'upgrade_cost', v_upgrade_cost,
      'slot_capacity_increase', v_slot_capacity_increase,
      'max_slot_increase', v_max_slot_increase,
      'finish_at', v_finish_at
    );
  elsif p_building_kind = 'field' then
    select
      f.*,
      ft.name as field_type_name,
      ft.construction_time_minutes,
      ft.cost as field_type_cost
    into v_field
    from public.fields f
    join public.field_types ft on ft.id = f.field_type_id
    where f.id = p_entity_id
      and f.player_id = p_player_id
    for update;

    if not found then
      raise exception 'Ciftlik bulunamadi veya size ait degil.';
    end if;

    if coalesce(v_field.is_active, false) = false then
      raise exception 'Pasif ciftlikte yukseltme baslatilamaz.';
    end if;

    v_current_level := coalesce(v_field.level, 1);
    v_target_level := v_current_level + 1;
    v_input_capacity_increase := greatest(0, coalesce(v_field.input_capacity, 0));
    v_output_capacity_increase := greatest(0, coalesce(v_field.output_capacity, 0));
    v_duration_minutes := greatest(
      1,
      coalesce(v_field.construction_time_minutes, 0) * v_target_level
    );
    v_upgrade_cost := greatest(
      0,
      coalesce(v_field.field_type_cost, 0) * v_target_level
    );
    v_finish_at := v_now + make_interval(mins => v_duration_minutes);

    if coalesce(v_player.cash, 0) < v_upgrade_cost then
      raise exception 'Yetersiz bakiye. Gerekli: %, Mevcut: %',
        v_upgrade_cost,
        coalesce(v_player.cash, 0);
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
    )
    values (
      p_player_id,
      p_building_kind,
      p_entity_id,
      v_current_level,
      v_target_level,
      jsonb_build_object(
        'name', v_field.name,
        'field_type_id', v_field.field_type_id,
        'field_type_name', v_field.field_type_name,
        'base_duration_minutes', coalesce(v_field.construction_time_minutes, 0),
        'duration_minutes', v_duration_minutes,
        'upgrade_cost', v_upgrade_cost,
        'slot_capacity_increase', 0,
        'max_slot_increase', 0,
        'previous_slot_capacity', 0,
        'next_slot_capacity', 0,
        'previous_max_slot_count', coalesce(v_field.max_slot_count, 0),
        'next_max_slot_count', coalesce(v_field.max_slot_count, 0),
        'input_capacity_increase', v_input_capacity_increase,
        'output_capacity_increase', v_output_capacity_increase,
        'previous_input_capacity', coalesce(v_field.input_capacity, 0),
        'next_input_capacity', coalesce(v_field.input_capacity, 0) + v_input_capacity_increase,
        'previous_output_capacity', coalesce(v_field.output_capacity, 0),
        'next_output_capacity', coalesce(v_field.output_capacity, 0) + v_output_capacity_increase
      ),
      'in_progress',
      v_now,
      v_finish_at,
      v_now,
      v_now
    )
    returning id into v_upgrade_id;

    return jsonb_build_object(
      'success', true,
      'upgrade_id', v_upgrade_id,
      'building_kind', p_building_kind,
      'entity_id', p_entity_id,
      'current_level', v_current_level,
      'target_level', v_target_level,
      'duration_minutes', v_duration_minutes,
      'upgrade_cost', v_upgrade_cost,
      'input_capacity_increase', v_input_capacity_increase,
      'output_capacity_increase', v_output_capacity_increase,
      'finish_at', v_finish_at
    );
  elsif p_building_kind = 'farm' then
    select
      f.*,
      ft.name as farm_type_name,
      ft.construction_time_minutes,
      ft.cost as farm_type_cost
    into v_farm
    from public.farms f
    join public.farm_types ft on ft.id = f.farm_type_id
    where f.id = p_entity_id
      and f.player_id = p_player_id
    for update;

    if not found then
      raise exception 'Tarla bulunamadi veya size ait degil.';
    end if;

    if coalesce(v_farm.is_active, false) = false then
      raise exception 'Pasif tarlada yukseltme baslatilamaz.';
    end if;

    v_current_level := coalesce(v_farm.level, 1);
    v_target_level := v_current_level + 1;
    v_input_capacity_increase := greatest(0, coalesce(v_farm.input_capacity, 0));
    v_output_capacity_increase := greatest(0, coalesce(v_farm.output_capacity, 0));
    v_duration_minutes := greatest(
      1,
      coalesce(v_farm.construction_time_minutes, 0) * v_target_level
    );
    v_upgrade_cost := greatest(
      0,
      coalesce(v_farm.farm_type_cost, 0) * v_target_level
    );
    v_finish_at := v_now + make_interval(mins => v_duration_minutes);

    if coalesce(v_player.cash, 0) < v_upgrade_cost then
      raise exception 'Yetersiz bakiye. Gerekli: %, Mevcut: %',
        v_upgrade_cost,
        coalesce(v_player.cash, 0);
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
    )
    values (
      p_player_id,
      p_building_kind,
      p_entity_id,
      v_current_level,
      v_target_level,
      jsonb_build_object(
        'name', v_farm.name,
        'farm_type_id', v_farm.farm_type_id,
        'farm_type_name', v_farm.farm_type_name,
        'base_duration_minutes', coalesce(v_farm.construction_time_minutes, 0),
        'duration_minutes', v_duration_minutes,
        'upgrade_cost', v_upgrade_cost,
        'slot_capacity_increase', 0,
        'max_slot_increase', 0,
        'previous_slot_capacity', 0,
        'next_slot_capacity', 0,
        'previous_max_slot_count', coalesce(v_farm.max_slot_count, 0),
        'next_max_slot_count', coalesce(v_farm.max_slot_count, 0),
        'input_capacity_increase', v_input_capacity_increase,
        'output_capacity_increase', v_output_capacity_increase,
        'previous_input_capacity', coalesce(v_farm.input_capacity, 0),
        'next_input_capacity', coalesce(v_farm.input_capacity, 0) + v_input_capacity_increase,
        'previous_output_capacity', coalesce(v_farm.output_capacity, 0),
        'next_output_capacity', coalesce(v_farm.output_capacity, 0) + v_output_capacity_increase
      ),
      'in_progress',
      v_now,
      v_finish_at,
      v_now,
      v_now
    )
    returning id into v_upgrade_id;

    return jsonb_build_object(
      'success', true,
      'upgrade_id', v_upgrade_id,
      'building_kind', p_building_kind,
      'entity_id', p_entity_id,
      'current_level', v_current_level,
      'target_level', v_target_level,
      'duration_minutes', v_duration_minutes,
      'upgrade_cost', v_upgrade_cost,
      'input_capacity_increase', v_input_capacity_increase,
      'output_capacity_increase', v_output_capacity_increase,
      'finish_at', v_finish_at
    );
  elsif p_building_kind = 'factory' then
    select
      f.*,
      ft.name as factory_type_name,
      ft.construction_time_minutes,
      ft.cost as factory_type_cost
    into v_factory
    from public.factories f
    join public.factory_types ft on ft.id = f.factory_type_id
    where f.id = p_entity_id
      and f.player_id = p_player_id
    for update;

    if not found then
      raise exception 'Fabrika bulunamadi veya size ait degil.';
    end if;

    if coalesce(v_factory.is_active, false) = false then
      raise exception 'Pasif fabrikada yukseltme baslatilamaz.';
    end if;

    v_current_level := coalesce(v_factory.level, 1);
    v_target_level := v_current_level + 1;
    v_input_capacity_increase := greatest(
      0,
      coalesce(v_factory.input_capacity, 0)
    );
    v_output_capacity_increase := greatest(
      0,
      coalesce(v_factory.output_capacity, 0)
    );
    v_duration_minutes := greatest(
      1,
      coalesce(v_factory.construction_time_minutes, 0) * v_target_level
    );
    v_upgrade_cost := greatest(
      0,
      coalesce(v_factory.factory_type_cost, 0) * v_target_level
    );
    v_finish_at := v_now + make_interval(mins => v_duration_minutes);

    if coalesce(v_player.cash, 0) < v_upgrade_cost then
      raise exception 'Yetersiz bakiye. Gerekli: %, Mevcut: %',
        v_upgrade_cost,
        coalesce(v_player.cash, 0);
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
    )
    values (
      p_player_id,
      p_building_kind,
      p_entity_id,
      v_current_level,
      v_target_level,
      jsonb_build_object(
        'name', v_factory.name,
        'factory_type_id', v_factory.factory_type_id,
        'factory_type_name', v_factory.factory_type_name,
        'base_duration_minutes', coalesce(v_factory.construction_time_minutes, 0),
        'duration_minutes', v_duration_minutes,
        'upgrade_cost', v_upgrade_cost,
        'slot_capacity_increase', 0,
        'max_slot_increase', 0,
        'previous_slot_capacity', 0,
        'next_slot_capacity', 0,
        'previous_max_slot_count', 0,
        'next_max_slot_count', 0,
        'input_capacity_increase', v_input_capacity_increase,
        'output_capacity_increase', v_output_capacity_increase,
        'previous_input_capacity', coalesce(v_factory.input_capacity, 0),
        'next_input_capacity', coalesce(v_factory.input_capacity, 0) + v_input_capacity_increase,
        'previous_output_capacity', coalesce(v_factory.output_capacity, 0),
        'next_output_capacity', coalesce(v_factory.output_capacity, 0) + v_output_capacity_increase
      ),
      'in_progress',
      v_now,
      v_finish_at,
      v_now,
      v_now
    )
    returning id into v_upgrade_id;

    return jsonb_build_object(
      'success', true,
      'upgrade_id', v_upgrade_id,
      'building_kind', p_building_kind,
      'entity_id', p_entity_id,
      'current_level', v_current_level,
      'target_level', v_target_level,
      'duration_minutes', v_duration_minutes,
      'upgrade_cost', v_upgrade_cost,
      'input_capacity_increase', v_input_capacity_increase,
      'output_capacity_increase', v_output_capacity_increase,
      'finish_at', v_finish_at
    );
  elsif p_building_kind = 'mine' then
    select
      m.*,
      mt.name as mine_type_name,
      mt.construction_time_minutes,
      mt.cost as mine_type_cost
    into v_mine
    from public.mines m
    join public.mine_types mt on mt.id = m.mine_type_id
    where m.id = p_entity_id
      and m.player_id = p_player_id
    for update;

    if not found then
      raise exception 'Maden bulunamadi veya size ait degil.';
    end if;

    if coalesce(v_mine.is_active, false) = false then
      raise exception 'Pasif madende yukseltme baslatilamaz.';
    end if;

    v_current_level := coalesce(v_mine.level, 1);
    v_target_level := v_current_level + 1;
    v_output_capacity_increase := greatest(
      0,
      coalesce(v_mine.output_capacity, 0)
    );
    v_duration_minutes := greatest(
      1,
      coalesce(v_mine.construction_time_minutes, 0) * v_target_level
    );
    v_upgrade_cost := greatest(
      0,
      coalesce(v_mine.mine_type_cost, 0) * v_target_level
    );
    v_finish_at := v_now + make_interval(mins => v_duration_minutes);

    if coalesce(v_player.cash, 0) < v_upgrade_cost then
      raise exception 'Yetersiz bakiye. Gerekli: %, Mevcut: %',
        v_upgrade_cost,
        coalesce(v_player.cash, 0);
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
    )
    values (
      p_player_id,
      p_building_kind,
      p_entity_id,
      v_current_level,
      v_target_level,
      jsonb_build_object(
        'name', v_mine.name,
        'mine_type_id', v_mine.mine_type_id,
        'mine_type_name', v_mine.mine_type_name,
        'base_duration_minutes', coalesce(v_mine.construction_time_minutes, 0),
        'duration_minutes', v_duration_minutes,
        'upgrade_cost', v_upgrade_cost,
        'slot_capacity_increase', 0,
        'max_slot_increase', 0,
        'previous_slot_capacity', 0,
        'next_slot_capacity', 0,
        'previous_max_slot_count', 0,
        'next_max_slot_count', 0,
        'input_capacity_increase', 0,
        'output_capacity_increase', v_output_capacity_increase,
        'previous_input_capacity', 0,
        'next_input_capacity', 0,
        'previous_output_capacity', coalesce(v_mine.output_capacity, 0),
        'next_output_capacity', coalesce(v_mine.output_capacity, 0) + v_output_capacity_increase
      ),
      'in_progress',
      v_now,
      v_finish_at,
      v_now,
      v_now
    )
    returning id into v_upgrade_id;

    return jsonb_build_object(
      'success', true,
      'upgrade_id', v_upgrade_id,
      'building_kind', p_building_kind,
      'entity_id', p_entity_id,
      'current_level', v_current_level,
      'target_level', v_target_level,
      'duration_minutes', v_duration_minutes,
      'upgrade_cost', v_upgrade_cost,
      'output_capacity_increase', v_output_capacity_increase,
      'finish_at', v_finish_at
    );
  elsif p_building_kind = 'arge_center' then
    select *
    into v_arge_center
    from public.arge_centers ac
    where ac.id = p_entity_id
      and ac.player_id = p_player_id
    for update;

    if not found then
      raise exception 'AR-GE merkezi bulunamadi veya size ait degil.';
    end if;

    if coalesce(v_arge_center.is_active, false) = false then
      raise exception 'Pasif AR-GE merkezinde yukseltme baslatilamaz.';
    end if;

    v_current_level := coalesce(v_arge_center.level, 1);
    v_target_level := v_current_level + 1;
    v_duration_minutes := greatest(1, 60 * v_target_level);
    v_upgrade_cost := greatest(0, 25000 * v_target_level);
    v_finish_at := v_now + make_interval(mins => v_duration_minutes);

    if coalesce(v_player.cash, 0) < v_upgrade_cost then
      raise exception 'Yetersiz bakiye. Gerekli: %, Mevcut: %',
        v_upgrade_cost,
        coalesce(v_player.cash, 0);
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
    )
    values (
      p_player_id,
      p_building_kind,
      p_entity_id,
      v_current_level,
      v_target_level,
      jsonb_build_object(
        'name', v_arge_center.name,
        'duration_minutes', v_duration_minutes,
        'upgrade_cost', v_upgrade_cost,
        'slot_capacity_increase', 0,
        'max_slot_increase', 0,
        'previous_slot_capacity', 0,
        'next_slot_capacity', 0,
        'previous_max_slot_count', 0,
        'next_max_slot_count', 0,
        'input_capacity_increase', 0,
        'output_capacity_increase', 0,
        'previous_input_capacity', 0,
        'next_input_capacity', 0,
        'previous_output_capacity', 0,
        'next_output_capacity', 0,
        'previous_concurrent_researches', coalesce(v_arge_center.max_concurrent_researches, 1),
        'next_concurrent_researches',
          case
            when v_target_level >= 6 then 4
            when v_target_level >= 4 then 3
            when v_target_level >= 2 then 2
            else 1
          end,
        'previous_duration_reduction_pct', coalesce(v_arge_center.duration_reduction_pct, 0),
        'next_duration_reduction_pct',
          case
            when v_target_level = 2 then 5
            when v_target_level = 3 then 10
            when v_target_level = 4 then 15
            when v_target_level = 5 then 20
            when v_target_level >= 6 then 25
            else 0
          end
      ),
      'in_progress',
      v_now,
      v_finish_at,
      v_now,
      v_now
    )
    returning id into v_upgrade_id;

    return jsonb_build_object(
      'success', true,
      'upgrade_id', v_upgrade_id,
      'building_kind', p_building_kind,
      'entity_id', p_entity_id,
      'current_level', v_current_level,
      'target_level', v_target_level,
      'duration_minutes', v_duration_minutes,
      'upgrade_cost', v_upgrade_cost,
      'finish_at', v_finish_at
    );
  end if;

  raise exception 'Bu building_kind icin yukseltme destegi henuz yok: %', p_building_kind;
end;
$function$;

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
$$;

grant execute on function public.get_player_any_active_building_upgrade() to authenticated;
