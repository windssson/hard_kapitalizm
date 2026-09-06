-- ============================================================================
-- MIGRATION: 2026-09-03_production_same_city_warehouse_alignment.sql
-- Kural: Üretim birimleri (Fabrika, Tarla, Çiftlik, Maden) yalnızca AYNI
-- ŞEHİRDEKİ Genel Depo ile transfer yapabilir. Şehirler arası doğrudan
-- üretim transferi yapılamaz; şehirler arası sevkiyatlar yalnızca Genel Depolar
-- arasında yürütülür.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. start_multi_production_to_warehouse_transfer
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.start_multi_production_to_warehouse_transfer(
  p_source_owner_kind text,
  p_source_owner_id uuid,
  p_buyer_warehouse_id uuid,
  p_items jsonb,
  p_vehicle_id uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_default_brand uuid := '00000000-0000-0000-0000-000000000000'::uuid;
  v_player_id uuid := auth.uid();
  v_now timestamptz := timezone('utc', now());
  v_source_owner_player_id uuid;
  v_source_owner_city_id uuid;
  v_target_warehouse record;
  v_header_item jsonb;
  v_header_inventory record;
  v_transfer_id uuid;
  v_item jsonb;
  v_inventory record;
  v_product products%rowtype;
  v_finish_at timestamptz := v_now;
  v_total_volume numeric := 0;
  v_total_quantity integer := 0;
  v_item_count integer := 0;
  v_target_used_capacity numeric := 0;
BEGIN
  IF v_player_id IS NULL THEN RAISE EXCEPTION 'Oturum acilmamis.'; END IF;
  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'Transfer kalemi secilmedi.';
  END IF;

  CASE p_source_owner_kind
    WHEN 'factory' THEN SELECT player_id, city_id INTO v_source_owner_player_id, v_source_owner_city_id FROM public.factories WHERE id = p_source_owner_id;
    WHEN 'farm' THEN SELECT player_id, city_id INTO v_source_owner_player_id, v_source_owner_city_id FROM public.farms WHERE id = p_source_owner_id;
    WHEN 'field' THEN SELECT player_id, city_id INTO v_source_owner_player_id, v_source_owner_city_id FROM public.fields WHERE id = p_source_owner_id;
    WHEN 'mine' THEN SELECT player_id, city_id INTO v_source_owner_player_id, v_source_owner_city_id FROM public.mines WHERE id = p_source_owner_id;
    ELSE RAISE EXCEPTION 'Gecersiz kaynak uretim tipi.';
  END CASE;

  IF v_source_owner_player_id IS NULL OR v_source_owner_player_id <> v_player_id THEN
    RAISE EXCEPTION 'Kaynak uretim birimi oyuncuya ait degil.';
  END IF;

  SELECT w.*, c.map_position_x, c.map_position_y INTO v_target_warehouse
  FROM public.warehouses w
  JOIN public.cities c ON c.id = w.city_id
  WHERE w.id = p_buyer_warehouse_id
    AND w.player_id = v_player_id
    AND w.is_active = true
    AND (w.warehouse_kind IS NULL OR w.warehouse_kind IN ('general', 'normal'))
  FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'Hedef depo bulunamadi.'; END IF;

  -- KURAL: Üretim birimleri yalnızca AYNI ŞEHİRDEKİ Genel Depoya ürün gönderebilir!
  IF v_source_owner_city_id <> v_target_warehouse.city_id THEN
    RAISE EXCEPTION 'Uretim birimleri yalnizca ayni sehirdeki Genel Depoya urun gonderebilir. Sehirler arasi transferler yalnizca Genel Depolar arasinda yapilabilir.';
  END IF;

  SELECT coalesce(sum((ws.quantity + coalesce(ws.pending_quantity, 0)) * coalesce(p.birim_hacim, 0)), 0)
  INTO v_target_used_capacity
  FROM public.warehouse_slots ws
  LEFT JOIN public.products p ON p.id = ws.product_id
  WHERE ws.warehouse_id = v_target_warehouse.id;

  v_header_item := p_items -> 0;
  SELECT * INTO v_header_inventory
  FROM public.production_inventory
  WHERE id = nullif(v_header_item ->> 'production_inventory_id', '')::uuid
  FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'Ilk production envanteri bulunamadi.'; END IF;
  IF v_header_inventory.owner_kind <> p_source_owner_kind OR v_header_inventory.owner_id <> p_source_owner_id THEN
    RAISE EXCEPTION 'Tum kalemler ayni uretim birimine ait olmalidir.';
  END IF;

  INSERT INTO public.logistics_transfers (
    buyer_player_id, seller_player_id, buyer_warehouse_id, seller_production_inventory_id, logistics_vehicle_id, vehicle_owner_player_id,
    is_rental, product_id, quality_level, quantity, unit_price, total_price, product_unit_volume, reserved_capacity_amount, distance_km,
    fuel_used, condition_loss, rental_cost, transport_cost, started_at, finish_at, completed_at, status, transfer_type, seller_entity_kind,
    buyer_entity_kind, item_count, total_quantity, brand_id, created_at, updated_at
  ) VALUES (
    v_player_id, v_player_id, p_buyer_warehouse_id, v_header_inventory.id, NULL, NULL, false, v_header_inventory.product_id, v_header_inventory.quality_level,
    1, 0, 0, 0.0001, 0, 0, 0, 0, 0, 0, v_now, v_now, NULL, 'in_transit', 'production_to_warehouse_multi', 'production_inventory', 'warehouse',
    1, 0, coalesce(v_header_inventory.brand_id, v_default_brand), v_now, v_now
  ) RETURNING id INTO v_transfer_id;

  FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) LOOP
    SELECT * INTO v_inventory
    FROM public.production_inventory
    WHERE id = nullif(v_item ->> 'production_inventory_id', '')::uuid
    FOR UPDATE;

    IF NOT FOUND THEN RAISE EXCEPTION 'Production envanteri bulunamadi.'; END IF;
    IF v_inventory.owner_kind <> p_source_owner_kind OR v_inventory.owner_id <> p_source_owner_id THEN
      RAISE EXCEPTION 'Tum kalemler ayni uretim birimine ait olmalidir.';
    END IF;
    IF coalesce(v_inventory.quantity, 0) < greatest(coalesce((v_item ->> 'quantity')::integer, 0), 0) THEN
      RAISE EXCEPTION 'Production envanterinde yeterli stok yok.';
    END IF;

    SELECT * INTO v_product FROM public.products WHERE id = v_inventory.product_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Urun bulunamadi.'; END IF;
    IF coalesce(v_product.birim_hacim, 0) <= 0 THEN RAISE EXCEPTION 'Urun hacim bilgisi gecersiz.'; END IF;

    v_total_quantity := v_total_quantity + greatest(coalesce((v_item ->> 'quantity')::integer, 0), 0);
    v_total_volume := v_total_volume + (greatest(coalesce((v_item ->> 'quantity')::integer, 0), 0) * coalesce(v_product.birim_hacim, 0));
    v_item_count := v_item_count + 1;
  END LOOP;

  IF v_target_used_capacity + coalesce(v_target_warehouse.reserved_capacity, 0) + v_total_volume > coalesce(v_target_warehouse.capacity, 0) THEN
    RAISE EXCEPTION 'Hedef depoda yeterli kapasite yok.';
  END IF;

  FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) LOOP
    SELECT * INTO v_inventory FROM public.production_inventory WHERE id = nullif(v_item ->> 'production_inventory_id', '')::uuid FOR UPDATE;
    SELECT * INTO v_product FROM public.products WHERE id = v_inventory.product_id;

    INSERT INTO public.logistics_transfer_items (
      transfer_id, source_warehouse_slot_id, target_warehouse_slot_id, product_id, quality_level, brand_id, quantity, unit_cost, unit_price, total_cost, total_price, product_unit_volume, reserved_capacity_amount, status, created_at, updated_at, completed_at
    ) VALUES (
      v_transfer_id, NULL, NULL, v_inventory.product_id, v_inventory.quality_level, coalesce(v_inventory.brand_id, v_default_brand), greatest(coalesce((v_item ->> 'quantity')::integer, 0), 0), coalesce(v_inventory.cost, 0), 0, greatest(coalesce((v_item ->> 'quantity')::integer, 0), 0) * coalesce(v_inventory.cost, 0), 0, coalesce(v_product.birim_hacim, 0), 0, 'in_transit', v_now, v_now, NULL
    );

    UPDATE public.production_inventory
    SET quantity = quantity - greatest(coalesce((v_item ->> 'quantity')::integer, 0), 0),
        pending_quantity = CASE WHEN inventory_type = 'input' THEN greatest(coalesce(pending_quantity, 0), 0) ELSE pending_quantity END
    WHERE id = v_inventory.id;
  END LOOP;

  UPDATE public.logistics_transfers
  SET logistics_vehicle_id = NULL,
    vehicle_owner_player_id = NULL,
    is_rental = false,
    quantity = greatest(v_total_quantity, 1), unit_price = 0, total_price = 0, product_unit_volume = greatest(v_total_volume, 0.0001), reserved_capacity_amount = 0, distance_km = 0, fuel_used = 0, condition_loss = 0, rental_cost = 0, transport_cost = 0, finish_at = v_finish_at, completed_at = NULL, status = 'in_transit', item_count = v_item_count, total_quantity = v_total_quantity, updated_at = v_now
  WHERE id = v_transfer_id;

  -- Şehir içi transfer anında tamamlanır!
  PERFORM public.complete_logistics_transfer(v_transfer_id);

  RETURN jsonb_build_object(
    'success', true,
    'mode', 'instant',
    'transfer_id', v_transfer_id,
    'transport_cost', 0,
    'finish_at', v_finish_at,
    'item_count', v_item_count,
    'total_quantity', v_total_quantity,
    'message', 'Uretim cikisi ayni sehirdeki Genel Depoya aninda aktarildi.',
    'changed', jsonb_build_object(
      'player', public.get_player_profile(v_player_id)
    )
  );
