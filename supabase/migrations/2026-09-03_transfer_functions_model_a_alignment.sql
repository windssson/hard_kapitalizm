-- ============================================================================
-- MIGRATION: 2026-09-03_transfer_functions_model_a_alignment.sql
-- Transfer Fonksiyonlarının Şehir Genel Depo (Model A) Mimarisine Uyumlanması:
-- 1. start_multi_logistics_transfer: 'store' kaynak/hedef olarak verilirse
--    doğrudan o ildeki aktif Genel Depo'ya yönlendirilir ve standart depo
--    rezervasyonu uygulanır (eski store_warehouse hataları engellendi).
-- 2. get_city_consolidated_transfer_source_cities: Sadece aktif Genel Depolar
--    kaynak olarak sayılır (deprecated depolar elendi).
-- 3. get_city_consolidated_transfer_candidates: Depo ürünlerinde sadece aktif
--    Genel Depolar listelenir.
-- 4. start_multi_production_to_warehouse_transfer: Hedef depo Genel Depo olarak
--    filtrelenir.
-- 5. start_multi_warehouse_to_production_transfer: Kaynak depo Genel Depo olarak
--    filtrelenir.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. start_multi_logistics_transfer: Genel Depo uyarlaması
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.start_multi_logistics_transfer(
  p_source_entity_kind text,
  p_source_entity_id uuid,
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
  v_npc_logistics_player_id uuid;
  v_now timestamptz := timezone('utc', now());
  v_source_warehouse record;
  v_target_warehouse record;
  v_source_store record;
  v_target_store record;
  v_vehicle public.logistics_vehicles%rowtype;
  v_transfer_id uuid;
  v_item jsonb;
  v_source_slot record;
  v_product public.products%rowtype;
  v_item_count integer := 0;
  v_total_quantity integer := 0;
  v_total_volume numeric := 0;
  v_total_price numeric := 0;
  v_transport_cost numeric := 0;
  v_rental_cost numeric := 0;
  v_distance_km numeric := 0;
  v_fuel_used numeric := 0;
  v_condition_loss numeric := 0;
  v_duration_seconds integer := 0;
  v_finish_at timestamptz;
  v_same_city boolean := false;
  v_mode text := 'instant';
  v_is_rental boolean := false;
  v_item_quantity integer;
  v_item_reserved_capacity numeric;
  v_target_used_capacity numeric;
  v_header_product_id text;
  v_header_quality_level integer;
  v_header_brand_id uuid;
  v_player_cash numeric := 0;
BEGIN
  IF v_player_id IS NULL THEN RAISE EXCEPTION 'Oturum acilmamis.'; END IF;
  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'Transfer kalemleri bos olamaz.';
  END IF;

  IF p_source_entity_kind NOT IN ('warehouse', 'store') THEN
    RAISE EXCEPTION 'Desteklenmeyen kaynak turu: %', p_source_entity_kind;
  END IF;
  IF p_target_entity_kind NOT IN ('warehouse', 'store') THEN
    RAISE EXCEPTION 'Desteklenmeyen hedef turu: %', p_target_entity_kind;
  END IF;

  -- Kaynak tesis tespiti
  IF p_source_entity_kind = 'warehouse' THEN
    SELECT w.*, c.map_position_x, c.map_position_y
    INTO v_source_warehouse
    FROM public.warehouses w
    JOIN public.cities c ON c.id = w.city_id
    WHERE w.id = p_source_entity_id
      AND w.player_id = v_player_id
      AND w.is_active = true
      AND (w.warehouse_kind IS NULL OR w.warehouse_kind IN ('general', 'normal'))
    FOR UPDATE;

    IF NOT FOUND THEN RAISE EXCEPTION 'Kaynak depo bulunamadi.'; END IF;
  ELSE
    SELECT * INTO v_source_store
    FROM public.stores
    WHERE id = p_source_entity_id AND player_id = v_player_id
    FOR UPDATE;

    IF NOT FOUND THEN RAISE EXCEPTION 'Kaynak magaza bulunamadi.'; END IF;

    -- Mağazanın bulunduğu ilin Genel Deposu kaynak kabul edilir
    SELECT w.*, c.map_position_x, c.map_position_y
    INTO v_source_warehouse
    FROM public.warehouses w
    JOIN public.cities c ON c.id = w.city_id
    WHERE w.city_id = v_source_store.city_id
      AND w.player_id = v_player_id
      AND w.is_active = true
      AND (w.warehouse_kind IS NULL OR w.warehouse_kind IN ('general', 'normal'))
    ORDER BY w.created_at ASC LIMIT 1
    FOR UPDATE;

    IF NOT FOUND THEN RAISE EXCEPTION 'Kaynak magazaya ait sehirde Genel Depo bulunamadi.'; END IF;
  END IF;

  -- Hedef tesis tespiti
  IF p_target_entity_kind = 'warehouse' THEN
    SELECT w.*, c.map_position_x, c.map_position_y
    INTO v_target_warehouse
    FROM public.warehouses w
    JOIN public.cities c ON c.id = w.city_id
    WHERE w.id = p_target_entity_id
      AND w.player_id = v_player_id
      AND w.is_active = true
      AND (w.warehouse_kind IS NULL OR w.warehouse_kind IN ('general', 'normal'))
    FOR UPDATE;

    IF NOT FOUND THEN RAISE EXCEPTION 'Hedef depo bulunamadi.'; END IF;
  ELSE
    SELECT * INTO v_target_store
    FROM public.stores
    WHERE id = p_target_entity_id AND player_id = v_player_id
    FOR UPDATE;

    IF NOT FOUND THEN RAISE EXCEPTION 'Hedef magaza bulunamadi.'; END IF;

    -- Mağazanın bulunduğu ilin Genel Deposu hedef kabul edilir
    SELECT w.*, c.map_position_x, c.map_position_y
    INTO v_target_warehouse
    FROM public.warehouses w
    JOIN public.cities c ON c.id = w.city_id
    WHERE w.city_id = v_target_store.city_id
      AND w.player_id = v_player_id
      AND w.is_active = true
      AND (w.warehouse_kind IS NULL OR w.warehouse_kind IN ('general', 'normal'))
    ORDER BY w.created_at ASC LIMIT 1
    FOR UPDATE;

    IF NOT FOUND THEN RAISE EXCEPTION 'Hedef magazanin sehrinde Genel Depo bulunamadi.'; END IF;
  END IF;

  IF v_source_warehouse.id = v_target_warehouse.id THEN
    RAISE EXCEPTION 'Kaynak ve hedef ayni depo olamaz.';
  END IF;

  v_item := p_items -> 0;
  IF v_item IS NULL THEN RAISE EXCEPTION 'Transfer kalemleri bos olamaz.'; END IF;

  SELECT ws.product_id, ws.quality_level, coalesce(ws.brand_id, v_default_brand)
  INTO v_header_product_id, v_header_quality_level, v_header_brand_id
  FROM public.warehouse_slots ws
  JOIN public.warehouses w ON w.id = ws.warehouse_id
  WHERE ws.id = (v_item ->> 'source_warehouse_slot_id')::uuid
    AND w.id = v_source_warehouse.id;

  IF coalesce(v_header_product_id, '') = '' THEN
    RAISE EXCEPTION 'Ilk transfer kalemi icin kaynak slotu bulunamadi.';
  END IF;

  v_same_city := (v_source_warehouse.city_id = v_target_warehouse.city_id);
  IF v_same_city THEN
    v_mode := 'instant';
    v_finish_at := v_now;
  ELSE
    v_mode := 'in_transit';
    IF p_vehicle_id IS NULL THEN
      RAISE EXCEPTION 'Sehirler arasi transfer icin arac secilmelidir.';
    END IF;

    v_npc_logistics_player_id := public.get_npc_logistics_player_id();
    SELECT * INTO v_vehicle
    FROM public.logistics_vehicles
    WHERE id = p_vehicle_id AND status = 'idle'
      AND (player_id = v_player_id OR (coalesce(is_available_for_rent, false) = true AND (player_id = v_npc_logistics_player_id OR public.logistics_vehicle_matches_route(route_city_a_id, route_city_b_id, v_source_warehouse.city_id, v_target_warehouse.city_id))))
    FOR UPDATE;

    IF NOT FOUND THEN RAISE EXCEPTION 'Secilen arac kullanima uygun degil.'; END IF;
    v_is_rental := (v_vehicle.player_id <> v_player_id);

    v_distance_km := round(
      (6371 * 2 * asin(sqrt(power(sin(radians(coalesce(v_target_warehouse.map_position_x, 0) - coalesce(v_source_warehouse.map_position_x, 0)) / 2), 2) + cos(radians(coalesce(v_source_warehouse.map_position_x, 0))) * cos(radians(coalesce(v_target_warehouse.map_position_x, 0))) * power(sin(radians(coalesce(v_target_warehouse.map_position_y, 0) - coalesce(v_source_warehouse.map_position_y, 0)) / 2), 2))))::numeric, 2
    );

    IF coalesce(v_vehicle.speed_kmh, 0) <= 0 THEN RAISE EXCEPTION 'Secilen aracin hizi gecersiz.'; END IF;
    v_duration_seconds := greatest(60, ceil((greatest(v_distance_km, 1) / v_vehicle.speed_kmh) * 120)::integer);
    v_finish_at := v_now + make_interval(secs => v_duration_seconds);
  END IF;

  INSERT INTO public.logistics_transfers (
    buyer_player_id, seller_player_id, buyer_warehouse_id, seller_warehouse_id, logistics_vehicle_id, vehicle_owner_player_id,
    is_rental, product_id, quality_level, quantity, unit_price, total_price, product_unit_volume, reserved_capacity_amount,
    distance_km, fuel_used, condition_loss, rental_cost, transport_cost, started_at, finish_at, status, buyer_store_id,
    transfer_type, seller_store_id, seller_entity_kind, buyer_entity_kind, item_count, total_quantity, brand_id, created_at, updated_at
  ) VALUES (
    v_player_id, v_player_id,
    v_target_warehouse.id,
    v_source_warehouse.id,
    p_vehicle_id, CASE WHEN p_vehicle_id IS NOT NULL THEN v_vehicle.player_id ELSE NULL END,
    v_is_rental, v_header_product_id, greatest(coalesce(v_header_quality_level, 1), 1), 1, 0, 0, 1, 0,
    v_distance_km, 0, 0, 0, 0, v_now, v_finish_at, 'in_transit',
    CASE WHEN p_target_entity_kind = 'store' THEN p_target_entity_id ELSE NULL END,
    CASE
      WHEN p_source_entity_kind = 'warehouse' AND p_target_entity_kind = 'warehouse' THEN 'warehouse_to_warehouse'
      WHEN p_source_entity_kind = 'warehouse' AND p_target_entity_kind = 'store' THEN 'warehouse_to_store'
      WHEN p_source_entity_kind = 'store' AND p_target_entity_kind = 'warehouse' THEN 'store_to_warehouse'
      ELSE 'internal_transfer'
    END,
    CASE WHEN p_source_entity_kind = 'store' THEN p_source_entity_id ELSE NULL END,
    p_source_entity_kind, p_target_entity_kind, 1, 0, coalesce(v_header_brand_id, v_default_brand), v_now, v_now
  ) RETURNING id INTO v_transfer_id;

  FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) LOOP
    v_item_quantity := greatest(coalesce((v_item ->> 'quantity')::integer, 0), 0);
    IF v_item_quantity <= 0 THEN RAISE EXCEPTION 'Transfer miktari 0 dan buyuk olmalidir.'; END IF;

    SELECT ws.*, w.player_id, w.store_id, w.city_id, w.warehouse_kind
    INTO v_source_slot
    FROM public.warehouse_slots ws
    JOIN public.warehouses w ON w.id = ws.warehouse_id
    WHERE ws.id = (v_item ->> 'source_warehouse_slot_id')::uuid
    FOR UPDATE;

    IF NOT FOUND THEN RAISE EXCEPTION 'Kaynak depo slotu bulunamadi.'; END IF;
    IF v_source_slot.player_id <> v_player_id THEN RAISE EXCEPTION 'Kaynak depo slotu oyuncuya ait degil.'; END IF;
    IF v_source_slot.warehouse_id <> v_source_warehouse.id THEN RAISE EXCEPTION 'Tum kalemler secilen kaynak depoya ait olmalidir.'; END IF;
    IF coalesce(v_source_slot.product_id, '') = '' THEN RAISE EXCEPTION 'Kaynak slotta urun bulunamadi.'; END IF;
    IF coalesce(v_source_slot.quantity, 0) < v_item_quantity THEN RAISE EXCEPTION 'Kaynak slotta yeterli stok yok.'; END IF;

    SELECT * INTO v_product FROM public.products WHERE id = v_source_slot.product_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Urun bulunamadi.'; END IF;

    v_item_reserved_capacity := v_item_quantity * coalesce(v_product.birim_hacim, 0);

    -- Hedef Genel Depoda kapasite kontrolü ve rezervasyon
    SELECT coalesce(sum((ws.quantity + coalesce(ws.pending_quantity, 0)) * coalesce(p.birim_hacim, 0)), 0)
    INTO v_target_used_capacity
    FROM public.warehouse_slots ws
    LEFT JOIN public.products p ON p.id = ws.product_id
    WHERE ws.warehouse_id = v_target_warehouse.id;

    IF v_target_used_capacity + coalesce(v_target_warehouse.reserved_capacity, 0) + v_item_reserved_capacity > coalesce(v_target_warehouse.capacity, 0) THEN
      RAISE EXCEPTION 'Hedef Genel Depoda yeterli rezerve kapasite yok. (Mevcut Doluluk: % m3, Gerekli: % m3, Kapasite: % m3)',
        round(v_target_used_capacity + coalesce(v_target_warehouse.reserved_capacity, 0), 2),
        round(v_item_reserved_capacity, 2),
        round(v_target_warehouse.capacity, 2);
    END IF;

    UPDATE public.warehouses
    SET reserved_capacity = coalesce(reserved_capacity, 0) + v_item_reserved_capacity,
        updated_at = v_now
    WHERE id = v_target_warehouse.id;

    v_target_warehouse.reserved_capacity := coalesce(v_target_warehouse.reserved_capacity, 0) + v_item_reserved_capacity;

    INSERT INTO public.logistics_transfer_items (
      transfer_id, source_warehouse_slot_id, target_warehouse_slot_id, product_id, quality_level, brand_id, quantity, unit_cost, unit_price, total_cost, total_price, product_unit_volume, reserved_capacity_amount, status, created_at, updated_at
    ) VALUES (
      v_transfer_id, v_source_slot.id, NULL, v_source_slot.product_id, v_source_slot.quality_level, coalesce(v_source_slot.brand_id, v_default_brand), v_item_quantity, coalesce(v_source_slot.cost, 0), 0, v_item_quantity * coalesce(v_source_slot.cost, 0), 0, coalesce(v_product.birim_hacim, 0), v_item_reserved_capacity, 'in_transit', v_now, v_now
    );

    UPDATE public.warehouse_slots
    SET quantity = quantity - v_item_quantity, updated_at = v_now
    WHERE id = v_source_slot.id;

    IF coalesce(v_source_slot.quantity, 0) - v_item_quantity <= 0 AND coalesce(v_source_slot.pending_quantity, 0) <= 0 THEN
      DELETE FROM public.warehouse_slots WHERE id = v_source_slot.id;
    END IF;

    v_item_count := v_item_count + 1;
    v_total_quantity := v_total_quantity + v_item_quantity;
    v_total_volume := v_total_volume + v_item_reserved_capacity;
  END LOOP;

  IF v_item_count <= 0 THEN RAISE EXCEPTION 'Transfer icin gecerli kalem bulunamadi.'; END IF;

  IF NOT v_same_city THEN
    IF v_is_rental AND v_vehicle.player_id = v_npc_logistics_player_id THEN
      v_vehicle.capacity := greatest(coalesce(v_vehicle.capacity, 0), ceil(v_total_volume));
      UPDATE public.logistics_vehicles SET capacity = v_vehicle.capacity WHERE id = v_vehicle.id;
    END IF;

    IF coalesce(v_vehicle.capacity, 0) < ceil(v_total_volume) THEN
      RAISE EXCEPTION 'Secilen aracin kapasitesi bu transfer icin yetersiz.';
    END IF;

    v_fuel_used := round(v_distance_km * coalesce(v_vehicle.fuel_rate, 0), 2);
    v_condition_loss := greatest(1, ceil(v_distance_km / 200.0));
    v_transport_cost := CASE WHEN v_is_rental THEN round(v_distance_km * coalesce(v_vehicle.rental_price, 0), 2) ELSE round(v_fuel_used * coalesce(v_vehicle.fuel_cost, 0), 2) END;
    v_rental_cost := CASE WHEN v_is_rental THEN v_transport_cost ELSE 0 END;

    IF coalesce(v_vehicle.current_fuel, 0) < ceil(v_fuel_used) THEN RAISE EXCEPTION 'Aracta yeterli yakit yok.'; END IF;
    IF coalesce(v_vehicle.condition, 0) <= 0 THEN RAISE EXCEPTION 'Aracin bakimi yetersiz.'; END IF;

    IF v_is_rental AND v_rental_cost > 0 THEN
      SELECT cash INTO v_player_cash FROM public.players WHERE id = v_player_id FOR UPDATE;
      IF coalesce(v_player_cash, 0) < v_rental_cost THEN
        RAISE EXCEPTION 'Arac kiralama bedeli icin yeterli nakit yok. Gerekli: % TL', v_rental_cost;
      END IF;
      UPDATE public.players SET cash = cash - v_rental_cost WHERE id = v_player_id;
      PERFORM public.log_player_cash_change(v_player_id, -v_rental_cost, v_player_cash, 'vehicle_rental_paid', format('Lojistik kiralama bedeli odendi (Transfer: %s)', v_transfer_id), v_transfer_id, 'logistics_transfer');
      PERFORM public.process_logistics_vehicle_rental_payout(p_vehicle_id, v_transfer_id, v_player_id, v_rental_cost, v_distance_km);
    END IF;

    UPDATE public.logistics_vehicles
    SET status = 'on_route', current_fuel = greatest(current_fuel - ceil(v_fuel_used), 0), condition = greatest(condition - ceil(v_condition_loss), 0), updated_at = v_now
    WHERE id = v_vehicle.id;
  END IF;

  UPDATE public.logistics_transfers
  SET product_id = v_header_product_id, quality_level = greatest(coalesce(v_header_quality_level, 1), 1), quantity = greatest(v_total_quantity, 1), unit_price = 0, total_price = v_total_price,
      product_unit_volume = greatest(v_total_volume, 0.0001), reserved_capacity_amount = v_total_volume, distance_km = v_distance_km, fuel_used = v_fuel_used, condition_loss = v_condition_loss,
      rental_cost = v_rental_cost, transport_cost = v_transport_cost, finish_at = v_finish_at,
      transfer_type = CASE
        WHEN p_source_entity_kind = 'warehouse' AND p_target_entity_kind = 'warehouse' THEN 'warehouse_to_warehouse_multi'
        WHEN p_source_entity_kind = 'warehouse' AND p_target_entity_kind = 'store' THEN 'warehouse_to_store_multi'
        WHEN p_source_entity_kind = 'store' AND p_target_entity_kind = 'warehouse' THEN 'store_to_warehouse_multi'
        ELSE transfer_type
      END,
      item_count = v_item_count, total_quantity = v_total_quantity, brand_id = coalesce(v_header_brand_id, v_default_brand), updated_at = v_now
  WHERE id = v_transfer_id;

  IF v_same_city THEN
    PERFORM public.complete_logistics_transfer(v_transfer_id);
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'transfer_id', v_transfer_id,
    'mode', v_mode,
    'item_count', v_item_count,
    'total_quantity', v_total_quantity,
    'reserved_capacity_amount', v_total_volume,
    'transport_cost', v_transport_cost,
    'finish_at', v_finish_at,
    'changed', jsonb_build_object(
      'player', public.get_player_profile(v_player_id)
    )
  );
