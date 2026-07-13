-- 1. Products tablosuna kategori sütunu ekle
ALTER TABLE products ADD COLUMN IF NOT EXISTS kategori text;

-- 2. Ürünleri farm_types, field_types, mine_types ve factory_types tablosundaki tesis tiplerine göre otomatik gruplandır
DO $$
DECLARE
    r RECORD;
    p_id text;
    p_array text[];
BEGIN
    -- Farm_types (Tarlalar)
    FOR r IN SELECT name, accepted_product_ids FROM public.farm_types WHERE accepted_product_ids IS NOT NULL LOOP
        p_array := string_to_array(replace(r.accepted_product_ids, ' ', ''), ',');
        FOREACH p_id IN ARRAY p_array LOOP
            UPDATE public.products SET kategori = r.name WHERE id = p_id;
        END LOOP;
    END LOOP;

    -- Field_types (Çiftlikler)
    FOR r IN SELECT name, accepted_product_ids FROM public.field_types WHERE accepted_product_ids IS NOT NULL LOOP
        p_array := string_to_array(replace(r.accepted_product_ids, ' ', ''), ',');
        FOREACH p_id IN ARRAY p_array LOOP
            UPDATE public.products SET kategori = r.name WHERE id = p_id;
        END LOOP;
    END LOOP;

    -- Mine_types (Madenler)
    FOR r IN SELECT name, accepted_product_ids FROM public.mine_types WHERE accepted_product_ids IS NOT NULL LOOP
        p_array := string_to_array(replace(r.accepted_product_ids, ' ', ''), ',');
        FOREACH p_id IN ARRAY p_array LOOP
            UPDATE public.products SET kategori = r.name WHERE id = p_id;
        END LOOP;
    END LOOP;

    -- Factory_types (Fabrikalar)
    FOR r IN SELECT name, accepted_product_ids FROM public.factory_types WHERE accepted_product_ids IS NOT NULL LOOP
        p_array := string_to_array(replace(r.accepted_product_ids, ' ', ''), ',');
        FOREACH p_id IN ARRAY p_array LOOP
            UPDATE public.products SET kategori = r.name WHERE id = p_id;
        END LOOP;
    END LOOP;

    -- Kategori atanmamış ürünler için varsayılan ata
    UPDATE public.products SET kategori = 'Diger' WHERE kategori IS NULL;
END $$;

-- 3. Cities tablosuna her tesis tipi için dinamik olarak bonus kolonu ekle
DO $$
DECLARE
    r RECORD;
    col_name text;
    safe_name text;
END DECLS; -- wait, DECLARE was closed correctly by DO $$
BEGIN
    -- Farm_types
    FOR r IN SELECT DISTINCT name FROM public.farm_types LOOP
        safe_name := translate(lower(r.name), 'çğıöşüİ', 'cgiosui');
        col_name := 'bonus_' || regexp_replace(safe_name, '[^a-z0-9]', '_', 'g');
        col_name := regexp_replace(col_name, '_+', '_', 'g');
        col_name := rtrim(ltrim(col_name, '_'), '_');
        
        EXECUTE 'ALTER TABLE public.cities ADD COLUMN IF NOT EXISTS ' || quote_ident(col_name) || ' numeric NOT NULL DEFAULT 1.0';
    END LOOP;

    -- Field_types
    FOR r IN SELECT DISTINCT name FROM public.field_types LOOP
        safe_name := translate(lower(r.name), 'çğıöşüİ', 'cgiosui');
        col_name := 'bonus_' || regexp_replace(safe_name, '[^a-z0-9]', '_', 'g');
        col_name := regexp_replace(col_name, '_+', '_', 'g');
        col_name := rtrim(ltrim(col_name, '_'), '_');
        
        EXECUTE 'ALTER TABLE public.cities ADD COLUMN IF NOT EXISTS ' || quote_ident(col_name) || ' numeric NOT NULL DEFAULT 1.0';
    END LOOP;

    -- Mine_types
    FOR r IN SELECT DISTINCT name FROM public.mine_types LOOP
        safe_name := translate(lower(r.name), 'çğıöşüİ', 'cgiosui');
        col_name := 'bonus_' || regexp_replace(safe_name, '[^a-z0-9]', '_', 'g');
        col_name := regexp_replace(col_name, '_+', '_', 'g');
        col_name := rtrim(ltrim(col_name, '_'), '_');
        
        EXECUTE 'ALTER TABLE public.cities ADD COLUMN IF NOT EXISTS ' || quote_ident(col_name) || ' numeric NOT NULL DEFAULT 1.0';
    END LOOP;

    -- Factory_types
    FOR r IN SELECT DISTINCT name FROM public.factory_types LOOP
        safe_name := translate(lower(r.name), 'çğıöşüİ', 'cgiosui');
        col_name := 'bonus_' || regexp_replace(safe_name, '[^a-z0-9]', '_', 'g');
        col_name := regexp_replace(col_name, '_+', '_', 'g');
        col_name := rtrim(ltrim(col_name, '_'), '_');
        
        EXECUTE 'ALTER TABLE public.cities ADD COLUMN IF NOT EXISTS ' || quote_ident(col_name) || ' numeric NOT NULL DEFAULT 1.0';
    END LOOP;
