-- ============================================================================
-- Cleanup: Genel Depo ve Consolidated Transfer modeline geçiş sonrası atıl kalan
-- start_multi_logistics_transfer fonksiyonunu veritabanından kaldırma.
-- ============================================================================

DROP FUNCTION IF EXISTS public.start_multi_logistics_transfer(
  text,
  uuid,
  text,
  uuid,
  jsonb,
  uuid
);
