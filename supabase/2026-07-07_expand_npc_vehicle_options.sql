-- 1. Insert dynamic pricing configurations into game_settings
INSERT INTO public.game_settings (key, value_text, description)
VALUES
  ('npc_rental_price_Hızlı Kurye 250', '1.0', 'Hızlı Kurye 250 aracı için km başına kiralama ücreti'),
  ('npc_rental_price_VoltExpress E-Truck', '1.6', 'VoltExpress E-Truck aracı için km başına kiralama ücreti'),
  ('npc_rental_price_Anadolu Aslanı', '2.0', 'Anadolu Aslanı aracı için km başına kiralama ücreti'),
  ('npc_rental_price_Kıtalararası Trans', '3.0', 'Kıtalararası Trans aracı için km başına kiralama ücreti')
ON CONFLICT (key) DO UPDATE
SET value_text = EXCLUDED.value_text, description = EXCLUDED.description;

-- 2. Redefine ensure_npc_rental_vehicle to support vehicle types and game_settings pricing
CREATE OR REPLACE FUNCTION public.ensure_npc_rental_vehicle(
    p_from_city_id uuid,
    p_to_city_id uuid,
    p_vehicle_type_id uuid
)
RETURNS public.logistics_vehicles
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
declare
  v_npc_player_id uuid;
  v_company_id uuid;
  v_vehicle_type record;
  v_vehicle public.logistics_vehicles%rowtype;
  v_city_a uuid;
  v_city_b uuid;
  v_now timestamptz := timezone('utc'::text, now());
  v_rental_price numeric := 2.0;
begin
  if p_from_city_id is null or p_to_city_id is null or p_from_city_id = p_to_city_id then
    raise exception 'NPC fallback araci icin gecersiz rota sehirleri.';
  end if;

  if p_from_city_id::text <= p_to_city_id::text then
    v_city_a := p_from_city_id;
    v_city_b := p_to_city_id;
  else
    v_city_a := p_to_city_id;
    v_city_b := p_from_city_id;
  end if;

  v_npc_player_id := public.get_npc_logistics_player_id();

  select lc.id
  into v_company_id
  from public.logistics_companies lc
  where lc.player_id = v_npc_player_id
  order by lc.created_at asc
  limit 1;

  if v_company_id is null then
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
      is_active,
      created_at,
      updated_at
    )
    values (
      v_npc_player_id,
      v_city_a,
      'Atlas Lojistik',
      99,
      0,
      9999,
      999999,
      999999,
      0,
      true,
      v_now,
      v_now
    )
    returning id into v_company_id;
  else
    update public.logistics_companies
    set
      city_id = coalesce(city_id, v_city_a),
      level = greatest(coalesce(level, 1), 99),
      max_vehicle_count = greatest(coalesce(max_vehicle_count, 0), 9999),
      fuel_capacity = greatest(coalesce(fuel_capacity, 0), 999999),
      current_fuel = greatest(coalesce(current_fuel, 0), 999999),
      fuel_cost = 0,
      is_active = true,
      updated_at = v_now
    where id = v_company_id;
  end if;

  select
    lvt.id,
    coalesce(lvt.capacity, 250) as capacity,
    coalesce(lvt.speed_kmh, 60) as speed_kmh,
    coalesce(lvt.fuel_capacity, 60) as fuel_capacity,
    coalesce(lvt.fuel_rate, 0.02) as fuel_rate,
    coalesce(lvt.name, 'Kiralik Arac') as name
  into v_vehicle_type
  from public.logistics_vehicle_types lvt
  where lvt.id = p_vehicle_type_id;

  if v_vehicle_type.id is null then
    raise exception 'NPC fallback araci icin vehicle type bulunamadi.';
  end if;

  -- Load rental price dynamically from game_settings
  select coalesce(value_text::numeric, 2.0)
  into v_rental_price
  from public.game_settings
  where key = 'npc_rental_price_' || v_vehicle_type.name;

  v_rental_price := coalesce(v_rental_price, 2.0);

  select lv.*
  into v_vehicle
  from public.logistics_vehicles lv
  where lv.player_id = v_npc_player_id
    and lv.logistics_company_id = v_company_id
    and lv.logistics_vehicle_type_id = p_vehicle_type_id
    and lv.is_available_for_rent = true
    and lv.status = 'idle'
    and (
      (lv.route_city_a_id = v_city_a and lv.route_city_b_id = v_city_b)
      or (lv.route_city_a_id = v_city_b and lv.route_city_b_id = v_city_a)
    )
  order by lv.created_at asc
  limit 1
  for update;

  if found then
    update public.logistics_vehicles
    set
      capacity = v_vehicle_type.capacity,
      speed_kmh = v_vehicle_type.speed_kmh,
      fuel_capacity = v_vehicle_type.fuel_capacity,
      current_fuel = v_vehicle_type.fuel_capacity,
      fuel_rate = v_vehicle_type.fuel_rate,
      condition = 100,
      status = 'idle',
      is_available_for_rent = true,
      rental_price = v_rental_price,
      route_city_a_id = v_city_a,
      route_city_b_id = v_city_b,
      updated_at = v_now
    where id = v_vehicle.id
    returning * into v_vehicle;

    return v_vehicle;
  end if;

  insert into public.logistics_vehicles (
    player_id,
    logistics_company_id,
    logistics_vehicle_type_id,
    capacity,
    speed_kmh,
    fuel_capacity,
    current_fuel,
    fuel_rate,
    condition,
    status,
    is_available_for_rent,
    rental_price,
    route_city_a_id,
    route_city_b_id,
    created_at,
    updated_at
  )
  values (
    v_npc_player_id,
    v_company_id,
    v_vehicle_type.id,
    v_vehicle_type.capacity,
    v_vehicle_type.speed_kmh,
    v_vehicle_type.fuel_capacity,
    v_vehicle_type.fuel_capacity,
    v_vehicle_type.fuel_rate,
    100,
    'idle',
    true,
    v_rental_price,
    v_city_a,
    v_city_b,
    v_now,
    v_now
  )
  returning * into v_vehicle;

  update public.logistics_companies
  set
    current_vehicle_count = coalesce(current_vehicle_count, 0) + 1,
    updated_at = v_now
  where id = v_company_id;

  return v_vehicle;
