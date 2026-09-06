-- ============================================================================
-- Migration: 2026-09-07_phase3_notification_and_alerts.sql
-- Description:
-- Hard Kapitalizm Teknik İnceleme Raporu - Faz 3 (K06, H07, H08)
-- 1. K06: send_game_notification fonksiyonundan authenticated yetkisinin alınması,
--    yalnızca service_role/postgres ve iç SECURITY DEFINER RPC'lerine sınırlandırılması.
--    FCM çağrısına iç servis doğrulama başlığının eklenmesi.
-- 2. H07: get_player_operational_alerts ve process_operational_alerts_push_notifications
--    fonksiyonlarında fabrika, tarla ve çiftlik için tam reçete (hammadde 1, 2, 3)
--    denetiminin yapılması; tek bir zorunlu girdi bile yetersizse alarm üretilmesi.
-- 3. H08: consume_rewarded_ad_usage_v2 yetkilerinin ve güvenlik kilitlerinin güvenceye alınması.
-- ============================================================================

-- ============================================================================
-- 1. K06: SEND_GAME_NOTIFICATION YETKİLERİ VE GÜVENLİĞİ
-- ============================================================================

CREATE OR REPLACE FUNCTION public.send_game_notification(
  p_player_id uuid,
  p_title text,
  p_message text,
  p_category text DEFAULT 'system'::text,
  p_entity_type text DEFAULT NULL::text,
  p_entity_id uuid DEFAULT NULL::uuid,
  p_send_push boolean DEFAULT true
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_notification_id uuid;
  v_token_row record;
BEGIN
  IF p_player_id IS NULL OR p_title IS NULL OR p_message IS NULL THEN
    RETURN NULL;
  END IF;

  -- 1. Oyun içi bildirimi ekle
  INSERT INTO public.player_notifications (
    player_id,
    title,
    message,
    category,
    entity_type,
    entity_id,
    is_read,
    created_at
  ) VALUES (
    p_player_id,
    p_title,
    p_message,
    coalesce(p_category, 'system'),
    p_entity_type,
    p_entity_id,
    false,
    timezone('utc'::text, now())
  ) RETURNING id INTO v_notification_id;

  -- 2. Otomatik budama: Oyuncu başına en yeni 50 bildirimi tut
  DELETE FROM public.player_notifications
  WHERE player_id = p_player_id
    AND id NOT IN (
      SELECT id FROM public.player_notifications
      WHERE player_id = p_player_id
      ORDER BY created_at DESC
      LIMIT 50
    );

  -- 3. FCM Push Gönderimi (pg_net ile asenkron çağrı)
  IF p_send_push THEN
    FOR v_token_row IN
      SELECT token
      FROM public.player_push_tokens
      WHERE player_id = p_player_id
    LOOP
      PERFORM net.http_post(
        url := 'https://lpiixtfxldhoyyppavyn.supabase.co/functions/v1/send-push',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'X-Internal-Secret', 'hk_internal_push_secret_2026'
        ),
        body := jsonb_build_object(
          'token', v_token_row.token,
          'title', p_title,
          'message', p_message,
          'player_id', p_player_id::text
        )
      );
    END LOOP;
  END IF;

  RETURN v_notification_id;
END;
$$;

-- Doğrudan istemciden çağrılamaz, sadece postgres ve service_role yetkilidir
REVOKE EXECUTE ON FUNCTION public.send_game_notification(uuid, text, text, text, text, uuid, boolean) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.send_game_notification(uuid, text, text, text, text, uuid, boolean) TO postgres, service_role;

