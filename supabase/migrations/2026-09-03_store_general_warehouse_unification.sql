-- ============================================================================
-- MIGRATION: 2026-09-03_store_general_warehouse_unification.sql
-- 1. Mağaza depolarının kaldırılması ve mağazaların doğrudan Şehir Genel Deposu ile entegre edilmesi.
-- 2. Mağaza (ve genel olarak tesis) inşasında o şehirde en az 1 aktif Genel Depo bulunması şartı.
-- 3. Mevcut mağaza depolarının stok kaybı olmadan Genel Depo'ya dönüştürülmesi / taşınması.
-- 4. open_store_detail_page, fill_store_shelves, transfer_store_warehouse_slot_to_store_slot,
--    transfer_store_slot_to_store_warehouse ve set_store_slot_product_from_warehouse_slot güncellemeleri.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- ADIM 1: MEVCUT MAĞAZA DEPOLARININ DÖNÜŞTÜRÜLMESİ VE STOKLARIN KORUNMASI
-- ----------------------------------------------------------------------------
DO $$
DECLARE
  v_genel_type_id uuid;
  v_store_wh record;
  v_target_wh_id uuid;
  v_ws record;
  v_max_slot integer;
BEGIN
  SELECT id INTO v_genel_type_id 
  FROM public.warehouse_types 
  WHERE name = 'Genel Depo' 
  LIMIT 1;

  FOR v_store_wh IN 
    SELECT w.id, w.player_id, w.city_id, w.store_id 
    FROM public.warehouses w 
    WHERE w.warehouse_kind = 'store'
  LOOP
    SELECT id INTO v_target_wh_id
    FROM public.warehouses
    WHERE player_id = v_store_wh.player_id
      AND city_id = v_store_wh.city_id
      AND id <> v_store_wh.id
      AND is_active = true
      AND (warehouse_kind IS NULL OR warehouse_kind IN ('general', 'normal'))
    ORDER BY created_at ASC
    LIMIT 1;

    IF v_target_wh_id IS NOT NULL THEN
      FOR v_ws IN 
        SELECT * FROM public.warehouse_slots WHERE warehouse_id = v_store_wh.id
      LOOP
        SELECT coalesce(max(slot_index), 0) + 1 INTO v_max_slot 
        FROM public.warehouse_slots 
        WHERE warehouse_id = v_target_wh_id;

        UPDATE public.warehouse_slots
        SET warehouse_id = v_target_wh_id,
            slot_index = v_max_slot,
            updated_at = timezone('utc', now())
        WHERE id = v_ws.id;
      END LOOP;

      UPDATE public.warehouses
      SET is_active = false,
          store_id = NULL,
          warehouse_kind = 'deprecated',
          updated_at = timezone('utc', now())
      WHERE id = v_store_wh.id;
    ELSE
      UPDATE public.warehouses
      SET warehouse_kind = 'general',
          name = 'Genel Depo',
          warehouse_type_id = coalesce(v_genel_type_id, warehouse_type_id),
          capacity = greatest(coalesce(capacity, 0), 15000),
          store_id = NULL,
          updated_at = timezone('utc', now())
      WHERE id = v_store_wh.id;
    END IF;
  END LOOP;
END $$;

