-- ============================================================================
-- MIGRATION: 2026-09-03_purge_obsolete_warehouse_types.sql
-- Amaç: Eski mağaza özel depo mimarisinden kalan 15 adet kullanılmayan depo türünü
-- temizlemek ve sistemde yalnızca tekil 'Genel Depo' türünü bırakmak.
-- ============================================================================

-- 1. store_types tablosundaki eski warehouse_type_id FK kısıtlamasını kaldır ve sütunu NULL yap
ALTER TABLE public.store_types DROP CONSTRAINT IF EXISTS store_types_warehouse_type_id_fkey;
UPDATE public.store_types SET warehouse_type_id = NULL;

-- 2. Eski mağaza tipi 15 adet depo türünü warehouse_types tablosundan sil
DELETE FROM public.warehouse_types WHERE id <> '604e422b-e260-468a-9c42-bff5360547d7';

-- 3. Kalan ana deponun adını 'Genel Depo' olarak standartlaştır
UPDATE public.warehouse_types
SET name = 'Genel Depo',
    icon = 'geneldepo.webp',
    accepted_production_units = 'TARLA,CIFTLIK,FABRIKA,MADEN,MAGAZA'
WHERE id = '604e422b-e260-468a-9c42-bff5360547d7';

-- 4. get_warehouse_types_catalog fonksiyonunu güncelle
CREATE OR REPLACE FUNCTION public.get_warehouse_types_catalog()
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT coalesce(
    jsonb_agg(to_jsonb(wt) ORDER BY wt.required_level, wt.cost),
    '[]'::jsonb
  )
  FROM public.warehouse_types wt;
$function$;
