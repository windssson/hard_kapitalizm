alter table public.logistics_transfers
  add column if not exists seller_entity_kind text,
  add column if not exists buyer_entity_kind text,
  add column if not exists seller_production_inventory_id uuid,
  add column if not exists buyer_production_inventory_id uuid;

create index if not exists logistics_transfers_seller_production_inventory_idx
  on public.logistics_transfers (seller_production_inventory_id);

create index if not exists logistics_transfers_buyer_production_inventory_idx
  on public.logistics_transfers (buyer_production_inventory_id);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'logistics_transfers_seller_production_inventory_fk'
  ) then
    alter table public.logistics_transfers
      add constraint logistics_transfers_seller_production_inventory_fk
      foreign key (seller_production_inventory_id)
      references public.production_inventory(id)
      on delete set null;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'logistics_transfers_buyer_production_inventory_fk'
  ) then
    alter table public.logistics_transfers
      add constraint logistics_transfers_buyer_production_inventory_fk
      foreign key (buyer_production_inventory_id)
      references public.production_inventory(id)
      on delete set null;
  end if;
end
$$;

update public.logistics_transfers
set seller_entity_kind = case
  when seller_production_inventory_id is not null then 'production_inventory'
  when seller_store_slot_id is not null or seller_store_id is not null then 'store_slot'
  when seller_warehouse_slot_id is not null or seller_warehouse_id is not null then 'warehouse'
  else seller_entity_kind
end
where seller_entity_kind is null;

update public.logistics_transfers
set buyer_entity_kind = case
  when buyer_production_inventory_id is not null then 'production_inventory'
  when buyer_store_slot_id is not null or buyer_store_id is not null then 'store_slot'
  when buyer_warehouse_id is not null then 'warehouse'
  else buyer_entity_kind
end
where buyer_entity_kind is null;