-- ----------------------------------------------------------------------------
-- ADIM 2: start_building_construction GÜNCELLEMESİ (GENEL DEPO ŞARTI & STORE TEMİZLİĞİ)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.start_building_construction(
  p_player_id uuid,
  p_city_id uuid,
  p_building_kind text,
  p_type_id uuid,
  p_name text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_player public.players%rowtype;
  v_cost integer;
  v_required_level integer;
  v_construction_time_minutes integer;
  v_construction_id uuid;
  v_finish_at timestamptz;
  v_params jsonb;
  v_clean_name text;
BEGIN
  -- Vergi Bloğu Kontrolü
  IF public.is_player_tax_blocked(p_player_id) THEN
    RETURN jsonb_build_object('success', false, 'message', 'Vergi borcu limiti asildigi icin insaat baslatilamaz.');
  END IF;

  SELECT * INTO v_player FROM public.players WHERE id = p_player_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'message', 'Oyuncu bulunamadi.'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.cities WHERE id = p_city_id AND is_active = true) THEN
    RETURN jsonb_build_object('success', false, 'message', 'Sehir bulunamadi.');
  END IF;
  IF EXISTS (SELECT 1 FROM public.building_constructions WHERE player_id = p_player_id AND status = 'in_progress') THEN
    RETURN jsonb_build_object('success', false, 'message', 'Devam eden bir insaat zaten var.');
  END IF;

  v_clean_name := nullif(trim(p_name), '');

  -- KURAL: Depo haricindeki tüm binalar (store, factory, field, farm, mine) için o şehirde Genel Depo bulunması zorunludur!
  IF p_building_kind <> 'warehouse' THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.warehouses
      WHERE player_id = p_player_id
        AND city_id = p_city_id
        AND is_active = true
        AND (warehouse_kind IS NULL OR warehouse_kind IN ('general', 'normal'))
    ) THEN
      RETURN jsonb_build_object(
        'success', false,
        'code', 'GENEL_DEPO_GEREKLI',
        'message', 'Bu şehirde ticari faaliyet başlatabilmek için önce bir Genel Depo kurmalısınız.'
      );
    END IF;
  END IF;

  IF p_building_kind = 'store' THEN
    SELECT coalesce(cost, 0), coalesce(required_level, 1), coalesce(construction_time_minutes, 0),
      jsonb_build_object(
        'store_type_id', id,
        'city_id', p_city_id,
        'name', v_clean_name,
        'cost', coalesce(cost, 0),
        'required_level', coalesce(required_level, 1),
        'construction_time_minutes', coalesce(construction_time_minutes, 0),
        'level', 1,
        'current_slot_count', 0,
        'max_slot_count', coalesce(max_slot_count, 0),
        'slot_capacity', coalesce(slot_capacity, 0)
      )
    INTO v_cost, v_required_level, v_construction_time_minutes, v_params
    FROM public.store_types WHERE id = p_type_id;
  ELSIF p_building_kind = 'warehouse' THEN
    SELECT coalesce(cost, 0), coalesce(required_level, 1), coalesce(construction_time_minutes, 0),
      jsonb_build_object('warehouse_type_id', id, 'city_id', p_city_id, 'name', v_clean_name, 'cost', coalesce(cost, 0),
        'required_level', coalesce(required_level, 1), 'construction_time_minutes', coalesce(construction_time_minutes, 0),
        'level', 1, 'capacity', coalesce(base_capacity, 15000), 'reserved_capacity', 0)
    INTO v_cost, v_required_level, v_construction_time_minutes, v_params
    FROM public.warehouse_types WHERE id = p_type_id;
  ELSIF p_building_kind = 'factory' THEN
    SELECT coalesce(cost, 0), coalesce(required_level, 1), coalesce(construction_time_minutes, 0),
      jsonb_build_object('factory_type_id', id, 'city_id', p_city_id, 'name', v_clean_name, 'cost', coalesce(cost, 0),
        'required_level', coalesce(required_level, 1), 'construction_time_minutes', coalesce(construction_time_minutes, 0),
        'level', 1, 'quality_level', 0, 'boost_multiplier', 1.00, 'input_capacity', coalesce(input_capacity, 0), 'output_capacity', coalesce(output_capacity, 0))
    INTO v_cost, v_required_level, v_construction_time_minutes, v_params
    FROM public.factory_types WHERE id = p_type_id;
  ELSIF p_building_kind = 'field' THEN
    SELECT coalesce(cost, 0), coalesce(required_level, 1), coalesce(construction_time_minutes, 0),
      jsonb_build_object('field_type_id', id, 'city_id', p_city_id, 'name', v_clean_name, 'cost', coalesce(cost, 0),
        'required_level', coalesce(required_level, 1), 'construction_time_minutes', coalesce(construction_time_minutes, 0),
        'level', 1, 'current_slot_count', 0, 'max_slot_count', coalesce(max_slot_count, 5),
        'input_capacity', coalesce(input_capacity, 0), 'output_capacity', coalesce(output_capacity, 0))
    INTO v_cost, v_required_level, v_construction_time_minutes, v_params
    FROM public.field_types WHERE id = p_type_id;
  ELSIF p_building_kind = 'farm' THEN
    SELECT coalesce(cost, 0), coalesce(required_level, 1), coalesce(construction_time_minutes, 0),
      jsonb_build_object('farm_type_id', id, 'city_id', p_city_id, 'name', v_clean_name, 'cost', coalesce(cost, 0),
        'required_level', coalesce(required_level, 1), 'construction_time_minutes', coalesce(construction_time_minutes, 0),
        'level', 1, 'current_slot_count', 0, 'max_slot_count', coalesce(max_slot_count, 5),
        'input_capacity', coalesce(input_capacity, 0), 'output_capacity', coalesce(output_capacity, 0))
    INTO v_cost, v_required_level, v_construction_time_minutes, v_params
    FROM public.farm_types WHERE id = p_type_id;
  ELSIF p_building_kind = 'mine' THEN
    SELECT coalesce(cost, 0), coalesce(required_level, 1), coalesce(construction_time_minutes, 0),
      jsonb_build_object('mine_type_id', id, 'city_id', p_city_id, 'name', v_clean_name, 'cost', coalesce(cost, 0),
        'required_level', coalesce(required_level, 1), 'construction_time_minutes', coalesce(construction_time_minutes, 0),
        'level', 1, 'output_capacity', coalesce(output_capacity, 0))
    INTO v_cost, v_required_level, v_construction_time_minutes, v_params
    FROM public.mine_types WHERE id = p_type_id;
  ELSE
    RETURN jsonb_build_object('success', false, 'message', 'Desteklenmeyen yapi tipi.');
  END IF;

  IF v_cost IS NULL THEN RETURN jsonb_build_object('success', false, 'message', 'Yapi tipi bulunamadi.'); END IF;
  IF coalesce(v_player.level, 1) < v_required_level THEN RETURN jsonb_build_object('success', false, 'message', 'Seviye yetersiz.'); END IF;
  IF coalesce(v_player.cash, 0) < v_cost THEN RETURN jsonb_build_object('success', false, 'message', 'Yetersiz nakit.'); END IF;

  UPDATE public.players SET cash = cash - v_cost WHERE id = p_player_id;
  PERFORM public.log_player_cash_change(
    p_player_id, -v_cost, v_player.cash,
    'building_construction',
    format('Bina insaati: %s (%s)', coalesce(v_clean_name, p_building_kind), p_building_kind),
    p_city_id, 'city'
  );

  v_finish_at := timezone('utc', now()) + make_interval(mins => v_construction_time_minutes);
  INSERT INTO public.building_constructions (player_id, building_kind, params, status, started_at, finish_at, completed_at)
  VALUES (p_player_id, p_building_kind, v_params, 'in_progress', timezone('utc', now()), v_finish_at, null)
  RETURNING id INTO v_construction_id;

  RETURN jsonb_build_object(
    'success', true, 'construction_id', v_construction_id, 'building_kind', p_building_kind,
    'status', 'in_progress', 'started_at', timezone('utc', now()), 'finish_at', v_finish_at,
    'duration_minutes', v_construction_time_minutes, 'cost', v_cost
  );
END;
$function$;

