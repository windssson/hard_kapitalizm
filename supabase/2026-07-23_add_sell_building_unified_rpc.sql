CREATE OR REPLACE FUNCTION public.sell_building(
  p_building_id uuid,
  p_building_kind text,
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
  v_base_cost numeric := 0;
  v_upgrades_cost numeric := 0;
  v_stock_refund numeric := 0;
  v_total_refund numeric := 0;
  v_building_name text := '';
  v_warehouse_slot_ids uuid[] := '{}'::uuid[];
  v_production_inventory_ids uuid[] := '{}'::uuid[];
  v_warehouse public.warehouses%rowtype;
begin
  if v_player_id is null then
    return jsonb_build_object(
      'success', false,
      'message', 'Oturum acilmamis.'
    );
  end if;

  if p_building_kind = 'store' then
    return public.sell_store(p_building_id, p_confirm);
  end if;

  -- 1. Depo Satışı
  if p_building_kind = 'warehouse' then
    select w.*
    into v_warehouse
    from public.warehouses w
    where w.id = p_building_id
      and w.player_id = v_player_id
    for update of w;

    if not found then
      return jsonb_build_object(
        'success', false,
        'message', 'Depo bulunamadi veya size ait degil.'
      );
    end if;

    if v_warehouse.warehouse_kind = 'store' or v_warehouse.store_id is not null then
      return jsonb_build_object(
        'success', false,
        'message', 'Magaza depolari bagli oldugu magaza ile birlikte satilmalidir.'
      );
    end if;

    v_building_name := v_warehouse.name;

    select coalesce(array_agg(ws.id), '{}'::uuid[])
    into v_warehouse_slot_ids
    from public.warehouse_slots ws
    where ws.warehouse_id = p_building_id;

    if exists (
      select 1
      from public.logistics_transfers lt
      where lt.status = 'in_transit'
        and (
          lt.buyer_warehouse_id = p_building_id
          or lt.seller_warehouse_id = p_building_id
          or lt.seller_warehouse_slot_id = any(v_warehouse_slot_ids)
        )
    ) then
      return jsonb_build_object(
        'success', false,
        'message', 'Depoya bagli aktif transferler tamamlanmadan satis yapilamaz.'
      );
    end if;

    if exists (
      select 1
      from public.building_upgrades bu
      where bu.player_id = v_player_id
        and bu.status = 'in_progress'
        and bu.building_kind = 'warehouse'
        and bu.entity_id = p_building_id
    ) then
      return jsonb_build_object(
        'success', false,
        'message', 'Depo icin devam eden bir yukseltme var.'
      );
    end if;

    select coalesce(wt.cost, 0)
    into v_base_cost
    from public.warehouse_types wt
    where wt.id = v_warehouse.warehouse_type_id;

    select coalesce(sum(coalesce((bu.params ->> 'upgrade_cost')::numeric, 0)), 0)
    into v_upgrades_cost
    from public.building_upgrades bu
    where bu.player_id = v_player_id
      and bu.building_kind = 'warehouse'
      and bu.entity_id = p_building_id
      and bu.status = 'completed';

    select coalesce(sum(ws.quantity * ws.cost), 0)
    into v_stock_refund
    from public.warehouse_slots ws
    where ws.warehouse_id = p_building_id;

    v_total_refund := v_base_cost + v_upgrades_cost + v_stock_refund;

    if p_confirm = false then
      return jsonb_build_object(
        'success', true,
        'construction_refund', round(v_base_cost + v_upgrades_cost, 2),
        'stock_refund', round(v_stock_refund, 2),
        'total_refund', round(v_total_refund, 2),
        'message', 'Depo satis teklifi hazirlandi.'
      );
    end if;

    -- İlişkileri temizle ve sil
    update public.logistics_transfer_items
    set source_warehouse_slot_id = null,
        target_warehouse_slot_id = null,
        updated_at = v_now
    where source_warehouse_slot_id = any(v_warehouse_slot_ids)
       or target_warehouse_slot_id = any(v_warehouse_slot_ids);

    update public.logistics_finance_entries
    set related_warehouse_slot_id = null
    where related_warehouse_slot_id = any(v_warehouse_slot_ids);

    update public.logistics_transfers
    set buyer_warehouse_id = case when buyer_warehouse_id = p_building_id then null else buyer_warehouse_id end,
        seller_warehouse_id = case when seller_warehouse_id = p_building_id then null else seller_warehouse_id end,
        seller_warehouse_slot_id = case when seller_warehouse_slot_id = any(v_warehouse_slot_ids) then null else seller_warehouse_slot_id end,
        updated_at = v_now
    where buyer_warehouse_id = p_building_id
       or seller_warehouse_id = p_building_id
       or seller_warehouse_slot_id = any(v_warehouse_slot_ids);

    delete from public.building_boosts
    where building_kind = 'warehouse' and entity_id = p_building_id;

    delete from public.building_upgrades
    where building_kind = 'warehouse' and entity_id = p_building_id;

    delete from public.warehouse_slots
    where warehouse_id = p_building_id;

    delete from public.warehouses
    where id = p_building_id;

  -- 2. Fabrika, Tarla, Çiftlik veya Maden Satışı
  elsif p_building_kind in ('factory', 'field', 'farm', 'mine') then
    if p_building_kind = 'factory' then
      select f.name, coalesce(ft.cost, 0)
      into v_building_name, v_base_cost
      from public.factories f
      join public.factory_types ft on ft.id = f.factory_type_id
      where f.id = p_building_id and f.player_id = v_player_id;
    elsif p_building_kind = 'field' then
      select f.name, coalesce(ft.cost, 0)
      into v_building_name, v_base_cost
      from public.fields f
      join public.field_types ft on ft.id = f.field_type_id
      where f.id = p_building_id and f.player_id = v_player_id;
    elsif p_building_kind = 'farm' then
      select f.name, coalesce(ft.cost, 0)
      into v_building_name, v_base_cost
      from public.farms f
      join public.farm_types ft on ft.id = f.farm_type_id
      where f.id = p_building_id and f.player_id = v_player_id;
    elsif p_building_kind = 'mine' then
      select m.name, coalesce(mt.cost, 0)
      into v_building_name, v_base_cost
      from public.mines m
      join public.mine_types mt on mt.id = m.mine_type_id
      where m.id = p_building_id and m.player_id = v_player_id;
    end if;

    if v_building_name is null or v_building_name = '' then
      return jsonb_build_object(
        'success', false,
        'message', 'Uretim birimi bulunamadi veya size ait degil.'
      );
    end if;

    select coalesce(array_agg(pi.id), '{}'::uuid[])
    into v_production_inventory_ids
    from public.production_inventory pi
    where pi.owner_id = p_building_id
      and pi.owner_kind = p_building_kind;

    if exists (
      select 1
      from public.logistics_transfers lt
      where lt.status = 'in_transit'
        and (
          lt.seller_production_inventory_id = any(v_production_inventory_ids)
          or lt.buyer_production_inventory_id = any(v_production_inventory_ids)
        )
    ) then
      return jsonb_build_object(
        'success', false,
        'message', 'Uretim birimine bagli aktif transferler tamamlanmadan satis yapilamaz.'
      );
    end if;

    if exists (
      select 1
      from public.building_upgrades bu
      where bu.player_id = v_player_id
        and bu.status = 'in_progress'
        and bu.building_kind = p_building_kind
        and bu.entity_id = p_building_id
    ) then
      return jsonb_build_object(
        'success', false,
        'message', 'Uretim birimi icin devam eden bir yukseltme var.'
      );
    end if;

    -- Check active production
    if p_building_kind in ('farm', 'field') and exists (
      select 1
      from public.production_slots ps
      where ps.owner_id = p_building_id
        and ps.owner_kind = p_building_kind
        and ps.is_active = true
        and ps.product_id is not null
    ) then
      return jsonb_build_object(
        'success', false,
        'message', 'Uretim biriminde aktif uretim devam ediyor.'
      );
    elsif p_building_kind = 'factory' and exists (
      select 1
      from public.factories f
      where f.id = p_building_id
        and f.is_active = true
        and f.product_id is not null
    ) then
      return jsonb_build_object(
        'success', false,
        'message', 'Fabrikada aktif uretim devam ediyor.'
      );
    elsif p_building_kind = 'mine' and exists (
      select 1
      from public.mines m
      where m.id = p_building_id
        and m.is_active = true
        and m.product_id is not null
    ) then
      return jsonb_build_object(
        'success', false,
        'message', 'Madende aktif uretim devam ediyor.'
      );
    end if;

    select coalesce(sum(coalesce((bu.params ->> 'upgrade_cost')::numeric, 0)), 0)
    into v_upgrades_cost
    from public.building_upgrades bu
    where bu.player_id = v_player_id
      and bu.building_kind = p_building_kind
      and bu.entity_id = p_building_id
      and bu.status = 'completed';

    select coalesce(sum(pi.quantity * pi.cost), 0)
    into v_stock_refund
    from public.production_inventory pi
    where pi.owner_id = p_building_id
      and pi.owner_kind = p_building_kind;

    v_total_refund := v_base_cost + v_upgrades_cost + v_stock_refund;

    if p_confirm = false then
      return jsonb_build_object(
        'success', true,
        'construction_refund', round(v_base_cost + v_upgrades_cost, 2),
        'stock_refund', round(v_stock_refund, 2),
        'total_refund', round(v_total_refund, 2),
        'message', 'Uretim birimi satis teklifi hazirlandi.'
      );
    end if;

    -- İlişkileri temizle ve sil
    update public.logistics_transfer_items
    set target_production_inventory_id = null,
        updated_at = v_now
    where target_production_inventory_id = any(v_production_inventory_ids);

    update public.logistics_transfers
    set seller_production_inventory_id = case when seller_production_inventory_id = any(v_production_inventory_ids) then null else seller_production_inventory_id end,
        buyer_production_inventory_id = case when buyer_production_inventory_id = any(v_production_inventory_ids) then null else buyer_production_inventory_id end,
        updated_at = v_now
    where seller_production_inventory_id = any(v_production_inventory_ids)
       or buyer_production_inventory_id = any(v_production_inventory_ids);

    delete from public.production_inventory
    where owner_id = p_building_id and owner_kind = p_building_kind;

    delete from public.production_slots
    where owner_id = p_building_id and owner_kind = p_building_kind;

    delete from public.building_boosts
    where building_kind = p_building_kind and entity_id = p_building_id;

    delete from public.building_upgrades
    where building_kind = p_building_kind and entity_id = p_building_id;

    if p_building_kind = 'factory' then
      delete from public.factories where id = p_building_id;
    elsif p_building_kind = 'field' then
      delete from public.fields where id = p_building_id;
    elsif p_building_kind = 'farm' then
      delete from public.farms where id = p_building_id;
    elsif p_building_kind = 'mine' then
      delete from public.mines where id = p_building_id;
    end if;

  else
    return jsonb_build_object(
      'success', false,
      'message', 'Gecersiz bina turu.'
    );
  end if;

  -- Para iadesini oyuncuya aktar
  update public.players
  set cash = cash + v_total_refund
  where id = v_player_id;

  perform public.log_player_cash_change(
    v_player_id,
    v_total_refund,
    (select cash - v_total_refund from public.players where id = v_player_id),
    p_building_kind || '_sale',
    format(
      '%s satildi: %s | Toplam iade %s TL',
      p_building_kind,
      v_building_name,
      round(v_total_refund, 2)
    ),
    p_building_id,
    p_building_kind
  );

  return jsonb_build_object(
    'success', true,
    'construction_refund', round(v_base_cost + v_upgrades_cost, 2),
    'stock_refund', round(v_stock_refund, 2),
    'total_refund', round(v_total_refund, 2),
    'message', format('%s satildi.', v_building_name)
  );
end;
$$;
