-- Fix set_mine_product function by replacing the ON CONFLICT insert statement with a SELECT-check insertion to match factory/field/farm patterns and avoid partial unique index mismatch.

CREATE OR REPLACE FUNCTION public.set_mine_product(
    p_player_id uuid,
    p_mine_id uuid,
    p_product_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
declare
  v_mine record;
  v_product record;
  v_accepted_product_ids text;
  v_player_quality integer := 1;
  v_same_setting boolean := false;
  v_old_product_id text;
  v_old_quality_level integer;
  v_old_brand_id uuid;
  v_existing_output_quantity integer := 0;
  v_existing_output_pending numeric := 0;
  v_deleted_obsolete_count integer := 0;
  v_output_inventory_id uuid;
  v_output_cost numeric := 0;
  v_output_row_count integer := 0;
  v_output_brand_id uuid;
begin
  if p_product_id is null or length(trim(p_product_id)) = 0 then
    raise exception 'Urun id bos olamaz.';
  end if;

  select
    m.*,
    mt.accepted_product_ids
  into v_mine
  from public.mines m
  join public.mine_types mt on mt.id = m.mine_type_id
  where m.id = p_mine_id
  for update;

  if not found then
    raise exception 'Maden bulunamadi.';
  end if;

  if v_mine.player_id <> p_player_id then
    raise exception 'Bu maden oyuncuya ait degil.';
  end if;

  select *
  into v_product
  from public.products
  where id = p_product_id;

  if not found then
    raise exception 'Urun bulunamadi.';
  end if;

  if lower(trim(coalesce(v_product.uretim_birimi, ''))) not in ('mine', 'maden') then
    raise exception 'Bu urun maden urunu degil. Uretim birimi: %', v_product.uretim_birimi;
  end if;

  if v_product.baz_satis_fiyati is null or v_product.baz_satis_fiyati < 0 then
    raise exception 'Urunun baz_satis_fiyati degeri gecerli degil.';
  end if;

  v_output_cost := v_product.baz_satis_fiyati * 0.10;
  v_accepted_product_ids := coalesce(v_mine.accepted_product_ids, '');

  if not (
    p_product_id = any (
      string_to_array(
        replace(v_accepted_product_ids, ' ', ''),
        ','
      )
    )
  ) then
    raise exception 'Bu maden turu secilen urunu uretemez.';
  end if;

  select coalesce(max_quality_level, 1)
  into v_player_quality
  from public.player_product_quality_levels
  where player_id = p_player_id
    and product_id = p_product_id;

  if not found then
    v_player_quality := 1;
  end if;

  v_old_product_id := v_mine.product_id;
  v_old_quality_level := v_mine.quality_level;
  v_old_brand_id := v_mine.brand_id;
  v_same_setting :=
    coalesce(v_old_product_id, '') = p_product_id
    and coalesce(v_old_quality_level, 0) = v_player_quality;

  v_output_brand_id := public.resolve_player_product_brand(p_player_id, p_product_id);

  if not v_same_setting and coalesce(v_old_product_id, '') <> '' and coalesce(v_old_quality_level, 0) > 0 then
    select coalesce(quantity, 0), coalesce(pending_quantity, 0)
    into v_existing_output_quantity, v_existing_output_pending
    from public.production_inventory pi
    where pi.owner_kind = 'mine'
      and pi.owner_id = p_mine_id
      and pi.inventory_type = 'output'
      and pi.product_id = v_old_product_id
      and pi.quality_level = v_old_quality_level
      and pi.brand_id = v_old_brand_id
    for update;

    if v_existing_output_quantity > 0 then
      raise exception 'Bu madende output stogu var. Urun degistirmeden once stoklari depoya aktar.';
    end if;

    if coalesce(v_existing_output_pending, 0) > 0 then
      update public.production_inventory
      set pending_quantity = 0
      where owner_kind = 'mine'
        and owner_id = p_mine_id
        and inventory_type = 'output'
        and product_id = v_old_product_id
        and quality_level = v_old_quality_level
        and brand_id = v_old_brand_id;
    end if;
  end if;

  update public.mines
  set
    product_id = p_product_id,
    quality_level = v_player_quality,
    brand_id = v_output_brand_id,
    updated_at = timezone('utc'::text, now()),
    last_production_at = timezone('utc'::text, now())
  where id = p_mine_id;

  select id into v_output_inventory_id
  from public.production_inventory
  where owner_kind = 'mine'
    and owner_id = p_mine_id
    and inventory_type = 'output'
    and product_id = p_product_id
    and quality_level = v_player_quality
    and brand_id = v_output_brand_id;

  if not found then
    insert into public.production_inventory (
      owner_kind,
      owner_id,
      inventory_type,
      product_id,
      quality_level,
      brand_id,
      quantity,
      pending_quantity,
      cost
    )
    values (
      'mine',
      p_mine_id,
      'output',
      p_product_id,
      v_player_quality,
      v_output_brand_id,
      0,
      0,
      v_output_cost
    )
    returning id into v_output_inventory_id;
    v_output_row_count := 1;
  else
    update public.production_inventory
    set cost = case
      when quantity = 0 then v_output_cost
      else cost
    end
    where id = v_output_inventory_id;
    v_output_row_count := 1;
  end if;

  if not v_same_setting then
    -- completed transfer references do not block obsolete mine inventory cleanup
    update public.logistics_transfer_items lti
    set target_production_inventory_id = null
    from public.logistics_transfers lt
    where lt.id = lti.transfer_id
      and lt.status = 'completed'
      and lti.status = 'completed'
      and exists (
        select 1
        from public.production_inventory pi
        where pi.id = lti.target_production_inventory_id
          and pi.owner_kind = 'mine'
          and pi.owner_id = p_mine_id
          and pi.inventory_type = 'output'
          and coalesce(pi.quantity, 0) = 0
          and coalesce(pi.pending_quantity, 0) = 0
          and not (
            pi.product_id = p_product_id
            and pi.quality_level = v_player_quality
            and pi.brand_id = v_output_brand_id
          )
      );

    update public.logistics_transfers lt
    set seller_production_inventory_id = null
    where lt.status = 'completed'
      and exists (
        select 1
        from public.production_inventory pi
        where pi.id = lt.seller_production_inventory_id
          and pi.owner_kind = 'mine'
          and pi.owner_id = p_mine_id
          and pi.inventory_type = 'output'
          and coalesce(pi.quantity, 0) = 0
          and coalesce(pi.pending_quantity, 0) = 0
          and not (
            pi.product_id = p_product_id
            and pi.quality_level = v_player_quality
            and pi.brand_id = v_output_brand_id
          )
      );

    update public.logistics_transfers lt
    set buyer_production_inventory_id = null
    where lt.status = 'completed'
      and exists (
        select 1
        from public.production_inventory pi
        where pi.id = lt.buyer_production_inventory_id
          and pi.owner_kind = 'mine'
          and pi.owner_id = p_mine_id
          and pi.inventory_type = 'output'
          and coalesce(pi.quantity, 0) = 0
          and coalesce(pi.pending_quantity, 0) = 0
          and not (
            pi.product_id = p_product_id
            and pi.quality_level = v_player_quality
            and pi.brand_id = v_output_brand_id
          )
      );

    delete from public.production_inventory pi
    where pi.owner_kind = 'mine'
      and pi.owner_id = p_mine_id
      and pi.inventory_type = 'output'
      and coalesce(pi.quantity, 0) = 0
      and coalesce(pi.pending_quantity, 0) = 0
      and not (
        pi.product_id = p_product_id
        and pi.quality_level = v_player_quality
        and pi.brand_id = v_output_brand_id
      )
      and not exists (
        select 1
        from public.logistics_transfers lt
        where lt.seller_production_inventory_id = pi.id
           or lt.buyer_production_inventory_id = pi.id
      );

    get diagnostics v_deleted_obsolete_count = row_count;
  end if;

  return jsonb_build_object(
    'success', true,
    'mine_id', p_mine_id,
    'mine_type_id', v_mine.mine_type_id,
    'product_id', p_product_id,
    'product_name', v_product.urun_adi,
    'quality_level', v_player_quality,
    'player_max_quality_level', v_player_quality,
    'same_setting', v_same_setting,
    'cleared_pending_quantity', coalesce(v_existing_output_pending, 0),
    'deleted_obsolete_inventory_count', v_deleted_obsolete_count,
    'baz_satis_fiyati', v_product.baz_satis_fiyati,
    'output_cost', v_output_cost,
    'output_inventory_id', v_output_inventory_id,
    'output_row_count', v_output_row_count
  );
end;
$$;