-- ============================================================================
-- 2. H07: GET_PLAYER_OPERATIONAL_ALERTS (REÇETE BAZLI GİRDİ DENETİMİ)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_player_operational_alerts(p_player_id uuid DEFAULT NULL::uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_player_id uuid;
  v_alerts jsonb := '[]'::jsonb;
  v_count integer;
  v_debt numeric;
  v_limit numeric;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz erişim: Oturum açılmamış.');
  END IF;
  v_player_id := auth.uid();

  -- 1. VERGİ KONTROLLERİ
  SELECT coalesce(pt.tax_debt, 0), public.get_player_tax_limit(coalesce(p.level, 1))
  INTO v_debt, v_limit
  FROM public.players p
  LEFT JOIN public.player_taxes pt ON pt.player_id = p.id
  WHERE p.id = v_player_id;

  IF v_debt > v_limit THEN
    v_alerts := v_alerts || jsonb_build_array(jsonb_build_object(
      'id', 'tax_blocked',
      'severity', 'critical',
      'category', 'tax',
      'title', 'Şirket İşlemleri Bloke!',
      'description', 'Vergi borcunuz yasal limiti aştığı için şirket faaliyetleriniz durduruldu.',
      'route', '/tax',
      'count', 1
    ));
  ELSIF v_debt > (v_limit * 0.75) THEN
    v_alerts := v_alerts || jsonb_build_array(jsonb_build_object(
      'id', 'tax_near_limit',
      'severity', 'warning',
      'category', 'tax',
      'title', 'Vergi Borcu Kritik Seviyede',
      'description', 'Vergi borcunuz yasal limitin %75''ine ulaştı. Kilitlenme riski var.',
      'route', '/tax',
      'count', 1
    ));
  END IF;

  -- 2. KREDİ VADESİ
  SELECT count(*) INTO v_count
  FROM public.player_loans
  WHERE player_id = v_player_id
    AND status = 'active'
    AND next_installment_due_at < timezone('utc', now());

  IF v_count > 0 THEN
    v_alerts := v_alerts || jsonb_build_array(jsonb_build_object(
      'id', 'bank_loan_overdue',
      'severity', 'critical',
      'category', 'bank',
      'title', 'Kredi Taksiti Gecikti!',
      'description', v_count || ' adet gecikmiş kredi taksitiniz var. Temerrüt faizi işliyor.',
      'route', '/bank',
      'count', v_count
    ));
  END IF;

  -- 3. FABRİKA REÇETE BAZLI GİRDİ KONTROLÜ (H07)
  -- Üretim için gereken hammadde 1, 2 veya 3'ten en az biri 1 birim üretime yetmiyorsa üretim durur
  SELECT count(*) INTO v_count
  FROM public.factories f
  JOIN public.products pr ON pr.id = f.product_id
  WHERE f.player_id = v_player_id
    AND f.is_active = true
    AND f.product_id IS NOT NULL
    AND (
      (pr.hammadde_1_id IS NOT NULL AND (
        SELECT coalesce(sum(pi.quantity + coalesce(pi.pending_quantity, 0)), 0)
        FROM public.production_inventory pi
        WHERE pi.owner_kind = 'factory'
          AND pi.owner_id = f.id
          AND pi.inventory_type = 'input'
          AND pi.product_id = pr.hammadde_1_id
          AND pi.quality_level = greatest(f.quality_level - 1, 1)
      ) < coalesce(pr.hammadde_1_miktar, 1))
      OR
      (pr.hammadde_2_id IS NOT NULL AND (
        SELECT coalesce(sum(pi.quantity + coalesce(pi.pending_quantity, 0)), 0)
        FROM public.production_inventory pi
        WHERE pi.owner_kind = 'factory'
          AND pi.owner_id = f.id
          AND pi.inventory_type = 'input'
          AND pi.product_id = pr.hammadde_2_id
          AND pi.quality_level = greatest(f.quality_level - 1, 1)
      ) < coalesce(pr.hammadde_2_miktar, 1))
      OR
      (pr.hammadde_3_id IS NOT NULL AND (
        SELECT coalesce(sum(pi.quantity + coalesce(pi.pending_quantity, 0)), 0)
        FROM public.production_inventory pi
        WHERE pi.owner_kind = 'factory'
          AND pi.owner_id = f.id
          AND pi.inventory_type = 'input'
          AND pi.product_id = pr.hammadde_3_id
          AND pi.quality_level = greatest(f.quality_level - 1, 1)
      ) < coalesce(pr.hammadde_3_miktar, 1))
    );

  IF v_count > 0 THEN
    v_alerts := v_alerts || jsonb_build_array(jsonb_build_object(
      'id', 'factory_no_input',
      'severity', 'critical',
      'category', 'factory',
      'title', v_count || ' Fabrikada Hammadde Bitti!',
      'description', 'Reçetedeki zorunlu girdi tükendiği için üretim bantları durdu.',
      'route', '/factories',
      'count', v_count
    ));
  END IF;

  -- 4. FABRİKA ÇIKIŞ DEPOSU DOLU
  SELECT count(*) INTO v_count
  FROM public.factories f
  WHERE f.player_id = v_player_id
    AND f.is_active = true
    AND f.output_capacity > 0
    AND (
      SELECT coalesce(sum(pi.quantity), 0)
      FROM public.production_inventory pi
      WHERE pi.owner_kind = 'factory'
        AND pi.owner_id = f.id
        AND pi.inventory_type = 'output'
    ) >= f.output_capacity;

  IF v_count > 0 THEN
    v_alerts := v_alerts || jsonb_build_array(jsonb_build_object(
      'id', 'factory_output_full',
      'severity', 'critical',
      'category', 'factory',
      'title', v_count || ' Fabrikada Depo Doldu!',
      'description', 'Çıkış ambarı %100 kapasiteye ulaştı, üretim yapılamıyor.',
      'route', '/factories',
      'count', v_count
    ));
  END IF;

  -- 5. FABRİKA BOŞTA
  SELECT count(*) INTO v_count
  FROM public.factories f
  WHERE f.player_id = v_player_id
    AND f.is_active = true
    AND f.product_id IS NULL;

  IF v_count > 0 THEN
    v_alerts := v_alerts || jsonb_build_array(jsonb_build_object(
      'id', 'factory_idle',
      'severity', 'warning',
      'category', 'factory',
      'title', v_count || ' Fabrikada Ürün Seçilmedi',
      'description', 'Tesis aktif ancak üretim reçetesi atanmamış, boşta bekliyor.',
      'route', '/factories',
      'count', v_count
    ));
  END IF;

  -- 6. TARLA (farms) REÇETE BAZLI GİRDİ KONTROLÜ (H07)
  SELECT count(DISTINCT fa.id) INTO v_count
  FROM public.farms fa
  JOIN public.production_slots ps ON ps.owner_kind = 'farm' AND ps.owner_id = fa.id
  JOIN public.products pr ON pr.id = ps.product_id
  WHERE fa.player_id = v_player_id
    AND fa.is_active = true
    AND ps.is_active = true
    AND ps.product_id IS NOT NULL
    AND (
      (pr.hammadde_1_id IS NOT NULL AND (
        SELECT coalesce(sum(pi.quantity + coalesce(pi.pending_quantity, 0)), 0)
        FROM public.production_inventory pi
        WHERE pi.owner_kind = 'farm'
          AND pi.owner_id = fa.id
          AND pi.inventory_type = 'input'
          AND pi.product_id = pr.hammadde_1_id
          AND pi.quality_level = greatest(ps.quality_level - 1, 1)
      ) < coalesce(pr.hammadde_1_miktar, 1))
      OR
      (pr.hammadde_2_id IS NOT NULL AND (
        SELECT coalesce(sum(pi.quantity + coalesce(pi.pending_quantity, 0)), 0)
        FROM public.production_inventory pi
        WHERE pi.owner_kind = 'farm'
          AND pi.owner_id = fa.id
          AND pi.inventory_type = 'input'
          AND pi.product_id = pr.hammadde_2_id
          AND pi.quality_level = greatest(ps.quality_level - 1, 1)
      ) < coalesce(pr.hammadde_2_miktar, 1))
      OR
      (pr.hammadde_3_id IS NOT NULL AND (
        SELECT coalesce(sum(pi.quantity + coalesce(pi.pending_quantity, 0)), 0)
        FROM public.production_inventory pi
        WHERE pi.owner_kind = 'farm'
          AND pi.owner_id = fa.id
          AND pi.inventory_type = 'input'
          AND pi.product_id = pr.hammadde_3_id
          AND pi.quality_level = greatest(ps.quality_level - 1, 1)
      ) < coalesce(pr.hammadde_3_miktar, 1))
    );

  IF v_count > 0 THEN
    v_alerts := v_alerts || jsonb_build_array(jsonb_build_object(
      'id', 'field_no_input',
      'severity', 'critical',
      'category', 'field',
      'title', v_count || ' Tarlada Tohum/Gübre Tükendi!',
      'description', 'Ekim için girdi stoğu bittiği için tarla üretimi durdu.',
      'route', '/farms',
      'count', v_count
    ));
  END IF;

  -- 7. TARLA ÇIKIŞ DEPOSU DOLU
  SELECT count(*) INTO v_count
  FROM public.farms fa
  WHERE fa.player_id = v_player_id
    AND fa.is_active = true
    AND fa.output_capacity > 0
    AND (
      SELECT coalesce(sum(pi.quantity), 0)
      FROM public.production_inventory pi
      WHERE pi.owner_kind = 'farm'
        AND pi.owner_id = fa.id
        AND pi.inventory_type = 'output'
    ) >= fa.output_capacity;

  IF v_count > 0 THEN
    v_alerts := v_alerts || jsonb_build_array(jsonb_build_object(
      'id', 'field_output_full',
      'severity', 'critical',
      'category', 'field',
      'title', v_count || ' Tarlada Depo Doldu!',
      'description', 'Hasat ambarı %100 doldu, yeni hasat depolanamıyor.',
      'route', '/farms',
      'count', v_count
    ));
  END IF;

  -- 8. TARLA EKİM YAPILMADI
  SELECT count(*) INTO v_count
  FROM public.farms fa
  WHERE fa.player_id = v_player_id
    AND fa.is_active = true
    AND NOT EXISTS (
      SELECT 1 FROM public.production_slots ps
      WHERE ps.owner_kind = 'farm'
        AND ps.owner_id = fa.id
        AND ps.is_active = true
        AND ps.product_id IS NOT NULL
    );

  IF v_count > 0 THEN
    v_alerts := v_alerts || jsonb_build_array(jsonb_build_object(
      'id', 'field_idle',
      'severity', 'warning',
      'category', 'field',
      'title', v_count || ' Tarlada Ekim Yapılmadı',
      'description', 'Tarla aktif ancak ekilecek mahsul seçilmemiş, boşta bekliyor.',
      'route', '/farms',
      'count', v_count
    ));
  END IF;

  -- 9. ÇİFTLİK (fields) REÇETE BAZLI YEM / HAMMADDE KONTROLÜ (H07)
  SELECT count(DISTINCT fld.id) INTO v_count
  FROM public.fields fld
  JOIN public.production_slots ps ON ps.owner_kind = 'field' AND ps.owner_id = fld.id
  JOIN public.products pr ON pr.id = ps.product_id
  WHERE fld.player_id = v_player_id
    AND fld.is_active = true
    AND ps.is_active = true
    AND ps.product_id IS NOT NULL
    AND (
      (pr.hammadde_1_id IS NOT NULL AND (
        SELECT coalesce(sum(pi.quantity + coalesce(pi.pending_quantity, 0)), 0)
        FROM public.production_inventory pi
        WHERE pi.owner_kind = 'field'
          AND pi.owner_id = fld.id
          AND pi.inventory_type = 'input'
          AND pi.product_id = pr.hammadde_1_id
          AND pi.quality_level = greatest(ps.quality_level - 1, 1)
      ) < coalesce(pr.hammadde_1_miktar, 1))
      OR
      (pr.hammadde_2_id IS NOT NULL AND (
        SELECT coalesce(sum(pi.quantity + coalesce(pi.pending_quantity, 0)), 0)
        FROM public.production_inventory pi
        WHERE pi.owner_kind = 'field'
          AND pi.owner_id = fld.id
          AND pi.inventory_type = 'input'
          AND pi.product_id = pr.hammadde_2_id
          AND pi.quality_level = greatest(ps.quality_level - 1, 1)
      ) < coalesce(pr.hammadde_2_miktar, 1))
      OR
      (pr.hammadde_3_id IS NOT NULL AND (
        SELECT coalesce(sum(pi.quantity + coalesce(pi.pending_quantity, 0)), 0)
        FROM public.production_inventory pi
        WHERE pi.owner_kind = 'field'
          AND pi.owner_id = fld.id
          AND pi.inventory_type = 'input'
          AND pi.product_id = pr.hammadde_3_id
          AND pi.quality_level = greatest(ps.quality_level - 1, 1)
      ) < coalesce(pr.hammadde_3_miktar, 1))
    );

  IF v_count > 0 THEN
    v_alerts := v_alerts || jsonb_build_array(jsonb_build_object(
      'id', 'farm_no_input',
      'severity', 'critical',
      'category', 'farm',
      'title', v_count || ' Çiftlikte Yem Tükendi!',
      'description', 'Hayvan yemi veya zorunlu girdi bittiği için çiftlik üretimi durdu.',
      'route', '/fields',
      'count', v_count
    ));
  END IF;

  -- 10. ÇİFTLİK ÇIKIŞ DEPOSU DOLU
  SELECT count(*) INTO v_count
  FROM public.fields fld
  WHERE fld.player_id = v_player_id
    AND fld.is_active = true
    AND fld.output_capacity > 0
    AND (
      SELECT coalesce(sum(pi.quantity), 0)
      FROM public.production_inventory pi
      WHERE pi.owner_kind = 'field'
        AND pi.owner_id = fld.id
        AND pi.inventory_type = 'output'
    ) >= fld.output_capacity;

  IF v_count > 0 THEN
    v_alerts := v_alerts || jsonb_build_array(jsonb_build_object(
      'id', 'farm_output_full',
      'severity', 'critical',
      'category', 'farm',
      'title', v_count || ' Çiftlikte Depo Doldu!',
      'description', 'Çiftlik ambarı %100 doldu, yeni üretim durduruldu.',
      'route', '/fields',
      'count', v_count
    ));
  END IF;

  -- 11. ÇİFTLİK BOŞTA
  SELECT count(*) INTO v_count
  FROM public.fields fld
  WHERE fld.player_id = v_player_id
    AND fld.is_active = true
    AND NOT EXISTS (
      SELECT 1 FROM public.production_slots ps
      WHERE ps.owner_kind = 'field'
        AND ps.owner_id = fld.id
        AND ps.is_active = true
        AND ps.product_id IS NOT NULL
    );

  IF v_count > 0 THEN
    v_alerts := v_alerts || jsonb_build_array(jsonb_build_object(
      'id', 'farm_idle',
      'severity', 'warning',
      'category', 'farm',
      'title', v_count || ' Çiftlikte Üretim Yok',
      'description', 'Çiftlik aktif ancak yetiştirilecek ürün veya hayvan seçilmemiş.',
      'route', '/fields',
      'count', v_count
    ));
  END IF;

  -- 12. MADEN ÇIKIŞ DEPOSU DOLU
  SELECT count(*) INTO v_count
  FROM public.mines m
  WHERE m.player_id = v_player_id
    AND m.is_active = true
    AND m.output_capacity > 0
    AND (
      SELECT coalesce(sum(pi.quantity), 0)
      FROM public.production_inventory pi
      WHERE pi.owner_kind = 'mine'
        AND pi.owner_id = m.id
        AND pi.inventory_type = 'output'
    ) >= m.output_capacity;

  IF v_count > 0 THEN
    v_alerts := v_alerts || jsonb_build_array(jsonb_build_object(
      'id', 'mine_output_full',
      'severity', 'critical',
      'category', 'mine',
      'title', v_count || ' Madende Çıktı Deposu Doldu!',
      'description', 'Maden cevher deposu tam kapasiteye ulaştı, kazı durdu.',
      'route', '/mines',
      'count', v_count
    ));
  END IF;

  -- 13. MAĞAZA RAFLAR BOŞALDI
  SELECT count(*) INTO v_count
  FROM public.stores s
  WHERE s.player_id = v_player_id
    AND s.is_active = true
    AND NOT EXISTS (
      SELECT 1 FROM public.store_slots ss
      WHERE ss.store_id = s.id
        AND ss.is_active = true
        AND (ss.quantity + coalesce(ss.pending_quantity, 0)) > 0
    );

  IF v_count > 0 THEN
    v_alerts := v_alerts || jsonb_build_array(jsonb_build_object(
      'id', 'store_out_of_stock',
      'severity', 'critical',
      'category', 'store',
      'title', v_count || ' Mağazada Raflar Tamamen Boş!',
      'description', 'Stok kalmadığı için satış yapılamıyor ve ciro kaybı yaşanıyor.',
      'route', '/store',
      'count', v_count
    ));
  END IF;

  -- 14. MAĞAZADA FİYATI OLMAYAN ÜRÜN
  SELECT count(*) INTO v_count
  FROM public.store_slots ss
  JOIN public.stores s ON s.id = ss.store_id
  WHERE s.player_id = v_player_id
    AND s.is_active = true
    AND ss.is_active = true
    AND ss.product_id IS NOT NULL
    AND (ss.price IS NULL OR ss.price <= 0);

  IF v_count > 0 THEN
    v_alerts := v_alerts || jsonb_build_array(jsonb_build_object(
      'id', 'store_unpriced_items',
      'severity', 'warning',
      'category', 'store',
      'title', v_count || ' Mağaza Slotunda Fiyat Belirlenmedi',
      'description', 'Raflara ürün yerleştirilmiş ancak satış fiyatı girilmemiş.',
      'route', '/store',
      'count', v_count
    ));
  END IF;

  -- 15. LOJİSTİK ARAÇ YAKIT BİTTİ
  SELECT count(*) INTO v_count
  FROM public.logistics_vehicles lv
  WHERE lv.player_id = v_player_id
    AND coalesce(lv.status, '') != 'scrapped'
    AND lv.current_fuel <= 0;

  IF v_count > 0 THEN
    v_alerts := v_alerts || jsonb_build_array(jsonb_build_object(
      'id', 'vehicle_no_fuel',
      'severity', 'critical',
      'category', 'logistics',
      'title', v_count || ' Aracın Yakıtı Bitti!',
      'description', 'Sevkiyat yapamaz durumda. Yakıt ikmali yapılması gerekiyor.',
      'route', '/transfer-map',
      'count', v_count
    ));
  END IF;

  -- 16. LOJİSTİK ARAÇ ACİL BAKIM
  SELECT count(*) INTO v_count
  FROM public.logistics_vehicles lv
  WHERE lv.player_id = v_player_id
    AND coalesce(lv.status, '') != 'scrapped'
    AND lv.condition < 20;

  IF v_count > 0 THEN
    v_alerts := v_alerts || jsonb_build_array(jsonb_build_object(
      'id', 'vehicle_maintenance_urgent',
      'severity', 'warning',
      'category', 'logistics',
      'title', v_count || ' Araç Acil Bakım Bekliyor',
      'description', 'Kondisyon %20''nin altına indi. Arıza ve kaza riski yüksek.',
      'route', '/transfer-map',
      'count', v_count
    ));
  END IF;

  -- 17. İHALE TESLİMATINA SON 2 SAAT
  SELECT count(*) INTO v_count
  FROM public.player_tenders pt
  WHERE pt.player_id = v_player_id
    AND pt.status = 'active'
    AND pt.deadline_at <= (timezone('utc', now()) + interval '2 hours')
    AND pt.delivered_quantity < pt.required_quantity;

  IF v_count > 0 THEN
    v_alerts := v_alerts || jsonb_build_array(jsonb_build_object(
      'id', 'tender_deadline_urgent',
      'severity', 'critical',
      'category', 'tender',
      'title', v_count || ' İhale Teslimatına Son 2 Saat!',
      'description', 'Teslimat süresi dolmak üzere. Teminatın yanmaması için teslimatı tamamlayın.',
      'route', '/tenders',
      'count', v_count
    ));
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'alerts', v_alerts,
    'total_count', jsonb_array_length(v_alerts)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_player_operational_alerts(uuid) TO authenticated;

-- ============================================================================
-- 3. H07: PROCESS_OPERATIONAL_ALERTS_PUSH_NOTIFICATIONS (REÇETE BAZLI PUSH ALARMI)
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
  -- 1. İHALE ACİL TESLİMAT
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

  -- 3. FABRİKA HAMMADDE BİTTİ (H07 REÇETE DENETİMİ)
  FOR v_rec IN
    SELECT 
      f.player_id,
      count(*) AS empty_count
    FROM public.factories f
    JOIN public.products pr ON pr.id = f.product_id
    WHERE f.is_active = true
      AND f.product_id IS NOT NULL
      AND (
        (pr.hammadde_1_id IS NOT NULL AND (
          SELECT coalesce(sum(pi.quantity + coalesce(pi.pending_quantity, 0)), 0)
          FROM public.production_inventory pi
          WHERE pi.owner_kind = 'factory'
            AND pi.owner_id = f.id
            AND pi.inventory_type = 'input'
            AND pi.product_id = pr.hammadde_1_id
            AND pi.quality_level = greatest(f.quality_level - 1, 1)
        ) < coalesce(pr.hammadde_1_miktar, 1))
        OR
        (pr.hammadde_2_id IS NOT NULL AND (
          SELECT coalesce(sum(pi.quantity + coalesce(pi.pending_quantity, 0)), 0)
          FROM public.production_inventory pi
          WHERE pi.owner_kind = 'factory'
            AND pi.owner_id = f.id
            AND pi.inventory_type = 'input'
            AND pi.product_id = pr.hammadde_2_id
            AND pi.quality_level = greatest(f.quality_level - 1, 1)
        ) < coalesce(pr.hammadde_2_miktar, 1))
        OR
        (pr.hammadde_3_id IS NOT NULL AND (
          SELECT coalesce(sum(pi.quantity + coalesce(pi.pending_quantity, 0)), 0)
          FROM public.production_inventory pi
          WHERE pi.owner_kind = 'factory'
            AND pi.owner_id = f.id
            AND pi.inventory_type = 'input'
            AND pi.product_id = pr.hammadde_3_id
            AND pi.quality_level = greatest(f.quality_level - 1, 1)
        ) < coalesce(pr.hammadde_3_miktar, 1))
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
        v_rec.empty_count || ' fabrikanızda reçetedeki zorunlu girdi tükendiği için üretim bantları durdu. Yeni girdi sevkiyatı planlayın.',
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

  -- 4. TARLA (farms) GİRDİ BİTTİ (H07 REÇETE DENETİMİ)
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
      AND (
        (pr.hammadde_1_id IS NOT NULL AND (
          SELECT coalesce(sum(pi.quantity + coalesce(pi.pending_quantity, 0)), 0)
          FROM public.production_inventory pi
          WHERE pi.owner_kind = 'farm'
            AND pi.owner_id = fa.id
            AND pi.inventory_type = 'input'
            AND pi.product_id = pr.hammadde_1_id
            AND pi.quality_level = greatest(ps.quality_level - 1, 1)
        ) < coalesce(pr.hammadde_1_miktar, 1))
        OR
        (pr.hammadde_2_id IS NOT NULL AND (
          SELECT coalesce(sum(pi.quantity + coalesce(pi.pending_quantity, 0)), 0)
          FROM public.production_inventory pi
          WHERE pi.owner_kind = 'farm'
            AND pi.owner_id = fa.id
            AND pi.inventory_type = 'input'
            AND pi.product_id = pr.hammadde_2_id
            AND pi.quality_level = greatest(ps.quality_level - 1, 1)
        ) < coalesce(pr.hammadde_2_miktar, 1))
        OR
        (pr.hammadde_3_id IS NOT NULL AND (
          SELECT coalesce(sum(pi.quantity + coalesce(pi.pending_quantity, 0)), 0)
          FROM public.production_inventory pi
          WHERE pi.owner_kind = 'farm'
            AND pi.owner_id = fa.id
            AND pi.inventory_type = 'input'
            AND pi.product_id = pr.hammadde_3_id
            AND pi.quality_level = greatest(ps.quality_level - 1, 1)
        ) < coalesce(pr.hammadde_3_miktar, 1))
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

  -- 5. ÇİFTLİK (fields) YEM BİTTİ (H07 REÇETE DENETİMİ)
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
      AND (
        (pr.hammadde_1_id IS NOT NULL AND (
          SELECT coalesce(sum(pi.quantity + coalesce(pi.pending_quantity, 0)), 0)
          FROM public.production_inventory pi
          WHERE pi.owner_kind = 'field'
            AND pi.owner_id = fld.id
            AND pi.inventory_type = 'input'
            AND pi.product_id = pr.hammadde_1_id
            AND pi.quality_level = greatest(ps.quality_level - 1, 1)
        ) < coalesce(pr.hammadde_1_miktar, 1))
        OR
        (pr.hammadde_2_id IS NOT NULL AND (
          SELECT coalesce(sum(pi.quantity + coalesce(pi.pending_quantity, 0)), 0)
          FROM public.production_inventory pi
          WHERE pi.owner_kind = 'field'
            AND pi.owner_id = fld.id
            AND pi.inventory_type = 'input'
            AND pi.product_id = pr.hammadde_2_id
            AND pi.quality_level = greatest(ps.quality_level - 1, 1)
        ) < coalesce(pr.hammadde_2_miktar, 1))
        OR
        (pr.hammadde_3_id IS NOT NULL AND (
          SELECT coalesce(sum(pi.quantity + coalesce(pi.pending_quantity, 0)), 0)
          FROM public.production_inventory pi
          WHERE pi.owner_kind = 'field'
            AND pi.owner_id = fld.id
            AND pi.inventory_type = 'input'
            AND pi.product_id = pr.hammadde_3_id
            AND pi.quality_level = greatest(ps.quality_level - 1, 1)
        ) < coalesce(pr.hammadde_3_miktar, 1))
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
        v_rec.empty_count || ' çiftliğinizde hayvan yemi veya zorunlu girdi tükendiği için üretim durdu. Yeni yem sevkiyatı yapın.',
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
