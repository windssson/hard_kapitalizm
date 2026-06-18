create or replace function public.get_route_transfer_vehicle_options(
  p_source_city_id uuid,
  p_target_city_id uuid,
  p_total_volume numeric
) returns table(
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
  fuel_cost numeric,
  total_price numeric,
  estimated_duration_seconds integer,
  can_select boolean,
  disabled_reason text
)
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_player_id uuid := auth.uid();
  v_default_vehicle_id uuid := '00000000-0000-0000-0000-000000000000'::uuid;
  v_distance_km numeric := 0;
  v_required_capacity integer;
begin
  if v_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  if p_source_city_id is null or p_target_city_id is null then
    raise exception 'Kaynak ve hedef sehir secilmelidir.';
  end if;

  if p_total_volume is null or p_total_volume <= 0 then
    raise exception 'Toplam hacim 0 dan buyuk olmalidir.';
  end if;

  v_required_capacity := ceil(p_total_volume);

  if p_source_city_id = p_target_city_id then
    return query
    select
      v_default_vehicle_id as vehicle_id,
      v_player_id as vehicle_owner_player_id,
      'Anlik Transfer'::text as vehicle_name,
      false as is_rental,
      greatest(v_required_capacity, 1) as capacity,
      999 as speed_kmh,
      999 as current_fuel,
      999 as fuel_capacity,
      0::numeric as fuel_rate,
      100 as condition,
      0::numeric as rental_price,
      0::numeric as distance_km,
      0::numeric as fuel_needed,
      0::numeric as condition_needed,
      0::numeric as rental_cost,
      0::numeric as fuel_cost,
      0::numeric as total_price,
      0 as estimated_duration_seconds,
      true as can_select,
      null::text as disabled_reason;
    return;
  end if;

  select round(
    sqrt(
      power(coalesce(sc.map_position_x, 0) - coalesce(tc.map_position_x, 0), 2) +
      power(coalesce(sc.map_position_y, 0) - coalesce(tc.map_position_y, 0), 2)
    ),
    2
  )
  into v_distance_km
  from public.cities sc
  join public.cities tc on tc.id = p_target_city_id
  where sc.id = p_source_city_id;

  return query
  with own_vehicles as (
    select
      lv.id as vehicle_id,
      lv.player_id as vehicle_owner_player_id,
      coalesce(lvt.name, 'Arac')::text as vehicle_name,
      false as is_rental,
      coalesce(lv.capacity, 0) as capacity,
      coalesce(lv.speed_kmh, 0) as speed_kmh,
      coalesce(lv.current_fuel, 0) as current_fuel,
      coalesce(lv.fuel_capacity, 0) as fuel_capacity,
      coalesce(lv.fuel_rate, 0) as fuel_rate,
      coalesce(lv.condition, 0) as condition,
      coalesce(lv.rental_price, 0) as rental_price,
      v_distance_km as distance_km,
      round(v_distance_km * coalesce(lv.fuel_rate, 0), 2) as fuel_needed,
      greatest(1, ceil(v_distance_km / 25.0))::numeric as condition_needed,
      0::numeric as rental_cost,
      round(v_distance_km * coalesce(lv.fuel_rate, 0) * coalesce(lv.fuel_cost, 0), 2) as fuel_cost,
      round(v_distance_km * coalesce(lv.fuel_rate, 0) * coalesce(lv.fuel_cost, 0), 2) as total_price,
      greatest(60, ceil((greatest(v_distance_km, 1) / greatest(coalesce(lv.speed_kmh, 0), 1)) * 3600))::integer as estimated_duration_seconds,
      (
        coalesce(lv.status, '') = 'idle'
        and coalesce(lv.capacity, 0) >= v_required_capacity
        and coalesce(lv.speed_kmh, 0) > 0
        and coalesce(lv.current_fuel, 0) >= ceil(v_distance_km * coalesce(lv.fuel_rate, 0))
        and coalesce(lv.condition, 0) > 0
      ) as can_select,
      case
        when coalesce(lv.status, '') <> 'idle' then 'Arac mesgul'
        when coalesce(lv.capacity, 0) < v_required_capacity then 'Kapasite yetersiz'
        when coalesce(lv.speed_kmh, 0) <= 0 then 'Arac hizi gecersiz'
        when coalesce(lv.current_fuel, 0) < ceil(v_distance_km * coalesce(lv.fuel_rate, 0)) then 'Yeterli yakit yok'
        when coalesce(lv.condition, 0) <= 0 then 'Bakim gerekli'
        else null
      end::text as disabled_reason
    from public.logistics_vehicles lv
    left join public.logistics_vehicle_types lvt on lvt.id = lv.logistics_vehicle_type_id
    where lv.player_id = v_player_id
  ),
  player_rental_vehicles as (
    select
      lv.id as vehicle_id,
      lv.player_id as vehicle_owner_player_id,
      coalesce(lvt.name, 'Kiralik Arac')::text as vehicle_name,
      true as is_rental,
      coalesce(lv.capacity, 0) as capacity,
      coalesce(lv.speed_kmh, 0) as speed_kmh,
      coalesce(lv.current_fuel, 0) as current_fuel,
      coalesce(lv.fuel_capacity, 0) as fuel_capacity,
      coalesce(lv.fuel_rate, 0) as fuel_rate,
      coalesce(lv.condition, 0) as condition,
      coalesce(lv.rental_price, 0) as rental_price,
      v_distance_km as distance_km,
      round(v_distance_km * coalesce(lv.fuel_rate, 0), 2) as fuel_needed,
      greatest(1, ceil(v_distance_km / 25.0))::numeric as condition_needed,
      round(v_distance_km * coalesce(lv.rental_price, 0), 2) as rental_cost,
      0::numeric as fuel_cost,
      round(v_distance_km * coalesce(lv.rental_price, 0), 2) as total_price,
      greatest(60, ceil((greatest(v_distance_km, 1) / greatest(coalesce(lv.speed_kmh, 0), 1)) * 3600))::integer as estimated_duration_seconds,
      (
        coalesce(lv.status, '') = 'idle'
        and coalesce(lv.is_available_for_rent, false) = true
        and coalesce(lv.capacity, 0) >= v_required_capacity
        and coalesce(lv.speed_kmh, 0) > 0
        and coalesce(lv.current_fuel, 0) >= ceil(v_distance_km * coalesce(lv.fuel_rate, 0))
        and coalesce(lv.condition, 0) > 0
        and public.logistics_vehicle_matches_route(
          lv.route_city_a_id,
          lv.route_city_b_id,
          p_source_city_id,
          p_target_city_id
        )
      ) as can_select,
      case
        when coalesce(lv.status, '') <> 'idle' then 'Arac mesgul'
        when coalesce(lv.is_available_for_rent, false) = false then 'Kiraya acik degil'
        when not public.logistics_vehicle_matches_route(
          lv.route_city_a_id,
          lv.route_city_b_id,
          p_source_city_id,
          p_target_city_id
        ) then 'Rota uyumsuz'
        when coalesce(lv.capacity, 0) < v_required_capacity then 'Kapasite yetersiz'
        when coalesce(lv.speed_kmh, 0) <= 0 then 'Arac hizi gecersiz'
        when coalesce(lv.current_fuel, 0) < ceil(v_distance_km * coalesce(lv.fuel_rate, 0)) then 'Yeterli yakit yok'
        when coalesce(lv.condition, 0) <= 0 then 'Bakim gerekli'
        else null
      end::text as disabled_reason
    from public.logistics_vehicles lv
    left join public.logistics_vehicle_types lvt on lvt.id = lv.logistics_vehicle_type_id
    where lv.player_id <> v_player_id
      and coalesce(lv.is_available_for_rent, false) = true
  ),
  npc_vehicle as (
    select
      n.vehicle_id,
      n.vehicle_owner_player_id,
      n.vehicle_name,
      n.is_rental,
      n.capacity,
      n.speed_kmh,
      n.current_fuel,
      n.fuel_capacity,
      n.fuel_rate,
      n.condition,
      n.rental_price,
      n.distance_km,
      n.fuel_needed,
      n.condition_needed,
      n.rental_cost,
      0::numeric as fuel_cost,
      coalesce(n.rental_cost, 0)::numeric as total_price,
      n.estimated_duration_seconds,
      (coalesce(n.capacity, 0) >= v_required_capacity) as can_select,
      case
        when coalesce(n.capacity, 0) < v_required_capacity then 'Kapasite yetersiz'
        else n.disabled_reason
      end::text as disabled_reason
    from public.get_npc_rental_vehicle_option(
      p_source_city_id,
      p_target_city_id,
      v_distance_km
    ) n
  )
  select * from own_vehicles
  union all
  select * from player_rental_vehicles
  union all
  select * from npc_vehicle;
end;
$function$;

grant execute on function public.get_route_transfer_vehicle_options(uuid, uuid, numeric) to anon, authenticated, service_role;
