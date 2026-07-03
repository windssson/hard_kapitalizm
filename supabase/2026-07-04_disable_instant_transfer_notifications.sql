-- Disable notifications for instant (same-city) transfers.
-- Same-city transfers have distance_km = 0 and happen instantly, so they do not need notifications.

CREATE OR REPLACE FUNCTION public.handle_logistics_transfer_notification()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_product_name text;
begin
  -- Only create a notification if the transfer status is completed, was not completed before, and it is not an instant transfer (distance_km > 0)
  if new.status = 'completed' and coalesce(old.status, '') <> 'completed' and coalesce(new.distance_km, 0) > 0 then
    select urun_adi into v_product_name
    from public.products
    where id = new.product_id;

    perform public.create_player_notification(
      new.buyer_player_id,
      'event',
      'transfer_completed',
      'Transfer Tamamlandi',
      coalesce(v_product_name, 'Urun') || ' transferi hedefe ulasti.',
      coalesce(new.buyer_entity_kind, case when new.buyer_store_id is not null then 'store' else 'warehouse' end),
      coalesce(new.buyer_store_id, new.buyer_warehouse_id),
      'success',
      jsonb_build_object(
        'transfer_id', new.id,
        'transfer_type', new.transfer_type,
        'product_id', new.product_id,
        'quantity', new.quantity
      ),
      'transfer_completed:' || new.id::text
    );
  end if;
  return new;
end;
$function$;
