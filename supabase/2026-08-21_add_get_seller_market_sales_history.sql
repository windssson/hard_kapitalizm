-- Add RPC for getting sales history to other players
CREATE OR REPLACE FUNCTION public.get_seller_market_sales_history(p_limit integer DEFAULT 50)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_player_id uuid := auth.uid();
  v_sales jsonb := '[]'::jsonb;
  v_total_sales_count integer := 0;
  v_total_sold_quantity bigint := 0;
  v_total_revenue numeric := 0;
BEGIN
  IF v_player_id IS NULL THEN
    v_player_id := nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
  END IF;

  IF v_player_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Oturum acilmamis.');
  END IF;

  -- Calculate summary stats
  SELECT
    count(*)::integer,
    coalesce(sum(coalesce(lt.total_quantity, lt.quantity, 0)), 0)::bigint,
    coalesce(sum(coalesce(lt.total_price, 0)), 0)::numeric
  INTO
    v_total_sales_count,
    v_total_sold_quantity,
    v_total_revenue
  FROM public.logistics_transfers lt
  WHERE lt.seller_player_id = v_player_id
    AND lt.buyer_player_id IS NOT NULL
    AND lt.buyer_player_id <> v_player_id
    AND lt.transfer_type IN ('market_to_warehouse_multi', 'market_transfer');

  -- Aggregate sales list with items and buyer details
  WITH transfer_items AS (
    SELECT
      lti.transfer_id,
      jsonb_agg(
        jsonb_build_object(
          'id', lti.id,
          'product_id', lti.product_id,
          'product_name', coalesce(p.urun_adi, 'Urun'),
          'product_icon', coalesce(p.urun_iconu, 'default.webp'),
          'quantity', coalesce(lti.quantity, 0),
          'quality_level', coalesce(lti.quality_level, 1),
          'unit_price', coalesce(lti.unit_price, 0)::double precision,
          'total_price', coalesce(lti.total_price, 0)::double precision,
          'brand_id', lti.brand_id
        )
        ORDER BY lti.created_at ASC, lti.id ASC
      ) AS items
    FROM public.logistics_transfer_items lti
    JOIN public.products p ON p.id = lti.product_id
    GROUP BY lti.transfer_id
  )
  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', lt.id,
        'transfer_type', lt.transfer_type,
        'status', lt.status,
        'total_price', coalesce(lt.total_price, 0)::double precision,
        'total_quantity', coalesce(nullif(lt.total_quantity, 0), lt.quantity, 0),
        'item_count', greatest(coalesce(lt.item_count, 1), 1),
        'started_at', lt.started_at,
        'finish_at', lt.finish_at,
        'completed_at', coalesce(lt.completed_at, lt.finish_at, lt.started_at),
        'buyer_player_id', bp.id,
        'buyer_player_name', coalesce(bp.player_name, 'Oyuncu'),
        'buyer_company_name', coalesce(bp.company_name, 'Sirket'),
        'buyer_avatar_id', coalesce(bp.avatar_id, 'ae1.webp'),
        'seller_warehouse_name', coalesce(sw.name, 'Depo'),
        'seller_city_name', coalesce(swc.name, '-'),
        'buyer_city_name', coalesce(bwc.name, '-'),
        'items', coalesce(
          ti.items,
          case
            when lt.product_id is not null then
              jsonb_build_array(
                jsonb_build_object(
                  'id', lt.id,
                  'product_id', lt.product_id,
                  'product_name', coalesce(p_single.urun_adi, 'Urun'),
                  'product_icon', coalesce(p_single.urun_iconu, 'default.webp'),
                  'quantity', coalesce(lt.quantity, 0),
                  'quality_level', coalesce(lt.quality_level, 1),
                  'unit_price', coalesce(lt.unit_price, 0)::double precision,
                  'total_price', coalesce(lt.total_price, 0)::double precision,
                  'brand_id', lt.brand_id
                )
              )
            else '[]'::jsonb
          end
        )
      )
      ORDER BY coalesce(lt.completed_at, lt.started_at) DESC, lt.id DESC
    ),
    '[]'::jsonb
  )
  INTO v_sales
  FROM (
    SELECT *
    FROM public.logistics_transfers
    WHERE seller_player_id = v_player_id
      AND buyer_player_id IS NOT NULL
      AND buyer_player_id <> v_player_id
      AND transfer_type IN ('market_to_warehouse_multi', 'market_transfer')
    ORDER BY coalesce(completed_at, started_at) DESC, id DESC
    LIMIT p_limit
  ) lt
  LEFT JOIN public.players bp ON bp.id = lt.buyer_player_id
  LEFT JOIN public.warehouses sw ON sw.id = lt.seller_warehouse_id
  LEFT JOIN public.cities swc ON swc.id = sw.city_id
  LEFT JOIN public.warehouses bw ON bw.id = lt.buyer_warehouse_id
  LEFT JOIN public.cities bwc ON bwc.id = bw.city_id
  LEFT JOIN transfer_items ti ON ti.transfer_id = lt.id
  LEFT JOIN public.products p_single ON p_single.id = lt.product_id;

  RETURN jsonb_build_object(
    'success', true,
    'total_sales_count', v_total_sales_count,
    'total_sold_quantity', v_total_sold_quantity,
    'total_revenue', v_total_revenue,
    'sales', v_sales
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.get_seller_market_sales_history(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_seller_market_sales_history(integer) TO authenticated;
