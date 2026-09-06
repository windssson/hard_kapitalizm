-- ============================================================================
-- MIGRATION: 2026-09-04_starter_pack_gift_system.sql
-- Amaç: Yeni başlayan oyunculara merkez şehir seçiminde:
--   1) Seçilen şehirde ücretsiz & anında 1 adet Genel Depo
--   2) Depoda 1. kalite 500 adet Domates ve 500 adet Biber (brandsız)
--   3) Seçilen şehirde ücretsiz & anında 1 adet Manav (2 slotlu)
--   4) Başlangıç parası: 20.000 TL, Başlangıç yıldızı (gold): 50
-- ============================================================================

-- 1. players tablosu varsayılanlarını ve starter_pack_claimed kolonunu güncelle
ALTER TABLE public.players ADD COLUMN IF NOT EXISTS starter_pack_claimed boolean DEFAULT false;
ALTER TABLE public.players ALTER COLUMN cash SET DEFAULT 20000;
ALTER TABLE public.players ALTER COLUMN gold SET DEFAULT 50;

-- 2. grant_starter_package fonksiyonunu oluştur
CREATE OR REPLACE FUNCTION public.grant_starter_package(p_player_id uuid, p_city_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_default_brand uuid := '00000000-0000-0000-0000-000000000000'::uuid;
  v_now timestamptz := timezone('utc', now());
  v_player public.players%rowtype;
  v_city public.cities%rowtype;
  v_warehouse_type public.warehouse_types%rowtype;
  v_manav_type public.store_types%rowtype;
  v_warehouse_id uuid;
  v_store_id uuid;
BEGIN
  IF p_player_id IS NULL OR p_city_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Gecersiz oyuncu veya sehir.');
  END IF;

  SELECT * INTO v_player FROM public.players WHERE id = p_player_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Oyuncu bulunamadi.');
  END IF;

  -- Zaten başlangıç paketi verildiyse tekrar verme
  IF coalesce(v_player.starter_pack_claimed, false) = true THEN
    RETURN jsonb_build_object('success', false, 'message', 'Baslangic paketi zaten tanimlanmis.', 'already_claimed', true);
  END IF;

  SELECT * INTO v_city FROM public.cities WHERE id = p_city_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Sehir bulunamadi.');
  END IF;

  -- Genel Depo Türü
  SELECT * INTO v_warehouse_type
  FROM public.warehouse_types
  WHERE id = '604e422b-e260-468a-9c42-bff5360547d7'
  LIMIT 1;

  IF NOT FOUND THEN
    SELECT * INTO v_warehouse_type FROM public.warehouse_types LIMIT 1;
  END IF;

  -- Manav Türü
  SELECT * INTO v_manav_type
  FROM public.store_types
  WHERE name = 'Manav'
  LIMIT 1;

  -- 1. Ücretsiz Genel Depo Kur
  INSERT INTO public.warehouses (
    player_id,
    warehouse_type_id,
    city_id,
    name,
    level,
    capacity,
    reserved_capacity,
    warehouse_kind,
    store_id,
    is_active,
    created_at,
    updated_at
  ) VALUES (
    p_player_id,
    v_warehouse_type.id,
    p_city_id,
    v_city.name || ' Genel Depo',
    1,
    coalesce(v_warehouse_type.base_capacity, 15000),
    0,
    'general',
    NULL,
    true,
    v_now,
    v_now
  ) RETURNING id INTO v_warehouse_id;

  -- 2. Depoya 500 Domates ve 500 Biber Başlangıç Stoğu Ekle (1. Kalite, Brandsız)
  INSERT INTO public.warehouse_slots (
    warehouse_id,
    slot_index,
    brand_id,
    product_id,
    quality_level,
    quantity,
    pending_quantity,
    cost,
    price,
    is_available_for_sale,
    created_at,
    updated_at
  ) VALUES (
    v_warehouse_id,
    1,
    v_default_brand,
    'DOMATES',
    1,
    500,
    0,
    1.0,
    0,
    false,
    v_now,
    v_now
  ), (
    v_warehouse_id,
    2,
    v_default_brand,
    'BIBER',
    1,
    500,
    0,
    1.0,
    0,
    false,
    v_now,
    v_now
  );

  -- 3. Ücretsiz Manav Kur (Eğer Manav türü varsa)
  IF v_manav_type.id IS NOT NULL THEN
    INSERT INTO public.stores (
      player_id,
      store_type_id,
      city_id,
      name,
      level,
      current_slot_count,
      max_slot_count,
      slot_capacity,
      is_active,
      created_at,
      updated_at
    ) VALUES (
      p_player_id,
      v_manav_type.id,
      p_city_id,
      v_city.name || ' Manavı',
      1,
      coalesce(v_manav_type.base_slot_count, 2),
      coalesce(v_manav_type.max_slot_count, 2),
      coalesce(v_manav_type.slot_capacity, 400),
      true,
      v_now,
      v_now
    ) RETURNING id INTO v_store_id;

    -- Manav rafları (2 slot)
    INSERT INTO public.store_slots (
      store_id,
      slot_index,
      product_id,
      quantity,
      quality_level,
      price,
      cost,
      capacity,
      boost_multiplier,
      pending_sale,
      is_active,
      created_at,
      updated_at
    ) VALUES (
      v_store_id,
      1,
      NULL,
      0,
      0,
      0,
      0,
      coalesce(v_manav_type.slot_capacity, 400),
      1.00,
      0,
      true,
      v_now,
      v_now
    ), (
      v_store_id,
      2,
      NULL,
      0,
      0,
      0,
      0,
      coalesce(v_manav_type.slot_capacity, 400),
      1.00,
      0,
      true,
      v_now,
      v_now
    );
  END IF;

  -- 4. Paketin verildiğini işaretle
  UPDATE public.players
  SET starter_pack_claimed = true
  WHERE id = p_player_id;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Baslangic paketi basariyla tanimlandi.',
    'warehouse_id', v_warehouse_id,
    'store_id', v_store_id,
    'city_name', v_city.name
  );
