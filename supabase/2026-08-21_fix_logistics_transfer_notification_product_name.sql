-- Fix column reference in handle_logistics_transfer_notification trigger
CREATE OR REPLACE FUNCTION public.handle_logistics_transfer_notification()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_product_name text;
begin
  if new.status = 'completed' and coalesce(old.status, '') <> 'completed' and coalesce(new.distance_km, 0) > 0 then
    if new.product_id is not null then
      select urun_adi into v_product_name
      from public.products
      where id = new.product_id;
    else
      select p.urun_adi into v_product_name
      from public.logistics_transfer_items lti
      join public.products p on p.id = lti.product_id
      where lti.transfer_id = new.id
      limit 1;
    end if;

    perform public.create_player_notification(
      new.buyer_player_id,
      'event',
      'transfer_completed',
      '🚚 Konvoy Depoya Yanaştı!',
      coalesce(v_product_name, 'Ürün') || ' sevkiyatı şehre ulaştı ve boşaltıldı. Ürünlerin hazır!',
      coalesce(new.buyer_entity_kind, case when new.buyer_store_id is not null then 'store' else 'warehouse' end),
      coalesce(new.buyer_store_id, new.buyer_warehouse_id),
      'success',
      jsonb_build_object(
        'transfer_id', new.id,
        'transfer_type', new.transfer_type,
        'product_id', new.product_id,
        'quantity', coalesce(new.total_quantity, new.quantity)
      ),
      'transfer_completed:' || new.id::text
    );
  end if;
  return new;
end;
$function$;