END;
$function$;

-- ----------------------------------------------------------------------------
-- 2. start_multi_warehouse_to_production_transfer
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.start_multi_warehouse_to_production_transfer(
  p_source_warehouse_id uuid,
  p_items jsonb,
  p_vehicle_id uuid DEFAULT NULL::uuid,
  p_production_inventory_id uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_default_brand uuid := '00000000-0000-0000-0000-000000000000'::uuid;
  v_player_id uuid := auth.uid();
  v_now timestamptz := timezone('utc', now());
  v_source_warehouse record;
  v_target_owner_city_id uuid;
  v_header_item jsonb;
  v_header_inventory record;
  v_header_inv_id uuid;
  v_transfer_id uuid;
  v_item jsonb;
  v_inv_id uuid;
  v_slot_id uuid;
  v_source_slot record;
  v_inventory record;
  v_product products%rowtype;
  v_finish_at timestamptz := v_now;
  v_total_volume numeric := 0;
  v_total_quantity integer := 0;
  v_item_count integer := 0;
  v_item_quantity integer := 0;
  v_item_volume numeric := 0;
BEGIN
  IF v_player_id IS NULL THEN RAISE EXCEPTION 'Oturum acilmamis.'; END IF;
  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'Transfer kalemi secilmedi.';
  END IF;

  SELECT w.*, c.map_position_x, c.map_position_y
  INTO v_source_warehouse
  FROM public.warehouses w
  JOIN public.cities c ON c.id = w.city_id
  WHERE w.id = p_source_warehouse_id
    AND w.player_id = v_player_id
    AND w.is_active = true
    AND (w.warehouse_kind IS NULL OR w.warehouse_kind IN ('general', 'normal'))
  FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'Kaynak depo bulunamadi.'; END IF;

  v_header_item := p_items -> 0;
  v_header_inv_id := coalesce(nullif(v_header_item ->> 'production_inventory_id', '')::uuid, p_production_inventory_id);
  IF v_header_inv_id IS NULL THEN RAISE EXCEPTION 'Hedef production envanteri belirtilmedi.'; END IF;

  SELECT pi.*,
    CASE WHEN pi.owner_kind = 'factory' THEN fx.player_id WHEN pi.owner_kind = 'farm' THEN fa.player_id WHEN pi.owner_kind = 'field' THEN fld.player_id WHEN pi.owner_kind = 'mine' THEN m.player_id ELSE NULL END as owner_player_id,
    CASE WHEN pi.owner_kind = 'factory' THEN fx.city_id WHEN pi.owner_kind = 'farm' THEN fa.city_id WHEN pi.owner_kind = 'field' THEN fld.city_id WHEN pi.owner_kind = 'mine' THEN m.city_id ELSE NULL END as owner_city_id
  INTO v_header_inventory
  FROM public.production_inventory pi
  LEFT JOIN public.factories fx ON pi.owner_kind = 'factory' AND fx.id = pi.owner_id
  LEFT JOIN public.farms fa ON pi.owner_kind = 'farm' AND fa.id = pi.owner_id
  LEFT JOIN public.fields fld ON pi.owner_kind = 'field' AND fld.id = pi.owner_id
  LEFT JOIN public.mines m ON pi.owner_kind = 'mine' AND m.id = pi.owner_id
  WHERE pi.id = v_header_inv_id
  FOR UPDATE OF pi;

  IF NOT FOUND THEN RAISE EXCEPTION 'Hedef production envanteri bulunamadi.'; END IF;
  IF v_header_inventory.owner_player_id <> v_player_id THEN RAISE EXCEPTION 'Hedef uretim birimi oyuncuya ait degil.'; END IF;

  v_target_owner_city_id := v_header_inventory.owner_city_id;

  -- KURAL: Üretim birimleri yalnızca AYNI ŞEHİRDEKİ Genel Depodan hammadde alabilir!
  IF v_source_warehouse.city_id <> v_target_owner_city_id THEN
    RAISE EXCEPTION 'Uretim birimleri yalnizca ayni sehirdeki Genel Depodan hammadde alabilir. Sehirler arasi transferler yalnizca Genel Depolar arasinda yapilabilir.';
  END IF;

  INSERT INTO public.logistics_transfers (
    buyer_player_id, seller_player_id, buyer_warehouse_id, seller_warehouse_id, buyer_production_inventory_id, logistics_vehicle_id,
    vehicle_owner_player_id, is_rental, product_id, quality_level, quantity, unit_price, total_price, product_unit_volume,
    reserved_capacity_amount, distance_km, fuel_used, condition_loss, rental_cost, transport_cost, started_at, finish_at, completed_at,
    status, transfer_type, seller_entity_kind, buyer_entity_kind, item_count, total_quantity, brand_id, created_at, updated_at
  ) VALUES (
    v_player_id, v_player_id, NULL, p_source_warehouse_id, v_header_inventory.id, NULL, NULL, false, v_header_inventory.product_id, v_header_inventory.quality_level,
    1, 0, 0, 0.0001, 0, 0, 0, 0, 0, 0, v_now, v_now, NULL, 'in_transit', 'warehouse_to_production_multi', 'warehouse', 'production_inventory',
    1, 0, coalesce(v_header_inventory.brand_id, v_default_brand), v_now, v_now
  ) RETURNING id INTO v_transfer_id;

  FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) LOOP
    v_inv_id := coalesce(nullif(v_item ->> 'production_inventory_id', '')::uuid, p_production_inventory_id);
    v_slot_id := coalesce(nullif(v_item ->> 'source_warehouse_slot_id', ''), nullif(v_item ->> 'warehouse_slot_id', ''))::uuid;
    v_item_quantity := greatest(coalesce((v_item ->> 'quantity')::integer, 0), 0);

    IF v_slot_id IS NULL THEN RAISE EXCEPTION 'Kaynak depo slot id si belirtilmedi.'; END IF;
    IF v_item_quantity <= 0 THEN RAISE EXCEPTION 'Transfer miktari 0 dan buyuk olmalidir.'; END IF;

    SELECT ws.*, w.player_id, w.city_id
    INTO v_source_slot
    FROM public.warehouse_slots ws
    JOIN public.warehouses w ON w.id = ws.warehouse_id
    WHERE ws.id = v_slot_id
    FOR UPDATE;

    IF NOT FOUND THEN RAISE EXCEPTION 'Kaynak depo slotu bulunamadi: %', v_slot_id; END IF;
    IF v_source_slot.player_id <> v_player_id THEN RAISE EXCEPTION 'Kaynak depo slotu oyuncuya ait degil.'; END IF;
    IF v_source_slot.warehouse_id <> p_source_warehouse_id THEN RAISE EXCEPTION 'Tum kalemler ayni kaynak depoya ait olmalidir.'; END IF;
    IF coalesce(v_source_slot.quantity, 0) < v_item_quantity THEN RAISE EXCEPTION 'Kaynak slotta yeterli stok yok.'; END IF;

    SELECT pi.*,
      CASE WHEN pi.owner_kind = 'factory' THEN fx.player_id WHEN pi.owner_kind = 'farm' THEN fa.player_id WHEN pi.owner_kind = 'field' THEN fld.player_id WHEN pi.owner_kind = 'mine' THEN m.player_id ELSE NULL END as owner_player_id
    INTO v_inventory
    FROM public.production_inventory pi
    LEFT JOIN public.factories fx ON pi.owner_kind = 'factory' AND fx.id = pi.owner_id
    LEFT JOIN public.farms fa ON pi.owner_kind = 'farm' AND fa.id = pi.owner_id
    LEFT JOIN public.fields fld ON pi.owner_kind = 'field' AND fld.id = pi.owner_id
    LEFT JOIN public.mines m ON pi.owner_kind = 'mine' AND m.id = pi.owner_id
    WHERE pi.id = v_inv_id
    FOR UPDATE OF pi;

    IF NOT FOUND THEN RAISE EXCEPTION 'Hedef production envanteri bulunamadi.'; END IF;
    IF v_inventory.owner_player_id <> v_player_id THEN RAISE EXCEPTION 'Hedef production envanteri oyuncuya ait degil.'; END IF;

    SELECT * INTO v_product FROM public.products WHERE id = v_source_slot.product_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Urun bulunamadi: %', v_source_slot.product_id; END IF;

    v_item_volume := v_item_quantity * coalesce(v_product.birim_hacim, 0.001);
    v_total_quantity := v_total_quantity + v_item_quantity;
    v_total_volume := v_total_volume + v_item_volume;
    v_item_count := v_item_count + 1;

    INSERT INTO public.logistics_transfer_items (
      transfer_id, source_warehouse_slot_id, target_warehouse_slot_id, target_production_inventory_id, product_id, quality_level,
      brand_id, quantity, unit_cost, unit_price, total_cost, total_price, product_unit_volume, reserved_capacity_amount, status, created_at, updated_at, completed_at
    ) VALUES (
      v_transfer_id, v_source_slot.id, NULL, v_inventory.id, v_source_slot.product_id, v_source_slot.quality_level, coalesce(v_source_slot.brand_id, v_default_brand),
      v_item_quantity, coalesce(v_source_slot.cost, 0), 0, v_item_quantity * coalesce(v_source_slot.cost, 0), 0, coalesce(v_product.birim_hacim, 0.001), 0, 'in_transit', v_now, v_now, NULL
    );

    UPDATE public.warehouse_slots
    SET quantity = quantity - v_item_quantity, updated_at = v_now
    WHERE id = v_source_slot.id;

    IF coalesce(v_source_slot.quantity, 0) - v_item_quantity <= 0 AND coalesce(v_source_slot.pending_quantity, 0) <= 0 THEN
      DELETE FROM public.warehouse_slots WHERE id = v_source_slot.id;
    END IF;
  END LOOP;

  UPDATE public.logistics_transfers
  SET logistics_vehicle_id = NULL,
    vehicle_owner_player_id = NULL,
    is_rental = false,
    quantity = greatest(v_total_quantity, 1), unit_price = 0, total_price = 0, product_unit_volume = greatest(v_total_volume, 0.0001), reserved_capacity_amount = 0, distance_km = 0, fuel_used = 0, condition_loss = 0, rental_cost = 0, transport_cost = 0, finish_at = v_finish_at, completed_at = NULL, status = 'in_transit', item_count = v_item_count, total_quantity = v_total_quantity, updated_at = v_now
  WHERE id = v_transfer_id;

  -- Şehir içi transfer anında tamamlanır!
  PERFORM public.complete_logistics_transfer(v_transfer_id);

  RETURN jsonb_build_object(
    'success', true,
    'mode', 'instant',
    'transfer_id', v_transfer_id,
    'transport_cost', 0,
    'finish_at', v_finish_at,
    'item_count', v_item_count,
    'total_quantity', v_total_quantity,
    'message', 'Genel Depodan uretim birimine hammadde aktarimi aninda tamamlandi.',
    'changed', jsonb_build_object(
      'player', public.get_player_profile(v_player_id)
    )
  );
