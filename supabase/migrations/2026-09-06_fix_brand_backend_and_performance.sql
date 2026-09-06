-- ============================================================================
-- Migration: 2026-09-06_fix_brand_backend_and_performance.sql
-- Description:
-- 1. Fix open_store_detail_page:
--    - Use public.brand_companies(brand_level) instead of non-existent public.brands(level).
--    - Update brand XP (brand_xp = brand_xp + v_sold_qty) and brand_level on sales.
--    - Fix marketing campaign multiplier (do not divide percentage bonus by elapsed minutes).
--    - Ensure store_daily_performance records brand_id, product_name, sale_event_count.
-- 2. Fix apply_production_brand_selection trigger:
--    - Add 'factory' and 'mine' owner_kind support for production_slots.
-- 3. Update patent_brand_company_product:
--    - Sync new patent brand_id immediately to active production_slots, factories, mines.
-- 4. Add get_player_brand_performance RPC:
--    - Return total sold, total revenue, total profit, and top 5 branded products.
-- 5. Update update_brand_company RPC:
--    - Support renaming brand with uniqueness & reserve name checks.
-- ============================================================================

-- 1. TRIGGER: apply_production_brand_selection (Factory ve Mine desteği)
CREATE OR REPLACE FUNCTION public.apply_production_brand_selection()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
declare
  v_default_brand uuid := '00000000-0000-0000-0000-000000000000'::uuid;
  v_player_id uuid;
begin
  if coalesce(new.product_id, '') = '' then
    new.brand_id := v_default_brand;
    return new;
  end if;

  if tg_table_name = 'production_slots' then
    if new.owner_kind = 'field' then
      select f.player_id
      into v_player_id
      from public.fields f
      where f.id = new.owner_id;
    elsif new.owner_kind = 'farm' then
      select fa.player_id
      into v_player_id
      from public.farms fa
      where fa.id = new.owner_id;
    elsif new.owner_kind = 'factory' then
      select fa.player_id
      into v_player_id
      from public.factories fa
      where fa.id = new.owner_id;
    elsif new.owner_kind = 'mine' then
      select m.player_id
      into v_player_id
      from public.mines m
      where m.id = new.owner_id;
    else
      v_player_id := null;
    end if;
  else
    v_player_id := new.player_id;
  end if;

  new.brand_id := public.resolve_player_product_brand(v_player_id, new.product_id);
  return new;
end;
$$;

-- 2. RPC: patent_brand_company_product (Mevcut üretim binalarını senkronize etme)
CREATE OR REPLACE FUNCTION public.patent_brand_company_product(
  p_product_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_player_id uuid := auth.uid();
  v_company_id uuid;
  v_cash numeric;
  v_patent_cost numeric := 50000.0;
  v_max_quality integer;
BEGIN
  IF v_player_id IS NULL THEN
    RAISE EXCEPTION 'Oturum acilmamis.';
  END IF;

  -- 1. Check if player has an active brand company
  SELECT id INTO v_company_id
  FROM public.brand_companies
  WHERE player_id = v_player_id AND is_active = true
  LIMIT 1;

  IF v_company_id IS NULL THEN
    RAISE EXCEPTION 'Aktif bir marka şirketiniz bulunmuyor.';
  END IF;

  -- 2. Check product quality eligibility (must be max quality level >= 2)
  SELECT COALESCE(MAX(max_quality_level), 1) INTO v_max_quality
  FROM public.player_product_quality_levels
  WHERE player_id = v_player_id AND product_id = p_product_id;

  IF v_max_quality < 2 THEN
    RAISE EXCEPTION 'Bir ürünü patentlemek için en az Q2 kalitesine yükseltmiş olmalısınız.';
  END IF;

  -- 3. Check if already patented
  IF EXISTS (
    SELECT 1 FROM public.brand_company_products
    WHERE brand_company_id = v_company_id AND product_id = p_product_id AND is_active = true
  ) THEN
    RAISE EXCEPTION 'Bu ürün zaten markanız altına tescilli.';
  END IF;

  -- 4. Check if player has enough cash
  SELECT cash INTO v_cash
  FROM public.players
  WHERE id = v_player_id FOR UPDATE;

  IF v_cash < v_patent_cost THEN
    RAISE EXCEPTION 'Bu ürünü patentlemek için yeterli nakitiniz yok (Gerekli: 50.000 ₺).';
  END IF;

  -- 5. Deduct cash & log transaction
  UPDATE public.players
  SET cash = cash - v_patent_cost
  WHERE id = v_player_id;

  PERFORM public.log_player_cash_change(
    v_player_id,
    -v_patent_cost,
    v_cash,
    'patent_expense',
    format('Ürün patentleme harcaması: %s', p_product_id),
    null,
    null
  );

  -- 6. Insert patent entry
  INSERT INTO public.brand_company_products (brand_company_id, player_id, product_id)
  VALUES (v_company_id, v_player_id, p_product_id);

  -- 7. Oyuncunun bu ürünü üreten aktif slot ve binalarının markasını anında güncelle
  UPDATE public.production_slots
  SET brand_id = v_company_id
  WHERE product_id = p_product_id
    AND (
      (owner_kind = 'field' AND owner_id IN (SELECT id FROM public.fields WHERE player_id = v_player_id)) OR
      (owner_kind = 'farm' AND owner_id IN (SELECT id FROM public.farms WHERE player_id = v_player_id)) OR
      (owner_kind = 'factory' AND owner_id IN (SELECT id FROM public.factories WHERE player_id = v_player_id)) OR
      (owner_kind = 'mine' AND owner_id IN (SELECT id FROM public.mines WHERE player_id = v_player_id))
    );

  UPDATE public.factories
  SET brand_id = v_company_id
  WHERE player_id = v_player_id AND product_id = p_product_id;

  UPDATE public.mines
  SET brand_id = v_company_id
  WHERE player_id = v_player_id AND product_id = p_product_id;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Ürün başarıyla markanız altına patentlendi. Bundan sonra yapılacak üretimler markanızla üretilecektir.',
    'changed', jsonb_build_object(
      'player', public.get_player_profile(v_player_id)
    )
  );
