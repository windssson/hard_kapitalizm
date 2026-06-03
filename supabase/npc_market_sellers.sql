create or replace function public.buy_npc_market_product_to_warehouse(
  p_buyer_warehouse_id uuid,
  p_product_id text,
  p_quantity integer
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_player_id uuid := auth.uid();
  v_player players%rowtype;
  v_warehouse warehouses%rowtype;
  v_product products%rowtype;
  v_unit_price numeric := 0;
  v_total_price numeric := 0;
  v_add_result jsonb;
  v_transfer_id uuid;
  v_now timestamptz := timezone('utc'::text, now());
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

  select * into v_warehouse
  from public.warehouses
  where id = p_buyer_warehouse_id
    and player_id = v_player_id
  for update;

  if not found then
    raise exception 'Alici deposu bulunamadi veya size ait degil.';
  end if;

  if v_warehouse.is_active is not true then
    raise exception 'Alici deposu aktif degil.';
  end if;

  select * into v_product
  from public.products
  where id = p_product_id;

  if not found then
    raise exception 'Urun bulunamadi.';
  end if;

  if coalesce(v_product.birim_hacim, 0) <= 0 then
    raise exception 'Urun hacim bilgisi gecersiz.';
  end if;

  v_unit_price := coalesce(v_product.baz_satis_fiyati, 0) * 1.25;
  if v_unit_price <= 0 then
    raise exception 'Urun baz fiyati gecersiz.';
  end if;

  v_total_price := p_quantity * v_unit_price;
  if coalesce(v_player.cash, 0) < v_total_price then
    raise exception 'Yeterli nakit yok.';
  end if;

  update public.players
  set cash = cash - v_total_price
  where id = v_player_id;

  v_add_result := public.add_product_to_warehouse(
    v_player_id,
    p_buyer_warehouse_id,
    p_product_id,
    1,
    p_quantity,
    v_unit_price,
    0,
    false
  );

  insert into public.logistics_transfers (
    buyer_player_id, seller_player_id, buyer_warehouse_id,
    logistics_vehicle_id, vehicle_owner_player_id, is_rental,
    product_id, quality_level, quantity, unit_price, total_price, product_unit_volume,
    reserved_capacity_amount, distance_km, fuel_used, condition_loss, rental_cost, transport_cost,
    transfer_type, seller_entity_kind, buyer_entity_kind,
    started_at, finish_at, completed_at, status, updated_at
  )
  values (
    v_player_id, v_player_id, p_buyer_warehouse_id,
    null, null, false,
    p_product_id, 1, p_quantity, v_unit_price, v_total_price, v_product.birim_hacim,
    0, 0, 0, 0, 0, 0,
    'market_to_warehouse', 'npc_market', 'warehouse',
    v_now, v_now, v_now, 'completed', v_now
  )
  returning id into v_transfer_id;

  return jsonb_build_object(
    'success', true,
    'mode', 'instant',
    'source', 'npc',
    'transfer_id', v_transfer_id,
    'warehouse_result', v_add_result,
    'product_id', p_product_id,
    'quality_level', 1,
    'quantity', p_quantity,
    'unit_price', v_unit_price,
    'total_price', v_total_price
  );
end;
$$;

grant execute on function public.buy_npc_market_product_to_warehouse(uuid, text, integer) to anon, authenticated, service_role;

create or replace function public.buy_npc_market_product_to_store(
  p_store_slot_id uuid,
  p_product_id text,
  p_quantity integer
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_player_id uuid := auth.uid();
  v_player players%rowtype;
  v_store_slot record;
  v_product products%rowtype;
  v_unit_price numeric := 0;
  v_total_price numeric := 0;
  v_new_cost numeric := 0;
  v_transfer_id uuid;
  v_now timestamptz := timezone('utc'::text, now());
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

  select ss.*, s.player_id, s.id as buyer_store_id, s.is_active as store_is_active
  into v_store_slot
  from public.store_slots ss
  join public.stores s on s.id = ss.store_id
  where ss.id = p_store_slot_id
  for update;

  if not found or v_store_slot.player_id <> v_player_id then
    raise exception 'Magaza slotu bulunamadi veya size ait degil.';
  end if;

  if v_store_slot.store_is_active is not true then
    raise exception 'Magaza aktif degil.';
  end if;

  if v_store_slot.product_id is null or coalesce(v_store_slot.quality_level, 0) = 0 then
    if coalesce(v_store_slot.quantity, 0) > 0 or coalesce(v_store_slot.pending_quantity, 0) > 0 then
      raise exception 'Slotta aktif stok veya rezerve varken urun atanamaz.';
    end if;

    update public.store_slots
    set product_id = p_product_id,
        quality_level = 1,
        updated_at = v_now
    where id = p_store_slot_id;

    v_store_slot.product_id := p_product_id;
    v_store_slot.quality_level := 1;
  elsif v_store_slot.product_id <> p_product_id or v_store_slot.quality_level <> 1 then
    raise exception 'Magaza slotu urun veya kalite uyusmazligi.';
  end if;

  if (
    coalesce(v_store_slot.quantity, 0)
    + coalesce(v_store_slot.pending_quantity, 0)
    + p_quantity
  ) > v_store_slot.capacity then
    raise exception 'Magaza slot kapasitesi yetersiz.';
  end if;

  select * into v_product
  from public.products
  where id = p_product_id;

  if not found then
    raise exception 'Urun bulunamadi.';
  end if;

  if coalesce(v_product.birim_hacim, 0) <= 0 then
    raise exception 'Urun hacim bilgisi gecersiz.';
  end if;

  v_unit_price := coalesce(v_product.baz_satis_fiyati, 0) * 1.25;
  if v_unit_price <= 0 then
    raise exception 'Urun baz fiyati gecersiz.';
  end if;

  v_total_price := p_quantity * v_unit_price;
  if coalesce(v_player.cash, 0) < v_total_price then
    raise exception 'Yeterli nakit yok.';
  end if;

  v_new_cost := case
    when coalesce(v_store_slot.quantity, 0) + p_quantity > 0 then
      (
        coalesce(v_store_slot.quantity, 0) * coalesce(v_store_slot.cost, 0)
        + p_quantity * v_unit_price
      ) / (coalesce(v_store_slot.quantity, 0) + p_quantity)
    else v_unit_price
  end;

  update public.players
  set cash = cash - v_total_price
  where id = v_player_id;

  update public.store_slots
  set quantity = quantity + p_quantity,
      cost = v_new_cost,
      updated_at = v_now
  where id = p_store_slot_id;

  insert into public.logistics_transfers (
    buyer_player_id, seller_player_id, buyer_store_id, buyer_store_slot_id,
    logistics_vehicle_id, vehicle_owner_player_id, is_rental,
    product_id, quality_level, quantity, unit_price, total_price, product_unit_volume,
    reserved_capacity_amount, distance_km, fuel_used, condition_loss, rental_cost, transport_cost,
    transfer_type, seller_entity_kind, buyer_entity_kind,
    started_at, finish_at, completed_at, status, updated_at
  )
  values (
    v_player_id, v_player_id, v_store_slot.buyer_store_id, p_store_slot_id,
    null, null, false,
    p_product_id, 1, p_quantity, v_unit_price, v_total_price, v_product.birim_hacim,
    0, 0, 0, 0, 0, 0,
    'market_to_store', 'npc_market', 'store',
    v_now, v_now, v_now, 'completed', v_now
  )
  returning id into v_transfer_id;

  return jsonb_build_object(
    'success', true,
    'mode', 'instant',
    'source', 'npc',
    'transfer_id', v_transfer_id,
    'store_slot_id', p_store_slot_id,
    'product_id', p_product_id,
    'quality_level', 1,
    'quantity', p_quantity,
    'unit_price', v_unit_price,
    'total_price', v_total_price,
    'new_cost', v_new_cost
  );
end;
$$;

grant execute on function public.buy_npc_market_product_to_store(uuid, text, integer) to anon, authenticated, service_role;