END;
$function$;

-- ----------------------------------------------------------------------------
-- 3. start_city_consolidated_transfer
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.start_city_consolidated_transfer(
  p_source_city_id uuid,
  p_target_entity_kind text,
  p_target_entity_id uuid,
  p_items jsonb,
  p_vehicle_id uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_default_brand uuid := '00000000-0000-0000-0000-000000000000'::uuid;
  v_player_id uuid := auth.uid();
  v_now timestamptz := timezone('utc', now());
  v_source_city public.cities%rowtype;
  v_target_city public.cities%rowtype;
  v_target_city_id uuid;
  v_target_warehouse record;
  v_target_store record;
  v_target_factory record;
  v_target_farm record;
  v_target_field record;
  v_target_empty_capacity numeric := 0;
  v_target_buyer_entity_kind text;
  v_target_buyer_warehouse_id uuid;
  v_target_buyer_store_id uuid;
  v_target_buyer_production_inventory_id uuid;
  v_vehicle public.logistics_vehicles%rowtype;
  v_npc_logistics_player_id uuid;
  v_is_rental boolean := false;
  v_transfer_id uuid;
  v_item jsonb;
  v_item_source_kind text;
  v_item_source_id uuid;
  v_item_id uuid;
  v_item_product_id text;
  v_item_quantity integer;
  v_item_quality integer;
  v_item_brand_id uuid;
  v_item_unit_cost numeric;
  v_item_unit_volume numeric;
  v_item_reserved_vol numeric;
  v_item_target_pi_id uuid;
  v_product public.products%rowtype;
  v_total_volume numeric := 0;
  v_total_quantity integer := 0;
  v_item_count integer := 0;
  v_distance_km numeric := 0;
  v_fuel_used numeric := 0;
  v_condition_loss numeric := 0;
  v_transport_cost numeric := 0;
  v_rental_cost numeric := 0;
  v_duration_seconds integer := 0;
  v_finish_at timestamptz;
  v_same_city boolean := false;
  v_player_cash numeric := 0;
  v_header_product_id text;
  v_header_quality integer := 1;
  v_header_brand uuid := v_default_brand;
BEGIN
  IF v_player_id IS NULL THEN
    RAISE EXCEPTION 'Oturum acilmamis.';
  END IF;

  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'Transfer kalemleri bos olamaz.';
  END IF;

  -- Kaynak şehri doğrula
  SELECT * INTO v_source_city FROM public.cities WHERE id = p_source_city_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Kaynak sehir bulunamadi.';
  END IF;

  -- Hedef tesisi doğrula ve hedef şehri/kapasiteyi bul
  IF p_target_entity_kind = 'warehouse' THEN
    SELECT w.*, c.id as c_city_id, c.map_position_x, c.map_position_y,
           wt.accepted_product_ids, wt.name as type_name
    INTO v_target_warehouse
    FROM public.warehouses w
    JOIN public.cities c ON c.id = w.city_id
    LEFT JOIN public.warehouse_types wt ON wt.id = w.warehouse_type_id
    WHERE w.id = p_target_entity_id AND w.player_id = v_player_id AND w.is_active = true
    FOR UPDATE OF w;

    IF NOT FOUND THEN RAISE EXCEPTION 'Hedef depo bulunamadi.'; END IF;
    v_target_city_id := v_target_warehouse.city_id;
    v_target_buyer_entity_kind := 'warehouse';
    v_target_buyer_warehouse_id := v_target_warehouse.id;

    -- Boş kapasite
    SELECT greatest(0, coalesce(v_target_warehouse.capacity, 0)
      - coalesce(sum(ws.quantity * coalesce(p.birim_hacim, 1)), 0)
      - coalesce(v_target_warehouse.reserved_capacity, 0))
    INTO v_target_empty_capacity
    FROM public.warehouse_slots ws
    JOIN public.products p ON p.id = ws.product_id
    WHERE ws.warehouse_id = v_target_warehouse.id;

  ELSIF p_target_entity_kind = 'store' THEN
    SELECT s.*, c.id as c_city_id, c.map_position_x, c.map_position_y
    INTO v_target_store
    FROM public.stores s
    JOIN public.cities c ON c.id = s.city_id
    WHERE s.id = p_target_entity_id AND s.player_id = v_player_id;

    IF NOT FOUND THEN RAISE EXCEPTION 'Hedef magaza bulunamadi.'; END IF;
    v_target_city_id := v_target_store.city_id;

    -- Mağaza hedefse o şehirdeki Genel Depoyu hedef olarak kullan
    SELECT w.*, c.map_position_x, c.map_position_y
    INTO v_target_warehouse
    FROM public.warehouses w
    JOIN public.cities c ON c.id = w.city_id
    WHERE w.player_id = v_player_id
      AND w.city_id = v_target_store.city_id
      AND (w.warehouse_kind IS NULL OR w.warehouse_kind IN ('general', 'normal'))
      AND w.is_active = true
    ORDER BY w.created_at ASC LIMIT 1
    FOR UPDATE OF w;

    IF NOT FOUND THEN RAISE EXCEPTION 'Hedef magazanin sehrinde Genel Depo bulunamadi.'; END IF;
    v_target_buyer_entity_kind := 'warehouse';
    v_target_buyer_warehouse_id := v_target_warehouse.id;

    SELECT greatest(0, coalesce(v_target_warehouse.capacity, 0)
      - coalesce(sum(ws.quantity * coalesce(p.birim_hacim, 1)), 0)
      - coalesce(v_target_warehouse.reserved_capacity, 0))
    INTO v_target_empty_capacity
    FROM public.warehouse_slots ws
    JOIN public.products p ON p.id = ws.product_id
    WHERE ws.warehouse_id = v_target_warehouse.id;

  ELSIF p_target_entity_kind = 'factory' THEN
    SELECT f.*, c.id as c_city_id, c.map_position_x, c.map_position_y
    INTO v_target_factory
    FROM public.factories f
    JOIN public.cities c ON c.id = f.city_id
    WHERE f.id = p_target_entity_id AND f.player_id = v_player_id
    FOR UPDATE OF f;

    IF NOT FOUND THEN RAISE EXCEPTION 'Hedef fabrika bulunamadi.'; END IF;
    v_target_city_id := v_target_factory.city_id;
    v_target_buyer_entity_kind := 'production_inventory';

    SELECT greatest(0, coalesce(v_target_factory.input_capacity, 0)
      - coalesce(sum(pi.quantity * coalesce(p.birim_hacim, 1)), 0))
    INTO v_target_empty_capacity
    FROM public.production_inventory pi
    JOIN public.products p ON p.id = pi.product_id
    WHERE pi.owner_kind = 'factory' AND pi.owner_id = v_target_factory.id AND pi.inventory_type = 'input';

  ELSIF p_target_entity_kind = 'farm' THEN
    SELECT fa.*, c.id as c_city_id, c.map_position_x, c.map_position_y
    INTO v_target_farm
    FROM public.farms fa
    JOIN public.cities c ON c.id = fa.city_id
    WHERE fa.id = p_target_entity_id AND fa.player_id = v_player_id
    FOR UPDATE OF fa;

    IF NOT FOUND THEN RAISE EXCEPTION 'Hedef tarla bulunamadi.'; END IF;
    v_target_city_id := v_target_farm.city_id;
    v_target_buyer_entity_kind := 'production_inventory';

    SELECT greatest(0, coalesce(v_target_farm.input_capacity, 0)
      - coalesce(sum(pi.quantity * coalesce(p.birim_hacim, 1)), 0))
    INTO v_target_empty_capacity
    FROM public.production_inventory pi
    JOIN public.products p ON p.id = pi.product_id
    WHERE pi.owner_kind = 'farm' AND pi.owner_id = v_target_farm.id AND pi.inventory_type = 'input';

  ELSIF p_target_entity_kind = 'field' THEN
    SELECT fi.*, c.id as c_city_id, c.map_position_x, c.map_position_y
    INTO v_target_field
    FROM public.fields fi
    JOIN public.cities c ON c.id = fi.city_id
    WHERE fi.id = p_target_entity_id AND fi.player_id = v_player_id
    FOR UPDATE OF fi;

    IF NOT FOUND THEN RAISE EXCEPTION 'Hedef ciftlik bulunamadi.'; END IF;
    v_target_city_id := v_target_field.city_id;
    v_target_buyer_entity_kind := 'production_inventory';

    SELECT greatest(0, coalesce(v_target_field.input_capacity, 0)
      - coalesce(sum(pi.quantity * coalesce(p.birim_hacim, 1)), 0))
    INTO v_target_empty_capacity
    FROM public.production_inventory pi
    JOIN public.products p ON p.id = pi.product_id
    WHERE pi.owner_kind = 'field' AND pi.owner_id = v_target_field.id AND pi.inventory_type = 'input';

  ELSE
    RAISE EXCEPTION 'Desteklenmeyen hedef turu: %', p_target_entity_kind;
  END IF;

  SELECT * INTO v_target_city FROM public.cities WHERE id = v_target_city_id;
  v_same_city := (p_source_city_id = v_target_city_id);

  -- KURAL: Şehirler arası transferde üretim birimleri kaynak veya hedef olamaz!
  IF NOT v_same_city THEN
    IF p_target_entity_kind IN ('factory', 'farm', 'field', 'mine') THEN
      RAISE EXCEPTION 'Uretim birimlerine sehirler arasi dogrudan transfer yapilamaz. Hammaddeyi once o sehrin Genel Deposu''na sevk etmelisiniz.';
    END IF;
  END IF;

  -- 1. ADIM: Kalemlerin toplam hacmini ve ilk kalem bilgilerini hesapla
  FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) LOOP
    v_item_source_kind := v_item ->> 'source_kind';
    v_item_product_id := v_item ->> 'product_id';
    v_item_quantity := greatest(coalesce((v_item ->> 'quantity')::integer, 0), 0);
    IF v_item_quantity <= 0 THEN
      RAISE EXCEPTION 'Transfer miktari 0 dan buyuk olmalidir.';
    END IF;

    -- Şehirler arasıysa kaynak bir üretim tesisi olamaz!
    IF NOT v_same_city AND v_item_source_kind IN ('factory', 'farm', 'field', 'mine') THEN
      RAISE EXCEPTION 'Uretim birimleri sehirler arasi dogrudan urun gonderemez. Urunlerinizi once ayni sehirdeki Genel Depoya aktarmalisiniz.';
    END IF;

    SELECT * INTO v_product FROM public.products WHERE id = v_item_product_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Urun bulunamadi: %', v_item_product_id; END IF;

    v_item_unit_volume := coalesce(v_product.birim_hacim, 1);
    v_item_reserved_vol := v_item_quantity * v_item_unit_volume;
    v_total_volume := v_total_volume + v_item_reserved_vol;
    v_total_quantity := v_total_quantity + v_item_quantity;
    v_item_count := v_item_count + 1;

    IF v_header_product_id IS NULL THEN
      v_header_product_id := v_item_product_id;
      v_header_quality := coalesce((v_item ->> 'quality_level')::integer, 1);
      v_header_brand := coalesce((v_item ->> 'brand_id')::uuid, v_default_brand);
    END IF;
  END LOOP;

  -- Hedef kapasite kontrolü
  IF v_total_volume > v_target_empty_capacity THEN
    RAISE EXCEPTION 'Hedef tesiste yeterli bos kapasite yok. Gerekli: % m3, Bos: % m3',
      round(v_total_volume, 2), round(v_target_empty_capacity, 2);
  END IF;

  -- Mesafe, süre ve araç kontrolü
  IF v_same_city THEN
    v_distance_km := 0;
    v_finish_at := v_now;
  ELSE
    IF p_vehicle_id IS NULL THEN
      RAISE EXCEPTION 'Sehirler arasi transfer icin arac secilmelidir.';
    END IF;

    v_npc_logistics_player_id := public.get_npc_logistics_player_id();
    SELECT * INTO v_vehicle
    FROM public.logistics_vehicles
    WHERE id = p_vehicle_id AND status = 'idle'
      AND (player_id = v_player_id OR (coalesce(is_available_for_rent, false) = true AND player_id = v_npc_logistics_player_id))
    FOR UPDATE;

    IF NOT FOUND THEN RAISE EXCEPTION 'Secilen arac kullanima uygun degil.'; END IF;
    v_is_rental := (v_vehicle.player_id <> v_player_id);

    -- Kapasite kontrolü
    IF coalesce(v_vehicle.capacity, 0) < ceil(v_total_volume) THEN
      RAISE EXCEPTION 'Secilen aracin kapasitesi yetersiz. Aracin kapasitesi: % m3, Yuk: % m3',
        v_vehicle.capacity, ceil(v_total_volume);
    END IF;

    -- Mesafe hesabı
    v_distance_km := round(
      (6371 * 2 * asin(sqrt(power(sin(radians(coalesce(v_target_city.map_position_x, 0) - coalesce(v_source_city.map_position_x, 0)) / 2), 2) + cos(radians(coalesce(v_source_city.map_position_x, 0))) * cos(radians(coalesce(v_target_city.map_position_x, 0))) * power(sin(radians(coalesce(v_target_city.map_position_y, 0) - coalesce(v_source_city.map_position_y, 0)) / 2), 2))))::numeric, 2
    );

    IF coalesce(v_vehicle.speed_kmh, 0) <= 0 THEN RAISE EXCEPTION 'Arac hizi gecersiz.'; END IF;
    v_duration_seconds := greatest(60, ceil((greatest(v_distance_km, 1) / v_vehicle.speed_kmh) * 120)::integer);
    v_finish_at := v_now + make_interval(secs => v_duration_seconds);

    v_fuel_used := round(v_distance_km * coalesce(v_vehicle.fuel_rate, 0), 2);
    v_condition_loss := greatest(1, ceil(v_distance_km / 200.0));
    v_transport_cost := CASE WHEN v_is_rental THEN round(v_distance_km * coalesce(v_vehicle.rental_price, 0), 2) ELSE round(v_fuel_used * coalesce(v_vehicle.fuel_cost, 0), 2) END;
    v_rental_cost := CASE WHEN v_is_rental THEN v_transport_cost ELSE 0 END;

    IF coalesce(v_vehicle.current_fuel, 0) < ceil(v_fuel_used) THEN
      RAISE EXCEPTION 'Aracta yeterli yakit yok. Gerekli: %, Mevcut: %', ceil(v_fuel_used), v_vehicle.current_fuel;
    END IF;
    IF coalesce(v_vehicle.condition, 0) <= 0 THEN
      RAISE EXCEPTION 'Aracin bakimi yetersiz.';
    END IF;

    IF v_is_rental AND v_rental_cost > 0 THEN
      SELECT cash INTO v_player_cash FROM public.players WHERE id = v_player_id FOR UPDATE;
      IF coalesce(v_player_cash, 0) < v_rental_cost THEN
        RAISE EXCEPTION 'Kiralama bedeli icin nakit yetersiz: % TL', v_rental_cost;
      END IF;
      UPDATE public.players SET cash = cash - v_rental_cost WHERE id = v_player_id;
    END IF;

    UPDATE public.logistics_vehicles
    SET status = 'on_route',
        current_fuel = greatest(current_fuel - ceil(v_fuel_used), 0),
        condition = greatest(condition - ceil(v_condition_loss), 0),
        updated_at = v_now
    WHERE id = v_vehicle.id;
  END IF;

  -- 2. ADIM: Transfer ana kaydını oluştur
  INSERT INTO public.logistics_transfers (
    buyer_player_id, seller_player_id, buyer_warehouse_id, buyer_store_id, buyer_production_inventory_id,
    logistics_vehicle_id, vehicle_owner_player_id, is_rental, product_id, quality_level, quantity,
    unit_price, total_price, product_unit_volume, reserved_capacity_amount, distance_km, fuel_used,
    condition_loss, rental_cost, transport_cost, started_at, finish_at, status, transfer_type,
    seller_entity_kind, buyer_entity_kind, item_count, total_quantity, brand_id, created_at, updated_at
  ) VALUES (
    v_player_id, v_player_id, v_target_buyer_warehouse_id, v_target_buyer_store_id, v_target_buyer_production_inventory_id,
    p_vehicle_id, CASE WHEN p_vehicle_id IS NOT NULL THEN v_vehicle.player_id ELSE NULL END,
    v_is_rental, v_header_product_id, v_header_quality, v_total_quantity, 0, 0,
    greatest(v_total_volume, 0.0001), v_total_volume, v_distance_km, v_fuel_used,
    v_condition_loss, v_rental_cost, v_transport_cost, v_now, v_finish_at, 'in_transit',
    'city_consolidated_transfer', 'city_consolidated', v_target_buyer_entity_kind,
    v_item_count, v_total_quantity, v_header_brand, v_now, v_now
  ) RETURNING id INTO v_transfer_id;

  -- 3. ADIM: Kaynak tesislerden ürünleri eksilt ve transfer kalemlerini ekle
  FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) LOOP
    v_item_source_kind := v_item ->> 'source_kind';
    v_item_source_id := (v_item ->> 'source_id')::uuid;
    v_item_id := (v_item ->> 'item_id')::uuid;
    v_item_product_id := v_item ->> 'product_id';
    v_item_quantity := (v_item ->> 'quantity')::integer;
    v_item_quality := coalesce((v_item ->> 'quality_level')::integer, 1);
    v_item_brand_id := coalesce((v_item ->> 'brand_id')::uuid, v_default_brand);

    SELECT * INTO v_product FROM public.products WHERE id = v_item_product_id;
    v_item_unit_volume := coalesce(v_product.birim_hacim, 1);
    v_item_reserved_vol := v_item_quantity * v_item_unit_volume;

    -- Hedef depo için ürün kabul kontrolü (Özel depolar için)
    IF v_target_buyer_entity_kind = 'warehouse' AND v_target_warehouse.accepted_product_ids IS NOT NULL 
       AND trim(v_target_warehouse.accepted_product_ids) <> '' AND coalesce(v_target_warehouse.type_name, '') <> 'Genel Depo' THEN
      IF NOT (v_item_product_id = ANY(regexp_split_to_array(trim(v_target_warehouse.accepted_product_ids), '\\s*,\\s*'))) THEN
        RAISE EXCEPTION 'Hedef depo bu urunu kabul etmiyor: %', v_item_product_id;
      END IF;
    END IF;

    -- Kaynaktan eksiltme
    IF v_item_source_kind = 'warehouse' THEN
      DECLARE
        v_w_slot record;
      BEGIN
        SELECT * INTO v_w_slot FROM public.warehouse_slots WHERE id = v_item_id AND warehouse_id = v_item_source_id FOR UPDATE;
        IF NOT FOUND OR v_w_slot.quantity < v_item_quantity THEN
          RAISE EXCEPTION 'Depo slotunda yeterli stok yok: %', v_item_product_id;
        END IF;
        v_item_unit_cost := coalesce(v_w_slot.cost, 0);

        UPDATE public.warehouse_slots
        SET quantity = quantity - v_item_quantity, updated_at = v_now
        WHERE id = v_item_id;

        IF v_w_slot.quantity - v_item_quantity <= 0 AND coalesce(v_w_slot.pending_quantity, 0) <= 0 THEN
          DELETE FROM public.warehouse_slots WHERE id = v_item_id;
        END IF;
      END;

    ELSIF v_item_source_kind IN ('factory', 'farm', 'field', 'mine') THEN
      DECLARE
        v_p_slot record;
      BEGIN
        SELECT * INTO v_p_slot FROM public.production_inventory
        WHERE id = v_item_id AND owner_kind = v_item_source_kind AND owner_id = v_item_source_id AND inventory_type = 'output' FOR UPDATE;
        IF NOT FOUND OR v_p_slot.quantity < v_item_quantity THEN
          RAISE EXCEPTION 'Uretim tesisinde yeterli cikti stok yok: %', v_item_product_id;
        END IF;
        v_item_unit_cost := coalesce(v_p_slot.cost, 0);

        UPDATE public.production_inventory
        SET quantity = quantity - v_item_quantity, updated_at = v_now
        WHERE id = v_item_id;
      END;
    ELSE
      RAISE EXCEPTION 'Bilinmeyen kaynak turu: %', v_item_source_kind;
    END IF;

    -- Hedef bir fabrika, tarla veya çiftlik ise o ürünün ve kalitenin input inventory ID'sini bul
    IF p_target_entity_kind IN ('factory', 'farm', 'field') THEN
      SELECT pi.id INTO v_item_target_pi_id
      FROM public.production_inventory pi
      WHERE pi.owner_kind = p_target_entity_kind AND pi.owner_id = p_target_entity_id AND pi.inventory_type = 'input' AND pi.product_id = v_item_product_id
        AND (pi.quality_level = v_item_quality OR p_target_entity_kind IN ('farm', 'field'))
      LIMIT 1;

      IF v_item_target_pi_id IS NULL THEN
        RAISE EXCEPTION 'Hedef tesiste bu urun (%) ve kalite (Q%) icin uygun girdi alani bulunamadi.', v_item_product_id, v_item_quality;
      END IF;
    ELSE
      v_item_target_pi_id := NULL;
    END IF;

    -- Transfer kalemi ekle
    INSERT INTO public.logistics_transfer_items (
      transfer_id, source_warehouse_slot_id, product_id, quality_level, brand_id,
      quantity, unit_cost, unit_price, total_cost, total_price, product_unit_volume,
      reserved_capacity_amount, status, target_production_inventory_id, created_at, updated_at
    ) VALUES (
      v_transfer_id, CASE WHEN v_item_source_kind = 'warehouse' THEN v_item_id ELSE NULL END,
      v_item_product_id, v_item_quality, v_item_brand_id,
      v_item_quantity, v_item_unit_cost, 0, v_item_quantity * v_item_unit_cost, 0,
      v_item_unit_volume, v_item_reserved_vol, 'in_transit', v_item_target_pi_id, v_now, v_now
    );
  END LOOP;

  -- Hedef depoda rezerve kapasiteyi artır (yalnızca şehirler arasıysa)
  IF NOT v_same_city AND v_target_buyer_entity_kind = 'warehouse' AND v_target_warehouse.id IS NOT NULL THEN
    UPDATE public.warehouses
    SET reserved_capacity = coalesce(reserved_capacity, 0) + v_total_volume, updated_at = v_now
    WHERE id = v_target_warehouse.id;
  END IF;

  -- 4. ADIM: Aynı şehirse hemen teslim et!
  IF v_same_city THEN
    PERFORM public.complete_logistics_transfer(v_transfer_id);
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'transfer_id', v_transfer_id,
    'same_city', v_same_city,
    'mode', CASE WHEN v_same_city THEN 'instant' ELSE 'in_transit' END,
    'item_count', v_item_count,
    'total_quantity', v_total_quantity,
    'total_volume', v_total_volume,
    'distance_km', v_distance_km,
    'finish_at', v_finish_at,
    'message', CASE WHEN v_same_city THEN 'Sehir ici transfer aninda teslim edildi.' ELSE 'Sevkiyat yola cikarildi.' END
  );
