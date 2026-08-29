-- ============================================================================
-- Migration: 2026-08-30_patch_system_completion_rpc_fixes.sql
-- Description: Patch sistemi için eksik olan tüm RPC response payload'larını tamamlar:
--              1. sell_store & sell_building -> changed: { player }
--              2. transfer_store_slot_to_store_warehouse -> target_warehouse_slot
--              3. complete_logistics_transfer_internal -> changed: { player }
--              4. start_multi_logistics_transfer -> changed: { player }
--              5. start_multi_warehouse_to_production_transfer -> changed: { player }
--              6. start_multi_production_to_warehouse_transfer -> changed: { player }
--              7. create_brand_company -> changed: { player }
--              8. patent_brand_company_product -> changed: { player }
--              9. start_marketing_campaign -> changed: { player }
--             10. start_arge_center_construction -> changed: { player }
--             11. start_arge_research -> changed: { player }
--             12. complete_arge_research -> changed: { player }
--             13. repair_all_logistics_vehicles -> changed: { player }
--             14. claim_daily_streak_reward -> changed: { player, dashboard_dirty }
-- ============================================================================

-- 1. sell_store
CREATE OR REPLACE FUNCTION public.sell_store(
  p_store_id uuid,
  p_confirm boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
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
    'message', 'Magaza ve bagli magaza deposu satildi.',
    'changed', jsonb_build_object(
      'player', public.get_player_profile(v_player_id)
    )
  );
end;
$$;

-- 2. sell_building
CREATE OR REPLACE FUNCTION public.sell_building(
  p_building_id uuid,
  p_building_kind text,
  p_confirm boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
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
    'message', format('%s satildi.', v_building_name),
    'changed', jsonb_build_object(
      'player', public.get_player_profile(v_player_id)
    )
  );
end;
$$;