end;
$function$;

-- 3. Redefine get_npc_rental_vehicle_option to loop and return all 4 vehicle options
CREATE OR REPLACE FUNCTION public.get_npc_rental_vehicle_option(
    p_from_city_id uuid,
    p_to_city_id uuid,
    p_distance_km numeric
)
RETURNS TABLE(
    vehicle_id uuid,
    vehicle_owner_player_id uuid,
    vehicle_name text,
    is_rental boolean,
    capacity integer,
    speed_kmh integer,
    current_fuel integer,
    fuel_capacity integer,
    fuel_rate numeric,
    condition integer,
    rental_price numeric,
    distance_km numeric,
    fuel_needed numeric,
    condition_needed numeric,
    rental_cost numeric,
    estimated_duration_seconds integer,
    can_select boolean,
    disabled_reason text
)
LANGUAGE plpgsql
AS $$
declare
  v_distance numeric := coalesce(p_distance_km, 0);
  v_type record;
  v_vehicle public.logistics_vehicles%rowtype;
begin
  if p_from_city_id is null or p_to_city_id is null or p_from_city_id = p_to_city_id then
    return;
  end if;

  for v_type in 
    select * 
    from public.logistics_vehicle_types 
    order by capacity asc, purchase_price asc
  loop
    v_vehicle := public.ensure_npc_rental_vehicle(p_from_city_id, p_to_city_id, v_type.id);

    vehicle_id := v_vehicle.id;
    vehicle_owner_player_id := v_vehicle.player_id;
    vehicle_name := v_type.name;
    is_rental := true;
    capacity := v_vehicle.capacity;
    speed_kmh := v_vehicle.speed_kmh;
    current_fuel := v_vehicle.current_fuel;
    fuel_capacity := v_vehicle.fuel_capacity;
    fuel_rate := v_vehicle.fuel_rate;
    condition := v_vehicle.condition;
    rental_price := v_vehicle.rental_price;
    distance_km := v_distance;
    fuel_needed := ceil(v_distance * coalesce(v_vehicle.fuel_rate, 0))::numeric;
    condition_needed := greatest(1, ceil(v_distance / 25.0))::numeric;
    rental_cost := ceil(v_distance * coalesce(v_vehicle.rental_price, 0))::numeric;
    estimated_duration_seconds := greatest(60, ceil((greatest(v_distance, 1) / greatest(v_vehicle.speed_kmh, 1)) * 120))::integer;
    can_select := true;
    disabled_reason := null::text;

    return next;
  end loop;
end;
$$;
