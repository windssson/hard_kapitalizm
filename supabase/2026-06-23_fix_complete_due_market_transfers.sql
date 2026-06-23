-- Create internal logistics transfer completion function that accepts player_id as a parameter
CREATE OR REPLACE FUNCTION public.complete_logistics_transfer_internal(
  p_transfer_id uuid,
  p_player_id uuid
)
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
BEGIN
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

  if v_transfer.status = 'completed' then
    return jsonb_build_object(
      'success', true,
      'transfer_id', p_transfer_id,
      'completed_item_count', 0,
      'completed_at', coalesce(v_transfer.completed_at, v_now)
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

  return jsonb_build_object(
    'success', true,
    'transfer_id', p_transfer_id,
    'completed_item_count', v_completed_count,
    'completed_at', v_now
  );
END;
$function$;


-- Redefine original complete_logistics_transfer wrapper function
CREATE OR REPLACE FUNCTION public.complete_logistics_transfer(p_transfer_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_player_id uuid := auth.uid();
BEGIN
  if v_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;
  return public.complete_logistics_transfer_internal(p_transfer_id, v_player_id);
END;
$function$;


-- Create complete_due_market_transfers function for the pg_cron job
CREATE OR REPLACE FUNCTION public.complete_due_market_transfers(
  p_player_id uuid,
  p_limit integer DEFAULT 500
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_row record;
  v_completed_count integer := 0;
  v_failed_count integer := 0;
  v_result jsonb;
BEGIN
  FOR v_row IN
    SELECT 
      id, 
      buyer_player_id
    FROM public.logistics_transfers
    WHERE status = 'in_transit'
      AND finish_at <= timezone('utc'::text, now())
      AND (p_player_id IS NULL OR buyer_player_id = p_player_id)
    ORDER BY finish_at ASC
    LIMIT p_limit
    FOR UPDATE SKIP LOCKED
  LOOP
    BEGIN
      v_result := public.complete_logistics_transfer_internal(v_row.id, v_row.buyer_player_id);
      v_completed_count := v_completed_count + 1;
    EXCEPTION WHEN OTHERS THEN
      v_failed_count := v_failed_count + 1;
    END;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'completed_count', v_completed_count,
    'failed_count', v_failed_count
  );
END;
$function$;
