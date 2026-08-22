-- Migration: 2026-08-22_add_trigger_tutorial_first_sale_rpc.sql
-- Description: Adds trigger_tutorial_first_sale RPC for new player tutorial onboarding

CREATE OR REPLACE FUNCTION public.trigger_tutorial_first_sale(p_store_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
declare
  v_player_id uuid := auth.uid();
  v_store stores%rowtype;
begin
  if v_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  select *
  into v_store
  from public.stores
  where id = p_store_id
    and player_id = v_player_id;

  if not found then
    return jsonb_build_object(
      'success', false,
      'message', 'Magaza bulunamadi veya oyuncuya ait degil.'
    );
  end if;

  -- Rehberdeki manav raflarının son satış zamanını 15 dakika geriye çek
  -- Böylece open_store_detail_page'deki 10 dakika kontrolü geçer ve anında ilk satış hesaplanır.
  update public.store_slots
  set last_sale_processed_at = timezone('utc'::text, now()) - interval '15 minutes'
  where store_id = p_store_id
    and is_active = true
    and product_id is not null
    and coalesce(price, 0) > 0
    and coalesce(quantity, 0) > 0;

  -- Standart open_store_detail_page fonksiyonunu çağırıp satış sonucunu dön
  return public.open_store_detail_page(p_store_id);
end;
$$;

GRANT EXECUTE ON FUNCTION public.trigger_tutorial_first_sale(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.trigger_tutorial_first_sale(uuid) TO service_role;
