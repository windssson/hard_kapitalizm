-- ============================================================================
-- Migration: 2026-09-06_fix_brand_similarity_extensions.sql
-- Description:
-- Fix 'function similarity(text, text) does not exist' in create_brand_company
-- and update_brand_company by adding 'extensions' to search_path and qualifying
-- extensions.similarity and extensions.levenshtein.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.create_brand_company(
  p_brand_name text,
  p_logo_id text DEFAULT NULL,
  p_theme_color text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_player_id uuid := auth.uid();
  v_brand_company public.brand_companies%rowtype;
  v_clean_name text;
  v_lower_name text;
  v_similar_record record;
  v_len integer;
BEGIN
  IF v_player_id IS NULL THEN
    RAISE EXCEPTION 'Oturum açılmamış.';
  END IF;

  -- 1. Check if player already has a brand company
  SELECT *
  INTO v_brand_company
  FROM public.brand_companies
  WHERE player_id = v_player_id
  LIMIT 1;

  IF FOUND THEN
    RAISE EXCEPTION 'Zaten aktif bir marka şirketiniz bulunmaktadır.';
  END IF;

  -- 2. Clean & normalize name (strip double spaces, trim)
  v_clean_name := btrim(regexp_replace(COALESCE(p_brand_name, ''), '\s+', ' ', 'g'));
  v_len := char_length(v_clean_name);

  -- 3. Length validation
  IF v_len < 3 THEN
    RAISE EXCEPTION 'Marka adı çok kısa. En az 3 karakterden oluşmalıdır.';
  END IF;

  IF v_len > 24 THEN
    RAISE EXCEPTION 'Marka adı çok uzun. En fazla 24 karakter olabilir.';
  END IF;

  -- 4. Character set validation (Only Turkish/Latin letters, digits and spaces)
  IF v_clean_name !~* '^[a-z0-9çğışöüÇĞİŞÖÜ ]+$' THEN
    RAISE EXCEPTION 'Marka adında yalnızca harf, rakam ve boşluk kullanılabilir. Özel semboller, noktalama işaretleri veya emojiler kullanılamaz.';
  END IF;

  v_lower_name := lower(v_clean_name);

  -- 5. Reserved / Official Names Check
  IF v_lower_name IN (
    'admin', 'administrator', 'sistem', 'system', 'hard kapitalizm', 'kapitalizm',
    'merkez bankasi', 'merkez bankası', 'devlet', 'resmi', 'official', 'destek',
    'support', 'npc', 'toptan ticaret', 'belediye', 'bakanlik', 'bakanlık',
    'moderator', 'mod', 'türkiye', 'turkiye', 'hazine', 'maliye'
  ) OR v_lower_name LIKE 'admin%' OR v_lower_name LIKE 'sistem%' THEN
    RAISE EXCEPTION 'Bu marka adı resmi kurumlar ve sistem için rezerve edilmiştir. Lütfen şirketiniz için özgün bir marka adı seçin.';
  END IF;

  -- 6. Exact duplicate check (case-insensitive)
  IF EXISTS (
    SELECT 1 FROM public.brand_companies
    WHERE lower(btrim(brand_name)) = v_lower_name
      AND is_active = true
  ) THEN
    RAISE EXCEPTION '"%" marka adı daha önce başka bir holding tarafından tescil edilmiş. Lütfen farklı ve benzersiz bir marka adı seçin.', v_clean_name;
  END IF;

  -- 7. Knock-off / Fuzzy similarity check against existing brands
  SELECT
    brand_name,
    extensions.similarity(lower(brand_name), v_lower_name) AS sim,
    extensions.levenshtein(lower(brand_name), v_lower_name) AS dist
  INTO v_similar_record
  FROM public.brand_companies
  WHERE is_active = true
    AND (
      extensions.similarity(lower(brand_name), v_lower_name) >= 0.72
      OR (char_length(brand_name) <= 5 AND extensions.levenshtein(lower(brand_name), v_lower_name) <= 1)
      OR (char_length(brand_name) > 5 AND extensions.levenshtein(lower(brand_name), v_lower_name) <= 2)
    )
  ORDER BY extensions.similarity(lower(brand_name), v_lower_name) DESC
  LIMIT 1;

  IF v_similar_record.brand_name IS NOT NULL THEN
    RAISE EXCEPTION 'Belirlediğiniz marka adı tescilli "%" markasına aşırı derecede benzemektedir. Marka taklitçiliğini ve haksız rekabeti önlemek adına lütfen daha özgün bir isim seçin.', v_similar_record.brand_name;
  END IF;

  -- 8. Insert new brand company
  INSERT INTO public.brand_companies (
    player_id,
    brand_name,
    is_active,
    logo_id,
    theme_color,
    brand_level,
    brand_xp
  ) VALUES (
    v_player_id,
    v_clean_name,
    true,
    COALESCE(p_logo_id, 'logo1.webp'),
    COALESCE(p_theme_color, '#E5C05C'),
    1,
    0
  )
  RETURNING * INTO v_brand_company;

  RETURN jsonb_build_object(
    'success', true,
    'message', format('"%s" marka şirketiniz başarıyla tescillendi ve koruma altına alındı.', v_brand_company.brand_name),
    'brand_company_id', v_brand_company.id,
    'brand_name', v_brand_company.brand_name,
    'changed', jsonb_build_object(
      'player', public.get_player_profile(v_player_id)
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_brand_company(text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_brand_company(text, text, text) TO service_role;

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
