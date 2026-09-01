-- =========================================================================================
-- MIGRATION: 2026-09-01_wire_core_game_events_to_notifications.sql
-- Temel Oyun Olaylarını Bildirim Sistemine Bağlama:
-- 1. complete_logistics_transfer_internal -> Lojistik/Sevkiyat varış bildirimi
-- 2. complete_building_upgrade -> Bina yükseltme tamamlanma bildirimi
-- 3. start_multi_market_transfer -> Pazar satışı gerçekleştiğinde satıcıya anlık bildirim
-- =========================================================================================

-- 1. Sevkiyat / Lojistik Tamamlanma Bildirimi
CREATE OR REPLACE FUNCTION public.complete_logistics_transfer_internal(p_transfer_id uuid, p_player_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_default_brand uuid := '00000000-0000-0000-0000-000000000000'::uuid;
  v_player_id uuid := p_player_id;
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
  v_transfer_exp integer := 0;
BEGIN
  if v_player_id is null then
    raise exception 'Oturum acilmamis.'; end if;

  select *
  into v_transfer
  from public.logistics_transfers
  where id = p_transfer_id
    and buyer_player_id = v_player_id
  for update;

  if not found then
    raise exception 'Transfer bulunamadi.';
  end if;

  if v_transfer.status = 'completed' then
    return jsonb_build_object(
      'success', true,
      'transfer_id', p_transfer_id,
      'completed_item_count', 0,
      'completed_at', coalesce(v_transfer.completed_at, v_now),
      'changed', jsonb_build_object(
        'player', public.get_player_profile(v_player_id)
      )
    );
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
      when coalesce(v_transfer.reserved_capacity_amount, 0) > 0
        and coalesce(v_item.reserved_capacity_amount, 0) > 0 then
        round(
          coalesce(v_transfer.transport_cost, 0)
          * (
            coalesce(v_item.reserved_capacity_amount, 0)
            / v_transfer.reserved_capacity_amount
          ),
          4
        )
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
      where pi.id = coalesce(
        v_item.target_production_inventory_id,
        v_transfer.buyer_production_inventory_id
      )
      for update of pi;

      if not found then
        raise exception 'Hedef production envanteri bulunamadi.';
      end if;

      if v_target_inventory.owner_player_id <> v_player_id then
        raise exception 'Hedef production envanteri oyuncuya ait degil.';
      end if;

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

  -- Transfer Tamamlanma XP Ödülü
  v_transfer_exp := greatest(10, least(80, 10 + floor(coalesce(v_transfer.total_quantity, 0)::numeric / 10)::integer));
  perform public.grant_player_experience(
    v_player_id,
    v_transfer_exp,
    'logistics_transfer_completed',
    jsonb_build_object(
      'transfer_id', p_transfer_id,
      'total_quantity', v_transfer.total_quantity
    )
  );

  -- Bildirim gönder (Oyun İçi + Push)
  PERFORM public.send_game_notification(
    v_player_id,
    'Sevkiyat Ulaştı',
    coalesce(v_transfer.total_quantity, 0)::text || ' adet ürün hedefe başarıyla teslim edildi.',
    'logistics',
    'transfer',
    p_transfer_id,
    true
  );

  return jsonb_build_object(
    'success', true,
    'transfer_id', p_transfer_id,
    'completed_item_count', v_completed_count,
    'exp_gained', v_transfer_exp,
    'completed_at', v_now,
    'changed', jsonb_build_object(
      'player', public.get_player_profile(v_player_id)
    )
  );
END;
$function$;

-- 2. Bina Yükseltmesi Tamamlanma Bildirimi
CREATE OR REPLACE FUNCTION public.complete_building_upgrade(p_player_id uuid, p_upgrade_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_now timestamptz := timezone('utc', now());
  v_upgrade public.building_upgrades%rowtype;
  v_slot_capacity_increase integer := 0;
  v_max_slot_increase integer := 0;
  v_input_capacity_increase integer := 0;
  v_output_capacity_increase integer := 0;
  v_capacity_increase numeric := 0;
  v_exp_result jsonb;
  v_building_name text;
begin
  select * into v_upgrade from public.building_upgrades
  where id = p_upgrade_id and player_id = p_player_id for update;
  if not found then raise exception 'Yukseltme bulunamadi.'; end if;
  if v_upgrade.status <> 'in_progress' then raise exception 'Bu yukseltme tamamlanabilir durumda degil.'; end if;
  if v_upgrade.finish_at > v_now then raise exception 'Yukseltme henuz bitmedi.'; end if;

  if v_upgrade.building_kind = 'store' then
    v_building_name := 'Mağaza';
    v_slot_capacity_increase := coalesce((v_upgrade.params->>'slot_capacity_increase')::integer, 0);
    v_max_slot_increase := coalesce((v_upgrade.params->>'max_slot_increase')::integer, 0);
    update public.stores set level=v_upgrade.target_level,
      slot_capacity=slot_capacity+v_slot_capacity_increase,
      max_slot_count=max_slot_count+v_max_slot_increase, updated_at=v_now
    where id=v_upgrade.entity_id and player_id=p_player_id;
    update public.store_slots set capacity=capacity+v_slot_capacity_increase, updated_at=v_now
    where store_id=v_upgrade.entity_id;
  elsif v_upgrade.building_kind = 'warehouse' then
    v_building_name := 'Depo';
    v_capacity_increase := coalesce((v_upgrade.params->>'capacity_increase')::numeric, 0);
    update public.warehouses set level=v_upgrade.target_level,
      capacity=capacity+v_capacity_increase, updated_at=v_now
    where id=v_upgrade.entity_id and player_id=p_player_id;
  elsif v_upgrade.building_kind = 'field' then
    v_building_name := 'Tarla';
    v_input_capacity_increase := coalesce((v_upgrade.params->>'input_capacity_increase')::integer, 0);
    v_output_capacity_increase := coalesce((v_upgrade.params->>'output_capacity_increase')::integer, 0);
    update public.fields set level=v_upgrade.target_level,
      input_capacity=input_capacity+v_input_capacity_increase,
      output_capacity=output_capacity+v_output_capacity_increase, updated_at=v_now
    where id=v_upgrade.entity_id and player_id=p_player_id;
  elsif v_upgrade.building_kind = 'farm' then
    v_building_name := 'Çiftlik';
    v_input_capacity_increase := coalesce((v_upgrade.params->>'input_capacity_increase')::integer, 0);
    v_output_capacity_increase := coalesce((v_upgrade.params->>'output_capacity_increase')::integer, 0);
    update public.farms set level=v_upgrade.target_level,
      input_capacity=input_capacity+v_input_capacity_increase,
      output_capacity=output_capacity+v_output_capacity_increase, updated_at=v_now
    where id=v_upgrade.entity_id and player_id=p_player_id;
  elsif v_upgrade.building_kind = 'factory' then
    v_building_name := 'Fabrika';
    v_input_capacity_increase := coalesce((v_upgrade.params->>'input_capacity_increase')::integer, 0);
    v_output_capacity_increase := coalesce((v_upgrade.params->>'output_capacity_increase')::integer, 0);
    update public.factories set level=v_upgrade.target_level,
      input_capacity=input_capacity+v_input_capacity_increase,
      output_capacity=output_capacity+v_output_capacity_increase, updated_at=v_now
    where id=v_upgrade.entity_id and player_id=p_player_id;
  elsif v_upgrade.building_kind = 'mine' then
    v_building_name := 'Maden';
    v_output_capacity_increase := coalesce((v_upgrade.params->>'output_capacity_increase')::integer, 0);
    update public.mines set level=v_upgrade.target_level,
      output_capacity=output_capacity+v_output_capacity_increase, updated_at=v_now
    where id=v_upgrade.entity_id and player_id=p_player_id;
  elsif v_upgrade.building_kind = 'arge_center' then
    v_building_name := 'Ar-Ge Merkezi';
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

  -- Bildirim gönder (Oyun İçi + Push)
  PERFORM public.send_game_notification(
    p_player_id,
    'Yükseltme Tamamlandı',
    coalesce(v_building_name, 'Bina') || ' Seviye ' || v_upgrade.target_level::text || ' oldu!',
    'building',
    'building_upgrade',
    v_upgrade.entity_id,
    true
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
$function$;

-- 3. Market Satışı Yapıldığında Satıcıya Bildirim Gönder
CREATE OR REPLACE FUNCTION public.start_multi_market_transfer(p_buyer_warehouse_id uuid, p_source_city_id uuid, p_items jsonb, p_vehicle_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_default_brand uuid := '00000000-0000-0000-0000-000000000000'::uuid;
  v_player_id uuid := auth.uid();
  v_npc_logistics_player_id uuid;
  v_now timestamptz := timezone('utc', now());
  v_target_warehouse record;
  v_source_city public.cities;
  v_vehicle public.logistics_vehicles;
  v_transfer_id uuid;
  v_header_item jsonb;
  v_header_slot record;
  v_header_product public.products;
  v_header_source_kind text;
  v_header_product_id text;
  v_header_quality_level integer;
  v_header_brand_id uuid;
  v_header_seller_player_id uuid;
  v_header_seller_warehouse_id uuid;
  v_item jsonb;
  v_seller_slot record;
  v_seller_slot_id uuid;
  v_product public.products;
  v_item_source_kind text;
  v_item_product_id text;
  v_item_quality_level integer := 1;
  v_item_brand_id uuid;
  v_item_unit_price numeric := 0;
  v_item_unit_cost numeric := 0;
  v_item_unit_volume numeric := 0;
  v_item_city_id uuid;
  v_item_quantity integer := 0;
  v_item_reserved_capacity numeric := 0;
  v_target_used_capacity numeric := 0;
  v_total_volume numeric := 0;
  v_total_quantity integer := 0;
  v_total_price numeric := 0;
  v_distance_km numeric := 0;
  v_fuel_used numeric := 0;
  v_condition_loss numeric := 0;
  v_transport_cost numeric := 0;
  v_rental_cost numeric := 0;
  v_duration_seconds integer := 0;
  v_finish_at timestamptz := v_now;
  v_item_count integer := 0;
  v_same_city boolean := false;
  v_mode text := 'instant';
  v_is_rental boolean := false;
  v_buyer_cash numeric := 0;
  v_total_payment numeric := 0;
  v_buyer_name text := 'Bir Oyuncu';
  v_seller_rec record;
begin
  if v_player_id is null then raise exception 'Oturum acilmamis.'; end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'Transfer sepeti bos olamaz.';
  end if;

  v_npc_logistics_player_id := public.get_npc_logistics_player_id();

  select coalesce(p.company_name, p.player_name, 'Bir Oyuncu')
  into v_buyer_name
  from public.players p where p.id = v_player_id;

  CREATE TEMP TABLE temp_seller_totals ON COMMIT DROP AS
  select
    case when coalesce(v_item.value ->> 'source_kind', 'warehouse_slot') = 'npc_market' then v_npc_logistics_player_id
         else w.player_id end as seller_player_id,
    sum(
      greatest(coalesce((v_item.value ->> 'quantity')::integer, 0), 0)
      * greatest(coalesce(case when coalesce(v_item.value ->> 'source_kind', 'warehouse_slot') = 'npc_market'
          then (v_item.value ->> 'unit_price')::numeric else ws.price end, 0), 0)
    ) as seller_amount
  from jsonb_array_elements(p_items) v_item(value)
  left join public.warehouse_slots ws
    on coalesce(v_item.value ->> 'source_kind', 'warehouse_slot') <> 'npc_market'
   and ws.id = (case when coalesce(v_item.value ->> 'source_kind', 'warehouse_slot') = 'npc_market' then null
                     else nullif(v_item.value ->> 'seller_slot_id', '')::uuid end)
  left join public.warehouses w on w.id = ws.warehouse_id
  group by 1;

  select w.*, c.map_position_x, c.map_position_y
  into v_target_warehouse
  from public.warehouses w join public.cities c on c.id = w.city_id
  where w.id = p_buyer_warehouse_id and w.player_id = v_player_id and w.is_active = true
  for update;
  if not found then raise exception 'Hedef depo bulunamadi.'; end if;

  v_header_item := p_items -> 0;
  v_header_source_kind := coalesce(v_header_item ->> 'source_kind', 'warehouse_slot');

  if v_header_source_kind = 'npc_market' then
    v_header_product_id := coalesce(v_header_item ->> 'product_id', '');
    v_header_quality_level := greatest(coalesce((v_header_item ->> 'quality_level')::integer, 1), 1);
    v_header_brand_id := coalesce(nullif(v_header_item ->> 'brand_id', '')::uuid, v_default_brand);
    v_header_seller_player_id := v_npc_logistics_player_id;
    v_header_seller_warehouse_id := null;
    if coalesce(v_header_item ->> 'city_id', '') <> p_source_city_id::text then
      raise exception 'Transfer sehir kilidi ilk secilen sehir ile eslesmiyor.';
    end if;
    select * into v_header_product from public.products where id = v_header_product_id;
    if not found then raise exception 'Ilk NPC ilan urunu bulunamadi.'; end if;
  else
    select ws.*, w.id as seller_warehouse_id, w.name as seller_warehouse_name,
           w.player_id as seller_player_id, w.city_id, c.map_position_x, c.map_position_y
    into v_header_slot
    from public.warehouse_slots ws join public.warehouses w on w.id = ws.warehouse_id join public.cities c on c.id = w.city_id
    where ws.id = (v_header_item ->> 'seller_slot_id')::uuid for update;
    if not found then raise exception 'Ilk satici slotu bulunamadi.'; end if;
    if v_header_slot.seller_player_id = v_player_id then raise exception 'Kendi market ilaninizi satin alamazsiniz.'; end if;
    if v_header_slot.city_id <> p_source_city_id then raise exception 'Transfer sehir kilidi ilk secilen sehir ile eslesmiyor.'; end if;
    if coalesce(v_header_slot.product_id, '') = '' then raise exception 'Ilk ilanda urun bulunamadi.'; end if;
    select * into v_header_product from public.products where id = v_header_slot.product_id;
    if not found then raise exception 'Ilk ilan urunu bulunamadi.'; end if;
    v_header_product_id := v_header_slot.product_id;
    v_header_quality_level := greatest(coalesce(v_header_slot.quality_level, 1), 1);
    v_header_brand_id := coalesce(v_header_slot.brand_id, v_default_brand);
    v_header_seller_player_id := v_header_slot.seller_player_id;
    v_header_seller_warehouse_id := v_header_slot.seller_warehouse_id;
  end if;

  select * into v_source_city from public.cities where id = p_source_city_id;
  if not found then raise exception 'Kaynak sehir bulunamadi.'; end if;

  v_same_city := v_target_warehouse.city_id = p_source_city_id;
  if not v_same_city then v_mode := 'in_transit'; end if;

  insert into public.logistics_transfers (
    buyer_player_id, seller_player_id, buyer_warehouse_id, seller_warehouse_id,
    logistics_vehicle_id, vehicle_owner_player_id, is_rental, product_id, quality_level, quantity,
    unit_price, total_price, product_unit_volume, reserved_capacity_amount, distance_km,
    fuel_used, condition_loss, rental_cost, transport_cost, started_at, finish_at, status,
    transfer_type, seller_entity_kind, buyer_entity_kind, item_count, total_quantity, brand_id, created_at, updated_at
  ) values (
    v_player_id, v_header_seller_player_id, v_target_warehouse.id, v_header_seller_warehouse_id,
    p_vehicle_id, null, false, v_header_product_id, v_header_quality_level, 1,
    0, 0, 1, 0, 0, 0, 0, 0, 0, v_now, v_now, 'in_transit',
    'market_to_warehouse_multi',
    case when v_header_source_kind = 'npc_market' then 'npc_market' else 'warehouse' end,
    'warehouse', 1, 0, v_header_brand_id, v_now, v_now
  ) returning id into v_transfer_id;

  select coalesce(sum((ws.quantity + coalesce(ws.pending_quantity, 0)) * coalesce(p.birim_hacim, 0)), 0)
  into v_target_used_capacity
  from public.warehouse_slots ws left join public.products p on p.id = ws.product_id
  where ws.warehouse_id = v_target_warehouse.id;

  for v_item in select value from jsonb_array_elements(p_items) loop
    v_seller_slot_id := null;
    v_item_quantity := greatest(coalesce((v_item ->> 'quantity')::integer, 0), 0);
    if v_item_quantity <= 0 then raise exception 'Transfer miktari 0 dan buyuk olmalidir.'; end if;
    v_item_source_kind := coalesce(v_item ->> 'source_kind', 'warehouse_slot');
    v_item_city_id := nullif(v_item ->> 'city_id', '')::uuid;
    if v_item_city_id is null or v_item_city_id <> p_source_city_id then
      raise exception 'Sepetteki tum ilanlar ayni sehirde olmalidir.';
    end if;

    if v_item_source_kind = 'npc_market' then
      v_item_product_id := coalesce(v_item ->> 'product_id', '');
      v_item_quality_level := greatest(coalesce((v_item ->> 'quality_level')::integer, 1), 1);
      v_item_brand_id := coalesce(nullif(v_item ->> 'brand_id', '')::uuid, v_default_brand);
      v_item_unit_price := greatest(coalesce((v_item ->> 'unit_price')::numeric, 0), 0);
      v_item_unit_cost := v_item_unit_price;
      select * into v_product from public.products where id = v_item_product_id;
      if not found then raise exception 'NPC urunu bulunamadi.'; end if;
      v_item_unit_volume := coalesce((v_item ->> 'unit_volume')::numeric, coalesce(v_product.birim_hacim, 0));
      v_item_reserved_capacity := v_item_quantity * v_item_unit_volume;
    else
      select ws.*, w.id as seller_warehouse_id, w.name as seller_warehouse_name, w.player_id as seller_player_id, w.city_id
      into v_seller_slot
      from public.warehouse_slots ws join public.warehouses w on w.id = ws.warehouse_id
      where ws.id = (v_item ->> 'seller_slot_id')::uuid for update;
      if not found then raise exception 'Satici slotu bulunamadi.'; end if;
      if v_seller_slot.seller_player_id = v_player_id then raise exception 'Kendi market ilaninizi satin alamazsiniz.'; end if;
      if v_seller_slot.city_id <> p_source_city_id then raise exception 'Sepetteki tum ilanlar ayni sehirde olmalidir.'; end if;
      if coalesce(v_seller_slot.is_available_for_sale, false) = false or coalesce(v_seller_slot.price, 0) <= 0 then
        raise exception 'Secilen slot satisa uygun degil.';
      end if;
      if coalesce(v_seller_slot.quantity, 0) < v_item_quantity then raise exception 'Satici stokunda yeterli urun yok.'; end if;
      select * into v_product from public.products where id = v_seller_slot.product_id;
      if not found then raise exception 'Urun bulunamadi.'; end if;
      v_item_product_id := v_seller_slot.product_id;
      v_item_quality_level := v_seller_slot.quality_level;
      v_item_brand_id := coalesce(v_seller_slot.brand_id, v_default_brand);
      v_item_unit_price := coalesce(v_seller_slot.price, 0);
      v_item_unit_cost := v_item_unit_price;
      v_item_unit_volume := coalesce(v_product.birim_hacim, 0);
      v_item_reserved_capacity := v_item_quantity * v_item_unit_volume;
    end if;

    if v_target_used_capacity + coalesce(v_target_warehouse.reserved_capacity, 0) + v_total_volume + v_item_reserved_capacity > coalesce(v_target_warehouse.capacity, 0) then
      raise exception 'Hedef depoda yeterli kapasite yok.';
    end if;

    insert into public.logistics_transfer_items (
      transfer_id, source_warehouse_slot_id, target_warehouse_slot_id, product_id, quality_level, brand_id,
      quantity, unit_cost, unit_price, total_cost, total_price, product_unit_volume, reserved_capacity_amount,
      status, created_at, updated_at
    ) values (
      v_transfer_id, v_seller_slot_id, null, v_item_product_id, v_item_quality_level, v_item_brand_id,
      v_item_quantity, v_item_unit_cost, v_item_unit_price,
      v_item_quantity * v_item_unit_cost, v_item_quantity * v_item_unit_price,
      v_item_unit_volume, v_item_reserved_capacity, 'in_transit', v_now, v_now
    );

    if v_item_source_kind <> 'npc_market' then
      update public.warehouse_slots set quantity = quantity - v_item_quantity, updated_at = v_now where id = v_seller_slot_id;
      if coalesce(v_seller_slot.quantity, 0) - v_item_quantity <= 0 and coalesce(v_seller_slot.pending_quantity, 0) <= 0 then
        delete from public.warehouse_slots where id = v_seller_slot_id;
      end if;
    end if;

    v_item_count := v_item_count + 1;
    v_total_quantity := v_total_quantity + v_item_quantity;
    v_total_volume := v_total_volume + v_item_reserved_capacity;
    v_total_price := v_total_price + (v_item_quantity * v_item_unit_price);
  end loop;

  if v_item_count <= 0 then raise exception 'Transfer icin kalem bulunamadi.'; end if;

  if not v_same_city then
    if p_vehicle_id is null then raise exception 'Sehirler arasi transfer icin arac secilmelidir.'; end if;
    select * into v_vehicle
    from public.logistics_vehicles
    where id = p_vehicle_id 
      and (player_id = v_player_id or (coalesce(is_available_for_rent, false) = true and (player_id = v_npc_logistics_player_id or public.logistics_vehicle_matches_route(route_city_a_id, route_city_b_id, p_source_city_id, v_target_warehouse.city_id))))
      and status = 'idle'
    for update;
    if not found then raise exception 'Secilen arac kullanima uygun degil.'; end if;
    v_distance_km := round(
      (6371 * 2 * asin(sqrt(power(sin(radians(coalesce(v_target_warehouse.map_position_x, 0) - coalesce(v_source_city.map_position_x, 0)) / 2), 2) + cos(radians(coalesce(v_source_city.map_position_x, 0))) * cos(radians(coalesce(v_target_warehouse.map_position_x, 0))) * power(sin(radians(coalesce(v_target_warehouse.map_position_y, 0) - coalesce(v_source_city.map_position_y, 0)) / 2), 2))))::numeric, 2
    );
    if coalesce(v_vehicle.capacity, 0) < ceil(v_total_volume) then raise exception 'Secilen aracin kapasitesi bu transfer icin yetersiz.'; end if;
    if coalesce(v_vehicle.speed_kmh, 0) <= 0 then raise exception 'Secilen aracin hizi gecersiz.'; end if;
    v_is_rental := v_vehicle.player_id <> v_player_id;
    v_duration_seconds := greatest(60, ceil((greatest(v_distance_km, 1) / v_vehicle.speed_kmh) * 120)::integer);
    v_finish_at := v_now + make_interval(secs => v_duration_seconds);
    v_fuel_used := round(v_distance_km * coalesce(v_vehicle.fuel_rate, 0), 2);
    v_condition_loss := greatest(1, ceil(v_distance_km / 200.0));
    v_transport_cost := case when v_is_rental then round(v_distance_km * coalesce(v_vehicle.rental_price, 0), 2) else round(v_fuel_used * coalesce(v_vehicle.fuel_cost, 0), 2) end;
    v_rental_cost := case when v_is_rental then v_transport_cost else 0 end;
    if coalesce(v_vehicle.current_fuel, 0) < ceil(v_fuel_used) then raise exception 'Aracta yeterli yakit yok.'; end if;
    if coalesce(v_vehicle.condition, 0) <= 0 then raise exception 'Aracin bakimi yetersiz.'; end if;
    update public.logistics_vehicles
    set status = 'on_route', current_fuel = greatest(current_fuel - ceil(v_fuel_used), 0),
        condition = greatest(condition - ceil(v_condition_loss), 0), updated_at = v_now
    where id = v_vehicle.id;
  end if;

  v_total_payment := v_total_price + v_rental_cost;

  select cash into v_buyer_cash from public.players where id = v_player_id for update;
  if coalesce(v_buyer_cash, 0) < v_total_payment then raise exception 'Yeterli nakit yok.'; end if;

  update public.players set cash = cash - v_total_payment where id = v_player_id;
  perform public.log_player_cash_change(
    v_player_id, -v_total_payment, v_buyer_cash, 'market_purchase',
    format('Pazar alimi: %s kalem, %s adet (nakliye: %s TL)', v_item_count, v_total_quantity, round(v_rental_cost + v_transport_cost, 0)),
    v_transfer_id, 'logistics_transfer'
  );

  update public.players p
  set cash = cash + st.seller_amount
  from temp_seller_totals st
  where p.id = st.seller_player_id and st.seller_player_id is not null and coalesce(st.seller_amount, 0) > 0;

  perform public.log_player_cash_change(
    st.seller_player_id, st.seller_amount,
    (select cash - st.seller_amount from public.players where id = st.seller_player_id),
    'market_sale', format('Pazar satisi: %s TL', round(st.seller_amount, 0)), v_transfer_id, 'logistics_transfer'
  )
  from temp_seller_totals st
  where st.seller_player_id is not null and st.seller_player_id <> v_npc_logistics_player_id and coalesce(st.seller_amount, 0) > 0;

  -- Satıcılara bildirim gönder (Oyun İçi + Push)
  FOR v_seller_rec IN
    SELECT seller_player_id, seller_amount
    FROM temp_seller_totals
    WHERE seller_player_id IS NOT NULL 
      AND seller_player_id <> v_npc_logistics_player_id 
      AND coalesce(seller_amount, 0) > 0
  LOOP
    PERFORM public.send_game_notification(
      v_seller_rec.seller_player_id,
      'Pazar Satışı Yapıldı!',
      v_buyer_name || ' pazarınızdan alışveriş yaptı. Gelir: ' || round(v_seller_rec.seller_amount, 0)::text || ' TL',
      'trade',
      'market',
      v_transfer_id,
      true
    );
  END LOOP;

  if v_is_rental and v_rental_cost > 0 then
    perform public.process_logistics_vehicle_rental_payout(p_vehicle_id, v_transfer_id, v_player_id, v_rental_cost, v_distance_km);
  end if;

  update public.warehouses set reserved_capacity = coalesce(reserved_capacity, 0) + v_total_volume, updated_at = v_now where id = v_target_warehouse.id;

  update public.logistics_transfers
  set logistics_vehicle_id = p_vehicle_id,
      vehicle_owner_player_id = case when p_vehicle_id is not null then v_vehicle.player_id else null end,
      is_rental = v_is_rental, quantity = greatest(v_total_quantity, 1), total_price = v_total_price,
      product_unit_volume = greatest(v_total_volume, 0.0001), reserved_capacity_amount = v_total_volume,
      distance_km = v_distance_km, fuel_used = v_fuel_used, condition_loss = v_condition_loss,
      rental_cost = v_rental_cost, transport_cost = v_transport_cost, finish_at = v_finish_at,
      item_count = v_item_count, total_quantity = v_total_quantity, updated_at = v_now
  where id = v_transfer_id;

  if v_same_city then perform public.complete_logistics_transfer(v_transfer_id); end if;

  return jsonb_build_object(
    'success', true, 'transfer_id', v_transfer_id, 'mode', v_mode, 'item_count', v_item_count, 'total_quantity', v_total_quantity,
    'reserved_capacity_amount', v_total_volume, 'transport_cost', v_transport_cost, 'finish_at', v_finish_at,
    'changed', jsonb_build_object('player', public.get_player_profile(v_player_id))
  );
end;
$function$;