END;
$$;

-- 3. RPC: update_brand_company (Marka Adı Güncelleme / Re-branding Desteği)
CREATE OR REPLACE FUNCTION public.update_brand_company(
  p_logo_id text,
  p_theme_color text,
  p_brand_name text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_player_id uuid := auth.uid();
  v_company public.brand_companies%ROWTYPE;
  v_clean_name text;
  v_lower_name text;
  v_len integer;
  v_similar_record record;
BEGIN
  IF v_player_id IS NULL THEN
    RAISE EXCEPTION 'Oturum acilmamis.';
  END IF;

  SELECT *
  INTO v_company
  FROM public.brand_companies
  WHERE player_id = v_player_id
    AND is_active = true
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Oyuncunun aktif marka sirketi yok.';
  END IF;

  v_clean_name := v_company.brand_name;
  IF p_brand_name IS NOT NULL AND btrim(p_brand_name) <> '' AND btrim(p_brand_name) <> v_company.brand_name THEN
    v_clean_name := btrim(regexp_replace(p_brand_name, '\s+', ' ', 'g'));
    v_len := char_length(v_clean_name);

    IF v_len < 3 THEN
      RAISE EXCEPTION 'Marka adı çok kısa. En az 3 karakterden oluşmalıdır.';
    END IF;
    IF v_len > 24 THEN
      RAISE EXCEPTION 'Marka adı çok uzun. En fazla 24 karakter olabilir.';
    END IF;
    IF v_clean_name !~* '^[a-z0-9çğışöüÇĞİŞÖÜ ]+$' THEN
      RAISE EXCEPTION 'Marka adında yalnızca harf, rakam ve boşluk kullanılabilir.';
    END IF;

    v_lower_name := lower(v_clean_name);
    IF v_lower_name IN (
      'admin', 'administrator', 'sistem', 'system', 'hard kapitalizm', 'kapitalizm',
      'merkez bankasi', 'merkez bankası', 'devlet', 'resmi', 'official', 'destek',
      'support', 'npc', 'toptan ticaret', 'belediye', 'bakanlik', 'bakanlık',
      'moderator', 'mod', 'türkiye', 'turkiye', 'hazine', 'maliye'
    ) OR v_lower_name LIKE 'admin%' OR v_lower_name LIKE 'sistem%' THEN
      RAISE EXCEPTION 'Bu marka adı rezerve edilmiştir.';
    END IF;

    IF EXISTS (
      SELECT 1 FROM public.brand_companies
      WHERE lower(btrim(brand_name)) = v_lower_name
        AND id <> v_company.id
        AND is_active = true
    ) THEN
      RAISE EXCEPTION '"%" marka adı daha önce başka bir holding tarafından tescil edilmiş.', v_clean_name;
    END IF;

    SELECT
      brand_name,
      extensions.similarity(lower(brand_name), v_lower_name) AS sim,
      extensions.levenshtein(lower(brand_name), v_lower_name) AS dist
    INTO v_similar_record
    FROM public.brand_companies
    WHERE is_active = true AND id <> v_company.id
      AND (
        extensions.similarity(lower(brand_name), v_lower_name) >= 0.72
        OR (char_length(brand_name) <= 5 AND extensions.levenshtein(lower(brand_name), v_lower_name) <= 1)
        OR (char_length(brand_name) > 5 AND extensions.levenshtein(lower(brand_name), v_lower_name) <= 2)
      )
    ORDER BY extensions.similarity(lower(brand_name), v_lower_name) DESC
    LIMIT 1;

    IF v_similar_record.brand_name IS NOT NULL THEN
      RAISE EXCEPTION 'Belirlediğiniz marka adı tescilli "%" markasına aşırı derecede benzemektedir.', v_similar_record.brand_name;
    END IF;
  END IF;

  UPDATE public.brand_companies
  SET logo_id = p_logo_id,
      theme_color = p_theme_color,
      brand_name = v_clean_name,
      updated_at = timezone('utc', now())
  WHERE id = v_company.id;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Marka bilgileri güncellendi.',
    'brand_name', v_clean_name,
    'logo_id', p_logo_id,
    'theme_color', p_theme_color
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.update_brand_company(text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_brand_company(text, text, text) TO service_role;

-- 4. RPC: get_player_brand_performance (Marka İstatistikleri ve En Çok Satanlar)
CREATE OR REPLACE FUNCTION public.get_player_brand_performance()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_player_id uuid := auth.uid();
  v_brand_id uuid;
  v_total_sold bigint := 0;
  v_total_revenue numeric := 0;
  v_total_profit numeric := 0;
  v_top_products jsonb := '[]'::jsonb;
BEGIN
  IF v_player_id IS NULL THEN
    RETURN jsonb_build_object('total_sold', 0, 'total_revenue', 0, 'total_profit', 0, 'top_products', '[]'::jsonb);
  END IF;

  SELECT id INTO v_brand_id
  FROM public.brand_companies
  WHERE player_id = v_player_id AND is_active = true
  LIMIT 1;

  IF v_brand_id IS NULL THEN
    RETURN jsonb_build_object('total_sold', 0, 'total_revenue', 0, 'total_profit', 0, 'top_products', '[]'::jsonb);
  END IF;

  SELECT
    coalesce(sum(sold_quantity), 0),
    coalesce(sum(revenue), 0),
    coalesce(sum(profit), 0)
  INTO v_total_sold, v_total_revenue, v_total_profit
  FROM public.store_daily_performance
  WHERE brand_id = v_brand_id;

  SELECT coalesce(jsonb_agg(sub), '[]'::jsonb)
  INTO v_top_products
  FROM (
    SELECT
      sdp.product_id,
      coalesce(p.urun_adi, sdp.product_name, sdp.product_id) AS product_name,
      sum(sdp.sold_quantity) AS sold_quantity,
      round(sum(sdp.revenue), 2) AS revenue,
      round(sum(sdp.profit), 2) AS profit
    FROM public.store_daily_performance sdp
    LEFT JOIN public.products p ON p.id = sdp.product_id
    WHERE sdp.brand_id = v_brand_id
    GROUP BY sdp.product_id, coalesce(p.urun_adi, sdp.product_name, sdp.product_id)
    ORDER BY sum(sdp.revenue) DESC
    LIMIT 5
  ) sub;

  RETURN jsonb_build_object(
    'total_sold', v_total_sold,
    'total_revenue', v_total_revenue,
    'total_profit', v_total_profit,
    'top_products', v_top_products
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_player_brand_performance() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_player_brand_performance() TO service_role;

-- 5. RPC: open_store_detail_page (Düzeltmeler)
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

      -- Marka seviyesi sorgusu (DÜZELTME: public.brand_companies tablosundan brand_level okunur)
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

        -- Marka XP ve Seviye Güncellemesi (DÜZELTME: Satış adedi markaya XP kazandırır)
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
          OR ws.product_id = ANY(regexp_split_to_array(st.accepted_product_ids, '\s*,\s*'))
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
GRANT EXECUTE ON FUNCTION public.open_store_detail_page(uuid) TO service_role;