END;
$function$;

-- ----------------------------------------------------------------------------
-- 2. get_city_consolidated_transfer_source_cities: Sadece aktif Genel Depolar
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_city_consolidated_transfer_source_cities()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_player_id uuid := auth.uid();
  v_cities jsonb := '[]'::jsonb;
BEGIN
  IF v_player_id IS NULL THEN
    RAISE EXCEPTION 'Oturum acilmamis.';
  END IF;

  WITH city_entities AS (
    -- Depolar (Sadece aktif Genel Depolar)
    SELECT w.city_id, 'warehouse' as kind, w.id as entity_id,
           coalesce((SELECT sum(ws.quantity) FROM public.warehouse_slots ws WHERE ws.warehouse_id = w.id AND ws.quantity > 0), 0) as stock
    FROM public.warehouses w
    WHERE w.player_id = v_player_id
      AND w.is_active = true
      AND (w.warehouse_kind IS NULL OR w.warehouse_kind IN ('general', 'normal'))

    UNION ALL

    -- Fabrikalar (Çıktı Deposu)
    SELECT f.city_id, 'factory' as kind, f.id as entity_id,
           coalesce((SELECT sum(pi.quantity) FROM public.production_inventory pi WHERE pi.owner_kind = 'factory' AND pi.owner_id = f.id AND pi.inventory_type = 'output' AND pi.quantity > 0), 0) as stock
    FROM public.factories f
    WHERE f.player_id = v_player_id

    UNION ALL

    -- Tarlalar (Çıktı Deposu)
    SELECT fa.city_id, 'farm' as kind, fa.id as entity_id,
           coalesce((SELECT sum(pi.quantity) FROM public.production_inventory pi WHERE pi.owner_kind = 'farm' AND pi.owner_id = fa.id AND pi.inventory_type = 'output' AND pi.quantity > 0), 0) as stock
    FROM public.farms fa
    WHERE fa.player_id = v_player_id

    UNION ALL

    -- Çiftlikler (Çıktı Deposu)
    SELECT fld.city_id, 'field' as kind, fld.id as entity_id,
           coalesce((SELECT sum(pi.quantity) FROM public.production_inventory pi WHERE pi.owner_kind = 'field' AND pi.owner_id = fld.id AND pi.inventory_type = 'output' AND pi.quantity > 0), 0) as stock
    FROM public.fields fld
    WHERE fld.player_id = v_player_id

    UNION ALL

    -- Madenler (Çıktı Deposu)
    SELECT m.city_id, 'mine' as kind, m.id as entity_id,
           coalesce((SELECT sum(pi.quantity) FROM public.production_inventory pi WHERE pi.owner_kind = 'mine' AND pi.owner_id = m.id AND pi.inventory_type = 'output' AND pi.quantity > 0), 0) as stock
    FROM public.mines m
    WHERE m.player_id = v_player_id
  ),
  city_summaries AS (
    SELECT
      c.id AS city_id,
      c.name AS city_name,
      c.map_position_x,
      c.map_position_y,
      count(DISTINCT ce.entity_id) AS facility_count,
      sum(ce.stock)::integer AS total_stock
    FROM city_entities ce
    JOIN public.cities c ON c.id = ce.city_id
    GROUP BY c.id, c.name, c.map_position_x, c.map_position_y
    HAVING sum(ce.stock) > 0
  )
  SELECT coalesce(jsonb_agg(
    jsonb_build_object(
      'city_id', cs.city_id,
      'city_name', cs.city_name,
      'map_position_x', cs.map_position_x,
      'map_position_y', cs.map_position_y,
      'facility_count', cs.facility_count,
      'total_stock', cs.total_stock
    )
    ORDER BY cs.total_stock DESC, cs.city_name
  ), '[]'::jsonb)
  INTO v_cities
  FROM city_summaries cs;

  RETURN v_cities;
