-- Migration: add get_product_price_history RPC for market price sparkline
-- Date: 2026-07-19

CREATE OR REPLACE FUNCTION public.get_product_price_history(p_product_id text)
RETURNS jsonb
LANGUAGE sql
SECURITY INVOKER
SET search_path TO 'public'
AS $function$
  SELECT jsonb_build_object(
    'product_id', ph.product_id,
    'price_day_4', COALESCE(ph.price_day_4, 0),
    'price_day_3', COALESCE(ph.price_day_3, 0),
    'price_day_2', COALESCE(ph.price_day_2, 0),
    'price_day_1', COALESCE(ph.price_day_1, 0),
    'price_day_0', COALESCE(ph.price_day_0, 0),
    'updated_at', COALESCE(ph.updated_at, timezone('utc', now()))
  )
  FROM public.product_price_history ph
  WHERE ph.product_id = p_product_id
  LIMIT 1;
$function$;
