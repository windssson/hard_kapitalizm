-- ============================================================================
-- Migration: Enhance set_factory_product and set_mine_product to return
-- complete product and inventories snapshots for client-side state patching
-- ============================================================================

-- 1. Enhance set_factory_product to return inventories snapshot
CREATE OR REPLACE FUNCTION public.set_factory_product(
  p_player_id uuid,
  p_factory_id uuid,
  p_product_id text,
  p_quality_level integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_default_brand uuid := '00000000-0000-0000-0000-000000000000'::uuid;
  v_output_brand_id uuid;
  v_factory record;
  v_product products%rowtype;
  v_old_product products%rowtype;
  v_max_quality integer;
  v_effective_quality integer;
  v_input_quality_level integer;
  v_old_input_quality_level integer;
  v_existing_input_quantity integer := 0;
  v_existing_input_pending numeric := 0;
  v_existing_output_quantity integer := 0;
  v_existing_output_pending numeric := 0;
  v_is_same_setting boolean;
  v_created_input_count integer := 0;
  v_created_output_count integer := 0;
  v_deleted_obsolete_count integer := 0;
  v_output_inventory_id uuid;
  v_hammadde_1_id text;
  v_hammadde_2_id text;
  v_hammadde_3_id text;
  v_hammadde_1_miktar numeric;
  v_hammadde_2_miktar numeric;
  v_hammadde_3_miktar numeric;
  v_old_hammadde_1_id text;
  v_old_hammadde_2_id text;
  v_old_hammadde_3_id text;
  v_input_inventory_id uuid;
begin
  perform pg_advisory_xact_lock(hashtext('factory_production_lock'));

  select f.*, ft.accepted_product_ids
  into v_factory
  from public.factories f
  join public.factory_types ft on ft.id = f.factory_type_id
  where f.id = p_factory_id
  for update of f;

  if not found then
    raise exception 'Fabrika bulunamadi.';
  end if;

  if v_factory.player_id <> p_player_id then
    raise exception 'Bu fabrika oyuncuya ait degil.';
  end if;

  select *
  into v_product
  from public.products
  where id = p_product_id;

  if not found then
    raise exception 'Urun bulunamadi: %', p_product_id;
  end if;

  if lower(trim(coalesce(v_product.uretim_birimi, ''))) not in ('factory', 'fabrika') then
    raise exception 'Bu urun fabrika urunu degil: %', p_product_id;
  end if;

  if v_factory.accepted_product_ids is null
     or not (p_product_id = any(regexp_split_to_array(v_factory.accepted_product_ids, '\s*,\s*'))) then
    raise exception 'Bu fabrika turu bu urunu uretemez: %', p_product_id;
  end if;

  select coalesce(max(max_quality_level), 1)
  into v_max_quality
  from public.player_product_quality_levels
  where player_id = p_player_id
    and product_id = p_product_id;

  if v_max_quality is null then
    v_max_quality := 1;
  end if;

  v_effective_quality := greatest(1, least(coalesce(p_quality_level, v_max_quality), v_max_quality, 5));
  v_input_quality_level := greatest(1, v_effective_quality - 1);
  v_output_brand_id := public.resolve_player_product_brand(p_player_id, p_product_id);
  v_hammadde_1_id := nullif(v_product.hammadde_1_id, '');
  v_hammadde_2_id := nullif(v_product.hammadde_2_id, '');
  v_hammadde_3_id := nullif(v_product.hammadde_3_id, '');
  v_hammadde_1_miktar := coalesce(v_product.hammadde_1_miktar, 0);
  v_hammadde_2_miktar := coalesce(v_product.hammadde_2_miktar, 0);
  v_hammadde_3_miktar := coalesce(v_product.hammadde_3_miktar, 0);

  v_is_same_setting :=
    v_factory.product_id = p_product_id
    and v_factory.quality_level = v_effective_quality;

  if not v_is_same_setting and coalesce(v_factory.product_id, '') <> '' then
    select *
    into v_old_product
    from public.products
    where id = v_factory.product_id;

    v_old_input_quality_level := greatest(1, coalesce(v_factory.quality_level, 1) - 1);

    v_old_hammadde_1_id := nullif(v_old_product.hammadde_1_id, '');
    v_old_hammadde_2_id := nullif(v_old_product.hammadde_2_id, '');
    v_old_hammadde_3_id := nullif(v_old_product.hammadde_3_id, '');
  else
    v_old_input_quality_level := greatest(1, coalesce(v_factory.quality_level, 1) - 1);
    v_old_hammadde_1_id := null;
    v_old_hammadde_2_id := null;
    v_old_hammadde_3_id := null;
  end if;

  if not v_is_same_setting then
    select coalesce(sum(quantity), 0), coalesce(sum(pending_quantity), 0)
    into v_existing_output_quantity, v_existing_output_pending
    from public.production_inventory
    where owner_kind = 'factory'
      and owner_id = p_factory_id
      and inventory_type = 'output';

    if v_existing_output_quantity > 0 then
      raise exception 'Bu fabrikada output stogu var. Urun degistirmeden once stoklari depoya aktar.';
    end if;

    select
      coalesce(sum(pi.quantity), 0),
      coalesce(sum(pi.pending_quantity), 0)
    into v_existing_input_quantity, v_existing_input_pending
    from public.production_inventory pi
    where pi.owner_kind = 'factory'
      and pi.owner_id = p_factory_id
      and pi.inventory_type = 'input'
      and (
        (v_old_hammadde_1_id is not null and pi.product_id = v_old_hammadde_1_id and pi.quality_level = v_old_input_quality_level)
        or (v_old_hammadde_2_id is not null and pi.product_id = v_old_hammadde_2_id and pi.quality_level = v_old_input_quality_level)
        or (v_old_hammadde_3_id is not null and pi.product_id = v_old_hammadde_3_id and pi.quality_level = v_old_input_quality_level)
      )
      and not (
        (v_hammadde_1_id is not null and pi.product_id = v_hammadde_1_id and pi.quality_level = v_input_quality_level)
        or (v_hammadde_2_id is not null and pi.product_id = v_hammadde_2_id and pi.quality_level = v_input_quality_level)
        or (v_hammadde_3_id is not null and pi.product_id = v_hammadde_3_id and pi.quality_level = v_input_quality_level)
      );

    if v_existing_input_quantity > 0 then
      raise exception 'Bu fabrikada yeni urunde kullanilmayan input stogu var. Urun degistirmeden once stoklari depoya aktar.';
    end if;

    if coalesce(v_existing_input_pending, 0) > 0 then
      raise exception 'Bu fabrikanin yeni urunde kullanilmayan inputlari icin yoldaki urunler var. Urun degistirmeden once transferlerin tamamlanmasini bekleyin.';
    end if;

    if coalesce(v_existing_output_pending, 0) > 0 then
      update public.production_inventory
      set pending_quantity = 0
      where owner_kind = 'factory'
        and owner_id = p_factory_id
        and inventory_type = 'output';
    end if;
  else
    v_existing_input_quantity := 0;
    v_existing_input_pending := 0;
    v_existing_output_quantity := 0;
    v_existing_output_pending := 0;
  end if;

  update public.factories
  set product_id = p_product_id,
      quality_level = v_effective_quality,
      brand_id = v_output_brand_id,
      updated_at = timezone('utc'::text, now()),
      last_production_at = timezone('utc'::text, now())
  where id = p_factory_id;

  if v_hammadde_1_id is not null and v_hammadde_1_miktar > 0 then
    select id into v_input_inventory_id
    from public.production_inventory
    where owner_kind = 'factory'
      and owner_id = p_factory_id
      and inventory_type = 'input'
      and product_id = v_hammadde_1_id
      and quality_level = v_input_quality_level
      and brand_id = v_default_brand;

    if not found then
      insert into public.production_inventory (
        owner_kind, owner_id, inventory_type, product_id, quality_level, brand_id, quantity, pending_quantity, cost
      ) values (
        'factory', p_factory_id, 'input', v_hammadde_1_id, v_input_quality_level, v_default_brand, 0, 0, 0
      );
      v_created_input_count := v_created_input_count + 1;
    end if;
  end if;

  if v_hammadde_2_id is not null and v_hammadde_2_miktar > 0 then
    select id into v_input_inventory_id
    from public.production_inventory
    where owner_kind = 'factory'
      and owner_id = p_factory_id
      and inventory_type = 'input'
      and product_id = v_hammadde_2_id
      and quality_level = v_input_quality_level
      and brand_id = v_default_brand;

    if not found then
      insert into public.production_inventory (
        owner_kind, owner_id, inventory_type, product_id, quality_level, brand_id, quantity, pending_quantity, cost
      ) values (
        'factory', p_factory_id, 'input', v_hammadde_2_id, v_input_quality_level, v_default_brand, 0, 0, 0
      );
      v_created_input_count := v_created_input_count + 1;
    end if;
  end if;

  if v_hammadde_3_id is not null and v_hammadde_3_miktar > 0 then
    select id into v_input_inventory_id
    from public.production_inventory
    where owner_kind = 'factory'
      and owner_id = p_factory_id
      and inventory_type = 'input'
      and product_id = v_hammadde_3_id
      and quality_level = v_input_quality_level
      and brand_id = v_default_brand;

    if not found then
      insert into public.production_inventory (
        owner_kind, owner_id, inventory_type, product_id, quality_level, brand_id, quantity, pending_quantity, cost
      ) values (
        'factory', p_factory_id, 'input', v_hammadde_3_id, v_input_quality_level, v_default_brand, 0, 0, 0
      );
      v_created_input_count := v_created_input_count + 1;
    end if;
  end if;

  select id into v_output_inventory_id
  from public.production_inventory
  where owner_kind = 'factory'
    and owner_id = p_factory_id
    and inventory_type = 'output'
    and product_id = p_product_id
    and quality_level = v_effective_quality
    and brand_id = v_output_brand_id;

  if not found then
    insert into public.production_inventory (
      owner_kind, owner_id, inventory_type, product_id, quality_level, brand_id, quantity, pending_quantity, cost
    ) values (
      'factory', p_factory_id, 'output', p_product_id, v_effective_quality, v_output_brand_id, 0, 0, 0
    ) returning id into v_output_inventory_id;
    v_created_output_count := 1;
  end if;

  if not v_is_same_setting then
    -- completed transfer references do not block obsolete inventory cleanup
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
          and pi.owner_kind = 'factory'
          and pi.owner_id = p_factory_id
          and coalesce(pi.quantity, 0) = 0
          and coalesce(pi.pending_quantity, 0) = 0
          and not (
            pi.inventory_type = 'output'
            and pi.product_id = p_product_id
            and pi.quality_level = v_effective_quality
            and pi.brand_id = v_output_brand_id
          )
          and not (
            pi.inventory_type = 'input'
            and pi.quality_level = v_input_quality_level
            and pi.brand_id = v_default_brand
            and (
              (v_hammadde_1_id is not null and pi.product_id = v_hammadde_1_id and v_hammadde_1_miktar > 0)
              or (v_hammadde_2_id is not null and pi.product_id = v_hammadde_2_id and v_hammadde_2_miktar > 0)
              or (v_hammadde_3_id is not null and pi.product_id = v_hammadde_3_id and v_hammadde_3_miktar > 0)
            )
          )
      );

    update public.logistics_transfers lt
    set seller_production_inventory_id = null
    where lt.status = 'completed'
      and exists (
        select 1
        from public.production_inventory pi
        where pi.id = lt.seller_production_inventory_id
          and pi.owner_kind = 'factory'
          and pi.owner_id = p_factory_id
          and coalesce(pi.quantity, 0) = 0
          and coalesce(pi.pending_quantity, 0) = 0
          and not (
            pi.inventory_type = 'output'
            and pi.product_id = p_product_id
            and pi.quality_level = v_effective_quality
            and pi.brand_id = v_output_brand_id
          )
          and not (
            pi.inventory_type = 'input'
            and pi.quality_level = v_input_quality_level
            and pi.brand_id = v_default_brand
            and (
              (v_hammadde_1_id is not null and pi.product_id = v_hammadde_1_id and v_hammadde_1_miktar > 0)
              or (v_hammadde_2_id is not null and pi.product_id = v_hammadde_2_id and v_hammadde_2_miktar > 0)
              or (v_hammadde_3_id is not null and pi.product_id = v_hammadde_3_id and v_hammadde_3_miktar > 0)
            )
          )
      );

    update public.logistics_transfers lt
    set buyer_production_inventory_id = null
    where lt.status = 'completed'
      and exists (
        select 1
        from public.production_inventory pi
        where pi.id = lt.buyer_production_inventory_id
          and pi.owner_kind = 'factory'
          and pi.owner_id = p_factory_id
          and coalesce(pi.quantity, 0) = 0
          and coalesce(pi.pending_quantity, 0) = 0
          and not (
            pi.inventory_type = 'output'
            and pi.product_id = p_product_id
            and pi.quality_level = v_effective_quality
            and pi.brand_id = v_output_brand_id
          )
          and not (
            pi.inventory_type = 'input'
            and pi.quality_level = v_input_quality_level
            and pi.brand_id = v_default_brand
            and (
              (v_hammadde_1_id is not null and pi.product_id = v_hammadde_1_id and v_hammadde_1_miktar > 0)
              or (v_hammadde_2_id is not null and pi.product_id = v_hammadde_2_id and v_hammadde_2_miktar > 0)
              or (v_hammadde_3_id is not null and pi.product_id = v_hammadde_3_id and v_hammadde_3_miktar > 0)
            )
          )
      );

    delete from public.production_inventory pi
    where pi.owner_kind = 'factory'
      and pi.owner_id = p_factory_id
      and coalesce(pi.quantity, 0) = 0
      and coalesce(pi.pending_quantity, 0) = 0
      and not (
        pi.inventory_type = 'output'
        and pi.product_id = p_product_id
        and pi.quality_level = v_effective_quality
        and pi.brand_id = v_output_brand_id
      )
      and not (
        pi.inventory_type = 'input'
        and pi.quality_level = v_input_quality_level
        and pi.brand_id = v_default_brand
        and (
          (v_hammadde_1_id is not null and pi.product_id = v_hammadde_1_id and v_hammadde_1_miktar > 0)
          or (v_hammadde_2_id is not null and pi.product_id = v_hammadde_2_id and v_hammadde_2_miktar > 0)
          or (v_hammadde_3_id is not null and pi.product_id = v_hammadde_3_id and v_hammadde_3_miktar > 0)
        )
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
    'factory_id', p_factory_id,
    'factory_type_id', v_factory.factory_type_id,
    'product_id', p_product_id,
    'product_name', v_product.urun_adi,
    'quality_level', v_effective_quality,
    'input_quality_level', v_input_quality_level,
    'player_max_quality_level', v_max_quality,
    'same_setting', v_is_same_setting,
    'existing_input_quantity', coalesce(v_existing_input_quantity, 0),
    'existing_input_pending_quantity', coalesce(v_existing_input_pending, 0),
    'existing_output_quantity', coalesce(v_existing_output_quantity, 0),
    'cleared_output_pending_quantity', coalesce(v_existing_output_pending, 0),
    'created_input_count', v_created_input_count,
    'created_output_count', v_created_output_count,
    'deleted_obsolete_inventory_count', v_deleted_obsolete_count,
    'output_inventory_id', v_output_inventory_id,
    'product', jsonb_build_object(
      'id', v_product.id,
      'urun_adi', v_product.urun_adi,
      'urun_iconu', v_product.urun_iconu,
      'birim_hacim', v_product.birim_hacim,
      'birim_agirlik', v_product.birim_agirlik,
      'hammadde_1_id', v_product.hammadde_1_id,
      'hammadde_1_miktar', v_product.hammadde_1_miktar,
      'hammadde_2_id', v_product.hammadde_2_id,
      'hammadde_2_miktar', v_product.hammadde_2_miktar,
      'hammadde_3_id', v_product.hammadde_3_id,
      'hammadde_3_miktar', v_product.hammadde_3_miktar,
      'uretim_birimi', v_product.uretim_birimi,
      'baz_satis_fiyati', v_product.baz_satis_fiyati,
      'uretim_adedi', v_product.uretim_adedi,
      'satis_adedi', v_product.satis_adedi,
      'en_dusuk_fiyat', v_product.en_dusuk_fiyat,
      'en_yuksek_fiyat', v_product.en_yuksek_fiyat,
      'ortalama_fiyat', v_product.ortalama_fiyat,
      'satici_sayisi', v_product.satici_sayisi,
      'piyasadaki_stok', v_product.piyasadaki_stok,
      'iscilik_maliyeti', v_product.iscilik_maliyeti,
      'created_at', v_product.created_at,
      'kategori', v_product.kategori
    ),
    'inventories', coalesce((
      select jsonb_agg(
        to_jsonb(pi) || jsonb_build_object(
          'product', case when p.id is null then null else to_jsonb(p) end
        )
        order by pi.inventory_type, pi.created_at
      )
      from public.production_inventory pi
      left join public.products p on p.id = pi.product_id
      where pi.owner_kind = 'factory'
        and pi.owner_id = p_factory_id
    ), '[]'::jsonb)
  );
