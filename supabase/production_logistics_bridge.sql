create or replace function public.start_warehouse_to_production_transfer(
  p_warehouse_slot_id uuid,
  p_production_inventory_id uuid,
  p_quantity integer,
  p_vehicle_id uuid default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_default_brand uuid := '00000000-0000-0000-0000-000000000000'::uuid;
  v_player_id uuid := auth.uid();
  v_npc_logistics_player_id uuid;
  v_now timestamptz := timezone('utc', now());
  v_source_slot record;
  v_target_inventory record;
  v_product products%rowtype;
  v_vehicle logistics_vehicles%rowtype;
  v_transfer_id uuid;
  v_same_city boolean := false;
  v_distance_km numeric := 0;
  v_fuel_used numeric := 0;
  v_condition_loss numeric := 0;
  v_transport_cost numeric := 0;
  v_rental_cost numeric := 0;
  v_duration_seconds integer := 0;
  v_finish_at timestamptz := v_now;
  v_item_volume numeric := 0;
  v_used_input_capacity numeric := 0;
  v_new_cost numeric := 0;
  v_total_existing_cost numeric := 0;
  v_total_incoming_cost numeric := 0;
  v_is_rental boolean := false;
begin
  if v_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  if p_quantity is null or p_quantity <= 0 then
    raise exception 'Transfer miktari 0 dan buyuk olmalidir.';
  end if;

  select
    ws.*,
    w.player_id,
    w.city_id
  into v_source_slot
  from public.warehouse_slots ws
  join public.warehouses w on w.id = ws.warehouse_id
  where ws.id = p_warehouse_slot_id
  for update;

  if not found then
    raise exception 'Kaynak depo slotu bulunamadi.';
  end if;

  if v_source_slot.player_id <> v_player_id then
    raise exception 'Kaynak depo slotu oyuncuya ait degil.';
  end if;

  if coalesce(v_source_slot.product_id, '') = '' then
    raise exception 'Kaynak slotta urun bulunamadi.';
  end if;

  if coalesce(v_source_slot.quantity, 0) < p_quantity then
    raise exception 'Kaynak slotta yeterli stok yok.';
  end if;

  select
    pi.*,
    case
      when pi.owner_kind = 'factory' then fx.player_id
      when pi.owner_kind = 'farm' then fa.player_id
      when pi.owner_kind = 'field' then fld.player_id
      when pi.owner_kind = 'mine' then m.player_id
      else null
    end as owner_player_id,
    case
      when pi.owner_kind = 'factory' then fx.city_id
      when pi.owner_kind = 'farm' then fa.city_id
      when pi.owner_kind = 'field' then fld.city_id
      when pi.owner_kind = 'mine' then m.city_id
      else null
    end as owner_city_id,
    case
      when pi.owner_kind = 'factory' then fx.input_capacity
      when pi.owner_kind = 'farm' then fa.input_capacity
      when pi.owner_kind = 'field' then fld.input_capacity
      else 0
    end as owner_input_capacity
  into v_target_inventory
  from public.production_inventory pi
  left join public.factories fx
    on pi.owner_kind = 'factory' and fx.id = pi.owner_id
  left join public.farms fa
    on pi.owner_kind = 'farm' and fa.id = pi.owner_id
  left join public.fields fld
    on pi.owner_kind = 'field' and fld.id = pi.owner_id
  left join public.mines m
    on pi.owner_kind = 'mine' and m.id = pi.owner_id
  where pi.id = p_production_inventory_id
  for update of pi;

  if not found then
    raise exception 'Hedef production envanteri bulunamadi.';
  end if;

  if v_target_inventory.owner_player_id <> v_player_id then
    raise exception 'Hedef production envanteri oyuncuya ait degil.';
  end if;

  if coalesce(v_target_inventory.inventory_type, '') <> 'input' then
    raise exception 'Hedef production envanteri input turunde olmalidir.';
  end if;

  if coalesce(v_target_inventory.product_id, '') <> coalesce(v_source_slot.product_id, '') then
    raise exception 'Production input urunu ile kaynak urun uyusmuyor.';
  end if;

  if coalesce(v_target_inventory.quality_level, 0) <> coalesce(v_source_slot.quality_level, 0) then
    raise exception 'Production input kalitesi ile kaynak kalite uyusmuyor.';
  end if;

  select *
  into v_product
  from public.products
  where id = v_source_slot.product_id;

  if not found then
    raise exception 'Urun bulunamadi.';
  end if;

  if coalesce(v_product.birim_hacim, 0) <= 0 then
    raise exception 'Urun hacim bilgisi gecersiz.';
  end if;

  select coalesce(sum(coalesce(quantity, 0) + coalesce(pending_quantity, 0)), 0)
  into v_used_input_capacity
  from public.production_inventory
  where owner_kind = v_target_inventory.owner_kind
    and owner_id = v_target_inventory.owner_id
    and inventory_type = 'input';

  if v_used_input_capacity + p_quantity > coalesce(v_target_inventory.owner_input_capacity, 0) then
    raise exception 'Hedef production input kapasitesi yetersiz.';
  end if;

  v_item_volume := p_quantity * coalesce(v_product.birim_hacim, 0);
  v_same_city := v_source_slot.city_id = v_target_inventory.owner_city_id;

  if not v_same_city then
    if p_vehicle_id is null then
      raise exception 'Sehirler arasi transfer icin arac secilmelidir.';
    end if;
    v_npc_logistics_player_id := public.get_npc_logistics_player_id();

    select *
    into v_vehicle
    from public.logistics_vehicles
    where id = p_vehicle_id
      and status = 'idle'
      and (
        player_id = v_player_id
        or (
          coalesce(is_available_for_rent, false) = true
          and (
            player_id = v_npc_logistics_player_id
            or public.logistics_vehicle_matches_route(
              route_city_a_id,
              route_city_b_id,
              v_source_slot.city_id,
              v_target_inventory.owner_city_id
            )
          )
        )
      )
    for update;

    if not found then
      raise exception 'Secilen arac kullanima uygun degil.';
    end if;

    if coalesce(v_vehicle.capacity, 0) < ceil(v_item_volume) then
      raise exception 'Secilen aracin kapasitesi bu transfer icin yetersiz.';
    end if;

    if coalesce(v_vehicle.speed_kmh, 0) <= 0 then
      raise exception 'Secilen aracin hizi gecersiz.';
    end if;

    v_distance_km := round(
      sqrt(
        power(
          coalesce((select map_position_x from public.cities where id = v_source_slot.city_id), 0)
          - coalesce((select map_position_x from public.cities where id = v_target_inventory.owner_city_id), 0),
          2
        )
        + power(
          coalesce((select map_position_y from public.cities where id = v_source_slot.city_id), 0)
          - coalesce((select map_position_y from public.cities where id = v_target_inventory.owner_city_id), 0),
          2
        )
      ),
      2
    );

    v_duration_seconds := greatest(60, ceil((greatest(v_distance_km, 1) / v_vehicle.speed_kmh) * 3600)::integer);
    v_finish_at := v_now + make_interval(secs => v_duration_seconds);
    v_fuel_used := round(v_distance_km * coalesce(v_vehicle.fuel_rate, 0), 2);
    v_condition_loss := greatest(1, ceil(v_distance_km / 25.0));
    v_is_rental := v_vehicle.player_id <> v_player_id;
    v_transport_cost := case
      when v_is_rental then round(v_distance_km * coalesce(v_vehicle.rental_price, 0), 2)
      else round(v_fuel_used * coalesce(v_vehicle.fuel_cost, 0), 2)
    end;
    v_rental_cost := case when v_is_rental then v_transport_cost else 0 end;

    if coalesce(v_vehicle.current_fuel, 0) < ceil(v_fuel_used) then
      raise exception 'Aracta yeterli yakit yok.';
    end if;

    if coalesce(v_vehicle.condition, 0) <= 0 then
      raise exception 'Aracin bakimi yetersiz.';
    end if;
  end if;

  insert into public.logistics_transfers (
    buyer_player_id,
    seller_player_id,
    seller_warehouse_id,
    seller_warehouse_slot_id,
    buyer_production_inventory_id,
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
    started_at,
    finish_at,
    completed_at,
    status,
    transfer_type,
    seller_entity_kind,
    buyer_entity_kind,
    item_count,
    total_quantity,
    brand_id,
    created_at,
    updated_at
  ) values (
    v_player_id,
    v_player_id,
    v_source_slot.warehouse_id,
    p_warehouse_slot_id,
    v_target_inventory.id,
    case when v_same_city then null else p_vehicle_id end,
    case when v_same_city then null else v_vehicle.player_id end,
    case when v_same_city then false else v_is_rental end,
    v_source_slot.product_id,
    v_source_slot.quality_level,
    p_quantity,
    case when v_same_city then 0 else v_rental_cost end,
    0,
    greatest(v_item_volume, 0.0001),
    0,
    case when v_same_city then 0 else v_distance_km end,
    case when v_same_city then 0 else v_fuel_used end,
    case when v_same_city then 0 else v_condition_loss end,
    0,
    case when v_same_city then 0 else v_transport_cost end,
    v_now,
    v_finish_at,
    case when v_same_city then v_now else null end,
    case when v_same_city then 'completed' else 'in_transit' end,
    'warehouse_to_production',
    'warehouse',
    'production_inventory',
    1,
    p_quantity,
    coalesce(v_source_slot.brand_id, v_default_brand),
    v_now,
    v_now
  )
  returning id into v_transfer_id;

  insert into public.logistics_transfer_items (
    transfer_id,
    source_warehouse_slot_id,
    target_warehouse_slot_id,
    product_id,
    quality_level,
    brand_id,
    quantity,
    unit_cost,
    unit_price,
    total_cost,
    total_price,
    product_unit_volume,
    reserved_capacity_amount,
    status,
    created_at,
    updated_at,
    completed_at
  ) values (
    v_transfer_id,
    p_warehouse_slot_id,
    null,
    v_source_slot.product_id,
    v_source_slot.quality_level,
    coalesce(v_source_slot.brand_id, v_default_brand),
    p_quantity,
    coalesce(v_source_slot.cost, 0),
    0,
    p_quantity * coalesce(v_source_slot.cost, 0),
    0,
    coalesce(v_product.birim_hacim, 0),
    0,
    case when v_same_city then 'completed' else 'in_transit' end,
    v_now,
    v_now,
    case when v_same_city then v_now else null end
  );

  if not v_same_city then
    update public.logistics_vehicles
    set
      status = 'on_route',
      current_fuel = greatest(current_fuel - ceil(v_fuel_used), 0),
      condition = greatest(condition - ceil(v_condition_loss), 0),
      updated_at = v_now
    where id = v_vehicle.id;

    update public.production_inventory
    set pending_quantity = coalesce(pending_quantity, 0) + p_quantity
    where id = v_target_inventory.id;
  else
    v_total_existing_cost := coalesce(v_target_inventory.quantity, 0) * coalesce(v_target_inventory.cost, 0);
    v_total_incoming_cost := p_quantity * coalesce(v_source_slot.cost, 0);
    v_new_cost := case
      when coalesce(v_target_inventory.quantity, 0) + p_quantity <= 0 then coalesce(v_target_inventory.cost, 0)
      else round((v_total_existing_cost + v_total_incoming_cost) / (coalesce(v_target_inventory.quantity, 0) + p_quantity), 4)
    end;

    update public.production_inventory
    set
      quantity = quantity + p_quantity,
      cost = v_new_cost
    where id = v_target_inventory.id;
  end if;

  update public.warehouse_slots
  set
    quantity = quantity - p_quantity,
    updated_at = v_now
  where id = v_source_slot.id;

  if coalesce(v_source_slot.quantity, 0) - p_quantity <= 0
     and coalesce(v_source_slot.pending_quantity, 0) <= 0 then
    delete from public.warehouse_slots
    where id = v_source_slot.id;
  end if;

  return jsonb_build_object(
    'success', true,
    'mode', case when v_same_city then 'instant' else 'in_transit' end,
    'transfer_id', v_transfer_id,
    'transport_cost', case when v_same_city then 0 else v_transport_cost end,
    'finish_at', v_finish_at,
    'message', case
      when v_same_city then 'Production input transferi aninda tamamlandi.'
      else 'Production input transferi baslatildi.'
    end
  );
end;
$$;

create or replace function public.start_production_to_warehouse_transfer(
  p_production_inventory_id uuid,
  p_buyer_warehouse_id uuid,
  p_quantity integer,
  p_vehicle_id uuid default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_default_brand uuid := '00000000-0000-0000-0000-000000000000'::uuid;
  v_player_id uuid := auth.uid();
  v_npc_logistics_player_id uuid;
  v_now timestamptz := timezone('utc', now());
  v_source_inventory record;
  v_target_warehouse record;
  v_product products%rowtype;
  v_vehicle logistics_vehicles%rowtype;
  v_transfer_id uuid;
  v_same_city boolean := false;
  v_distance_km numeric := 0;
  v_fuel_used numeric := 0;
  v_condition_loss numeric := 0;
  v_transport_cost numeric := 0;
  v_rental_cost numeric := 0;
  v_duration_seconds integer := 0;
  v_finish_at timestamptz := v_now;
  v_item_volume numeric := 0;
  v_target_used_capacity numeric := 0;
  v_is_rental boolean := false;
begin
  if v_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  if p_quantity is null or p_quantity <= 0 then
    raise exception 'Transfer miktari 0 dan buyuk olmalidir.';
  end if;

  select
    pi.*,
    case
      when pi.owner_kind = 'factory' then fx.player_id
      when pi.owner_kind = 'farm' then fa.player_id
      when pi.owner_kind = 'field' then fld.player_id
      when pi.owner_kind = 'mine' then m.player_id
      else null
    end as owner_player_id,
    case
      when pi.owner_kind = 'factory' then fx.city_id
      when pi.owner_kind = 'farm' then fa.city_id
      when pi.owner_kind = 'field' then fld.city_id
      when pi.owner_kind = 'mine' then m.city_id
      else null
    end as owner_city_id
  into v_source_inventory
  from public.production_inventory pi
  left join public.factories fx
    on pi.owner_kind = 'factory' and fx.id = pi.owner_id
  left join public.farms fa
    on pi.owner_kind = 'farm' and fa.id = pi.owner_id
  left join public.fields fld
    on pi.owner_kind = 'field' and fld.id = pi.owner_id
  left join public.mines m
    on pi.owner_kind = 'mine' and m.id = pi.owner_id
  where pi.id = p_production_inventory_id
  for update of pi;

  if not found then
    raise exception 'Kaynak production envanteri bulunamadi.';
  end if;

  if v_source_inventory.owner_player_id <> v_player_id then
    raise exception 'Kaynak production envanteri oyuncuya ait degil.';
  end if;

  if coalesce(v_source_inventory.product_id, '') = '' then
    raise exception 'Kaynak production envanterinde urun bulunamadi.';
  end if;

  if coalesce(v_source_inventory.quantity, 0) < p_quantity then
    raise exception 'Kaynak production envanterinde yeterli stok yok.';
  end if;

  select w.*, c.map_position_x, c.map_position_y
  into v_target_warehouse
  from public.warehouses w
  join public.cities c on c.id = w.city_id
  where w.id = p_buyer_warehouse_id
    and w.player_id = v_player_id
  for update;

  if not found then
    raise exception 'Hedef depo bulunamadi.';
  end if;

  select *
  into v_product
  from public.products
  where id = v_source_inventory.product_id;

  if not found then
    raise exception 'Urun bulunamadi.';
  end if;

  if coalesce(v_product.birim_hacim, 0) <= 0 then
    raise exception 'Urun hacim bilgisi gecersiz.';
  end if;

  v_item_volume := p_quantity * coalesce(v_product.birim_hacim, 0);

  select coalesce(sum((ws.quantity + coalesce(ws.pending_quantity, 0)) * coalesce(p.birim_hacim, 0)), 0)
  into v_target_used_capacity
  from public.warehouse_slots ws
  left join public.products p on p.id = ws.product_id
  where ws.warehouse_id = v_target_warehouse.id;

  if v_target_used_capacity + coalesce(v_target_warehouse.reserved_capacity, 0) + v_item_volume > coalesce(v_target_warehouse.capacity, 0) then
    raise exception 'Hedef depoda yeterli kapasite yok.';
  end if;

  v_same_city := v_source_inventory.owner_city_id = v_target_warehouse.city_id;

  if not v_same_city then
    if p_vehicle_id is null then
      raise exception 'Sehirler arasi transfer icin arac secilmelidir.';
    end if;
    v_npc_logistics_player_id := public.get_npc_logistics_player_id();

    select *
    into v_vehicle
    from public.logistics_vehicles
    where id = p_vehicle_id
      and status = 'idle'
      and (
        player_id = v_player_id
        or (
          coalesce(is_available_for_rent, false) = true
          and (
            player_id = v_npc_logistics_player_id
            or public.logistics_vehicle_matches_route(
              route_city_a_id,
              route_city_b_id,
              v_source_inventory.owner_city_id,
              v_target_warehouse.city_id
            )
          )
        )
      )
    for update;

    if not found then
      raise exception 'Secilen arac kullanima uygun degil.';
    end if;

    if coalesce(v_vehicle.capacity, 0) < ceil(v_item_volume) then
      raise exception 'Secilen aracin kapasitesi bu transfer icin yetersiz.';
    end if;

    if coalesce(v_vehicle.speed_kmh, 0) <= 0 then
      raise exception 'Secilen aracin hizi gecersiz.';
    end if;

    v_distance_km := round(
      sqrt(
        power(
          coalesce((select map_position_x from public.cities where id = v_source_inventory.owner_city_id), 0)
          - coalesce(v_target_warehouse.map_position_x, 0),
          2
        )
        + power(
          coalesce((select map_position_y from public.cities where id = v_source_inventory.owner_city_id), 0)
          - coalesce(v_target_warehouse.map_position_y, 0),
          2
        )
      ),
      2
    );

    v_duration_seconds := greatest(60, ceil((greatest(v_distance_km, 1) / v_vehicle.speed_kmh) * 3600)::integer);
    v_finish_at := v_now + make_interval(secs => v_duration_seconds);
    v_fuel_used := round(v_distance_km * coalesce(v_vehicle.fuel_rate, 0), 2);
    v_condition_loss := greatest(1, ceil(v_distance_km / 25.0));
    v_is_rental := v_vehicle.player_id <> v_player_id;
    v_transport_cost := case
      when v_is_rental then round(v_distance_km * coalesce(v_vehicle.rental_price, 0), 2)
      else round(v_fuel_used * coalesce(v_vehicle.fuel_cost, 0), 2)
    end;
    v_rental_cost := case when v_is_rental then v_transport_cost else 0 end;

    if coalesce(v_vehicle.current_fuel, 0) < ceil(v_fuel_used) then
      raise exception 'Aracta yeterli yakit yok.';
    end if;

    if coalesce(v_vehicle.condition, 0) <= 0 then
      raise exception 'Aracin bakimi yetersiz.';
    end if;
  end if;

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
    started_at,
    finish_at,
    completed_at,
    status,
    transfer_type,
    seller_entity_kind,
    buyer_entity_kind,
    item_count,
    total_quantity,
    brand_id,
    created_at,
    updated_at
  ) values (
    v_player_id,
    v_player_id,
    v_target_warehouse.id,
    p_production_inventory_id,
    case when v_same_city then null else p_vehicle_id end,
    case when v_same_city then null else v_vehicle.player_id end,
    case when v_same_city then false else v_is_rental end,
    v_source_inventory.product_id,
    v_source_inventory.quality_level,
    p_quantity,
    case when v_same_city then 0 else v_rental_cost end,
    0,
    greatest(v_item_volume, 0.0001),
    case when v_same_city then 0 else v_item_volume end,
    case when v_same_city then 0 else v_distance_km end,
    case when v_same_city then 0 else v_fuel_used end,
    case when v_same_city then 0 else v_condition_loss end,
    0,
    case when v_same_city then 0 else v_transport_cost end,
    v_now,
    v_finish_at,
    case when v_same_city then v_now else null end,
    case when v_same_city then 'completed' else 'in_transit' end,
    'production_to_warehouse',
    'production_inventory',
    'warehouse',
    1,
    p_quantity,
    coalesce(v_source_inventory.brand_id, v_default_brand),
    v_now,
    v_now
  )
  returning id into v_transfer_id;

  insert into public.logistics_transfer_items (
    transfer_id,
    source_warehouse_slot_id,
    target_warehouse_slot_id,
    product_id,
    quality_level,
    brand_id,
    quantity,
    unit_cost,
    unit_price,
    total_cost,
    total_price,
    product_unit_volume,
    reserved_capacity_amount,
    status,
    created_at,
    updated_at,
    completed_at
  ) values (
    v_transfer_id,
    null,
    null,
    v_source_inventory.product_id,
    v_source_inventory.quality_level,
    coalesce(v_source_inventory.brand_id, v_default_brand),
    p_quantity,
    coalesce(v_source_inventory.cost, 0),
    0,
    p_quantity * coalesce(v_source_inventory.cost, 0),
    0,
    coalesce(v_product.birim_hacim, 0),
    case when v_same_city then 0 else v_item_volume end,
    case when v_same_city then 'completed' else 'in_transit' end,
    v_now,
    v_now,
    case when v_same_city then v_now else null end
  );

  if not v_same_city then
    update public.logistics_vehicles
    set
      status = 'on_route',
      current_fuel = greatest(current_fuel - ceil(v_fuel_used), 0),
      condition = greatest(condition - ceil(v_condition_loss), 0),
      updated_at = v_now
    where id = v_vehicle.id;

    update public.warehouses
    set
      reserved_capacity = coalesce(reserved_capacity, 0) + v_item_volume,
      updated_at = v_now
    where id = v_target_warehouse.id;
  else
    perform public.add_product_to_warehouse_with_brand(
      v_player_id,
      v_target_warehouse.id,
      v_source_inventory.product_id,
      v_source_inventory.quality_level,
      coalesce(v_source_inventory.brand_id, v_default_brand),
      p_quantity,
      coalesce(v_source_inventory.cost, 0),
      0,
      false,
      null
    );
  end if;

  update public.production_inventory
  set quantity = quantity - p_quantity
  where id = v_source_inventory.id;

  if coalesce(v_source_inventory.quantity, 0) - p_quantity <= 0
     and coalesce(v_source_inventory.pending_quantity, 0) <= 0 then
    delete from public.production_inventory
    where id = v_source_inventory.id;
  end if;

  return jsonb_build_object(
    'success', true,
    'mode', case when v_same_city then 'instant' else 'in_transit' end,
    'transfer_id', v_transfer_id,
    'transport_cost', case when v_same_city then 0 else v_transport_cost end,
    'finish_at', v_finish_at,
    'message', case
      when v_same_city then 'Production cikis transferi aninda tamamlandi.'
      else 'Production cikis transferi baslatildi.'
    end
  );
end;
$$;

create or replace function public.transfer_warehouse_slot_to_production_inventory(
  p_player_id uuid,
  p_warehouse_slot_id uuid,
  p_production_inventory_id uuid,
  p_quantity integer
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Oturum acilmamis.';
  end if;

  if p_player_id is not null and p_player_id <> auth.uid() then
    raise exception 'Oyuncu bilgisi gecersiz.';
  end if;

  return public.start_warehouse_to_production_transfer(
    p_warehouse_slot_id,
    p_production_inventory_id,
    p_quantity,
    null
  );
end;
$$;

create or replace function public.transfer_production_inventory_to_warehouse(
  p_player_id uuid,
  p_production_inventory_id uuid,
  p_warehouse_id uuid,
  p_quantity integer
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Oturum acilmamis.';
  end if;

  if p_player_id is not null and p_player_id <> auth.uid() then
    raise exception 'Oyuncu bilgisi gecersiz.';
  end if;

  return public.start_production_to_warehouse_transfer(
    p_production_inventory_id,
    p_warehouse_id,
    p_quantity,
    null
  );
end;
$$;

create or replace function public.complete_logistics_transfer(
  p_transfer_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_default_brand uuid := '00000000-0000-0000-0000-000000000000'::uuid;
  v_player_id uuid := auth.uid();
  v_now timestamptz := timezone('utc'::text, now());
  v_transfer logistics_transfers%rowtype;
  v_item logistics_transfer_items%rowtype;
  v_target_store_warehouse_id uuid;
  v_result jsonb;
  v_completed_count integer := 0;
  v_item_transport_cost numeric := 0;
  v_target_inventory record;
  v_total_existing_cost numeric := 0;
  v_total_incoming_cost numeric := 0;
  v_new_cost numeric := 0;
begin
  if v_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  select *
  into v_transfer
  from public.logistics_transfers
  where id = p_transfer_id
    and buyer_player_id = v_player_id
  for update;

  if not found then
    raise exception 'Transfer bulunamadi.';
  end if;

  if v_transfer.status <> 'in_transit' then
    raise exception 'Transfer tamamlanabilir durumda degil.';
  end if;

  if coalesce(v_transfer.finish_at, v_now) > v_now then
    raise exception 'Transfer henuz hedefe ulasmadi.';
  end if;

  if coalesce(v_transfer.buyer_entity_kind, '') = 'store' then
    select id
    into v_target_store_warehouse_id
    from public.warehouses
    where store_id = v_transfer.buyer_store_id
      and warehouse_kind = 'store'
      and is_active = true
    order by created_at desc
    limit 1
    for update;

    if not found then
      raise exception 'Hedef magazaya bagli depo bulunamadi.';
    end if;
  elsif coalesce(v_transfer.buyer_entity_kind, '') = 'production_inventory' then
    select
      pi.*,
      case
        when pi.owner_kind = 'factory' then fx.player_id
        when pi.owner_kind = 'farm' then fa.player_id
        when pi.owner_kind = 'field' then fld.player_id
        when pi.owner_kind = 'mine' then m.player_id
        else null
      end as owner_player_id
    into v_target_inventory
    from public.production_inventory pi
    left join public.factories fx
      on pi.owner_kind = 'factory' and fx.id = pi.owner_id
    left join public.farms fa
      on pi.owner_kind = 'farm' and fa.id = pi.owner_id
    left join public.fields fld
      on pi.owner_kind = 'field' and fld.id = pi.owner_id
    left join public.mines m
      on pi.owner_kind = 'mine' and m.id = pi.owner_id
    where pi.id = v_transfer.buyer_production_inventory_id
    for update of pi;

    if not found then
      raise exception 'Hedef production envanteri bulunamadi.';
    end if;

    if v_target_inventory.owner_player_id <> v_player_id then
      raise exception 'Hedef production envanteri oyuncuya ait degil.';
    end if;
  end if;

  for v_item in
    select *
    from public.logistics_transfer_items
    where transfer_id = p_transfer_id
      and status = 'in_transit'
    order by created_at, id
    for update
  loop
    v_item_transport_cost := case
      when coalesce(v_transfer.total_quantity, 0) > 0 then
        round(
          coalesce(v_transfer.transport_cost, 0)
          * (coalesce(v_item.quantity, 0)::numeric / v_transfer.total_quantity::numeric),
          4
        )
      else 0
    end;

    if coalesce(v_transfer.buyer_entity_kind, '') = 'warehouse' then
      v_result := public.add_product_to_warehouse_with_brand(
        v_player_id,
        v_transfer.buyer_warehouse_id,
        v_item.product_id,
        v_item.quality_level,
        coalesce(v_item.brand_id, v_default_brand),
        v_item.quantity,
        v_item.unit_cost,
        v_item_transport_cost,
        true,
        null
      );
    elsif coalesce(v_transfer.buyer_entity_kind, '') = 'store' then
      v_result := public.add_product_to_warehouse_with_brand(
        v_player_id,
        v_target_store_warehouse_id,
        v_item.product_id,
        v_item.quality_level,
        coalesce(v_item.brand_id, v_default_brand),
        v_item.quantity,
        v_item.unit_cost,
        v_item_transport_cost,
        false,
        v_item.target_warehouse_slot_id
      );
    elsif coalesce(v_transfer.buyer_entity_kind, '') = 'production_inventory' then
      if coalesce(v_target_inventory.product_id, '') <> coalesce(v_item.product_id, '') then
        raise exception 'Transfer urunu ile hedef production envanteri uyusmuyor.';
      end if;

      if coalesce(v_target_inventory.quality_level, 0) <> coalesce(v_item.quality_level, 0) then
        raise exception 'Transfer kalitesi ile hedef production envanteri uyusmuyor.';
      end if;

      if coalesce(v_target_inventory.inventory_type, '') <> 'input'
         and coalesce(v_target_inventory.brand_id, v_default_brand) <> coalesce(v_item.brand_id, v_default_brand) then
        raise exception 'Transfer brandi ile hedef production envanteri uyusmuyor.';
      end if;

      v_total_existing_cost := coalesce(v_target_inventory.quantity, 0) * coalesce(v_target_inventory.cost, 0);
      v_total_incoming_cost := (coalesce(v_item.quantity, 0) * coalesce(v_item.unit_cost, 0)) + coalesce(v_item_transport_cost, 0);
      v_new_cost := case
        when coalesce(v_target_inventory.quantity, 0) + coalesce(v_item.quantity, 0) <= 0 then coalesce(v_target_inventory.cost, 0)
        else round(
          (v_total_existing_cost + v_total_incoming_cost)
          / (coalesce(v_target_inventory.quantity, 0) + coalesce(v_item.quantity, 0)),
          4
        )
      end;

      update public.production_inventory
      set
        quantity = quantity + v_item.quantity,
        pending_quantity = greatest(coalesce(pending_quantity, 0) - v_item.quantity, 0),
        cost = v_new_cost
      where id = v_target_inventory.id;

      v_target_inventory.quantity := coalesce(v_target_inventory.quantity, 0) + v_item.quantity;
      v_target_inventory.pending_quantity := greatest(coalesce(v_target_inventory.pending_quantity, 0) - v_item.quantity, 0);
      v_target_inventory.cost := v_new_cost;
    else
      raise exception 'Desteklenmeyen hedef turu: %', v_transfer.buyer_entity_kind;
    end if;

    update public.logistics_transfer_items
    set
      status = 'completed',
      completed_at = v_now,
      updated_at = v_now
    where id = v_item.id;

    v_completed_count := v_completed_count + 1;
  end loop;

  update public.logistics_transfers
  set
    status = 'completed',
    completed_at = v_now,
    updated_at = v_now
  where id = p_transfer_id;

  if v_transfer.logistics_vehicle_id is not null then
    update public.logistics_vehicles
    set
      status = 'idle',
      updated_at = v_now
    where id = v_transfer.logistics_vehicle_id;
  end if;

  return jsonb_build_object(
    'success', true,
    'transfer_id', p_transfer_id,
    'completed_item_count', v_completed_count,
    'completed_at', v_now
  );
end;
$$;

grant execute on function public.start_warehouse_to_production_transfer(uuid, uuid, integer, uuid) to anon, authenticated, service_role;
grant execute on function public.start_production_to_warehouse_transfer(uuid, uuid, integer, uuid) to anon, authenticated, service_role;
grant execute on function public.transfer_warehouse_slot_to_production_inventory(uuid, uuid, uuid, integer) to anon, authenticated, service_role;
grant execute on function public.transfer_production_inventory_to_warehouse(uuid, uuid, uuid, integer) to anon, authenticated, service_role;
grant execute on function public.complete_logistics_transfer(uuid) to anon, authenticated, service_role;
