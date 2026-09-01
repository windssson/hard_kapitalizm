-- ==============================================================================
-- MIGRATION: Operational Alerts System (Uyarı Sistemi)
-- Created: 2026-09-01
-- Description: State-driven real-time operational risk and bottleneck detection
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.get_player_operational_alerts(p_player_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_player_id uuid := coalesce(p_player_id, auth.uid());
  v_alerts jsonb := '[]'::jsonb;
  
  v_count integer;
  v_tax_debt numeric;
  v_tax_limit numeric;
  v_is_tax_blocked boolean;
  v_level integer;
BEGIN
  IF v_player_id IS NULL THEN
    RETURN '[]'::jsonb;
  END IF;

  -- 1. VERGİ KONTROLÜ
  SELECT coalesce(tax_debt, 0) INTO v_tax_debt
  FROM public.player_taxes WHERE player_id = v_player_id;
  
  SELECT coalesce(level, 1) INTO v_level
  FROM public.players WHERE id = v_player_id;
  
  v_tax_limit := public.get_player_tax_limit(v_level);
  v_is_tax_blocked := coalesce(v_tax_debt, 0) > coalesce(v_tax_limit, 0);

  IF v_is_tax_blocked THEN
    v_alerts := v_alerts || jsonb_build_array(jsonb_build_object(
      'id', 'tax_blocked',
      'severity', 'critical',
      'category', 'tax',
      'title', 'Şirket Faaliyetleri Kilitlendi!',
      'description', 'Vergi borcunuz yasal limiti (' || to_char(v_tax_limit, 'FM999G999G999') || ' TL) aştı. Tüm ticari işlemler askıya alındı.',
      'route', '/tax',
      'count', 1
    ));
  ELSIF v_tax_debt > (v_tax_limit * 0.75) AND v_tax_debt > 0 THEN
    v_alerts := v_alerts || jsonb_build_array(jsonb_build_object(
      'id', 'tax_warning',
      'severity', 'warning',
      'category', 'tax',
      'title', 'Vergi Borcu Kritik Seviyede',
      'description', 'Vergi borcunuz yasal limitin %75''ine ulaştı. Kilitlenme riski var.',
      'route', '/tax',
      'count', 1
    ));
  END IF;

  -- 2. BANKA KREDİ TEMERRÜT KONTROLÜ
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

  -- 3. FABRİKA DURUMLARI
  -- 3a. Hammadde yok (Üretim Durdu)
  SELECT count(*) INTO v_count
  FROM public.factories f
  WHERE f.player_id = v_player_id
    AND f.is_active = true
    AND f.product_id IS NOT NULL
    AND NOT EXISTS (
      SELECT 1 FROM public.production_inventory pi
      WHERE pi.owner_kind = 'factory'
        AND pi.owner_id = f.id
        AND pi.inventory_type = 'input'
        AND (pi.quantity + coalesce(pi.pending_quantity, 0)) > 0
    );

  IF v_count > 0 THEN
    v_alerts := v_alerts || jsonb_build_array(jsonb_build_object(
      'id', 'factory_no_input',
      'severity', 'critical',
      'category', 'factory',
      'title', v_count || ' Fabrikada Hammadde Bitti!',
      'description', 'Girdi stoğu tükendiği için üretim bantları tamamen durdu.',
      'route', '/factory',
      'count', v_count
    ));
  END IF;

  -- 3b. Çıkış deposu dolu (Üretim Kilitlendi)
  SELECT count(*) INTO v_count
  FROM public.factories f
  WHERE f.player_id = v_player_id
    AND f.is_active = true
    AND f.output_capacity > 0
    AND (
      SELECT coalesce(sum(pi.quantity + coalesce(pi.pending_quantity, 0)), 0)
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
      'route', '/factory',
      'count', v_count
    ));
  END IF;

  -- 3c. Ürün seçilmemiş (Atıl Tesis)
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
      'route', '/factory',
      'count', v_count
    ));
  END IF;

  -- 4. MADENLER (Depo Dolu)
  SELECT count(*) INTO v_count
  FROM public.mines m
  WHERE m.player_id = v_player_id
    AND m.is_active = true
    AND m.output_capacity > 0
    AND (
      SELECT coalesce(sum(pi.quantity + coalesce(pi.pending_quantity, 0)), 0)
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
      'route', '/mine',
      'count', v_count
    ));
  END IF;

  -- 5. MAĞAZALAR
  -- 5a. Tüm rafları boş mağazalar
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

  -- 5b. Fiyatı belirlenmemiş aktif mağaza ürünleri
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

  -- 6. LOJİSTİK VE FİLO
  -- 6a. Yakıtı tükenmiş araçlar
  SELECT count(*) INTO v_count
  FROM public.logistics_vehicles lv
  WHERE lv.player_id = v_player_id
    AND coalesce(lv.current_fuel, 0) <= 0;

  IF v_count > 0 THEN
    v_alerts := v_alerts || jsonb_build_array(jsonb_build_object(
      'id', 'logistics_no_fuel',
      'severity', 'critical',
      'category', 'logistics',
      'title', v_count || ' Nakliye Aracının Yakıtı Bitti!',
      'description', 'Araçlar yakıt yetersizliği nedeniyle sefere çıkamıyor.',
      'route', '/logistics',
      'count', v_count
    ));
  END IF;

  -- 6b. Düşük kondisyon (< 20)
  SELECT count(*) INTO v_count
  FROM public.logistics_vehicles lv
  WHERE lv.player_id = v_player_id
    AND coalesce(lv.condition, 100) < 20;

  IF v_count > 0 THEN
    v_alerts := v_alerts || jsonb_build_array(jsonb_build_object(
      'id', 'logistics_low_condition',
      'severity', 'warning',
      'category', 'logistics',
      'title', v_count || ' Araçta Acil Bakım Gerekli',
      'description', 'Kondisyon %20''nin altına indi, kaza ve arıza riski yüksek.',
      'route', '/logistics',
      'count', v_count
    ));
  END IF;

  -- 7. İHALELER (Son 2 saat ve tamamlanmamış teslimat)
  SELECT count(*) INTO v_count
  FROM public.player_tenders pt
  WHERE pt.player_id = v_player_id
    AND pt.status = 'active'
    AND pt.deadline_at < (timezone('utc', now()) + interval '2 hours')
    AND pt.delivered_quantity < pt.required_quantity;

  IF v_count > 0 THEN
    v_alerts := v_alerts || jsonb_build_array(jsonb_build_object(
      'id', 'tender_urgent_deadline',
      'severity', 'critical',
      'category', 'tender',
      'title', 'İhale Teslimatına Son 2 Saat!',
      'description', v_count || ' aktif ihalede teslimat henüz bitmedi, teminat yanma riski!',
      'route', '/tenders',
      'count', v_count
    ));
  END IF;

  RETURN v_alerts;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_player_operational_alerts(uuid) TO authenticated, service_role;
