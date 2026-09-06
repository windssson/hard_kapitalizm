-- ============================================================================
-- Migration: 2026-09-07_phase2_stock_production_and_alerts.sql
-- Description:
-- Hard Kapitalizm Teknik İnceleme Raporu - Faz 2 (H01, H02, H04, H05, H06)
-- (Not: Kullanıcı talebi doğrultusunda H03 kapsam dışı bırakılmıştır)
-- 1. H01 & H02: clear_store_slot_product ve set_store_slot_product_from_warehouse_slot
--    - slot_index NOT NULL eksikliği giderildi
--    - Genel depo kapasite ve ağırlıklı maliyet hesaplama garantisi eklendi
--    - auth.uid() oturum kontrolü güçlendirildi
-- 2. H04: store_daily_performance UNIQUE kısıtı (performance_date, store_slot_id, product_id, quality_level, brand_id)
--    ve open_store_detail_page UPSERT güncellemesi
-- 3. H05: process_operational_alerts_push_notifications ihale bildirimi imza düzeltmesi (UUID entity_id)
-- 4. H06: process_factory_production_entry, process_field_farm_production_entry ve
--    process_mine_production_entry içinde çıkış stoğunu FOR UPDATE ile kilitleme
-- ============================================================================

-- ============================================================================
-- 1. H04: STORE_DAILY_PERFORMANCE TABLOSUNDA MÜKERRER UNIQUE KISITI KALDIRMA
-- (Teknik Rapor Madde 308: Aynı günlük slot tekilliğini kapsayan iki kısıttan
--  mükerrer olan (performance_date, store_id, store_slot_id) kaldırılarak
--  gereksiz indeks maliyeti azaltılır; date_slot_key korunur.)
-- ============================================================================

ALTER TABLE public.store_daily_performance
  DROP CONSTRAINT IF EXISTS store_daily_performance_performance_date_store_id_store_slo_key;

-- ============================================================================
-- 2. H05: İHALE PUSH BİLDİRİMİ İMZA DÜZELTMESİ
-- ============================================================================

CREATE OR REPLACE FUNCTION public.process_operational_alerts_push_notifications()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_rec record;
  v_sent_count integer := 0;
  v_now timestamptz := timezone('utc', now());
