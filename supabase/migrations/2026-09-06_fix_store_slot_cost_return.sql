-- ============================================================================
-- Fix: set_store_slot_product_from_warehouse_slot ve transfer_store_warehouse_slot_to_store_slot
-- Slota ürün atandığında ve depodan stok aktarıldığında güncel cost (maliyet) değerini döndürme
-- ============================================================================

-- 1. set_store_slot_product_from_warehouse_slot GÜNCELLEMESİ
CREATE OR REPLACE FUNCTION public.set_store_slot_product_from_warehouse_slot(
  p_player_id uuid,
  p_store_slot_id uuid,
  p_warehouse_slot_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_slot record;
  v_source_slot record;
  v_warehouse_id uuid;
  v_existing_wh_slot_id uuid;
  v_new_cost numeric;
  v_now timestamptz := timezone('utc'::text, now());
BEGIN
  SELECT ss.*, s.player_id, s.city_id, s.store_type_id
  INTO v_slot
  FROM public.store_slots ss
  JOIN public.stores s ON s.id = ss.store_id
  WHERE ss.id = p_store_slot_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Magaza slotu bulunamadi.';
  END IF;

  IF v_slot.player_id <> p_player_id THEN
    RAISE EXCEPTION 'Bu slot oyuncuya ait degil.';
  END IF;

  SELECT ws.*, w.player_id, w.city_id, w.id AS wh_id
  INTO v_source_slot
  FROM public.warehouse_slots ws
  JOIN public.warehouses w ON w.id = ws.warehouse_id
  WHERE ws.id = p_warehouse_slot_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Kaynak depo slotu bulunamadi.';
  END IF;

  IF v_source_slot.player_id <> p_player_id THEN
    RAISE EXCEPTION 'Kaynak depo slotu oyuncuya ait degil.';
  END IF;

  -- KURAL: Kaynak depo ile Mağaza aynı şehirde olmalıdır!
  IF v_source_slot.city_id IS DISTINCT FROM v_slot.city_id THEN
    RAISE EXCEPTION 'Sadece ayni sehirdeki Genel Depodaki urunler secilebilir.';
  END IF;

  IF coalesce(v_source_slot.product_id, '') = '' THEN
    RAISE EXCEPTION 'Kaynak depo slotunda urun bulunamadi.';
  END IF;

  IF coalesce(v_source_slot.quantity, 0) <= 0 THEN
    RAISE EXCEPTION 'Kaynak depo slotunda secilebilir stok bulunamadi.';
  END IF;

  IF coalesce(v_source_slot.quality_level, 0) < 1 OR coalesce(v_source_slot.quality_level, 0) > 5 THEN
    RAISE EXCEPTION 'Kaynak depo slotunun kalite seviyesi gecersiz.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.stores s
    JOIN public.store_types st ON st.id = s.store_type_id
    WHERE s.id = v_slot.store_id
      AND (
        st.accepted_product_ids IS NULL
        OR NOT (v_source_slot.product_id = ANY(regexp_split_to_array(st.accepted_product_ids, '\s*,\s*')))
      )
  ) THEN
    RAISE EXCEPTION 'Bu magaza turu bu urunu satamaz: %', v_source_slot.product_id;
  END IF;

  -- Eger rafta baska bir urunun stoğu varsa, o stoğu o ildeki Genel Depoya geri aktar
  IF coalesce(v_slot.quantity, 0) > 0 AND (
    v_slot.product_id IS DISTINCT FROM v_source_slot.product_id OR
    v_slot.quality_level IS DISTINCT FROM v_source_slot.quality_level OR
    v_slot.brand_id IS DISTINCT FROM coalesce(v_source_slot.brand_id, '00000000-0000-0000-0000-000000000000'::uuid)
  ) THEN
    SELECT id INTO v_warehouse_id
    FROM public.warehouses
    WHERE player_id = p_player_id
      AND city_id = v_slot.city_id
      AND (warehouse_kind IS NULL OR warehouse_kind IN ('general', 'normal'))
      AND is_active = true
    ORDER BY created_at ASC
    LIMIT 1;

    IF v_warehouse_id IS NOT NULL THEN
      SELECT id INTO v_existing_wh_slot_id
      FROM public.warehouse_slots
      WHERE warehouse_id = v_warehouse_id
        AND product_id = v_slot.product_id
        AND quality_level = v_slot.quality_level
        AND coalesce(brand_id, '00000000-0000-0000-0000-000000000000'::uuid) = coalesce(v_slot.brand_id, '00000000-0000-0000-0000-000000000000'::uuid)
      LIMIT 1;

      IF v_existing_wh_slot_id IS NOT NULL THEN
        UPDATE public.warehouse_slots
        SET
          quantity = quantity + v_slot.quantity,
          updated_at = v_now
        WHERE id = v_existing_wh_slot_id;
      ELSE
        INSERT INTO public.warehouse_slots (
          warehouse_id,
          product_id,
          quality_level,
          brand_id,
          quantity,
          cost,
          created_at,
          updated_at
        ) VALUES (
          v_warehouse_id,
          v_slot.product_id,
          v_slot.quality_level,
          coalesce(v_slot.brand_id, '00000000-0000-0000-0000-000000000000'::uuid),
          v_slot.quantity,
          coalesce(v_slot.cost, 0),
          v_now,
          v_now
        );
      END IF;
    END IF;
  END IF;

  v_new_cost := CASE
    WHEN coalesce(v_slot.product_id, '') = coalesce(v_source_slot.product_id, '')
     AND coalesce(v_slot.quality_level, 0) = coalesce(v_source_slot.quality_level, 0)
     AND coalesce(v_slot.brand_id, '00000000-0000-0000-0000-000000000000'::uuid) = coalesce(v_source_slot.brand_id, '00000000-0000-0000-0000-000000000000'::uuid)
    THEN coalesce(v_slot.cost, 0) ELSE coalesce(v_source_slot.cost, 0) END;

  UPDATE public.store_slots
  SET
    product_id = v_source_slot.product_id,
    quality_level = v_source_slot.quality_level,
    brand_id = coalesce(v_source_slot.brand_id, '00000000-0000-0000-0000-000000000000'::uuid),
    quantity = CASE
      WHEN coalesce(v_slot.product_id, '') = coalesce(v_source_slot.product_id, '')
       AND coalesce(v_slot.quality_level, 0) = coalesce(v_source_slot.quality_level, 0)
       AND coalesce(v_slot.brand_id, '00000000-0000-0000-0000-000000000000'::uuid) = coalesce(v_source_slot.brand_id, '00000000-0000-0000-0000-000000000000'::uuid)
      THEN quantity ELSE 0 END,
    price = CASE
      WHEN coalesce(v_slot.product_id, '') = coalesce(v_source_slot.product_id, '')
       AND coalesce(v_slot.quality_level, 0) = coalesce(v_source_slot.quality_level, 0)
       AND coalesce(v_slot.brand_id, '00000000-0000-0000-0000-000000000000'::uuid) = coalesce(v_source_slot.brand_id, '00000000-0000-0000-0000-000000000000'::uuid)
      THEN price ELSE 0 END,
    cost = v_new_cost,
    pending_sale = 0,
    pending_quantity = 0,
    last_sale_processed_at = CASE
      WHEN coalesce(v_slot.product_id, '') = coalesce(v_source_slot.product_id, '')
       AND coalesce(v_slot.quality_level, 0) = coalesce(v_source_slot.quality_level, 0)
       AND coalesce(v_slot.brand_id, '00000000-0000-0000-0000-000000000000'::uuid) = coalesce(v_source_slot.brand_id, '00000000-0000-0000-0000-000000000000'::uuid)
      THEN last_sale_processed_at ELSE v_now END,
    updated_at = v_now
  WHERE id = p_store_slot_id;

  RETURN jsonb_build_object(
    'success', true,
    'store_slot_id', p_store_slot_id,
    'store_id', v_slot.store_id,
    'product_id', v_source_slot.product_id,
    'quality_level', v_source_slot.quality_level,
    'brand_id', coalesce(v_source_slot.brand_id, '00000000-0000-0000-0000-000000000000'::uuid),
    'warehouse_slot_id', p_warehouse_slot_id,
    'cost', v_new_cost
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.set_store_slot_product_from_warehouse_slot(uuid, uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_store_slot_product_from_warehouse_slot(uuid, uuid, uuid) TO service_role;


-- 2. transfer_store_warehouse_slot_to_store_slot GÜNCELLEMESİ
CREATE OR REPLACE FUNCTION public.transfer_store_warehouse_slot_to_store_slot(
  p_player_id uuid,
  p_warehouse_slot_id uuid,
  p_store_slot_id uuid,
  p_quantity integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_default_brand uuid := '00000000-0000-0000-0000-000000000000'::uuid;
  v_now timestamptz := timezone('utc'::text, now());
  v_store_slot record;
  v_warehouse_slot record;
  v_available_capacity integer;
  v_new_store_quantity integer;
  v_new_store_cost numeric;
  v_remaining_warehouse_quantity integer;
BEGIN
  IF p_quantity IS NULL OR p_quantity <= 0 THEN
    RAISE EXCEPTION 'Transfer miktari 0 dan buyuk olmalidir.';
  END IF;

  SELECT ss.*, s.player_id, s.city_id
  INTO v_store_slot
  FROM public.store_slots ss
  JOIN public.stores s ON s.id = ss.store_id
  WHERE ss.id = p_store_slot_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Magaza slotu bulunamadi.';
  END IF;

  IF v_store_slot.player_id <> p_player_id THEN
    RAISE EXCEPTION 'Bu magaza slotu oyuncuya ait degil.';
  END IF;

  IF coalesce(v_store_slot.is_active, true) = false THEN
    RAISE EXCEPTION 'Pasif magaza slotuna stok aktarilamaz.';
  END IF;

  IF coalesce(v_store_slot.product_id, '') = '' THEN
    RAISE EXCEPTION 'Once magaza slotu urununu depodan secin.';
  END IF;

  IF coalesce(v_store_slot.quality_level, 0) < 1 OR coalesce(v_store_slot.quality_level, 0) > 5 THEN
    RAISE EXCEPTION 'Magaza slotunun kalite seviyesi gecersiz.';
  END IF;

  SELECT ws.*, w.player_id, w.city_id
  INTO v_warehouse_slot
  FROM public.warehouse_slots ws
  JOIN public.warehouses w ON w.id = ws.warehouse_id
  WHERE ws.id = p_warehouse_slot_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Genel depo slotu bulunamadi.';
  END IF;

  IF v_warehouse_slot.player_id <> p_player_id THEN
    RAISE EXCEPTION 'Bu depo slotu oyuncuya ait degil.';
  END IF;

  -- KURAL: Depo ve Mağaza aynı şehirde olmalıdır!
  IF v_warehouse_slot.city_id <> v_store_slot.city_id THEN
    RAISE EXCEPTION 'Sadece ayni sehirdeki Genel Depodan magazaya stok aktarilabilir.';
  END IF;

  IF coalesce(v_warehouse_slot.product_id, '') = '' THEN
    RAISE EXCEPTION 'Kaynak depo slotunda urun bulunamadi.';
  END IF;

  IF coalesce(v_warehouse_slot.quality_level, 0) < 1 OR coalesce(v_warehouse_slot.quality_level, 0) > 5 THEN
    RAISE EXCEPTION 'Kaynak depo slotunun kalite seviyesi gecersiz.';
  END IF;

  IF coalesce(v_warehouse_slot.quantity, 0) < p_quantity THEN
    RAISE EXCEPTION 'Kaynak depo slotunda yeterli stok yok.';
  END IF;

  IF v_store_slot.product_id <> v_warehouse_slot.product_id THEN
    RAISE EXCEPTION 'Magaza slotu ile depo slotundaki urun ayni olmalidir.';
  END IF;

  IF v_store_slot.quality_level <> v_warehouse_slot.quality_level THEN
    RAISE EXCEPTION 'Magaza slotu ile depo slotundaki kalite ayni olmalidir.';
  END IF;

  IF coalesce(v_store_slot.brand_id, v_default_brand) <> coalesce(v_warehouse_slot.brand_id, v_default_brand) THEN
    RAISE EXCEPTION 'Magaza slotu ile depo slotundaki marka ayni olmalidir.';
  END IF;

  v_available_capacity := greatest(
    coalesce(v_store_slot.capacity, 0)
    - coalesce(v_store_slot.quantity, 0)
    - coalesce(v_store_slot.pending_quantity, 0),
    0
  );

  IF p_quantity > v_available_capacity THEN
    RAISE EXCEPTION 'Magaza slotunda yeterli kapasite yok.';
  END IF;

  v_new_store_quantity := coalesce(v_store_slot.quantity, 0) + p_quantity;
  v_new_store_cost := CASE
    WHEN v_new_store_quantity <= 0 THEN 0
    WHEN coalesce(v_store_slot.quantity, 0) <= 0 THEN coalesce(v_warehouse_slot.cost, 0)
    ELSE round(((coalesce(v_store_slot.quantity, 0) * coalesce(v_store_slot.cost, 0)) + (p_quantity * coalesce(v_warehouse_slot.cost, 0))) / v_new_store_quantity::numeric, 4)
  END;

  UPDATE public.store_slots
  SET
    product_id = v_warehouse_slot.product_id,
    quality_level = v_warehouse_slot.quality_level,
    brand_id = coalesce(v_warehouse_slot.brand_id, v_default_brand),
    quantity = v_new_store_quantity,
    cost = v_new_store_cost,
    updated_at = v_now
  WHERE id = v_store_slot.id;

  v_remaining_warehouse_quantity := coalesce(v_warehouse_slot.quantity, 0) - p_quantity;

  IF v_remaining_warehouse_quantity <= 0 THEN
    DELETE FROM public.warehouse_slots
    WHERE id = v_warehouse_slot.id;
  ELSE
    UPDATE public.warehouse_slots
    SET
      quantity = v_remaining_warehouse_quantity,
      updated_at = v_now
    WHERE id = v_warehouse_slot.id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'store_id', v_store_slot.store_id,
    'store_slot_id', v_store_slot.id,
    'warehouse_slot_id', v_warehouse_slot.id,
    'product_id', v_warehouse_slot.product_id,
    'quality_level', v_warehouse_slot.quality_level,
    'brand_id', coalesce(v_warehouse_slot.brand_id, v_default_brand),
    'transferred_quantity', p_quantity,
    'store_slot_quantity', v_new_store_quantity,
    'remaining_warehouse_quantity', greatest(v_remaining_warehouse_quantity, 0),
    'cost', v_new_store_cost,
    'message', 'Stok Genel Depodan magazaya aktarildi.'
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.transfer_store_warehouse_slot_to_store_slot(uuid, uuid, uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.transfer_store_warehouse_slot_to_store_slot(uuid, uuid, uuid, integer) TO service_role;
