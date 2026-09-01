-- ==============================================================================
-- MIGRATION: Smart Cooldown-Protected Operational Alerts Push Notifications
-- Created: 2026-09-01
-- Description: Sends FCM push notifications for critical emergencies with anti-spam cooldown
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.player_alert_push_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id uuid NOT NULL REFERENCES public.players(id) ON DELETE CASCADE,
  alert_key text NOT NULL,
  last_sent_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT uq_player_alert_push UNIQUE (player_id, alert_key)
);

CREATE INDEX IF NOT EXISTS idx_player_alert_push_logs_lookup
  ON public.player_alert_push_logs (player_id, alert_key, last_sent_at);

CREATE OR REPLACE FUNCTION public.process_operational_alerts_push_notifications()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_rec record;
  v_sent_count integer := 0;
  v_now timestamptz := timezone('utc', now());
BEGIN
  -- 1. İHALE ACİL TESLİMAT (Son 2 saat, teslimat tamamlanmamış)
  -- Cooldown: İhale başına 1 kez (veya 24 saat)
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
        '/tenders',
        jsonb_build_object('tender_id', v_rec.tender_assignment_id),
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

  -- 2. VERGİ BLOKE UYARISI (Yasal limit aşıldı, şirket kilitlendi)
  -- Cooldown: 12 saatte en fazla 1 kez
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
        '/tax',
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

  -- 3. FABRİKA HAMMADDE BİTTİ (Üretim Durdu)
  -- Cooldown: 8 saatte en fazla 1 kez
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
        '🏭 Üretim Durdu: Hammadde Yok!',
        v_rec.empty_count || ' fabrikanızda hammadde tükendiği için üretim bantları durdu. Yeni hammadde sevkiyatı planlayın.',
        'factory',
        '/factory',
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

  -- 4. MAĞAZA RAFLARI BOŞALDI (Satış Durdu)
  -- Cooldown: 8 saatte en fazla 1 kez
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
        '/store',
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

  -- 5. TESİS ÇIKIŞ DEPOSU DOLDU (Maden veya Fabrika Ambarı Dolu - Üretim Kilitlendi)
  -- Cooldown: 8 saatte en fazla 1 kez
  FOR v_rec IN
    SELECT 
      owner_player_id AS player_id,
      count(*) AS full_count
    FROM (
      SELECT 
        m.player_id AS owner_player_id,
        m.id
      FROM public.mines m
      WHERE m.is_active = true
        AND m.output_capacity > 0
        AND (
          SELECT coalesce(sum(quantity + coalesce(pending_quantity, 0)), 0)
          FROM public.production_inventory pi
          WHERE pi.owner_kind = 'mine' AND pi.owner_id = m.id AND pi.inventory_type = 'output'
        ) >= m.output_capacity
      UNION ALL
      SELECT 
        f.player_id AS owner_player_id,
        f.id
      FROM public.factories f
      WHERE f.is_active = true
        AND f.output_capacity > 0
        AND (
          SELECT coalesce(sum(quantity + coalesce(pending_quantity, 0)), 0)
          FROM public.production_inventory pi
          WHERE pi.owner_kind = 'factory' AND pi.owner_id = f.id AND pi.inventory_type = 'output'
        ) >= f.output_capacity
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
        '/mine',
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
$function$;

GRANT EXECUTE ON FUNCTION public.process_operational_alerts_push_notifications() TO authenticated, service_role;

-- Schedule in pg_cron (runs every 30 minutes)
SELECT cron.schedule(
  'process_operational_alerts_push',
  '*/30 * * * *',
  'SELECT public.process_operational_alerts_push_notifications();'
);
