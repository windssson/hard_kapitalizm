-- ============================================================================
-- Migration: 2026-09-07_phase1_security_and_economy_fixes.sql
-- Description:
-- Hard Kapitalizm Teknik İnceleme Raporu - Faz 1 (K01 - K05)
-- 1. K01: players ve ekonomik tablolarda istemcinin doğrudan yazma yetkilerini kapatma
-- 2. K02: RPC'lerde (set_store_slot_price, start_building_construction vb.) auth.uid() oturum kontrolü
-- 3. K03: player_daily_streaks tablosu ve sunucu taraflı güvenli claim_daily_streak_reward
-- 4. K04: add_product_to_warehouse ve add_product_to_warehouse_with_brand helper'larının authenticated rolüne kapatılması
-- 5. K05: set_store_slot_price tavan kontrolü ve open_store_detail_page elastik talep eğrisi (taban talep açığının giderilmesi)
-- ============================================================================

-- ============================================================================
-- 1. K01: İSTEMCİNİN DOĞRUDAN TABLO YAZMA YETKİLERİNİN KALDIRILMASI
-- ============================================================================

REVOKE INSERT, UPDATE, DELETE ON TABLE public.players FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.production_inventory FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.building_constructions FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.building_boosts FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.player_product_quality_levels FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.player_missions FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.player_achievements FROM anon, authenticated;

-- Aşırı yetkili doğrudan yazma RLS politikalarının kaldırılması (Tüm yazmalar SECURITY DEFINER RPC ile yapılır)
DROP POLICY IF EXISTS "Users can update their own player data" ON public.players;
DROP POLICY IF EXISTS "Users can insert their own player data" ON public.players;

DROP POLICY IF EXISTS "Users can update their own building boosts" ON public.building_boosts;
DROP POLICY IF EXISTS "Users can insert their own building boosts" ON public.building_boosts;

DROP POLICY IF EXISTS "Users can update their own building constructions" ON public.building_constructions;
DROP POLICY IF EXISTS "Users can insert their own building constructions" ON public.building_constructions;

DROP POLICY IF EXISTS "Players can update owned production inventory" ON public.production_inventory;
DROP POLICY IF EXISTS "Players can insert owned production inventory" ON public.production_inventory;
DROP POLICY IF EXISTS "Players can delete owned production inventory" ON public.production_inventory;

DROP POLICY IF EXISTS "player_product_quality_levels_update_own" ON public.player_product_quality_levels;
DROP POLICY IF EXISTS "player_product_quality_levels_insert_own" ON public.player_product_quality_levels;

DROP POLICY IF EXISTS "player_missions_update_own" ON public.player_missions;
DROP POLICY IF EXISTS "player_missions_insert_own" ON public.player_missions;

DROP POLICY IF EXISTS "player_achievements_update_own" ON public.player_achievements;
DROP POLICY IF EXISTS "player_achievements_insert_own" ON public.player_achievements;

-- Güvenli SELECT okuma yetkilerini koru
GRANT SELECT ON TABLE public.players TO authenticated;
GRANT SELECT ON TABLE public.production_inventory TO authenticated;
GRANT SELECT ON TABLE public.building_constructions TO authenticated;
GRANT SELECT ON TABLE public.building_boosts TO authenticated;
GRANT SELECT ON TABLE public.player_product_quality_levels TO authenticated;
GRANT SELECT ON TABLE public.player_missions TO authenticated;
GRANT SELECT ON TABLE public.player_achievements TO authenticated;

-- ============================================================================
-- 2. K04: İÇ DEPO STOK EKLEME YARDIMCILARININ İSTEMCİYE KAPATILMASI
-- ============================================================================

REVOKE EXECUTE ON FUNCTION public.add_product_to_warehouse(uuid, uuid, text, integer, integer, numeric, numeric, boolean) FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.add_product_to_warehouse_with_brand(uuid, uuid, text, integer, uuid, integer, numeric, numeric, boolean, uuid) FROM anon, authenticated;

