-- ============================================================================
-- MIGRATION: 2026-09-04_create_update_company_name_rpc.sql
-- Amaç: Profil sayfasında holding adının güvenle değiştirilmesini sağlayan
--       update_company_name RPC fonksiyonunun oluşturulması.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.update_company_name(p_company_name text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $function$
DECLARE
  v_player public.players%rowtype;
  v_clean_name text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Oturum acilmamis.';
  END IF;

  v_clean_name := trim(p_company_name);
  IF v_clean_name IS NULL OR length(v_clean_name) < 2 THEN
    RAISE EXCEPTION 'Holding adı en az 2 karakter olmalıdır.';
  END IF;

  IF length(v_clean_name) > 30 THEN
    v_clean_name := substring(v_clean_name, 1, 30);
  END IF;

  UPDATE public.players
  SET company_name = v_clean_name
  WHERE id = auth.uid()
  RETURNING * INTO v_player;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Oyuncu kaydi bulunamadi.';
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Holding adı güncellendi.',
    'company_name', v_clean_name,
    'player', to_jsonb(v_player)
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.update_company_name(text) TO authenticated, anon;
