-- 1. Redefine complete_building_upgrade to include 'changed' block with player profile.
CREATE OR REPLACE FUNCTION public.complete_building_upgrade(p_player_id uuid, p_upgrade_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = 'public'
AS $$
declare
  v_now timestamptz := timezone('utc', now());
  v_upgrade public.building_upgrades%rowtype;
  v_slot_capacity_increase integer := 0;
  v_max_slot_increase integer := 0;
  v_input_capacity_increase integer := 0;
  v_output_capacity_increase integer := 0;
  v_capacity_increase numeric := 0;
  v_exp_result jsonb;
begin
  select * into v_upgrade from public.building_upgrades
  where id = p_upgrade_id and player_id = p_player_id for update;
  if not found then raise exception 'Yukseltme bulunamadi.'; end if;
  if v_upgrade.status <> 'in_progress' then raise exception 'Bu yukseltme tamamlanabilir durumda degil.'; end if;
  if v_upgrade.finish_at > v_now then raise exception 'Yukseltme henuz bitmedi.'; end if;

  if v_upgrade.building_kind = 'store' then
    v_slot_capacity_increase := coalesce((v_upgrade.params->>'slot_capacity_increase')::integer, 0);
    v_max_slot_increase := coalesce((v_upgrade.params->>'max_slot_increase')::integer, 0);
    update public.stores set level=v_upgrade.target_level,
      slot_capacity=slot_capacity+v_slot_capacity_increase,
      max_slot_count=max_slot_count+v_max_slot_increase, updated_at=v_now
    where id=v_upgrade.entity_id and player_id=p_player_id;
    update public.store_slots set capacity=capacity+v_slot_capacity_increase, updated_at=v_now
    where store_id=v_upgrade.entity_id;
  elsif v_upgrade.building_kind = 'warehouse' then
    v_capacity_increase := coalesce((v_upgrade.params->>'capacity_increase')::numeric, 0);
    update public.warehouses set level=v_upgrade.target_level,
      capacity=capacity+v_capacity_increase, updated_at=v_now
    where id=v_upgrade.entity_id and player_id=p_player_id;
  elsif v_upgrade.building_kind = 'field' then
    v_input_capacity_increase := coalesce((v_upgrade.params->>'input_capacity_increase')::integer, 0);
    v_output_capacity_increase := coalesce((v_upgrade.params->>'output_capacity_increase')::integer, 0);
    update public.fields set level=v_upgrade.target_level,
      input_capacity=input_capacity+v_input_capacity_increase,
      output_capacity=output_capacity+v_output_capacity_increase, updated_at=v_now
    where id=v_upgrade.entity_id and player_id=p_player_id;
  elsif v_upgrade.building_kind = 'farm' then
    v_input_capacity_increase := coalesce((v_upgrade.params->>'input_capacity_increase')::integer, 0);
    v_output_capacity_increase := coalesce((v_upgrade.params->>'output_capacity_increase')::integer, 0);
    update public.farms set level=v_upgrade.target_level,
      input_capacity=input_capacity+v_input_capacity_increase,
      output_capacity=output_capacity+v_output_capacity_increase, updated_at=v_now
    where id=v_upgrade.entity_id and player_id=p_player_id;
  elsif v_upgrade.building_kind = 'factory' then
    v_input_capacity_increase := coalesce((v_upgrade.params->>'input_capacity_increase')::integer, 0);
    v_output_capacity_increase := coalesce((v_upgrade.params->>'output_capacity_increase')::integer, 0);
    update public.factories set level=v_upgrade.target_level,
      input_capacity=input_capacity+v_input_capacity_increase,
      output_capacity=output_capacity+v_output_capacity_increase, updated_at=v_now
    where id=v_upgrade.entity_id and player_id=p_player_id;
  elsif v_upgrade.building_kind = 'mine' then
    v_output_capacity_increase := coalesce((v_upgrade.params->>'output_capacity_increase')::integer, 0);
    update public.mines set level=v_upgrade.target_level,
      output_capacity=output_capacity+v_output_capacity_increase, updated_at=v_now
    where id=v_upgrade.entity_id and player_id=p_player_id;
  elsif v_upgrade.building_kind = 'arge_center' then
    update public.arge_centers set level=v_upgrade.target_level,
      max_concurrent_researches=coalesce((v_upgrade.params->>'next_concurrent_researches')::integer,max_concurrent_researches),
      duration_reduction_pct=coalesce((v_upgrade.params->>'next_duration_reduction_pct')::numeric,duration_reduction_pct), updated_at=v_now
    where id=v_upgrade.entity_id and player_id=p_player_id;
  else raise exception 'Desteklenmeyen yukseltme turu: %', v_upgrade.building_kind;
  end if;

  if not found then raise exception 'Yukseltilecek isletme bulunamadi.'; end if;
  update public.building_upgrades set status='completed', completed_at=v_now, updated_at=v_now where id=p_upgrade_id;

  v_exp_result := public.grant_player_experience(
    p_player_id,
    public.calculate_experience_reward('building_upgrade_completed', jsonb_build_object('building_kind',v_upgrade.building_kind,'target_level',v_upgrade.target_level)),
    'building_upgrade_completed',
    jsonb_build_object('upgrade_id',p_upgrade_id,'building_kind',v_upgrade.building_kind,'entity_id',v_upgrade.entity_id,'target_level',v_upgrade.target_level)
  );
  return jsonb_build_object('success',true,'upgrade_id',p_upgrade_id,'building_kind',v_upgrade.building_kind,
    'entity_id',v_upgrade.entity_id,'target_level',v_upgrade.target_level,
    'slot_capacity_increase',v_slot_capacity_increase,'max_slot_increase',v_max_slot_increase,
    'input_capacity_increase',v_input_capacity_increase,'output_capacity_increase',v_output_capacity_increase,
    'capacity_increase',v_capacity_increase,'completed_at',v_now,'experience',v_exp_result,
    'changed', jsonb_build_object(
      'player', public.get_player_profile(p_player_id)
    )
  );
end;
$$;


-- 2. Redefine complete_building_construction to include 'changed' block with player profile.
CREATE OR REPLACE FUNCTION public.complete_building_construction(p_player_id uuid, p_construction_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = 'public'
AS $$
declare
  v_construction record;
  v_now timestamptz := timezone('utc'::text, now());
  v_created_id uuid;
  v_store record;
  v_store_warehouse_type record;
  v_exp_result jsonb;
begin
  select *
  into v_construction
  from public.building_constructions
  where id = p_construction_id
    and player_id = p_player_id
  for update;

  if not found then
    raise exception 'Insaat kaydi bulunamadi.';
  end if;

  if v_construction.status <> 'in_progress' then
    raise exception 'Bu insaat tamamlanabilir durumda degil. Mevcut durum: %', v_construction.status;
  end if;

  if v_construction.finish_at > v_now then
    raise exception 'Insaat henuz bitmedi. Bitis zamani: %', v_construction.finish_at;
  end if;

  if v_construction.building_kind = 'store' then
    insert into public.stores (
      player_id,
      store_type_id,
      city_id,
      name,
      level,
      current_slot_count,
      max_slot_count,
      slot_capacity,
      is_active
    )
    values (
      p_player_id,
      (v_construction.params->>'store_type_id')::uuid,
      (v_construction.params->>'city_id')::uuid,
      v_construction.params->>'name',
      coalesce((v_construction.params->>'level')::integer, 1),
      coalesce((v_construction.params->>'current_slot_count')::integer, 0),
      coalesce((v_construction.params->>'max_slot_count')::integer, 0),
      coalesce((v_construction.params->>'slot_capacity')::integer, 0),
      true
    )
    returning id into v_created_id;

    select *
    into v_store
    from public.stores
    where id = v_created_id;

    select wt.*
    into v_store_warehouse_type
    from public.warehouse_types wt
    join public.store_types st on st.id = v_store.store_type_id
    where coalesce(wt.accepted_production_units, '') = 'MAGAZA'
      and lower(trim(coalesce(wt.name, ''))) = lower(trim(
        case st.name
          when 'Büfe' then 'Büfe Deposu'
          when 'Manav' then 'Manav Soğuk Deposu'
          when 'Market' then 'Market Ana Deposu'
          when 'Fırın' then 'Fırın Ürün Deposu'
          when 'Kasap' then 'Kasap Soğuk Et Deposu'
          when 'Süpermarket' then 'Süpermarket Lojistik Deposu'
          when 'Kuruyemişçi' then 'Kuruyemiş Deposu'
          when 'Tekstil Mağazası' then 'Tekstil Deposu'
          when 'Mobilya Mağazası' then 'Mobilya Deposu'
          when 'Kozmetik Mağazası' then 'Kozmetik Deposu'
          when 'Beyaz Eşya' then 'Beyaz Eşya Deposu'
          when 'Teknoloji ve Elektronik' then 'Teknoloji ve Elektronik Deposu'
          when 'İnşaat Malzemeleri' then 'İnşaat Malzemesi Sahası'
          when 'Kuyumcu' then 'Kuyumcu Güvenli Kasa Deposu'
          when 'Oto Galeri' then 'Araç Stok Alanı'
          else st.name || ' Deposu'
        end
      ))
    limit 1;

    if not found then
      raise exception 'Magaza deposu tipi bulunamadi. Store type id: %, store id: %', v_store.store_type_id, v_store.id;
    end if;

    insert into public.warehouses (
      player_id,
      warehouse_type_id,
      city_id,
      store_id,
      warehouse_kind,
      name,
      level,
      capacity,
      is_active
    )
    values (
      v_store.player_id,
      v_store_warehouse_type.id,
      v_store.city_id,
      v_store.id,
      'store',
      v_store.name || ' Deposu',
      1,
      greatest(coalesce(v_store.slot_capacity, 0), 0) * 10,
      true
    );
  elsif v_construction.building_kind = 'warehouse' then
    insert into public.warehouses (
      player_id,
      warehouse_type_id,
      city_id,
      name,
      level,
      capacity,
      is_active
    )
    values (
      p_player_id,
      (v_construction.params->>'warehouse_type_id')::uuid,
      (v_construction.params->>'city_id')::uuid,
      v_construction.params->>'name',
      coalesce((v_construction.params->>'level')::integer, 1),
      coalesce((v_construction.params->>'capacity')::numeric, 0),
      true
    )
    returning id into v_created_id;
  elsif v_construction.building_kind = 'factory' then
    insert into public.factories (
      player_id,
      factory_type_id,
      city_id,
      name,
      level,
      product_id,
      quality_level,
      input_capacity,
      output_capacity,
      boost_multiplier,
      is_active
    )
    values (
      p_player_id,
      (v_construction.params->>'factory_type_id')::uuid,
      (v_construction.params->>'city_id')::uuid,
      v_construction.params->>'name',
      coalesce((v_construction.params->>'level')::integer, 1),
      null,
      coalesce((v_construction.params->>'quality_level')::integer, 0),
      coalesce((v_construction.params->>'input_capacity')::integer, 0),
      coalesce((v_construction.params->>'output_capacity')::integer, 0),
      coalesce((v_construction.params->>'boost_multiplier')::numeric, 1.00),
      true
    )
    returning id into v_created_id;
  elsif v_construction.building_kind = 'field' then
    insert into public.fields (
      player_id,
      field_type_id,
      city_id,
      name,
      level,
      current_slot_count,
      max_slot_count,
      input_capacity,
      output_capacity,
      is_active
    )
    values (
      p_player_id,
      (v_construction.params->>'field_type_id')::uuid,
      (v_construction.params->>'city_id')::uuid,
      v_construction.params->>'name',
      coalesce((v_construction.params->>'level')::integer, 1),
      coalesce((v_construction.params->>'current_slot_count')::integer, 0),
      coalesce((v_construction.params->>'max_slot_count')::integer, 0),
      coalesce((v_construction.params->>'input_capacity')::integer, 0),
      coalesce((v_construction.params->>'output_capacity')::integer, 0),
      true
    )
    returning id into v_created_id;
  elsif v_construction.building_kind = 'farm' then
    insert into public.farms (
      player_id,
      farm_type_id,
      city_id,
      name,
      level,
      current_slot_count,
      max_slot_count,
      input_capacity,
      output_capacity,
      is_active
    )
    values (
      p_player_id,
      (v_construction.params->>'farm_type_id')::uuid,
      (v_construction.params->>'city_id')::uuid,
      v_construction.params->>'name',
      coalesce((v_construction.params->>'level')::integer, 1),
      coalesce((v_construction.params->>'current_slot_count')::integer, 0),
      coalesce((v_construction.params->>'max_slot_count')::integer, 0),
      coalesce((v_construction.params->>'input_capacity')::integer, 0),
      coalesce((v_construction.params->>'output_capacity')::integer, 0),
      true
    )
    returning id into v_created_id;
  elsif v_construction.building_kind = 'mine' then
    insert into public.mines (
      player_id,
      mine_type_id,
      city_id,
      name,
      level,
      product_id,
      quality_level,
      output_capacity,
      boost_multiplier,
      is_active
    )
    values (
      p_player_id,
      (v_construction.params->>'mine_type_id')::uuid,
      (v_construction.params->>'city_id')::uuid,
      v_construction.params->>'name',
      coalesce((v_construction.params->>'level')::integer, 1),
      null,
      coalesce((v_construction.params->>'quality_level')::integer, 0),
      coalesce((v_construction.params->>'output_capacity')::integer, 0),
      coalesce((v_construction.params->>'boost_multiplier')::numeric, 1.00),
      true
    )
    returning id into v_created_id;
  elsif v_construction.building_kind = 'logistics_company' then
    insert into public.logistics_companies (
      player_id,
      city_id,
      name,
      level,
      current_vehicle_count,
      max_vehicle_count,
      fuel_capacity,
      current_fuel,
      fuel_cost,
      is_active
    )
    values (
      p_player_id,
      (v_construction.params->>'city_id')::uuid,
      v_construction.params->>'name',
      coalesce((v_construction.params->>'level')::integer, 1),
      coalesce((v_construction.params->>'current_vehicle_count')::integer, 0),
      coalesce((v_construction.params->>'max_vehicle_count')::integer, 0),
      coalesce((v_construction.params->>'fuel_capacity')::integer, 0),
      coalesce((v_construction.params->>'current_fuel')::integer, 0),
      coalesce((v_construction.params->>'fuel_cost')::numeric, 0),
      true
    )
    returning id into v_created_id;
  elsif v_construction.building_kind = 'arge_center' then
    insert into public.arge_centers (
      player_id,
      name,
      level,
      max_concurrent_researches,
      duration_reduction_pct,
      is_active
    )
    values (
      p_player_id,
      coalesce(v_construction.params->>'name', 'AR-GE Merkezi'),
      coalesce((v_construction.params->>'level')::integer, 1),
      coalesce((v_construction.params->>'max_concurrent_researches')::integer, 1),
      coalesce((v_construction.params->>'duration_reduction_pct')::numeric, 0),
      true
    )
    returning id into v_created_id;
  else
    raise exception 'Gecersiz building_kind: %', v_construction.building_kind;
  end if;

  update public.building_constructions
  set
    status = 'complete',
    completed_at = v_now
  where id = p_construction_id;

  v_exp_result := public.grant_player_experience(
    p_player_id,
    public.calculate_experience_reward(
      'building_construction_completed',
      jsonb_build_object('building_kind', v_construction.building_kind)
    ),
    'building_construction_completed',
    jsonb_build_object(
      'construction_id', p_construction_id,
      'building_kind', v_construction.building_kind,
      'created_id', v_created_id
    )
  );

  return jsonb_build_object(
    'success', true,
    'construction_id', p_construction_id,
    'building_kind', v_construction.building_kind,
    'created_id', v_created_id,
    'status', 'complete',
    'completed_at', v_now,
    'experience', v_exp_result,
    'changed', jsonb_build_object(
      'player', public.get_player_profile(p_player_id)
    )
  );
end;
$$;


-- 3. Redefine start_building_construction to return 'changed' block.
CREATE OR REPLACE FUNCTION public.start_building_construction(p_player_id uuid, p_city_id uuid, p_building_kind text, p_type_id uuid, p_name text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = 'public'
AS $$
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
    'cost', v_cost, 'remaining_cash', coalesce(v_player.cash, 0) - v_cost, 'params', v_params,
    'changed', jsonb_build_object(
      'player', public.get_player_profile(p_player_id)
    )
  );
end;
$$;


-- 4. Redefine start_building_upgrade to return 'changed' block.
CREATE OR REPLACE FUNCTION public.start_building_upgrade(p_player_id uuid, p_building_kind text, p_entity_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = 'public'
AS $$
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
      'slot_capacity_increase', v_slot_capacity_increase, 'max_slot_increase', v_max_slot_increase, 'finish_at', v_finish_at,
      'changed', jsonb_build_object(
        'player', public.get_player_profile(p_player_id)
      ));

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
      'input_capacity_increase', v_input_capacity_increase, 'output_capacity_increase', v_output_capacity_increase, 'finish_at', v_finish_at,
      'changed', jsonb_build_object(
        'player', public.get_player_profile(p_player_id)
      ));

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
      'input_capacity_increase', v_input_capacity_increase, 'output_capacity_increase', v_output_capacity_increase, 'finish_at', v_finish_at,
      'changed', jsonb_build_object(
        'player', public.get_player_profile(p_player_id)
      ));

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
      'input_capacity_increase', v_input_capacity_increase, 'output_capacity_increase', v_output_capacity_increase, 'finish_at', v_finish_at,
      'changed', jsonb_build_object(
        'player', public.get_player_profile(p_player_id)
      ));

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
      'output_capacity_increase', v_output_capacity_increase, 'finish_at', v_finish_at,
      'changed', jsonb_build_object(
        'player', public.get_player_profile(p_player_id)
      ));

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
      'current_level', v_current_level, 'target_level', v_target_level, 'duration_minutes', v_duration_minutes, 'upgrade_cost', v_upgrade_cost, 'finish_at', v_finish_at,
      'changed', jsonb_build_object(
        'player', public.get_player_profile(p_player_id)
      ));
  end if;

  raise exception 'Bu building_kind icin yukseltme destegi henuz yok: %', p_building_kind;