END;
$function$;

-- ----------------------------------------------------------------------------
-- 4. get_city_consolidated_transfer_candidates
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_city_consolidated_transfer_candidates(
  p_source_city_id uuid,
  p_target_entity_kind text DEFAULT NULL::text,
  p_target_entity_id uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_player_id uuid := auth.uid();
  v_candidates jsonb := '[]'::jsonb;
  v_accepted_product_ids text[];
  v_target_city_id uuid;
  v_is_inter_city boolean := false;
BEGIN
  IF v_player_id IS NULL THEN
    RAISE EXCEPTION 'Oturum acilmamis.';
  END IF;

  -- Hedef tesisin şehrini ve kabul ettiği ürünleri belirle
  IF p_target_entity_kind = 'warehouse' AND p_target_entity_id IS NOT NULL THEN
    SELECT city_id INTO v_target_city_id FROM public.warehouses WHERE id = p_target_entity_id;
  ELSIF p_target_entity_kind = 'store' AND p_target_entity_id IS NOT NULL THEN
    SELECT s.city_id, string_to_array(st.accepted_product_ids, ',')
    INTO v_target_city_id, v_accepted_product_ids
    FROM public.stores s
    JOIN public.store_types st ON st.id = s.store_type_id
    WHERE s.id = p_target_entity_id;
  ELSIF p_target_entity_kind = 'factory' AND p_target_entity_id IS NOT NULL THEN
    SELECT f.city_id, array_agg(DISTINCT pi.product_id)
    INTO v_target_city_id, v_accepted_product_ids
    FROM public.factories f
    LEFT JOIN public.production_inventory pi ON pi.owner_kind = 'factory' AND pi.owner_id = f.id AND pi.inventory_type = 'input'
    WHERE f.id = p_target_entity_id
    GROUP BY f.city_id;
  ELSIF p_target_entity_kind = 'farm' AND p_target_entity_id IS NOT NULL THEN
    SELECT city_id INTO v_target_city_id FROM public.farms WHERE id = p_target_entity_id;
  ELSIF p_target_entity_kind = 'field' AND p_target_entity_id IS NOT NULL THEN
    SELECT city_id INTO v_target_city_id FROM public.fields WHERE id = p_target_entity_id;
  END IF;

  IF v_target_city_id IS NOT NULL AND v_target_city_id <> p_source_city_id THEN
    v_is_inter_city := true;
  END IF;

  WITH city_products AS (
    -- 1. Depolardaki Ürünler (Yalnızca aktif Genel Depolar - Her zaman listelenir)
    SELECT
      'warehouse'::text AS source_kind,
      'Depo'::text AS source_kind_display,
      w.id AS source_id,
      w.name AS source_name,
      ws.id AS item_id,
      ws.product_id,
      p.urun_adi AS product_name,
      p.urun_iconu AS product_icon,
      p.birim_hacim,
      ws.quantity,
      ws.quality_level,
      coalesce(ws.cost, 0)::numeric AS unit_cost,
      ws.brand_id,
      coalesce(b.brand_name, 'Standart') AS brand_name
    FROM public.warehouses w
    JOIN public.warehouse_slots ws ON ws.warehouse_id = w.id
    JOIN public.products p ON p.id = ws.product_id
    LEFT JOIN public.brand_companies b ON b.id = ws.brand_id
    WHERE w.player_id = v_player_id
      AND w.city_id = p_source_city_id
      AND w.is_active = true
      AND (w.warehouse_kind IS NULL OR w.warehouse_kind IN ('general', 'normal'))
      AND ws.quantity > 0
      AND (v_accepted_product_ids IS NULL OR ws.product_id = ANY(v_accepted_product_ids))

    UNION ALL

    -- 2. Fabrika Çıktı Ürünleri (YALNIZCA AYNI ŞEHİR TRANSFERİNDE LİSTELENİR)
    SELECT
      'factory'::text AS source_kind,
      'Fabrika'::text AS source_kind_display,
      f.id AS source_id,
      f.name AS source_name,
      pi.id AS item_id,
      pi.product_id,
      p.urun_adi AS product_name,
      p.urun_iconu AS product_icon,
      p.birim_hacim,
      pi.quantity,
      pi.quality_level,
      coalesce(pi.cost, 0)::numeric AS unit_cost,
      pi.brand_id,
      coalesce(b.brand_name, 'Standart') AS brand_name
    FROM public.factories f
    JOIN public.production_inventory pi ON pi.owner_kind = 'factory' AND pi.owner_id = f.id AND pi.inventory_type = 'output'
    JOIN public.products p ON p.id = pi.product_id
    LEFT JOIN public.brand_companies b ON b.id = pi.brand_id
    WHERE f.player_id = v_player_id
      AND f.city_id = p_source_city_id
      AND NOT v_is_inter_city
      AND pi.quantity > 0
      AND (v_accepted_product_ids IS NULL OR pi.product_id = ANY(v_accepted_product_ids))

    UNION ALL

    -- 3. Tarla Çıktı Ürünleri (YALNIZCA AYNI ŞEHİR TRANSFERİNDE LİSTELENİR)
    SELECT
      'farm'::text AS source_kind,
      'Tarla'::text AS source_kind_display,
      fa.id AS source_id,
      fa.name AS source_name,
      pi.id AS item_id,
      pi.product_id,
      p.urun_adi AS product_name,
      p.urun_iconu AS product_icon,
      p.birim_hacim,
      pi.quantity,
      pi.quality_level,
      coalesce(pi.cost, 0)::numeric AS unit_cost,
      pi.brand_id,
      coalesce(b.brand_name, 'Standart') AS brand_name
    FROM public.farms fa
    JOIN public.production_inventory pi ON pi.owner_kind = 'farm' AND pi.owner_id = fa.id AND pi.inventory_type = 'output'
    JOIN public.products p ON p.id = pi.product_id
    LEFT JOIN public.brand_companies b ON b.id = pi.brand_id
    WHERE fa.player_id = v_player_id
      AND fa.city_id = p_source_city_id
      AND NOT v_is_inter_city
      AND pi.quantity > 0
      AND (v_accepted_product_ids IS NULL OR pi.product_id = ANY(v_accepted_product_ids))

    UNION ALL

    -- 4. Çiftlik Çıktı Ürünleri (YALNIZCA AYNI ŞEHİR TRANSFERİNDE LİSTELENİR)
    SELECT
      'field'::text AS source_kind,
      'Çiftlik'::text AS source_kind_display,
      fld.id AS source_id,
      fld.name AS source_name,
      pi.id AS item_id,
      pi.product_id,
      p.urun_adi AS product_name,
      p.urun_iconu AS product_icon,
      p.birim_hacim,
      pi.quantity,
      pi.quality_level,
      coalesce(pi.cost, 0)::numeric AS unit_cost,
      pi.brand_id,
      coalesce(b.brand_name, 'Standart') AS brand_name
    FROM public.fields fld
    JOIN public.production_inventory pi ON pi.owner_kind = 'field' AND pi.owner_id = fld.id AND pi.inventory_type = 'output'
    JOIN public.products p ON p.id = pi.product_id
    LEFT JOIN public.brand_companies b ON b.id = pi.brand_id
    WHERE fld.player_id = v_player_id
      AND fld.city_id = p_source_city_id
      AND NOT v_is_inter_city
      AND pi.quantity > 0
      AND (v_accepted_product_ids IS NULL OR pi.product_id = ANY(v_accepted_product_ids))

    UNION ALL

    -- 5. Maden Çıktı Ürünleri (YALNIZCA AYNI ŞEHİR TRANSFERİNDE LİSTELENİR)
    SELECT
      'mine'::text AS source_kind,
      'Maden'::text AS source_kind_display,
      m.id AS source_id,
      m.name AS source_name,
      pi.id AS item_id,
      pi.product_id,
      p.urun_adi AS product_name,
      p.urun_iconu AS product_icon,
      p.birim_hacim,
      pi.quantity,
      pi.quality_level,
      coalesce(pi.cost, 0)::numeric AS unit_cost,
      pi.brand_id,
      coalesce(b.brand_name, 'Standart') AS brand_name
    FROM public.mines m
    JOIN public.production_inventory pi ON pi.owner_kind = 'mine' AND pi.owner_id = m.id AND pi.inventory_type = 'output'
    JOIN public.products p ON p.id = pi.product_id
    LEFT JOIN public.brand_companies b ON b.id = pi.brand_id
    WHERE m.player_id = v_player_id
      AND m.city_id = p_source_city_id
      AND NOT v_is_inter_city
      AND pi.quantity > 0
      AND (v_accepted_product_ids IS NULL OR pi.product_id = ANY(v_accepted_product_ids))
  )
  SELECT coalesce(jsonb_agg(
    jsonb_build_object(
      'source_kind', cp.source_kind,
      'source_kind_display', cp.source_kind_display,
      'source_id', cp.source_id,
      'source_name', cp.source_name,
      'item_id', cp.item_id,
      'product_id', cp.product_id,
      'product_name', cp.product_name,
      'product_icon', cp.product_icon,
      'birim_hacim', cp.birim_hacim,
      'quantity', cp.quantity,
      'quality_level', cp.quality_level,
      'unit_cost', cp.unit_cost,
      'brand_id', cp.brand_id,
      'brand_name', cp.brand_name
    )
    ORDER BY cp.source_kind, cp.source_name, cp.product_name
  ), '[]'::jsonb)
  INTO v_candidates
  FROM city_products cp;

  RETURN v_candidates;
END;
$function$;
