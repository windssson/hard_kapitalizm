-- Migration to retrieve logistics transfer items with product and brand details for a given transfer.

CREATE OR REPLACE FUNCTION public.get_logistics_transfer_items(p_transfer_id uuid)
RETURNS TABLE (
  id uuid,
  product_id text,
  product_name text,
  product_icon text,
  quality_level integer,
  brand_id uuid,
  brand_name text,
  quantity integer,
  total_price numeric
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    lti.id,
    lti.product_id,
    p.urun_adi as product_name,
    p.urun_iconu as product_icon,
    lti.quality_level,
    lti.brand_id,
    COALESCE(bc.brand_name, 'Standart') as brand_name,
    lti.quantity,
    lti.total_price
  FROM public.logistics_transfer_items lti
  JOIN public.products p ON p.id = lti.product_id
  LEFT JOIN public.brand_companies bc ON bc.id = lti.brand_id
  WHERE lti.transfer_id = p_transfer_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