END;
$function$;

-- ----------------------------------------------------------------------------
-- 3. get_city_consolidated_transfer_candidates: Depo ürünlerinde sadece aktif Genel Depolar
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
BEGIN
  IF v_player_id IS NULL THEN
    RAISE EXCEPTION 'Oturum acilmamis.';
  END IF;

  -- Hedef tesis belirtildiyse kabul ettiği ürünleri belirle
  IF p_target_entity_kind = 'factory' AND p_target_entity_id IS NOT NULL THEN
    SELECT array_agg(DISTINCT pi.product_id)
    INTO v_accepted_product_ids
    FROM public.production_inventory pi
    WHERE pi.owner_kind = 'factory' AND pi.owner_id = p_target_entity_id AND pi.inventory_type = 'input';
  ELSIF p_target_entity_kind = 'store' AND p_target_entity_id IS NOT NULL THEN
    SELECT string_to_array(st.accepted_product_ids, ',')
    INTO v_accepted_product_ids
    FROM public.stores s
    JOIN public.store_types st ON st.id = s.store_type_id
    WHERE s.id = p_target_entity_id;
  END IF;

  WITH city_products AS (
    -- 1. Depolardaki Ürünler (Yalnızca aktif Genel Depolar)
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

    -- 2. Fabrika Çıktı Ürünleri
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
      AND pi.quantity > 0
      AND (v_accepted_product_ids IS NULL OR pi.product_id = ANY(v_accepted_product_ids))

    UNION ALL

    -- 3. Tarla Çıktı Ürünleri
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
      AND pi.quantity > 0
      AND (v_accepted_product_ids IS NULL OR pi.product_id = ANY(v_accepted_product_ids))

    UNION ALL

    -- 4. Çiftlik Çıktı Ürünleri
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
      AND pi.quantity > 0
      AND (v_accepted_product_ids IS NULL OR pi.product_id = ANY(v_accepted_product_ids))

    UNION ALL

    -- 5. Maden Çıktı Ürünleri
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

-- ----------------------------------------------------------------------------
-- 4. start_multi_production_to_warehouse_transfer: Hedef depoyu doğrula
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
  v_npc_logistics_player_id uuid;
  v_now timestamptz := timezone('utc', now());
  v_source_owner_player_id uuid;
  v_source_owner_city_id uuid;
  v_target_warehouse record;
  v_header_item jsonb;
  v_header_inventory record;
  v_vehicle logistics_vehicles%rowtype;
  v_transfer_id uuid;
  v_item jsonb;
  v_inventory record;
  v_product products%rowtype;
  v_same_city boolean := false;
  v_distance_km numeric := 0;
  v_fuel_used numeric := 0;
  v_condition_loss numeric := 0;
  v_transport_cost numeric := 0;
  v_rental_cost numeric := 0;
  v_duration_seconds integer := 0;
  v_finish_at timestamptz := v_now;
  v_total_volume numeric := 0;
  v_total_quantity integer := 0;
  v_item_count integer := 0;
  v_target_used_capacity numeric := 0;
  v_is_rental boolean := false;
  v_player_cash numeric := 0;
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

  v_same_city := (v_source_owner_city_id = v_target_warehouse.city_id);

  IF NOT v_same_city THEN
    IF p_vehicle_id IS NULL THEN RAISE EXCEPTION 'Sehirler arasi transfer icin arac secilmelidir.'; END IF;
    v_npc_logistics_player_id := public.get_npc_logistics_player_id();
    SELECT * INTO v_vehicle FROM public.logistics_vehicles
    WHERE id = p_vehicle_id AND status = 'idle'
      AND (player_id = v_player_id OR (coalesce(is_available_for_rent, false) = true AND (player_id = v_npc_logistics_player_id OR public.logistics_vehicle_matches_route(route_city_a_id, route_city_b_id, v_source_owner_city_id, v_target_warehouse.city_id))))
    FOR UPDATE;

    IF NOT FOUND THEN RAISE EXCEPTION 'Secilen arac kullanima uygun degil.'; END IF;
    v_is_rental := (v_vehicle.player_id <> v_player_id);

    IF v_is_rental AND v_vehicle.player_id = v_npc_logistics_player_id THEN
      v_vehicle.capacity := greatest(coalesce(v_vehicle.capacity, 0), ceil(v_total_volume));
      UPDATE public.logistics_vehicles SET capacity = v_vehicle.capacity WHERE id = v_vehicle.id;
    END IF;

    IF coalesce(v_vehicle.capacity, 0) < ceil(v_total_volume) THEN RAISE EXCEPTION 'Secilen aracin kapasitesi bu transfer icin yetersiz.'; END IF;
    IF coalesce(v_vehicle.speed_kmh, 0) <= 0 THEN RAISE EXCEPTION 'Secilen aracin hizi gecersiz.'; END IF;

    SELECT round((6371 * 2 * asin(sqrt(power(sin(radians(coalesce(v_target_warehouse.map_position_x, 0) - coalesce(sc.map_position_x, 0)) / 2), 2) + cos(radians(coalesce(sc.map_position_x, 0))) * cos(radians(coalesce(v_target_warehouse.map_position_x, 0))) * power(sin(radians(coalesce(v_target_warehouse.map_position_y, 0) - coalesce(sc.map_position_y, 0)) / 2), 2))))::numeric, 2)
    INTO v_distance_km FROM public.cities sc WHERE sc.id = v_source_owner_city_id;

    v_duration_seconds := greatest(60, ceil((greatest(v_distance_km, 1) / v_vehicle.speed_kmh) * 120)::integer);
    v_finish_at := v_now + make_interval(secs => v_duration_seconds);
    v_fuel_used := round(v_distance_km * coalesce(v_vehicle.fuel_rate, 0), 2);
    v_condition_loss := greatest(1, ceil(v_distance_km / 200.0));
    v_transport_cost := CASE WHEN v_is_rental THEN round(v_distance_km * coalesce(v_vehicle.rental_price, 0), 2) ELSE round(v_fuel_used * coalesce(v_vehicle.fuel_cost, 0), 2) END;
    v_rental_cost := CASE WHEN v_is_rental THEN v_transport_cost ELSE 0 END;

    IF coalesce(v_vehicle.current_fuel, 0) < ceil(v_fuel_used) THEN RAISE EXCEPTION 'Aracta yeterli yakit yok.'; END IF;
    IF coalesce(v_vehicle.condition, 0) <= 0 THEN RAISE EXCEPTION 'Aracin bakimi yetersiz.'; END IF;

    IF v_is_rental AND v_rental_cost > 0 THEN
      SELECT cash INTO v_player_cash FROM public.players WHERE id = v_player_id FOR UPDATE;
      IF coalesce(v_player_cash, 0) < v_rental_cost THEN RAISE EXCEPTION 'Arac kiralama bedeli icin yeterli nakit yok. Gerekli: % TL', v_rental_cost; END IF;
      UPDATE public.players SET cash = cash - v_rental_cost WHERE id = v_player_id;
      PERFORM public.log_player_cash_change(v_player_id, -v_rental_cost, v_player_cash, 'vehicle_rental_paid', format('Uretim nakliye kiralama bedeli odendi (Transfer: %s)', v_transfer_id), v_transfer_id, 'logistics_transfer');
      PERFORM public.process_logistics_vehicle_rental_payout(p_vehicle_id, v_transfer_id, v_player_id, v_rental_cost, v_distance_km);
    END IF;
  END IF;

  FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) LOOP
    SELECT * INTO v_inventory FROM public.production_inventory WHERE id = nullif(v_item ->> 'production_inventory_id', '')::uuid FOR UPDATE;
    SELECT * INTO v_product FROM public.products WHERE id = v_inventory.product_id;

    INSERT INTO public.logistics_transfer_items (
      transfer_id, source_warehouse_slot_id, target_warehouse_slot_id, product_id, quality_level, brand_id, quantity, unit_cost, unit_price, total_cost, total_price, product_unit_volume, reserved_capacity_amount, status, created_at, updated_at, completed_at
    ) VALUES (
      v_transfer_id, NULL, NULL, v_inventory.product_id, v_inventory.quality_level, coalesce(v_inventory.brand_id, v_default_brand), greatest(coalesce((v_item ->> 'quantity')::integer, 0), 0), coalesce(v_inventory.cost, 0), 0, greatest(coalesce((v_item ->> 'quantity')::integer, 0), 0) * coalesce(v_inventory.cost, 0), 0, coalesce(v_product.birim_hacim, 0), CASE WHEN v_same_city THEN 0 ELSE greatest(coalesce((v_item ->> 'quantity')::integer, 0), 0) * coalesce(v_product.birim_hacim, 0) END, 'in_transit', v_now, v_now, NULL
    );

    UPDATE public.production_inventory
    SET quantity = quantity - greatest(coalesce((v_item ->> 'quantity')::integer, 0), 0),
        pending_quantity = CASE WHEN inventory_type = 'input' THEN greatest(coalesce(pending_quantity, 0), 0) ELSE pending_quantity END
    WHERE id = v_inventory.id;
  END LOOP;

  UPDATE public.logistics_transfers
  SET logistics_vehicle_id = CASE WHEN v_same_city THEN NULL ELSE p_vehicle_id END,
    vehicle_owner_player_id = CASE WHEN v_same_city THEN NULL ELSE v_vehicle.player_id END,
    is_rental = CASE WHEN v_same_city THEN false ELSE v_is_rental END,
    quantity = greatest(v_total_quantity, 1), unit_price = CASE WHEN v_same_city THEN 0 ELSE v_rental_cost END, total_price = 0, product_unit_volume = greatest(v_total_volume, 0.0001), reserved_capacity_amount = CASE WHEN v_same_city THEN 0 ELSE v_total_volume END, distance_km = CASE WHEN v_same_city THEN 0 ELSE v_distance_km END, fuel_used = CASE WHEN v_same_city THEN 0 ELSE v_fuel_used END, condition_loss = CASE WHEN v_same_city THEN 0 ELSE v_condition_loss END, rental_cost = 0, transport_cost = CASE WHEN v_same_city THEN 0 ELSE v_transport_cost END, finish_at = v_finish_at, completed_at = NULL, status = 'in_transit', item_count = v_item_count, total_quantity = v_total_quantity, updated_at = v_now
  WHERE id = v_transfer_id;

  IF NOT v_same_city THEN
    UPDATE public.logistics_vehicles SET status = 'on_route', current_fuel = greatest(current_fuel - ceil(v_fuel_used), 0), condition = greatest(condition - ceil(v_condition_loss), 0), updated_at = v_now WHERE id = v_vehicle.id;
    UPDATE public.warehouses SET reserved_capacity = coalesce(reserved_capacity, 0) + v_total_volume, updated_at = v_now WHERE id = p_buyer_warehouse_id;
  ELSE
    PERFORM public.complete_logistics_transfer(v_transfer_id);
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'mode', CASE WHEN v_same_city THEN 'instant' ELSE 'in_transit' END,
    'transfer_id', v_transfer_id,
    'transport_cost', CASE WHEN v_same_city THEN 0 ELSE v_transport_cost END,
    'finish_at', v_finish_at,
    'item_count', v_item_count,
    'total_quantity', v_total_quantity,
    'message', CASE WHEN v_same_city THEN 'Coklu production cikis transferi aninda tamamlandi.' ELSE 'Coklu production cikis transferi baslatildi.' END,
    'changed', jsonb_build_object(
      'player', public.get_player_profile(v_player_id)
    )
  );
