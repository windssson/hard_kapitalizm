CREATE OR REPLACE FUNCTION public.update_brand_company(
  p_logo_id text,
  p_theme_color text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_player_id uuid := auth.uid();
  v_company public.brand_companies%ROWTYPE;
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

  UPDATE public.brand_companies
  SET logo_id = p_logo_id,
      theme_color = p_theme_color,
      updated_at = timezone('utc', now())
  WHERE player_id = v_player_id
    AND is_active = true;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Marka tasarimi guncellendi.',
    'logo_id', p_logo_id,
    'theme_color', p_theme_color
  );
END;
$$;
