create or replace function public.sell_store(
  p_store_id uuid,
  p_confirm boolean default false
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_player_id uuid := auth.uid();
  v_store record;
  v_construction_refund numeric := 0;
  v_stock_refund numeric := 0;
  v_total_refund numeric := 0;
  v_active_transfer_count integer := 0;
begin
  if v_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  select
    s.id,
    s.player_id,
    s.name,
    coalesce(st.cost, 0)::numeric as store_cost
  into v_store
  from public.stores s
  join public.store_types st on st.id = s.store_type_id
  where s.id = p_store_id
    and s.player_id = v_player_id
  for update;

  if not found then
    raise exception 'Magaza bulunamadi veya size ait degil.';
  end if;

  select count(*)
  into v_active_transfer_count
  from public.logistics_transfers lt
  where lt.status = 'in_transit'
    and (
      lt.buyer_store_id = p_store_id
      or lt.seller_store_id = p_store_id
      or lt.buyer_store_slot_id in (
        select ss.id from public.store_slots ss where ss.store_id = p_store_id
      )
      or lt.seller_store_slot_id in (
        select ss.id from public.store_slots ss where ss.store_id = p_store_id
      )
    );

  if v_active_transfer_count > 0 then
    return jsonb_build_object(
      'success', false,
      'can_sell', false,
      'message', 'Bu magazaya bagli aktif transfer varken satis yapilamaz.',
      'active_transfer_count', v_active_transfer_count
    );
  end if;

  v_construction_refund := round(v_store.store_cost * 0.50, 2);

  select round(
    coalesce(sum(coalesce(ss.quantity, 0)::numeric * coalesce(ss.cost, 0)), 0)
    * 0.50,
    2
  )
  into v_stock_refund
  from public.store_slots ss
  where ss.store_id = p_store_id;

  v_total_refund := coalesce(v_construction_refund, 0) + coalesce(v_stock_refund, 0);

  if p_confirm is not true then
    return jsonb_build_object(
      'success', true,
      'can_sell', true,
      'store_id', p_store_id,
      'store_name', v_store.name,
      'construction_refund', v_construction_refund,
      'stock_refund', v_stock_refund,
      'total_refund', v_total_refund
    );
  end if;

  update public.players
  set cash = cash + v_total_refund
  where id = v_player_id;

  update public.logistics_transfers
  set buyer_store_id = case when buyer_store_id = p_store_id then null else buyer_store_id end,
      buyer_store_slot_id = case
        when buyer_store_slot_id in (
          select ss.id from public.store_slots ss where ss.store_id = p_store_id
        ) then null
        else buyer_store_slot_id
      end,
      seller_store_id = case when seller_store_id = p_store_id then null else seller_store_id end,
      seller_store_slot_id = case
        when seller_store_slot_id in (
          select ss.id from public.store_slots ss where ss.store_id = p_store_id
        ) then null
        else seller_store_slot_id
      end,
      updated_at = timezone('utc'::text, now())
  where status = 'completed'
    and (
      buyer_store_id = p_store_id
      or seller_store_id = p_store_id
      or buyer_store_slot_id in (
        select ss.id from public.store_slots ss where ss.store_id = p_store_id
      )
      or seller_store_slot_id in (
        select ss.id from public.store_slots ss where ss.store_id = p_store_id
      )
    );

  delete from public.building_boosts
  where building_kind = 'store'
    and entity_id = p_store_id;

  delete from public.building_upgrades
  where building_kind = 'store'
    and entity_id = p_store_id;

  delete from public.stores
  where id = p_store_id
    and player_id = v_player_id;

  return jsonb_build_object(
    'success', true,
    'can_sell', true,
    'store_id', p_store_id,
    'store_name', v_store.name,
    'construction_refund', v_construction_refund,
    'stock_refund', v_stock_refund,
    'total_refund', v_total_refund
  );
end;
$$;

grant execute on function public.sell_store(uuid, boolean)
to anon, authenticated, service_role;