END $$;

-- 4. Şehir tiplerine göre başlangıç katsayılarını (bonusları) ayarla
DO $$
DECLARE
    r RECORD;
    col_name text;
    safe_name text;
BEGIN
    -- Adana, Şanlıurfa, Konya, Antalya: Tarım (Farm) katsayıları 1.25 olsun
    FOR r IN SELECT DISTINCT name FROM public.farm_types LOOP
        safe_name := translate(lower(r.name), 'çğıöşüİ', 'cgiosui');
        col_name := 'bonus_' || regexp_replace(safe_name, '[^a-z0-9]', '_', 'g');
        col_name := regexp_replace(col_name, '_+', '_', 'g');
        col_name := rtrim(ltrim(col_name, '_'), '_');
        
        EXECUTE 'UPDATE public.cities SET ' || quote_ident(col_name) || ' = 1.25 WHERE name IN (''Adana'', ''Sanliurfa'', ''Konya'', ''Antalya'')';
    END LOOP;

    -- Zonguldak, Sivas, Kütahya, Batman, Elazığ: Maden (Mine) katsayıları 1.30 olsun
    FOR r IN SELECT DISTINCT name FROM public.mine_types LOOP
        safe_name := translate(lower(r.name), 'çğıöşüİ', 'cgiosui');
        col_name := 'bonus_' || regexp_replace(safe_name, '[^a-z0-9]', '_', 'g');
        col_name := regexp_replace(col_name, '_+', '_', 'g');
        col_name := rtrim(ltrim(col_name, '_'), '_');
        
        EXECUTE 'UPDATE public.cities SET ' || quote_ident(col_name) || ' = 1.30 WHERE name IN (''Zonguldak'', ''Sivas'', ''Kutahya'', ''Batman'', ''Elazig'')';
    END LOOP;

    -- Kocaeli, Bursa, Manisa, Gaziantep: Sanayi (Factory) katsayıları 1.20 olsun
    FOR r IN SELECT DISTINCT name FROM public.factory_types LOOP
        safe_name := translate(lower(r.name), 'çğıöşüİ', 'cgiosui');
        col_name := 'bonus_' || regexp_replace(safe_name, '[^a-z0-9]', '_', 'g');
        col_name := regexp_replace(col_name, '_+', '_', 'g');
        col_name := rtrim(ltrim(col_name, '_'), '_');
        
        EXECUTE 'UPDATE public.cities SET ' || quote_ident(col_name) || ' = 1.20 WHERE name IN (''Kocaeli'', ''Bursa'', ''Manisa'', ''Gaziantep'')';
    END LOOP;
END $$;
