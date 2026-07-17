-- Migration to define the get_player_active_products_data RPC function.
-- Aggregates all active products across stores, factories, farms, mines, fields, and inventories in a single JSONB payload.

CREATE OR REPLACE FUNCTION public.get_player_active_products_data(p_player_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_stores jsonb;
  v_factories jsonb;
  v_farms jsonb;
  v_mines jsonb;
  v_fields jsonb;
  v_inventories jsonb;
BEGIN
  -- Query active stores and their filled slots
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', s.id,
    'name', s.name,
    'store_slots', COALESCE(
      (
        SELECT jsonb_agg(jsonb_build_object(
          'product_id', ss.product_id,
          'quantity', ss.quantity,
          'products', jsonb_build_object(
            'urun_adi', p.urun_adi,
            'urun_iconu', p.urun_iconu
          )
        ))
        FROM public.store_slots ss
        JOIN public.products p ON p.id = ss.product_id
        WHERE ss.store_id = s.id AND ss.is_active = true AND ss.quantity > 0
      ),
      '[]'::jsonb
    )
  )), '[]'::jsonb)
  INTO v_stores
  FROM public.stores s
  WHERE s.player_id = p_player_id AND s.is_active = true;

  -- Query active factories
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', f.id,
    'name', f.name
  )), '[]'::jsonb)
  INTO v_factories
  FROM public.factories f
  WHERE f.player_id = p_player_id AND f.is_active = true;

  -- Query active farms
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', fm.id,
    'name', fm.name
  )), '[]'::jsonb)
  INTO v_farms
  FROM public.farms fm
  WHERE fm.player_id = p_player_id AND fm.is_active = true;

  -- Query active mines
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', m.id,
    'name', m.name
  )), '[]'::jsonb)
  INTO v_mines
  FROM public.mines m
  WHERE m.player_id = p_player_id AND m.is_active = true;

  -- Query active fields
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', fld.id,
    'name', fld.name
  )), '[]'::jsonb)
  INTO v_fields
  FROM public.fields fld
  WHERE fld.player_id = p_player_id AND fld.is_active = true;

  -- Query active inventories
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'owner_id', pi.owner_id,
    'product_id', pi.product_id,
    'quantity', pi.quantity,
    'inventory_type', pi.inventory_type,
    'products', jsonb_build_object(
      'urun_adi', pr.urun_adi,
      'urun_iconu', pr.urun_iconu
    )
  )), '[]'::jsonb)
  INTO v_inventories
  FROM public.production_inventory pi
  JOIN public.products pr ON pr.id = pi.product_id
  WHERE pi.owner_id IN (
    SELECT id FROM public.factories WHERE player_id = p_player_id AND is_active = true
    UNION ALL
    SELECT id FROM public.farms WHERE player_id = p_player_id AND is_active = true
    UNION ALL
    SELECT id FROM public.fields WHERE player_id = p_player_id AND is_active = true
    UNION ALL
    SELECT id FROM public.mines WHERE player_id = p_player_id AND is_active = true
  )
  AND pi.quantity > 0;

  RETURN jsonb_build_object(
    'stores', v_stores,
    'factories', v_factories,
    'farms', v_farms,
    'mines', v_mines,
    'fields', v_fields,
    'inventories', v_inventories
  );
END;
$$;
