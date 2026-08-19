-- Consolidated Static Catalogs Bundle RPC for ultra-fast single roundtrip load
CREATE OR REPLACE FUNCTION public.get_static_catalogs_bundle()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT jsonb_build_object(
    'cities', coalesce(public.get_active_cities(), '[]'::jsonb),
    'products', coalesce(public.get_all_products_catalog(), '[]'::jsonb),
    'store_types', coalesce(public.get_store_types_catalog(), '[]'::jsonb),
    'warehouse_types', coalesce(public.get_warehouse_types_catalog(), '[]'::jsonb),
    'factory_types', coalesce(public.get_factory_types_catalog(), '[]'::jsonb),
    'farm_types', coalesce(public.get_farm_types_catalog(), '[]'::jsonb),
    'field_types', coalesce(public.get_field_types_catalog(), '[]'::jsonb),
    'mine_types', coalesce(public.get_mine_types_catalog(), '[]'::jsonb),
    'logistics_company_types', coalesce(public.get_logistics_company_types_catalog(), '[]'::jsonb),
    'logistics_vehicle_types', coalesce(public.get_logistics_vehicle_types_catalog(), '[]'::jsonb)
  );
$function$;

REVOKE ALL ON FUNCTION public.get_static_catalogs_bundle() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_static_catalogs_bundle() TO anon, authenticated, service_role;