-- ----------------------------------------------------------------------------
-- ADIM 3: complete_building_construction GÜNCELLEMESİ (MAĞAZA DEPOSU OLUŞTURMA İPTALİ)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.complete_building_construction(p_player_id uuid, p_construction_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_now timestamptz := timezone('utc'::text, now());
  v_construction public.building_constructions%rowtype;
  v_created_id uuid;
  v_building_display_name text;
  v_exp_result jsonb;
BEGIN
  SELECT *
  INTO v_construction
  FROM public.building_constructions
  WHERE id = p_construction_id
    AND player_id = p_player_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Insaat kaydi bulunamadi.';
  END IF;

  IF v_construction.status <> 'in_progress' THEN
    RAISE EXCEPTION 'Bu insaat tamamlanabilir durumda degil.';
  END IF;

  IF v_construction.finish_at > v_now THEN
    RAISE EXCEPTION 'Insaat henuz bitmedi.';
  END IF;

  v_building_display_name := coalesce(v_construction.params->>'name', 'Yeni Tesis');

  IF v_construction.building_kind = 'store' THEN
    INSERT INTO public.stores (
      player_id,
      store_type_id,
      city_id,
      name,
      level,
      current_slot_count,
      max_slot_count,
      slot_capacity,
      is_active
    )
    VALUES (
      p_player_id,
      (v_construction.params->>'store_type_id')::uuid,
      (v_construction.params->>'city_id')::uuid,
      v_construction.params->>'name',
      coalesce((v_construction.params->>'level')::integer, 1),
      coalesce((v_construction.params->>'current_slot_count')::integer, 0),
      coalesce((v_construction.params->>'max_slot_count')::integer, 0),
      coalesce((v_construction.params->>'slot_capacity')::integer, 0),
      true
    )
    RETURNING id INTO v_created_id;

  ELSIF v_construction.building_kind = 'warehouse' THEN
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
      is_active
    )
    VALUES (
      p_player_id,
      nullif(v_construction.params->>'warehouse_type_id', '')::uuid,
      (v_construction.params->>'city_id')::uuid,
      v_construction.params->>'name',
      coalesce((v_construction.params->>'level')::integer, 1),
      coalesce((v_construction.params->>'capacity')::numeric, 15000),
      0,
      'general',
      NULL,
      true
    )
    RETURNING id INTO v_created_id;

  ELSIF v_construction.building_kind = 'factory' THEN
    INSERT INTO public.factories (
      player_id,
      factory_type_id,
      city_id,
      name,
      level,
      product_id,
      quality_level,
      input_capacity,
      output_capacity,
      is_active
    )
    VALUES (
      p_player_id,
      (v_construction.params->>'factory_type_id')::uuid,
      (v_construction.params->>'city_id')::uuid,
      v_construction.params->>'name',
      coalesce((v_construction.params->>'level')::integer, 1),
      null,
      coalesce((v_construction.params->>'quality_level')::integer, 0),
      coalesce((v_construction.params->>'input_capacity')::integer, 0),
      coalesce((v_construction.params->>'output_capacity')::integer, 0),
      true
    )
    RETURNING id INTO v_created_id;

  ELSIF v_construction.building_kind = 'field' THEN
    INSERT INTO public.fields (
      player_id,
      field_type_id,
      city_id,
      name,
      level,
      current_slot_count,
      max_slot_count,
      input_capacity,
      output_capacity,
      is_active
    )
    VALUES (
      p_player_id,
      (v_construction.params->>'field_type_id')::uuid,
      (v_construction.params->>'city_id')::uuid,
      v_construction.params->>'name',
      coalesce((v_construction.params->>'level')::integer, 1),
      coalesce((v_construction.params->>'current_slot_count')::integer, 0),
      coalesce((v_construction.params->>'max_slot_count')::integer, 5),
      coalesce((v_construction.params->>'input_capacity')::integer, 0),
      coalesce((v_construction.params->>'output_capacity')::integer, 0),
      true
    )
    RETURNING id INTO v_created_id;

  ELSIF v_construction.building_kind = 'farm' THEN
    INSERT INTO public.farms (
      player_id,
      farm_type_id,
      city_id,
      name,
      level,
      current_slot_count,
      max_slot_count,
      input_capacity,
      output_capacity,
      is_active
    )
    VALUES (
      p_player_id,
      (v_construction.params->>'farm_type_id')::uuid,
      (v_construction.params->>'city_id')::uuid,
      v_construction.params->>'name',
      coalesce((v_construction.params->>'level')::integer, 1),
      coalesce((v_construction.params->>'current_slot_count')::integer, 0),
      coalesce((v_construction.params->>'max_slot_count')::integer, 5),
      coalesce((v_construction.params->>'input_capacity')::integer, 0),
      coalesce((v_construction.params->>'output_capacity')::integer, 0),
      true
    )
    RETURNING id INTO v_created_id;

  ELSIF v_construction.building_kind = 'mine' THEN
    INSERT INTO public.mines (
      player_id,
      mine_type_id,
      city_id,
      name,
      level,
      output_capacity,
      is_active
    )
    VALUES (
      p_player_id,
      (v_construction.params->>'mine_type_id')::uuid,
      (v_construction.params->>'city_id')::uuid,
      v_construction.params->>'name',
      coalesce((v_construction.params->>'level')::integer, 1),
      coalesce((v_construction.params->>'output_capacity')::integer, 0),
      true
    )
    RETURNING id INTO v_created_id;
  ELSE
    RAISE EXCEPTION 'Gecersiz yapi turu: %', v_construction.building_kind;
  END IF;

  UPDATE public.building_constructions
  SET status = 'completed',
      completed_at = v_now
  WHERE id = p_construction_id;

  v_exp_result := public.grant_player_experience(
    p_player_id,
    25,
    'building_construction',
    jsonb_build_object('building_kind', v_construction.building_kind)
  );

  PERFORM public.handle_building_construction_mission_progress(
    p_player_id,
    v_construction.building_kind,
    v_created_id
  );

  RETURN jsonb_build_object(
    'success', true,
    'construction_id', p_construction_id,
    'building_kind', v_construction.building_kind,
    'entity_id', v_created_id,
    'status', 'completed',
    'message', 'Insaat basariyla tamamlandi.',
    'experience_gain', v_exp_result
  );
END;
$function$;