-- ============================================================================
-- 3. K02 & K05: SET_STORE_SLOT_PRICE (OTURUM DOĞRULAMASI + FİYAT TAVANI)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.set_store_slot_price(
  p_player_id uuid,
  p_store_slot_id uuid,
  p_price numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
declare
  v_slot record;
  v_base_price numeric;
  v_max_allowed_price numeric;
begin
  if auth.uid() is null then
    raise exception 'Yetkisiz erişim: Oturum açılmamış.';
  end if;

  -- Slotu ve bağlı mağazayı kilitleyerek al
  select
    ss.*,
    s.player_id as owner_player_id
  into v_slot
  from public.store_slots ss
  join public.stores s on s.id = ss.store_id
  where ss.id = p_store_slot_id
  for update;

  if not found then
    raise exception 'Mağaza slotu bulunamadı.';
  end if;

  -- K02 DÜZELTME: Oturum kimliği doğrulaması
  if v_slot.owner_player_id <> auth.uid() or (p_player_id is not null and p_player_id <> auth.uid()) then
    raise exception 'Bu slot oyuncuya ait değil.';
  end if;

  if v_slot.product_id is null or v_slot.quality_level = 0 then
    raise exception 'Fiyat belirlemek için önce slotta ürün ve kalite seçilmelidir.';
  end if;

  if p_price is null or p_price <= 0 then
    raise exception 'Satış fiyatı 0''dan büyük olmalıdır.';
  end if;

  -- K05 DÜZELTME: Tavan fiyat kontrolü (baz satış fiyatının en fazla 5 katı)
  select baz_satis_fiyati into v_base_price
  from public.products
  where id = v_slot.product_id;

  v_max_allowed_price := coalesce(v_base_price, 100) * 5.0;
  if p_price > v_max_allowed_price then
    raise exception 'Satış fiyatı piyasa tavanının (% TL) üzerinde olamaz.', v_max_allowed_price;
  end if;

  -- Fiyat değişiminde geçmiş sürenin yeni fiyatla istismar edilmemesi için last_sale_processed_at güncellenir
  update public.store_slots
  set
    price = p_price,
    last_sale_processed_at = timezone('utc'::text, now()),
    updated_at = timezone('utc'::text, now())
  where id = p_store_slot_id;

  return jsonb_build_object(
    'success', true,
    'store_slot_id', p_store_slot_id,
    'store_id', v_slot.store_id,
    'product_id', v_slot.product_id,
    'quality_level', v_slot.quality_level,
    'price', p_price
  );
end;
$$;

GRANT EXECUTE ON FUNCTION public.set_store_slot_price(uuid, uuid, numeric) TO authenticated;

-- ============================================================================
-- 4. K02: SET_STORE_SLOT_ACTIVE (OTURUM DOĞRULAMASI)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.set_store_slot_active(
  p_player_id uuid,
  p_store_slot_id uuid,
  p_is_active boolean
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
declare
  v_slot record;
begin
  if auth.uid() is null then
    raise exception 'Yetkisiz erişim: Oturum açılmamış.';
  end if;

  -- Slotu ve bağlı mağazayı kilitleyerek al
  select
    ss.*,
    s.player_id as owner_player_id
  into v_slot
  from public.store_slots ss
  join public.stores s on s.id = ss.store_id
  where ss.id = p_store_slot_id
  for update;

  if not found then
    raise exception 'Mağaza slotu bulunamadı.';
  end if;

  -- K02 DÜZELTME: Oturum kimliği doğrulaması
  if v_slot.owner_player_id <> auth.uid() or (p_player_id is not null and p_player_id <> auth.uid()) then
    raise exception 'Bu slot oyuncuya ait değil.';
  end if;

  update public.store_slots
  set
    is_active = p_is_active,
    updated_at = timezone('utc'::text, now())
  where id = p_store_slot_id;

  return jsonb_build_object(
    'success', true,
    'store_slot_id', p_store_slot_id,
    'store_id', v_slot.store_id,
    'is_active', p_is_active
  );
end;
$$;

GRANT EXECUTE ON FUNCTION public.set_store_slot_active(uuid, uuid, boolean) TO authenticated;

-- ============================================================================
-- 5. K02: START_BUILDING_CONSTRUCTION (OTURUM DOĞRULAMASI)
-- ============================================================================

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
SET search_path = public, extensions
AS $$
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
  -- K02 DÜZELTME: Oturum kimliği doğrulaması
  IF auth.uid() IS NULL OR (p_player_id IS NOT NULL AND p_player_id <> auth.uid()) THEN
    RETURN jsonb_build_object('success', false, 'message', 'Yetkisiz istek: Oturum kimliği eşleşmiyor.');
  END IF;
  p_player_id := auth.uid();

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

  -- KURAL 1: Depo haricindeki tüm binalar için o şehirde Genel Depo bulunması zorunludur!
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

  -- KURAL 2: Aynı şehirde en fazla 1 adet Genel Depo bulunabilir!
  IF p_building_kind = 'warehouse' THEN
    IF EXISTS (
      SELECT 1 FROM public.warehouses
      WHERE player_id = p_player_id
        AND city_id = p_city_id
        AND is_active = true
        AND (warehouse_kind IS NULL OR warehouse_kind IN ('general', 'normal'))
    ) OR EXISTS (
      SELECT 1 FROM public.building_constructions
      WHERE player_id = p_player_id
        AND building_kind = 'warehouse'
        AND status = 'in_progress'
        AND (params ->> 'city_id')::uuid = p_city_id
    ) THEN
      RETURN jsonb_build_object(
        'success', false,
        'message', 'Bu şehirde zaten aktif veya inşaatı süren bir Genel Deponuz bulunmaktadır. Her şehirde en fazla 1 adet Genel Depo bulunabilir. Kapasiteyi artırmak için mevcut deponuzu yükseltebilirsiniz.'
      );
    END IF;
  END IF;

  IF p_building_kind = 'store' THEN
    SELECT coalesce(cost, 0), coalesce(required_level, 1), coalesce(construction_time_minutes, 0),
      jsonb_build_object(
        'store_type_id', id,
        'city_id', p_city_id,
        'name', coalesce(v_clean_name, name),
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
      jsonb_build_object('warehouse_type_id', id, 'city_id', p_city_id, 'name', coalesce(v_clean_name, 'Genel Depo'), 'cost', coalesce(cost, 0),
        'required_level', coalesce(required_level, 1), 'construction_time_minutes', coalesce(construction_time_minutes, 0),
        'level', 1, 'capacity', coalesce(base_capacity, 15000), 'reserved_capacity', 0)
    INTO v_cost, v_required_level, v_construction_time_minutes, v_params
    FROM public.warehouse_types WHERE id = p_type_id;
  ELSIF p_building_kind = 'factory' THEN
    SELECT coalesce(cost, 0), coalesce(required_level, 1), coalesce(construction_time_minutes, 0),
      jsonb_build_object('factory_type_id', id, 'city_id', p_city_id, 'name', coalesce(v_clean_name, name), 'cost', coalesce(cost, 0),
        'required_level', coalesce(required_level, 1), 'construction_time_minutes', coalesce(construction_time_minutes, 0),
        'level', 1, 'quality_level', 0, 'boost_multiplier', 1.00, 'input_capacity', coalesce(input_capacity, 0), 'output_capacity', coalesce(output_capacity, 0))
    INTO v_cost, v_required_level, v_construction_time_minutes, v_params
    FROM public.factory_types WHERE id = p_type_id;
  ELSIF p_building_kind = 'field' THEN
    SELECT coalesce(cost, 0), coalesce(required_level, 1), coalesce(construction_time_minutes, 0),
      jsonb_build_object('field_type_id', id, 'city_id', p_city_id, 'name', coalesce(v_clean_name, name), 'cost', coalesce(cost, 0),
        'required_level', coalesce(required_level, 1), 'construction_time_minutes', coalesce(construction_time_minutes, 0),
        'level', 1, 'current_slot_count', 0, 'max_slot_count', coalesce(max_slot_count, 5),
        'input_capacity', coalesce(input_capacity, 0), 'output_capacity', coalesce(output_capacity, 0))
    INTO v_cost, v_required_level, v_construction_time_minutes, v_params
    FROM public.field_types WHERE id = p_type_id;
  ELSIF p_building_kind = 'farm' THEN
    SELECT coalesce(cost, 0), coalesce(required_level, 1), coalesce(construction_time_minutes, 0),
      jsonb_build_object('farm_type_id', id, 'city_id', p_city_id, 'name', coalesce(v_clean_name, name), 'cost', coalesce(cost, 0),
        'required_level', coalesce(required_level, 1), 'construction_time_minutes', coalesce(construction_time_minutes, 0),
        'level', 1, 'current_slot_count', 0, 'max_slot_count', coalesce(max_slot_count, 5),
        'input_capacity', coalesce(input_capacity, 0), 'output_capacity', coalesce(output_capacity, 0))
    INTO v_cost, v_required_level, v_construction_time_minutes, v_params
    FROM public.farm_types WHERE id = p_type_id;
  ELSIF p_building_kind = 'mine' THEN
    SELECT coalesce(cost, 0), coalesce(required_level, 1), coalesce(construction_time_minutes, 0),
      jsonb_build_object('mine_type_id', id, 'city_id', p_city_id, 'name', coalesce(v_clean_name, name), 'cost', coalesce(cost, 0),
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
$$;

GRANT EXECUTE ON FUNCTION public.start_building_construction(uuid, uuid, text, uuid, text) TO authenticated;

-- ============================================================================
-- 6. K02: PROCESS_PLAYER_PRODUCTION_ENTRY (OTURUM DOĞRULAMASI)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.process_player_production_entry(
  p_player_id uuid DEFAULT auth.uid(),
  p_owner_kind text DEFAULT NULL::text,
  p_owner_id uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_boosts_result jsonb := jsonb_build_object('success', true, 'completed_count', 0);
  v_upgrades_result jsonb := jsonb_build_object('success', true, 'completed_count', 0);
  v_production_result jsonb;
BEGIN
  -- K02 DÜZELTME: Oturum kimliği doğrulaması
  IF auth.uid() IS NULL OR (p_player_id IS NOT NULL AND p_player_id <> auth.uid()) THEN
    RAISE EXCEPTION 'Yetkisiz erişim: Oturum kimliği eşleşmiyor.';
  END IF;
  p_player_id := auth.uid();

  IF public.is_player_tax_blocked(p_player_id) THEN
    RETURN jsonb_build_object(
      'success', false,
      'tax_blocked', true,
      'message', 'Vergi borcu limiti asildigi icin uretim donduruldu.'
    );
  END IF;

  IF p_owner_kind IS NULL THEN
    v_boosts_result := public.complete_due_player_building_boosts(p_player_id, 100);
    v_upgrades_result := public.complete_due_player_building_upgrades(p_player_id, 100);
  ELSIF p_owner_id IS NOT NULL THEN
    v_upgrades_result := public.complete_due_player_building_upgrades(
      p_player_id,
      100,
      p_owner_kind,
      p_owner_id
    );
  END IF;

  v_production_result := public.process_player_production_core(
    p_player_id,
    p_owner_kind,
    p_owner_id
  );

  RETURN jsonb_build_object(
    'completed_due_building_boosts', CASE
      WHEN p_owner_kind IS NULL THEN v_boosts_result
      ELSE jsonb_build_object('success', true, 'completed_count', 0, 'skipped', true)
    END,
    'completed_due_building_upgrades', v_upgrades_result
  ) || v_production_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.process_player_production_entry(uuid, text, uuid) TO authenticated;

-- ============================================================================
-- 7. K02: GET_PLAYER_OPERATIONAL_ALERTS (OTURUM DOĞRULAMASI + ANON ENGELİ)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_player_operational_alerts(
  p_player_id uuid DEFAULT NULL::uuid
)
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
  -- K02 DÜZELTME: Her zaman gerçek oturum kimliğini kullan, anon'a kapat
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz erişim: Oturum açılmamış.');
  END IF;
  v_player_id := auth.uid();

  -- 1. VERGİ BLOKE VE LİMİT KONTROLÜ
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
      'route', '/factories',
      'count', v_count
    ));
  END IF;

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

  -- 4. TARLALAR (farms tablosu)
  SELECT count(DISTINCT fa.id) INTO v_count
  FROM public.farms fa
  JOIN public.production_slots ps ON ps.owner_kind = 'farm' AND ps.owner_id = fa.id
  JOIN public.products pr ON pr.id = ps.product_id
  WHERE fa.player_id = v_player_id
    AND fa.is_active = true
    AND ps.is_active = true
    AND ps.product_id IS NOT NULL
    AND (pr.hammadde_1_id IS NOT NULL OR pr.hammadde_2_id IS NOT NULL OR pr.hammadde_3_id IS NOT NULL)
    AND NOT EXISTS (
      SELECT 1 FROM public.production_inventory pi
      WHERE pi.owner_kind = 'farm'
        AND pi.owner_id = fa.id
        AND pi.inventory_type = 'input'
        AND (pi.quantity + coalesce(pi.pending_quantity, 0)) > 0
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

  -- 5. ÇİFTLİKLER (fields tablosu)
  SELECT count(DISTINCT fld.id) INTO v_count
  FROM public.fields fld
  JOIN public.production_slots ps ON ps.owner_kind = 'field' AND ps.owner_id = fld.id
  JOIN public.products pr ON pr.id = ps.product_id
  WHERE fld.player_id = v_player_id
    AND fld.is_active = true
    AND ps.is_active = true
    AND ps.product_id IS NOT NULL
    AND (pr.hammadde_1_id IS NOT NULL OR pr.hammadde_2_id IS NOT NULL OR pr.hammadde_3_id IS NOT NULL)
    AND NOT EXISTS (
      SELECT 1 FROM public.production_inventory pi
      WHERE pi.owner_kind = 'field'
        AND pi.owner_id = fld.id
        AND pi.inventory_type = 'input'
        AND (pi.quantity + coalesce(pi.pending_quantity, 0)) > 0
    );

  IF v_count > 0 THEN
    v_alerts := v_alerts || jsonb_build_array(jsonb_build_object(
      'id', 'farm_no_input',
      'severity', 'critical',
      'category', 'farm',
      'title', v_count || ' Çiftlikte Yem Tükendi!',
      'description', 'Hayvan yemi veya girdi bittiği için çiftlik üretimi durdu.',
      'route', '/fields',
      'count', v_count
    ));
  END IF;

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

  -- 6. MADENLER
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

  -- 7. MAĞAZALAR
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

  -- 8. LOJİSTİK & FİLO
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

  -- 9. İHALELER
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

REVOKE EXECUTE ON FUNCTION public.get_player_operational_alerts(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.get_player_operational_alerts(uuid) TO authenticated;

-- ============================================================================
-- 8. K03: GÜNLÜK GİRİŞ SERİSİ (TABLO + GETTER + PARAMETRESİZ GÜVENLİ CLAIM)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.player_daily_streaks (
    player_id uuid PRIMARY KEY REFERENCES public.players(id) ON DELETE CASCADE,
    streak_count integer NOT NULL DEFAULT 0,
    last_claimed_date date,
    last_claimed_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
    updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

ALTER TABLE public.player_daily_streaks ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "player_daily_streaks_select_own" ON public.player_daily_streaks;
CREATE POLICY "player_daily_streaks_select_own" ON public.player_daily_streaks
    FOR SELECT USING (auth.uid() = player_id);

GRANT SELECT ON public.player_daily_streaks TO authenticated;

CREATE OR REPLACE FUNCTION public.get_player_daily_streak()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_player_id uuid := auth.uid();
  v_streak record;
  v_today date := (timezone('Europe/Istanbul', now()))::date;
  v_can_claim boolean := true;
  v_active_streak integer := 0;
BEGIN
  IF v_player_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Oturum acilmamis.');
  END IF;

  SELECT * INTO v_streak FROM public.player_daily_streaks WHERE player_id = v_player_id;

  IF FOUND THEN
    IF v_streak.last_claimed_date = v_today THEN
      v_can_claim := false;
      v_active_streak := v_streak.streak_count;
    ELSIF v_streak.last_claimed_date = v_today - 1 THEN
      v_can_claim := true;
      v_active_streak := v_streak.streak_count;
    ELSE
      -- Seri bozulmuş, sıfırla
      v_can_claim := true;
      v_active_streak := 0;
    END IF;
  ELSE
    v_can_claim := true;
    v_active_streak := 0;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'streak_count', v_active_streak,
    'can_claim_today', v_can_claim,
    'last_claimed_date', CASE WHEN v_streak.last_claimed_date IS NOT NULL THEN v_streak.last_claimed_date::text ELSE null END,
    'last_claimed_at', v_streak.last_claimed_at
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_player_daily_streak() TO authenticated;

-- Eski parametreli claim fonksiyonunu kaldırıyoruz
DROP FUNCTION IF EXISTS public.claim_daily_streak_reward(numeric, numeric);

CREATE OR REPLACE FUNCTION public.claim_daily_streak_reward()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_player_id uuid := auth.uid();
  v_streak record;
  v_today date := (timezone('Europe/Istanbul', now()))::date;
  v_now timestamptz := timezone('utc', now());
  v_next_streak integer := 1;
  v_reward_cash numeric := 0;
  v_reward_gold numeric := 0;
  v_new_cash numeric;
  v_new_gold numeric;
BEGIN
  IF v_player_id IS NULL THEN
    RAISE EXCEPTION 'Oturum acilmamis.';
  END IF;

  -- Kilit altında satırı al
  SELECT * INTO v_streak
  FROM public.player_daily_streaks
  WHERE player_id = v_player_id
  FOR UPDATE;

  IF FOUND THEN
    IF v_streak.last_claimed_date = v_today THEN
      RAISE EXCEPTION 'Bugünkü ödül zaten alındı.';
    ELSIF v_streak.last_claimed_date = v_today - 1 THEN
      v_next_streak := v_streak.streak_count + 1;
      IF v_next_streak > 7 THEN
        v_next_streak := 1;
      END IF;
    ELSE
      v_next_streak := 1;
    END IF;
  ELSE
    v_next_streak := 1;
  END IF;

  -- Sunucu tarafı sabit ödül matrisi
  CASE v_next_streak
    WHEN 1 THEN v_reward_cash := 5000;  v_reward_gold := 0;
    WHEN 2 THEN v_reward_cash := 10000; v_reward_gold := 0;
    WHEN 3 THEN v_reward_cash := 0;     v_reward_gold := 1;
    WHEN 4 THEN v_reward_cash := 15000; v_reward_gold := 0;
    WHEN 5 THEN v_reward_cash := 0;     v_reward_gold := 2;
    WHEN 6 THEN v_reward_cash := 25000; v_reward_gold := 0;
    WHEN 7 THEN v_reward_cash := 50000; v_reward_gold := 5;
    ELSE        v_reward_cash := 5000;  v_reward_gold := 0;
  END CASE;

  -- Günlük seriyi kaydet
  INSERT INTO public.player_daily_streaks (
    player_id, streak_count, last_claimed_date, last_claimed_at, created_at, updated_at
  ) VALUES (
    v_player_id, v_next_streak, v_today, v_now, v_now, v_now
  )
  ON CONFLICT (player_id) DO UPDATE SET
    streak_count = v_next_streak,
    last_claimed_date = v_today,
    last_claimed_at = v_now,
    updated_at = v_now;

  -- Oyuncu bakiyesini artır
  UPDATE public.players
  SET cash = cash + v_reward_cash,
      gold = gold + v_reward_gold
  WHERE id = v_player_id
  RETURNING cash, gold INTO v_new_cash, v_new_gold;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Oyuncu bulunamadi.';
  END IF;

  IF v_reward_cash > 0 THEN
    PERFORM public.log_player_cash_change(
      v_player_id,
      v_reward_cash,
      v_new_cash,
      'daily_streak_reward',
      format('Günlük Giriş Ödülü (Gün %s)', v_next_streak),
      null,
      'reward'
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Günlük giriş ödülü alındı.',
    'streak_count', v_next_streak,
    'reward_cash', v_reward_cash,
    'reward_gold', v_reward_gold,
    'new_cash', v_new_cash,
    'new_gold', v_new_gold,
    'changed', jsonb_build_object(
      'player', public.get_player_profile(v_player_id),
      'dashboard_dirty', true
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.claim_daily_streak_reward() TO authenticated;

-- ============================================================================
-- 9. K05: OPEN_STORE_DETAIL_PAGE (TABAN TALEP KALDIRILMASI & GERÇEKÇİ ELASTİK TALEP)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.open_store_detail_page(p_store_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
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
      IF v_elapsed_minutes < 1.0 THEN
        CONTINUE;
      END IF;

      v_processed := true;
      IF v_elapsed_minutes > v_elapsed_minutes_max THEN
        v_elapsed_minutes_max := round(v_elapsed_minutes)::integer;
      END IF;

      -- Pazarlama katkıları (hız ve fiyat esnekliği)
      SELECT
        coalesce(
          sum(
            CASE c.campaign_type
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
            CASE c.campaign_type
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

      v_mkt_speed_mult := 1.0 + v_mkt_speed_contrib;
      v_mkt_price_mult := 1.0 + v_mkt_price_contrib;

      v_quality_multiplier := CASE v_slot.quality_level
        WHEN 1 THEN 0.8
        WHEN 2 THEN 0.95
        WHEN 3 THEN 1.10
        WHEN 4 THEN 1.30
        WHEN 5 THEN 1.60
        ELSE 1.0
      END;

      -- Marka seviyesi sorgusu
      IF v_slot.brand_id IS NOT NULL AND v_slot.brand_id <> '00000000-0000-0000-0000-000000000000'::uuid THEN
        SELECT coalesce(brand_level, 1) INTO v_brand_level
        FROM public.brand_companies
        WHERE id = v_slot.brand_id;
      ELSE
        v_brand_level := 1;
      END IF;

      v_brand_multiplier := CASE
        WHEN v_brand_level = 1 THEN 1.05
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

        -- K05 DÜZELTME: Sınırsız fiyat / taban talep açığı kapatıldı.
        -- 3.5 katı üzerinde müşteri talebi tamamen 0 olur.
        IF v_price_ratio >= 3.5 THEN
          v_price_multiplier := 0.0;
        ELSIF v_price_ratio > 1.0 THEN
          v_price_multiplier := 1.0 / (v_price_ratio ^ 2.5);
        ELSE
          v_price_multiplier := least(2.5, 1.0 / (v_price_ratio ^ 1.2));
        END IF;
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

        -- Marka XP ve Seviye Güncellemesi
        IF v_slot.brand_id IS NOT NULL AND v_slot.brand_id <> '00000000-0000-0000-0000-000000000000'::uuid THEN
          UPDATE public.brand_companies
          SET brand_xp = brand_xp + v_sold_qty,
              brand_level = public.calculate_brand_level(brand_xp + v_sold_qty),
              updated_at = v_now
          WHERE id = v_slot.brand_id;
        END IF;

        INSERT INTO public.store_daily_performance (
          performance_date,
          player_id,
          store_id,
          store_slot_id,
          slot_index,
          product_id,
          product_name,
          quality_level,
          brand_id,
          sold_quantity,
          revenue,
          profit,
          sale_event_count,
          last_sale_at,
          created_at,
          updated_at
        )
        VALUES (
          v_performance_date,
          v_player_id,
          p_store_id,
          v_slot.id,
          v_slot.slot_index,
          v_slot.product_id,
          v_slot.urun_adi,
          v_slot.quality_level,
          v_slot.brand_id,
          v_sold_qty,
          v_revenue,
          v_profit,
          1,
          v_now,
          v_now,
          v_now
        )
        ON CONFLICT (performance_date, store_slot_id)
        DO UPDATE SET
          sold_quantity = public.store_daily_performance.sold_quantity + excluded.sold_quantity,
          revenue = public.store_daily_performance.revenue + excluded.revenue,
          profit = public.store_daily_performance.profit + excluded.profit,
          sale_event_count = public.store_daily_performance.sale_event_count + 1,
          last_sale_at = excluded.last_sale_at,
          product_name = coalesce(excluded.product_name, public.store_daily_performance.product_name),
          brand_id = coalesce(excluded.brand_id, public.store_daily_performance.brand_id),
          updated_at = v_now;

        v_items := v_items || jsonb_build_object(
          'store_slot_id', v_slot.id,
          'product_id', v_slot.product_id,
          'product_name', v_slot.urun_adi,
          'quality_level', v_slot.quality_level,
          'brand_id', v_slot.brand_id,
          'sold_quantity', v_sold_qty,
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

  -- 5. Mağaza JSON oluşturma
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
      'construction_time_minutes', st.construction_time_minutes,
      'accepted_product_ids', st.accepted_product_ids
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
      coalesce(warehouse_cap.used_capacity, 0) AS warehouse_used_capacity,
      coalesce(warehouse_summary.slots, '[]'::jsonb) AS warehouse_slots,
      jsonb_build_object(
        'id', w.id,
        'name', w.name,
        'capacity', coalesce(w.capacity, 0),
        'used_capacity', coalesce(warehouse_cap.used_capacity, 0),
        'slots', coalesce(warehouse_summary.slots, '[]'::jsonb)
      ) AS payload
    FROM public.warehouses w
    LEFT JOIN LATERAL (
      SELECT
        coalesce(sum(ws.quantity * coalesce(p.birim_hacim, 0)), 0) AS used_capacity
      FROM public.warehouse_slots ws
      LEFT JOIN public.products p ON p.id = ws.product_id
      WHERE ws.warehouse_id = w.id
    ) warehouse_cap ON true
    LEFT JOIN LATERAL (
      SELECT
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
        AND ws.product_id IS NOT NULL
        AND coalesce(ws.quantity, 0) > 0
        AND (
          st.accepted_product_ids IS NULL
          OR ws.product_id = ANY(regexp_split_to_array(st.accepted_product_ids, '\\s*,\\s*'))
        )
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

GRANT EXECUTE ON FUNCTION public.open_store_detail_page(uuid) TO authenticated;