end;
$$;


-- 5. Redefine start_building_boost to return 'changed' block.
CREATE OR REPLACE FUNCTION public.start_building_boost(p_player_id uuid, p_building_kind text, p_entity_id uuid, p_duration_hours integer, p_star_cost integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = 'public'
AS $$
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
    'finish_at', v_finish_at,
    'changed', jsonb_build_object(
      'player', public.get_player_profile(p_player_id)
    )
  );
end;
$$;


-- 6. Redefine pay_tax_debt to include 'changed' block with player profile and tax_dirty.
CREATE OR REPLACE FUNCTION public.pay_tax_debt(p_amount numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = 'public'
AS $$
DECLARE
  v_player_id uuid := auth.uid();
  v_current_cash numeric;
  v_current_tax numeric;
  v_paid_amount numeric;
BEGIN
  if v_player_id is null then
    return jsonb_build_object('success', false, 'message', 'Oturum acilmamis.');
  end if;

  if p_amount <= 0 and p_amount != -1 then
    return jsonb_build_object('success', false, 'message', 'Gecersiz odeme tutari.');
  end if;

  -- Lock player and tax records
  select cash into v_current_cash from public.players where id = v_player_id for update;
  if v_current_cash is null then
    return jsonb_build_object('success', false, 'message', 'Oyuncu bulunamadi.');
  end if;

  select tax_debt into v_current_tax from public.player_taxes where player_id = v_player_id for update;
  if v_current_tax is null or v_current_tax <= 0 then
    return jsonb_build_object('success', false, 'message', 'Vergi borcunuz bulunmamaktadir.');
  end if;

  if p_amount = -1 then
    v_paid_amount := v_current_tax;
  else
    v_paid_amount := p_amount;
    if v_paid_amount > v_current_tax then
      v_paid_amount := v_current_tax;
    end if;
  end if;

  if v_current_cash < v_paid_amount then
    return jsonb_build_object('success', false, 'message', 'Yetersiz nakit bakiye.');
  end if;

  update public.players
  set cash = cash - v_paid_amount
  where id = v_player_id;

  update public.player_taxes
  set tax_debt = tax_debt - v_paid_amount,
      updated_at = now()
  where player_id = v_player_id;

  perform public.log_player_cash_change(
    v_player_id,
    -v_paid_amount,
    v_current_cash,
    'tax_payment',
    format('Vergi odemesi: %s TL', round(v_paid_amount, 2)),
    null,
    'tax'
  );

  return jsonb_build_object(
    'success', true,
    'message', format('%s TL vergi borcu odendi.', round(v_paid_amount, 2)),
    'paid_amount', v_paid_amount,
    'remaining_tax_debt', v_current_tax - v_paid_amount,
    'remaining_cash', v_current_cash - v_paid_amount,
    'changed', jsonb_build_object(
      'player', public.get_player_profile(v_player_id),
      'tax_dirty', true
    )
  );
END;
$$;