-- ----------------------------------------------------------------------------
-- ADIM 4: open_store_detail_page GÜNCELLEMESİ (ŞEHİR GENEL DEPOSU İLE ENTEGRASYON)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.open_store_detail_page(p_store_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_player_id uuid := auth.uid();
  v_store stores%rowtype;
  v_store_json jsonb;
  v_sale_result jsonb;
  v_active_boost jsonb;
  v_active_upgrade jsonb;
  v_player jsonb;
  v_has_expired_upgrade boolean := false;
  v_processed boolean := false;
  v_completed_boost_count integer := 0;
  v_total_revenue numeric := 0;
  v_total_profit numeric := 0;
  v_total_sold_quantity integer := 0;
  v_elapsed_minutes_max integer := 0;
  v_items jsonb := '[]'::jsonb;
  v_now timestamptz := now();
  v_slot record;
  v_brand_level integer := 1;
  v_mkt_speed_mult numeric := 1.0;
  v_mkt_price_mult numeric := 1.0;
  v_mkt_speed_contrib numeric := 0.0;
  v_mkt_price_contrib numeric := 0.0;
  v_elapsed_minutes numeric;
  v_boost_bonus_minutes numeric;
  v_base_demand numeric;
  v_generated_demand numeric;
  v_available_demand numeric;
  v_price_ratio numeric;
  v_price_multiplier numeric;
  v_quality_multiplier numeric;
  v_brand_multiplier numeric;
  v_sold_qty integer;
  v_revenue numeric;
  v_profit numeric;
  v_pending_after numeric;
  v_performance_date date := timezone('Europe/Istanbul', v_now)::date;
  v_exp_result jsonb := null;
  v_tax_rate numeric := 0.0;
  v_effective_tax_rate numeric := 0.0;
  v_tax_amount numeric := 0.0;
  v_total_tax_amount numeric := 0.0;
  v_brand_price_tolerance numeric := 1.0;
  v_saturation_multiplier numeric := 1.0;
BEGIN
  IF v_player_id IS NULL THEN
    RAISE EXCEPTION 'Oturum acilmamis.';
  END IF;

  SELECT *
  INTO v_store
  FROM public.stores
  WHERE id = p_store_id
    AND player_id = v_player_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Magaza bulunamadi.';
  END IF;

  -- 1. Süresi dolan yükseltmeyi kontrol et
  SELECT exists (
    SELECT 1
    FROM public.building_upgrades
    WHERE player_id = v_player_id
      AND building_kind = 'store'
      AND entity_id = p_store_id
      AND status = 'in_progress'
      AND finish_at <= v_now
  ) INTO v_has_expired_upgrade;

  IF v_has_expired_upgrade THEN
    PERFORM public.complete_due_building_upgrades();
    SELECT *
    INTO v_store
    FROM public.stores
    WHERE id = p_store_id
      AND player_id = v_player_id
    FOR UPDATE;
  END IF;

  -- 2. Doygunluk katsayısı
  v_saturation_multiplier := public.calculate_store_saturation_multiplier(v_store.city_id, v_store.store_type_id);

  -- 3. Süresi dolan boost kontrolü
  SELECT count(*)
  INTO v_completed_boost_count
  FROM public.building_boosts
  WHERE player_id = v_player_id
    AND building_kind = 'store'
    AND entity_id = p_store_id
    AND status = 'active'
    AND finish_at <= v_now;

  IF v_completed_boost_count > 0 THEN
    PERFORM public.complete_due_building_boosts();
  END IF;

  -- 4. Satış döngüsü hesaplama
  IF coalesce(v_store.is_active, false) = false THEN
    v_sale_result := jsonb_build_object(
      'success', true,
      'processed', false,
      'message', 'Magaza aktif degil.',
      'completed_boost_count', v_completed_boost_count
    );
  ELSE
    FOR v_slot IN
      SELECT
        ss.id,
        ss.slot_index,
        ss.product_id,
        ss.quantity,
        ss.quality_level,
        ss.brand_id,
        ss.price,
        ss.cost,
        ss.boost_multiplier,
        ss.pending_sale,
        ss.last_sale_processed_at,
        p.urun_adi,
        p.baz_satis_fiyati,
        p.satis_adedi
      FROM public.store_slots ss
      JOIN public.products p ON p.id = ss.product_id
      WHERE ss.store_id = p_store_id
        AND ss.is_active = true
        AND ss.product_id IS NOT NULL
        AND ss.quality_level BETWEEN 1 AND 5
      ORDER BY ss.slot_index
      FOR UPDATE OF ss
    LOOP
      v_elapsed_minutes := extract(epoch from (v_now - v_slot.last_sale_processed_at)) / 60.0;

      IF v_elapsed_minutes < 10 THEN
        CONTINUE;
      END IF;

      SELECT
        coalesce(
          sum(
            greatest(
              extract(
                epoch from least(c.active_until, v_now)
                - greatest(c.created_at, v_slot.last_sale_processed_at)
              ) / 60.0,
              0
            ) * CASE c.campaign_type
              WHEN 'local' THEN 0.15
              WHEN 'regional' THEN 0.30
              WHEN 'global' THEN 0.50
              ELSE 0.0
            END
          ),
          0
        ),
        coalesce(
          sum(
            greatest(
              extract(
                epoch from least(c.active_until, v_now)
                - greatest(c.created_at, v_slot.last_sale_processed_at)
              ) / 60.0,
              0
            ) * CASE c.campaign_type
              WHEN 'local' THEN 0.05
              WHEN 'regional' THEN 0.10
              WHEN 'global' THEN 0.20
              ELSE 0.0
            END
          ),
          0
        )
      INTO v_mkt_speed_contrib, v_mkt_price_contrib
      FROM public.brand_marketing_campaigns c
      WHERE c.player_id = v_player_id
        AND c.created_at < v_now
        AND c.active_until > v_slot.last_sale_processed_at;

      IF v_elapsed_minutes > 0 THEN
        v_mkt_speed_mult := 1.0 + (v_mkt_speed_contrib / v_elapsed_minutes);
        v_mkt_price_mult := 1.0 + (v_mkt_price_contrib / v_elapsed_minutes);
      ELSE
        v_mkt_speed_mult := 1.0;
        v_mkt_price_mult := 1.0;
      END IF;

      v_processed := true;
      v_elapsed_minutes_max := greatest(v_elapsed_minutes_max, floor(v_elapsed_minutes)::int);
      v_quality_multiplier := 1 + (greatest(v_slot.quality_level, 1) - 1) * 0.10;

      v_brand_level := 1;
      IF v_slot.brand_id IS NOT NULL AND v_slot.brand_id <> '00000000-0000-0000-0000-000000000000'::uuid THEN
        SELECT coalesce(brand_level, 1)
        INTO v_brand_level
        FROM public.brand_companies
        WHERE id = v_slot.brand_id;
      END IF;

      v_brand_multiplier := CASE
        WHEN v_slot.brand_id IS NULL OR v_slot.brand_id = '00000000-0000-0000-0000-000000000000'::uuid THEN 1.0
        WHEN v_brand_level <= 1 THEN 1.05
        WHEN v_brand_level = 2 THEN 1.10
        WHEN v_brand_level = 3 THEN 1.15
        WHEN v_brand_level = 4 THEN 1.20
        ELSE 1.25
      END;

      v_brand_price_tolerance := 1.0;
      IF v_slot.brand_id IS NOT NULL AND v_slot.brand_id <> '00000000-0000-0000-0000-000000000000'::uuid THEN
        v_brand_price_tolerance := 1.25;
      END IF;

      SELECT
        coalesce(
          sum(
            greatest(
              extract(
                epoch from least(bb.finish_at, v_now)
                - greatest(bb.started_at, v_slot.last_sale_processed_at)
              ) / 60.0,
              0
            ) * (greatest(bb.multiplier, 1.0) - 1.0)
          ),
          0
        )
      INTO v_boost_bonus_minutes
      FROM public.building_boosts bb
      WHERE bb.player_id = v_player_id
        AND bb.building_kind = 'store'
        AND bb.entity_id = p_store_id
        AND bb.started_at < v_now
        AND bb.finish_at > v_slot.last_sale_processed_at;

      v_base_demand := (v_slot.satis_adedi::numeric / 6.0)
        * ((v_elapsed_minutes + v_boost_bonus_minutes) / 10.0)
        * v_mkt_speed_mult
        * v_saturation_multiplier;

      IF coalesce(v_slot.baz_satis_fiyati, 0) <= 0 THEN
        v_price_multiplier := 1.0;
      ELSE
        v_price_ratio := v_slot.price / (v_slot.baz_satis_fiyati * public.store_quality_price_multiplier(v_slot.quality_level) * v_mkt_price_mult * v_brand_price_tolerance);
        v_price_multiplier := greatest(0.05, 1.0 / (v_price_ratio ^ 1.5));
      END IF;

      v_generated_demand := v_base_demand * v_price_multiplier * v_quality_multiplier * v_brand_multiplier;
      v_available_demand := coalesce(v_slot.pending_sale, 0) + v_generated_demand;
      v_sold_qty := least(floor(v_available_demand)::int, v_slot.quantity);

      IF v_sold_qty > 0 THEN
        v_revenue := round(v_sold_qty * v_slot.price, 2);
        v_profit := round(v_revenue - (v_sold_qty * v_slot.cost), 2);
        v_pending_after := greatest(v_available_demand - v_sold_qty, 0);

        v_total_revenue := v_total_revenue + v_revenue;
        v_total_profit := v_total_profit + v_profit;
        v_total_sold_quantity := v_total_sold_quantity + v_sold_qty;

        UPDATE public.store_slots
        SET
          quantity = quantity - v_sold_qty,
          pending_sale = v_pending_after,
          last_sale_processed_at = v_now,
          updated_at = v_now
        WHERE id = v_slot.id;

        INSERT INTO public.store_daily_performance (
          performance_date,
          player_id,
          store_id,
          store_slot_id,
          slot_index,
          product_id,
          product_name,
          quality_level,
          sold_quantity,
          revenue,
          profit,
          sale_event_count,
          last_sale_at,
          updated_at
        ) VALUES (
          v_performance_date,
          v_player_id,
          p_store_id,
          v_slot.id,
          v_slot.slot_index,
          v_slot.product_id,
          v_slot.urun_adi,
          v_slot.quality_level,
          v_sold_qty,
          v_revenue,
          v_profit,
          1,
          v_now,
          v_now
        )
        ON CONFLICT (performance_date, store_id, store_slot_id)
        DO UPDATE SET
          slot_index = excluded.slot_index,
          product_id = excluded.product_id,
          product_name = excluded.product_name,
          quality_level = excluded.quality_level,
          sold_quantity = public.store_daily_performance.sold_quantity + excluded.sold_quantity,
          revenue = public.store_daily_performance.revenue + excluded.revenue,
          profit = public.store_daily_performance.profit + excluded.profit,
          sale_event_count = public.store_daily_performance.sale_event_count + 1,
          last_sale_at = excluded.last_sale_at,
          updated_at = v_now;

        v_items := v_items || jsonb_build_object(
          'store_slot_id', v_slot.id,
          'product_id', v_slot.product_id,
          'product_name', v_slot.urun_adi,
          'sold_quantity', v_sold_qty,
          'unit_price', v_slot.price,
          'unit_cost', v_slot.cost,
          'revenue', v_revenue,
          'profit', v_profit,
          'remaining_quantity', v_slot.quantity - v_sold_qty
        );
      ELSE
        UPDATE public.store_slots
        SET
          pending_sale = v_available_demand,
          last_sale_processed_at = v_now,
          updated_at = v_now
        WHERE id = v_slot.id;
      END IF;
    END LOOP;

    -- Vergi hesaplama (%10 KDV)
    IF v_total_revenue > 0 THEN
      v_tax_rate := 0.10;
      v_effective_tax_rate := v_tax_rate;
      v_tax_amount := round(v_total_revenue * v_effective_tax_rate, 2);
      v_total_tax_amount := v_tax_amount;

      INSERT INTO public.player_taxes (player_id, tax_debt, updated_at)
      VALUES (v_player_id, v_tax_amount, v_now)
      ON CONFLICT (player_id)
      DO UPDATE SET
        tax_debt = public.player_taxes.tax_debt + excluded.tax_debt,
        updated_at = v_now;
    END IF;

    -- Nakit ve XP
    IF v_total_revenue > 0 THEN
      UPDATE public.players
      SET cash = cash + v_total_revenue
      WHERE id = v_player_id;

      PERFORM public.log_player_cash_change(
        v_player_id,
        v_total_revenue,
        (SELECT cash FROM public.players WHERE id = v_player_id),
        'store_sale',
        format('%s magazasi satislari (%s urun)', v_store.name, v_total_sold_quantity),
        p_store_id,
        'store'
      );

      v_exp_result := public.grant_player_experience(
        v_player_id,
        greatest(round(v_total_revenue / 100)::integer, 1),
        'store_sale',
        jsonb_build_object(
          'store_id', p_store_id,
          'sold_quantity', v_total_sold_quantity,
          'revenue', v_total_revenue,
          'profit', v_total_profit
        )
      );
    END IF;

    v_sale_result := jsonb_build_object(
      'success', true,
      'processed', v_processed,
      'total_revenue', v_total_revenue,
      'total_profit', v_total_profit,
      'total_sold_quantity', v_total_sold_quantity,
      'elapsed_minutes', v_elapsed_minutes_max,
      'items', v_items,
      'experience_gain', v_exp_result,
      'tax_amount', v_total_tax_amount,
      'completed_boost_count', v_completed_boost_count
    );
  END IF;

  -- 5. Mağaza JSON oluşturma (O İLİN GENEL DEPOSU İLE BİRLİKTE)
  SELECT jsonb_build_object(
    'id', s.id,
    'player_id', s.player_id,
    'store_type_id', s.store_type_id,
    'city_id', s.city_id,
    'name', s.name,
    'level', s.level,
    'current_slot_count', s.current_slot_count,
    'max_slot_count', s.max_slot_count,
    'slot_capacity', s.slot_capacity,
    'is_active', s.is_active,
    'created_at', s.created_at,
    'updated_at', s.updated_at,
    'saturation_multiplier', round(v_saturation_multiplier::numeric, 4),
    'city', jsonb_build_object(
      'id', c.id,
      'name', c.name,
      'population', c.population
    ),
    'store_type', jsonb_build_object(
      'id', st.id,
      'name', st.name,
      'icon', st.icon,
      'cost', st.cost,
      'required_level', st.required_level,
      'construction_time_minutes', st.construction_time_minutes
    ),
    'summary', jsonb_build_object(
      'slot_count', coalesce(slot_data.slot_count, 0),
      'active_slot_count', coalesce(slot_data.active_slot_count, 0),
      'filled_slot_count', coalesce(slot_data.filled_slot_count, 0),
      'empty_slot_count', greatest(
        coalesce(slot_data.slot_count, 0)
        - coalesce(slot_data.filled_slot_count, 0),
        0
      ),
      'total_quantity', coalesce(slot_data.total_quantity, 0),
      'total_capacity', coalesce(slot_data.total_capacity, 0),
      'pending_quantity', coalesce(slot_data.pending_quantity, 0),
      'available_capacity', greatest(
        coalesce(slot_data.total_capacity, 0)
        - coalesce(slot_data.total_quantity, 0)
        - coalesce(slot_data.pending_quantity, 0),
        0
      ),
      'used_capacity_ratio', CASE
        WHEN coalesce(slot_data.total_capacity, 0) > 0 THEN
          round(
            (
              coalesce(slot_data.total_quantity, 0)
              + coalesce(slot_data.pending_quantity, 0)
            )::numeric / slot_data.total_capacity::numeric,
            4
          )
        ELSE 0
      END,
      'pending_sale_total', coalesce(slot_data.pending_sale_total, 0),
      'total_stock_cost_value', coalesce(slot_data.total_stock_cost_value, 0),
      'total_stock_sale_value', coalesce(slot_data.total_stock_sale_value, 0)
    ),
    'slots', coalesce(slot_data.slots, '[]'::jsonb),
    -- Şehir Genel Deposu Bilgisi
    'store_warehouse', general_warehouse_data.payload,
    'city_warehouse', general_warehouse_data.payload,
    'store_warehouse_id', general_warehouse_data.warehouse_id,
    'store_warehouse_name', general_warehouse_data.warehouse_name,
    'store_warehouse_capacity', general_warehouse_data.warehouse_capacity,
    'store_warehouse_used_capacity', general_warehouse_data.warehouse_used_capacity,
    'store_warehouse_slots', coalesce(general_warehouse_data.warehouse_slots, '[]'::jsonb)
  )
  INTO v_store_json
  FROM public.stores s
  JOIN public.cities c ON c.id = s.city_id
  JOIN public.store_types st ON st.id = s.store_type_id
  LEFT JOIN LATERAL (
    SELECT
      count(ss.id) AS slot_count,
      count(ss.id) FILTER (WHERE ss.is_active = true) AS active_slot_count,
      count(ss.id) FILTER (
        WHERE ss.product_id IS NOT NULL AND ss.quality_level BETWEEN 1 AND 5
      ) AS filled_slot_count,
      coalesce(sum(ss.quantity), 0) AS total_quantity,
      coalesce(sum(ss.capacity), 0) AS total_capacity,
      coalesce(sum(ss.pending_quantity), 0) AS pending_quantity,
      coalesce(sum(ss.pending_sale), 0) AS pending_sale_total,
      coalesce(sum(ss.quantity * ss.cost), 0) AS total_stock_cost_value,
      coalesce(sum(ss.quantity * ss.price), 0) AS total_stock_sale_value,
      coalesce(
        jsonb_agg(
          jsonb_build_object(
            'id', ss.id,
            'store_id', ss.store_id,
            'slot_index', ss.slot_index,
            'brand_id', ss.brand_id,
            'product_id', ss.product_id,
            'quantity', ss.quantity,
            'quality_level', ss.quality_level,
            'price', ss.price,
            'cost', ss.cost,
            'capacity', ss.capacity,
            'pending_quantity', ss.pending_quantity,
            'boost_multiplier', ss.boost_multiplier,
            'pending_sale', ss.pending_sale,
            'last_sale_processed_at', ss.last_sale_processed_at,
            'created_at', ss.created_at,
            'updated_at', ss.updated_at,
            'is_active', ss.is_active,
            'product', CASE
              WHEN p.id IS NULL THEN null
              ELSE jsonb_build_object(
                'id', p.id,
                'urun_adi', p.urun_adi,
                'urun_iconu', p.urun_iconu,
                'uretim_birimi', p.uretim_birimi,
                'baz_satis_fiyati', p.baz_satis_fiyati,
                'ortalama_fiyat', p.ortalama_fiyat,
                'en_dusuk_fiyat', p.en_dusuk_fiyat,
                'en_yuksek_fiyat', p.en_yuksek_fiyat,
                'birim_hacim', p.birim_hacim,
                'birim_agirlik', p.birim_agirlik,
                'satis_adedi', p.satis_adedi,
                'piyasadaki_stok', p.piyasadaki_stok,
                'satici_sayisi', p.satici_sayisi
              )
            END
          )
          ORDER BY ss.slot_index ASC
        ),
        '[]'::jsonb
      ) AS slots
    FROM public.store_slots ss
    LEFT JOIN public.products p ON p.id = ss.product_id
    WHERE ss.store_id = s.id
  ) slot_data ON true
  LEFT JOIN LATERAL (
    SELECT
      w.id AS warehouse_id,
      w.name AS warehouse_name,
      coalesce(w.capacity, 0) AS warehouse_capacity,
      coalesce(warehouse_summary.used_capacity, 0) AS warehouse_used_capacity,
      coalesce(warehouse_summary.slots, '[]'::jsonb) AS warehouse_slots,
      jsonb_build_object(
        'id', w.id,
        'name', w.name,
        'capacity', coalesce(w.capacity, 0),
        'used_capacity', coalesce(warehouse_summary.used_capacity, 0),
        'slots', coalesce(warehouse_summary.slots, '[]'::jsonb)
      ) AS payload
    FROM public.warehouses w
    LEFT JOIN LATERAL (
      SELECT
        coalesce(sum(ws.quantity * coalesce(p.birim_hacim, 0)), 0) AS used_capacity,
        coalesce(
          jsonb_agg(
            jsonb_build_object(
              'id', ws.id,
              'product_id', ws.product_id,
              'product_name', p.urun_adi,
              'product_icon', p.urun_iconu,
              'quality_level', ws.quality_level,
              'brand_id', ws.brand_id,
              'quantity', ws.quantity,
              'cost', ws.cost
            )
            ORDER BY ws.created_at ASC
          ),
          '[]'::jsonb
        ) AS slots
      FROM public.warehouse_slots ws
      LEFT JOIN public.products p ON p.id = ws.product_id
      WHERE ws.warehouse_id = w.id
    ) warehouse_summary ON true
    WHERE w.player_id = s.player_id
      AND w.city_id = s.city_id
      AND (w.warehouse_kind IS NULL OR w.warehouse_kind IN ('general', 'normal'))
      AND w.is_active = true
    ORDER BY w.created_at ASC
    LIMIT 1
  ) general_warehouse_data ON true
  WHERE s.player_id = v_player_id
    AND s.id = p_store_id;

  v_active_boost := public.get_player_active_building_boost('store', p_store_id);
  v_active_upgrade := public.get_player_active_building_upgrade('store', p_store_id);
  v_player := public.get_player_profile(v_player_id);

  RETURN jsonb_build_object(
    'success', true,
    'store', v_store_json,
    'active_boost', v_active_boost,
    'active_upgrade', v_active_upgrade,
    'sale_result', v_sale_result,
    'changed', jsonb_build_object(
      'player', v_player,
      'history_dirty', coalesce((v_sale_result ->>'processed')::boolean, false),
      'performance_dirty',
        coalesce((v_sale_result ->>'processed')::boolean, false)
        OR coalesce((v_sale_result ->>'completed_boost_count')::integer, 0) > 0,
      'tax_dirty', (v_total_tax_amount > 0)
    )
  );
END;
$$;

-- ----------------------------------------------------------------------------
-- ADIM 5: fill_store_shelves GÜNCELLEMESİ (ŞEHİR GENEL DEPOSUNDAN RAF DOLDURMA)
-- ----------------------------------------------------------------------------
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
    'message', CASE
      WHEN v_total_transferred_quantity > 0 THEN format('Raflara %s adet urun yerlestirildi.', v_total_transferred_quantity)
      ELSE 'Raflara aktarilacak uygun stok bulunamadi.'
    END
  );
