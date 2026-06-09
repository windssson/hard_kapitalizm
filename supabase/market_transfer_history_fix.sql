create or replace function public.start_market_transfer(
  p_buyer_warehouse_id uuid,
  p_seller_slot_id uuid,
  p_quantity integer,
  p_vehicle_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_buyer_id uuid := auth.uid();
  v_buyer_player record;
  v_seller_player record;
  v_buyer_warehouse record;
  v_seller_slot record;
  v_product record;
  v_vehicle record;
  v_reserve_result jsonb;
  v_add_result jsonb;
  v_transfer_id uuid;
  v_distance_km numeric := 0;
  v_required_capacity numeric := 0;
  v_fuel_used numeric := 0;
  v_condition_loss numeric := 0;
  v_rental_cost numeric := 0;
  v_transport_cost numeric := 0;
  v_duration_seconds integer := 0;
  v_finish_at timestamptz;
  v_total_price numeric := 0;
  v_unit_price numeric := 0;
  v_now timestamptz := timezone('utc'::text, now());
begin
  if v_buyer_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  if p_quantity is null or p_quantity <= 0 then
    raise exception 'Miktar 0''dan buyuk olmalidir.';
  end if;

  select * into v_buyer_player
  from public.players
  where id = v_buyer_id
  for update;

  if not found then
    raise exception 'Alici oyuncu bulunamadi.';
  end if;

  select w.*, c.map_position_x as city_x, c.map_position_y as city_y
  into v_buyer_warehouse
  from public.warehouses w
  join public.cities c on c.id = w.city_id
  where w.id = p_buyer_warehouse_id
    and w.player_id = v_buyer_id
  for update;

  if not found then
    raise exception 'Alici deposu bulunamadi veya size ait degil.';
  end if;

  if v_buyer_warehouse.is_active is not true then
    raise exception 'Alici deposu aktif degil.';
  end if;

  select ws.*, w.player_id as seller_player_id, w.id as seller_warehouse_id,
         w.city_id as seller_city_id,
         c.map_position_x as city_x, c.map_position_y as city_y
  into v_seller_slot
  from public.warehouse_slots ws
  join public.warehouses w on w.id = ws.warehouse_id
  join public.cities c on c.id = w.city_id
  where ws.id = p_seller_slot_id
  for update;

  if not found then
    raise exception 'Satici slotu bulunamadi.';
  end if;

  if v_seller_slot.is_available_for_sale is not true then
    raise exception 'Bu slot su anda satisa acik degil.';
  end if;

  if p_quantity > v_seller_slot.quantity then
    raise exception 'Istenen miktar mevcut stoktan fazla.';
  end if;

  if v_seller_slot.seller_player_id = v_buyer_id then
    raise exception 'Kendi ilaninizi satin alamazsiniz.';
  end if;

  select * into v_seller_player
  from public.players
  where id = v_seller_slot.seller_player_id
  for update;

  if not found then
    raise exception 'Satici oyuncu bulunamadi.';
  end if;

  select * into v_product
  from public.products
  where id = v_seller_slot.product_id;

  if not found or coalesce(v_product.birim_hacim, 0) <= 0 then
    raise exception 'Urun hacim bilgisi gecersiz.';
  end if;

  v_required_capacity := p_quantity * v_product.birim_hacim;
  v_unit_price := coalesce(v_seller_slot.price, 0);

  if v_unit_price <= 0 then
    raise exception 'Bu ilan icin gecerli satis fiyati yok.';
  end if;

  v_total_price := p_quantity * v_unit_price;

  if v_seller_slot.seller_city_id = v_buyer_warehouse.city_id then
    if coalesce(v_buyer_player.cash, 0) < v_total_price then
      raise exception 'Yeterli nakit yok.';
    end if;

    update public.warehouse_slots
    set
      quantity = quantity - p_quantity,
      is_available_for_sale = case when quantity - p_quantity > 0 then is_available_for_sale else false end,
      updated_at = v_now
    where id = p_seller_slot_id;

    update public.players
    set cash = cash - v_total_price
    where id = v_buyer_id;

    update public.players
    set cash = cash + v_total_price
    where id = v_seller_slot.seller_player_id;

    v_add_result := public.add_product_to_warehouse(
      v_buyer_id,
      p_buyer_warehouse_id,
      v_seller_slot.product_id,
      v_seller_slot.quality_level,
      p_quantity,
      v_unit_price,
      0,
      false
    );

    insert into public.logistics_transfers (
      buyer_player_id, seller_player_id, buyer_warehouse_id, seller_warehouse_id,
      seller_warehouse_slot_id, logistics_vehicle_id, vehicle_owner_player_id, is_rental,
      product_id, quality_level, quantity, unit_price, total_price, product_unit_volume,
      reserved_capacity_amount, distance_km, fuel_used, condition_loss, rental_cost,
      transport_cost, transfer_type, seller_entity_kind, buyer_entity_kind,
      started_at, finish_at, completed_at, status, updated_at
    )
    values (
      v_buyer_id, v_seller_slot.seller_player_id, p_buyer_warehouse_id, v_seller_slot.seller_warehouse_id,
      p_seller_slot_id, null, null, false,
      v_seller_slot.product_id, v_seller_slot.quality_level, p_quantity, v_unit_price, v_total_price, v_product.birim_hacim,
      0, 0, 0, 0, 0,
      0, 'market_to_warehouse', 'warehouse', 'warehouse',
      v_now, v_now, v_now, 'completed', v_now
    )
    returning id into v_transfer_id;

    return jsonb_build_object(
      'success', true, 'mode', 'instant', 'transfer_id', v_transfer_id,
      'warehouse_result', v_add_result, 'seller_slot_id', p_seller_slot_id,
      'product_id', v_seller_slot.product_id, 'quality_level', v_seller_slot.quality_level,
      'quantity', p_quantity, 'unit_price', v_unit_price, 'total_price', v_total_price
    );
  end if;

  v_distance_km := 6371 * 2 * asin(
    sqrt(
      power(sin(radians((v_seller_slot.city_x - v_buyer_warehouse.city_x) / 2)), 2) +
      cos(radians(v_buyer_warehouse.city_x)) *
      cos(radians(v_seller_slot.city_x)) *
      power(sin(radians((v_seller_slot.city_y - v_buyer_warehouse.city_y) / 2)), 2)
    )
  );

  if p_vehicle_id = '00000000-0000-0000-0000-000000000000' then
    select '00000000-0000-0000-0000-000000000000'::uuid as player_id into v_vehicle;
    v_rental_cost := ceil(v_distance_km * 5.0);
    v_transport_cost := v_rental_cost;
    v_duration_seconds := greatest(1, ceil(((v_distance_km / 60.0) / 6.0) * 3600))::integer;
    v_finish_at := timezone('utc'::text, now()) + make_interval(secs => v_duration_seconds);
  else
    select lv.*, lc.is_active as company_is_active
    into v_vehicle
    from public.logistics_vehicles lv
    join public.logistics_companies lc on lc.id = lv.logistics_company_id
    where lv.id = p_vehicle_id
    for update;
    if not found then raise exception 'Arac bulunamadi.'; end if;
    if v_vehicle.player_id = v_seller_slot.seller_player_id then raise exception 'Saticinin araci kullanilamaz.'; end if;
    if v_vehicle.player_id <> v_buyer_id and v_vehicle.is_available_for_rent is not true then raise exception 'Kiralik arac uygun degil.'; end if;
    if v_vehicle.status <> 'idle' then raise exception 'Arac su anda uygun degil.'; end if;
    if v_vehicle.company_is_active is not true then raise exception 'Aracin firmasi aktif degil.'; end if;
    if public.logistics_vehicle_matches_route(v_vehicle.route_city_a_id, v_vehicle.route_city_b_id, v_seller_slot.seller_city_id, v_buyer_warehouse.city_id) is not true then
      raise exception 'Bu arac secilen sehir cifti icin atanmis degil.';
    end if;
    v_fuel_used := ceil(v_distance_km * v_vehicle.fuel_rate);
    v_condition_loss := ceil(v_distance_km * 0.005);
    if v_vehicle.capacity < v_required_capacity then raise exception 'Arac kapasitesi yetersiz.'; end if;
    if v_vehicle.current_fuel < v_fuel_used then raise exception 'Aracin yakiti yetersiz.'; end if;
    if v_vehicle.condition <= v_condition_loss then raise exception 'Aracin kondisyonu yetersiz.'; end if;
    v_rental_cost := case when v_vehicle.player_id <> v_buyer_id then ceil(v_distance_km * coalesce(v_vehicle.rental_price, 0)) else 0 end;
    v_transport_cost := v_rental_cost + (v_fuel_used * coalesce(v_vehicle.fuel_cost, 0));
    v_duration_seconds := greatest(1, ceil(((v_distance_km / greatest(v_vehicle.speed_kmh, 1)) / 6.0) * 3600));
    v_finish_at := timezone('utc'::text, now()) + make_interval(secs => v_duration_seconds);
  end if;

  if coalesce(v_buyer_player.cash, 0) < (v_total_price + v_rental_cost) then
    raise exception 'Yeterli nakit yok.';
  end if;

  v_reserve_result := public.reserve_warehouse_capacity(v_buyer_id, p_buyer_warehouse_id, v_seller_slot.product_id, p_quantity);

  update public.warehouse_slots
  set quantity = quantity - p_quantity,
      is_available_for_sale = case when quantity - p_quantity > 0 then is_available_for_sale else false end,
      updated_at = timezone('utc'::text, now())
  where id = p_seller_slot_id;

  update public.players set cash = cash - (v_total_price + v_rental_cost) where id = v_buyer_id;
  update public.players set cash = cash + v_total_price where id = v_seller_slot.seller_player_id;

  if v_rental_cost > 0 and p_vehicle_id <> '00000000-0000-0000-0000-000000000000' then
    update public.players set cash = cash + v_rental_cost where id = v_vehicle.player_id;
  end if;

  if p_vehicle_id <> '00000000-0000-0000-0000-000000000000' then
    update public.logistics_vehicles
    set current_fuel = greatest(current_fuel - v_fuel_used::integer, 0),
        condition = greatest(condition - v_condition_loss::integer, 0),
        status = 'on_route',
        updated_at = timezone('utc'::text, now())
    where id = p_vehicle_id;
  end if;

  insert into public.logistics_transfers (
    buyer_player_id, seller_player_id, buyer_warehouse_id, seller_warehouse_id,
    seller_warehouse_slot_id, logistics_vehicle_id, vehicle_owner_player_id, is_rental,
    product_id, quality_level, quantity, unit_price, total_price, product_unit_volume,
    reserved_capacity_amount, distance_km, fuel_used, condition_loss, rental_cost,
    transport_cost, transfer_type, seller_entity_kind, buyer_entity_kind,
    started_at, finish_at, status, updated_at
  )
  values (
    v_buyer_id, v_seller_slot.seller_player_id, p_buyer_warehouse_id, v_seller_slot.seller_warehouse_id,
    p_seller_slot_id,
    case when p_vehicle_id = '00000000-0000-0000-0000-000000000000' then null else p_vehicle_id end,
    case when p_vehicle_id = '00000000-0000-0000-0000-000000000000' then null else v_vehicle.player_id end,
    (p_vehicle_id <> '00000000-0000-0000-0000-000000000000' and v_vehicle.player_id <> v_buyer_id),
    v_seller_slot.product_id, v_seller_slot.quality_level, p_quantity, v_unit_price, v_total_price,
    v_product.birim_hacim, v_required_capacity, v_distance_km, v_fuel_used, v_condition_loss,
    v_rental_cost, v_transport_cost, 'market_to_warehouse', 'warehouse', 'warehouse',
    timezone('utc'::text, now()), v_finish_at, 'in_transit', timezone('utc'::text, now())
  )
  returning id into v_transfer_id;

  if v_rental_cost > 0
     and p_vehicle_id <> '00000000-0000-0000-0000-000000000000'
     and v_vehicle.player_id is not null then
    insert into public.logistics_finance_entries (
      player_id, logistics_company_id, vehicle_id, entry_type, category,
      amount, related_transfer_id, description, metadata
    )
    values (
      v_vehicle.player_id, v_vehicle.logistics_company_id, p_vehicle_id,
      'income', 'rental_income', v_rental_cost, v_transfer_id,
      'Arac kiralama geliri',
      jsonb_build_object('transfer_type', 'market_to_warehouse')
    );
  end if;

  return jsonb_build_object(
    'success', true, 'transfer_id', v_transfer_id, 'vehicle_id', p_vehicle_id,
    'seller_slot_id', p_seller_slot_id, 'product_id', v_seller_slot.product_id,
    'quality_level', v_seller_slot.quality_level, 'quantity', p_quantity,
    'unit_price', v_unit_price, 'total_price', v_total_price,
    'rental_cost', v_rental_cost, 'transport_cost', v_transport_cost,
    'distance_km', round(v_distance_km, 2), 'fuel_used', v_fuel_used,
    'condition_loss', v_condition_loss, 'reserved_capacity_amount', v_required_capacity,
    'duration_seconds', v_duration_seconds, 'finish_at', v_finish_at,
    'reserve_result', v_reserve_result
  );
end;
$function$;
