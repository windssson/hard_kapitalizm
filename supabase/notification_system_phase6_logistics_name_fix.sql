create or replace function public.build_player_attention_notifications(
  p_player_id uuid default auth.uid()
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_player_id uuid := p_player_id;
  v_keys text[] := array[]::text[];
  v_key text;
  v_count integer := 0;
  v_now timestamptz := timezone('utc', now());
  v_row record;
begin
  if v_player_id is null then
    return jsonb_build_object('success', false, 'message', 'Oyuncu bulunamadi.');
  end if;

  for v_row in
    select s.id, s.name, count(*)::int as empty_slot_count
    from public.stores s
    join public.store_slots ss on ss.store_id = s.id
    where s.player_id = v_player_id
      and s.is_active = true
      and ss.is_active = true
      and ss.product_id is null
    group by s.id, s.name
    having count(*) > 0
  loop
    v_key := 'store_empty_slots:' || v_row.id::text;
    v_keys := array_append(v_keys, v_key);
    perform public.create_player_notification(v_player_id,'warning','store_blocked','Magazada Bos Slot Var',v_row.name || ' icinde ' || v_row.empty_slot_count::text || ' bos aktif slot bulunuyor.','store',v_row.id,'warning',jsonb_build_object('empty_slot_count', v_row.empty_slot_count),v_key);
    v_count := v_count + 1;
  end loop;

  for v_row in
    select s.id, s.name, count(*)::int as out_of_stock_slot_count
    from public.stores s
    join public.store_slots ss on ss.store_id = s.id
    where s.player_id = v_player_id
      and s.is_active = true
      and ss.is_active = true
      and ss.product_id is not null
      and coalesce(ss.quantity, 0) <= 0
      and coalesce(ss.pending_quantity, 0) <= 0
    group by s.id, s.name
    having count(*) > 0
  loop
    v_key := 'store_out_of_stock:' || v_row.id::text;
    v_keys := array_append(v_keys, v_key);
    perform public.create_player_notification(v_player_id,'warning','store_blocked','Magazada Stok Bitti',v_row.name || ' icinde ' || v_row.out_of_stock_slot_count::text || ' aktif slotta stok kalmadi.','store',v_row.id,'warning',jsonb_build_object('out_of_stock_slot_count', v_row.out_of_stock_slot_count),v_key);
    v_count := v_count + 1;
  end loop;

  for v_row in
    select entity_kind, entity_id, entity_name
    from (
      select 'store'::text as entity_kind, s.id as entity_id, s.name as entity_name
      from public.stores s
      where s.player_id = v_player_id
        and s.is_active = false
      union all
      select 'factory'::text as entity_kind, f.id as entity_id, f.name as entity_name
      from public.factories f
      where f.player_id = v_player_id
        and f.is_active = false
      union all
      select 'field'::text as entity_kind, f.id as entity_id, f.name as entity_name
      from public.fields f
      where f.player_id = v_player_id
        and f.is_active = false
      union all
      select 'farm'::text as entity_kind, f.id as entity_id, f.name as entity_name
      from public.farms f
      where f.player_id = v_player_id
        and f.is_active = false
      union all
      select 'mine'::text as entity_kind, m.id as entity_id, m.name as entity_name
      from public.mines m
      where m.player_id = v_player_id
        and m.is_active = false
    ) inactive_entities
  loop
    v_key := 'inactive_reminder:' || v_row.entity_kind || ':' || v_row.entity_id::text;
    v_keys := array_append(v_keys, v_key);
    perform public.create_player_notification(v_player_id,'event','inactive_reminder','Pasif Isletme Hatirlatmasi',v_row.entity_name || ' su anda pasif durumda.',v_row.entity_kind,v_row.entity_id,'info',jsonb_build_object('reason', 'inactive'),v_key);
  end loop;

  for v_row in
    select f.id, f.name
    from public.factories f
    where f.player_id = v_player_id
      and f.is_active = true
      and f.product_id is null
  loop
    v_key := 'factory_product_missing:' || v_row.id::text;
    v_keys := array_append(v_keys, v_key);
    perform public.create_player_notification(v_player_id,'warning','production_blocked','Fabrikada Urun Secili Degil',v_row.name || ' icin uretim urunu secilmedigi icin uretim duruyor.','factory',v_row.id,'warning','{}'::jsonb,v_key);
    v_count := v_count + 1;
  end loop;

  for v_row in
    select f.id, f.name
    from public.factories f
    join public.products p on p.id = f.product_id
    where f.player_id = v_player_id
      and f.is_active = true
      and f.product_id is not null
      and exists (
        select 1
        from (
          values
            (p.hammadde_1_id, p.hammadde_1_miktar),
            (p.hammadde_2_id, p.hammadde_2_miktar),
            (p.hammadde_3_id, p.hammadde_3_miktar)
        ) as req(product_id, qty)
        left join public.production_inventory pi
          on pi.owner_kind = 'factory'
         and pi.owner_id = f.id
         and pi.inventory_type = 'input'
         and pi.product_id = req.product_id
         and pi.quality_level = f.quality_level
        where req.product_id is not null
          and coalesce(req.qty, 0) > coalesce(pi.quantity, 0)
      )
  loop
    v_key := 'factory_input_missing:' || v_row.id::text;
    v_keys := array_append(v_keys, v_key);
    perform public.create_player_notification(v_player_id,'warning','production_blocked','Fabrikada Hammadde Eksik',v_row.name || ' icin gerekli hammadde yetersiz.','factory',v_row.id,'warning','{}'::jsonb,v_key);
    v_count := v_count + 1;
  end loop;

  for v_row in
    select f.id, f.name
    from public.factories f
    left join public.production_inventory pi
      on pi.owner_kind = 'factory'
     and pi.owner_id = f.id
     and pi.inventory_type = 'output'
    where f.player_id = v_player_id
      and f.is_active = true
      and f.output_capacity > 0
    group by f.id, f.name, f.output_capacity
    having coalesce(sum(coalesce(pi.quantity, 0) + coalesce(pi.pending_quantity, 0)), 0) >= f.output_capacity
  loop
    v_key := 'factory_output_full:' || v_row.id::text;
    v_keys := array_append(v_keys, v_key);
    perform public.create_player_notification(v_player_id,'warning','production_blocked','Fabrika Cikti Deposu Dolu',v_row.name || ' icin cikti kapasitesi doldu.','factory',v_row.id,'warning','{}'::jsonb,v_key);
    v_count := v_count + 1;
  end loop;

  for v_row in
    select owner_kind, owner_id, owner_name, count(*)::int as empty_slot_count
    from (
      select ps.owner_kind, ps.owner_id, f.name as owner_name
      from public.production_slots ps
      join public.fields f on f.id = ps.owner_id
      where ps.owner_kind = 'field'
        and f.player_id = v_player_id
        and f.is_active = true
        and ps.is_active = true
        and ps.product_id is null
      union all
      select ps.owner_kind, ps.owner_id, f.name as owner_name
      from public.production_slots ps
      join public.farms f on f.id = ps.owner_id
      where ps.owner_kind = 'farm'
        and f.player_id = v_player_id
        and f.is_active = true
        and ps.is_active = true
        and ps.product_id is null
    ) slots
    group by owner_kind, owner_id, owner_name
  loop
    v_key := v_row.owner_kind || '_empty_slots:' || v_row.owner_id::text;
    v_keys := array_append(v_keys, v_key);
    perform public.create_player_notification(v_player_id,'warning','production_blocked','Bos Uretim Slotu Var',v_row.owner_name || ' icinde ' || v_row.empty_slot_count::text || ' bos aktif uretim slotu bulunuyor.',v_row.owner_kind,v_row.owner_id,'warning',jsonb_build_object('empty_slot_count', v_row.empty_slot_count),v_key);
    v_count := v_count + 1;
  end loop;

  for v_row in
    select owner_kind, owner_id, owner_name
    from (
      select 'field'::text as owner_kind, f.id as owner_id, f.name as owner_name, f.output_capacity,
             coalesce(sum(coalesce(pi.quantity, 0) + coalesce(pi.pending_quantity, 0)), 0) as used_capacity
      from public.fields f
      left join public.production_inventory pi
        on pi.owner_kind = 'field'
       and pi.owner_id = f.id
       and pi.inventory_type = 'output'
      where f.player_id = v_player_id
        and f.is_active = true
      group by f.id, f.name, f.output_capacity
      union all
      select 'farm'::text as owner_kind, f.id as owner_id, f.name as owner_name, f.output_capacity,
             coalesce(sum(coalesce(pi.quantity, 0) + coalesce(pi.pending_quantity, 0)), 0) as used_capacity
      from public.farms f
      left join public.production_inventory pi
        on pi.owner_kind = 'farm'
       and pi.owner_id = f.id
       and pi.inventory_type = 'output'
      where f.player_id = v_player_id
        and f.is_active = true
      group by f.id, f.name, f.output_capacity
    ) owners
    where output_capacity > 0 and used_capacity >= output_capacity
  loop
    v_key := v_row.owner_kind || '_output_full:' || v_row.owner_id::text;
    v_keys := array_append(v_keys, v_key);
    perform public.create_player_notification(v_player_id,'warning','production_blocked','Uretim Cikti Deposu Dolu',v_row.owner_name || ' icin cikti kapasitesi doldu.',v_row.owner_kind,v_row.owner_id,'warning','{}'::jsonb,v_key);
    v_count := v_count + 1;
  end loop;

  for v_row in
    select m.id, m.name
    from public.mines m
    where m.player_id = v_player_id
      and m.is_active = true
      and m.product_id is null
  loop
    v_key := 'mine_product_missing:' || v_row.id::text;
    v_keys := array_append(v_keys, v_key);
    perform public.create_player_notification(v_player_id,'warning','production_blocked','Madende Urun Secili Degil',v_row.name || ' icin uretim urunu secilmedigi icin uretim duruyor.','mine',v_row.id,'warning','{}'::jsonb,v_key);
    v_count := v_count + 1;
  end loop;

  for v_row in
    select m.id, m.name
    from public.mines m
    left join public.production_inventory pi
      on pi.owner_kind = 'mine'
     and pi.owner_id = m.id
     and pi.inventory_type = 'output'
    where m.player_id = v_player_id
      and m.is_active = true
      and m.output_capacity > 0
    group by m.id, m.name, m.output_capacity
    having coalesce(sum(coalesce(pi.quantity, 0) + coalesce(pi.pending_quantity, 0)), 0) >= m.output_capacity
  loop
    v_key := 'mine_output_full:' || v_row.id::text;
    v_keys := array_append(v_keys, v_key);
    perform public.create_player_notification(v_player_id,'warning','production_blocked','Maden Cikti Deposu Dolu',v_row.name || ' icin cikti kapasitesi doldu.','mine',v_row.id,'warning','{}'::jsonb,v_key);
    v_count := v_count + 1;
  end loop;

  for v_row in
    select lc.id, lc.name, count(*)::int as inactive_vehicle_count
    from public.logistics_companies lc
    join public.logistics_vehicles lv on lv.logistics_company_id = lc.id
    where lc.player_id = v_player_id
      and lv.status = 'inactive'
    group by lc.id, lc.name
    having count(*) > 0
  loop
    v_key := 'logistics_inactive_vehicles:' || v_row.id::text;
    v_keys := array_append(v_keys, v_key);
    perform public.create_player_notification(v_player_id,'warning','logistics_attention','Pasif Nakliye Araci Var',v_row.name || ' icinde ' || v_row.inactive_vehicle_count::text || ' arac pasif durumda.','logistics',v_row.id,'warning',jsonb_build_object('inactive_vehicle_count', v_row.inactive_vehicle_count),v_key);
    v_count := v_count + 1;
  end loop;

  for v_row in
    select lc.id, lc.name, count(*)::int as low_fuel_vehicle_count
    from public.logistics_companies lc
    join public.logistics_vehicles lv on lv.logistics_company_id = lc.id
    where lc.player_id = v_player_id
      and lv.status = 'idle'
      and lv.fuel_capacity > 0
      and coalesce(lv.current_fuel, 0) <= greatest(5, ceil(lv.fuel_capacity * 0.10)::integer)
    group by lc.id, lc.name
    having count(*) > 0
  loop
    v_key := 'logistics_low_fuel:' || v_row.id::text;
    v_keys := array_append(v_keys, v_key);
    perform public.create_player_notification(v_player_id,'warning','logistics_attention','Yakit Kritik Seviyede',v_row.name || ' icinde ' || v_row.low_fuel_vehicle_count::text || ' arac kritik yakit seviyesinde.','logistics',v_row.id,'warning',jsonb_build_object('low_fuel_vehicle_count', v_row.low_fuel_vehicle_count),v_key);
    v_count := v_count + 1;
  end loop;

  for v_row in
    select lc.id, lc.name, count(*)::int as low_condition_vehicle_count
    from public.logistics_companies lc
    join public.logistics_vehicles lv on lv.logistics_company_id = lc.id
    where lc.player_id = v_player_id
      and lv.status = 'idle'
      and coalesce(lv.condition, 100) <= 25
    group by lc.id, lc.name
    having count(*) > 0
  loop
    v_key := 'logistics_low_condition:' || v_row.id::text;
    v_keys := array_append(v_keys, v_key);
    perform public.create_player_notification(v_player_id,'warning','logistics_attention','Kondisyon Dusuk',v_row.name || ' icinde ' || v_row.low_condition_vehicle_count::text || ' arac bakim ihtiyaci duyuyor.','logistics',v_row.id,'warning',jsonb_build_object('low_condition_vehicle_count', v_row.low_condition_vehicle_count),v_key);
    v_count := v_count + 1;
  end loop;

  update public.player_notifications
  set
    status = 'resolved',
    resolved_at = coalesce(resolved_at, v_now),
    updated_at = v_now
  where player_id = v_player_id
    and (kind = 'warning' or category = 'inactive_reminder')
    and status <> 'resolved'
    and (cardinality(v_keys) = 0 or dedupe_key <> all(v_keys));

  return jsonb_build_object('success', true, 'active_warning_count', v_count);
end;
$$;
