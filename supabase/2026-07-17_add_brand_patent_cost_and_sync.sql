-- Migration to define the patent_brand_company_product RPC function with a cash cost and synchronization logic.

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
  
  v_synced_output_inventory_count integer := 0;
  v_synced_slot_count integer := 0;
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
  WHERE id = v_player_id;

  IF v_cash < v_patent_cost THEN
    RAISE EXCEPTION 'Bu ürünü patentlemek için yeterli nakitiniz yok (Gerekli: 50.000 ₺).';
  END IF;

  -- 5. Deduct cash
  UPDATE public.players
  SET cash = cash - v_patent_cost
  WHERE id = v_player_id;

  -- 6. Insert patent entry
  INSERT INTO public.brand_company_products (brand_company_id, player_id, product_id)
  VALUES (v_company_id, v_player_id, p_product_id);

  -- 7. Sync brand on existing output inventories (factories, mines, tarlalar, vb.)
  UPDATE public.production_inventory
  SET brand_id = v_company_id
  WHERE owner_id IN (
    SELECT id FROM public.factories WHERE player_id = v_player_id
    UNION ALL
    SELECT id FROM public.mines WHERE player_id = v_player_id
    UNION ALL
    SELECT id FROM public.farms WHERE player_id = v_player_id
    UNION ALL
    SELECT id FROM public.fields WHERE player_id = v_player_id
  )
  AND product_id = p_product_id
  AND inventory_type = 'output';
  
  GET DIAGNOSTICS v_synced_output_inventory_count = ROW_COUNT;

  -- 8. Sync brand on warehouse slots
  UPDATE public.warehouse_slots
  SET brand_id = v_company_id
  WHERE warehouse_id IN (SELECT id FROM public.warehouses WHERE player_id = v_player_id)
    AND product_id = p_product_id;
    
  GET DIAGNOSTICS v_synced_slot_count = ROW_COUNT;

  -- 9. Sync brand on store slots
  UPDATE public.store_slots
  SET brand_id = v_company_id
  WHERE store_id IN (SELECT id FROM public.stores WHERE player_id = v_player_id)
    AND product_id = p_product_id;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Ürün başarıyla markanız altına patentlendi.',
    'synced_factory_count', v_synced_output_inventory_count,
    'synced_mine_count', 0,
    'synced_slot_count', v_synced_slot_count,
    'synced_output_inventory_count', v_synced_output_inventory_count,
    'merged_output_inventory_count', 0
  );
END;
$$;
