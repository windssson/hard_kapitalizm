-- ============================================================================
-- Migration: Store Actions Patch Payload Enhancement
-- Enhances bulk_update_store_slot_prices and fill_store_shelves RPCs to return
-- detailed slot snapshots for zero-latency client-side patching.
-- ============================================================================

-- 1. ENHANCE bulk_update_store_slot_prices
DROP FUNCTION IF EXISTS public.bulk_update_store_slot_prices(uuid, uuid, integer);
DROP FUNCTION IF EXISTS public.bulk_update_store_slot_prices(uuid, uuid, numeric);

CREATE OR REPLACE FUNCTION public.bulk_update_store_slot_prices(
  p_player_id uuid,
  p_store_id uuid,
  p_markup_percent numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
declare
  v_store record;
  v_slot record;
  v_update_result jsonb;
  v_new_price numeric;
  v_examined_slot_count integer := 0;
  v_updated_slot_count integer := 0;
  v_failed_slot_count integer := 0;
  v_affected_slot_ids uuid[] := '{}'::uuid[];
  v_updated_slots jsonb := '[]'::jsonb;
begin
  if p_markup_percent is null or p_markup_percent < 1 or p_markup_percent > 300 then
    raise exception 'Kar marji 1 ile 300 arasinda olmalidir.';
  end if;

  select s.*
  into v_store
  from public.stores s
  where s.id = p_store_id
  for update;

  if not found then
    raise exception 'Magaza bulunamadi.';
  end if;

  if v_store.player_id <> p_player_id then
    raise exception 'Bu magaza oyuncuya ait degil.';
  end if;

  for v_slot in
    select ss.*
    from public.store_slots ss
    where ss.store_id = p_store_id
      and coalesce(ss.is_active, true) = true
      and coalesce(ss.product_id, '') <> ''
      and coalesce(ss.quality_level, 0) > 0
      and coalesce(ss.cost, 0) > 0
    order by ss.slot_index, ss.id
  loop
    v_examined_slot_count := v_examined_slot_count + 1;
    v_new_price := round(
      (coalesce(v_slot.cost, 0) * (1 + (p_markup_percent / 100.0)))::numeric,
      2
    );

    v_update_result := public.set_store_slot_price(
      p_player_id,
      v_slot.id,
      v_new_price
    );

    if coalesce((v_update_result ->> 'success')::boolean, false) then
      v_updated_slot_count := v_updated_slot_count + 1;
      v_affected_slot_ids := array_append(v_affected_slot_ids, v_slot.id);
      v_updated_slots := v_updated_slots || jsonb_build_object(
        'slot_id', v_slot.id,
        'price', v_new_price
      );
    else
      v_failed_slot_count := v_failed_slot_count + 1;
    end if;
  end loop;

  return jsonb_build_object(
    'success', true,
    'store_id', p_store_id,
    'markup_percent', p_markup_percent,
    'examined_slot_count', v_examined_slot_count,
    'updated_slot_count', v_updated_slot_count,
    'failed_slot_count', v_failed_slot_count,
    'store_slot_ids', coalesce(to_jsonb(v_affected_slot_ids), '[]'::jsonb),
    'updated_slots', v_updated_slots,
    'message', case
      when v_updated_slot_count > 0
        then format('Magaza fiyatlari maliyet +%%%s olarak guncellendi.', p_markup_percent)
      else 'Guncellenecek uygun magaza slotu bulunamadi.'
    end
  );
end;
$$;


-- 2. ENHANCE fill_store_shelves
CREATE OR REPLACE FUNCTION public.fill_store_shelves(
  p_player_id uuid,
  p_store_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
declare
  v_default_brand uuid := '00000000-0000-0000-0000-000000000000'::uuid;
  v_store record;
  v_store_warehouse record;
  v_store_slot record;
  v_source_slot record;
  v_transfer_result jsonb;
  v_available_capacity integer;
  v_transfer_quantity integer;
  v_total_transferred_quantity integer := 0;
  v_filled_slot_count integer := 0;
  v_examined_slot_count integer := 0;
  v_used_source_slot_count integer := 0;
  v_affected_store_slot_ids uuid[] := '{}'::uuid[];
  v_affected_warehouse_slot_ids uuid[] := '{}'::uuid[];
  v_updated_store_slots jsonb := '[]'::jsonb;
  v_updated_warehouse_slots jsonb := '[]'::jsonb;
begin
  select s.*
  into v_store
  from public.stores s
  where s.id = p_store_id
  for update;

  if not found then
    raise exception 'Magaza bulunamadi.';
  end if;

  if v_store.player_id <> p_player_id then
    raise exception 'Bu magaza oyuncuya ait degil.';
  end if;

  select w.*
  into v_store_warehouse
  from public.warehouses w
  where w.store_id = p_store_id
    and w.warehouse_kind = 'store'
    and w.is_active = true
  order by w.created_at desc
  limit 1
  for update;

  if not found then
    raise exception 'Magazaya bagli aktif depo bulunamadi.';
  end if;

  for v_store_slot in
    select ss.*
    from public.store_slots ss
    where ss.store_id = p_store_id
      and coalesce(ss.is_active, true) = true
      and coalesce(ss.product_id, '') <> ''
      and coalesce(ss.quality_level, 0) between 1 and 5
      and greatest(
        coalesce(ss.capacity, 0)
        - coalesce(ss.quantity, 0)
        - coalesce(ss.pending_quantity, 0),
        0
      ) > 0
    order by ss.slot_index, ss.id
  loop
    v_examined_slot_count := v_examined_slot_count + 1;
    v_available_capacity := greatest(
      coalesce(v_store_slot.capacity, 0)
      - coalesce(v_store_slot.quantity, 0)
      - coalesce(v_store_slot.pending_quantity, 0),
      0
    );

    if v_available_capacity <= 0 then
      continue;
    end if;

    for v_source_slot in
      select ws.*
      from public.warehouse_slots ws
      where ws.warehouse_id = v_store_warehouse.id
        and ws.product_id = v_store_slot.product_id
        and ws.quality_level = v_store_slot.quality_level
        and coalesce(ws.brand_id, v_default_brand) = coalesce(v_store_slot.brand_id, v_default_brand)
        and coalesce(ws.quantity, 0) > 0
      order by ws.slot_index, ws.id
    loop
      exit when v_available_capacity <= 0;

      v_transfer_quantity := least(v_available_capacity, coalesce(v_source_slot.quantity, 0));
      if v_transfer_quantity <= 0 then
        continue;
      end if;

      v_transfer_result := public.transfer_store_warehouse_slot_to_store_slot(
        p_player_id,
        v_source_slot.id,
        v_store_slot.id,
        v_transfer_quantity
      );

      if coalesce((v_transfer_result ->> 'success')::boolean, false) then
        v_total_transferred_quantity := v_total_transferred_quantity + v_transfer_quantity;
        v_available_capacity := v_available_capacity - v_transfer_quantity;
        v_used_source_slot_count := v_used_source_slot_count + 1;

        if not (v_store_slot.id = any(v_affected_store_slot_ids)) then
          v_affected_store_slot_ids := array_append(v_affected_store_slot_ids, v_store_slot.id);
          v_filled_slot_count := v_filled_slot_count + 1;
        end if;

        if not (v_source_slot.id = any(v_affected_warehouse_slot_ids)) then
          v_affected_warehouse_slot_ids := array_append(v_affected_warehouse_slot_ids, v_source_slot.id);
        end if;
      end if;
    end loop;
  end loop;

  -- Build detailed updated slot snapshots for in-memory client patching
  if array_length(v_affected_store_slot_ids, 1) > 0 then
    select coalesce(jsonb_agg(jsonb_build_object(
      'id', ss.id,
      'quantity', ss.quantity,
      'cost', ss.cost
    )), '[]'::jsonb)
    into v_updated_store_slots
    from public.store_slots ss
    where ss.id = any(v_affected_store_slot_ids);
  end if;

  if array_length(v_affected_warehouse_slot_ids, 1) > 0 then
    select coalesce(jsonb_agg(jsonb_build_object(
      'id', ws.id,
      'quantity', ws.quantity,
      'cost', ws.cost
    )), '[]'::jsonb)
    into v_updated_warehouse_slots
    from public.warehouse_slots ws
    where ws.id = any(v_affected_warehouse_slot_ids);
  end if;

  return jsonb_build_object(
    'success', true,
    'store_id', p_store_id,
    'warehouse_id', v_store_warehouse.id,
    'examined_slot_count', v_examined_slot_count,
    'filled_slot_count', v_filled_slot_count,
    'used_source_slot_count', v_used_source_slot_count,
    'transferred_quantity', v_total_transferred_quantity,
    'store_slot_ids', coalesce(to_jsonb(v_affected_store_slot_ids), '[]'::jsonb),
    'warehouse_slot_ids', coalesce(to_jsonb(v_affected_warehouse_slot_ids), '[]'::jsonb),
    'updated_store_slots', v_updated_store_slots,
    'updated_warehouse_slots', v_updated_warehouse_slots,
    'message', case
      when v_total_transferred_quantity > 0 then 'Magaza raflari depodan dolduruldu.'
      else 'Doldurulacak uygun depo stogu bulunamadi.'
    end
  );
end;
$$;
