CREATE OR REPLACE FUNCTION public.sell_store(
  p_store_id uuid,
  p_confirm boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
declare
  v_player_id uuid := auth.uid();
  v_now timestamptz := timezone('utc', now());
  v_store public.stores%rowtype;
  v_store_type_cost numeric := 0;
  v_store_slots uuid[] := '{}'::uuid[];
  v_store_warehouse_ids uuid[] := '{}'::uuid[];
  v_store_warehouse_slot_ids uuid[] := '{}'::uuid[];
  v_store_construction_refund numeric := 0;
  v_store_warehouse_construction_refund numeric := 0;
  v_store_stock_refund numeric := 0;
  v_store_warehouse_stock_refund numeric := 0;
  v_stock_refund numeric := 0;
  v_construction_refund numeric := 0;
  v_total_refund numeric := 0;
begin
  if v_player_id is null then
    return jsonb_build_object(
      'success', false,
      'message', 'Oturum acilmamis.'
    );
  end if;

  select s.*
  into v_store
  from public.stores s
  where s.id = p_store_id
    and s.player_id = v_player_id
  for update of s;

  if not found then
    return jsonb_build_object(
      'success', false,
      'message', 'Magaza bulunamadi veya size ait degil.'
    );
  end if;

  select coalesce(st.cost, 0)
  into v_store_type_cost
  from public.store_types st
  where st.id = v_store.store_type_id;

  perform 1
  from public.warehouses w
  where w.store_id = p_store_id
    and w.warehouse_kind = 'store'
  for update;

  select coalesce(array_agg(ss.id), '{}'::uuid[])
  into v_store_slots
  from public.store_slots ss
  where ss.store_id = p_store_id;

  select coalesce(array_agg(w.id), '{}'::uuid[])
  into v_store_warehouse_ids
  from public.warehouses w
  where w.store_id = p_store_id
    and w.warehouse_kind = 'store';

  select coalesce(array_agg(ws.id), '{}'::uuid[])
  into v_store_warehouse_slot_ids
  from public.warehouse_slots ws
  where ws.warehouse_id = any(v_store_warehouse_ids);

  if exists (
    select 1
    from public.logistics_transfers lt
    where lt.status = 'in_transit'
      and (
        lt.buyer_store_id = p_store_id
        or lt.seller_store_id = p_store_id
        or lt.buyer_store_slot_id = any(v_store_slots)
        or lt.seller_store_slot_id = any(v_store_slots)
        or lt.buyer_warehouse_id = any(v_store_warehouse_ids)
        or lt.seller_warehouse_id = any(v_store_warehouse_ids)
        or lt.seller_warehouse_slot_id = any(v_store_warehouse_slot_ids)
      )
  ) then
    return jsonb_build_object(
      'success', false,
      'message', 'Magaza deposu veya magazaya bagli aktif transferler tamamlanmadan satis yapilamaz.'
    );
  end if;

  if exists (
    select 1
    from public.building_upgrades bu
    where bu.player_id = v_player_id
      and bu.status = 'in_progress'
      and (
        (bu.building_kind = 'store' and bu.entity_id = p_store_id)
        or (bu.building_kind = 'warehouse' and bu.entity_id = any(v_store_warehouse_ids))
      )
  ) then
    return jsonb_build_object(
      'success', false,
      'message', 'Magaza veya magaza deposu icin devam eden bir yukseltme var.'
    );
  end if;

  select coalesce(sum(ss.quantity * ss.cost), 0)
  into v_store_stock_refund
  from public.store_slots ss
  where ss.store_id = p_store_id;

  select coalesce(sum(coalesce((bu.params ->> 'upgrade_cost')::numeric, 0)), 0)
  into v_store_construction_refund
  from public.building_upgrades bu
  where bu.player_id = v_player_id
    and bu.building_kind = 'store'
    and bu.entity_id = p_store_id
    and bu.status = 'completed';

  v_store_construction_refund := v_store_type_cost + v_store_construction_refund;

  select coalesce(sum(ws.quantity * ws.cost), 0)
  into v_store_warehouse_stock_refund
  from public.warehouse_slots ws
  where ws.warehouse_id = any(v_store_warehouse_ids);

  select
    coalesce(sum(coalesce(wt.cost, 0)), 0)
    + coalesce(
        (
          select sum(coalesce((bu.params ->> 'upgrade_cost')::numeric, 0))
          from public.building_upgrades bu
          where bu.player_id = v_player_id
            and bu.building_kind = 'warehouse'
            and bu.entity_id = any(v_store_warehouse_ids)
            and bu.status = 'completed'
        ),
        0
      )
  into v_store_warehouse_construction_refund
  from public.warehouses w
  left join public.warehouse_types wt on wt.id = w.warehouse_type_id
  where w.store_id = p_store_id
    and w.warehouse_kind = 'store';

  v_stock_refund := v_store_stock_refund + v_store_warehouse_stock_refund;
  v_construction_refund :=
    v_store_construction_refund + v_store_warehouse_construction_refund;
  v_total_refund := v_construction_refund + v_stock_refund;

  if p_confirm = false then
    return jsonb_build_object(
      'success', true,
      'store_construction_refund', round(v_store_construction_refund, 2),
      'store_warehouse_construction_refund', round(v_store_warehouse_construction_refund, 2),
      'store_stock_refund', round(v_store_stock_refund, 2),
      'store_warehouse_stock_refund', round(v_store_warehouse_stock_refund, 2),
      'construction_refund', round(v_construction_refund, 2),
      'stock_refund', round(v_stock_refund, 2),
      'total_refund', round(v_total_refund, 2),
      'message', 'Magaza satis teklifi hazirlandi.'
    );
  end if;

  update public.warehouses
  set is_active = false,
      updated_at = v_now
  where id = any(v_store_warehouse_ids);

  update public.logistics_transfer_items
  set source_warehouse_slot_id = null,
      target_warehouse_slot_id = null,
      updated_at = v_now
  where source_warehouse_slot_id = any(v_store_warehouse_slot_ids)
     or target_warehouse_slot_id = any(v_store_warehouse_slot_ids);

  update public.logistics_finance_entries
  set related_warehouse_slot_id = null
  where related_warehouse_slot_id = any(v_store_warehouse_slot_ids);

  update public.logistics_transfers
  set buyer_store_id = case when buyer_store_id = p_store_id then null else buyer_store_id end,
      seller_store_id = case when seller_store_id = p_store_id then null else seller_store_id end,
      buyer_store_slot_id = case when buyer_store_slot_id = any(v_store_slots) then null else buyer_store_slot_id end,
      seller_store_slot_id = case when seller_store_slot_id = any(v_store_slots) then null else seller_store_slot_id end,
      buyer_warehouse_id = case when buyer_warehouse_id = any(v_store_warehouse_ids) then null else buyer_warehouse_id end,
      seller_warehouse_id = case when seller_warehouse_id = any(v_store_warehouse_ids) then null else seller_warehouse_id end,
      seller_warehouse_slot_id = case when seller_warehouse_slot_id = any(v_store_warehouse_slot_ids) then null else seller_warehouse_slot_id end,
      updated_at = v_now
  where buyer_store_id = p_store_id
     or seller_store_id = p_store_id
     or buyer_store_slot_id = any(v_store_slots)
     or seller_store_slot_id = any(v_store_slots)
     or buyer_warehouse_id = any(v_store_warehouse_ids)
     or seller_warehouse_id = any(v_store_warehouse_ids)
     or seller_warehouse_slot_id = any(v_store_warehouse_slot_ids);

  delete from public.store_daily_performance
  where store_id = p_store_id;

  delete from public.building_boosts
  where (building_kind = 'store' and entity_id = p_store_id)
     or (building_kind = 'warehouse' and entity_id = any(v_store_warehouse_ids));

  delete from public.building_upgrades
  where (building_kind = 'store' and entity_id = p_store_id)
     or (building_kind = 'warehouse' and entity_id = any(v_store_warehouse_ids));

  delete from public.warehouse_slots
  where warehouse_id = any(v_store_warehouse_ids);

  delete from public.store_slots
  where store_id = p_store_id;

  delete from public.warehouses
  where id = any(v_store_warehouse_ids);

  delete from public.stores
  where id = p_store_id
    and player_id = v_player_id;

  update public.players
  set cash = cash + v_total_refund
  where id = v_player_id;

  perform public.log_player_cash_change(
    v_player_id,
    v_total_refund,
    (select cash - v_total_refund from public.players where id = v_player_id),
    'store_sale',
    format(
      'Magaza satildi: %s | Magaza deposu dahil toplam iade %s TL',
      v_store.name,
      round(v_total_refund, 2)
    ),
    p_store_id,
    'store'
  );

  return jsonb_build_object(
    'success', true,
    'construction_refund', round(v_construction_refund, 2),
    'stock_refund', round(v_stock_refund, 2),
    'total_refund', round(v_total_refund, 2),
    'message', 'Magaza ve bagli magaza deposu satildi.'
  );
end;
$$;
