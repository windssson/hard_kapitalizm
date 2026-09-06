-- ============================================================================
-- Migration: 2026-09-04_fix_fill_store_shelves_patch_payload.sql
-- Description: fill_store_shelves RPC'sinin frontend client patch ve
--              merkezi MutationSyncService mimarisi ile tam uyumlu çalışması için
--              updated_store_slots, updated_warehouse_slots ve changed bloğunu
--              eksiksiz dönmesini sağlar.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fill_store_shelves(
  p_player_id uuid,
  p_store_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_default_brand uuid := '00000000-0000-0000-0000-000000000000'::uuid;
  v_store record;
  v_general_warehouse record;
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
BEGIN
  SELECT s.*
  INTO v_store
  FROM public.stores s
  WHERE s.id = p_store_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Magaza bulunamadi.';
  END IF;

  IF v_store.player_id <> p_player_id THEN
    RAISE EXCEPTION 'Bu magaza oyuncuya ait degil.';
  END IF;

  -- Bu şehirdeki aktif Genel Depo'yu bul
  SELECT w.*
  INTO v_general_warehouse
  FROM public.warehouses w
  WHERE w.player_id = p_player_id
    AND w.city_id = v_store.city_id
    AND (w.warehouse_kind IS NULL OR w.warehouse_kind IN ('general', 'normal'))
    AND w.is_active = true
  ORDER BY w.created_at ASC
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Bu sehirde aktif bir Genel Depo bulunamadi.';
  END IF;

  FOR v_store_slot IN
    SELECT ss.*
    FROM public.store_slots ss
    WHERE ss.store_id = p_store_id
      AND coalesce(ss.is_active, true) = true
      AND coalesce(ss.product_id, '') <> ''
      AND coalesce(ss.quality_level, 0) BETWEEN 1 AND 5
      AND greatest(
        coalesce(ss.capacity, 0)
        - coalesce(ss.quantity, 0)
        - coalesce(ss.pending_quantity, 0),
        0
      ) > 0
    ORDER BY ss.slot_index, ss.id
  LOOP
    v_examined_slot_count := v_examined_slot_count + 1;
    v_available_capacity := greatest(
      coalesce(v_store_slot.capacity, 0)
      - coalesce(v_store_slot.quantity, 0)
      - coalesce(v_store_slot.pending_quantity, 0),
      0
    );

    IF v_available_capacity <= 0 THEN
      CONTINUE;
    END IF;

    FOR v_source_slot IN
      SELECT ws.*
      FROM public.warehouse_slots ws
      WHERE ws.warehouse_id = v_general_warehouse.id
        AND ws.product_id = v_store_slot.product_id
        AND ws.quality_level = v_store_slot.quality_level
        AND coalesce(ws.brand_id, v_default_brand) = coalesce(v_store_slot.brand_id, v_default_brand)
        AND coalesce(ws.quantity, 0) > 0
      ORDER BY ws.slot_index, ws.id
    LOOP
      EXIT WHEN v_available_capacity <= 0;

      v_transfer_quantity := least(v_available_capacity, coalesce(v_source_slot.quantity, 0));
      IF v_transfer_quantity <= 0 THEN
        CONTINUE;
      END IF;

      v_transfer_result := public.transfer_store_warehouse_slot_to_store_slot(
        p_player_id,
        v_source_slot.id,
        v_store_slot.id,
        v_transfer_quantity
      );

      IF coalesce((v_transfer_result ->> 'success')::boolean, false) = true THEN
        v_available_capacity := v_available_capacity - v_transfer_quantity;
        v_total_transferred_quantity := v_total_transferred_quantity + v_transfer_quantity;
        v_used_source_slot_count := v_used_source_slot_count + 1;

        IF NOT (v_store_slot.id = ANY(v_affected_store_slot_ids)) THEN
          v_affected_store_slot_ids := array_append(v_affected_store_slot_ids, v_store_slot.id);
          v_filled_slot_count := v_filled_slot_count + 1;
        END IF;

        IF NOT (v_source_slot.id = ANY(v_affected_warehouse_slot_ids)) THEN
          v_affected_warehouse_slot_ids := array_append(v_affected_warehouse_slot_ids, v_source_slot.id);
        END IF;
      END IF;
    END LOOP;
  END LOOP;

  -- Client in-memory patch için güncellenen slotların tam snapshot'ını oluştur
  IF array_length(v_affected_store_slot_ids, 1) > 0 THEN
    SELECT coalesce(jsonb_agg(jsonb_build_object(
      'id', ss.id,
      'quantity', ss.quantity,
      'cost', ss.cost,
      'capacity', ss.capacity,
      'pending_quantity', ss.pending_quantity
    )), '[]'::jsonb)
    INTO v_updated_store_slots
    FROM public.store_slots ss
    WHERE ss.id = ANY(v_affected_store_slot_ids);
  END IF;

  IF array_length(v_affected_warehouse_slot_ids, 1) > 0 THEN
    SELECT coalesce(jsonb_agg(jsonb_build_object(
      'id', ws.id,
      'quantity', ws.quantity,
      'cost', ws.cost
    )), '[]'::jsonb)
    INTO v_updated_warehouse_slots
    FROM public.warehouse_slots ws
    WHERE ws.id = ANY(v_affected_warehouse_slot_ids);
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'store_id', p_store_id,
    'warehouse_id', v_general_warehouse.id,
    'filled_slot_count', v_filled_slot_count,
    'examined_slot_count', v_examined_slot_count,
    'used_source_slot_count', v_used_source_slot_count,
    'transferred_quantity', v_total_transferred_quantity,
    'affected_store_slot_ids', to_jsonb(v_affected_store_slot_ids),
    'affected_warehouse_slot_ids', to_jsonb(v_affected_warehouse_slot_ids),
    'updated_store_slots', v_updated_store_slots,
    'updated_warehouse_slots', v_updated_warehouse_slots,
    'changed', jsonb_build_object(
      'performance_dirty', (v_total_transferred_quantity > 0),
      'history_dirty', (v_total_transferred_quantity > 0),
      'dashboard_dirty', (v_total_transferred_quantity > 0)
    ),
    'message', CASE
      WHEN v_total_transferred_quantity > 0 THEN format('Raflara %s adet urun yerlestirildi.', v_total_transferred_quantity)
      ELSE 'Raflara aktarilacak uygun stok bulunamadi.'
    END
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.fill_store_shelves(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fill_store_shelves(uuid, uuid) TO service_role;
