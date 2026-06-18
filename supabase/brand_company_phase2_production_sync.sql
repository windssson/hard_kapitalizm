create or replace function public.patent_brand_company_product(
  p_product_id text
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_player_id uuid := auth.uid();
  v_company public.brand_companies%rowtype;
  v_product public.products%rowtype;
  v_inventory_row record;
  v_max_quality integer := 0;
  v_factory_sync_count integer := 0;
  v_mine_sync_count integer := 0;
  v_slot_sync_count integer := 0;
  v_inventory_sync_count integer := 0;
  v_inventory_merge_count integer := 0;
  v_target_inventory_id uuid;
  v_existing_quantity numeric;
  v_existing_pending numeric;
  v_existing_cost numeric;
  v_merged_quantity numeric;
begin
  if v_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  select *
  into v_company
  from public.brand_companies
  where player_id = v_player_id
    and is_active = true
  limit 1;

  if not found then
    raise exception 'Oyuncunun aktif marka sirketi yok.';
  end if;

  select *
  into v_product
  from public.products
  where id = p_product_id;

  if not found then
    raise exception 'Urun bulunamadi.';
  end if;

  select coalesce(max(max_quality_level), 0)
  into v_max_quality
  from public.player_product_quality_levels
  where player_id = v_player_id
    and product_id = p_product_id;

  if v_max_quality < 5 then
    raise exception 'Bu urun icin marka patenti almak icin kalite 5 gereklidir.';
  end if;

  insert into public.brand_company_products (
    brand_company_id,
    player_id,
    product_id,
    is_active
  ) values (
    v_company.id,
    v_player_id,
    p_product_id,
    true
  )
  on conflict (player_id, product_id)
  do update set
    brand_company_id = excluded.brand_company_id,
    is_active = true,
    updated_at = timezone('utc', now());

  insert into public.player_product_brands (
    player_id,
    product_id,
    brand_id
  ) values (
    v_player_id,
    p_product_id,
    v_company.id
  )
  on conflict (player_id, product_id)
  do update set
    brand_id = excluded.brand_id,
    updated_at = timezone('utc', now());

  update public.factories
  set
    brand_id = v_company.id,
    updated_at = timezone('utc', now())
  where player_id = v_player_id
    and product_id = p_product_id
    and brand_id <> v_company.id;
  get diagnostics v_factory_sync_count = row_count;

  update public.mines
  set
    brand_id = v_company.id,
    updated_at = timezone('utc', now())
  where player_id = v_player_id
    and product_id = p_product_id
    and brand_id <> v_company.id;
  get diagnostics v_mine_sync_count = row_count;

  update public.production_slots ps
  set
    brand_id = v_company.id,
    updated_at = timezone('utc', now())
  where ps.product_id = p_product_id
    and ps.brand_id <> v_company.id
    and (
      (ps.owner_kind = 'field' and exists (
        select 1
        from public.fields f
        where f.id = ps.owner_id
          and f.player_id = v_player_id
      )) or
      (ps.owner_kind = 'farm' and exists (
        select 1
        from public.farms fa
        where fa.id = ps.owner_id
          and fa.player_id = v_player_id
      ))
    );
  get diagnostics v_slot_sync_count = row_count;

  for v_inventory_row in
    select pi.*
    from public.production_inventory pi
    where pi.inventory_type = 'output'
      and pi.product_id = p_product_id
      and pi.brand_id <> v_company.id
      and (
        (pi.owner_kind = 'factory' and exists (
          select 1
          from public.factories f
          where f.id = pi.owner_id
            and f.player_id = v_player_id
        )) or
        (pi.owner_kind = 'mine' and exists (
          select 1
          from public.mines m
          where m.id = pi.owner_id
            and m.player_id = v_player_id
        )) or
        (pi.owner_kind = 'field' and exists (
          select 1
          from public.fields f
          where f.id = pi.owner_id
            and f.player_id = v_player_id
        )) or
        (pi.owner_kind = 'farm' and exists (
          select 1
          from public.farms fa
          where fa.id = pi.owner_id
            and fa.player_id = v_player_id
        ))
      )
    for update
  loop
    select pi.id, pi.quantity, pi.pending_quantity, pi.cost
    into
      v_target_inventory_id,
      v_existing_quantity,
      v_existing_pending,
      v_existing_cost
    from public.production_inventory pi
    where pi.owner_kind = v_inventory_row.owner_kind
      and pi.owner_id = v_inventory_row.owner_id
      and pi.inventory_type = 'output'
      and pi.product_id = v_inventory_row.product_id
      and pi.quality_level = v_inventory_row.quality_level
      and pi.brand_id = v_company.id
    limit 1;

    if v_target_inventory_id is null then
      update public.production_inventory
      set brand_id = v_company.id
      where id = v_inventory_row.id;

      v_inventory_sync_count := v_inventory_sync_count + 1;
    else
      v_merged_quantity := coalesce(v_existing_quantity, 0) + coalesce(v_inventory_row.quantity, 0);

      update public.production_inventory
      set
        quantity = v_merged_quantity,
        pending_quantity = coalesce(v_existing_pending, 0) + coalesce(v_inventory_row.pending_quantity, 0),
        cost = case
          when v_merged_quantity > 0 then
            (
              (coalesce(v_existing_quantity, 0) * coalesce(v_existing_cost, 0)) +
              (coalesce(v_inventory_row.quantity, 0) * coalesce(v_inventory_row.cost, 0))
            ) / v_merged_quantity
          when coalesce(v_existing_quantity, 0) > 0 then coalesce(v_existing_cost, 0)
          else greatest(coalesce(v_existing_cost, 0), coalesce(v_inventory_row.cost, 0))
        end
      where id = v_target_inventory_id;

      update public.logistics_transfers
      set seller_production_inventory_id = v_target_inventory_id
      where seller_production_inventory_id = v_inventory_row.id;

      update public.logistics_transfers
      set buyer_production_inventory_id = v_target_inventory_id
      where buyer_production_inventory_id = v_inventory_row.id;

      delete from public.production_inventory
      where id = v_inventory_row.id;

      v_inventory_merge_count := v_inventory_merge_count + 1;
    end if;
  end loop;

  return jsonb_build_object(
    'success', true,
    'message', 'Urun marka altina alindi.',
    'product_id', p_product_id,
    'product_name', v_product.urun_adi,
    'brand_company_id', v_company.id,
    'brand_name', v_company.brand_name,
    'synced_factory_count', v_factory_sync_count,
    'synced_mine_count', v_mine_sync_count,
    'synced_slot_count', v_slot_sync_count,
    'synced_output_inventory_count', v_inventory_sync_count,
    'merged_output_inventory_count', v_inventory_merge_count
  );
end;
$$;

grant all on function public.patent_brand_company_product(text) to anon, authenticated, service_role;