end;
$function$;

-- 2. Enhance set_mine_product to return product and inventories snapshot
CREATE OR REPLACE FUNCTION public.set_mine_product(
  p_player_id uuid,
  p_mine_id uuid,
  p_product_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
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
    'output_row_count', v_output_row_count,
    'product', jsonb_build_object(
      'id', v_product.id,
      'urun_adi', v_product.urun_adi,
      'urun_iconu', v_product.urun_iconu,
      'birim_hacim', v_product.birim_hacim,
      'birim_agirlik', v_product.birim_agirlik,
      'hammadde_1_id', v_product.hammadde_1_id,
      'hammadde_1_miktar', v_product.hammadde_1_miktar,
      'hammadde_2_id', v_product.hammadde_2_id,
      'hammadde_2_miktar', v_product.hammadde_2_miktar,
      'hammadde_3_id', v_product.hammadde_3_id,
      'hammadde_3_miktar', v_product.hammadde_3_miktar,
      'uretim_birimi', v_product.uretim_birimi,
      'baz_satis_fiyati', v_product.baz_satis_fiyati,
      'uretim_adedi', v_product.uretim_adedi,
      'satis_adedi', v_product.satis_adedi,
      'en_dusuk_fiyat', v_product.en_dusuk_fiyat,
      'en_yuksek_fiyat', v_product.en_yuksek_fiyat,
      'ortalama_fiyat', v_product.ortalama_fiyat,
      'satici_sayisi', v_product.satici_sayisi,
      'piyasadaki_stok', v_product.piyasadaki_stok,
      'iscilik_maliyeti', v_product.iscilik_maliyeti,
      'created_at', v_product.created_at,
      'kategori', v_product.kategori
    ),
    'inventories', coalesce((
      select jsonb_agg(
        to_jsonb(pi) || jsonb_build_object(
          'product', case when p.id is null then null else to_jsonb(p) end
        )
        order by pi.inventory_type, pi.created_at
      )
      from public.production_inventory pi
      left join public.products p on p.id = pi.product_id
      where pi.owner_kind = 'mine'
        and pi.owner_id = p_mine_id
    ), '[]'::jsonb)
  );
end;
$function$;
