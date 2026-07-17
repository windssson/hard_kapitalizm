-- Enforce raw material quality level x-1 before starting R&D upgrade to quality level x.

CREATE OR REPLACE FUNCTION public.start_arge_research(
  p_player_id uuid,
  p_product_id text
) RETURNS jsonb
LANGUAGE plpgsql
AS $function$
DECLARE
  v_arge_center record;
  v_active_count integer;
  v_already_researching integer;
  v_product record;
  v_current_quality integer;
  v_target_quality integer;
  v_required_rm_quality integer;
  v_rm_quality integer;
  v_rm_name text;
  v_player_level integer;
  v_player_cash numeric;
  v_required_player_level integer;
  v_multiplier integer;
  v_min_cost numeric;
  v_scaled_cost numeric;
  v_upgrade_cost numeric;
  v_base_hours integer;
  v_reduced_hours numeric;
  v_finish_at timestamp with time zone;
  v_research_id uuid;
BEGIN
  -- 1. Check if the player has an active ARGE center
  SELECT * INTO v_arge_center
  FROM public.arge_centers
  WHERE player_id = p_player_id AND is_active = true;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Aktif bir AR-GE merkeziniz bulunmuyor.'
    );
  END IF;

  -- 2. Check if the player has reached maximum concurrent researches
  SELECT COUNT(*) INTO v_active_count
  FROM public.arge_researches
  WHERE player_id = p_player_id AND status = 'in_progress';
  
  IF v_active_count >= v_arge_center.max_concurrent_researches THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Tüm araştırma slotlarınız dolu.'
    );
  END IF;

  -- 3. Check if the player is already researching this exact product
  SELECT COUNT(*) INTO v_already_researching
  FROM public.arge_researches
  WHERE player_id = p_player_id AND product_id = p_product_id AND status = 'in_progress';
  
  IF v_already_researching > 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Bu ürün için zaten aktif bir araştırma yürütülüyor.'
    );
  END IF;

  -- 4. Find the product details
  SELECT * INTO v_product FROM public.products WHERE id = p_product_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Ürün bulunamadı.'
    );
  END IF;

  -- 5. Get current quality level of the product for the player
  SELECT COALESCE(max_quality_level, 1) INTO v_current_quality
  FROM public.player_product_quality_levels
  WHERE player_id = p_player_id AND product_id = p_product_id;

  -- 6. Check if already at maximum quality level (level 5)
  IF v_current_quality >= 5 THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Bu ürün zaten maksimum kalite seviyesinde (Q5).'
    );
  END IF;
  
  v_target_quality := v_current_quality + 1;
  v_required_rm_quality := v_target_quality - 1;

  -- 7. Check raw material quality levels
  -- Check hammadde 1
  IF v_product.hammadde_1_id IS NOT NULL AND v_product.hammadde_1_id <> '' THEN
    SELECT COALESCE(max_quality_level, 1) INTO v_rm_quality
    FROM public.player_product_quality_levels
    WHERE player_id = p_player_id AND product_id = v_product.hammadde_1_id;
    
    IF v_rm_quality < v_required_rm_quality THEN
      SELECT urun_adi INTO v_rm_name FROM public.products WHERE id = v_product.hammadde_1_id;
      RETURN jsonb_build_object(
        'success', false,
        'message', 'Bu ürünü Q' || v_target_quality::text || ' seviyesine yükseltmek için hammaddesi ' || v_rm_name || ' en az Q' || v_required_rm_quality::text || ' seviyesinde olmalıdır.'
      );
    END IF;
  END IF;

  -- Check hammadde 2
  IF v_product.hammadde_2_id IS NOT NULL AND v_product.hammadde_2_id <> '' THEN
    SELECT COALESCE(max_quality_level, 1) INTO v_rm_quality
    FROM public.player_product_quality_levels
    WHERE player_id = p_player_id AND product_id = v_product.hammadde_2_id;
    
    IF v_rm_quality < v_required_rm_quality THEN
      SELECT urun_adi INTO v_rm_name FROM public.products WHERE id = v_product.hammadde_2_id;
      RETURN jsonb_build_object(
        'success', false,
        'message', 'Bu ürünü Q' || v_target_quality::text || ' seviyesine yükseltmek için hammaddesi ' || v_rm_name || ' en az Q' || v_required_rm_quality::text || ' seviyesinde olmalıdır.'
      );
    END IF;
  END IF;

  -- Check hammadde 3
  IF v_product.hammadde_3_id IS NOT NULL AND v_product.hammadde_3_id <> '' THEN
    SELECT COALESCE(max_quality_level, 1) INTO v_rm_quality
    FROM public.player_product_quality_levels
    WHERE player_id = p_player_id AND product_id = v_product.hammadde_3_id;
    
    IF v_rm_quality < v_required_rm_quality THEN
      SELECT urun_adi INTO v_rm_name FROM public.products WHERE id = v_product.hammadde_3_id;
      RETURN jsonb_build_object(
        'success', false,
        'message', 'Bu ürünü Q' || v_target_quality::text || ' seviyesine yükseltmek için hammaddesi ' || v_rm_name || ' en az Q' || v_required_rm_quality::text || ' seviyesinde olmalıdır.'
      );
    END IF;
  END IF;

  -- 8. Check player level requirement
  v_required_player_level := v_target_quality * 10;
  SELECT level, cash INTO v_player_level, v_player_cash FROM public.players WHERE id = p_player_id;
  
  IF v_player_level < v_required_player_level THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Gerekli oyuncu seviyesine (Lv. ' || v_required_player_level::text || ') sahip değilsiniz.'
    );
  END IF;

  -- 9. Calculate upgrade cost
  IF v_current_quality = 1 THEN
    v_multiplier := 10;
    v_min_cost := 2500;
  ELSIF v_current_quality = 2 THEN
    v_multiplier := 25;
    v_min_cost := 15000;
  ELSIF v_current_quality = 3 THEN
    v_multiplier := 60;
    v_min_cost := 75000;
  ELSIF v_current_quality = 4 THEN
    v_multiplier := 150;
    v_min_cost := 300000;
  ELSE
    v_multiplier := 0;
    v_min_cost := 0;
  END IF;
  
  v_scaled_cost := v_product.baz_satis_fiyati * v_multiplier;
  IF v_scaled_cost < v_min_cost THEN
    v_upgrade_cost := v_min_cost;
  ELSE
    v_upgrade_cost := v_scaled_cost;
  END IF;
  
  IF v_player_cash < v_upgrade_cost THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Araştırma başlatmak için yeterli paranız bulunmuyor.'
    );
  END IF;

  -- 10. Calculate duration
  IF v_current_quality = 1 THEN
    v_base_hours := 2;
  ELSIF v_current_quality = 2 THEN
    v_base_hours := 5;
  ELSIF v_current_quality = 3 THEN
    v_base_hours := 10;
  ELSIF v_current_quality = 4 THEN
    v_base_hours := 24;
  ELSE
    v_base_hours := 0;
  END IF;
  
  v_reduced_hours := v_base_hours * (1.0 - COALESCE(v_arge_center.duration_reduction_pct, 0) / 100.0);
  v_finish_at := now() + (v_reduced_hours * interval '1 hour');

  -- 11. Process deduction and insert research record
  UPDATE public.players SET cash = cash - v_upgrade_cost WHERE id = p_player_id;
  
  INSERT INTO public.arge_researches (
    player_id,
    product_id,
    product_name,
    current_quality,
    target_quality,
    cost_paid,
    status,
    started_at,
    finish_at
  ) VALUES (
    p_player_id,
    p_product_id,
    v_product.urun_adi,
    v_current_quality,
    v_target_quality,
    v_upgrade_cost,
    'in_progress',
    now(),
    v_finish_at
  ) RETURNING id INTO v_research_id;

  RETURN jsonb_build_object(
    'success', true,
    'message', v_product.urun_adi || ' için geliştirme başlatıldı.',
    'product_name', v_product.urun_adi,
    'research_id', v_research_id
  );
END;
$function$;