create or replace function public.get_production_input_transfer_vehicle_options(
  p_warehouse_slot_id uuid,
  p_production_inventory_id uuid,
  p_quantity integer
)
returns table(
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
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_player_id uuid := auth.uid();
  v_warehouse_slot record;
  v_inventory record;
  v_owner_city_id uuid;
  v_owner_player_id uuid;
  v_product record;
  v_required_capacity numeric := 0;
  v_distance_km numeric := 0;
begin
  if v_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  if p_quantity is null or p_quantity <= 0 then
    raise exception 'Miktar 0''dan buyuk olmalidir.';
  end if;

  select
    ws.*,
    w.player_id,
    w.id as warehouse_id,
    w.city_id,
    w.is_active as warehouse_is_active,
    c.map_position_x as city_x,
    c.map_position_y as city_y
  into v_warehouse_slot
  from public.warehouse_slots ws
  join public.warehouses w on w.id = ws.warehouse_id
  join public.cities c on c.id = w.city_id
  where ws.id = p_warehouse_slot_id;

  if not found or v_warehouse_slot.player_id <> v_player_id then
    raise exception 'Depo slotu bulunamadi veya size ait degil.';
  end if;

  if v_warehouse_slot.warehouse_is_active is not true then
    raise exception 'Kaynak depo aktif degil.';
  end if;

  if p_quantity > coalesce(v_warehouse_slot.quantity, 0) then
    raise exception 'Istenen miktar mevcut stoktan fazla.';
  end if;

  select *
  into v_inventory
  from public.production_inventory
  where id = p_production_inventory_id;

  if not found then
    raise exception 'Production inventory bulunamadi.';
  end if;

  if v_inventory.inventory_type <> 'input' then
    raise exception 'Sadece input inventory icin hammadde lojistigi desteklenir.';
  end if;

  if v_inventory.owner_kind not in ('factory', 'field', 'farm') then
    raise exception 'Bu owner_kind icin input lojistigi desteklenmiyor: %', v_inventory.owner_kind;
  end if;

  if v_inventory.owner_kind = 'factory' then
    select player_id, city_id into v_owner_player_id, v_owner_city_id
    from public.factories
    where id = v_inventory.owner_id;
  elsif v_inventory.owner_kind = 'field' then
    select player_id, city_id into v_owner_player_id, v_owner_city_id
    from public.fields
    where id = v_inventory.owner_id;
  else
    select player_id, city_id into v_owner_player_id, v_owner_city_id
    from public.farms
    where id = v_inventory.owner_id;
  end if;

  if v_owner_player_id is null then
    raise exception 'Hedef uretim birimi bulunamadi.';
  end if;

  if v_owner_player_id <> v_player_id then
    raise exception 'Hedef uretim birimi size ait degil.';
  end if;

  if v_inventory.product_id <> v_warehouse_slot.product_id then
    raise exception 'Depo slotundaki urun ile input inventory urunu ayni olmalidir.';
  end if;

  if v_inventory.quality_level <> v_warehouse_slot.quality_level then
    raise exception 'Depo slotundaki kalite ile input inventory kalitesi ayni olmalidir.';
  end if;

  select *
  into v_product
  from public.products
  where id = v_warehouse_slot.product_id;

  if not found or coalesce(v_product.birim_hacim, 0) <= 0 then
    raise exception 'Urun hacim bilgisi gecersiz.';
  end if;

  v_required_capacity := p_quantity * v_product.birim_hacim;
  v_distance_km := 6371 * 2 * asin(
    sqrt(
      power(sin(radians((v_warehouse_slot.city_x - (
        select c.map_position_x from public.cities c where c.id = v_owner_city_id
      )) / 2)), 2)
      +
      cos(radians((
        select c.map_position_x from public.cities c where c.id = v_owner_city_id
      ))) *
      cos(radians(v_warehouse_slot.city_x)) *
      power(sin(radians((v_warehouse_slot.city_y - (
        select c.map_position_y from public.cities c where c.id = v_owner_city_id
      )) / 2)), 2)
    )
  );

  return query
  with candidates as (
    select
      lv.id as vehicle_id,
      lv.player_id as vehicle_owner_player_id,
      lvt.name as vehicle_name,
      (lv.player_id <> v_player_id) as is_rental,
      lv.capacity,
      lv.speed_kmh,
      lv.current_fuel,
      lv.fuel_capacity,
      lv.fuel_rate,
      lv.condition,
      lv.rental_price,
      v_distance_km as distance_km,
      ceil(v_distance_km * lv.fuel_rate) as fuel_needed,
      ceil(v_distance_km * 0.02) as condition_needed,
      case when lv.player_id <> v_player_id then ceil(v_distance_km * lv.rental_price) else 0 end as rental_cost,
      greatest(1, ceil(((v_distance_km / greatest(lv.speed_kmh, 1)) / 4.0) * 3600))::integer as estimated_duration_seconds,
      lv.status,
      lc.is_active as company_is_active
    from public.logistics_vehicles lv
    join public.logistics_vehicle_types lvt on lvt.id = lv.logistics_vehicle_type_id
    join public.logistics_companies lc on lc.id = lv.logistics_company_id
    where lv.player_id = v_player_id
       or (lv.player_id <> v_player_id and lv.is_available_for_rent = true)
  )
  select
    c.vehicle_id,
    c.vehicle_owner_player_id,
    c.vehicle_name,
    c.is_rental,
    c.capacity,
    c.speed_kmh,
    c.current_fuel,
    c.fuel_capacity,
    c.fuel_rate,
    c.condition,
    c.rental_price,
    c.distance_km,
    c.fuel_needed,
    c.condition_needed,
    c.rental_cost,
    c.estimated_duration_seconds,
    (
      c.status = 'idle'
      and c.company_is_active = true
      and c.capacity >= v_required_capacity
      and c.current_fuel >= c.fuel_needed
      and c.condition > c.condition_needed
    ) as can_select,
    case
      when c.status <> 'idle' then 'Arac su anda uygun degil.'
      when c.company_is_active = false then 'Nakliye firmasi aktif degil.'
      when c.capacity < v_required_capacity then 'Kapasite yetersiz.'
      when c.current_fuel < c.fuel_needed then 'Yakit yetersiz.'
      when c.condition <= c.condition_needed then 'Kondisyon yetersiz.'
      else null
    end as disabled_reason
  from candidates c
  order by c.is_rental asc, can_select desc, c.capacity asc, c.rental_price asc, c.vehicle_name asc;
end;
$function$;

create or replace function public.get_production_output_transfer_vehicle_options(
  p_production_inventory_id uuid,
  p_buyer_warehouse_id uuid,
  p_quantity integer
)
returns table(
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
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_player_id uuid := auth.uid();
  v_inventory record;
  v_owner_city_id uuid;
  v_owner_player_id uuid;
  v_buyer_warehouse record;
  v_product record;
  v_required_capacity numeric := 0;
  v_distance_km numeric := 0;
begin
  if v_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  if p_quantity is null or p_quantity <= 0 then
    raise exception 'Miktar 0''dan buyuk olmalidir.';
  end if;

  select *
  into v_inventory
  from public.production_inventory
  where id = p_production_inventory_id;

  if not found then
    raise exception 'Production inventory bulunamadi.';
  end if;

  if v_inventory.inventory_type <> 'output' then
    raise exception 'Sadece output inventory icin output lojistigi desteklenir.';
  end if;

  if v_inventory.owner_kind not in ('factory', 'field', 'farm', 'mine') then
    raise exception 'Bu owner_kind icin output lojistigi desteklenmiyor: %', v_inventory.owner_kind;
  end if;

  if coalesce(v_inventory.quantity, 0) < p_quantity then
    raise exception 'Istenen miktar mevcut output stoktan fazla.';
  end if;

  if v_inventory.owner_kind = 'factory' then
    select player_id, city_id into v_owner_player_id, v_owner_city_id
    from public.factories
    where id = v_inventory.owner_id;
  elsif v_inventory.owner_kind = 'field' then
    select player_id, city_id into v_owner_player_id, v_owner_city_id
    from public.fields
    where id = v_inventory.owner_id;
  elsif v_inventory.owner_kind = 'farm' then
    select player_id, city_id into v_owner_player_id, v_owner_city_id
    from public.farms
    where id = v_inventory.owner_id;
  else
    select player_id, city_id into v_owner_player_id, v_owner_city_id
    from public.mines
    where id = v_inventory.owner_id;
  end if;

  if v_owner_player_id is null then
    raise exception 'Kaynak uretim birimi bulunamadi.';
  end if;

  if v_owner_player_id <> v_player_id then
    raise exception 'Kaynak uretim birimi size ait degil.';
  end if;

  select
    w.*,
    c.map_position_x as city_x,
    c.map_position_y as city_y
  into v_buyer_warehouse
  from public.warehouses w
  join public.cities c on c.id = w.city_id
  where w.id = p_buyer_warehouse_id
    and w.player_id = v_player_id;

  if not found then
    raise exception 'Hedef depo bulunamadi veya size ait degil.';
  end if;

  if v_buyer_warehouse.is_active is not true then
    raise exception 'Hedef depo aktif degil.';
  end if;

  select *
  into v_product
  from public.products
  where id = v_inventory.product_id;

  if not found or coalesce(v_product.birim_hacim, 0) <= 0 then
    raise exception 'Urun hacim bilgisi gecersiz.';
  end if;

  v_required_capacity := p_quantity * v_product.birim_hacim;
  v_distance_km := 6371 * 2 * asin(
    sqrt(
      power(sin(radians(((
        select c.map_position_x from public.cities c where c.id = v_owner_city_id
      ) - v_buyer_warehouse.city_x) / 2)), 2)
      +
      cos(radians(v_buyer_warehouse.city_x)) *
      cos(radians((
        select c.map_position_x from public.cities c where c.id = v_owner_city_id
      ))) *
      power(sin(radians(((
        select c.map_position_y from public.cities c where c.id = v_owner_city_id
      ) - v_buyer_warehouse.city_y) / 2)), 2)
    )
  );

  return query
  with candidates as (
    select
      lv.id as vehicle_id,
      lv.player_id as vehicle_owner_player_id,
      lvt.name as vehicle_name,
      (lv.player_id <> v_player_id) as is_rental,
      lv.capacity,
      lv.speed_kmh,
      lv.current_fuel,
      lv.fuel_capacity,
      lv.fuel_rate,
      lv.condition,
      lv.rental_price,
      v_distance_km as distance_km,
      ceil(v_distance_km * lv.fuel_rate) as fuel_needed,
      ceil(v_distance_km * 0.02) as condition_needed,
      case when lv.player_id <> v_player_id then ceil(v_distance_km * lv.rental_price) else 0 end as rental_cost,
      greatest(1, ceil(((v_distance_km / greatest(lv.speed_kmh, 1)) / 4.0) * 3600))::integer as estimated_duration_seconds,
      lv.status,
      lc.is_active as company_is_active
    from public.logistics_vehicles lv
    join public.logistics_vehicle_types lvt on lvt.id = lv.logistics_vehicle_type_id
    join public.logistics_companies lc on lc.id = lv.logistics_company_id
    where lv.player_id = v_player_id
       or (lv.player_id <> v_player_id and lv.is_available_for_rent = true)
  )
  select
    c.vehicle_id,
    c.vehicle_owner_player_id,
    c.vehicle_name,
    c.is_rental,
    c.capacity,
    c.speed_kmh,
    c.current_fuel,
    c.fuel_capacity,
    c.fuel_rate,
    c.condition,
    c.rental_price,
    c.distance_km,
    c.fuel_needed,
    c.condition_needed,
    c.rental_cost,
    c.estimated_duration_seconds,
    (
      c.status = 'idle'
      and c.company_is_active = true
      and c.capacity >= v_required_capacity
      and c.current_fuel >= c.fuel_needed
      and c.condition > c.condition_needed
    ) as can_select,
    case
      when c.status <> 'idle' then 'Arac su anda uygun degil.'
      when c.company_is_active = false then 'Nakliye firmasi aktif degil.'
      when c.capacity < v_required_capacity then 'Kapasite yetersiz.'
      when c.current_fuel < c.fuel_needed then 'Yakit yetersiz.'
      when c.condition <= c.condition_needed then 'Kondisyon yetersiz.'
      else null
    end as disabled_reason
  from candidates c
  order by c.is_rental asc, can_select desc, c.capacity asc, c.rental_price asc, c.vehicle_name asc;
end;
$function$;

create or replace function public.start_warehouse_to_production_transfer(
  p_warehouse_slot_id uuid,
  p_production_inventory_id uuid,
  p_quantity integer,
  p_vehicle_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_player_id uuid := auth.uid();
  v_player record;
  v_warehouse_slot record;
  v_inventory record;
  v_owner_city_id uuid;
  v_owner_player_id uuid;
  v_target_city record;
  v_vehicle record;
  v_product record;
  v_transfer_id uuid;
  v_distance_km numeric := 0;
  v_required_capacity numeric := 0;
  v_fuel_used numeric := 0;
  v_condition_loss numeric := 0;
  v_rental_cost numeric := 0;
  v_transport_cost numeric := 0;
  v_duration_seconds integer := 0;
  v_finish_at timestamptz;
  v_now timestamptz := timezone('utc'::text, now());
  v_instant_result jsonb;
begin
  if v_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  if p_quantity is null or p_quantity <= 0 then
    raise exception 'Miktar 0''dan buyuk olmalidir.';
  end if;

  select * into v_player
  from public.players
  where id = v_player_id
  for update;

  if not found then
    raise exception 'Oyuncu bulunamadi.';
  end if;

  select
    ws.*,
    w.player_id,
    w.id as warehouse_id,
    w.city_id,
    w.is_active as warehouse_is_active,
    c.map_position_x as city_x,
    c.map_position_y as city_y
  into v_warehouse_slot
  from public.warehouse_slots ws
  join public.warehouses w on w.id = ws.warehouse_id
  join public.cities c on c.id = w.city_id
  where ws.id = p_warehouse_slot_id
  for update;

  if not found or v_warehouse_slot.player_id <> v_player_id then
    raise exception 'Depo slotu bulunamadi veya size ait degil.';
  end if;

  if v_warehouse_slot.warehouse_is_active is not true then
    raise exception 'Kaynak depo aktif degil.';
  end if;

  if p_quantity > coalesce(v_warehouse_slot.quantity, 0) then
    raise exception 'Istenen miktar mevcut stoktan fazla.';
  end if;

  select *
  into v_inventory
  from public.production_inventory
  where id = p_production_inventory_id
  for update;

  if not found then
    raise exception 'Production inventory bulunamadi.';
  end if;

  if v_inventory.inventory_type <> 'input' then
    raise exception 'Sadece input inventory icin hammadde lojistigi desteklenir.';
  end if;

  if v_inventory.owner_kind not in ('factory', 'field', 'farm') then
    raise exception 'Bu owner_kind icin input lojistigi desteklenmiyor: %', v_inventory.owner_kind;
  end if;

  if v_inventory.owner_kind = 'factory' then
    select player_id, city_id into v_owner_player_id, v_owner_city_id
    from public.factories
    where id = v_inventory.owner_id;
  elsif v_inventory.owner_kind = 'field' then
    select player_id, city_id into v_owner_player_id, v_owner_city_id
    from public.fields
    where id = v_inventory.owner_id;
  else
    select player_id, city_id into v_owner_player_id, v_owner_city_id
    from public.farms
    where id = v_inventory.owner_id;
  end if;

  if v_owner_player_id is null then
    raise exception 'Hedef uretim birimi bulunamadi.';
  end if;

  if v_owner_player_id <> v_player_id then
    raise exception 'Hedef uretim birimi size ait degil.';
  end if;

  if v_inventory.product_id <> v_warehouse_slot.product_id then
    raise exception 'Depo slotundaki urun ile input inventory urunu ayni olmalidir.';
  end if;

  if v_inventory.quality_level <> v_warehouse_slot.quality_level then
    raise exception 'Depo slotundaki kalite ile input inventory kalitesi ayni olmalidir.';
  end if;

  select *
  into v_product
  from public.products
  where id = v_warehouse_slot.product_id;

  if not found or coalesce(v_product.birim_hacim, 0) <= 0 then
    raise exception 'Urun hacim bilgisi gecersiz.';
  end if;

  if v_owner_city_id = v_warehouse_slot.city_id then
    v_instant_result := public.transfer_warehouse_slot_to_production_inventory(
      v_player_id,
      p_warehouse_slot_id,
      p_production_inventory_id,
      p_quantity
    );

    return jsonb_build_object(
      'success', true,
      'message', 'Ayni sehir transferi aninda tamamlandi.',
      'transfer_id', null,
      'mode', 'instant',
      'result', v_instant_result
    );
  end if;

  if p_vehicle_id is null then
    raise exception 'Farkli sehir transferi icin arac secilmelidir.';
  end if;

  select *
  into v_target_city
  from public.cities
  where id = v_owner_city_id;

  if not found then
    raise exception 'Hedef sehir bulunamadi.';
  end if;

  v_required_capacity := p_quantity * v_product.birim_hacim;
  v_distance_km := 6371 * 2 * asin(
    sqrt(
      power(sin(radians((v_warehouse_slot.city_x - v_target_city.map_position_x) / 2)), 2)
      +
      cos(radians(v_target_city.map_position_x)) *
      cos(radians(v_warehouse_slot.city_x)) *
      power(sin(radians((v_warehouse_slot.city_y - v_target_city.map_position_y) / 2)), 2)
    )
  );

  select
    lv.*,
    lc.is_active as company_is_active
  into v_vehicle
  from public.logistics_vehicles lv
  join public.logistics_companies lc on lc.id = lv.logistics_company_id
  where lv.id = p_vehicle_id
  for update;

  if not found then
    raise exception 'Arac bulunamadi.';
  end if;

  if v_vehicle.status <> 'idle' then
    raise exception 'Arac su anda uygun degil.';
  end if;

  if v_vehicle.company_is_active is not true then
    raise exception 'Aracin firmasi aktif degil.';
  end if;

  if v_vehicle.player_id <> v_player_id and v_vehicle.is_available_for_rent is not true then
    raise exception 'Kiralik arac uygun degil.';
  end if;

  v_fuel_used := ceil(v_distance_km * v_vehicle.fuel_rate);
  v_condition_loss := ceil(v_distance_km * 0.02);

  if v_vehicle.capacity < v_required_capacity then
    raise exception 'Arac kapasitesi yetersiz.';
  end if;

  if v_vehicle.current_fuel < v_fuel_used then
    raise exception 'Aracin yakiti yetersiz.';
  end if;

  if v_vehicle.condition <= v_condition_loss then
    raise exception 'Aracin kondisyonu yetersiz.';
  end if;

  v_rental_cost := case
    when v_vehicle.player_id <> v_player_id then ceil(v_distance_km * coalesce(v_vehicle.rental_price, 0))
    else 0
  end;
  v_transport_cost := v_rental_cost;
  v_duration_seconds := greatest(1, ceil(((v_distance_km / greatest(v_vehicle.speed_kmh, 1)) / 4.0) * 3600));
  v_finish_at := v_now + make_interval(secs => v_duration_seconds);

  if coalesce(v_player.cash, 0) < v_rental_cost then
    raise exception 'Kiralik arac icin yeterli nakit yok.';
  end if;

  update public.warehouse_slots
  set
    quantity = quantity - p_quantity,
    updated_at = v_now
  where id = p_warehouse_slot_id;

  update public.production_inventory
  set
    pending_quantity = coalesce(pending_quantity, 0) + p_quantity
  where id = p_production_inventory_id;

  if v_rental_cost > 0 then
    update public.players
    set cash = cash - v_rental_cost
    where id = v_player_id;

    update public.players
    set cash = cash + v_rental_cost
    where id = v_vehicle.player_id;
  end if;

  update public.logistics_vehicles
  set
    current_fuel = greatest(current_fuel - v_fuel_used::integer, 0),
    condition = greatest(condition - v_condition_loss::integer, 0),
    status = 'on_route',
    updated_at = v_now
  where id = p_vehicle_id;

  insert into public.logistics_transfers (
    buyer_player_id,
    seller_player_id,
    buyer_production_inventory_id,
    seller_warehouse_id,
    seller_warehouse_slot_id,
    logistics_vehicle_id,
    vehicle_owner_player_id,
    is_rental,
    product_id,
    quality_level,
    quantity,
    unit_price,
    total_price,
    product_unit_volume,
    reserved_capacity_amount,
    distance_km,
    fuel_used,
    condition_loss,
    rental_cost,
    transport_cost,
    transfer_type,
    seller_entity_kind,
    buyer_entity_kind,
    started_at,
    finish_at,
    status,
    updated_at
  )
  values (
    v_player_id,
    v_player_id,
    p_production_inventory_id,
    v_warehouse_slot.warehouse_id,
    p_warehouse_slot_id,
    p_vehicle_id,
    v_vehicle.player_id,
    (v_vehicle.player_id <> v_player_id),
    v_warehouse_slot.product_id,
    v_warehouse_slot.quality_level,
    p_quantity,
    coalesce(v_warehouse_slot.cost, 0),
    0,
    v_product.birim_hacim,
    0,
    v_distance_km,
    v_fuel_used,
    v_condition_loss,
    v_rental_cost,
    v_transport_cost,
    'warehouse_to_production',
    'warehouse',
    'production_inventory',
    v_now,
    v_finish_at,
    'in_transit',
    v_now
  )
  returning id into v_transfer_id;

  return jsonb_build_object(
    'success', true,
    'message', 'Uretim lojistigi transferi baslatildi.',
    'transfer_id', v_transfer_id,
    'mode', 'transfer'
  );
end;
$function$;

create or replace function public.start_production_to_warehouse_transfer(
  p_production_inventory_id uuid,
  p_buyer_warehouse_id uuid,
  p_quantity integer,
  p_vehicle_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_player_id uuid := auth.uid();
  v_player record;
  v_inventory record;
  v_owner_city_id uuid;
  v_owner_player_id uuid;
  v_source_city record;
  v_buyer_warehouse record;
  v_vehicle record;
  v_product record;
  v_reserve_result jsonb;
  v_transfer_id uuid;
  v_distance_km numeric := 0;
  v_required_capacity numeric := 0;
  v_fuel_used numeric := 0;
  v_condition_loss numeric := 0;
  v_rental_cost numeric := 0;
  v_transport_cost numeric := 0;
  v_duration_seconds integer := 0;
  v_finish_at timestamptz;
  v_now timestamptz := timezone('utc'::text, now());
  v_instant_result jsonb;
begin
  if v_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  if p_quantity is null or p_quantity <= 0 then
    raise exception 'Miktar 0''dan buyuk olmalidir.';
  end if;

  select * into v_player
  from public.players
  where id = v_player_id
  for update;

  if not found then
    raise exception 'Oyuncu bulunamadi.';
  end if;

  select *
  into v_inventory
  from public.production_inventory
  where id = p_production_inventory_id
  for update;

  if not found then
    raise exception 'Production inventory bulunamadi.';
  end if;

  if v_inventory.inventory_type <> 'output' then
    raise exception 'Sadece output inventory icin output lojistigi desteklenir.';
  end if;

  if v_inventory.owner_kind not in ('factory', 'field', 'farm', 'mine') then
    raise exception 'Bu owner_kind icin output lojistigi desteklenmiyor: %', v_inventory.owner_kind;
  end if;

  if coalesce(v_inventory.quantity, 0) < p_quantity then
    raise exception 'Istenen miktar mevcut output stoktan fazla.';
  end if;

  if v_inventory.owner_kind = 'factory' then
    select player_id, city_id into v_owner_player_id, v_owner_city_id
    from public.factories
    where id = v_inventory.owner_id;
  elsif v_inventory.owner_kind = 'field' then
    select player_id, city_id into v_owner_player_id, v_owner_city_id
    from public.fields
    where id = v_inventory.owner_id;
  elsif v_inventory.owner_kind = 'farm' then
    select player_id, city_id into v_owner_player_id, v_owner_city_id
    from public.farms
    where id = v_inventory.owner_id;
  else
    select player_id, city_id into v_owner_player_id, v_owner_city_id
    from public.mines
    where id = v_inventory.owner_id;
  end if;

  if v_owner_player_id is null then
    raise exception 'Kaynak uretim birimi bulunamadi.';
  end if;

  if v_owner_player_id <> v_player_id then
    raise exception 'Kaynak uretim birimi size ait degil.';
  end if;

  select
    w.*,
    c.map_position_x as city_x,
    c.map_position_y as city_y
  into v_buyer_warehouse
  from public.warehouses w
  join public.cities c on c.id = w.city_id
  where w.id = p_buyer_warehouse_id
    and w.player_id = v_player_id
  for update;

  if not found then
    raise exception 'Hedef depo bulunamadi veya size ait degil.';
  end if;

  if v_buyer_warehouse.is_active is not true then
    raise exception 'Hedef depo aktif degil.';
  end if;

  select *
  into v_product
  from public.products
  where id = v_inventory.product_id;

  if not found or coalesce(v_product.birim_hacim, 0) <= 0 then
    raise exception 'Urun hacim bilgisi gecersiz.';
  end if;

  if v_buyer_warehouse.city_id = v_owner_city_id then
    v_instant_result := public.transfer_production_inventory_to_warehouse(
      v_player_id,
      p_production_inventory_id,
      p_buyer_warehouse_id,
      p_quantity
    );

    return jsonb_build_object(
      'success', true,
      'message', 'Ayni sehir transferi aninda tamamlandi.',
      'transfer_id', null,
      'mode', 'instant',
      'result', v_instant_result
    );
  end if;

  if p_vehicle_id is null then
    raise exception 'Farkli sehir transferi icin arac secilmelidir.';
  end if;

  select *
  into v_source_city
  from public.cities
  where id = v_owner_city_id;

  if not found then
    raise exception 'Kaynak sehir bulunamadi.';
  end if;

  v_required_capacity := p_quantity * v_product.birim_hacim;
  v_distance_km := 6371 * 2 * asin(
    sqrt(
      power(sin(radians((v_source_city.map_position_x - v_buyer_warehouse.city_x) / 2)), 2)
      +
      cos(radians(v_buyer_warehouse.city_x)) *
      cos(radians(v_source_city.map_position_x)) *
      power(sin(radians((v_source_city.map_position_y - v_buyer_warehouse.city_y) / 2)), 2)
    )
  );

  select
    lv.*,
    lc.is_active as company_is_active
  into v_vehicle
  from public.logistics_vehicles lv
  join public.logistics_companies lc on lc.id = lv.logistics_company_id
  where lv.id = p_vehicle_id
  for update;

  if not found then
    raise exception 'Arac bulunamadi.';
  end if;

  if v_vehicle.status <> 'idle' then
    raise exception 'Arac su anda uygun degil.';
  end if;

  if v_vehicle.company_is_active is not true then
    raise exception 'Aracin firmasi aktif degil.';
  end if;

  if v_vehicle.player_id <> v_player_id and v_vehicle.is_available_for_rent is not true then
    raise exception 'Kiralik arac uygun degil.';
  end if;

  v_fuel_used := ceil(v_distance_km * v_vehicle.fuel_rate);
  v_condition_loss := ceil(v_distance_km * 0.02);

  if v_vehicle.capacity < v_required_capacity then
    raise exception 'Arac kapasitesi yetersiz.';
  end if;

  if v_vehicle.current_fuel < v_fuel_used then
    raise exception 'Aracin yakiti yetersiz.';
  end if;

  if v_vehicle.condition <= v_condition_loss then
    raise exception 'Aracin kondisyonu yetersiz.';
  end if;

  v_rental_cost := case
    when v_vehicle.player_id <> v_player_id then ceil(v_distance_km * coalesce(v_vehicle.rental_price, 0))
    else 0
  end;
  v_transport_cost := v_rental_cost;
  v_duration_seconds := greatest(1, ceil(((v_distance_km / greatest(v_vehicle.speed_kmh, 1)) / 4.0) * 3600));
  v_finish_at := v_now + make_interval(secs => v_duration_seconds);

  if coalesce(v_player.cash, 0) < v_rental_cost then
    raise exception 'Kiralik arac icin yeterli nakit yok.';
  end if;

  v_reserve_result := public.reserve_warehouse_capacity(
    v_player_id,
    p_buyer_warehouse_id,
    v_inventory.product_id,
    p_quantity
  );

  update public.production_inventory
  set quantity = quantity - p_quantity
  where id = p_production_inventory_id;

  if v_rental_cost > 0 then
    update public.players
    set cash = cash - v_rental_cost
    where id = v_player_id;

    update public.players
    set cash = cash + v_rental_cost
    where id = v_vehicle.player_id;
  end if;

  update public.logistics_vehicles
  set
    current_fuel = greatest(current_fuel - v_fuel_used::integer, 0),
    condition = greatest(condition - v_condition_loss::integer, 0),
    status = 'on_route',
    updated_at = v_now
  where id = p_vehicle_id;

  insert into public.logistics_transfers (
    buyer_player_id,
    seller_player_id,
    buyer_warehouse_id,
    seller_production_inventory_id,
    logistics_vehicle_id,
    vehicle_owner_player_id,
    is_rental,
    product_id,
    quality_level,
    quantity,
    unit_price,
    total_price,
    product_unit_volume,
    reserved_capacity_amount,
    distance_km,
    fuel_used,
    condition_loss,
    rental_cost,
    transport_cost,
    transfer_type,
    seller_entity_kind,
    buyer_entity_kind,
    started_at,
    finish_at,
    status,
    updated_at
  )
  values (
    v_player_id,
    v_player_id,
    p_buyer_warehouse_id,
    p_production_inventory_id,
    p_vehicle_id,
    v_vehicle.player_id,
    (v_vehicle.player_id <> v_player_id),
    v_inventory.product_id,
    v_inventory.quality_level,
    p_quantity,
    coalesce(v_inventory.cost, 0),
    0,
    v_product.birim_hacim,
    coalesce((v_reserve_result ->> 'reserved_added')::numeric, 0),
    v_distance_km,
    v_fuel_used,
    v_condition_loss,
    v_rental_cost,
    v_transport_cost,
    'production_to_warehouse',
    'production_inventory',
    'warehouse',
    v_now,
    v_finish_at,
    'in_transit',
    v_now
  )
  returning id into v_transfer_id;

  return jsonb_build_object(
    'success', true,
    'message', 'Output lojistigi transferi baslatildi.',
    'transfer_id', v_transfer_id,
    'mode', 'transfer'
  );
end;
$function$;

create or replace function public.complete_production_logistics_transfer(
  p_transfer_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_transfer record;
  v_inventory record;
  v_incoming_unit_cost numeric := 0;
  v_new_cost numeric := 0;
  v_add_result jsonb;
begin
  select *
  into v_transfer
  from public.logistics_transfers
  where id = p_transfer_id
  for update;

  if not found then
    raise exception 'Transfer bulunamadi.';
  end if;

  if v_transfer.status <> 'in_transit' then
    return jsonb_build_object(
      'success', true,
      'transfer_id', p_transfer_id,
      'status', v_transfer.status,
      'skipped', true
    );
  end if;

  if v_transfer.transfer_type = 'warehouse_to_production' then
    select *
    into v_inventory
    from public.production_inventory
    where id = v_transfer.buyer_production_inventory_id
    for update;

    if not found then
      raise exception 'Hedef production inventory bulunamadi.';
    end if;

    if v_inventory.inventory_type <> 'input' then
      raise exception 'Hedef production inventory input tipinde degil.';
    end if;

    if v_inventory.product_id <> v_transfer.product_id
       or v_inventory.quality_level <> v_transfer.quality_level then
      raise exception 'Hedef production inventory urun/kalite uyumsuz.';
    end if;

    v_incoming_unit_cost := coalesce(v_transfer.unit_price, 0)
      + case when v_transfer.quantity > 0 then coalesce(v_transfer.transport_cost, 0) / v_transfer.quantity else 0 end;

    v_new_cost := case
      when coalesce(v_inventory.quantity, 0) + v_transfer.quantity > 0 then
        (
          coalesce(v_inventory.quantity, 0) * coalesce(v_inventory.cost, 0)
          + v_transfer.quantity * v_incoming_unit_cost
        ) / (coalesce(v_inventory.quantity, 0) + v_transfer.quantity)
      else coalesce(v_inventory.cost, 0)
    end;

    update public.production_inventory
    set
      quantity = coalesce(quantity, 0) + v_transfer.quantity,
      pending_quantity = greatest(coalesce(pending_quantity, 0) - v_transfer.quantity, 0),
      cost = v_new_cost
    where id = v_transfer.buyer_production_inventory_id;

    v_add_result := jsonb_build_object(
      'success', true,
      'target', 'production_inventory',
      'production_inventory_id', v_transfer.buyer_production_inventory_id,
      'quantity_added', v_transfer.quantity,
      'new_cost', v_new_cost
    );
  elsif v_transfer.transfer_type = 'production_to_warehouse' then
    v_add_result := public.add_product_to_warehouse(
      v_transfer.buyer_player_id,
      v_transfer.buyer_warehouse_id,
      v_transfer.product_id,
      v_transfer.quality_level,
      v_transfer.quantity,
      v_transfer.unit_price,
      v_transfer.transport_cost,
      true
    );
  else
    raise exception 'Desteklenmeyen production transfer type: %', v_transfer.transfer_type;
  end if;

  update public.logistics_vehicles
  set
    status = 'idle',
    updated_at = timezone('utc'::text, now())
  where id = v_transfer.logistics_vehicle_id;

  update public.logistics_transfers
  set
    status = 'completed',
    completed_at = timezone('utc'::text, now()),
    updated_at = timezone('utc'::text, now())
  where id = p_transfer_id;

  return jsonb_build_object(
    'success', true,
    'transfer_id', p_transfer_id,
    'status', 'completed',
    'result', v_add_result
  );
end;
$function$;

create or replace function public.complete_due_market_transfers(
  p_buyer_player_id uuid default auth.uid(),
  p_limit integer default 100
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_completed_count integer := 0;
  v_transfer record;
  v_result jsonb;
  v_ids uuid[] := '{}';
begin
  for v_transfer in
    select lt.id, lt.transfer_type
    from public.logistics_transfers lt
    where lt.status = 'in_transit'
      and lt.finish_at <= timezone('utc'::text, now())
      and (p_buyer_player_id is null or lt.buyer_player_id = p_buyer_player_id)
    order by lt.finish_at asc
    limit greatest(coalesce(p_limit, 100), 1)
    for update skip locked
  loop
    if coalesce(v_transfer.transfer_type, '') in ('warehouse_to_production', 'production_to_warehouse') then
      v_result := public.complete_production_logistics_transfer(v_transfer.id);
    else
      v_result := public.complete_market_transfer_system(v_transfer.id);
    end if;

    if coalesce((v_result ->> 'success')::boolean, false) then
      v_completed_count := v_completed_count + 1;
      v_ids := array_append(v_ids, v_transfer.id);
    end if;
  end loop;

  return jsonb_build_object(
    'success', true,
    'completed_count', v_completed_count,
    'transfer_ids', v_ids
  );
end;
$function$;

drop function if exists public.get_buyer_transfer_map_items();

create function public.get_buyer_transfer_map_items()
returns table(
  id uuid,
  quantity integer,
  status text,
  is_rental boolean,
  total_price numeric,
  rental_cost numeric,
  started_at timestamp with time zone,
  finish_at timestamp with time zone,
  product_id text,
  product_name text,
  product_icon text,
  seller_entity_kind text,
  buyer_entity_kind text,
  seller_warehouse_id uuid,
  seller_warehouse_name text,
  seller_city_id uuid,
  seller_city_name text,
  seller_city_x numeric,
  seller_city_y numeric,
  buyer_warehouse_id uuid,
  buyer_warehouse_name text,
  buyer_city_id uuid,
  buyer_city_name text,
  buyer_city_x numeric,
  buyer_city_y numeric
)
language sql
security definer
set search_path to 'public'
as $function$
  select
    lt.id,
    lt.quantity,
    lt.status,
    lt.is_rental,
    lt.total_price,
    lt.rental_cost,
    lt.started_at,
    lt.finish_at,
    p.id as product_id,
    p.urun_adi as product_name,
    p.urun_iconu as product_icon,
    coalesce(
      lt.seller_entity_kind,
      case
        when lt.seller_production_inventory_id is not null then 'production_inventory'
        when lt.seller_store_id is not null or lt.seller_store_slot_id is not null then 'store_slot'
        else 'warehouse'
      end
    ) as seller_entity_kind,
    coalesce(
      lt.buyer_entity_kind,
      case
        when lt.buyer_production_inventory_id is not null then 'production_inventory'
        when lt.buyer_store_id is not null or lt.buyer_store_slot_id is not null then 'store_slot'
        else 'warehouse'
      end
    ) as buyer_entity_kind,
    coalesce(sw.id, ss.id, spi.id) as seller_warehouse_id,
    coalesce(
      sw.name,
      ss.name,
      case
        when spi.id is not null then
          coalesce(sf.name, sfi.name, sfa.name, sm.name, 'Uretim')
          || ' '
          || case when spi.inventory_type = 'input' then 'Input' else 'Output' end
        else null
      end
    ) as seller_warehouse_name,
    coalesce(sc_w.id, sc_s.id, sc_p.id) as seller_city_id,
    coalesce(sc_w.name, sc_s.name, sc_p.name) as seller_city_name,
    coalesce(sc_w.map_position_x, sc_s.map_position_x, sc_p.map_position_x) as seller_city_x,
    coalesce(sc_w.map_position_y, sc_s.map_position_y, sc_p.map_position_y) as seller_city_y,
    coalesce(bw.id, bs.id, bpi.id) as buyer_warehouse_id,
    coalesce(
      bw.name,
      bs.name,
      case
        when bpi.id is not null then
          coalesce(bf.name, bfi.name, bfa.name, bm.name, 'Uretim')
          || ' '
          || case when bpi.inventory_type = 'input' then 'Input' else 'Output' end
        else null
      end
    ) as buyer_warehouse_name,
    coalesce(bc_w.id, bc_s.id, bc_p.id) as buyer_city_id,
    coalesce(bc_w.name, bc_s.name, bc_p.name) as buyer_city_name,
    coalesce(bc_w.map_position_x, bc_s.map_position_x, bc_p.map_position_x) as buyer_city_x,
    coalesce(bc_w.map_position_y, bc_s.map_position_y, bc_p.map_position_y) as buyer_city_y
  from public.logistics_transfers lt
  join public.products p on p.id = lt.product_id
  left join public.warehouses sw on sw.id = lt.seller_warehouse_id
  left join public.cities sc_w on sc_w.id = sw.city_id
  left join public.stores ss on ss.id = lt.seller_store_id
  left join public.cities sc_s on sc_s.id = ss.city_id
  left join public.production_inventory spi on spi.id = lt.seller_production_inventory_id
  left join public.factories sf on sf.id = spi.owner_id and spi.owner_kind = 'factory'
  left join public.fields sfi on sfi.id = spi.owner_id and spi.owner_kind = 'field'
  left join public.farms sfa on sfa.id = spi.owner_id and spi.owner_kind = 'farm'
  left join public.mines sm on sm.id = spi.owner_id and spi.owner_kind = 'mine'
  left join public.cities sc_p on sc_p.id = coalesce(sf.city_id, sfi.city_id, sfa.city_id, sm.city_id)
  left join public.warehouses bw on bw.id = lt.buyer_warehouse_id
  left join public.cities bc_w on bc_w.id = bw.city_id
  left join public.stores bs on bs.id = lt.buyer_store_id
  left join public.cities bc_s on bc_s.id = bs.city_id
  left join public.production_inventory bpi on bpi.id = lt.buyer_production_inventory_id
  left join public.factories bf on bf.id = bpi.owner_id and bpi.owner_kind = 'factory'
  left join public.fields bfi on bfi.id = bpi.owner_id and bpi.owner_kind = 'field'
  left join public.farms bfa on bfa.id = bpi.owner_id and bpi.owner_kind = 'farm'
  left join public.mines bm on bm.id = bpi.owner_id and bpi.owner_kind = 'mine'
  left join public.cities bc_p on bc_p.id = coalesce(bf.city_id, bfi.city_id, bfa.city_id, bm.city_id)
  where lt.buyer_player_id = auth.uid()
    and lt.status = 'in_transit'
  order by lt.finish_at asc;
$function$;