END;
$function$;

-- ----------------------------------------------------------------------------
-- 5. start_multi_warehouse_to_production_transfer: Kaynak depoyu doğrula
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
  v_npc_logistics_player_id uuid;
  v_now timestamptz := timezone('utc', now());
  v_source_warehouse record;
  v_target_owner_city_id uuid;
  v_header_item jsonb;
  v_header_inventory record;
  v_header_inv_id uuid;
  v_vehicle logistics_vehicles%rowtype;
  v_transfer_id uuid;
  v_item jsonb;
  v_inv_id uuid;
  v_slot_id uuid;
  v_source_slot record;
  v_inventory record;
  v_product products%rowtype;
  v_same_city boolean := false;
  v_distance_km numeric := 0;
  v_fuel_used numeric := 0;
  v_condition_loss numeric := 0;
  v_transport_cost numeric := 0;
  v_rental_cost numeric := 0;
  v_duration_seconds integer := 0;
  v_finish_at timestamptz := v_now;
  v_total_volume numeric := 0;
  v_total_quantity integer := 0;
  v_item_count integer := 0;
  v_item_quantity integer := 0;
  v_item_volume numeric := 0;
  v_is_rental boolean := false;
  v_player_cash numeric := 0;
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
  v_same_city := (v_source_warehouse.city_id = v_target_owner_city_id);

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
      v_item_quantity, coalesce(v_source_slot.cost, 0), 0, v_item_quantity * coalesce(v_source_slot.cost, 0), 0, coalesce(v_product.birim_hacim, 0.001), v_item_volume, 'in_transit', v_now, v_now, NULL
    );

    UPDATE public.warehouse_slots
    SET quantity = quantity - v_item_quantity, updated_at = v_now
    WHERE id = v_source_slot.id;

    IF coalesce(v_source_slot.quantity, 0) - v_item_quantity <= 0 AND coalesce(v_source_slot.pending_quantity, 0) <= 0 THEN
      DELETE FROM public.warehouse_slots WHERE id = v_source_slot.id;
    END IF;

    IF NOT v_same_city THEN
      UPDATE public.production_inventory
      SET pending_quantity = coalesce(pending_quantity, 0) + v_item_quantity, updated_at = v_now
      WHERE id = v_inventory.id;
    END IF;
  END LOOP;

  IF NOT v_same_city THEN
    IF p_vehicle_id IS NULL THEN RAISE EXCEPTION 'Sehirler arasi transfer icin arac secilmelidir.'; END IF;
    v_npc_logistics_player_id := public.get_npc_logistics_player_id();
    SELECT * INTO v_vehicle FROM public.logistics_vehicles
    WHERE id = p_vehicle_id AND status = 'idle'
      AND (player_id = v_player_id OR (coalesce(is_available_for_rent, false) = true AND (player_id = v_npc_logistics_player_id OR public.logistics_vehicle_matches_route(route_city_a_id, route_city_b_id, v_source_warehouse.city_id, v_target_owner_city_id))))
    FOR UPDATE;

    IF NOT FOUND THEN RAISE EXCEPTION 'Secilen arac kullanima uygun degil.'; END IF;
    v_is_rental := (v_vehicle.player_id <> v_player_id);

    IF v_is_rental AND v_vehicle.player_id = v_npc_logistics_player_id THEN
      v_vehicle.capacity := greatest(coalesce(v_vehicle.capacity, 0), ceil(v_total_volume));
      UPDATE public.logistics_vehicles SET capacity = v_vehicle.capacity WHERE id = v_vehicle.id;
    END IF;

    IF coalesce(v_vehicle.capacity, 0) < ceil(v_total_volume) THEN RAISE EXCEPTION 'Secilen aracin kapasitesi bu transfer icin yetersiz.'; END IF;
    IF coalesce(v_vehicle.speed_kmh, 0) <= 0 THEN RAISE EXCEPTION 'Secilen aracin hizi gecersiz.'; END IF;

    SELECT round((6371 * 2 * asin(sqrt(power(sin(radians(coalesce(tc.map_position_x, 0) - coalesce(v_source_warehouse.map_position_x, 0)) / 2), 2) + cos(radians(coalesce(v_source_warehouse.map_position_x, 0))) * cos(radians(coalesce(tc.map_position_x, 0))) * power(sin(radians(coalesce(tc.map_position_y, 0) - coalesce(v_source_warehouse.map_position_y, 0)) / 2), 2))))::numeric, 2)
    INTO v_distance_km FROM public.cities tc WHERE tc.id = v_target_owner_city_id;

    v_duration_seconds := greatest(60, ceil((greatest(v_distance_km, 1) / v_vehicle.speed_kmh) * 120)::integer);
    v_finish_at := v_now + make_interval(secs => v_duration_seconds);
    v_fuel_used := round(v_distance_km * coalesce(v_vehicle.fuel_rate, 0), 2);
    v_condition_loss := greatest(1, ceil(v_distance_km / 200.0));
    v_transport_cost := CASE WHEN v_is_rental THEN round(v_distance_km * coalesce(v_vehicle.rental_price, 0), 2) ELSE round(v_fuel_used * coalesce(v_vehicle.fuel_cost, 0), 2) END;
    v_rental_cost := CASE WHEN v_is_rental THEN v_transport_cost ELSE 0 END;

    IF coalesce(v_vehicle.current_fuel, 0) < ceil(v_fuel_used) THEN RAISE EXCEPTION 'Aracta yeterli yakit yok.'; END IF;
    IF coalesce(v_vehicle.condition, 0) <= 0 THEN RAISE EXCEPTION 'Aracin bakimi yetersiz.'; END IF;

    IF v_is_rental AND v_rental_cost > 0 THEN
      SELECT cash INTO v_player_cash FROM public.players WHERE id = v_player_id FOR UPDATE;
      IF coalesce(v_player_cash, 0) < v_rental_cost THEN RAISE EXCEPTION 'Arac kiralama bedeli icin yeterli nakit yok. Gerekli: % TL', v_rental_cost; END IF;
      UPDATE public.players SET cash = cash - v_rental_cost WHERE id = v_player_id;
      PERFORM public.log_player_cash_change(v_player_id, -v_rental_cost, v_player_cash, 'vehicle_rental_paid', format('Uretim girdi nakliye kiralama bedeli odendi (Transfer: %s)', v_transfer_id), v_transfer_id, 'logistics_transfer');
      PERFORM public.process_logistics_vehicle_rental_payout(p_vehicle_id, v_transfer_id, v_player_id, v_rental_cost, v_distance_km);
    END IF;

    UPDATE public.logistics_vehicles SET status = 'on_route', current_fuel = greatest(current_fuel - ceil(v_fuel_used), 0), condition = greatest(condition - ceil(v_condition_loss), 0), updated_at = v_now WHERE id = v_vehicle.id;
  END IF;

  UPDATE public.logistics_transfers
  SET logistics_vehicle_id = CASE WHEN v_same_city THEN NULL ELSE p_vehicle_id END,
    vehicle_owner_player_id = CASE WHEN v_same_city THEN NULL ELSE v_vehicle.player_id END,
    is_rental = CASE WHEN v_same_city THEN false ELSE v_is_rental END,
    quantity = greatest(v_total_quantity, 1), unit_price = CASE WHEN v_same_city THEN 0 ELSE v_rental_cost END, total_price = 0, product_unit_volume = greatest(v_total_volume, 0.0001), reserved_capacity_amount = CASE WHEN v_same_city THEN 0 ELSE v_total_volume END, distance_km = CASE WHEN v_same_city THEN 0 ELSE v_distance_km END, fuel_used = CASE WHEN v_same_city THEN 0 ELSE v_fuel_used END, condition_loss = CASE WHEN v_same_city THEN 0 ELSE v_condition_loss END, rental_cost = 0, transport_cost = CASE WHEN v_same_city THEN 0 ELSE v_transport_cost END, finish_at = v_finish_at, completed_at = NULL, status = 'in_transit', item_count = v_item_count, total_quantity = v_total_quantity, updated_at = v_now
  WHERE id = v_transfer_id;

  IF v_same_city THEN
    PERFORM public.complete_logistics_transfer(v_transfer_id);
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'mode', CASE WHEN v_same_city THEN 'instant' ELSE 'in_transit' END,
    'transfer_id', v_transfer_id,
    'transport_cost', CASE WHEN v_same_city THEN 0 ELSE v_transport_cost END,
    'finish_at', v_finish_at,
    'item_count', v_item_count,
    'total_quantity', v_total_quantity,
    'message', CASE WHEN v_same_city THEN 'Uretim birimine stok aktarimi aninda tamamlandi.' ELSE 'Uretim birimine stok transferi baslatildi.' END,
    'changed', jsonb_build_object(
      'player', public.get_player_profile(v_player_id)
    )
  );
END;
$function$;
