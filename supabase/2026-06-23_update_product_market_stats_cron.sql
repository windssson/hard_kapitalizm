-- Function to update satici_sayisi and piyasadaki_stok for all products based on active warehouse slots
CREATE OR REPLACE FUNCTION public.update_product_market_stats()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  WITH stats AS (
    SELECT 
      ws.product_id,
      COUNT(DISTINCT w.player_id) AS satici_sayisi,
      SUM(ws.quantity) AS piyasadaki_stok
    FROM public.warehouse_slots ws
    JOIN public.warehouses w ON w.id = ws.warehouse_id
    WHERE ws.is_available_for_sale = true
      AND ws.quantity > 0
      AND w.is_active = true
    GROUP BY ws.product_id
  )
  UPDATE public.products p
  SET 
    satici_sayisi = COALESCE(s.satici_sayisi, 0),
    piyasadaki_stok = COALESCE(s.piyasadaki_stok, 0)
  FROM public.products p2
  LEFT JOIN stats s ON s.product_id = p2.id
  WHERE p.id = p2.id;
END;
$function$;

-- Unschedule the job if it already exists to avoid duplicates
SELECT cron.unschedule(jobid) 
FROM cron.job 
WHERE jobname = 'update_product_market_stats_every_4_hours';

-- Schedule the job to run every 4 hours (on the hour)
SELECT cron.schedule(
  'update_product_market_stats_every_4_hours',
  '0 */4 * * *',
  'SELECT public.update_product_market_stats();'
);
