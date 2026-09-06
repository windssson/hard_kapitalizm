-- ============================================================================
-- MIGRATION: 2026-09-03_store_cleanup_and_sell_alignment.sql
-- 1. clear_store_slot_product: Rafta kalan stok varsa mağazanın bulunduğu
--    ildeki Genel Depo'ya aktarılır (eski store_warehouse aranması engellendi).
-- 2. sell_store: Mağaza satıldığında artık bağımsız mağaza deposu aranmaz ve
--    silinmez; sadece mağaza ve rafları satılır.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. clear_store_slot_product
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.clear_store_slot_product(p_player_id uuid, p_store_slot_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_slot record;
  v_warehouse_id uuid;
  v_existing_wh_slot_id uuid;
  v_now timestamptz := timezone('utc'::text, now());
BEGIN
  SELECT
    ss.*,
    s.player_id,
    s.city_id
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

  -- Eger rafta kalan stok varsa o ildeki Genel Depoya aktar
  IF coalesce(v_slot.quantity, 0) > 0 AND v_slot.product_id IS NOT NULL THEN
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

  UPDATE public.store_slots
  SET
    product_id = null,
    brand_id = '00000000-0000-0000-0000-000000000000'::uuid,
    quality_level = 0,
    quantity = 0,
    price = 0,
    cost = 0,
    pending_sale = 0,
    pending_quantity = 0,
    updated_at = v_now
  WHERE id = p_store_slot_id;

  RETURN jsonb_build_object(
    'success', true,
    'store_slot_id', p_store_slot_id,
    'store_id', v_slot.store_id,
    'product_id', null,
    'brand_id', '00000000-0000-0000-0000-000000000000'::uuid,
    'quality_level', 0,
    'quantity', 0,
    'price', 0,
    'cost', 0,
    'pending_sale', 0
  );
END;
$function$;

-- ----------------------------------------------------------------------------
-- 2. sell_store
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sell_store(p_store_id uuid, p_confirm boolean DEFAULT false)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_player_id uuid := auth.uid();
  v_now timestamptz := timezone('utc', now());
  v_store public.stores%rowtype;
  v_store_type_cost numeric := 0;
  v_store_slots uuid[] := '{}'::uuid[];
  v_store_construction_refund numeric := 0;
  v_store_stock_refund numeric := 0;
  v_total_refund numeric := 0;
BEGIN
  IF v_player_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Oturum acilmamis.'
    );
  END IF;

  SELECT s.*
  INTO v_store
  FROM public.stores s
  WHERE s.id = p_store_id
    AND s.player_id = v_player_id
  FOR UPDATE OF s;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Magaza bulunamadi veya size ait degil.'
    );
  END IF;

  SELECT coalesce(st.cost, 0)
  INTO v_store_type_cost
  FROM public.store_types st
  WHERE st.id = v_store.store_type_id;

  SELECT coalesce(array_agg(ss.id), '{}'::uuid[])
  INTO v_store_slots
  FROM public.store_slots ss
  WHERE ss.store_id = p_store_id;

  -- Aktif sevkiyat kontrolü
  IF EXISTS (
    SELECT 1
    FROM public.logistics_transfers lt
    WHERE lt.status = 'in_transit'
      AND (
        lt.buyer_store_id = p_store_id
        OR lt.seller_store_id = p_store_id
        OR lt.buyer_store_slot_id = ANY(v_store_slots)
        OR lt.seller_store_slot_id = ANY(v_store_slots)
      )
  ) THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Magazaya bagli aktif transferler tamamlanmadan satis yapilamaz.'
    );
  END IF;

  -- Devam eden yükseltme kontrolü
  IF EXISTS (
    SELECT 1
    FROM public.building_upgrades bu
    WHERE bu.player_id = v_player_id
      AND bu.status = 'in_progress'
      AND bu.building_kind = 'store'
      AND bu.entity_id = p_store_id
  ) THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Magaza icin devam eden bir yukseltme var.'
    );
  END IF;

  -- Raflardaki stok iadesi
  SELECT coalesce(sum(ss.quantity * ss.cost), 0)
  INTO v_store_stock_refund
  FROM public.store_slots ss
  WHERE ss.store_id = p_store_id;

  -- İnşaat ve yükseltme maliyeti iadesi
  SELECT coalesce(sum(coalesce((bu.params ->> 'upgrade_cost')::numeric, 0)), 0)
  INTO v_store_construction_refund
  FROM public.building_upgrades bu
  WHERE bu.player_id = v_player_id
    AND bu.building_kind = 'store'
    AND bu.entity_id = p_store_id
    AND bu.status = 'completed';

  v_store_construction_refund := v_store_type_cost + v_store_construction_refund;
  v_total_refund := v_store_construction_refund + v_store_stock_refund;

  IF p_confirm = false THEN
    RETURN jsonb_build_object(
      'success', true,
      'store_construction_refund', round(v_store_construction_refund, 2),
      'store_stock_refund', round(v_store_stock_refund, 2),
      'construction_refund', round(v_store_construction_refund, 2),
      'stock_refund', round(v_store_stock_refund, 2),
      'total_refund', round(v_total_refund, 2),
      'message', 'Magaza satis teklifi hazirlandi.'
    );
  END IF;

  -- Transfer kayıtlarında mağaza bağlantılarını temizle
  UPDATE public.logistics_transfers
  SET buyer_store_id = CASE WHEN buyer_store_id = p_store_id THEN null ELSE buyer_store_id END,
      seller_store_id = CASE WHEN seller_store_id = p_store_id THEN null ELSE seller_store_id END,
      buyer_store_slot_id = CASE WHEN buyer_store_slot_id = ANY(v_store_slots) THEN null ELSE buyer_store_slot_id END,
      seller_store_slot_id = CASE WHEN seller_store_slot_id = ANY(v_store_slots) THEN null ELSE seller_store_slot_id END,
      updated_at = v_now
  WHERE buyer_store_id = p_store_id
     OR seller_store_id = p_store_id
     OR buyer_store_slot_id = ANY(v_store_slots)
     OR seller_store_slot_id = ANY(v_store_slots);

  DELETE FROM public.store_daily_performance
  WHERE store_id = p_store_id;

  DELETE FROM public.building_boosts
  WHERE building_kind = 'store' AND entity_id = p_store_id;

  DELETE FROM public.building_upgrades
  WHERE building_kind = 'store' AND entity_id = p_store_id;

  DELETE FROM public.store_slots
  WHERE store_id = p_store_id;

  DELETE FROM public.stores
  WHERE id = p_store_id
    AND player_id = v_player_id;

  UPDATE public.players
  SET cash = cash + v_total_refund
  WHERE id = v_player_id;

  PERFORM public.log_player_cash_change(
    v_player_id,
    v_total_refund,
    (SELECT cash - v_total_refund FROM public.players WHERE id = v_player_id),
    'store_sale',
    format('Magaza satildi: %s | Toplam iade %s TL', v_store.name, round(v_total_refund, 2)),
    p_store_id,
    'store'
  );

  RETURN jsonb_build_object(
    'success', true,
    'construction_refund', round(v_store_construction_refund, 2),
    'stock_refund', round(v_store_stock_refund, 2),
    'total_refund', round(v_total_refund, 2),
    'message', 'Magaza basariyla satildi.',
    'changed', jsonb_build_object(
      'player', public.get_player_profile(v_player_id)
    )
  );
END;
$function$;