END;
$function$;

-- 3. ensure_player_record_exists fonksiyonunu güncelle (20.000 TL nakit, 50 yıldız)
CREATE OR REPLACE FUNCTION public.ensure_player_record_exists(p_user_id uuid, p_city_id uuid DEFAULT NULL::uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_player public.players%rowtype;
  v_created boolean := false;
  v_assigned_city_id uuid := p_city_id;
BEGIN
  IF auth.uid() IS NULL OR auth.uid() <> p_user_id THEN
    RAISE EXCEPTION 'Yetkisiz istek.';
  END IF;

  SELECT *
  INTO v_player
  FROM public.players
  WHERE id = p_user_id;

  IF NOT FOUND THEN
    IF v_assigned_city_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.cities WHERE id = v_assigned_city_id) THEN
      v_assigned_city_id := NULL;
    END IF;

    INSERT INTO public.players (
      id,
      player_name,
      company_name,
      avatar_id,
      level,
      experience,
      cash,
      gold,
      headquarters_city_id,
      starter_pack_claimed
    )
    VALUES (
      p_user_id,
      'Oyuncu_' || left(p_user_id::text, 4),
      'Yeni Holding',
      'ae1.webp',
      1,
      0,
      20000,
      50,
      v_assigned_city_id,
      false
    )
    RETURNING *
    INTO v_player;

    v_created := true;
  ELSIF p_city_id IS NOT NULL AND v_player.headquarters_city_id IS NULL THEN
    UPDATE public.players
    SET headquarters_city_id = p_city_id
    WHERE id = p_user_id
    RETURNING *
    INTO v_player;
  END IF;

  -- Eğer merkez şehir belirlenmişse ve başlangıç paketi verilmemişse hemen ver
  IF v_player.headquarters_city_id IS NOT NULL AND coalesce(v_player.starter_pack_claimed, false) = false THEN
    PERFORM public.grant_starter_package(p_user_id, v_player.headquarters_city_id);
    SELECT * INTO v_player FROM public.players WHERE id = p_user_id;
  END IF;

  RETURN jsonb_build_object(
    'created', v_created,
    'player', to_jsonb(v_player)
  );
END;
$function$;

-- 4. set_player_headquarters_city fonksiyonunu güncelle
CREATE OR REPLACE FUNCTION public.set_player_headquarters_city(p_city_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_player_id uuid := auth.uid();
  v_city_name text;
  v_starter_granted boolean := false;
  v_starter_res jsonb;
BEGIN
  IF v_player_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Oturum acilmamis.');
  END IF;

  SELECT name INTO v_city_name FROM public.cities WHERE id = p_city_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Gecersiz sehir.');
  END IF;

  UPDATE public.players
  SET headquarters_city_id = p_city_id
  WHERE id = v_player_id;

  -- Başlangıç paketi verilmemişse ver
  v_starter_res := public.grant_starter_package(v_player_id, p_city_id);
  IF (v_starter_res ->> 'success')::boolean = true THEN
    v_starter_granted := true;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Merkez sehir basariyla guncellendi.',
    'headquarters_city_id', p_city_id,
    'headquarters_city_name', v_city_name,
    'starter_package_granted', v_starter_granted
  );
END;
$function$;

-- 5. bootstrap_game_session fonksiyonunu güncelle
CREATE OR REPLACE FUNCTION public.bootstrap_game_session(p_city_id uuid DEFAULT NULL::uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_player_id uuid := auth.uid();
  v_player jsonb;
  v_logistics_state jsonb;
  v_production_result jsonb;
  v_transfer_result jsonb;
BEGIN
  IF v_player_id IS NULL THEN
    RAISE EXCEPTION 'Oturum acilmamis.';
  END IF;

  PERFORM public.ensure_player_record_exists(v_player_id, p_city_id);
  
  IF p_city_id IS NOT NULL THEN
    PERFORM public.set_player_headquarters_city(p_city_id);
  END IF;

  -- 1. Tamamlanma süresi dolmuş transferleri ve ihale teslimatlarını tamamla
  v_transfer_result := public.complete_due_market_transfers(v_player_id, 100);
  PERFORM public.process_tender_deliveries(v_player_id);
  PERFORM public.process_player_tenders(v_player_id);

  -- 2. Liderlik ve şirket değerini güncelle
  PERFORM public.refresh_player_leaderboard_stats(v_player_id);

  -- 3. Üretimleri işle
  v_production_result := public.process_player_production_entry(v_player_id);
  v_player := public.get_player_profile(v_player_id);
  v_logistics_state := public.get_logistics_entry_state();

  RETURN jsonb_build_object(
    'success', true,
    'player', v_player,
    'logistics_entry_state', v_logistics_state,
    'completed_transfers', v_transfer_result,
    'completed_due_building_boosts', v_production_result -> 'completed_due_building_boosts',
    'completed_due_building_upgrades', v_production_result -> 'completed_due_building_upgrades',
    'processed_production', v_production_result
  );
END;
$function$;