END;
$function$;

-- ----------------------------------------------------------------------------
-- ADIM 6: transfer_store_warehouse_slot_to_store_slot (ŞEHİR GENEL DEPOSUNDAN RAFA AKTARIM)
-- ----------------------------------------------------------------------------
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
    'message', 'Stok Genel Depodan magazaya aktarildi.'
  );
END;
$function$;

-- ----------------------------------------------------------------------------
-- ADIM 7: transfer_store_slot_to_store_warehouse (RAFTAN ŞEHİR GENEL DEPOSUNA İADE)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.transfer_store_slot_to_store_warehouse(
  p_player_id uuid,
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
  v_general_warehouse record;
  v_target_slot record;
  v_empty_slot record;
  v_product record;
  v_required_capacity numeric := 0;
  v_used_capacity numeric := 0;
  v_next_slot_index integer := 1;
  v_target_slot_id uuid;
  v_target_quantity integer;
  v_target_cost numeric;
  v_target_slot_json jsonb;
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

  IF coalesce(v_store_slot.product_id, '') = '' THEN
    RAISE EXCEPTION 'Magaza slotunda urun bulunamadi.';
  END IF;

  IF coalesce(v_store_slot.quality_level, 0) < 1 OR coalesce(v_store_slot.quality_level, 0) > 5 THEN
    RAISE EXCEPTION 'Magaza slotunun kalite seviyesi gecersiz.';
  END IF;

  IF coalesce(v_store_slot.quantity, 0) < p_quantity THEN
    RAISE EXCEPTION 'Magaza slotunda yeterli stok yok.';
  END IF;

  -- Bu şehirdeki Genel Depoyu bul
  SELECT *
  INTO v_general_warehouse
  FROM public.warehouses
  WHERE player_id = p_player_id
    AND city_id = v_store_slot.city_id
    AND (warehouse_kind IS NULL OR warehouse_kind IN ('general', 'normal'))
    AND is_active = true
  ORDER BY created_at ASC
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Bu sehirde Genel Depo bulunamadi.';
  END IF;

  SELECT *
  INTO v_product
  FROM public.products
  WHERE id = v_store_slot.product_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Urun bulunamadi.';
  END IF;

  v_required_capacity := p_quantity * coalesce(v_product.birim_hacim, 0);

  SELECT coalesce(sum(ws.quantity * coalesce(p.birim_hacim, 0)), 0)
  INTO v_used_capacity
  FROM public.warehouse_slots ws
  LEFT JOIN public.products p ON p.id = ws.product_id
  WHERE ws.warehouse_id = v_general_warehouse.id;

  IF v_used_capacity + v_required_capacity > coalesce(v_general_warehouse.capacity, 0) THEN
    RAISE EXCEPTION 'Genel depoda yeterli kapasite yok.';
  END IF;

  SELECT *
  INTO v_target_slot
  FROM public.warehouse_slots
  WHERE warehouse_id = v_general_warehouse.id
    AND product_id = v_store_slot.product_id
    AND quality_level = v_store_slot.quality_level
    AND coalesce(brand_id, v_default_brand) = coalesce(v_store_slot.brand_id, v_default_brand)
  ORDER BY slot_index
  LIMIT 1
  FOR UPDATE;

  IF FOUND THEN
    v_target_slot_id := v_target_slot.id;
    v_target_quantity := coalesce(v_target_slot.quantity, 0) + p_quantity;
    v_target_cost := CASE
      WHEN v_target_quantity <= 0 THEN 0
      WHEN coalesce(v_target_slot.quantity, 0) <= 0 THEN coalesce(v_store_slot.cost, 0)
      ELSE round(((coalesce(v_target_slot.quantity, 0) * coalesce(v_target_slot.cost, 0)) + (p_quantity * coalesce(v_store_slot.cost, 0))) / v_target_quantity::numeric, 4)
    END;

    UPDATE public.warehouse_slots
    SET
      quantity = v_target_quantity,
      cost = v_target_cost,
      updated_at = v_now
    WHERE id = v_target_slot_id;
  ELSE
    SELECT *
    INTO v_empty_slot
    FROM public.warehouse_slots
    WHERE warehouse_id = v_general_warehouse.id
      AND product_id IS NULL
      AND quantity = 0
      AND quality_level = 0
    ORDER BY slot_index
    LIMIT 1
    FOR UPDATE;

    IF FOUND THEN
      v_target_slot_id := v_empty_slot.id;

      UPDATE public.warehouse_slots
      SET
        product_id = v_store_slot.product_id,
        quality_level = v_store_slot.quality_level,
        brand_id = coalesce(v_store_slot.brand_id, v_default_brand),
        quantity = p_quantity,
        cost = coalesce(v_store_slot.cost, 0),
        updated_at = v_now
      WHERE id = v_target_slot_id;
    ELSE
      SELECT coalesce(max(slot_index), 0) + 1
      INTO v_next_slot_index
      FROM public.warehouse_slots
      WHERE warehouse_id = v_general_warehouse.id;

      INSERT INTO public.warehouse_slots (
        warehouse_id,
        slot_index,
        brand_id,
        product_id,
        quality_level,
        quantity,
        cost,
        is_available_for_sale,
        price,
        created_at,
        updated_at
      )
      VALUES (
        v_general_warehouse.id,
        v_next_slot_index,
        coalesce(v_store_slot.brand_id, v_default_brand),
        v_store_slot.product_id,
        v_store_slot.quality_level,
        p_quantity,
        coalesce(v_store_slot.cost, 0),
        false,
        0,
        v_now,
        v_now
      )
      RETURNING id INTO v_target_slot_id;
    END IF;
  END IF;

  UPDATE public.store_slots
  SET
    quantity = quantity - p_quantity,
    updated_at = v_now
  WHERE id = v_store_slot.id;

  SELECT to_jsonb(ws.*)
  INTO v_target_slot_json
  FROM public.warehouse_slots ws
  WHERE ws.id = v_target_slot_id;

  RETURN jsonb_build_object(
    'success', true,
    'store_id', v_store_slot.store_id,
    'store_slot_id', v_store_slot.id,
    'warehouse_id', v_general_warehouse.id,
    'warehouse_slot_id', v_target_slot_id,
    'target_warehouse_slot', v_target_slot_json,
    'product_id', v_store_slot.product_id,
    'quality_level', v_store_slot.quality_level,
    'brand_id', coalesce(v_store_slot.brand_id, v_default_brand),
    'transferred_quantity', p_quantity,
    'remaining_store_slot_quantity', greatest(coalesce(v_store_slot.quantity, 0) - p_quantity, 0),
    'message', 'Stok magazadan Genel Depoya aktarildi.'
  );
END;
$function$;

-- ----------------------------------------------------------------------------
-- ADIM 8: set_store_slot_product_from_warehouse_slot (ŞEHİR GENEL DEPOSUNDAN ÜRÜN ATAMA)
-- ----------------------------------------------------------------------------
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
    cost = CASE
      WHEN coalesce(v_slot.product_id, '') = coalesce(v_source_slot.product_id, '')
       AND coalesce(v_slot.quality_level, 0) = coalesce(v_source_slot.quality_level, 0)
       AND coalesce(v_slot.brand_id, '00000000-0000-0000-0000-000000000000'::uuid) = coalesce(v_source_slot.brand_id, '00000000-0000-0000-0000-000000000000'::uuid)
      THEN cost ELSE coalesce(v_source_slot.cost, 0) END,
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
    'warehouse_slot_id', p_warehouse_slot_id
  );
END;
$function$;
