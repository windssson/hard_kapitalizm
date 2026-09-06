-- ============================================================================
-- Migration: 2026-09-06_drop_obsolete_update_brand_company_overload.sql
-- Description:
-- Drop obsolete 2-argument overload of update_brand_company(text, text) to
-- resolve PostgREST 'Could not choose the best candidate function' ambiguity.
-- ============================================================================

DROP FUNCTION IF EXISTS public.update_brand_company(text, text);