BEGIN
  -- 1. İHALE ACİL TESLİMAT (Son 2 saat, teslimat tamamlanmamış)
  FOR v_rec IN
    SELECT 
      pt.id AS tender_assignment_id,
      pt.player_id,
      pt.deadline_at,
      p.player_name,
      pr.urun_adi,
      pt.required_quantity,
      pt.delivered_quantity
    FROM public.player_tenders pt
    JOIN public.players p ON p.id = pt.player_id
    LEFT JOIN public.products pr ON pr.id = pt.product_id
    WHERE pt.status = 'active'
      AND pt.deadline_at > v_now
      AND pt.deadline_at <= (v_now + interval '2 hours')
      AND pt.delivered_quantity < pt.required_quantity
      AND NOT EXISTS (
        SELECT 1 FROM public.player_alert_push_logs l
        WHERE l.player_id = pt.player_id
          AND l.alert_key = ('tender_deadline_' || pt.id::text)
          AND l.last_sent_at > (v_now - interval '24 hours')
      )
  LOOP
    BEGIN
      -- H05 DÜZELTME: 6. parametre (p_entity_id) için jsonb yerine tender_assignment_id (uuid) gönderilir.
      PERFORM public.send_game_notification(
        v_rec.player_id,
        '⏰ İhale Süresi Azalıyor!',
        coalesce(v_rec.urun_adi, 'Ürün') || ' ihale teslimatınızın bitmesine 2 saatten az kaldı! Teminatın yanmaması için teslimatı tamamlayın.',
        'tender',
        'tender',
        v_rec.tender_assignment_id,
        true
      );

      INSERT INTO public.player_alert_push_logs (player_id, alert_key, last_sent_at)
      VALUES (v_rec.player_id, 'tender_deadline_' || v_rec.tender_assignment_id::text, v_now)
      ON CONFLICT (player_id, alert_key)
      DO UPDATE SET last_sent_at = v_now;

      v_sent_count := v_sent_count + 1;
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END LOOP;

  -- 2. VERGİ BLOKE UYARISI
  FOR v_rec IN
    SELECT 
      p.id AS player_id,
      pt.tax_debt,
      public.get_player_tax_limit(coalesce(p.level, 1)) AS tax_limit
    FROM public.players p
    JOIN public.player_taxes pt ON pt.player_id = p.id
    WHERE coalesce(pt.tax_debt, 0) > public.get_player_tax_limit(coalesce(p.level, 1))
      AND NOT EXISTS (
        SELECT 1 FROM public.player_alert_push_logs l
        WHERE l.player_id = p.id
          AND l.alert_key = 'tax_blocked'
          AND l.last_sent_at > (v_now - interval '12 hours')
      )
  LOOP
    BEGIN
      PERFORM public.send_game_notification(
        v_rec.player_id,
        '🚨 Şirket İşlemleri Kilitlendi!',
        'Vergi borcunuz yasal limiti (' || to_char(v_rec.tax_limit, 'FM999G999G999') || ' TL) aştığı için şirket faaliyetleri askıya alındı. Vergi dairesinden ödeme yapabilirsiniz.',
        'tax',
        'tax',
        null,
        true
      );

      INSERT INTO public.player_alert_push_logs (player_id, alert_key, last_sent_at)
      VALUES (v_rec.player_id, 'tax_blocked', v_now)
      ON CONFLICT (player_id, alert_key)
      DO UPDATE SET last_sent_at = v_now;

      v_sent_count := v_sent_count + 1;
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END LOOP;

  -- 3. FABRİKA HAMMADDE BİTTİ
  FOR v_rec IN
    SELECT 
      f.player_id,
      count(*) AS empty_count
    FROM public.factories f
    WHERE f.is_active = true
      AND f.product_id IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM public.production_inventory pi
        WHERE pi.owner_kind = 'factory'
          AND pi.owner_id = f.id
          AND pi.inventory_type = 'input'
          AND (pi.quantity + coalesce(pi.pending_quantity, 0)) > 0
      )
      AND NOT EXISTS (
        SELECT 1 FROM public.player_alert_push_logs l
        WHERE l.player_id = f.player_id
          AND l.alert_key = 'factory_no_input'
          AND l.last_sent_at > (v_now - interval '8 hours')
      )
    GROUP BY f.player_id
  LOOP
    BEGIN
      PERFORM public.send_game_notification(
        v_rec.player_id,
        '🏭 Fabrikada Hammadde Bitti: Üretim Durdu!',
        v_rec.empty_count || ' fabrikanızda hammadde tükendiği için üretim bantları durdu. Yeni hammadde sevkiyatı planlayın.',
        'factory',
        'factory',
        null,
        true
      );

      INSERT INTO public.player_alert_push_logs (player_id, alert_key, last_sent_at)
      VALUES (v_rec.player_id, 'factory_no_input', v_now)
      ON CONFLICT (player_id, alert_key)
      DO UPDATE SET last_sent_at = v_now;

      v_sent_count := v_sent_count + 1;
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END LOOP;

  -- 4. TARLA (farms) TOHUM / GÜBRE BİTTİ
  FOR v_rec IN
    SELECT 
      fa.player_id,
      count(DISTINCT fa.id) AS empty_count
    FROM public.farms fa
    JOIN public.production_slots ps ON ps.owner_kind = 'farm' AND ps.owner_id = fa.id
    JOIN public.products pr ON pr.id = ps.product_id
    WHERE fa.is_active = true
      AND ps.is_active = true
      AND ps.product_id IS NOT NULL
      AND (pr.hammadde_1_id IS NOT NULL OR pr.hammadde_2_id IS NOT NULL OR pr.hammadde_3_id IS NOT NULL)
      AND NOT EXISTS (
        SELECT 1 FROM public.production_inventory pi
        WHERE pi.owner_kind = 'farm'
          AND pi.owner_id = fa.id
          AND pi.inventory_type = 'input'
          AND (pi.quantity + coalesce(pi.pending_quantity, 0)) > 0
      )
      AND NOT EXISTS (
        SELECT 1 FROM public.player_alert_push_logs l
        WHERE l.player_id = fa.player_id
          AND l.alert_key = 'field_no_input'
          AND l.last_sent_at > (v_now - interval '8 hours')
      )
    GROUP BY fa.player_id
  LOOP
    BEGIN
      PERFORM public.send_game_notification(
        v_rec.player_id,
        '🌾 Tarlada Girdi Bitti: Ekim Durdu!',
        v_rec.empty_count || ' tarlanızda tohum veya gübre tükendiği için üretim durdu. Yeni girdi sevkiyatı planlayın.',
        'field',
        'farm',
        null,
        true
      );

      INSERT INTO public.player_alert_push_logs (player_id, alert_key, last_sent_at)
      VALUES (v_rec.player_id, 'field_no_input', v_now)
      ON CONFLICT (player_id, alert_key)
      DO UPDATE SET last_sent_at = v_now;

      v_sent_count := v_sent_count + 1;
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END LOOP;

  -- 5. ÇİFTLİK (fields) YEM / HAMMADDE BİTTİ
  FOR v_rec IN
    SELECT 
      fld.player_id,
      count(DISTINCT fld.id) AS empty_count
    FROM public.fields fld
    JOIN public.production_slots ps ON ps.owner_kind = 'field' AND ps.owner_id = fld.id
    JOIN public.products pr ON pr.id = ps.product_id
    WHERE fld.is_active = true
      AND ps.is_active = true
      AND ps.product_id IS NOT NULL
      AND (pr.hammadde_1_id IS NOT NULL OR pr.hammadde_2_id IS NOT NULL OR pr.hammadde_3_id IS NOT NULL)
      AND NOT EXISTS (
        SELECT 1 FROM public.production_inventory pi
        WHERE pi.owner_kind = 'field'
          AND pi.owner_id = fld.id
          AND pi.inventory_type = 'input'
          AND (pi.quantity + coalesce(pi.pending_quantity, 0)) > 0
      )
      AND NOT EXISTS (
        SELECT 1 FROM public.player_alert_push_logs l
        WHERE l.player_id = fld.player_id
          AND l.alert_key = 'farm_no_input'
          AND l.last_sent_at > (v_now - interval '8 hours')
      )
    GROUP BY fld.player_id
  LOOP
    BEGIN
      PERFORM public.send_game_notification(
        v_rec.player_id,
        '🐔 Çiftlikte Yem Bitti: Üretim Durdu!',
        v_rec.empty_count || ' çiftliğinizde hayvan yemi tükendiği için üretim durdu. Yeni yem sevkiyatı yapın.',
        'farm',
        'field',
        null,
        true
      );

      INSERT INTO public.player_alert_push_logs (player_id, alert_key, last_sent_at)
      VALUES (v_rec.player_id, 'farm_no_input', v_now)
      ON CONFLICT (player_id, alert_key)
      DO UPDATE SET last_sent_at = v_now;

      v_sent_count := v_sent_count + 1;
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END LOOP;

  -- 6. MAĞAZA RAFLARI BOŞALDI
  FOR v_rec IN
    SELECT 
      s.player_id,
      count(*) AS empty_store_count
    FROM public.stores s
    WHERE s.is_active = true
      AND NOT EXISTS (
        SELECT 1 FROM public.store_slots ss
        WHERE ss.store_id = s.id
          AND ss.is_active = true
          AND (ss.quantity + coalesce(ss.pending_quantity, 0)) > 0
      )
      AND NOT EXISTS (
        SELECT 1 FROM public.player_alert_push_logs l
        WHERE l.player_id = s.player_id
          AND l.alert_key = 'store_out_of_stock'
          AND l.last_sent_at > (v_now - interval '8 hours')
      )
    GROUP BY s.player_id
  LOOP
    BEGIN
      PERFORM public.send_game_notification(
        v_rec.player_id,
        '🏪 Mağaza Rafları Boşaldı!',
        v_rec.empty_store_count || ' mağazanızda tüm ürünler tükendi ve satış yapılamıyor. Rafları doldurmak için depodan sevkiyat yapın.',
        'store',
        'store',
        null,
        true
      );

      INSERT INTO public.player_alert_push_logs (player_id, alert_key, last_sent_at)
      VALUES (v_rec.player_id, 'store_out_of_stock', v_now)
      ON CONFLICT (player_id, alert_key)
      DO UPDATE SET last_sent_at = v_now;

      v_sent_count := v_sent_count + 1;
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END LOOP;

  -- 7. TESİS ÇIKIŞ DEPOSU DOLDU
  FOR v_rec IN
    SELECT 
      owner_player_id AS player_id,
      count(*) AS full_count
    FROM (
      SELECT m.player_id AS owner_player_id, m.id FROM public.mines m
      WHERE m.is_active = true AND m.output_capacity > 0
        AND (SELECT coalesce(sum(quantity + coalesce(pending_quantity, 0)), 0) FROM public.production_inventory pi WHERE pi.owner_kind = 'mine' AND pi.owner_id = m.id AND pi.inventory_type = 'output') >= m.output_capacity
      UNION ALL
      SELECT f.player_id AS owner_player_id, f.id FROM public.factories f
      WHERE f.is_active = true AND f.output_capacity > 0
        AND (SELECT coalesce(sum(quantity + coalesce(pending_quantity, 0)), 0) FROM public.production_inventory pi WHERE pi.owner_kind = 'factory' AND pi.owner_id = f.id AND pi.inventory_type = 'output') >= f.output_capacity
      UNION ALL
      SELECT fa.player_id AS owner_player_id, fa.id FROM public.farms fa
      WHERE fa.is_active = true AND fa.output_capacity > 0
        AND (SELECT coalesce(sum(quantity + coalesce(pending_quantity, 0)), 0) FROM public.production_inventory pi WHERE pi.owner_kind = 'farm' AND pi.owner_id = fa.id AND pi.inventory_type = 'output') >= fa.output_capacity
      UNION ALL
      SELECT fld.player_id AS owner_player_id, fld.id FROM public.fields fld
      WHERE fld.is_active = true AND fld.output_capacity > 0
        AND (SELECT coalesce(sum(quantity + coalesce(pending_quantity, 0)), 0) FROM public.production_inventory pi WHERE pi.owner_kind = 'field' AND pi.owner_id = fld.id AND pi.inventory_type = 'output') >= fld.output_capacity
    ) full_facilities
    WHERE NOT EXISTS (
      SELECT 1 FROM public.player_alert_push_logs l
      WHERE l.player_id = owner_player_id
        AND l.alert_key = 'production_output_full'
        AND l.last_sent_at > (v_now - interval '8 hours')
    )
    GROUP BY owner_player_id
  LOOP
    BEGIN
      PERFORM public.send_game_notification(
        v_rec.player_id,
        '⚠️ Tesis Deposu Doldu: Üretim Durdu!',
        v_rec.full_count || ' üretim tesisinizde ambar %100 doldu ve yeni üretim durduruldu. Ürünleri merkeze veya pazara transfer edin.',
        'mine',
        'facility',
        null,
        true
      );

      INSERT INTO public.player_alert_push_logs (player_id, alert_key, last_sent_at)
      VALUES (v_rec.player_id, 'production_output_full', v_now)
      ON CONFLICT (player_id, alert_key)
      DO UPDATE SET last_sent_at = v_now;

      v_sent_count := v_sent_count + 1;
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'alerts_sent', v_sent_count,
    'processed_at', v_now
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.process_operational_alerts_push_notifications() TO postgres, service_role;

