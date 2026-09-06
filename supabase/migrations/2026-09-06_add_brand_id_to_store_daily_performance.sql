-- ============================================================================
-- Fix: store_daily_performance tablosuna brand_id sütunu eklenmesi
-- ============================================================================

ALTER TABLE public.store_daily_performance 
ADD COLUMN IF NOT EXISTS brand_id uuid DEFAULT '00000000-0000-0000-0000-000000000000'::uuid;

-- open_store_detail_page fonksiyonundaki insert bloğunda product_name, sale_event_count, last_sale_at alanlarını da güvene alalım
COMMENT ON COLUMN public.store_daily_performance.brand_id IS 'Satışın yapıldığı ürünün marka kimliği';
