-- Tax Lock System (v2): Exceeding a level-based tax limit will freeze production and lock actions.

-- 1. Create a function to determine the tax limit based on the player's level
CREATE OR REPLACE FUNCTION public.get_player_tax_limit(p_level integer)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
begin
  if p_level <= 1 then return 10000;
  elsif p_level = 2 then return 25000;
  elsif p_level = 3 then return 50000;
  elsif p_level = 4 then return 100000;
  elsif p_level = 5 then return 250000;
  elsif p_level = 6 then return 500000;
  elsif p_level = 7 then return 1000000;
  else return p_level * 200000;
  end if;
end;
$$;

-- 2. Create a function to check if the player is tax blocked
CREATE OR REPLACE FUNCTION public.is_player_tax_blocked(p_player_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
declare
  v_tax_debt numeric;
  v_level integer;
  v_limit numeric;
begin
  if p_player_id is null then
    return false;
  end if;

  select coalesce(tax_debt, 0) into v_tax_debt
  from public.player_taxes
  where player_id = p_player_id;

  if v_tax_debt <= 0 then
    return false;
  end if;

  select coalesce(level, 1) into v_level
  from public.players
  where id = p_player_id;

  v_limit := public.get_player_tax_limit(v_level);

  return v_tax_debt > v_limit;
end;
$$;

-- 3. Create a function to get detailed tax status for the client
CREATE OR REPLACE FUNCTION public.get_player_tax_status()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
declare
  v_player_id uuid := auth.uid();
  v_tax_debt numeric := 0;
  v_level integer := 1;
  v_limit numeric := 0;
  v_is_blocked boolean := false;
begin
  if v_player_id is null then
    return jsonb_build_object(
      'tax_debt', 0,
      'tax_limit', 0,
      'is_blocked', false
    );
  end if;

  select coalesce(tax_debt, 0) into v_tax_debt
  from public.player_taxes
  where player_id = v_player_id;

  select coalesce(level, 1) into v_level
  from public.players
  where id = v_player_id;

  v_limit := public.get_player_tax_limit(v_level);
  v_is_blocked := v_tax_debt > v_limit;

  return jsonb_build_object(
    'tax_debt', v_tax_debt,
    'tax_limit', v_limit,
    'is_blocked', v_is_blocked
  );
end;
$$;

-- 4. Redefine process_player_production_entry to freeze production if tax blocked
CREATE OR REPLACE FUNCTION public.process_player_production_entry(p_player_id uuid DEFAULT auth.uid(), p_owner_kind text DEFAULT NULL::text, p_owner_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_boosts_result jsonb := jsonb_build_object('success', true, 'completed_count', 0);
  v_upgrades_result jsonb := jsonb_build_object('success', true, 'completed_count', 0);
  v_factory_result jsonb := jsonb_build_object('success', true, 'processed_count', 0, 'produced_count', 0, 'pending_only_count', 0, 'skipped_count', 0, 'total_produced', 0);
  v_field_farm_result jsonb := jsonb_build_object('success', true, 'processed_count', 0, 'produced_count', 0, 'pending_only_count', 0, 'skipped_count', 0, 'total_produced', 0);
  v_mine_result jsonb := jsonb_build_object('success', true, 'processed_count', 0, 'produced_count', 0, 'pending_only_count', 0, 'skipped_count', 0, 'total_produced', 0);
begin
  if p_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  -- Tax Block Check: If the player is tax blocked, freeze their production calculations!
  if public.is_player_tax_blocked(p_player_id) then
    return jsonb_build_object(
      'success', false,
      'tax_blocked', true,
      'message', 'Vergi borcu limiti asildigi icin uretim donduruldu.'
    );
  end if;

  if p_owner_kind is null then
    v_boosts_result := public.complete_due_building_boosts(100);
    v_upgrades_result := public.complete_due_building_upgrades(100);
  elsif p_owner_id is not null then
    if exists (
      select 1
      from public.building_upgrades bu
      where bu.player_id = p_player_id
        and bu.building_kind = p_owner_kind
        and bu.entity_id = p_owner_id
        and bu.status = 'in_progress'
        and bu.finish_at <= timezone('utc'::text, now())
    ) then
      v_upgrades_result := public.complete_due_building_upgrades(100);
    end if;
  end if;

  if p_owner_kind is null or p_owner_kind = 'factory' then
    v_factory_result := public.process_factory_production_entry(
      p_player_id,
      case when p_owner_kind = 'factory' then p_owner_id else null end
    );
  end if;

  if p_owner_kind is null or p_owner_kind in ('field', 'farm') then
    v_field_farm_result := public.process_field_farm_production_entry(
      p_player_id,
      case when p_owner_kind in ('field', 'farm') then p_owner_kind else null end,
      case when p_owner_kind in ('field', 'farm') then p_owner_id else null end
    );
  end if;

  if p_owner_kind is null or p_owner_kind = 'mine' then
    v_mine_result := public.process_mine_production_entry(
      p_player_id,
      case when p_owner_kind = 'mine' then p_owner_id else null end
    );
  end if;

  return jsonb_build_object(
    'success', true,
    'completed_due_building_boosts', case
      when p_owner_kind is null then v_boosts_result
      else jsonb_build_object('success', true, 'completed_count', 0, 'skipped', true)
    end,
    'completed_due_building_upgrades', v_upgrades_result,
    'factory', v_factory_result,
    'field_farm', v_field_farm_result,
    'mine', v_mine_result
  );
end;
$function$;

-- 5. Redefine start_building_construction to block if tax blocked
CREATE OR REPLACE FUNCTION public.start_building_construction(p_player_id uuid, p_building_kind text, p_type_id uuid, p_city_id uuid, p_name text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
  -- Tax Block Check
  if public.is_player_tax_blocked(p_player_id) then
    return jsonb_build_object('success', false, 'message', 'Vergi borcu limiti asildigi icin insaat baslatilamaz.');
  end if;

  select * into v_player from public.players where id = p_player_id for update;
  if not found then return jsonb_build_object('success', false, 'message', 'Oyuncu bulunamadi.'); end if;
  if not exists (select 1 from public.cities where id = p_city_id and is_active = true) then
    return jsonb_build_object('success', false, 'message', 'Sehir bulunamadi.');
  end if;
  if exists (select 1 from public.building_constructions where player_id = p_player_id and status = 'in_progress') then
    return jsonb_build_object('success', false, 'message', 'Devam eden bir insaat zaten var.');
  end if;

  v_clean_name := nullif(trim(p_name), '');

  if p_building_kind = 'store' then
    select coalesce(cost, 0), coalesce(required_level, 1), coalesce(construction_time_minutes, 0),
      jsonb_build_object('store_type_id', id, 'city_id', p_city_id, 'name', v_clean_name, 'cost', coalesce(cost, 0),
        'required_level', coalesce(required_level, 1), 'construction_time_minutes', coalesce(construction_time_minutes, 0),
        'level', 1, 'current_slot_count', 0, 'max_slot_count', coalesce(max_slot_count, 0), 'slot_capacity', coalesce(slot_capacity, 0))
    into v_cost, v_required_level, v_construction_time_minutes, v_params
    from public.store_types where id = p_type_id;
  elsif p_building_kind = 'warehouse' then
    select coalesce(cost, 0), coalesce(required_level, 1), coalesce(construction_time_minutes, 0),
      jsonb_build_object('warehouse_type_id', id, 'city_id', p_city_id, 'name', v_clean_name, 'cost', coalesce(cost, 0),
        'required_level', coalesce(required_level, 1), 'construction_time_minutes', coalesce(construction_time_minutes, 0),
        'level', 1, 'capacity', coalesce(base_capacity, 0), 'reserved_capacity', 0)
    into v_cost, v_required_level, v_construction_time_minutes, v_params
    from public.warehouse_types where id = p_type_id;
  elsif p_building_kind = 'factory' then
    select coalesce(cost, 0), coalesce(required_level, 1), coalesce(construction_time_minutes, 0),
      jsonb_build_object('factory_type_id', id, 'city_id', p_city_id, 'name', v_clean_name, 'cost', coalesce(cost, 0),
        'required_level', coalesce(required_level, 1), 'construction_time_minutes', coalesce(construction_time_minutes, 0),
        'level', 1, 'quality_level', 0, 'boost_multiplier', 1.00, 'input_capacity', coalesce(input_capacity, 0), 'output_capacity', coalesce(output_capacity, 0))
    into v_cost, v_required_level, v_construction_time_minutes, v_params
    from public.factory_types where id = p_type_id;
  elsif p_building_kind = 'field' then
    select coalesce(cost, 0), coalesce(required_level, 1), coalesce(construction_time_minutes, 0),
      jsonb_build_object('field_type_id', id, 'city_id', p_city_id, 'name', v_clean_name, 'cost', coalesce(cost, 0),
        'required_level', coalesce(required_level, 1), 'construction_time_minutes', coalesce(construction_time_minutes, 0),
        'level', 1, 'current_slot_count', 0, 'max_slot_count', coalesce(max_slot_count, 5),
        'input_capacity', coalesce(input_capacity, 0), 'output_capacity', coalesce(output_capacity, 0))
    into v_cost, v_required_level, v_construction_time_minutes, v_params
    from public.field_types where id = p_type_id;
  elsif p_building_kind = 'farm' then
    select coalesce(cost, 0), coalesce(required_level, 1), coalesce(construction_time_minutes, 0),
      jsonb_build_object('farm_type_id', id, 'city_id', p_city_id, 'name', v_clean_name, 'cost', coalesce(cost, 0),
        'required_level', coalesce(required_level, 1), 'construction_time_minutes', coalesce(construction_time_minutes, 0),
        'level', 1, 'current_slot_count', 0, 'max_slot_count', coalesce(max_slot_count, 5),
        'input_capacity', coalesce(input_capacity, 0), 'output_capacity', coalesce(output_capacity, 0))
    into v_cost, v_required_level, v_construction_time_minutes, v_params
    from public.farm_types where id = p_type_id;
  elsif p_building_kind = 'mine' then
    select coalesce(cost, 0), coalesce(required_level, 1), coalesce(construction_time_minutes, 0),
      jsonb_build_object('mine_type_id', id, 'city_id', p_city_id, 'name', v_clean_name, 'cost', coalesce(cost, 0),
        'required_level', coalesce(required_level, 1), 'construction_time_minutes', coalesce(construction_time_minutes, 0),
        'level', 1, 'output_capacity', coalesce(output_capacity, 0))
    into v_cost, v_required_level, v_construction_time_minutes, v_params
    from public.mine_types where id = p_type_id;
  else
    return jsonb_build_object('success', false, 'message', 'Desteklenmeyen yapi tipi.');
  end if;

  if v_cost is null then return jsonb_build_object('success', false, 'message', 'Yapi tipi bulunamadi.'); end if;
  if coalesce(v_player.level, 1) < v_required_level then return jsonb_build_object('success', false, 'message', 'Seviye yetersiz.'); end if;
  if coalesce(v_player.cash, 0) < v_cost then return jsonb_build_object('success', false, 'message', 'Yetersiz nakit.'); end if;

  update public.players set cash = cash - v_cost where id = p_player_id;
  perform public.log_player_cash_change(
    p_player_id, -v_cost, v_player.cash,
    'building_construction',
    format('Bina insaati: %s (%s)', coalesce(v_clean_name, p_building_kind), p_building_kind),
    p_city_id, 'city'
  );

  v_finish_at := timezone('utc', now()) + make_interval(mins => v_construction_time_minutes);
  insert into public.building_constructions (player_id, building_kind, params, status, started_at, finish_at, completed_at)
  values (p_player_id, p_building_kind, v_params, 'in_progress', timezone('utc', now()), v_finish_at, null)
  returning id into v_construction_id;

  return jsonb_build_object(
    'success', true, 'construction_id', v_construction_id, 'building_kind', p_building_kind,
    'status', 'in_progress', 'started_at', timezone('utc', now()), 'finish_at', v_finish_at,
    'cost', v_cost, 'remaining_cash', coalesce(v_player.cash, 0) - v_cost, 'params', v_params
  );
end;
$function$;

-- 6. Redefine start_building_upgrade to block if tax blocked
CREATE OR REPLACE FUNCTION public.start_building_upgrade(p_player_id uuid, p_building_kind text, p_entity_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
  v_entity_name text := '';
begin
  -- Tax Block Check
  if public.is_player_tax_blocked(p_player_id) then
    raise exception 'Vergi borcu limiti asildigi icin yukseltme baslatilamaz.';
  end if;

  if p_player_id is null or p_player_id <> auth.uid() then raise exception 'Gecersiz oyuncu.'; end if;

  select * into v_player from public.players where id = p_player_id for update;
  if not found then raise exception 'Oyuncu bulunamadi.'; end if;

  if exists (
    select 1 from public.building_upgrades bu
    where bu.player_id = p_player_id and bu.building_kind = p_building_kind
      and bu.entity_id = p_entity_id and bu.status = 'in_progress' and coalesce(bu.finish_at, v_now) > v_now
  ) then
    raise exception 'Bu isletme icin zaten devam eden bir yukseltme var.';
  end if;

  if p_building_kind = 'store' then
    select s.*, st.name as store_type_name, st.construction_time_minutes, st.cost as store_type_cost, st.slot_capacity as base_slot_capacity
    into v_store from public.stores s join public.store_types st on st.id = s.store_type_id
    where s.id = p_entity_id and s.player_id = p_player_id for update;
    if not found then raise exception 'Magaza bulunamadi veya size ait degil.'; end if;
    if coalesce(v_store.is_active, false) = false then raise exception 'Pasif magazada yukseltme baslatilamaz.'; end if;

    v_entity_name := v_store.name;
    v_current_level := coalesce(v_store.level, 1);
    v_target_level := v_current_level + 1;
    v_slot_capacity_increase := greatest(0, coalesce(v_store.base_slot_capacity, 0));
    v_duration_minutes := greatest(1, coalesce(v_store.construction_time_minutes, 0) * v_target_level);
    v_upgrade_cost := greatest(0, coalesce(v_store.store_type_cost, 0) * v_target_level);
    v_finish_at := v_now + make_interval(mins => v_duration_minutes);

    if coalesce(v_player.cash, 0) < v_upgrade_cost then
      raise exception 'Yetersiz bakiye. Gerekli: %, Mevcut: %', v_upgrade_cost, coalesce(v_player.cash, 0);
    end if;

    update public.players set cash = cash - v_upgrade_cost where id = p_player_id;
    perform public.log_player_cash_change(
      p_player_id, -v_upgrade_cost, v_player.cash,
      'building_upgrade', format('Magaza yukseltme: %s Seviye %s->%s', v_store.name, v_current_level, v_target_level),
      p_entity_id, 'store'
    );

    insert into public.building_upgrades (player_id, building_kind, entity_id, current_level, target_level, params, status, started_at, finish_at, created_at, updated_at)
    values (p_player_id, p_building_kind, p_entity_id, v_current_level, v_target_level,
      jsonb_build_object('name', v_store.name, 'store_type_id', v_store.store_type_id, 'store_type_name', v_store.store_type_name,
        'base_duration_minutes', coalesce(v_store.construction_time_minutes, 0), 'duration_minutes', v_duration_minutes, 'upgrade_cost', v_upgrade_cost,
        'slot_capacity_increase', v_slot_capacity_increase, 'max_slot_increase', v_max_slot_increase,
        'previous_slot_capacity', coalesce(v_store.slot_capacity, 0), 'next_slot_capacity', coalesce(v_store.slot_capacity, 0) + v_slot_capacity_increase,
        'previous_max_slot_count', coalesce(v_store.max_slot_count, 0), 'next_max_slot_count', coalesce(v_store.max_slot_count, 0) + v_max_slot_increase),
      'in_progress', v_now, v_finish_at, v_now, v_now)
    returning id into v_upgrade_id;

    return jsonb_build_object('success', true, 'upgrade_id', v_upgrade_id, 'building_kind', p_building_kind, 'entity_id', p_entity_id,
      'current_level', v_current_level, 'target_level', v_target_level, 'duration_minutes', v_duration_minutes, 'upgrade_cost', v_upgrade_cost,
      'slot_capacity_increase', v_slot_capacity_increase, 'max_slot_increase', v_max_slot_increase, 'finish_at', v_finish_at);

  elsif p_building_kind = 'field' then
    select f.*, ft.name as field_type_name, ft.construction_time_minutes, ft.cost as field_type_cost
    into v_field from public.fields f join public.field_types ft on ft.id = f.field_type_id
    where f.id = p_entity_id and f.player_id = p_player_id for update;
    if not found then raise exception 'Ciftlik bulunamadi veya size ait degil.'; end if;
    if coalesce(v_field.is_active, false) = false then raise exception 'Pasif ciftlikte yukseltme baslatilamaz.'; end if;

    v_current_level := coalesce(v_field.level, 1); v_target_level := v_current_level + 1;
    v_input_capacity_increase := greatest(0, coalesce(v_field.input_capacity, 0));
    v_output_capacity_increase := greatest(0, coalesce(v_field.output_capacity, 0));
    v_duration_minutes := greatest(1, coalesce(v_field.construction_time_minutes, 0) * v_target_level);
    v_upgrade_cost := greatest(0, coalesce(v_field.field_type_cost, 0) * v_target_level);
    v_finish_at := v_now + make_interval(mins => v_duration_minutes);
    if coalesce(v_player.cash, 0) < v_upgrade_cost then raise exception 'Yetersiz bakiye. Gerekli: %, Mevcut: %', v_upgrade_cost, coalesce(v_player.cash, 0); end if;

    update public.players set cash = cash - v_upgrade_cost where id = p_player_id;
    perform public.log_player_cash_change(p_player_id, -v_upgrade_cost, v_player.cash, 'building_upgrade',
      format('Tarla yukseltme: %s Seviye %s->%s', v_field.name, v_current_level, v_target_level), p_entity_id, 'field');

    insert into public.building_upgrades (player_id, building_kind, entity_id, current_level, target_level, params, status, started_at, finish_at, created_at, updated_at)
    values (p_player_id, p_building_kind, p_entity_id, v_current_level, v_target_level,
      jsonb_build_object('name', v_field.name, 'field_type_id', v_field.field_type_id, 'field_type_name', v_field.field_type_name,
        'base_duration_minutes', coalesce(v_field.construction_time_minutes, 0), 'duration_minutes', v_duration_minutes, 'upgrade_cost', v_upgrade_cost,
        'slot_capacity_increase', 0, 'max_slot_increase', 0, 'previous_slot_capacity', 0, 'next_slot_capacity', 0,
        'previous_max_slot_count', coalesce(v_field.max_slot_count, 0), 'next_max_slot_count', coalesce(v_field.max_slot_count, 0),
        'input_capacity_increase', v_input_capacity_increase, 'output_capacity_increase', v_output_capacity_increase,
        'previous_input_capacity', coalesce(v_field.input_capacity, 0), 'next_input_capacity', coalesce(v_field.input_capacity, 0) + v_input_capacity_increase,
        'previous_output_capacity', coalesce(v_field.output_capacity, 0), 'next_output_capacity', coalesce(v_field.output_capacity, 0) + v_output_capacity_increase),
      'in_progress', v_now, v_finish_at, v_now, v_now)
    returning id into v_upgrade_id;
    return jsonb_build_object('success', true, 'upgrade_id', v_upgrade_id, 'building_kind', p_building_kind, 'entity_id', p_entity_id,
      'current_level', v_current_level, 'target_level', v_target_level, 'duration_minutes', v_duration_minutes, 'upgrade_cost', v_upgrade_cost,
      'input_capacity_increase', v_input_capacity_increase, 'output_capacity_increase', v_output_capacity_increase, 'finish_at', v_finish_at);

  elsif p_building_kind = 'farm' then
    select f.*, ft.name as farm_type_name, ft.construction_time_minutes, ft.cost as farm_type_cost
    into v_farm from public.farms f join public.farm_types ft on ft.id = f.farm_type_id
    where f.id = p_entity_id and f.player_id = p_player_id for update;
    if not found then raise exception 'Tarla bulunamadi veya size ait degil.'; end if;
    if coalesce(v_farm.is_active, false) = false then raise exception 'Pasif tarlada yukseltme baslatilamaz.'; end if;

    v_current_level := coalesce(v_farm.level, 1); v_target_level := v_current_level + 1;
    v_input_capacity_increase := greatest(0, coalesce(v_farm.input_capacity, 0));
    v_output_capacity_increase := greatest(0, coalesce(v_farm.output_capacity, 0));
    v_duration_minutes := greatest(1, coalesce(v_farm.construction_time_minutes, 0) * v_target_level);
    v_upgrade_cost := greatest(0, coalesce(v_farm.farm_type_cost, 0) * v_target_level);
    v_finish_at := v_now + make_interval(mins => v_duration_minutes);
    if coalesce(v_player.cash, 0) < v_upgrade_cost then raise exception 'Yetersiz bakiye. Gerekli: %, Mevcut: %', v_upgrade_cost, coalesce(v_player.cash, 0); end if;

    update public.players set cash = cash - v_upgrade_cost where id = p_player_id;
    perform public.log_player_cash_change(p_player_id, -v_upgrade_cost, v_player.cash, 'building_upgrade',
      format('Ciftlik yukseltme: %s Seviye %s->%s', v_farm.name, v_current_level, v_target_level), p_entity_id, 'farm');

    insert into public.building_upgrades (player_id, building_kind, entity_id, current_level, target_level, params, status, started_at, finish_at, created_at, updated_at)
    values (p_player_id, p_building_kind, p_entity_id, v_current_level, v_target_level,
      jsonb_build_object('name', v_farm.name, 'farm_type_id', v_farm.farm_type_id, 'farm_type_name', v_farm.farm_type_name,
        'base_duration_minutes', coalesce(v_farm.construction_time_minutes, 0), 'duration_minutes', v_duration_minutes, 'upgrade_cost', v_upgrade_cost,
        'slot_capacity_increase', 0, 'max_slot_increase', 0, 'previous_slot_capacity', 0, 'next_slot_capacity', 0,
        'previous_max_slot_count', coalesce(v_farm.max_slot_count, 0), 'next_max_slot_count', coalesce(v_farm.max_slot_count, 0),
        'input_capacity_increase', v_input_capacity_increase, 'output_capacity_increase', v_output_capacity_increase,
        'previous_input_capacity', coalesce(v_farm.input_capacity, 0), 'next_input_capacity', coalesce(v_farm.input_capacity, 0) + v_input_capacity_increase,
        'previous_output_capacity', coalesce(v_farm.output_capacity, 0), 'next_output_capacity', coalesce(v_farm.output_capacity, 0) + v_output_capacity_increase),
      'in_progress', v_now, v_finish_at, v_now, v_now)
    returning id into v_upgrade_id;
    return jsonb_build_object('success', true, 'upgrade_id', v_upgrade_id, 'building_kind', p_building_kind, 'entity_id', p_entity_id,
      'current_level', v_current_level, 'target_level', v_target_level, 'duration_minutes', v_duration_minutes, 'upgrade_cost', v_upgrade_cost,
      'input_capacity_increase', v_input_capacity_increase, 'output_capacity_increase', v_output_capacity_increase, 'finish_at', v_finish_at);

  elsif p_building_kind = 'factory' then
    select f.*, ft.name as factory_type_name, ft.construction_time_minutes, ft.cost as factory_type_cost
    into v_factory from public.factories f join public.factory_types ft on ft.id = f.factory_type_id
    where f.id = p_entity_id and f.player_id = p_player_id for update;
    if not found then raise exception 'Fabrika bulunamadi veya size ait degil.'; end if;
    if coalesce(v_factory.is_active, false) = false then raise exception 'Pasif fabrikada yukseltme baslatilamaz.'; end if;

    v_current_level := coalesce(v_factory.level, 1); v_target_level := v_current_level + 1;
    v_input_capacity_increase := greatest(0, coalesce(v_factory.input_capacity, 0));
    v_output_capacity_increase := greatest(0, coalesce(v_factory.output_capacity, 0));
    v_duration_minutes := greatest(1, coalesce(v_factory.construction_time_minutes, 0) * v_target_level);
    v_upgrade_cost := greatest(0, coalesce(v_factory.factory_type_cost, 0) * v_target_level);
    v_finish_at := v_now + make_interval(mins => v_duration_minutes);
    if coalesce(v_player.cash, 0) < v_upgrade_cost then raise exception 'Yetersiz bakiye. Gerekli: %, Mevcut: %', v_upgrade_cost, coalesce(v_player.cash, 0); end if;

    update public.players set cash = cash - v_upgrade_cost where id = p_player_id;
    perform public.log_player_cash_change(p_player_id, -v_upgrade_cost, v_player.cash, 'building_upgrade',
      format('Fabrika yukseltme: %s Seviye %s->%s', v_factory.name, v_current_level, v_target_level), p_entity_id, 'factory');

    insert into public.building_upgrades (player_id, building_kind, entity_id, current_level, target_level, params, status, started_at, finish_at, created_at, updated_at)
    values (p_player_id, p_building_kind, p_entity_id, v_current_level, v_target_level,
      jsonb_build_object('name', v_factory.name, 'factory_type_id', v_factory.factory_type_id, 'factory_type_name', v_factory.factory_type_name,
        'base_duration_minutes', coalesce(v_factory.construction_time_minutes, 0), 'duration_minutes', v_duration_minutes, 'upgrade_cost', v_upgrade_cost,
        'slot_capacity_increase', 0, 'max_slot_increase', 0, 'previous_slot_capacity', 0, 'next_slot_capacity', 0, 'previous_max_slot_count', 0, 'next_max_slot_count', 0,
        'input_capacity_increase', v_input_capacity_increase, 'output_capacity_increase', v_output_capacity_increase,
        'previous_input_capacity', coalesce(v_factory.input_capacity, 0), 'next_input_capacity', coalesce(v_factory.input_capacity, 0) + v_input_capacity_increase,
        'previous_output_capacity', coalesce(v_factory.output_capacity, 0), 'next_output_capacity', coalesce(v_factory.output_capacity, 0) + v_output_capacity_increase),
      'in_progress', v_now, v_finish_at, v_now, v_now)
    returning id into v_upgrade_id;
    return jsonb_build_object('success', true, 'upgrade_id', v_upgrade_id, 'building_kind', p_building_kind, 'entity_id', p_entity_id,
      'current_level', v_current_level, 'target_level', v_target_level, 'duration_minutes', v_duration_minutes, 'upgrade_cost', v_upgrade_cost,
      'input_capacity_increase', v_input_capacity_increase, 'output_capacity_increase', v_output_capacity_increase, 'finish_at', v_finish_at);

  elsif p_building_kind = 'mine' then
    select m.*, mt.name as mine_type_name, mt.construction_time_minutes, mt.cost as mine_type_cost
    into v_mine from public.mines m join public.mine_types mt on mt.id = m.mine_type_id
    where m.id = p_entity_id and m.player_id = p_player_id for update;
    if not found then raise exception 'Maden bulunamadi veya size ait degil.'; end if;
    if coalesce(v_mine.is_active, false) = false then raise exception 'Pasif madende yukseltme baslatilamaz.'; end if;

    v_current_level := coalesce(v_mine.level, 1); v_target_level := v_current_level + 1;
    v_output_capacity_increase := greatest(0, coalesce(v_mine.output_capacity, 0));
    v_duration_minutes := greatest(1, coalesce(v_mine.construction_time_minutes, 0) * v_target_level);
    v_upgrade_cost := greatest(0, coalesce(v_mine.mine_type_cost, 0) * v_target_level);
    v_finish_at := v_now + make_interval(mins => v_duration_minutes);
    if coalesce(v_player.cash, 0) < v_upgrade_cost then raise exception 'Yetersiz bakiye. Gerekli: %, Mevcut: %', v_upgrade_cost, coalesce(v_player.cash, 0); end if;

    update public.players set cash = cash - v_upgrade_cost where id = p_player_id;
    perform public.log_player_cash_change(p_player_id, -v_upgrade_cost, v_player.cash, 'building_upgrade',
      format('Maden yukseltme: %s Seviye %s->%s', v_mine.name, v_current_level, v_target_level), p_entity_id, 'mine');

    insert into public.building_upgrades (player_id, building_kind, entity_id, current_level, target_level, params, status, started_at, finish_at, created_at, updated_at)
    values (p_player_id, p_building_kind, p_entity_id, v_current_level, v_target_level,
      jsonb_build_object('name', v_mine.name, 'mine_type_id', v_mine.mine_type_id, 'mine_type_name', v_mine.mine_type_name,
        'base_duration_minutes', coalesce(v_mine.construction_time_minutes, 0), 'duration_minutes', v_duration_minutes, 'upgrade_cost', v_upgrade_cost,
        'slot_capacity_increase', 0, 'max_slot_increase', 0, 'previous_slot_capacity', 0, 'next_slot_capacity', 0, 'previous_max_slot_count', 0, 'next_max_slot_count', 0,
        'input_capacity_increase', 0, 'output_capacity_increase', v_output_capacity_increase,
        'previous_input_capacity', 0, 'next_input_capacity', 0,
        'previous_output_capacity', coalesce(v_mine.output_capacity, 0), 'next_output_capacity', coalesce(v_mine.output_capacity, 0) + v_output_capacity_increase),
      'in_progress', v_now, v_finish_at, v_now, v_now)
    returning id into v_upgrade_id;
    return jsonb_build_object('success', true, 'upgrade_id', v_upgrade_id, 'building_kind', p_building_kind, 'entity_id', p_entity_id,
      'current_level', v_current_level, 'target_level', v_target_level, 'duration_minutes', v_duration_minutes, 'upgrade_cost', v_upgrade_cost,
      'output_capacity_increase', v_output_capacity_increase, 'finish_at', v_finish_at);

  elsif p_building_kind = 'arge_center' then
    select * into v_arge_center from public.arge_centers ac where ac.id = p_entity_id and ac.player_id = p_player_id for update;
    if not found then raise exception 'AR-GE merkezi bulunamadi veya size ait degil.'; end if;
    if coalesce(v_arge_center.is_active, false) = false then raise exception 'Pasif AR-GE merkezinde yukseltme baslatilamaz.'; end if;

    v_current_level := coalesce(v_arge_center.level, 1); v_target_level := v_current_level + 1;
    v_duration_minutes := greatest(1, 60 * v_target_level);
    v_upgrade_cost := greatest(0, 25000 * v_target_level);
    v_finish_at := v_now + make_interval(mins => v_duration_minutes);
    if coalesce(v_player.cash, 0) < v_upgrade_cost then raise exception 'Yetersiz bakiye. Gerekli: %, Mevcut: %', v_upgrade_cost, coalesce(v_player.cash, 0); end if;

    update public.players set cash = cash - v_upgrade_cost where id = p_player_id;
    perform public.log_player_cash_change(p_player_id, -v_upgrade_cost, v_player.cash, 'building_upgrade',
      format('AR-GE yukseltme: %s Seviye %s->%s', v_arge_center.name, v_current_level, v_target_level), p_entity_id, 'arge_center');

    insert into public.building_upgrades (player_id, building_kind, entity_id, current_level, target_level, params, status, started_at, finish_at, created_at, updated_at)
    values (p_player_id, p_building_kind, p_entity_id, v_current_level, v_target_level,
      jsonb_build_object('name', v_arge_center.name, 'duration_minutes', v_duration_minutes, 'upgrade_cost', v_upgrade_cost,
        'slot_capacity_increase', 0, 'max_slot_increase', 0, 'previous_slot_capacity', 0, 'next_slot_capacity', 0,
        'previous_max_slot_count', 0, 'next_max_slot_count', 0, 'input_capacity_increase', 0, 'output_capacity_increase', 0,
        'previous_concurrent_researches', coalesce(v_arge_center.max_concurrent_researches, 1),
        'next_concurrent_researches', case when v_target_level >= 6 then 4 when v_target_level >= 4 then 3 when v_target_level >= 2 then 2 else 1 end,
        'previous_duration_reduction_pct', coalesce(v_arge_center.duration_reduction_pct, 0),
        'next_duration_reduction_pct', case when v_target_level = 2 then 5 when v_target_level = 3 then 10 when v_target_level = 4 then 15 when v_target_level = 5 then 20 when v_target_level >= 6 then 25 else 0 end),
      'in_progress', v_now, v_finish_at, v_now, v_now)
    returning id into v_upgrade_id;
    return jsonb_build_object('success', true, 'upgrade_id', v_upgrade_id, 'building_kind', p_building_kind, 'entity_id', p_entity_id,
      'current_level', v_current_level, 'target_level', v_target_level, 'duration_minutes', v_duration_minutes, 'upgrade_cost', v_upgrade_cost, 'finish_at', v_finish_at);
  end if;

  raise exception 'Bu building_kind icin yukseltme destegi henuz yok: %', p_building_kind;
end;
$function$;

-- 7. Redefine start_building_boost to block if tax blocked
CREATE OR REPLACE FUNCTION public.start_building_boost(p_player_id uuid, p_building_kind text, p_entity_id uuid, p_duration_hours integer, p_star_cost integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_now timestamptz := timezone('utc', now());
  v_finish_at timestamptz;
  v_boost_id uuid;
  v_multiplier numeric := 2.00;
  v_player_gold numeric;
begin
  -- Tax Block Check
  if public.is_player_tax_blocked(p_player_id) then
    raise exception 'Vergi borcu limiti asildigi icin boost baslatilamaz.';
  end if;

  if p_player_id is null or p_player_id <> auth.uid() then
    raise exception 'Gecersiz oyuncu.';
  end if;

  if p_duration_hours not in (6, 12, 24) then
    raise exception 'Boost suresi yalnizca 6, 12 veya 24 saat olabilir.';
  end if;

  if coalesce(p_star_cost, 0) < 0 then
    raise exception 'Boost maliyeti gecersiz.';
  end if;

  if exists (
    select 1
    from public.building_boosts bb
    where bb.player_id = p_player_id
      and bb.building_kind = p_building_kind
      and bb.entity_id = p_entity_id
      and bb.status = 'in_progress'
      and coalesce(bb.finish_at, v_now) > v_now
  ) then
    raise exception 'Bu isletme icin zaten aktif bir boost var.';
  end if;

  select gold
  into v_player_gold
  from public.players
  where id = p_player_id
  for update;

  if not found then
    raise exception 'Oyuncu bulunamadi.';
  end if;

  if coalesce(v_player_gold, 0) < p_star_cost then
    raise exception 'Yetersiz yildiz. Gerekli: %, Mevcut: %', p_star_cost, coalesce(v_player_gold, 0);
  end if;

  if p_building_kind = 'store' then
    if not exists (
      select 1
      from public.stores s
      where s.id = p_entity_id
        and s.player_id = p_player_id
        and s.is_active = true
    ) then
      raise exception 'Magaza bulunamadi veya aktif degil.';
    end if;

    update public.store_slots
    set
      boost_multiplier = v_multiplier,
      updated_at = v_now
    where store_id = p_entity_id;
  elsif p_building_kind in ('field', 'farm') then
    if not exists (
      select 1
      from public.production_slots ps
      where ps.owner_kind = p_building_kind
        and ps.owner_id = p_entity_id
    ) then
      raise exception 'Uretim slotlari bulunamadi.';
    end if;

    update public.production_slots
    set
      boost_multiplier = v_multiplier,
      updated_at = v_now
    where owner_kind = p_building_kind
      and owner_id = p_entity_id;
  elsif p_building_kind = 'factory' then
    update public.factories
    set
      boost_multiplier = v_multiplier,
      updated_at = v_now
    where id = p_entity_id
      and player_id = p_player_id
      and is_active = true;

    if not found then
      raise exception 'Fabrika bulunamadi veya aktif degil.';
    end if;
  elsif p_building_kind = 'mine' then
    update public.mines
    set
      boost_multiplier = v_multiplier,
      updated_at = v_now
    where id = p_entity_id
      and player_id = p_player_id
      and is_active = true;

    if not found then
      raise exception 'Maden bulunamadi veya aktif degil.';
    end if;
  else
    raise exception 'Bu building_kind icin boost destegi henuz yok: %', p_building_kind;
  end if;

  update public.players
  set gold = gold - p_star_cost
  where id = p_player_id;

  v_finish_at := v_now + make_interval(hours => p_duration_hours);

  insert into public.building_boosts (
    player_id,
    building_kind,
    entity_id,
    duration_hours,
    star_cost,
    multiplier,
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
    p_duration_hours,
    p_star_cost,
    v_multiplier,
    jsonb_build_object(
      'duration_hours', p_duration_hours,
      'star_cost', p_star_cost,
      'multiplier', v_multiplier
    ),
    'in_progress',
    v_now,
    v_finish_at,
    v_now,
    v_now
  )
  returning id into v_boost_id;

  return jsonb_build_object(
    'success', true,
    'boost_id', v_boost_id,
    'building_kind', p_building_kind,
    'entity_id', p_entity_id,
    'duration_hours', p_duration_hours,
    'star_cost', p_star_cost,
    'multiplier', v_multiplier,
    'finish_at', v_finish_at
  );
end;
$function$;