-- ============================================================================
-- 3. H01 & H02: CLEAR_STORE_SLOT_PRODUCT (GÜVENLİ RAF İADESİ & KAPASİTE/MALİYET/SLOT GARANTİSİ)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.clear_store_slot_product(
  p_player_id uuid,
  p_store_slot_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_slot record;
  v_warehouse record;
  v_existing_wh_slot record;
  v_next_slot_index integer;
  v_used_capacity numeric := 0;
  v_unit_volume numeric := 0.1;
  v_incoming_volume numeric := 0;
  v_new_wh_qty integer;
  v_new_wh_cost numeric;
  v_now timestamptz := timezone('utc'::text, now());
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Yetkisiz erişim: Oturum açılmamış.';
  END IF;

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
    RAISE EXCEPTION 'Mağaza slotu bulunamadı.';
  END IF;

  IF v_slot.player_id <> auth.uid() OR (p_player_id IS NOT NULL AND p_player_id <> auth.uid()) THEN
    RAISE EXCEPTION 'Bu slot oyuncuya ait değil.';
  END IF;

  -- Eğer rafta kalan stok varsa o ildeki Genel Depoya aktar
  IF coalesce(v_slot.quantity, 0) > 0 AND v_slot.product_id IS NOT NULL THEN
    SELECT * INTO v_warehouse
    FROM public.warehouses
    WHERE player_id = auth.uid()
      AND city_id = v_slot.city_id
      AND (warehouse_kind IS NULL OR warehouse_kind IN ('general', 'normal'))
      AND is_active = true
    ORDER BY created_at ASC
    LIMIT 1
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Bu şehirde aktif bir Genel Deponuz bulunmadığı için raftaki ürün iade edilemez.';
    END IF;

    -- Kapasite kontrolü (H02)
    SELECT coalesce(sum(ws.quantity * coalesce(p.birim_hacim, 0.1)), 0)
    INTO v_used_capacity
    FROM public.warehouse_slots ws
    JOIN public.products p ON p.id = ws.product_id
    WHERE ws.warehouse_id = v_warehouse.id;

    SELECT coalesce(birim_hacim, 0.1) INTO v_unit_volume FROM public.products WHERE id = v_slot.product_id;
    v_incoming_volume := v_slot.quantity * coalesce(v_unit_volume, 0.1);

    IF (v_used_capacity + coalesce(v_warehouse.reserved_capacity, 0) + v_incoming_volume) > v_warehouse.capacity THEN
      RAISE EXCEPTION 'Genel Depoda yeterli boş kapasite yok. (Gereken hacim: % birim)', v_incoming_volume;
    END IF;

    -- Eşleşen depo slotunu bul ve kilitle
    SELECT * INTO v_existing_wh_slot
    FROM public.warehouse_slots
    WHERE warehouse_id = v_warehouse.id
      AND product_id = v_slot.product_id
      AND quality_level = v_slot.quality_level
      AND coalesce(brand_id, '00000000-0000-0000-0000-000000000000'::uuid) = coalesce(v_slot.brand_id, '00000000-0000-0000-0000-000000000000'::uuid)
    ORDER BY slot_index ASC
    LIMIT 1
    FOR UPDATE;

    IF FOUND THEN
      -- Ağırlıklı ortalama birim maliyet (H02)
      v_new_wh_qty := v_existing_wh_slot.quantity + v_slot.quantity;
      v_new_wh_cost := CASE
        WHEN v_new_wh_qty <= 0 THEN 0
        ELSE round(
          ((coalesce(v_existing_wh_slot.quantity, 0) * coalesce(v_existing_wh_slot.cost, 0)) +
           (v_slot.quantity * coalesce(v_slot.cost, 0))) / v_new_wh_qty::numeric,
          4
        )
      END;

      UPDATE public.warehouse_slots
      SET
        quantity = v_new_wh_qty,
        cost = v_new_wh_cost,
        updated_at = v_now
      WHERE id = v_existing_wh_slot.id;
    ELSE
      -- Bir sonraki slot_index'i bul (H01 DÜZELTMESİ)
      SELECT coalesce(max(slot_index), 0) + 1 INTO v_next_slot_index
      FROM public.warehouse_slots
      WHERE warehouse_id = v_warehouse.id;

      INSERT INTO public.warehouse_slots (
        warehouse_id,
        slot_index,
        product_id,
        quality_level,
        brand_id,
        quantity,
        cost,
        is_available_for_sale,
        price,
        created_at,
        updated_at
      ) VALUES (
        v_warehouse.id,
        v_next_slot_index,
        v_slot.product_id,
        v_slot.quality_level,
        coalesce(v_slot.brand_id, '00000000-0000-0000-0000-000000000000'::uuid),
        v_slot.quantity,
        coalesce(v_slot.cost, 0),
        false,
        0,
        v_now,
        v_now
      );
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
$$;

GRANT EXECUTE ON FUNCTION public.clear_store_slot_product(uuid, uuid) TO authenticated;

-- ============================================================================
-- 4. H01 & H02: SET_STORE_SLOT_PRODUCT_FROM_WAREHOUSE_SLOT
-- ============================================================================

CREATE OR REPLACE FUNCTION public.set_store_slot_product_from_warehouse_slot(
  p_player_id uuid,
  p_store_slot_id uuid,
  p_warehouse_slot_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_slot record;
  v_source_slot record;
  v_warehouse record;
  v_existing_wh_slot record;
  v_next_slot_index integer;
  v_used_capacity numeric := 0;
  v_unit_volume numeric := 0.1;
  v_incoming_volume numeric := 0;
  v_new_wh_qty integer;
  v_new_wh_cost numeric;
  v_new_cost numeric;
  v_now timestamptz := timezone('utc'::text, now());
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Yetkisiz erişim: Oturum açılmamış.';
  END IF;

  SELECT ss.*, s.player_id, s.city_id, s.store_type_id
  INTO v_slot
  FROM public.store_slots ss
  JOIN public.stores s ON s.id = ss.store_id
  WHERE ss.id = p_store_slot_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Mağaza slotu bulunamadı.';
  END IF;

  IF v_slot.player_id <> auth.uid() OR (p_player_id IS NOT NULL AND p_player_id <> auth.uid()) THEN
    RAISE EXCEPTION 'Bu slot oyuncuya ait değil.';
  END IF;

  SELECT ws.*, w.player_id, w.city_id, w.id AS wh_id
  INTO v_source_slot
  FROM public.warehouse_slots ws
  JOIN public.warehouses w ON w.id = ws.warehouse_id
  WHERE ws.id = p_warehouse_slot_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Kaynak depo slotu bulunamadı.';
  END IF;

  IF v_source_slot.player_id <> auth.uid() THEN
    RAISE EXCEPTION 'Kaynak depo slotu oyuncuya ait değil.';
  END IF;

  IF v_source_slot.city_id IS DISTINCT FROM v_slot.city_id THEN
    RAISE EXCEPTION 'Sadece aynı şehirdeki Genel Depodaki ürünler seçilebilir.';
  END IF;

  IF coalesce(v_source_slot.product_id, '') = '' THEN
    RAISE EXCEPTION 'Kaynak depo slotunda ürün bulunamadı.';
  END IF;

  IF coalesce(v_source_slot.quantity, 0) <= 0 THEN
    RAISE EXCEPTION 'Kaynak depo slotunda seçilebilir stok bulunamadı.';
  END IF;

  IF coalesce(v_source_slot.quality_level, 0) < 1 OR coalesce(v_source_slot.quality_level, 0) > 5 THEN
    RAISE EXCEPTION 'Kaynak depo slotunun kalite seviyesi geçersiz.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.stores s
    JOIN public.store_types st ON st.id = s.store_type_id
    WHERE s.id = v_slot.store_id
      AND (
        st.accepted_product_ids IS NULL
        OR NOT (v_source_slot.product_id = ANY(regexp_split_to_array(st.accepted_product_ids, '\\s*,\\s*')))
      )
  ) THEN
    RAISE EXCEPTION 'Bu mağaza türü bu ürünü satamaz: %', v_source_slot.product_id;
  END IF;

  -- Eğer rafta farklı bir ürün varsa depoya iade et
  IF coalesce(v_slot.quantity, 0) > 0 AND (
    v_slot.product_id IS DISTINCT FROM v_source_slot.product_id OR
    v_slot.quality_level IS DISTINCT FROM v_source_slot.quality_level OR
    v_slot.brand_id IS DISTINCT FROM coalesce(v_source_slot.brand_id, '00000000-0000-0000-0000-000000000000'::uuid)
  ) THEN
    SELECT * INTO v_warehouse
    FROM public.warehouses
    WHERE player_id = auth.uid()
      AND city_id = v_slot.city_id
      AND (warehouse_kind IS NULL OR warehouse_kind IN ('general', 'normal'))
      AND is_active = true
    ORDER BY created_at ASC
    LIMIT 1
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Bu şehirde aktif bir Genel Deponuz bulunmadığı için raftaki ürün iade edilemez.';
    END IF;

    -- Kapasite kontrolü (H02)
    SELECT coalesce(sum(ws.quantity * coalesce(p.birim_hacim, 0.1)), 0)
    INTO v_used_capacity
    FROM public.warehouse_slots ws
    JOIN public.products p ON p.id = ws.product_id
    WHERE ws.warehouse_id = v_warehouse.id;

    SELECT coalesce(birim_hacim, 0.1) INTO v_unit_volume FROM public.products WHERE id = v_slot.product_id;
    v_incoming_volume := v_slot.quantity * coalesce(v_unit_volume, 0.1);

    IF (v_used_capacity + coalesce(v_warehouse.reserved_capacity, 0) + v_incoming_volume) > v_warehouse.capacity THEN
      RAISE EXCEPTION 'Genel Depoda yeterli boş kapasite yok. (Gereken hacim: % birim)', v_incoming_volume;
    END IF;

    SELECT * INTO v_existing_wh_slot
    FROM public.warehouse_slots
    WHERE warehouse_id = v_warehouse.id
      AND product_id = v_slot.product_id
      AND quality_level = v_slot.quality_level
      AND coalesce(brand_id, '00000000-0000-0000-0000-000000000000'::uuid) = coalesce(v_slot.brand_id, '00000000-0000-0000-0000-000000000000'::uuid)
    ORDER BY slot_index ASC
    LIMIT 1
    FOR UPDATE;

    IF FOUND THEN
      v_new_wh_qty := v_existing_wh_slot.quantity + v_slot.quantity;
      v_new_wh_cost := CASE
        WHEN v_new_wh_qty <= 0 THEN 0
        ELSE round(
          ((coalesce(v_existing_wh_slot.quantity, 0) * coalesce(v_existing_wh_slot.cost, 0)) +
           (v_slot.quantity * coalesce(v_slot.cost, 0))) / v_new_wh_qty::numeric,
          4
        )
      END;

      UPDATE public.warehouse_slots
      SET
        quantity = v_new_wh_qty,
        cost = v_new_wh_cost,
        updated_at = v_now
      WHERE id = v_existing_wh_slot.id;
    ELSE
      -- Bir sonraki slot_index'i bul (H01 DÜZELTMESİ)
      SELECT coalesce(max(slot_index), 0) + 1 INTO v_next_slot_index
      FROM public.warehouse_slots
      WHERE warehouse_id = v_warehouse.id;

      INSERT INTO public.warehouse_slots (
        warehouse_id,
        slot_index,
        product_id,
        quality_level,
        brand_id,
        quantity,
        cost,
        is_available_for_sale,
        price,
        created_at,
        updated_at
      ) VALUES (
        v_warehouse.id,
        v_next_slot_index,
        v_slot.product_id,
        v_slot.quality_level,
        coalesce(v_slot.brand_id, '00000000-0000-0000-0000-000000000000'::uuid),
        v_slot.quantity,
        coalesce(v_slot.cost, 0),
        false,
        0,
        v_now,
        v_now
      );
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
$$;

GRANT EXECUTE ON FUNCTION public.set_store_slot_product_from_warehouse_slot(uuid, uuid, uuid) TO authenticated;

-- ============================================================================
-- 5. H06: ÜRETİM MOTORUNDA ÇIKIŞ AMBARINI FOR UPDATE İLE KİLİTLEME
-- ============================================================================

CREATE OR REPLACE FUNCTION public.process_factory_production_entry(
  p_player_id uuid,
  p_factory_id uuid DEFAULT NULL::uuid,
  p_tick_minutes integer DEFAULT 10,
  p_max_ticks integer DEFAULT NULL::integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_now timestamptz := timezone('utc'::text, now());
  v_processed_count integer := 0;
  v_produced_count integer := 0;
  v_pending_only_count integer := 0;
  v_skipped_count integer := 0;
  v_total_produced integer := 0;
  v_ticks integer;
  v_processed_until timestamptz;
  v_rate_per_tick numeric;
  v_raw_output numeric;
  v_whole_output integer;
  v_available_output_capacity integer;
  v_output_to_produce integer;
  v_pending_after numeric;
  v_h1_required integer;
  v_h2_required integer;
  v_h3_required integer;
  v_h1_quantity integer;
  v_h2_quantity integer;
  v_h3_quantity integer;
  v_h1_cost numeric;
  v_h2_cost numeric;
  v_h3_cost numeric;
  v_total_input_cost numeric;
  v_total_labor_cost numeric;
  v_total_production_cost numeric;
  v_output_cost_after numeric;
  v_output_quantity_after integer;
  v_boost_bonus_minutes numeric;
  v_effective_ticks numeric;
  v_fresh_output_qty integer;
  v_fresh_output_cost numeric;
  v_row record;
BEGIN
  IF p_player_id IS NULL THEN RAISE EXCEPTION 'Oturum acilmamis.'; END IF;
  PERFORM pg_advisory_xact_lock(hashtext('factory_production_entry:' || p_player_id::text));

  FOR v_row IN
    SELECT
      f.id AS factory_id,
      f.product_id,
      f.quality_level,
      f.brand_id,
      f.output_capacity,
      f.last_production_at,
      p.uretim_adedi,
      coalesce(p.iscilik_maliyeti, 0) AS iscilik_maliyeti,
      nullif(p.hammadde_1_id, '') AS h1_id,
      coalesce(p.hammadde_1_miktar, 0) AS h1_per_unit,
      nullif(p.hammadde_2_id, '') AS h2_id,
      coalesce(p.hammadde_2_miktar, 0) AS h2_per_unit,
      nullif(p.hammadde_3_id, '') AS h3_id,
      coalesce(p.hammadde_3_miktar, 0) AS h3_per_unit,
      out_pi.id AS output_inventory_id,
      out_pi.quantity AS output_quantity,
      coalesce(out_pi.pending_quantity, 0) AS output_pending_quantity,
      coalesce(out_pi.cost, 0) AS output_cost,
      coalesce(
        (to_jsonb(c) ->> ('bonus_' || lower(replace(replace(replace(replace(replace(replace(p.kategori, ' ', '_'), 'ı', 'i'), 'ğ', 'g'), 'ş', 's'), 'ü', 'u'), 'ö', 'o'))))::numeric,
        1.0
      ) AS city_bonus
    FROM public.factories f
    JOIN public.products p ON p.id = f.product_id
    LEFT JOIN public.cities c ON c.id = f.city_id
    JOIN public.production_inventory out_pi
      ON out_pi.owner_kind = 'factory'
     AND out_pi.owner_id = f.id
     AND out_pi.inventory_type = 'output'
     AND out_pi.product_id = f.product_id
     AND out_pi.quality_level = f.quality_level
     AND out_pi.brand_id = f.brand_id
    WHERE f.player_id = p_player_id
      AND (p_factory_id IS NULL OR f.id = p_factory_id)
      AND f.is_active = true
      AND f.product_id IS NOT NULL
      AND f.quality_level BETWEEN 1 AND 5
      AND coalesce(p.uretim_adedi, 0) > 0
    ORDER BY f.created_at, f.id
  LOOP
    v_ticks := floor(extract(epoch from (v_now - coalesce(v_row.last_production_at, v_now))) / greatest(p_tick_minutes * 60, 60))::integer;
    v_ticks := greatest(least(v_ticks, coalesce(p_max_ticks, v_ticks)), 0);
    IF v_ticks <= 0 THEN CONTINUE; END IF;
    v_processed_count := v_processed_count + 1;
    v_processed_until := coalesce(v_row.last_production_at, v_now) + make_interval(mins => p_tick_minutes * v_ticks);
    v_available_output_capacity := greatest(v_row.output_capacity - v_row.output_quantity, 0);
    IF v_available_output_capacity <= 0 THEN
      UPDATE public.factories SET last_production_at = v_processed_until, updated_at = timezone('utc'::text, now()) WHERE id = v_row.factory_id;
      v_skipped_count := v_skipped_count + 1;
      CONTINUE;
    END IF;
    SELECT coalesce(sum(greatest(extract(epoch from least(coalesce(bb.completed_at, bb.finish_at, v_processed_until), v_processed_until) - greatest(bb.started_at, v_row.last_production_at)) / 60.0,0) * greatest(coalesce(bb.multiplier, 1) - 1, 0)),0)
    INTO v_boost_bonus_minutes
    FROM public.building_boosts bb
    WHERE bb.player_id = p_player_id AND bb.building_kind = 'factory' AND bb.entity_id = v_row.factory_id AND bb.started_at < v_processed_until AND coalesce(bb.completed_at, bb.finish_at, v_processed_until) > v_row.last_production_at;
    v_effective_ticks := greatest(0, (((p_tick_minutes * v_ticks)::numeric + coalesce(v_boost_bonus_minutes, 0)) / greatest(p_tick_minutes, 1)::numeric));
    
    v_rate_per_tick := (coalesce(v_row.uretim_adedi, 0)::numeric / 6) * (1.0 + (v_row.quality_level - 1) * 0.20) * coalesce(v_row.city_bonus, 1.0);
    
    v_raw_output := coalesce(v_row.output_pending_quantity, 0) + (v_rate_per_tick * v_effective_ticks);
    v_whole_output := floor(v_raw_output)::integer;
    IF v_whole_output <= 0 THEN
      UPDATE public.production_inventory SET pending_quantity = v_raw_output WHERE id = v_row.output_inventory_id;
      UPDATE public.factories SET last_production_at = v_processed_until, updated_at = timezone('utc'::text, now()) WHERE id = v_row.factory_id;
      v_pending_only_count := v_pending_only_count + 1;
      CONTINUE;
    END IF;
    v_output_to_produce := least(v_whole_output, v_available_output_capacity);
    IF v_output_to_produce <= 0 THEN
      UPDATE public.factories SET last_production_at = v_processed_until, updated_at = timezone('utc'::text, now()) WHERE id = v_row.factory_id;
      v_skipped_count := v_skipped_count + 1;
      CONTINUE;
    END IF;
    v_h1_required := CASE WHEN v_row.h1_id IS NOT NULL AND v_row.h1_per_unit > 0 THEN ceil(v_output_to_produce * v_row.h1_per_unit)::integer ELSE 0 END;
    v_h2_required := CASE WHEN v_row.h2_id IS NOT NULL AND v_row.h2_per_unit > 0 THEN ceil(v_output_to_produce * v_row.h2_per_unit)::integer ELSE 0 END;
    v_h3_required := CASE WHEN v_row.h3_id IS NOT NULL AND v_row.h3_per_unit > 0 THEN ceil(v_output_to_produce * v_row.h3_per_unit)::integer ELSE 0 END;
    SELECT coalesce(quantity, 0), coalesce(cost, 0) INTO v_h1_quantity, v_h1_cost FROM public.production_inventory WHERE owner_kind = 'factory' AND owner_id = v_row.factory_id AND inventory_type = 'input' AND product_id = v_row.h1_id AND quality_level = greatest(v_row.quality_level - 1, 1) FOR UPDATE;
    SELECT coalesce(quantity, 0), coalesce(cost, 0) INTO v_h2_quantity, v_h2_cost FROM public.production_inventory WHERE owner_kind = 'factory' AND owner_id = v_row.factory_id AND inventory_type = 'input' AND product_id = v_row.h2_id AND quality_level = greatest(v_row.quality_level - 1, 1) FOR UPDATE;
    SELECT coalesce(quantity, 0), coalesce(cost, 0) INTO v_h3_quantity, v_h3_cost FROM public.production_inventory WHERE owner_kind = 'factory' AND owner_id = v_row.factory_id AND inventory_type = 'input' AND product_id = v_row.h3_id AND quality_level = greatest(v_row.quality_level - 1, 1) FOR UPDATE;
    IF (v_h1_required > 0 AND coalesce(v_h1_quantity, 0) < v_h1_required) OR (v_h2_required > 0 AND coalesce(v_h2_quantity, 0) < v_h2_required) OR (v_h3_required > 0 AND coalesce(v_h3_quantity, 0) < v_h3_required) THEN
      UPDATE public.factories SET last_production_at = v_processed_until, updated_at = timezone('utc'::text, now()) WHERE id = v_row.factory_id;
      v_skipped_count := v_skipped_count + 1;
      CONTINUE;
    END IF;
    IF v_h1_required > 0 THEN UPDATE public.production_inventory SET quantity = quantity - v_h1_required WHERE owner_kind = 'factory' AND owner_id = v_row.factory_id AND inventory_type = 'input' AND product_id = v_row.h1_id AND quality_level = greatest(v_row.quality_level - 1, 1); END IF;
    IF v_h2_required > 0 THEN UPDATE public.production_inventory SET quantity = quantity - v_h2_required WHERE owner_kind = 'factory' AND owner_id = v_row.factory_id AND inventory_type = 'input' AND product_id = v_row.h2_id AND quality_level = greatest(v_row.quality_level - 1, 1); END IF;
    IF v_h3_required > 0 THEN UPDATE public.production_inventory SET quantity = quantity - v_h3_required WHERE owner_kind = 'factory' AND owner_id = v_row.factory_id AND inventory_type = 'input' AND product_id = v_row.h3_id AND quality_level = greatest(v_row.quality_level - 1, 1); END IF;
    v_total_input_cost := (v_h1_required * coalesce(v_h1_cost, 0)) + (v_h2_required * coalesce(v_h2_cost, 0)) + (v_h3_required * coalesce(v_h3_cost, 0));
    v_total_labor_cost := v_output_to_produce * v_row.iscilik_maliyeti;
    v_total_production_cost := v_total_input_cost + v_total_labor_cost;
    v_pending_after := CASE WHEN v_output_to_produce < v_whole_output THEN 0 ELSE v_raw_output - v_whole_output END;
    
    -- H06 DÜZELTME: Çıkış ambarı satırını FOR UPDATE ile kilitle ve taze stok oku
    SELECT quantity, cost INTO v_fresh_output_qty, v_fresh_output_cost
    FROM public.production_inventory
    WHERE id = v_row.output_inventory_id
    FOR UPDATE;

    v_output_quantity_after := coalesce(v_fresh_output_qty, 0) + v_output_to_produce;
    v_output_cost_after := CASE
      WHEN v_output_quantity_after > 0 AND v_output_to_produce > 0 THEN
        (((coalesce(v_fresh_output_qty, 0) * coalesce(v_fresh_output_cost, 0)) + v_total_production_cost) / v_output_quantity_after)
      ELSE coalesce(v_fresh_output_cost, v_row.output_cost)
    END;

    UPDATE public.production_inventory
    SET quantity = v_output_quantity_after,
        pending_quantity = v_pending_after,
        cost = v_output_cost_after
    WHERE id = v_row.output_inventory_id;

    UPDATE public.factories SET last_production_at = v_processed_until, updated_at = timezone('utc'::text, now()) WHERE id = v_row.factory_id;
    IF v_output_to_produce > 0 THEN PERFORM public.upsert_player_daily_production_stat(p_player_id, 'factory', v_row.factory_id, v_row.product_id, v_output_to_produce, v_total_production_cost); END IF;
    v_produced_count := v_produced_count + 1;
    v_total_produced := v_total_produced + v_output_to_produce;
  END LOOP;

  RETURN jsonb_build_object('success', true, 'processed_count', v_processed_count, 'produced_count', v_produced_count, 'pending_only_count', v_pending_only_count, 'skipped_count', v_skipped_count, 'total_produced', v_total_produced);
END;
$$;

GRANT EXECUTE ON FUNCTION public.process_factory_production_entry(uuid, uuid, integer, integer) TO authenticated;

-- ============================================================================
-- 6. H06: TARLA & ÇİFTLİK ÜRETİMİNDE ÇIKIŞ AMBARINI FOR UPDATE İLE KİLİTLEME
-- ============================================================================

CREATE OR REPLACE FUNCTION public.process_field_farm_production_entry(
  p_player_id uuid,
  p_owner_kind text DEFAULT NULL::text,
  p_owner_id uuid DEFAULT NULL::uuid,
  p_tick_minutes integer DEFAULT 10,
  p_max_ticks integer DEFAULT NULL::integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_now timestamptz := timezone('utc'::text, now());
  v_processed_count integer := 0;
  v_produced_count integer := 0;
  v_pending_only_count integer := 0;
  v_skipped_count integer := 0;
  v_total_produced integer := 0;
  v_ticks integer;
  v_processed_until timestamptz;
  v_rate_per_tick numeric;
  v_raw_output numeric;
  v_whole_output integer;
  v_available_output_capacity integer;
  v_owner_total_output integer;
  v_output_to_produce integer;
  v_tentative_output integer;
  v_pending_after numeric;
  v_h1_required integer;
  v_h2_required integer;
  v_h3_required integer;
  v_h1_quantity integer;
  v_h2_quantity integer;
  v_h3_quantity integer;
  v_h1_cost numeric;
  v_h2_cost numeric;
  v_h3_cost numeric;
  v_total_input_cost numeric;
  v_total_labor_cost numeric;
  v_total_production_cost numeric;
  v_output_cost_after numeric;
  v_output_quantity_after integer;
  v_boost_bonus_minutes numeric;
  v_effective_ticks numeric;
  v_fresh_output_qty integer;
  v_fresh_output_cost numeric;
  v_row record;
  v_stat_date date := timezone('Europe/Istanbul'::text, now())::date;
BEGIN
  IF p_player_id IS NULL THEN
    RAISE EXCEPTION 'Oturum acilmamis.';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('field_farm_production_entry:' || p_player_id::text));

  FOR v_row IN
    SELECT
      ps.id AS production_slot_id,
      ps.owner_kind,
      ps.owner_id,
      ps.slot_index,
      ps.product_id,
      ps.quality_level,
      ps.brand_id,
      ps.last_production_at,
      owners.output_capacity AS owner_output_capacity,
      p.uretim_adedi,
      coalesce(p.iscilik_maliyeti, 0) AS iscilik_maliyeti,
      nullif(p.hammadde_1_id, '') AS h1_id,
      coalesce(p.hammadde_1_miktar, 0) AS h1_per_unit,
      nullif(p.hammadde_2_id, '') AS h2_id,
      coalesce(p.hammadde_2_miktar, 0) AS h2_per_unit,
      nullif(p.hammadde_3_id, '') AS h3_id,
      coalesce(p.hammadde_3_miktar, 0) AS h3_per_unit,
      out_pi.id AS output_inventory_id,
      out_pi.quantity AS output_quantity,
      coalesce(out_pi.pending_quantity, 0) AS output_pending_quantity,
      coalesce(out_pi.cost, 0) AS output_cost,
      coalesce(
        (to_jsonb(c) ->> ('bonus_' || lower(replace(replace(replace(replace(replace(replace(p.kategori, ' ', '_'), 'ı', 'i'), 'ğ', 'g'), 'ş', 's'), 'ü', 'u'), 'ö', 'o'))))::numeric,
        1.0
      ) AS city_bonus
    FROM (
      SELECT 'field'::text AS owner_kind, id AS owner_id, city_id, output_capacity
      FROM public.fields
      WHERE player_id = p_player_id
        AND is_active = true
        AND (p_owner_kind IS NULL OR p_owner_kind = 'field')
        AND (p_owner_id IS NULL OR id = p_owner_id)
      UNION ALL
      SELECT 'farm'::text AS owner_kind, id AS owner_id, city_id, output_capacity
      FROM public.farms
      WHERE player_id = p_player_id
        AND is_active = true
        AND (p_owner_kind IS NULL OR p_owner_kind = 'farm')
        AND (p_owner_id IS NULL OR id = p_owner_id)
    ) owners
    JOIN public.production_slots ps
      ON ps.owner_kind = owners.owner_kind
     AND ps.owner_id = owners.owner_id
    JOIN public.products p
      ON p.id = ps.product_id
    LEFT JOIN public.cities c
      ON c.id = owners.city_id
    JOIN public.production_inventory out_pi
      ON out_pi.owner_kind = ps.owner_kind
     AND out_pi.owner_id = ps.owner_id
     AND out_pi.inventory_type = 'output'
     AND out_pi.product_id = ps.product_id
     AND out_pi.quality_level = ps.quality_level
     AND out_pi.brand_id = coalesce(ps.brand_id, '00000000-0000-0000-0000-000000000000'::uuid)
    WHERE ps.is_active = true
      AND ps.owner_kind IN ('field', 'farm')
      AND ps.product_id IS NOT NULL
      AND ps.quality_level BETWEEN 1 AND 5
      AND coalesce(p.uretim_adedi, 0) > 0
    ORDER BY ps.owner_kind, ps.owner_id, ps.slot_index, ps.id
  LOOP
    v_ticks := floor(extract(epoch from (v_now - coalesce(v_row.last_production_at, v_now))) / greatest(p_tick_minutes * 60, 60))::integer;
    v_ticks := greatest(least(v_ticks, coalesce(p_max_ticks, v_ticks)), 0);

    IF v_ticks <= 0 THEN
      CONTINUE;
    END IF;

    v_processed_count := v_processed_count + 1;
    v_processed_until := coalesce(v_row.last_production_at, v_now) + make_interval(mins => p_tick_minutes * v_ticks);

    SELECT coalesce(sum(quantity), 0)::integer
    INTO v_owner_total_output
    FROM public.production_inventory
    WHERE owner_kind = v_row.owner_kind
      AND owner_id = v_row.owner_id
      AND inventory_type = 'output';

    v_available_output_capacity := greatest(coalesce(v_row.owner_output_capacity, 0) - coalesce(v_owner_total_output, 0), 0);

    IF v_available_output_capacity <= 0 THEN
      UPDATE public.production_slots
      SET last_production_at = v_processed_until,
          updated_at = timezone('utc'::text, now())
      WHERE id = v_row.production_slot_id;

      v_skipped_count := v_skipped_count + 1;
      CONTINUE;
    END IF;

    SELECT coalesce(sum(greatest(extract(epoch from least(coalesce(bb.completed_at, bb.finish_at, v_processed_until), v_processed_until) - greatest(bb.started_at, v_row.last_production_at)) / 60.0, 0) * greatest(coalesce(bb.multiplier, 1) - 1, 0)), 0)
    INTO v_boost_bonus_minutes
    FROM public.building_boosts bb
    WHERE bb.player_id = p_player_id
      AND bb.building_kind = v_row.owner_kind
      AND bb.entity_id = v_row.owner_id
      AND bb.started_at < v_processed_until
      AND coalesce(bb.completed_at, bb.finish_at, v_processed_until) > v_row.last_production_at;

    v_effective_ticks := greatest(0, (((p_tick_minutes * v_ticks)::numeric + coalesce(v_boost_bonus_minutes, 0)) / greatest(p_tick_minutes, 1)::numeric));

    v_rate_per_tick := (coalesce(v_row.uretim_adedi, 0)::numeric / 6) * (1.0 + (v_row.quality_level - 1) * 0.20) * coalesce(v_row.city_bonus, 1.0);
    v_raw_output := coalesce(v_row.output_pending_quantity, 0) + (v_rate_per_tick * v_effective_ticks);
    v_whole_output := floor(v_raw_output)::integer;

    IF v_whole_output <= 0 THEN
      UPDATE public.production_inventory
      SET pending_quantity = v_raw_output
      WHERE id = v_row.output_inventory_id;

      UPDATE public.production_slots
      SET last_production_at = v_processed_until,
          updated_at = timezone('utc'::text, now())
      WHERE id = v_row.production_slot_id;

      v_pending_only_count := v_pending_only_count + 1;
      CONTINUE;
    END IF;

    v_tentative_output := least(v_whole_output, v_available_output_capacity);

    WITH locked_inputs AS MATERIALIZED (
      SELECT product_id, quantity, cost
      FROM public.production_inventory
      WHERE owner_kind = v_row.owner_kind
        AND owner_id = v_row.owner_id
        AND inventory_type = 'input'
        AND quality_level = greatest(v_row.quality_level - 1, 1)
        AND product_id = ANY (array_remove(ARRAY[v_row.h1_id, v_row.h2_id, v_row.h3_id], null))
      ORDER BY product_id, quality_level, id
      FOR UPDATE
    )
    SELECT
      coalesce(max(quantity) FILTER (WHERE product_id = v_row.h1_id), 0)::integer,
      coalesce(max(cost) FILTER (WHERE product_id = v_row.h1_id), 0),
      coalesce(max(quantity) FILTER (WHERE product_id = v_row.h2_id), 0)::integer,
      coalesce(max(cost) FILTER (WHERE product_id = v_row.h2_id), 0),
      coalesce(max(quantity) FILTER (WHERE product_id = v_row.h3_id), 0)::integer,
      coalesce(max(cost) FILTER (WHERE product_id = v_row.h3_id), 0)
    INTO
      v_h1_quantity,
      v_h1_cost,
      v_h2_quantity,
      v_h2_cost,
      v_h3_quantity,
      v_h3_cost
    FROM locked_inputs;

    v_output_to_produce := v_tentative_output;

    IF v_row.h1_id IS NOT NULL AND v_row.h1_per_unit > 0 THEN
      v_output_to_produce := least(v_output_to_produce, floor(v_h1_quantity::numeric / v_row.h1_per_unit)::integer);
    END IF;

    IF v_row.h2_id IS NOT NULL AND v_row.h2_per_unit > 0 THEN
      v_output_to_produce := least(v_output_to_produce, floor(v_h2_quantity::numeric / v_row.h2_per_unit)::integer);
    END IF;

    IF v_row.h3_id IS NOT NULL AND v_row.h3_per_unit > 0 THEN
      v_output_to_produce := least(v_output_to_produce, floor(v_h3_quantity::numeric / v_row.h3_per_unit)::integer);
    END IF;

    IF v_output_to_produce <= 0 THEN
      UPDATE public.production_inventory
      SET pending_quantity = least(coalesce(v_row.output_pending_quantity, 0), 0.9999)
      WHERE id = v_row.output_inventory_id;

      UPDATE public.production_slots
      SET last_production_at = v_processed_until,
          updated_at = timezone('utc'::text, now())
      WHERE id = v_row.production_slot_id;

      v_skipped_count := v_skipped_count + 1;
      CONTINUE;
    END IF;

    v_h1_required := CASE WHEN v_row.h1_id IS NOT NULL THEN v_output_to_produce * v_row.h1_per_unit ELSE 0 END;
    v_h2_required := CASE WHEN v_row.h2_id IS NOT NULL THEN v_output_to_produce * v_row.h2_per_unit ELSE 0 END;
    v_h3_required := CASE WHEN v_row.h3_id IS NOT NULL THEN v_output_to_produce * v_row.h3_per_unit ELSE 0 END;

    IF v_row.h1_id IS NOT NULL AND v_h1_required > 0 THEN
      UPDATE public.production_inventory
      SET quantity = greatest(quantity - v_h1_required, 0)
      WHERE owner_kind = v_row.owner_kind
        AND owner_id = v_row.owner_id
        AND inventory_type = 'input'
        AND product_id = v_row.h1_id
        AND quality_level = greatest(v_row.quality_level - 1, 1);
    END IF;

    IF v_row.h2_id IS NOT NULL AND v_h2_required > 0 THEN
      UPDATE public.production_inventory
      SET quantity = greatest(quantity - v_h2_required, 0)
      WHERE owner_kind = v_row.owner_kind
        AND owner_id = v_row.owner_id
        AND inventory_type = 'input'
        AND product_id = v_row.h2_id
        AND quality_level = greatest(v_row.quality_level - 1, 1);
    END IF;

    IF v_row.h3_id IS NOT NULL AND v_h3_required > 0 THEN
      UPDATE public.production_inventory
      SET quantity = greatest(quantity - v_h3_required, 0)
      WHERE owner_kind = v_row.owner_kind
        AND owner_id = v_row.owner_id
        AND inventory_type = 'input'
        AND product_id = v_row.h3_id
        AND quality_level = greatest(v_row.quality_level - 1, 1);
    END IF;

    v_total_input_cost := (v_h1_required * v_h1_cost) + (v_h2_required * v_h2_cost) + (v_h3_required * v_h3_cost);
    v_total_labor_cost := v_output_to_produce * v_row.iscilik_maliyeti;
    v_total_production_cost := v_total_input_cost + v_total_labor_cost;

    v_pending_after := CASE
      WHEN v_output_to_produce < v_whole_output THEN 0
      ELSE v_raw_output - v_whole_output
    END;

    -- H06 DÜZELTME: Çıkış ambarını FOR UPDATE ile kilitle ve güncel stok oku
    SELECT quantity, cost INTO v_fresh_output_qty, v_fresh_output_cost
    FROM public.production_inventory
    WHERE id = v_row.output_inventory_id
    FOR UPDATE;

    v_output_quantity_after := coalesce(v_fresh_output_qty, 0) + v_output_to_produce;
    v_output_cost_after := CASE
      WHEN v_output_quantity_after > 0 AND v_output_to_produce > 0 THEN
        (((coalesce(v_fresh_output_qty, 0) * coalesce(v_fresh_output_cost, 0)) + v_total_production_cost) / v_output_quantity_after)
      ELSE coalesce(v_fresh_output_cost, v_row.output_cost)
    END;

    UPDATE public.production_inventory
    SET quantity = v_output_quantity_after,
        cost = v_output_cost_after,
        pending_quantity = least(v_pending_after, 0.9999)
    WHERE id = v_row.output_inventory_id;

    UPDATE public.production_slots
    SET last_production_at = v_processed_until,
        updated_at = timezone('utc'::text, now())
    WHERE id = v_row.production_slot_id;

    PERFORM public.upsert_player_daily_production_stat(
      p_player_id,
      v_row.owner_kind,
      v_row.owner_id,
      v_row.product_id,
      v_output_to_produce,
      v_total_production_cost,
      v_stat_date
    );

    v_produced_count := v_produced_count + 1;
    v_total_produced := v_total_produced + v_output_to_produce;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'processed_count', v_processed_count,
    'produced_count', v_produced_count,
    'pending_only_count', v_pending_only_count,
    'skipped_count', v_skipped_count,
    'total_produced', v_total_produced
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.process_field_farm_production_entry(uuid, text, uuid, integer, integer) TO authenticated;

-- ============================================================================
-- 7. H06: MADEN ÜRETİMİNDE ÇIKIŞ AMBARINI FOR UPDATE İLE KİLİTLEME
-- ============================================================================

CREATE OR REPLACE FUNCTION public.process_mine_production_entry(
  p_player_id uuid,
  p_mine_id uuid DEFAULT NULL::uuid,
  p_tick_minutes integer DEFAULT 10,
  p_max_ticks integer DEFAULT NULL::integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_now timestamptz := timezone('utc'::text, now());
  v_processed_count integer := 0;
  v_produced_count integer := 0;
  v_pending_only_count integer := 0;
  v_skipped_count integer := 0;
  v_total_produced integer := 0;
  v_ticks integer;
  v_processed_until timestamptz;
  v_rate_per_tick numeric;
  v_raw_output numeric;
  v_whole_output integer;
  v_available_output_capacity integer;
  v_output_to_produce integer;
  v_pending_after numeric;
  v_boost_bonus_minutes numeric;
  v_effective_ticks numeric;
  v_total_labor_cost numeric;
  v_output_cost_after numeric;
  v_output_quantity_after integer;
  v_fresh_output_qty integer;
  v_fresh_output_cost numeric;
  v_row record;
BEGIN
  IF p_player_id IS NULL THEN RAISE EXCEPTION 'Oturum acilmamis.'; END IF;
  PERFORM pg_advisory_xact_lock(hashtext('mine_production_entry:' || p_player_id::text));

  FOR v_row IN
    SELECT
      m.id AS mine_id,
      m.product_id,
      m.quality_level,
      m.brand_id,
      m.output_capacity,
      m.last_production_at,
      p.uretim_adedi,
      coalesce(p.iscilik_maliyeti, 0) AS iscilik_maliyeti,
      out_pi.id AS output_inventory_id,
      out_pi.quantity AS output_quantity,
      coalesce(out_pi.pending_quantity, 0) AS output_pending_quantity,
      coalesce(out_pi.cost, 0) AS output_cost,
      coalesce(
        (to_jsonb(c) ->> ('bonus_' || lower(replace(replace(replace(replace(replace(replace(p.kategori, ' ', '_'), 'ı', 'i'), 'ğ', 'g'), 'ş', 's'), 'ü', 'u'), 'ö', 'o'))))::numeric,
        1.0
      ) AS city_bonus
    FROM public.mines m
    JOIN public.products p ON p.id = m.product_id
    LEFT JOIN public.cities c ON c.id = m.city_id
    JOIN public.production_inventory out_pi
      ON out_pi.owner_kind = 'mine'
     AND out_pi.owner_id = m.id
     AND out_pi.inventory_type = 'output'
     AND out_pi.product_id = m.product_id
     AND out_pi.quality_level = m.quality_level
     AND out_pi.brand_id = m.brand_id
    WHERE m.player_id = p_player_id
      AND (p_mine_id IS NULL OR m.id = p_mine_id)
      AND m.is_active = true
      AND m.product_id IS NOT NULL
      AND m.quality_level BETWEEN 1 AND 5
      AND coalesce(p.uretim_adedi, 0) > 0
    ORDER BY m.created_at, m.id
  LOOP
    v_ticks := floor(extract(epoch from (v_now - coalesce(v_row.last_production_at, v_now))) / greatest(p_tick_minutes * 60, 60))::integer;
    v_ticks := greatest(least(v_ticks, coalesce(p_max_ticks, v_ticks)), 0);
    IF v_ticks <= 0 THEN CONTINUE; END IF;
    v_processed_count := v_processed_count + 1;
    v_processed_until := coalesce(v_row.last_production_at, v_now) + make_interval(mins => p_tick_minutes * v_ticks);
    v_available_output_capacity := greatest(v_row.output_capacity - v_row.output_quantity, 0);
    IF v_available_output_capacity <= 0 THEN
      UPDATE public.mines SET last_production_at = v_processed_until, updated_at = timezone('utc'::text, now()) WHERE id = v_row.mine_id;
      v_skipped_count := v_skipped_count + 1;
      CONTINUE;
    END IF;
    SELECT coalesce(sum(greatest(extract(epoch from least(coalesce(bb.completed_at, bb.finish_at, v_processed_until), v_processed_until) - greatest(bb.started_at, v_row.last_production_at)) / 60.0, 0) * greatest(coalesce(bb.multiplier, 1) - 1, 0)), 0)
    INTO v_boost_bonus_minutes
    FROM public.building_boosts bb
    WHERE bb.player_id = p_player_id AND bb.building_kind = 'mine' AND bb.entity_id = v_row.mine_id AND bb.started_at < v_processed_until AND coalesce(bb.completed_at, bb.finish_at, v_processed_until) > v_row.last_production_at;
    v_effective_ticks := greatest(0, (((p_tick_minutes * v_ticks)::numeric + coalesce(v_boost_bonus_minutes, 0)) / greatest(p_tick_minutes, 1)::numeric));
    
    v_rate_per_tick := (coalesce(v_row.uretim_adedi, 0)::numeric / 6) * (1.0 + (v_row.quality_level - 1) * 0.20) * coalesce(v_row.city_bonus, 1.0);
    
    v_raw_output := coalesce(v_row.output_pending_quantity, 0) + (v_rate_per_tick * v_effective_ticks);
    v_whole_output := floor(v_raw_output)::integer;
    IF v_whole_output <= 0 THEN
      UPDATE public.production_inventory SET pending_quantity = v_raw_output WHERE id = v_row.output_inventory_id;
      UPDATE public.mines SET last_production_at = v_processed_until, updated_at = timezone('utc'::text, now()) WHERE id = v_row.mine_id;
      v_pending_only_count := v_pending_only_count + 1;
      CONTINUE;
    END IF;
    v_output_to_produce := least(v_whole_output, v_available_output_capacity);
    v_pending_after := CASE WHEN v_output_to_produce < v_whole_output THEN 0 ELSE v_raw_output - v_whole_output END;
    v_total_labor_cost := v_output_to_produce * v_row.iscilik_maliyeti;

    -- H06 DÜZELTME: Çıkış ambarını FOR UPDATE ile kilitle ve güncel stok oku
    SELECT quantity, cost INTO v_fresh_output_qty, v_fresh_output_cost
    FROM public.production_inventory
    WHERE id = v_row.output_inventory_id
    FOR UPDATE;

    v_output_quantity_after := coalesce(v_fresh_output_qty, 0) + v_output_to_produce;
    v_output_cost_after := CASE
      WHEN v_output_quantity_after > 0 AND v_output_to_produce > 0 THEN
        (((coalesce(v_fresh_output_qty, 0) * coalesce(v_fresh_output_cost, 0)) + v_total_labor_cost) / v_output_quantity_after)
      ELSE coalesce(v_fresh_output_cost, v_row.output_cost)
    END;

    UPDATE public.production_inventory
    SET quantity = v_output_quantity_after,
        pending_quantity = v_pending_after,
        cost = v_output_cost_after
    WHERE id = v_row.output_inventory_id;

    UPDATE public.mines SET last_production_at = v_processed_until, updated_at = timezone('utc'::text, now()) WHERE id = v_row.mine_id;
    IF v_output_to_produce > 0 THEN
      PERFORM public.upsert_player_daily_production_stat(p_player_id, 'mine', v_row.mine_id, v_row.product_id, v_output_to_produce, v_total_labor_cost);
      v_produced_count := v_produced_count + 1;
      v_total_produced := v_total_produced + v_output_to_produce;
    ELSE
      v_skipped_count := v_skipped_count + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('success', true, 'processed_count', v_processed_count, 'produced_count', v_produced_count, 'pending_only_count', v_pending_only_count, 'skipped_count', v_skipped_count, 'total_produced', v_total_produced);
END;
$$;

GRANT EXECUTE ON FUNCTION public.process_mine_production_entry(uuid, uuid, integer, integer) TO authenticated;
