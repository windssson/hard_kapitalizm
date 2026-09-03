-- Migration: Link Store Types to Warehouse Types & Auto-create Store Warehouse on Store Construction
-- Date: 2026-09-03

-- 1. Add warehouse_type_id to store_types
ALTER TABLE public.store_types 
ADD COLUMN IF NOT EXISTS warehouse_type_id uuid REFERENCES public.warehouse_types(id);

-- 2. Populate warehouse_type_id for all store types
UPDATE public.store_types st
SET warehouse_type_id = wt.id
FROM public.warehouse_types wt
WHERE (
  (st.name = 'Beyaz Eşya' AND wt.name = 'Beyaz Eşya Deposu') OR
  (st.name = 'Büfe' AND wt.name = 'Büfe Deposu') OR
  (st.name = 'Fırın' AND wt.name = 'Fırın Ürün Deposu') OR
  (st.name = 'İnşaat Malzemeleri' AND wt.name = 'İnşaat Malzemesi Sahası') OR
  (st.name = 'Kasap' AND wt.name = 'Kasap Soğuk Et Deposu') OR
  (st.name = 'Kozmetik Mağazası' AND wt.name = 'Kozmetik Deposu') OR
  (st.name = 'Kuruyemişçi' AND wt.name = 'Kuruyemiş Deposu') OR
  (st.name = 'Kuyumcu' AND wt.name = 'Kuyumcu Deposu') OR
  (st.name = 'Manav' AND wt.name = 'Manav Soğuk Deposu') OR
  (st.name = 'Market' AND wt.name = 'Market Ana Deposu') OR
  (st.name = 'Mobilya Mağazası' AND wt.name = 'Mobilya Deposu') OR
  (st.name = 'Oto Galeri' AND wt.name = 'Araç Stok Alanı') OR
  (st.name = 'Süpermarket' AND wt.name = 'Süpermarket Lojistik Deposu') OR
  (st.name = 'Teknoloji ve Elektronik' AND wt.name = 'Teknoloji ve Elektronik Deposu') OR
  (st.name = 'Tekstil Mağazası' AND wt.name = 'Tekstil Deposu')
);

-- 3. Update start_building_construction
CREATE OR REPLACE FUNCTION public.start_building_construction(p_player_id uuid, p_city_id uuid, p_building_kind text, p_type_id uuid, p_name text)
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
      jsonb_build_object(
        'store_type_id', id,
        'warehouse_type_id', warehouse_type_id,
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
$function$;

-- 4. Update complete_building_construction to auto-create store warehouse
CREATE OR REPLACE FUNCTION public.complete_building_construction(p_player_id uuid, p_construction_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_now timestamptz := timezone('utc'::text, now());
  v_construction public.building_constructions%rowtype;
  v_created_id uuid;
  v_building_display_name text;
  v_exp_result jsonb;
  v_store_warehouse_type_id uuid;
  v_store_warehouse_capacity numeric;
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
    raise exception 'Bu insaat tamamlanabilir durumda degil.';
  end if;

  if v_construction.finish_at > v_now then
    raise exception 'Insaat henuz bitmedi.';
  end if;

  v_building_display_name := coalesce(v_construction.params->>'name', 'Yeni Tesis');

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

    -- Magazaya bagli ayni sehirde ozel magaza deposu olustur
    select 
      coalesce(st.warehouse_type_id, wt.id),
      coalesce(wt.base_capacity, 100)
    into v_store_warehouse_type_id, v_store_warehouse_capacity
    from public.store_types st
    left join public.warehouse_types wt on wt.id = st.warehouse_type_id
      or wt.accepted_product_ids = st.accepted_product_ids
      or wt.name ilike '%' || st.name || '%'
    where st.id = (v_construction.params->>'store_type_id')::uuid
    limit 1;

    if v_store_warehouse_type_id is not null then
      insert into public.warehouses (
        player_id,
        warehouse_type_id,
        city_id,
        name,
        level,
        capacity,
        reserved_capacity,
        warehouse_kind,
        store_id,
        is_active
      )
      values (
        p_player_id,
        v_store_warehouse_type_id,
        (v_construction.params->>'city_id')::uuid,
        coalesce(v_construction.params->>'name', 'Mağaza') || ' Deposu',
        1,
        coalesce(v_store_warehouse_capacity, 100),
        0,
        'store',
        v_created_id,
        true
      );
    end if;

  elsif v_construction.building_kind = 'warehouse' then
    insert into public.warehouses (
      player_id,
      warehouse_type_id,
      city_id,
      name,
      level,
      capacity,
      reserved_capacity,
      warehouse_kind,
      store_id,
      is_active
    )
    values (
      p_player_id,
      nullif(v_construction.params->>'warehouse_type_id', '')::uuid,
      (v_construction.params->>'city_id')::uuid,
      v_construction.params->>'name',
      coalesce((v_construction.params->>'level')::integer, 1),
      coalesce((v_construction.params->>'capacity')::numeric, 0),
      0,
      coalesce(v_construction.params->>'warehouse_kind', 'general'),
      nullif(v_construction.params->>'store_id', '')::uuid,
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

  -- Insaat Tamamlanma Bildirimi (Oyun Ici + Push)
  PERFORM public.send_game_notification(
    p_player_id,
    'İnşaat Tamamlandı!',
    v_building_display_name || ' inşaatı tamamlandı ve hizmete açıldı.',
    'building',
    'construction',
    v_created_id,
    true
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
$function$;

-- 5. Backfill any existing stores missing their store warehouse
INSERT INTO public.warehouses (
  player_id,
  warehouse_type_id,
  city_id,
  name,
  level,
  capacity,
  reserved_capacity,
  warehouse_kind,
  store_id,
  is_active
)
SELECT 
  s.player_id,
  st.warehouse_type_id,
  s.city_id,
  s.name || ' Deposu',
  1,
  coalesce(wt.base_capacity, 100),
  0,
  'store',
  s.id,
  true
FROM public.stores s
JOIN public.store_types st ON st.id = s.store_type_id
JOIN public.warehouse_types wt ON wt.id = st.warehouse_type_id
WHERE NOT EXISTS (
  SELECT 1 FROM public.warehouses w 
  WHERE w.store_id = s.id AND w.warehouse_kind = 'store'
);