-- 3. transfer_store_slot_to_store_warehouse (target_warehouse_slot eklemesi)
CREATE OR REPLACE FUNCTION public.transfer_store_slot_to_store_warehouse(
  p_player_id uuid,
  p_store_slot_id uuid,
  p_quantity integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
declare
  v_default_brand uuid := '00000000-0000-0000-0000-000000000000'::uuid;
  v_now timestamptz := timezone('utc'::text, now());
  v_store_slot record;
  v_store_warehouse record;
  v_target_slot record;
  v_empty_slot record;
  v_product record;
  v_required_capacity numeric := 0;
  v_used_capacity numeric := 0;
  v_next_slot_index integer := 1;
  v_target_slot_id uuid;
  v_target_quantity integer;
  v_target_cost numeric;
  v_target_slot_json jsonb;
begin
  if p_quantity is null or p_quantity <= 0 then
    raise exception 'Transfer miktari 0 dan buyuk olmalidir.';
  end if;

  select ss.*, s.player_id
  into v_store_slot
  from public.store_slots ss
  join public.stores s on s.id = ss.store_id
  where ss.id = p_store_slot_id
  for update;

  if not found then
    raise exception 'Magaza slotu bulunamadi.';
  end if;

  if v_store_slot.player_id <> p_player_id then
    raise exception 'Bu magaza slotu oyuncuya ait degil.';
  end if;

  if coalesce(v_store_slot.product_id, '') = '' then
    raise exception 'Magaza slotunda urun bulunamadi.';
  end if;

  if coalesce(v_store_slot.quality_level, 0) < 1 or coalesce(v_store_slot.quality_level, 0) > 5 then
    raise exception 'Magaza slotunun kalite seviyesi gecersiz.';
  end if;

  if coalesce(v_store_slot.quantity, 0) < p_quantity then
    raise exception 'Magaza slotunda yeterli stok yok.';
  end if;

  select *
  into v_store_warehouse
  from public.warehouses
  where store_id = v_store_slot.store_id
    and warehouse_kind = 'store'
    and is_active = true
  order by created_at desc
  limit 1
  for update;

  if not found then
    raise exception 'Magazaya bagli depo bulunamadi.';
  end if;

  select *
  into v_product
  from public.products
  where id = v_store_slot.product_id;

  if not found then
    raise exception 'Urun bulunamadi.';
  end if;

  v_required_capacity := p_quantity * coalesce(v_product.birim_hacim, 0);

  select coalesce(sum(ws.quantity * coalesce(p.birim_hacim, 0)), 0)
  into v_used_capacity
  from public.warehouse_slots ws
  left join public.products p on p.id = ws.product_id
  where ws.warehouse_id = v_store_warehouse.id;

  if v_used_capacity + v_required_capacity > coalesce(v_store_warehouse.capacity, 0) then
    raise exception 'Magaza deposunda yeterli kapasite yok.';
  end if;

  select *
  into v_target_slot
  from public.warehouse_slots
  where warehouse_id = v_store_warehouse.id
    and product_id = v_store_slot.product_id
    and quality_level = v_store_slot.quality_level
    and coalesce(brand_id, v_default_brand) = coalesce(v_store_slot.brand_id, v_default_brand)
  order by slot_index
  limit 1
  for update;

  if found then
    v_target_slot_id := v_target_slot.id;
    v_target_quantity := coalesce(v_target_slot.quantity, 0) + p_quantity;
    v_target_cost := case
      when v_target_quantity <= 0 then 0
      when coalesce(v_target_slot.quantity, 0) <= 0 then coalesce(v_store_slot.cost, 0)
      else round(((coalesce(v_target_slot.quantity, 0) * coalesce(v_target_slot.cost, 0)) + (p_quantity * coalesce(v_store_slot.cost, 0))) / v_target_quantity::numeric, 4)
    end;

    update public.warehouse_slots
    set
      quantity = v_target_quantity,
      cost = v_target_cost,
      updated_at = v_now
    where id = v_target_slot_id;
  else
    select *
    into v_empty_slot
    from public.warehouse_slots
    where warehouse_id = v_store_warehouse.id
      and product_id is null
      and quantity = 0
      and quality_level = 0
    order by slot_index
    limit 1
    for update;

    if found then
      v_target_slot_id := v_empty_slot.id;

      update public.warehouse_slots
      set
        product_id = v_store_slot.product_id,
        quality_level = v_store_slot.quality_level,
        brand_id = coalesce(v_store_slot.brand_id, v_default_brand),
        quantity = p_quantity,
        cost = coalesce(v_store_slot.cost, 0),
        updated_at = v_now
      where id = v_target_slot_id;
    else
      select coalesce(max(slot_index), 0) + 1
      into v_next_slot_index
      from public.warehouse_slots
      where warehouse_id = v_store_warehouse.id;

      insert into public.warehouse_slots (
        warehouse_id,
        slot_index,
        brand_id,
        product_id,
        quality_level,
        quantity,
        cost,
        is_available_for_sale,
        price,
        created_at,
        updated_at
      )
      values (
        v_store_warehouse.id,
        v_next_slot_index,
        coalesce(v_store_slot.brand_id, v_default_brand),
        v_store_slot.product_id,
        v_store_slot.quality_level,
        p_quantity,
        coalesce(v_store_slot.cost, 0),
        false,
        0,
        v_now,
        v_now
      )
      returning id into v_target_slot_id;
    end if;
  end if;

  update public.store_slots
  set
    quantity = quantity - p_quantity,
    updated_at = v_now
  where id = v_store_slot.id;

  select to_jsonb(ws.*)
  into v_target_slot_json
  from public.warehouse_slots ws
  where ws.id = v_target_slot_id;

  return jsonb_build_object(
    'success', true,
    'store_id', v_store_slot.store_id,
    'store_slot_id', v_store_slot.id,
    'warehouse_id', v_store_warehouse.id,
    'warehouse_slot_id', v_target_slot_id,
    'target_warehouse_slot', v_target_slot_json,
    'product_id', v_store_slot.product_id,
    'quality_level', v_store_slot.quality_level,
    'brand_id', coalesce(v_store_slot.brand_id, v_default_brand),
    'transferred_quantity', p_quantity,
    'remaining_store_slot_quantity', greatest(coalesce(v_store_slot.quantity, 0) - p_quantity, 0),
    'message', 'Stok magazadan magaza deposuna aktarildi.'
  );
end;
$$;

-- 4. complete_logistics_transfer_internal (changed: { player } eklemesi)
CREATE OR REPLACE FUNCTION public.complete_logistics_transfer_internal(
  p_transfer_id uuid,
  p_player_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_default_brand uuid := '00000000-0000-0000-0000-000000000000'::uuid;
  v_player_id uuid := p_player_id;
  v_now timestamptz := timezone('utc'::text, now());
  v_transfer logistics_transfers%rowtype;
  v_item logistics_transfer_items%rowtype;
  v_target_store_warehouse_id uuid;
  v_result jsonb;
  v_completed_count integer := 0;
  v_item_transport_cost numeric := 0;
  v_target_inventory record;
  v_total_existing_cost numeric := 0;
  v_total_incoming_cost numeric := 0;
  v_new_cost numeric := 0;
  v_transfer_exp integer := 0;
BEGIN
  if v_player_id is null then
    raise exception 'Oturum acilmamis.'; end if;

  select *
  into v_transfer
  from public.logistics_transfers
  where id = p_transfer_id
    and buyer_player_id = v_player_id
  for update;

  if not found then
    raise exception 'Transfer bulunamadi.';
  end if;

  if v_transfer.status = 'completed' then
    return jsonb_build_object(
      'success', true,
      'transfer_id', p_transfer_id,
      'completed_item_count', 0,
      'completed_at', coalesce(v_transfer.completed_at, v_now),
      'changed', jsonb_build_object(
        'player', public.get_player_profile(v_player_id)
      )
    );
  end if;

  if v_transfer.status <> 'in_transit' then
    raise exception 'Transfer tamamlanabilir durumda degil.';
  end if;

  if coalesce(v_transfer.finish_at, v_now) > v_now then
    raise exception 'Transfer henuz hedefe ulasmadi.';
  end if;

  if coalesce(v_transfer.buyer_entity_kind, '') = 'store' then
    select id
    into v_target_store_warehouse_id
    from public.warehouses
    where store_id = v_transfer.buyer_store_id
      and warehouse_kind = 'store'
      and is_active = true
    order by created_at desc
    limit 1
    for update;

    if not found then
      raise exception 'Hedef magazaya bagli depo bulunamadi.';
    end if;
  end if;

  for v_item in
    select *
    from public.logistics_transfer_items
    where transfer_id = p_transfer_id
      and status = 'in_transit'
    order by created_at, id
    for update
  loop
    v_item_transport_cost := case
      when coalesce(v_transfer.reserved_capacity_amount, 0) > 0
        and coalesce(v_item.reserved_capacity_amount, 0) > 0 then
        round(
          coalesce(v_transfer.transport_cost, 0)
          * (
            coalesce(v_item.reserved_capacity_amount, 0)
            / v_transfer.reserved_capacity_amount
          ),
          4
        )
      when coalesce(v_transfer.total_quantity, 0) > 0 then
        round(
          coalesce(v_transfer.transport_cost, 0)
          * (coalesce(v_item.quantity, 0)::numeric / v_transfer.total_quantity::numeric),
          4
        )
      else 0
    end;

    if coalesce(v_transfer.buyer_entity_kind, '') = 'warehouse' then
      v_result := public.add_product_to_warehouse_with_brand(
        v_player_id,
        v_transfer.buyer_warehouse_id,
        v_item.product_id,
        v_item.quality_level,
        coalesce(v_item.brand_id, v_default_brand),
        v_item.quantity,
        v_item.unit_cost,
        v_item_transport_cost,
        true,
        null
      );
    elsif coalesce(v_transfer.buyer_entity_kind, '') = 'store' then
      v_result := public.add_product_to_warehouse_with_brand(
        v_player_id,
        v_target_store_warehouse_id,
        v_item.product_id,
        v_item.quality_level,
        coalesce(v_item.brand_id, v_default_brand),
        v_item.quantity,
        v_item.unit_cost,
        v_item_transport_cost,
        false,
        v_item.target_warehouse_slot_id
      );
    elsif coalesce(v_transfer.buyer_entity_kind, '') = 'production_inventory' then
      select
        pi.*,
        case
          when pi.owner_kind = 'factory' then fx.player_id
          when pi.owner_kind = 'farm' then fa.player_id
          when pi.owner_kind = 'field' then fld.player_id
          when pi.owner_kind = 'mine' then m.player_id
          else null
        end as owner_player_id
      into v_target_inventory
      from public.production_inventory pi
      left join public.factories fx
        on pi.owner_kind = 'factory' and fx.id = pi.owner_id
      left join public.farms fa
        on pi.owner_kind = 'farm' and fa.id = pi.owner_id
      left join public.fields fld
        on pi.owner_kind = 'field' and fld.id = pi.owner_id
      left join public.mines m
        on pi.owner_kind = 'mine' and m.id = pi.owner_id
      where pi.id = coalesce(
        v_item.target_production_inventory_id,
        v_transfer.buyer_production_inventory_id
      )
      for update of pi;

      if not found then
        raise exception 'Hedef production envanteri bulunamadi.';
      end if;

      if v_target_inventory.owner_player_id <> v_player_id then
        raise exception 'Hedef production envanteri oyuncuya ait degil.';
      end if;

      if coalesce(v_target_inventory.product_id, '') <> coalesce(v_item.product_id, '') then
        raise exception 'Transfer urunu ile hedef production envanteri uyusmuyor.';
      end if;

      if coalesce(v_target_inventory.quality_level, 0) <> coalesce(v_item.quality_level, 0) then
        raise exception 'Transfer kalitesi ile hedef production envanteri uyusmuyor.';
      end if;

      if coalesce(v_target_inventory.inventory_type, '') <> 'input'
         and coalesce(v_target_inventory.brand_id, v_default_brand) <> coalesce(v_item.brand_id, v_default_brand) then
        raise exception 'Transfer brandi ile hedef production envanteri uyusmuyor.';
      end if;

      v_total_existing_cost := coalesce(v_target_inventory.quantity, 0) * coalesce(v_target_inventory.cost, 0);
      v_total_incoming_cost := (coalesce(v_item.quantity, 0) * coalesce(v_item.unit_cost, 0)) + coalesce(v_item_transport_cost, 0);
      v_new_cost := case
        when coalesce(v_target_inventory.quantity, 0) + coalesce(v_item.quantity, 0) <= 0 then coalesce(v_target_inventory.cost, 0)
        else round(
          (v_total_existing_cost + v_total_incoming_cost)
          / (coalesce(v_target_inventory.quantity, 0) + coalesce(v_item.quantity, 0)),
          4
        )
      end;

      update public.production_inventory
      set
        quantity = quantity + v_item.quantity,
        pending_quantity = greatest(coalesce(pending_quantity, 0) - v_item.quantity, 0),
        cost = v_new_cost
      where id = v_target_inventory.id;
    else
      raise exception 'Desteklenmeyen hedef turu: %', v_transfer.buyer_entity_kind;
    end if;

    update public.logistics_transfer_items
    set
      status = 'completed',
      completed_at = v_now,
      updated_at = v_now
    where id = v_item.id;

    v_completed_count := v_completed_count + 1;
  end loop;

  update public.logistics_transfers
  set
    status = 'completed',
    completed_at = v_now,
    updated_at = v_now
  where id = p_transfer_id;

  if v_transfer.logistics_vehicle_id is not null then
    update public.logistics_vehicles
    set
      status = 'idle',
      updated_at = v_now
    where id = v_transfer.logistics_vehicle_id;
  end if;

  -- Transfer Tamamlanma XP Ödülü
  v_transfer_exp := greatest(10, least(80, 10 + floor(coalesce(v_transfer.total_quantity, 0)::numeric / 10)::integer));
  perform public.grant_player_experience(
    v_player_id,
    v_transfer_exp,
    'logistics_transfer_completed',
    jsonb_build_object(
      'transfer_id', p_transfer_id,
      'total_quantity', v_transfer.total_quantity
    )
  );

  return jsonb_build_object(
    'success', true,
    'transfer_id', p_transfer_id,
    'completed_item_count', v_completed_count,
    'exp_gained', v_transfer_exp,
    'completed_at', v_now,
    'changed', jsonb_build_object(
      'player', public.get_player_profile(v_player_id)
    )
  );
END;
$$;

-- 5. start_multi_logistics_transfer (changed: { player } eklemesi)
CREATE OR REPLACE FUNCTION public.start_multi_logistics_transfer(
  p_source_entity_kind text,
  p_source_entity_id uuid,
  p_target_entity_kind text,
  p_target_entity_id uuid,
  p_items jsonb,
  p_vehicle_id uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
declare
  v_default_brand uuid := '00000000-0000-0000-0000-000000000000'::uuid;
  v_player_id uuid := auth.uid();
  v_npc_logistics_player_id uuid;
  v_now timestamptz := timezone('utc', now());
  v_source_warehouse record;
  v_target_warehouse record;
  v_source_store record;
  v_target_store record;
  v_vehicle public.logistics_vehicles%rowtype;
  v_transfer_id uuid;
  v_item jsonb;
  v_source_slot record;
  v_target_slot record;
  v_empty_slot record;
  v_product public.products%rowtype;
  v_item_count integer := 0;
  v_total_quantity integer := 0;
  v_total_volume numeric := 0;
  v_total_price numeric := 0;
  v_transport_cost numeric := 0;
  v_rental_cost numeric := 0;
  v_distance_km numeric := 0;
  v_fuel_used numeric := 0;
  v_condition_loss numeric := 0;
  v_duration_seconds integer := 0;
  v_finish_at timestamptz;
  v_same_city boolean := false;
  v_mode text := 'instant';
  v_is_rental boolean := false;
  v_item_quantity integer;
  v_item_reserved_capacity numeric;
  v_target_slot_id uuid;
  v_next_slot_index integer;
  v_store_used_capacity numeric;
  v_target_used_capacity numeric;
  v_header_product_id text;
  v_header_quality_level integer;
  v_header_brand_id uuid;
  v_player_cash numeric := 0;
begin
  if v_player_id is null then raise exception 'Oturum acilmamis.'; end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'Transfer kalemleri bos olamaz.';
  end if;

  if p_source_entity_kind not in ('warehouse', 'store') then
    raise exception 'Desteklenmeyen kaynak turu: %', p_source_entity_kind;
  end if;
  if p_target_entity_kind not in ('warehouse', 'store') then
    raise exception 'Desteklenmeyen hedef turu: %', p_target_entity_kind;
  end if;

  if p_source_entity_kind = 'warehouse' then
    select w.*, c.map_position_x, c.map_position_y
    into v_source_warehouse
    from public.warehouses w join public.cities c on c.id = w.city_id
    where w.id = p_source_entity_id and w.player_id = v_player_id for update;
    if not found then raise exception 'Kaynak depo bulunamadi.'; end if;
  else
    select * into v_source_store from public.stores where id = p_source_entity_id and player_id = v_player_id for update;
    if not found then raise exception 'Kaynak magaza bulunamadi.'; end if;
    select w.*, c.map_position_x, c.map_position_y
    into v_source_warehouse
    from public.warehouses w join public.cities c on c.id = w.city_id
    where w.store_id = v_source_store.id and w.warehouse_kind = 'store' and w.player_id = v_player_id and w.is_active = true
    order by w.created_at desc limit 1 for update;
    if not found then raise exception 'Kaynak magazaya bagli depo bulunamadi.'; end if;
  end if;

  if p_target_entity_kind = 'warehouse' then
    select w.*, c.map_position_x, c.map_position_y
    into v_target_warehouse
    from public.warehouses w join public.cities c on c.id = w.city_id
    where w.id = p_target_entity_id and w.player_id = v_player_id for update;
    if not found then raise exception 'Hedef depo bulunamadi.'; end if;
  else
    select * into v_target_store from public.stores where id = p_target_entity_id and player_id = v_player_id for update;
    if not found then raise exception 'Hedef magaza bulunamadi.'; end if;
    select w.*, c.map_position_x, c.map_position_y
    into v_target_warehouse
    from public.warehouses w join public.cities c on c.id = w.city_id
    where w.store_id = v_target_store.id and w.warehouse_kind = 'store' and w.player_id = v_player_id and w.is_active = true
    order by w.created_at desc limit 1 for update;
    if not found then raise exception 'Hedef magazaya bagli depo bulunamadi.'; end if;
  end if;

  if v_source_warehouse.id = v_target_warehouse.id then raise exception 'Kaynak ve hedef ayni depo olamaz.'; end if;

  v_item := p_items -> 0;
  if v_item is null then raise exception 'Transfer kalemleri bos olamaz.'; end if;

  select ws.product_id, ws.quality_level, coalesce(ws.brand_id, v_default_brand)
  into v_header_product_id, v_header_quality_level, v_header_brand_id
  from public.warehouse_slots ws join public.warehouses w on w.id = ws.warehouse_id
  where ws.id = (v_item ->> 'source_warehouse_slot_id')::uuid and w.id = v_source_warehouse.id;

  if coalesce(v_header_product_id, '') = '' then raise exception 'Ilk transfer kalemi icin kaynak slotu bulunamadi.'; end if;

  v_same_city := v_source_warehouse.city_id = v_target_warehouse.city_id;
  if v_same_city then
    v_mode := 'instant'; v_finish_at := v_now;
  else
    v_mode := 'in_transit';
    if p_vehicle_id is null then raise exception 'Sehirler arasi transfer icin arac secilmelidir.'; end if;
    v_npc_logistics_player_id := public.get_npc_logistics_player_id();
    select * into v_vehicle from public.logistics_vehicles
    where id = p_vehicle_id and status = 'idle'
      and (player_id = v_player_id or (coalesce(is_available_for_rent, false) = true and (player_id = v_npc_logistics_player_id or public.logistics_vehicle_matches_route(route_city_a_id, route_city_b_id, v_source_warehouse.city_id, v_target_warehouse.city_id))))
    for update;
    if not found then raise exception 'Secilen arac kullanima uygun degil.'; end if;
    v_is_rental := v_vehicle.player_id <> v_player_id;
    
    v_distance_km := round(
      (6371 * 2 * asin(sqrt(power(sin(radians(coalesce(v_target_warehouse.map_position_x, 0) - coalesce(v_source_warehouse.map_position_x, 0)) / 2), 2) + cos(radians(coalesce(v_source_warehouse.map_position_x, 0))) * cos(radians(coalesce(v_target_warehouse.map_position_x, 0))) * power(sin(radians(coalesce(v_target_warehouse.map_position_y, 0) - coalesce(v_source_warehouse.map_position_y, 0)) / 2), 2))))::numeric, 2
    );

    if coalesce(v_vehicle.speed_kmh, 0) <= 0 then raise exception 'Secilen aracin hizi gecersiz.'; end if;
    v_duration_seconds := greatest(60, ceil((greatest(v_distance_km, 1) / v_vehicle.speed_kmh) * 120)::integer);
    v_finish_at := v_now + make_interval(secs => v_duration_seconds);
  end if;

  insert into public.logistics_transfers (
    buyer_player_id, seller_player_id, buyer_warehouse_id, seller_warehouse_id, logistics_vehicle_id, vehicle_owner_player_id,
    is_rental, product_id, quality_level, quantity, unit_price, total_price, product_unit_volume, reserved_capacity_amount,
    distance_km, fuel_used, condition_loss, rental_cost, transport_cost, started_at, finish_at, status, buyer_store_id,
    transfer_type, seller_store_id, seller_entity_kind, buyer_entity_kind, item_count, total_quantity, brand_id, created_at, updated_at
  ) values (
    v_player_id, v_player_id,
    case when p_target_entity_kind = 'warehouse' then v_target_warehouse.id else null end,
    case when p_source_entity_kind = 'warehouse' then v_source_warehouse.id else null end,
    p_vehicle_id, case when p_vehicle_id is not null then v_vehicle.player_id else null end,
    v_is_rental, v_header_product_id, greatest(coalesce(v_header_quality_level, 1), 1), 1, 0, 0, 1, 0,
    v_distance_km, 0, 0, 0, 0, v_now, v_finish_at, 'in_transit',
    case when p_target_entity_kind = 'store' then p_target_entity_id else null end,
    case
      when p_source_entity_kind = 'warehouse' and p_target_entity_kind = 'warehouse' then 'warehouse_to_warehouse'
      when p_source_entity_kind = 'warehouse' and p_target_entity_kind = 'store' then 'warehouse_to_store'
      when p_source_entity_kind = 'store' and p_target_entity_kind = 'warehouse' then 'store_to_warehouse'
      else 'internal_transfer'
    end,
    case when p_source_entity_kind = 'store' then p_source_entity_id else null end,
    p_source_entity_kind, p_target_entity_kind, 1, 0, coalesce(v_header_brand_id, v_default_brand), v_now, v_now
  ) returning id into v_transfer_id;

  for v_item in select value from jsonb_array_elements(p_items) loop
    v_item_quantity := greatest(coalesce((v_item ->> 'quantity')::integer, 0), 0);
    if v_item_quantity <= 0 then raise exception 'Transfer miktari 0 dan buyuk olmalidir.'; end if;

    select ws.*, w.player_id, w.store_id, w.city_id, w.warehouse_kind
    into v_source_slot
    from public.warehouse_slots ws join public.warehouses w on w.id = ws.warehouse_id
    where ws.id = (v_item ->> 'source_warehouse_slot_id')::uuid for update;

    if not found then raise exception 'Kaynak depo slotu bulunamadi.'; end if;
    if v_source_slot.player_id <> v_player_id then raise exception 'Kaynak depo slotu oyuncuya ait degil.'; end if;
    if v_source_slot.warehouse_id <> v_source_warehouse.id then raise exception 'Tum kalemler secilen kaynak depoya ait olmalidir.'; end if;
    if coalesce(v_source_slot.product_id, '') = '' then raise exception 'Kaynak slotta urun bulunamadi.'; end if;
    if coalesce(v_source_slot.quantity, 0) < v_item_quantity then raise exception 'Kaynak slotta yeterli stok yok.'; end if;

    select * into v_product from public.products where id = v_source_slot.product_id;
    if not found then raise exception 'Urun bulunamadi.'; end if;

    v_item_reserved_capacity := v_item_quantity * coalesce(v_product.birim_hacim, 0);

    if p_target_entity_kind = 'warehouse' then
      select coalesce(sum((ws.quantity + coalesce(ws.pending_quantity, 0)) * coalesce(p.birim_hacim, 0)), 0)
      into v_target_used_capacity from public.warehouse_slots ws left join public.products p on p.id = ws.product_id where ws.warehouse_id = v_target_warehouse.id;
      if v_target_used_capacity + coalesce(v_target_warehouse.reserved_capacity, 0) + v_item_reserved_capacity > coalesce(v_target_warehouse.capacity, 0) then
        raise exception 'Hedef depoda yeterli rezerve kapasite yok.';
      end if;
      update public.warehouses set reserved_capacity = coalesce(reserved_capacity, 0) + v_item_reserved_capacity, updated_at = v_now where id = v_target_warehouse.id;
      v_target_slot_id := null;
      v_target_warehouse.reserved_capacity := coalesce(v_target_warehouse.reserved_capacity, 0) + v_item_reserved_capacity;
    else
      select coalesce(sum((ws.quantity + coalesce(ws.pending_quantity, 0)) * coalesce(p.birim_hacim, 0)), 0)
      into v_store_used_capacity from public.warehouse_slots ws left join public.products p on p.id = ws.product_id where ws.warehouse_id = v_target_warehouse.id;
      if v_store_used_capacity + v_item_reserved_capacity > coalesce(v_target_warehouse.capacity, 0) then
        raise exception 'Hedef magaza deposunda yeterli kapasite yok.';
      end if;

      select * into v_target_slot from public.warehouse_slots
      where warehouse_id = v_target_warehouse.id and product_id = v_source_slot.product_id and quality_level = v_source_slot.quality_level and coalesce(brand_id, v_default_brand) = coalesce(v_source_slot.brand_id, v_default_brand)
      order by slot_index limit 1 for update;

      if found then
        v_target_slot_id := v_target_slot.id;
        update public.warehouse_slots set pending_quantity = coalesce(pending_quantity, 0) + v_item_quantity, updated_at = v_now where id = v_target_slot_id;
      else
        select * into v_empty_slot from public.warehouse_slots where warehouse_id = v_target_warehouse.id and product_id is null and quantity = 0 and coalesce(pending_quantity, 0) = 0 and quality_level = 0 order by slot_index limit 1 for update;
        if found then
          v_target_slot_id := v_empty_slot.id;
          update public.warehouse_slots set product_id = v_source_slot.product_id, quality_level = v_source_slot.quality_level, brand_id = coalesce(v_source_slot.brand_id, v_default_brand), pending_quantity = v_item_quantity, cost = coalesce(v_source_slot.cost, 0), updated_at = v_now where id = v_target_slot_id;
        else
          select coalesce(max(slot_index), 0) + 1 into v_next_slot_index from public.warehouse_slots where warehouse_id = v_target_warehouse.id;
          insert into public.warehouse_slots (warehouse_id, slot_index, brand_id, product_id, quality_level, quantity, pending_quantity, cost, is_available_for_sale, created_at, updated_at, price)
          values (v_target_warehouse.id, v_next_slot_index, coalesce(v_source_slot.brand_id, v_default_brand), v_source_slot.product_id, v_source_slot.quality_level, 0, v_item_quantity, coalesce(v_source_slot.cost, 0), false, v_now, v_now, 0)
          returning id into v_target_slot_id;
        end if;
      end if;
    end if;

    insert into public.logistics_transfer_items (
      transfer_id, source_warehouse_slot_id, target_warehouse_slot_id, product_id, quality_level, brand_id, quantity, unit_cost, unit_price, total_cost, total_price, product_unit_volume, reserved_capacity_amount, status, created_at, updated_at
    ) values (
      v_transfer_id, v_source_slot.id, v_target_slot_id, v_source_slot.product_id, v_source_slot.quality_level, coalesce(v_source_slot.brand_id, v_default_brand), v_item_quantity, coalesce(v_source_slot.cost, 0), 0, v_item_quantity * coalesce(v_source_slot.cost, 0), 0, coalesce(v_product.birim_hacim, 0), v_item_reserved_capacity, 'in_transit', v_now, v_now
    );

    update public.warehouse_slots set quantity = quantity - v_item_quantity, updated_at = v_now where id = v_source_slot.id;
    if coalesce(v_source_slot.quantity, 0) - v_item_quantity <= 0 and coalesce(v_source_slot.pending_quantity, 0) <= 0 then
      delete from public.warehouse_slots where id = v_source_slot.id;
    end if;

    v_item_count := v_item_count + 1;
    v_total_quantity := v_total_quantity + v_item_quantity;
    v_total_volume := v_total_volume + v_item_reserved_capacity;
  end loop;

  if v_item_count <= 0 then raise exception 'Transfer icin gecerli kalem bulunamadi.'; end if;

  if not v_same_city then
    if v_is_rental and v_vehicle.player_id = v_npc_logistics_player_id then
      v_vehicle.capacity := greatest(coalesce(v_vehicle.capacity, 0), ceil(v_total_volume));
      update public.logistics_vehicles set capacity = v_vehicle.capacity where id = v_vehicle.id;
    end if;

    if coalesce(v_vehicle.capacity, 0) < ceil(v_total_volume) then raise exception 'Secilen aracin kapasitesi bu transfer icin yetersiz.'; end if;
    v_fuel_used := round(v_distance_km * coalesce(v_vehicle.fuel_rate, 0), 2);
    v_condition_loss := greatest(1, ceil(v_distance_km / 200.0));
    v_transport_cost := case when v_is_rental then round(v_distance_km * coalesce(v_vehicle.rental_price, 0), 2) else round(v_fuel_used * coalesce(v_vehicle.fuel_cost, 0), 2) end;
    v_rental_cost := case when v_is_rental then v_transport_cost else 0 end;

    if coalesce(v_vehicle.current_fuel, 0) < ceil(v_fuel_used) then raise exception 'Aracta yeterli yakit yok.'; end if;
    if coalesce(v_vehicle.condition, 0) <= 0 then raise exception 'Aracin bakimi yetersiz.'; end if;

    if v_is_rental and v_rental_cost > 0 then
      select cash into v_player_cash from public.players where id = v_player_id for update;
      if coalesce(v_player_cash, 0) < v_rental_cost then
        raise exception 'Arac kiralama bedeli icin yeterli nakit yok. Gerekli: % TL', v_rental_cost;
      end if;
      update public.players set cash = cash - v_rental_cost where id = v_player_id;
      perform public.log_player_cash_change(v_player_id, -v_rental_cost, v_player_cash, 'vehicle_rental_paid', format('Lojistik kiralama bedeli odendi (Transfer: %s)', v_transfer_id), v_transfer_id, 'logistics_transfer');
      perform public.process_logistics_vehicle_rental_payout(p_vehicle_id, v_transfer_id, v_player_id, v_rental_cost, v_distance_km);
    end if;

    update public.logistics_vehicles
    set status = 'on_route', current_fuel = greatest(current_fuel - ceil(v_fuel_used), 0), condition = greatest(condition - ceil(v_condition_loss), 0), updated_at = v_now
    where id = v_vehicle.id;
  end if;

  update public.logistics_transfers
  set product_id = v_header_product_id, quality_level = greatest(coalesce(v_header_quality_level, 1), 1), quantity = greatest(v_total_quantity, 1), unit_price = 0, total_price = v_total_price,
      product_unit_volume = greatest(v_total_volume, 0.0001), reserved_capacity_amount = v_total_volume, distance_km = v_distance_km, fuel_used = v_fuel_used, condition_loss = v_condition_loss,
      rental_cost = v_rental_cost, transport_cost = v_transport_cost, finish_at = v_finish_at,
      transfer_type = case
        when p_source_entity_kind = 'warehouse' and p_target_entity_kind = 'warehouse' then 'warehouse_to_warehouse_multi'
        when p_source_entity_kind = 'warehouse' and p_target_entity_kind = 'store' then 'warehouse_to_store_multi'
        when p_source_entity_kind = 'store' and p_target_entity_kind = 'warehouse' then 'store_to_warehouse_multi'
        else transfer_type
      end,
      item_count = v_item_count, total_quantity = v_total_quantity, brand_id = coalesce(v_header_brand_id, v_default_brand), updated_at = v_now
  where id = v_transfer_id;

  if v_same_city then perform public.complete_logistics_transfer(v_transfer_id); end if;

  return jsonb_build_object(
    'success', true,
    'transfer_id', v_transfer_id,
    'mode', v_mode,
    'item_count', v_item_count,
    'total_quantity', v_total_quantity,
    'reserved_capacity_amount', v_total_volume,
    'transport_cost', v_transport_cost,
    'finish_at', v_finish_at,
    'changed', jsonb_build_object(
      'player', public.get_player_profile(v_player_id)
    )
  );
end;
$$;

-- 6. start_multi_production_to_warehouse_transfer (changed: { player } eklemesi)
CREATE OR REPLACE FUNCTION public.start_multi_production_to_warehouse_transfer(
  p_source_owner_kind text,
  p_source_owner_id uuid,
  p_buyer_warehouse_id uuid,
  p_items jsonb,
  p_vehicle_id uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
declare
  v_default_brand uuid := '00000000-0000-0000-0000-000000000000'::uuid;
  v_player_id uuid := auth.uid();
  v_npc_logistics_player_id uuid;
  v_now timestamptz := timezone('utc', now());
  v_source_owner_player_id uuid;
  v_source_owner_city_id uuid;
  v_target_warehouse record;
  v_header_item jsonb;
  v_header_inventory record;
  v_vehicle logistics_vehicles%rowtype;
  v_transfer_id uuid;
  v_item jsonb;
  v_inventory record;
  v_product products%rowtype;
  v_same_city boolean := false;
  v_distance_km numeric := 0;
  v_fuel_used numeric := 0;
  v_condition_loss numeric := 0;
  v_transport_cost numeric := 0;
  v_rental_cost numeric := 0;
  v_duration_seconds integer := 0;
  v_finish_at timestamptz := v_now;
  v_total_volume numeric := 0;
  v_total_quantity integer := 0;
  v_item_count integer := 0;
  v_target_used_capacity numeric := 0;
  v_is_rental boolean := false;
  v_player_cash numeric := 0;
begin
  if v_player_id is null then raise exception 'Oturum acilmamis.'; end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then raise exception 'Transfer kalemi secilmedi.'; end if;

  case p_source_owner_kind
    when 'factory' then select player_id, city_id into v_source_owner_player_id, v_source_owner_city_id from public.factories where id = p_source_owner_id;
    when 'farm' then select player_id, city_id into v_source_owner_player_id, v_source_owner_city_id from public.farms where id = p_source_owner_id;
    when 'field' then select player_id, city_id into v_source_owner_player_id, v_source_owner_city_id from public.fields where id = p_source_owner_id;
    when 'mine' then select player_id, city_id into v_source_owner_player_id, v_source_owner_city_id from public.mines where id = p_source_owner_id;
    else raise exception 'Gecersiz kaynak uretim tipi.';
  end case;

  if v_source_owner_player_id is null or v_source_owner_player_id <> v_player_id then raise exception 'Kaynak uretim birimi oyuncuya ait degil.'; end if;

  select w.*, c.map_position_x, c.map_position_y into v_target_warehouse
  from public.warehouses w join public.cities c on c.id = w.city_id
  where w.id = p_buyer_warehouse_id and w.player_id = v_player_id and w.is_active = true for update;
  if not found then raise exception 'Hedef depo bulunamadi.'; end if;

  select coalesce(sum((ws.quantity + coalesce(ws.pending_quantity, 0)) * coalesce(p.birim_hacim, 0)), 0)
  into v_target_used_capacity from public.warehouse_slots ws left join public.products p on p.id = ws.product_id where ws.warehouse_id = v_target_warehouse.id;

  v_header_item := p_items -> 0;
  select * into v_header_inventory from public.production_inventory where id = nullif(v_header_item ->> 'production_inventory_id', '')::uuid for update;
  if not found then raise exception 'Ilk production envanteri bulunamadi.'; end if;
  if v_header_inventory.owner_kind <> p_source_owner_kind or v_header_inventory.owner_id <> p_source_owner_id then raise exception 'Tum kalemler ayni uretim birimine ait olmalidir.'; end if;

  insert into public.logistics_transfers (
    buyer_player_id, seller_player_id, buyer_warehouse_id, seller_production_inventory_id, logistics_vehicle_id, vehicle_owner_player_id,
    is_rental, product_id, quality_level, quantity, unit_price, total_price, product_unit_volume, reserved_capacity_amount, distance_km,
    fuel_used, condition_loss, rental_cost, transport_cost, started_at, finish_at, completed_at, status, transfer_type, seller_entity_kind,
    buyer_entity_kind, item_count, total_quantity, brand_id, created_at, updated_at
  ) values (
    v_player_id, v_player_id, p_buyer_warehouse_id, v_header_inventory.id, null, null, false, v_header_inventory.product_id, v_header_inventory.quality_level,
    1, 0, 0, 0.0001, 0, 0, 0, 0, 0, 0, v_now, v_now, null, 'in_transit', 'production_to_warehouse_multi', 'production_inventory', 'warehouse',
    1, 0, coalesce(v_header_inventory.brand_id, v_default_brand), v_now, v_now
  ) returning id into v_transfer_id;

  for v_item in select value from jsonb_array_elements(p_items) loop
    select * into v_inventory from public.production_inventory where id = nullif(v_item ->> 'production_inventory_id', '')::uuid for update;
    if not found then raise exception 'Production envanteri bulunamadi.'; end if;
    if v_inventory.owner_kind <> p_source_owner_kind or v_inventory.owner_id <> p_source_owner_id then raise exception 'Tum kalemler ayni uretim birimine ait olmalidir.'; end if;
    if coalesce(v_inventory.quantity, 0) < greatest(coalesce((v_item ->> 'quantity')::integer, 0), 0) then raise exception 'Production envanterinde yeterli stok yok.'; end if;
    select * into v_product from public.products where id = v_inventory.product_id;
    if not found then raise exception 'Urun bulunamadi.'; end if;
    if coalesce(v_product.birim_hacim, 0) <= 0 then raise exception 'Urun hacim bilgisi gecersiz.'; end if;

    v_total_quantity := v_total_quantity + greatest(coalesce((v_item ->> 'quantity')::integer, 0), 0);
    v_total_volume := v_total_volume + (greatest(coalesce((v_item ->> 'quantity')::integer, 0), 0) * coalesce(v_product.birim_hacim, 0));
    v_item_count := v_item_count + 1;
  end loop;

  if v_target_used_capacity + coalesce(v_target_warehouse.reserved_capacity, 0) + v_total_volume > coalesce(v_target_warehouse.capacity, 0) then
    raise exception 'Hedef depoda yeterli kapasite yok.';
  end if;

  v_same_city := v_source_owner_city_id = v_target_warehouse.city_id;

  if not v_same_city then
    if p_vehicle_id is null then raise exception 'Sehirler arasi transfer icin arac secilmelidir.'; end if;
    v_npc_logistics_player_id := public.get_npc_logistics_player_id();
    select * into v_vehicle from public.logistics_vehicles
    where id = p_vehicle_id and status = 'idle'
      and (player_id = v_player_id or (coalesce(is_available_for_rent, false) = true and (player_id = v_npc_logistics_player_id or public.logistics_vehicle_matches_route(route_city_a_id, route_city_b_id, v_source_owner_city_id, v_target_warehouse.city_id))))
    for update;
    if not found then raise exception 'Secilen arac kullanima uygun degil.'; end if;
    v_is_rental := v_vehicle.player_id <> v_player_id;

    if v_is_rental and v_vehicle.player_id = v_npc_logistics_player_id then
      v_vehicle.capacity := greatest(coalesce(v_vehicle.capacity, 0), ceil(v_total_volume));
      update public.logistics_vehicles set capacity = v_vehicle.capacity where id = v_vehicle.id;
    end if;

    if coalesce(v_vehicle.capacity, 0) < ceil(v_total_volume) then raise exception 'Secilen aracin kapasitesi bu transfer icin yetersiz.'; end if;
    if coalesce(v_vehicle.speed_kmh, 0) <= 0 then raise exception 'Secilen aracin hizi gecersiz.'; end if;

    select round((6371 * 2 * asin(sqrt(power(sin(radians(coalesce(v_target_warehouse.map_position_x, 0) - coalesce(sc.map_position_x, 0)) / 2), 2) + cos(radians(coalesce(sc.map_position_x, 0))) * cos(radians(coalesce(v_target_warehouse.map_position_x, 0))) * power(sin(radians(coalesce(v_target_warehouse.map_position_y, 0) - coalesce(sc.map_position_y, 0)) / 2), 2))))::numeric, 2)
    into v_distance_km from public.cities sc where sc.id = v_source_owner_city_id;

    v_duration_seconds := greatest(60, ceil((greatest(v_distance_km, 1) / v_vehicle.speed_kmh) * 120)::integer);
    v_finish_at := v_now + make_interval(secs => v_duration_seconds);
    v_fuel_used := round(v_distance_km * coalesce(v_vehicle.fuel_rate, 0), 2);
    v_condition_loss := greatest(1, ceil(v_distance_km / 200.0));
    v_transport_cost := case when v_is_rental then round(v_distance_km * coalesce(v_vehicle.rental_price, 0), 2) else round(v_fuel_used * coalesce(v_vehicle.fuel_cost, 0), 2) end;
    v_rental_cost := case when v_is_rental then v_transport_cost else 0 end;

    if coalesce(v_vehicle.current_fuel, 0) < ceil(v_fuel_used) then raise exception 'Aracta yeterli yakit yok.'; end if;
    if coalesce(v_vehicle.condition, 0) <= 0 then raise exception 'Aracin bakimi yetersiz.'; end if;

    if v_is_rental and v_rental_cost > 0 then
      select cash into v_player_cash from public.players where id = v_player_id for update;
      if coalesce(v_player_cash, 0) < v_rental_cost then raise exception 'Arac kiralama bedeli icin yeterli nakit yok. Gerekli: % TL', v_rental_cost; end if;
      update public.players set cash = cash - v_rental_cost where id = v_player_id;
      perform public.log_player_cash_change(v_player_id, -v_rental_cost, v_player_cash, 'vehicle_rental_paid', format('Uretim nakliye kiralama bedeli odendi (Transfer: %s)', v_transfer_id), v_transfer_id, 'logistics_transfer');
      perform public.process_logistics_vehicle_rental_payout(p_vehicle_id, v_transfer_id, v_player_id, v_rental_cost, v_distance_km);
    end if;
  end if;

  for v_item in select value from jsonb_array_elements(p_items) loop
    select * into v_inventory from public.production_inventory where id = nullif(v_item ->> 'production_inventory_id', '')::uuid for update;
    select * into v_product from public.products where id = v_inventory.product_id;

    insert into public.logistics_transfer_items (
      transfer_id, source_warehouse_slot_id, target_warehouse_slot_id, product_id, quality_level, brand_id, quantity, unit_cost, unit_price, total_cost, total_price, product_unit_volume, reserved_capacity_amount, status, created_at, updated_at, completed_at
    ) values (
      v_transfer_id, null, null, v_inventory.product_id, v_inventory.quality_level, coalesce(v_inventory.brand_id, v_default_brand), greatest(coalesce((v_item ->> 'quantity')::integer, 0), 0), coalesce(v_inventory.cost, 0), 0, greatest(coalesce((v_item ->> 'quantity')::integer, 0), 0) * coalesce(v_inventory.cost, 0), 0, coalesce(v_product.birim_hacim, 0), case when v_same_city then 0 else greatest(coalesce((v_item ->> 'quantity')::integer, 0), 0) * coalesce(v_product.birim_hacim, 0) end, 'in_transit', v_now, v_now, null
    );

    update public.production_inventory
    set quantity = quantity - greatest(coalesce((v_item ->> 'quantity')::integer, 0), 0),
        pending_quantity = case when inventory_type = 'input' then greatest(coalesce(pending_quantity, 0), 0) else pending_quantity end
    where id = v_inventory.id;
  end loop;

  update public.logistics_transfers
  set logistics_vehicle_id = case when v_same_city then null else p_vehicle_id end,
    vehicle_owner_player_id = case when v_same_city then null else v_vehicle.player_id end,
    is_rental = case when v_same_city then false else v_is_rental end,
    quantity = greatest(v_total_quantity, 1), unit_price = case when v_same_city then 0 else v_rental_cost end, total_price = 0, product_unit_volume = greatest(v_total_volume, 0.0001), reserved_capacity_amount = case when v_same_city then 0 else v_total_volume end, distance_km = case when v_same_city then 0 else v_distance_km end, fuel_used = case when v_same_city then 0 else v_fuel_used end, condition_loss = case when v_same_city then 0 else v_condition_loss end, rental_cost = 0, transport_cost = case when v_same_city then 0 else v_transport_cost end, finish_at = v_finish_at, completed_at = null, status = 'in_transit', item_count = v_item_count, total_quantity = v_total_quantity, updated_at = v_now
  where id = v_transfer_id;

  if not v_same_city then
    update public.logistics_vehicles set status = 'on_route', current_fuel = greatest(current_fuel - ceil(v_fuel_used), 0), condition = greatest(condition - ceil(v_condition_loss), 0), updated_at = v_now where id = v_vehicle.id;
    update public.warehouses set reserved_capacity = coalesce(reserved_capacity, 0) + v_total_volume, updated_at = v_now where id = p_buyer_warehouse_id;
  else
    perform public.complete_logistics_transfer(v_transfer_id);
  end if;

  return jsonb_build_object(
    'success', true,
    'mode', case when v_same_city then 'instant' else 'in_transit' end,
    'transfer_id', v_transfer_id,
    'transport_cost', case when v_same_city then 0 else v_transport_cost end,
    'finish_at', v_finish_at,
    'item_count', v_item_count,
    'total_quantity', v_total_quantity,
    'message', case when v_same_city then 'Coklu production cikis transferi aninda tamamlandi.' else 'Coklu production cikis transferi baslatildi.' end,
    'changed', jsonb_build_object(
      'player', public.get_player_profile(v_player_id)
    )
  );
end;
$$;

-- 7. start_multi_warehouse_to_production_transfer (changed: { player } eklemesi)
CREATE OR REPLACE FUNCTION public.start_multi_warehouse_to_production_transfer(
  p_source_warehouse_id uuid,
  p_items jsonb,
  p_vehicle_id uuid DEFAULT NULL::uuid,
  p_production_inventory_id uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
declare
  v_default_brand uuid := '00000000-0000-0000-0000-000000000000'::uuid;
  v_player_id uuid := auth.uid();
  v_npc_logistics_player_id uuid;
  v_now timestamptz := timezone('utc', now());
  v_source_warehouse record;
  v_target_owner_city_id uuid;
  v_header_item jsonb;
  v_header_inventory record;
  v_header_inv_id uuid;
  v_vehicle logistics_vehicles%rowtype;
  v_transfer_id uuid;
  v_item jsonb;
  v_inv_id uuid;
  v_slot_id uuid;
  v_source_slot record;
  v_inventory record;
  v_product products%rowtype;
  v_same_city boolean := false;
  v_distance_km numeric := 0;
  v_fuel_used numeric := 0;
  v_condition_loss numeric := 0;
  v_transport_cost numeric := 0;
  v_rental_cost numeric := 0;
  v_duration_seconds integer := 0;
  v_finish_at timestamptz := v_now;
  v_total_volume numeric := 0;
  v_total_quantity integer := 0;
  v_item_count integer := 0;
  v_item_quantity integer := 0;
  v_item_volume numeric := 0;
  v_is_rental boolean := false;
  v_player_cash numeric := 0;
begin
  if v_player_id is null then raise exception 'Oturum acilmamis.'; end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then raise exception 'Transfer kalemi secilmedi.'; end if;

  select w.*, c.map_position_x, c.map_position_y into v_source_warehouse from public.warehouses w join public.cities c on c.id = w.city_id
  where w.id = p_source_warehouse_id and w.player_id = v_player_id and w.is_active = true for update;
  if not found then raise exception 'Kaynak depo bulunamadi.'; end if;

  v_header_item := p_items -> 0;
  v_header_inv_id := coalesce(nullif(v_header_item ->> 'production_inventory_id', '')::uuid, p_production_inventory_id);
  if v_header_inv_id is null then raise exception 'Hedef production envanteri belirtilmedi.'; end if;

  select pi.*,
    case when pi.owner_kind = 'factory' then fx.player_id when pi.owner_kind = 'farm' then fa.player_id when pi.owner_kind = 'field' then fld.player_id when pi.owner_kind = 'mine' then m.player_id else null end as owner_player_id,
    case when pi.owner_kind = 'factory' then fx.city_id when pi.owner_kind = 'farm' then fa.city_id when pi.owner_kind = 'field' then fld.city_id when pi.owner_kind = 'mine' then m.city_id else null end as owner_city_id
  into v_header_inventory from public.production_inventory pi
  left join public.factories fx on pi.owner_kind = 'factory' and fx.id = pi.owner_id
  left join public.farms fa on pi.owner_kind = 'farm' and fa.id = pi.owner_id
  left join public.fields fld on pi.owner_kind = 'field' and fld.id = pi.owner_id
  left join public.mines m on pi.owner_kind = 'mine' and m.id = pi.owner_id
  where pi.id = v_header_inv_id for update of pi;

  if not found then raise exception 'Hedef production envanteri bulunamadi.'; end if;
  if v_header_inventory.owner_player_id <> v_player_id then raise exception 'Hedef uretim birimi oyuncuya ait degil.'; end if;

  v_target_owner_city_id := v_header_inventory.owner_city_id;
  v_same_city := (v_source_warehouse.city_id = v_target_owner_city_id);

  insert into public.logistics_transfers (
    buyer_player_id, seller_player_id, buyer_warehouse_id, seller_warehouse_id, buyer_production_inventory_id, logistics_vehicle_id,
    vehicle_owner_player_id, is_rental, product_id, quality_level, quantity, unit_price, total_price, product_unit_volume,
    reserved_capacity_amount, distance_km, fuel_used, condition_loss, rental_cost, transport_cost, started_at, finish_at, completed_at,
    status, transfer_type, seller_entity_kind, buyer_entity_kind, item_count, total_quantity, brand_id, created_at, updated_at
  ) values (
    v_player_id, v_player_id, null, p_source_warehouse_id, v_header_inventory.id, null, null, false, v_header_inventory.product_id, v_header_inventory.quality_level,
    1, 0, 0, 0.0001, 0, 0, 0, 0, 0, 0, v_now, v_now, null, 'in_transit', 'warehouse_to_production_multi', 'warehouse', 'production_inventory',
    1, 0, coalesce(v_header_inventory.brand_id, v_default_brand), v_now, v_now
  ) returning id into v_transfer_id;

  for v_item in select value from jsonb_array_elements(p_items) loop
    v_inv_id := coalesce(nullif(v_item ->> 'production_inventory_id', '')::uuid, p_production_inventory_id);
    v_slot_id := coalesce(nullif(v_item ->> 'source_warehouse_slot_id', ''), nullif(v_item ->> 'warehouse_slot_id', ''))::uuid;
    v_item_quantity := greatest(coalesce((v_item ->> 'quantity')::integer, 0), 0);

    if v_slot_id is null then raise exception 'Kaynak depo slot id si belirtilmedi.'; end if;
    if v_item_quantity <= 0 then raise exception 'Transfer miktari 0 dan buyuk olmalidir.'; end if;

    select ws.*, w.player_id, w.city_id into v_source_slot from public.warehouse_slots ws join public.warehouses w on w.id = ws.warehouse_id where ws.id = v_slot_id for update;
    if not found then raise exception 'Kaynak depo slotu bulunamadi: %', v_slot_id; end if;
    if v_source_slot.player_id <> v_player_id then raise exception 'Kaynak depo slotu oyuncuya ait degil.'; end if;
    if v_source_slot.warehouse_id <> p_source_warehouse_id then raise exception 'Tum kalemler ayni kaynak depoya ait olmalidir.'; end if;
    if coalesce(v_source_slot.quantity, 0) < v_item_quantity then raise exception 'Kaynak slotta yeterli stok yok.'; end if;

    select pi.*,
      case when pi.owner_kind = 'factory' then fx.player_id when pi.owner_kind = 'farm' then fa.player_id when pi.owner_kind = 'field' then fld.player_id when pi.owner_kind = 'mine' then m.player_id else null end as owner_player_id
    into v_inventory from public.production_inventory pi
    left join public.factories fx on pi.owner_kind = 'factory' and fx.id = pi.owner_id
    left join public.farms fa on pi.owner_kind = 'farm' and fa.id = pi.owner_id
    left join public.fields fld on pi.owner_kind = 'field' and fld.id = pi.owner_id
    left join public.mines m on pi.owner_kind = 'mine' and m.id = pi.owner_id
    where pi.id = v_inv_id for update of pi;

    if not found then raise exception 'Hedef production envanteri bulunamadi.'; end if;
    if v_inventory.owner_player_id <> v_player_id then raise exception 'Hedef production envanteri oyuncuya ait degil.'; end if;

    select * into v_product from public.products where id = v_source_slot.product_id;
    if not found then raise exception 'Urun bulunamadi: %', v_source_slot.product_id; end if;

    v_item_volume := v_item_quantity * coalesce(v_product.birim_hacim, 0.001);
    v_total_quantity := v_total_quantity + v_item_quantity;
    v_total_volume := v_total_volume + v_item_volume;
    v_item_count := v_item_count + 1;

    insert into public.logistics_transfer_items (
      transfer_id, source_warehouse_slot_id, target_warehouse_slot_id, target_production_inventory_id, product_id, quality_level,
      brand_id, quantity, unit_cost, unit_price, total_cost, total_price, product_unit_volume, reserved_capacity_amount, status, created_at, updated_at, completed_at
    ) values (
      v_transfer_id, v_source_slot.id, null, v_inventory.id, v_source_slot.product_id, v_source_slot.quality_level, coalesce(v_source_slot.brand_id, v_default_brand),
      v_item_quantity, coalesce(v_source_slot.cost, 0), 0, v_item_quantity * coalesce(v_source_slot.cost, 0), 0, coalesce(v_product.birim_hacim, 0.001), v_item_volume, 'in_transit', v_now, v_now, null
    );

    update public.warehouse_slots set quantity = quantity - v_item_quantity, updated_at = v_now where id = v_source_slot.id;
    if coalesce(v_source_slot.quantity, 0) - v_item_quantity <= 0 and coalesce(v_source_slot.pending_quantity, 0) <= 0 then
      delete from public.warehouse_slots where id = v_source_slot.id;
    end if;

    if not v_same_city then
      update public.production_inventory set pending_quantity = coalesce(pending_quantity, 0) + v_item_quantity, updated_at = v_now where id = v_inventory.id;
    end if;
  end loop;

  if not v_same_city then
    if p_vehicle_id is null then raise exception 'Sehirler arasi transfer icin arac secilmelidir.'; end if;
    v_npc_logistics_player_id := public.get_npc_logistics_player_id();
    select * into v_vehicle from public.logistics_vehicles
    where id = p_vehicle_id and status = 'idle'
      and (player_id = v_player_id or (coalesce(is_available_for_rent, false) = true and (player_id = v_npc_logistics_player_id or public.logistics_vehicle_matches_route(route_city_a_id, route_city_b_id, v_source_warehouse.city_id, v_target_owner_city_id))))
    for update;
    if not found then raise exception 'Secilen arac kullanima uygun degil.'; end if;
    v_is_rental := v_vehicle.player_id <> v_player_id;

    if v_is_rental and v_vehicle.player_id = v_npc_logistics_player_id then
      v_vehicle.capacity := greatest(coalesce(v_vehicle.capacity, 0), ceil(v_total_volume));
      update public.logistics_vehicles set capacity = v_vehicle.capacity where id = v_vehicle.id;
    end if;

    if coalesce(v_vehicle.capacity, 0) < ceil(v_total_volume) then raise exception 'Secilen aracin kapasitesi bu transfer icin yetersiz.'; end if;
    if coalesce(v_vehicle.speed_kmh, 0) <= 0 then raise exception 'Secilen aracin hizi gecersiz.'; end if;

    select round((6371 * 2 * asin(sqrt(power(sin(radians(coalesce(tc.map_position_x, 0) - coalesce(v_source_warehouse.map_position_x, 0)) / 2), 2) + cos(radians(coalesce(v_source_warehouse.map_position_x, 0))) * cos(radians(coalesce(v_target_warehouse.map_position_x, 0))) * power(sin(radians(coalesce(tc.map_position_y, 0) - coalesce(v_source_warehouse.map_position_y, 0)) / 2), 2))))::numeric, 2)
    into v_distance_km from public.cities tc where tc.id = v_target_owner_city_id;

    v_duration_seconds := greatest(60, ceil((greatest(v_distance_km, 1) / v_vehicle.speed_kmh) * 120)::integer);
    v_finish_at := v_now + make_interval(secs => v_duration_seconds);
    v_fuel_used := round(v_distance_km * coalesce(v_vehicle.fuel_rate, 0), 2);
    v_condition_loss := greatest(1, ceil(v_distance_km / 200.0));
    v_transport_cost := case when v_is_rental then round(v_distance_km * coalesce(v_vehicle.rental_price, 0), 2) else round(v_fuel_used * coalesce(v_vehicle.fuel_cost, 0), 2) end;
    v_rental_cost := case when v_is_rental then v_transport_cost else 0 end;

    if coalesce(v_vehicle.current_fuel, 0) < ceil(v_fuel_used) then raise exception 'Aracta yeterli yakit yok.'; end if;
    if coalesce(v_vehicle.condition, 0) <= 0 then raise exception 'Aracin bakimi yetersiz.'; end if;

    if v_is_rental and v_rental_cost > 0 then
      select cash into v_player_cash from public.players where id = v_player_id for update;
      if coalesce(v_player_cash, 0) < v_rental_cost then raise exception 'Arac kiralama bedeli icin yeterli nakit yok. Gerekli: % TL', v_rental_cost; end if;
      update public.players set cash = cash - v_rental_cost where id = v_player_id;
      perform public.log_player_cash_change(v_player_id, -v_rental_cost, v_player_cash, 'vehicle_rental_paid', format('Uretim girdi nakliye kiralama bedeli odendi (Transfer: %s)', v_transfer_id), v_transfer_id, 'logistics_transfer');
      perform public.process_logistics_vehicle_rental_payout(p_vehicle_id, v_transfer_id, v_player_id, v_rental_cost, v_distance_km);
    end if;

    update public.logistics_vehicles set status = 'on_route', current_fuel = greatest(current_fuel - ceil(v_fuel_used), 0), condition = greatest(condition - ceil(v_condition_loss), 0), updated_at = v_now where id = v_vehicle.id;
  end if;

  update public.logistics_transfers
  set logistics_vehicle_id = case when v_same_city then null else p_vehicle_id end,
    vehicle_owner_player_id = case when v_same_city then null else v_vehicle.player_id end,
    is_rental = case when v_same_city then false else v_is_rental end,
    quantity = greatest(v_total_quantity, 1), unit_price = case when v_same_city then 0 else v_rental_cost end, total_price = 0, product_unit_volume = greatest(v_total_volume, 0.0001), reserved_capacity_amount = case when v_same_city then 0 else v_total_volume end, distance_km = case when v_same_city then 0 else v_distance_km end, fuel_used = case when v_same_city then 0 else v_fuel_used end, condition_loss = case when v_same_city then 0 else v_condition_loss end, rental_cost = 0, transport_cost = case when v_same_city then 0 else v_transport_cost end, finish_at = v_finish_at, completed_at = null, status = 'in_transit', item_count = v_item_count, total_quantity = v_total_quantity, updated_at = v_now
  where id = v_transfer_id;

  if v_same_city then perform public.complete_logistics_transfer(v_transfer_id); end if;

  return jsonb_build_object(
    'success', true,
    'mode', case when v_same_city then 'instant' else 'in_transit' end,
    'transfer_id', v_transfer_id,
    'transport_cost', case when v_same_city then 0 else v_transport_cost end,
    'finish_at', v_finish_at,
    'item_count', v_item_count,
    'total_quantity', v_total_quantity,
    'message', case when v_same_city then 'Uretim birimine stok aktarimi aninda tamamlandi.' else 'Uretim birimine stok transferi baslatildi.' end,
    'changed', jsonb_build_object(
      'player', public.get_player_profile(v_player_id)
    )
  );
end;
$$;

-- 8. create_brand_company (changed: { player } eklemesi)
CREATE OR REPLACE FUNCTION public.create_brand_company(
  p_brand_name text,
  p_logo_id text DEFAULT NULL::text,
  p_theme_color text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_player_id uuid := auth.uid();
  v_brand_company public.brand_companies%rowtype;
  v_clean_name text;
  v_lower_name text;
  v_similar_record record;
  v_len integer;
BEGIN
  IF v_player_id IS NULL THEN
    RAISE EXCEPTION 'Oturum açılmamış.';
  END IF;

  -- 1. Check if player already has a brand company
  SELECT *
  INTO v_brand_company
  FROM public.brand_companies
  WHERE player_id = v_player_id
  LIMIT 1;

  IF FOUND THEN
    RAISE EXCEPTION 'Zaten aktif bir marka şirketiniz bulunmaktadır.';
  END IF;

  -- 2. Clean & normalize name (strip double spaces, trim)
  v_clean_name := btrim(regexp_replace(COALESCE(p_brand_name, ''), '\\s+', ' ', 'g'));
  v_len := char_length(v_clean_name);

  -- 3. Length validation
  IF v_len < 3 THEN
    RAISE EXCEPTION 'Marka adı çok kısa. En az 3 karakterden oluşmalıdır.';
  END IF;

  IF v_len > 24 THEN
    RAISE EXCEPTION 'Marka adı çok uzun. En fazla 24 karakter olabilir.';
  END IF;

  -- 4. Character set validation (Only Turkish/Latin letters, digits and spaces)
  IF v_clean_name !~* '^[a-z0-9çğışöüÇĞİŞÖÜ ]+$' THEN
    RAISE EXCEPTION 'Marka adında yalnızca harf, rakam ve boşluk kullanılabilir. Özel semboller, noktalama işaretleri veya emojiler kullanılamaz.';
  END IF;

  v_lower_name := lower(v_clean_name);

  -- 5. Reserved / Official Names Check
  IF v_lower_name IN (
    'admin', 'administrator', 'sistem', 'system', 'hard kapitalizm', 'kapitalizm',
    'merkez bankasi', 'merkez bankası', 'devlet', 'resmi', 'official', 'destek',
    'support', 'npc', 'toptan ticaret', 'belediye', 'bakanlik', 'bakanlık',
    'moderator', 'mod', 'türkiye', 'turkiye', 'hazine', 'maliye'
  ) OR v_lower_name LIKE 'admin%' OR v_lower_name LIKE 'sistem%' THEN
    RAISE EXCEPTION 'Bu marka adı resmi kurumlar ve sistem için rezerve edilmiştir. Lütfen şirketiniz için özgün bir marka adı seçin.';
  END IF;

  -- 6. Exact duplicate check (case-insensitive)
  IF EXISTS (
    SELECT 1 FROM public.brand_companies
    WHERE lower(btrim(brand_name)) = v_lower_name
      AND is_active = true
  ) THEN
    RAISE EXCEPTION '"%" marka adı daha önce başka bir holding tarafından tescil edilmiş. Lütfen farklı ve benzersiz bir marka adı seçin.', v_clean_name;
  END IF;

  -- 7. Knock-off / Fuzzy similarity check against existing brands
  SELECT
    brand_name,
    similarity(lower(brand_name), v_lower_name) AS sim,
    levenshtein(lower(brand_name), v_lower_name) AS dist
  INTO v_similar_record
  FROM public.brand_companies
  WHERE is_active = true
    AND (
      similarity(lower(brand_name), v_lower_name) >= 0.72
      OR (char_length(brand_name) <= 5 AND levenshtein(lower(brand_name), v_lower_name) <= 1)
      OR (char_length(brand_name) > 5 AND levenshtein(lower(brand_name), v_lower_name) <= 2)
    )
  ORDER BY similarity(lower(brand_name), v_lower_name) DESC
  LIMIT 1;

  IF v_similar_record.brand_name IS NOT NULL THEN
    RAISE EXCEPTION 'Belirlediğiniz marka adı tescilli "%" markasına aşırı derecede benzemektedir. Marka taklitçiliğini ve haksız rekabeti önlemek adına lütfen daha özgün bir isim seçin.', v_similar_record.brand_name;
  END IF;

  -- 8. Insert new brand company
  INSERT INTO public.brand_companies (
    player_id,
    brand_name,
    is_active,
    logo_id,
    theme_color,
    brand_level,
    brand_xp
  ) VALUES (
    v_player_id,
    v_clean_name,
    true,
    COALESCE(p_logo_id, 'logo_1.png'),
    COALESCE(p_theme_color, '#E5C05C'),
    1,
    0
  )
  RETURNING * INTO v_brand_company;

  RETURN jsonb_build_object(
    'success', true,
    'message', format('"%s" marka şirketiniz başarıyla tescillendi ve koruma altına alındı.', v_brand_company.brand_name),
    'brand_company_id', v_brand_company.id,
    'brand_name', v_brand_company.brand_name,
    'changed', jsonb_build_object(
      'player', public.get_player_profile(v_player_id)
    )
  );
END;
$$;

-- 9. patent_brand_company_product (changed: { player } eklemesi)
CREATE OR REPLACE FUNCTION public.patent_brand_company_product(
  p_product_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_player_id uuid := auth.uid();
  v_company_id uuid;
  v_cash numeric;
  v_patent_cost numeric := 50000.0;
  v_max_quality integer;
BEGIN
  IF v_player_id IS NULL THEN
    RAISE EXCEPTION 'Oturum acilmamis.';
  END IF;

  -- 1. Check if player has an active brand company
  SELECT id INTO v_company_id
  FROM public.brand_companies
  WHERE player_id = v_player_id AND is_active = true
  LIMIT 1;

  IF v_company_id IS NULL THEN
    RAISE EXCEPTION 'Aktif bir marka şirketiniz bulunmuyor.';
  END IF;

  -- 2. Check product quality eligibility (must be max quality level >= 2)
  SELECT COALESCE(MAX(max_quality_level), 1) INTO v_max_quality
  FROM public.player_product_quality_levels
  WHERE player_id = v_player_id AND product_id = p_product_id;

  IF v_max_quality < 2 THEN
    RAISE EXCEPTION 'Bir ürünü patentlemek için en az Q2 kalitesine yükseltmiş olmalısınız.';
  END IF;

  -- 3. Check if already patented
  IF EXISTS (
    SELECT 1 FROM public.brand_company_products
    WHERE brand_company_id = v_company_id AND product_id = p_product_id AND is_active = true
  ) THEN
    RAISE EXCEPTION 'Bu ürün zaten markanız altına tescilli.';
  END IF;

  -- 4. Check if player has enough cash
  SELECT cash INTO v_cash
  FROM public.players
  WHERE id = v_player_id FOR UPDATE;

  IF v_cash < v_patent_cost THEN
    RAISE EXCEPTION 'Bu ürünü patentlemek için yeterli nakitiniz yok (Gerekli: 50.000 ₺).';
  END IF;

  -- 5. Deduct cash & log transaction
  UPDATE public.players
  SET cash = cash - v_patent_cost
  WHERE id = v_player_id;

  PERFORM public.log_player_cash_change(
    v_player_id,
    -v_patent_cost,
    v_cash,
    'patent_expense',
    format('Ürün patentleme harcaması: %s', p_product_id),
    null,
    null
  );

  -- 6. Insert patent entry (Mevcut stoklar değiştirilmez, sadece yeni tescil kaydı açılır)
  INSERT INTO public.brand_company_products (brand_company_id, player_id, product_id)
  VALUES (v_company_id, v_player_id, p_product_id);

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Ürün başarıyla markanız altına patentlendi. Bundan sonra yapılacak üretimler markanızla üretilecektir.',
    'changed', jsonb_build_object(
      'player', public.get_player_profile(v_player_id)
    )
  );
END;
$$;

-- 10. start_marketing_campaign (changed: { player } eklemesi)
CREATE OR REPLACE FUNCTION public.start_marketing_campaign(
  p_campaign_type text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
declare
  v_player_id uuid := auth.uid();
  v_cash numeric;
  v_cost numeric;
  v_duration_hours integer;
  v_speed_mult numeric;
  v_price_mult numeric;
  v_active_until timestamptz;
  v_campaign record;
  v_now timestamptz := timezone('utc'::text, now());
begin
  if v_player_id is null then raise exception 'Oturum acilmamis.'; end if;

  if p_campaign_type = 'local' then
    v_cost := 25000; v_duration_hours := 24; v_speed_mult := 1.15; v_price_mult := 1.05;
  elsif p_campaign_type = 'regional' then
    v_cost := 75000; v_duration_hours := 24; v_speed_mult := 1.30; v_price_mult := 1.10;
  elsif p_campaign_type = 'global' then
    v_cost := 200000; v_duration_hours := 48; v_speed_mult := 1.50; v_price_mult := 1.20;
  else
    raise exception 'Gecersiz kampanya turu: %', p_campaign_type;
  end if;

  select cash into v_cash from public.players where id = v_player_id for update;
  if v_cash < v_cost then
    raise exception 'Kampanya baslatmak icin yeterli nakit yok. Gereken: %TL', v_cost;
  end if;

  select * into v_campaign from public.brand_marketing_campaigns
  where player_id = v_player_id and campaign_type = p_campaign_type and active_until > v_now limit 1;
  if found then
    raise exception 'Bu turde aktif bir kampanya zaten devam ediyor. Bitis: %', timezone('Europe/Istanbul', v_campaign.active_until);
  end if;

  update public.players set cash = cash - v_cost where id = v_player_id;
  perform public.log_player_cash_change(
    v_player_id, -v_cost, v_cash,
    'marketing_campaign',
    format('Pazarlama kampanyasi: %s', p_campaign_type),
    null, null
  );

  v_active_until := v_now + make_interval(hours => v_duration_hours);
  insert into public.brand_marketing_campaigns (player_id, campaign_type, cost_paid, active_until, sales_speed_multiplier, price_premium_multiplier)
  values (v_player_id, p_campaign_type, v_cost, v_active_until, v_speed_mult, v_price_mult);

  return jsonb_build_object(
    'success', true, 'message', 'Pazarlama kampanyasi baslatildi.',
    'campaign_type', p_campaign_type, 'cost_paid', v_cost, 'active_until', v_active_until,
    'changed', jsonb_build_object(
      'player', public.get_player_profile(v_player_id)
    )
  );
end;
$$;

-- 11. start_arge_center_construction (changed: { player } eklemesi)
CREATE OR REPLACE FUNCTION public.start_arge_center_construction(
  p_player_id uuid,
  p_name text DEFAULT 'AR-GE Merkezi'::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
declare
  v_player players%rowtype;
  v_cost numeric := 25000;
  v_required_level integer := 1;
  v_construction_time_minutes integer := 60;
  v_started_at timestamptz := timezone('utc', now());
  v_finish_at timestamptz;
  v_construction_id uuid;
  v_name text := coalesce(nullif(trim(p_name), ''), 'AR-GE Merkezi');
begin
  select * into v_player from public.players where id = p_player_id;
  if not found then return jsonb_build_object('success', false, 'message', 'Oyuncu bulunamadi.'); end if;

  if exists (select 1 from public.arge_centers ac where ac.player_id = p_player_id) then
    return jsonb_build_object('success', false, 'message', 'Zaten aktif bir AR-GE merkeziniz bulunuyor.');
  end if;

  if exists (
    select 1 from public.building_constructions bc
    where bc.player_id = p_player_id and bc.building_kind = 'arge_center' and bc.status = 'in_progress'
  ) then
    return jsonb_build_object('success', false, 'message', 'Devam eden bir AR-GE merkez kurulumu var.');
  end if;

  if v_player.level < v_required_level then
    return jsonb_build_object('success', false, 'message', format('Bu kurulum icin seviye %s gerekli. Mevcut seviyeniz: %s.', v_required_level, v_player.level));
  end if;

  if v_player.cash < v_cost then
    return jsonb_build_object('success', false, 'message', format('Yetersiz bakiye. Gerekli: %s TL, Mevcut: %s TL.', v_cost::bigint, v_player.cash::bigint));
  end if;

  v_finish_at := v_started_at + make_interval(mins => v_construction_time_minutes);

  update public.players set cash = cash - v_cost where id = p_player_id;
  perform public.log_player_cash_change(
    p_player_id, -v_cost, v_player.cash,
    'arge_construction', format('AR-GE Merkezi insaati: %s', v_name), null, 'arge_center'
  );

  insert into public.building_constructions (player_id, building_kind, params, status, started_at, finish_at)
  values (p_player_id, 'arge_center',
    jsonb_build_object('name', v_name, 'level', 1, 'max_concurrent_researches', 1, 'duration_reduction_pct', 0,
      'cost', v_cost, 'construction_time_minutes', v_construction_time_minutes),
    'in_progress', v_started_at, v_finish_at)
  returning id into v_construction_id;

  return jsonb_build_object(
    'success', true, 'construction_id', v_construction_id, 'building_kind', 'arge_center',
    'name', v_name, 'cost', v_cost, 'finish_at', v_finish_at, 'construction_time_minutes', v_construction_time_minutes,
    'changed', jsonb_build_object(
      'player', public.get_player_profile(p_player_id)
    )
  );
end;
$$;

-- 12. start_arge_research (changed: { player } eklemesi)
CREATE OR REPLACE FUNCTION public.start_arge_research(
  p_player_id uuid,
  p_product_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_arge_center record;
  v_active_count integer;
  v_already_researching integer;
  v_product record;
  v_current_quality integer := 1;
  v_target_quality integer;
  v_required_rm_quality integer;
  v_rm_quality integer := 1;
  v_rm_name text;
  v_player_level integer;
  v_player_cash numeric;
  v_required_player_level integer;
  v_multiplier integer;
  v_min_cost numeric;
  v_scaled_cost numeric;
  v_upgrade_cost numeric;
  v_base_hours integer;
  v_reduced_hours numeric;
  v_finish_at timestamp with time zone;
  v_research_id uuid;
BEGIN
  -- 1. Check if the player has an active ARGE center
  SELECT * INTO v_arge_center
  FROM public.arge_centers
  WHERE player_id = p_player_id AND is_active = true;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Aktif bir AR-GE merkeziniz bulunmuyor.'
    );
  END IF;

  -- 2. Check if the player has reached maximum concurrent researches
  SELECT COUNT(*) INTO v_active_count
  FROM public.arge_researches
  WHERE player_id = p_player_id AND status = 'in_progress';
  
  IF v_active_count >= v_arge_center.max_concurrent_researches THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Tüm araştırma slotlarınız dolu.'
    );
  END IF;

  -- 3. Check if the player is already researching this exact product
  SELECT COUNT(*) INTO v_already_researching
  FROM public.arge_researches
  WHERE player_id = p_player_id AND product_id = p_product_id AND status = 'in_progress';
  
  IF v_already_researching > 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Bu ürün için zaten aktif bir araştırma yürütülüyor.'
    );
  END IF;

  -- 4. Find the product details
  SELECT * INTO v_product FROM public.products WHERE id = p_product_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Ürün bulunamadı.'
    );
  END IF;

  -- 5. Get current quality level of the product for the player
  SELECT COALESCE(max_quality_level, 1) INTO v_current_quality
  FROM public.player_product_quality_levels
  WHERE player_id = p_player_id AND product_id = p_product_id;
  
  v_current_quality := COALESCE(v_current_quality, 1);

  -- 6. Check if already at maximum quality level (level 5)
  IF v_current_quality >= 5 THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Bu ürün zaten maksimum kalite seviyesinde (Q5).'
    );
  END IF;
  
  v_target_quality := v_current_quality + 1;
  v_required_rm_quality := v_target_quality - 1;

  -- 7. Check raw material quality levels
  -- Check hammadde 1
  IF v_product.hammadde_1_id IS NOT NULL AND v_product.hammadde_1_id <> '' THEN
    v_rm_quality := 1;
    SELECT COALESCE(max_quality_level, 1) INTO v_rm_quality
    FROM public.player_product_quality_levels
    WHERE player_id = p_player_id AND product_id = v_product.hammadde_1_id;
    v_rm_quality := COALESCE(v_rm_quality, 1);
    
    IF v_rm_quality < v_required_rm_quality THEN
      SELECT urun_adi INTO v_rm_name FROM public.products WHERE id = v_product.hammadde_1_id;
      RETURN jsonb_build_object(
        'success', false,
        'message', 'Bu ürünü Q' || v_target_quality::text || ' seviyesine yükseltmek için hammaddesi ' || v_rm_name || ' en az Q' || v_required_rm_quality::text || ' seviyesinde olmalıdır.'
      );
    END IF;
  END IF;

  -- Check hammadde 2
  IF v_product.hammadde_2_id IS NOT NULL AND v_product.hammadde_2_id <> '' THEN
    v_rm_quality := 1;
    SELECT COALESCE(max_quality_level, 1) INTO v_rm_quality
    FROM public.player_product_quality_levels
    WHERE player_id = p_player_id AND product_id = v_product.hammadde_2_id;
    v_rm_quality := COALESCE(v_rm_quality, 1);
    
    IF v_rm_quality < v_required_rm_quality THEN
      SELECT urun_adi INTO v_rm_name FROM public.products WHERE id = v_product.hammadde_2_id;
      RETURN jsonb_build_object(
        'success', false,
        'message', 'Bu ürünü Q' || v_target_quality::text || ' seviyesine yükseltmek için hammaddesi ' || v_rm_name || ' en az Q' || v_required_rm_quality::text || ' seviyesinde olmalıdır.'
      );
    END IF;
  END IF;

  -- Check hammadde 3
  IF v_product.hammadde_3_id IS NOT NULL AND v_product.hammadde_3_id <> '' THEN
    v_rm_quality := 1;
    SELECT COALESCE(max_quality_level, 1) INTO v_rm_quality
    FROM public.player_product_quality_levels
    WHERE player_id = p_player_id AND product_id = v_product.hammadde_3_id;
    v_rm_quality := COALESCE(v_rm_quality, 1);
    
    IF v_rm_quality < v_required_rm_quality THEN
      SELECT urun_adi INTO v_rm_name FROM public.products WHERE id = v_product.hammadde_3_id;
      RETURN jsonb_build_object(
        'success', false,
        'message', 'Bu ürünü Q' || v_target_quality::text || ' seviyesine yükseltmek için hammaddesi ' || v_rm_name || ' en az Q' || v_required_rm_quality::text || ' seviyesinde olmalıdır.'
      );
    END IF;
  END IF;

  -- 8. Check player level requirement
  IF v_target_quality = 2 THEN
    v_required_player_level := 5;
  ELSIF v_target_quality = 3 THEN
    v_required_player_level := 15;
  ELSIF v_target_quality = 4 THEN
    v_required_player_level := 30;
  ELSIF v_target_quality = 5 THEN
    v_required_player_level := 45;
  ELSE
    v_required_player_level := 50;
  END IF;

  SELECT level, cash INTO v_player_level, v_player_cash FROM public.players WHERE id = p_player_id;
  
  IF v_player_level < v_required_player_level THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Gerekli oyuncu seviyesine (Lv. ' || v_required_player_level::text || ') sahip değilsiniz.'
    );
  END IF;

  -- 9. Calculate upgrade cost
  IF v_current_quality = 1 THEN
    v_multiplier := 10;
    v_min_cost := 2500;
  ELSIF v_current_quality = 2 THEN
    v_multiplier := 25;
    v_min_cost := 15000;
  ELSIF v_current_quality = 3 THEN
    v_multiplier := 60;
    v_min_cost := 75000;
  ELSIF v_current_quality = 4 THEN
    v_multiplier := 150;
    v_min_cost := 300000;
  ELSE
    v_multiplier := 0;
    v_min_cost := 0;
  END IF;
  
  v_scaled_cost := v_product.baz_satis_fiyati * v_multiplier;
  IF v_scaled_cost < v_min_cost THEN
    v_upgrade_cost := v_min_cost;
  ELSE
    v_upgrade_cost := v_scaled_cost;
  END IF;
  
  IF v_player_cash < v_upgrade_cost THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Araştırma başlatmak için yeterli paranız bulunmuyor.'
    );
  END IF;

  -- 10. Calculate duration
  IF v_current_quality = 1 THEN
    v_base_hours := 2;
  ELSIF v_current_quality = 2 THEN
    v_base_hours := 5;
  ELSIF v_current_quality = 3 THEN
    v_base_hours := 10;
  ELSIF v_current_quality = 4 THEN
    v_base_hours := 24;
  ELSE
    v_base_hours := 0;
  END IF;
  
  v_reduced_hours := v_base_hours * (1.0 - COALESCE(v_arge_center.duration_reduction_pct, 0) / 100.0);
  v_finish_at := now() + (v_reduced_hours * interval '1 hour');

  -- 11. Process deduction and insert research record
  UPDATE public.players SET cash = cash - v_upgrade_cost WHERE id = p_player_id;
  PERFORM public.log_player_cash_change(
    p_player_id, -v_upgrade_cost, v_player_cash,
    'arge_research', format('AR-GE Arastirma: %s Q%s->Q%s', v_product.urun_adi, v_current_quality, v_target_quality),
    null, 'arge_research'
  );
  
  INSERT INTO public.arge_researches (
    player_id,
    product_id,
    product_name,
    current_quality,
    target_quality,
    cost_paid,
    status,
    started_at,
    finish_at
  ) VALUES (
    p_player_id,
    p_product_id,
    v_product.urun_adi,
    v_current_quality,
    v_target_quality,
    v_upgrade_cost,
    'in_progress',
    now(),
    v_finish_at
  ) RETURNING id INTO v_research_id;

  RETURN jsonb_build_object(
    'success', true,
    'message', v_product.urun_adi || ' için geliştirme başlatıldı.',
    'product_name', v_product.urun_adi,
    'research_id', v_research_id,
    'finish_at', v_finish_at,
    'changed', jsonb_build_object(
      'player', public.get_player_profile(p_player_id)
    )
  );
END;
$$;

-- 13. complete_arge_research (changed: { player } eklemesi)
CREATE OR REPLACE FUNCTION public.complete_arge_research(
  p_research_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
declare
  v_research arge_researches%rowtype;
  v_now timestamptz := timezone('utc', now());
  v_exp_result jsonb;
begin
  select * into v_research
  from arge_researches
  where id = p_research_id
  for update;

  if not found then
    return jsonb_build_object('success', false, 'message', 'Arastirma bulunamadi.');
  end if;

  if v_research.status <> 'in_progress' then
    return jsonb_build_object('success', false, 'message', 'Bu arastirma zaten tamamlanmis.');
  end if;

  if v_research.finish_at > v_now then
    return jsonb_build_object('success', false, 'message', 'Arastirma henuz tamamlanmadi.');
  end if;

  insert into player_product_quality_levels (player_id, product_id, max_quality_level, created_at, updated_at)
  values (v_research.player_id, v_research.product_id, v_research.target_quality, v_now, v_now)
  on conflict (player_id, product_id) do update
    set max_quality_level = excluded.max_quality_level, updated_at = v_now;

  update arge_researches
  set status = 'completed', completed_at = v_now
  where id = p_research_id;

  v_exp_result := public.grant_player_experience(
    v_research.player_id,
    public.calculate_experience_reward(
      'arge_research_completed',
      jsonb_build_object(
        'product_id', v_research.product_id,
        'target_quality', v_research.target_quality
      )
    ),
    'arge_research_completed',
    jsonb_build_object(
      'research_id', p_research_id,
      'product_id', v_research.product_id,
      'product_name', v_research.product_name,
      'target_quality', v_research.target_quality
    )
  );

  return jsonb_build_object(
    'success', true,
    'product_id', v_research.product_id,
    'product_name', v_research.product_name,
    'new_quality_level', v_research.target_quality,
    'experience', v_exp_result,
    'changed', jsonb_build_object(
      'player', public.get_player_profile(v_research.player_id)
    )
  );
end;
$$;

-- 14. repair_all_logistics_vehicles (changed: { player } eklemesi)
CREATE OR REPLACE FUNCTION public.repair_all_logistics_vehicles(
  p_player_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
declare
  v_vehicle record;
  v_count integer := 0;
  v_total_cost numeric := 0;
  v_res jsonb;
begin
  if p_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  for v_vehicle in
    select id
    from public.logistics_vehicles
    where player_id = p_player_id
      and status = 'idle'
      and condition < 100
    order by condition asc
  loop
    begin
      v_res := public.repair_logistics_vehicle(p_player_id, v_vehicle.id);
      v_count := v_count + 1;
      v_total_cost := v_total_cost + coalesce((v_res ->> 'repair_cost')::numeric, 0);
    exception when others then
      -- Bakiye yetmezse dur
      exit;
    end;
  end loop;

  return jsonb_build_object(
    'success', true,
    'repaired_vehicle_count', v_count,
    'total_cost', v_total_cost,
    'message', format('%s arac bakimdan gecirildi. Toplam harcama: %s TL', v_count, v_total_cost::bigint),
    'changed', jsonb_build_object(
      'player', public.get_player_profile(p_player_id)
    )
  );
end;
$$;

-- 15. claim_daily_streak_reward (changed: { player, dashboard_dirty } eklemesi)
CREATE OR REPLACE FUNCTION public.claim_daily_streak_reward(
  p_reward_cash numeric,
  p_reward_gold numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_player_id uuid := auth.uid();
  v_current_cash numeric;
  v_current_gold numeric;
BEGIN
  IF v_player_id IS NULL THEN
    RAISE EXCEPTION 'Oturum acilmamis.';
  END IF;

  -- Update player cash and gold
  UPDATE public.players
  SET cash = cash + p_reward_cash,
      gold = gold + p_reward_gold
  WHERE id = v_player_id
  RETURNING cash, gold INTO v_current_cash, v_current_gold;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Oyuncu bulunamadi.';
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Gunluk giris odulu alindi.',
    'new_cash', v_current_cash,
    'new_gold', v_current_gold,
    'changed', jsonb_build_object(
      'player', public.get_player_profile(v_player_id),
      'dashboard_dirty', true
    )
  );
END;
$$;
