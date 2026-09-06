-- ============================================================================
-- MIGRATION: 2026-09-04_grant_anon_catalog_permissions.sql
-- Amaç: Giriş yapmamış (anon) kullanıcıların açılışta ve kayıt ekranında
--       şehir, ürün ve bina kataloglarını sorunsuz çekebilmesi için izin tanımları
-- ============================================================================

GRANT EXECUTE ON FUNCTION public.get_static_catalogs_bundle() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_active_cities() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_all_products_catalog() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_store_types_catalog() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_warehouse_types_catalog() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_factory_types_catalog() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_farm_types_catalog() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_field_types_catalog() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_mine_types_catalog() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_logistics_company_types_catalog() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_logistics_vehicle_types_catalog() TO anon, authenticated;
