create or replace function public.assign_production_slot_product(
  p_player_id uuid,
  p_production_slot_id uuid,
  p_product_id text,
  p_quality_level integer
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_default_brand uuid := '00000000-0000-0000-0000-000000000000'::uuid;
  v_output_brand_id uuid;
  v_slot public.production_slots%rowtype;
  v_product public.products%rowtype;
  v_owner_player_id uuid;
  v_owner_type_id uuid;
  v_accepted_product_ids text;
  v_product_unit text;
  v_max_quality integer;
  v_duplicate_slot_index integer;
  v_created_input_count integer := 0;
  v_created_output_count integer := 0;
  v_hammadde_1_id text;
  v_hammadde_2_id text;
  v_hammadde_3_id text;
  v_hammadde_1_miktar numeric;
  v_hammadde_2_miktar numeric;
  v_hammadde_3_miktar numeric;
  v_input_quality_level integer;
  v_inventory_id uuid;
  v_output_inventory_id uuid;
begin
  perform pg_advisory_xact_lock(hashtext('field_farm_production_lock'));

  if p_quality_level is null or p_quality_level < 1 or p_quality_level > 5 then
    raise exception 'Kalite seviyesi 1 ile 5 arasinda olmalidir.';
  end if;

  v_input_quality_level := greatest(1, least(coalesce(p_quality_level, 1), 5) - 1);

  select *
  into v_slot
  from public.production_slots
  where id = p_production_slot_id
  for update;

  if not found then
    raise exception 'Uretim slotu bulunamadi.';
  end if;

  if coalesce(v_slot.product_id, '') <> '' and coalesce(v_slot.quality_level, 0) > 0 then
    raise exception 'Bu slotta zaten urun var. Urun degistirme akisini kullan.';
  end if;

  if v_slot.owner_kind not in ('field', 'farm') then
    raise exception 'Gecersiz production slot owner_kind: %', v_slot.owner_kind;
  end if;

  if v_slot.owner_kind = 'field' then
    select f.player_id, f.field_type_id, ft.accepted_product_ids
    into v_owner_player_id, v_owner_type_id, v_accepted_product_ids
    from public.fields f
    join public.field_types ft on ft.id = f.field_type_id
    where f.id = v_slot.owner_id;
  elsif v_slot.owner_kind = 'farm' then
    select fa.player_id, fa.farm_type_id, ft.accepted_product_ids
    into v_owner_player_id, v_owner_type_id, v_accepted_product_ids
    from public.farms fa
    join public.farm_types ft on ft.id = fa.farm_type_id
    where fa.id = v_slot.owner_id;
  end if;

  if v_owner_player_id is null then
    raise exception 'Uretim slotunun bagli oldugu yapi bulunamadi.';
  end if;

  if v_owner_player_id <> p_player_id then
    raise exception 'Bu uretim slotu oyuncuya ait degil.';
  end if;

  select *
  into v_product
  from public.products
  where id = p_product_id;

  if not found then
    raise exception 'Urun bulunamadi: %', p_product_id;
  end if;

  v_product_unit := lower(trim(coalesce(v_product.uretim_birimi, '')));

  if v_slot.owner_kind = 'field'
     and v_product_unit not in ('farm', 'ciftlik') then
    raise exception 'Bu urun ciftlik urunu degil: %', p_product_id;
  end if;

  if v_slot.owner_kind = 'farm'
     and v_product_unit not in ('field', 'tarla') then
    raise exception 'Bu urun tarla urunu degil: %', p_product_id;
  end if;

  if v_accepted_product_ids is null
     or not (p_product_id = any(regexp_split_to_array(v_accepted_product_ids, '\s*,\s*'))) then
    raise exception 'Bu yapi turu bu urunu uretemez: %', p_product_id;
  end if;

  select ps.slot_index
  into v_duplicate_slot_index
  from public.production_slots ps
  where ps.owner_kind = v_slot.owner_kind
    and ps.owner_id = v_slot.owner_id
    and ps.id <> v_slot.id
    and ps.product_id = p_product_id
  limit 1;

  if v_duplicate_slot_index is not null then
    raise exception 'Ayni uretim biriminde ayni urun yalnizca tek slotta uretilebilir. Urun zaten slot % uzerinde ayarli.', v_duplicate_slot_index;
  end if;

  select coalesce(max(max_quality_level), 1)
  into v_max_quality
  from public.player_product_quality_levels
  where player_id = p_player_id
    and product_id = p_product_id;

  if v_max_quality is null then
    v_max_quality := 1;
  end if;

  if p_quality_level > v_max_quality then
    raise exception 'Oyuncu bu urun icin kalite % seviyesine ulasmadi. Mevcut maksimum kalite: %', p_quality_level, v_max_quality;
  end if;

  v_output_brand_id := public.resolve_player_product_brand(
    v_owner_player_id,
    p_product_id
  );

  update public.production_slots
  set product_id = p_product_id,
      quality_level = p_quality_level,
      updated_at = timezone('utc'::text, now()),
      last_production_at = timezone('utc'::text, now())
  where id = p_production_slot_id;

  v_hammadde_1_id := nullif(v_product.hammadde_1_id, '');
  v_hammadde_2_id := nullif(v_product.hammadde_2_id, '');
  v_hammadde_3_id := nullif(v_product.hammadde_3_id, '');
  v_hammadde_1_miktar := coalesce(v_product.hammadde_1_miktar, 0);
  v_hammadde_2_miktar := coalesce(v_product.hammadde_2_miktar, 0);
  v_hammadde_3_miktar := coalesce(v_product.hammadde_3_miktar, 0);

  if v_hammadde_1_id is not null and v_hammadde_1_miktar > 0 then
    select id into v_inventory_id
    from public.production_inventory
    where owner_kind = v_slot.owner_kind
      and owner_id = v_slot.owner_id
      and inventory_type = 'input'
      and product_id = v_hammadde_1_id
      and quality_level = v_input_quality_level
      and brand_id = v_default_brand;

    if not found then
      insert into public.production_inventory (
        owner_kind, owner_id, inventory_type, product_id, quality_level, brand_id, quantity, pending_quantity, cost
      ) values (
        v_slot.owner_kind, v_slot.owner_id, 'input', v_hammadde_1_id, v_input_quality_level, v_default_brand, 0, 0, 0
      );
      v_created_input_count := v_created_input_count + 1;
    end if;
  end if;

  if v_hammadde_2_id is not null and v_hammadde_2_miktar > 0 then
    select id into v_inventory_id
    from public.production_inventory
    where owner_kind = v_slot.owner_kind
      and owner_id = v_slot.owner_id
      and inventory_type = 'input'
      and product_id = v_hammadde_2_id
      and quality_level = v_input_quality_level
      and brand_id = v_default_brand;

    if not found then
      insert into public.production_inventory (
        owner_kind, owner_id, inventory_type, product_id, quality_level, brand_id, quantity, pending_quantity, cost
      ) values (
        v_slot.owner_kind, v_slot.owner_id, 'input', v_hammadde_2_id, v_input_quality_level, v_default_brand, 0, 0, 0
      );
      v_created_input_count := v_created_input_count + 1;
    end if;
  end if;

  if v_hammadde_3_id is not null and v_hammadde_3_miktar > 0 then
    select id into v_inventory_id
    from public.production_inventory
    where owner_kind = v_slot.owner_kind
      and owner_id = v_slot.owner_id
      and inventory_type = 'input'
      and product_id = v_hammadde_3_id
      and quality_level = v_input_quality_level
      and brand_id = v_default_brand;

    if not found then
      insert into public.production_inventory (
        owner_kind, owner_id, inventory_type, product_id, quality_level, brand_id, quantity, pending_quantity, cost
      ) values (
        v_slot.owner_kind, v_slot.owner_id, 'input', v_hammadde_3_id, v_input_quality_level, v_default_brand, 0, 0, 0
      );
      v_created_input_count := v_created_input_count + 1;
    end if;
  end if;

  select id into v_output_inventory_id
  from public.production_inventory
  where owner_kind = v_slot.owner_kind
    and owner_id = v_slot.owner_id
    and inventory_type = 'output'
    and product_id = p_product_id
    and quality_level = p_quality_level
    and brand_id = v_output_brand_id;

  if not found then
    insert into public.production_inventory (
      owner_kind, owner_id, inventory_type, product_id, quality_level, brand_id, quantity, pending_quantity, cost
    ) values (
      v_slot.owner_kind, v_slot.owner_id, 'output', p_product_id, p_quality_level, v_output_brand_id, 0, 0, 0
    ) returning id into v_output_inventory_id;
    v_created_output_count := 1;
  end if;

  return jsonb_build_object(
    'success', true,
    'mode', 'assign',
    'production_slot_id', p_production_slot_id,
    'owner_kind', v_slot.owner_kind,
    'owner_id', v_slot.owner_id,
    'owner_type_id', v_owner_type_id,
    'product_id', p_product_id,
    'product_name', v_product.urun_adi,
    'quality_level', p_quality_level,
    'input_quality_level', v_input_quality_level,
    'player_max_quality_level', v_max_quality,
    'created_input_count', v_created_input_count,
    'created_output_count', v_created_output_count,
    'output_inventory_id', v_output_inventory_id
  );
end;
$function$;

create or replace function public.set_factory_product(
  p_player_id uuid,
  p_factory_id uuid,
  p_product_id text,
  p_quality_level integer
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_default_brand uuid := '00000000-0000-0000-0000-000000000000'::uuid;
  v_output_brand_id uuid;
  v_factory record;
  v_product products%rowtype;
  v_max_quality integer;
  v_effective_quality integer;
  v_input_quality_level integer;
  v_existing_quantity integer := 0;
  v_cleared_pending numeric := 0;
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
  v_input_inventory_id uuid;
begin
  perform pg_advisory_xact_lock(hashtext('factory_production_lock'));

  select f.*, ft.accepted_product_ids
  into v_factory
  from public.factories f
  join public.factory_types ft on ft.id = f.factory_type_id
  where f.id = p_factory_id
  for update;

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
  v_output_brand_id := public.resolve_player_product_brand(
    p_player_id,
    p_product_id
  );

  v_is_same_setting :=
    v_factory.product_id = p_product_id
    and v_factory.quality_level = v_effective_quality;

  if not v_is_same_setting then
    select coalesce(sum(quantity), 0), coalesce(sum(pending_quantity), 0)
    into v_existing_quantity, v_cleared_pending
    from public.production_inventory
    where owner_kind = 'factory'
      and owner_id = p_factory_id
      and inventory_type in ('input', 'output');

    if v_existing_quantity > 0 then
      raise exception 'Bu fabrikada input/output stogu var. Urun degistirmeden once stoklari depoya aktar.';
    end if;

    if coalesce(v_cleared_pending, 0) > 0 then
      update public.production_inventory
      set pending_quantity = 0
      where owner_kind = 'factory'
        and owner_id = p_factory_id
        and inventory_type in ('input', 'output');
    end if;
  else
    v_existing_quantity := 0;
    v_cleared_pending := 0;
  end if;

  update public.factories
  set
    product_id = p_product_id,
    quality_level = v_effective_quality,
    updated_at = timezone('utc'::text, now()),
    last_production_at = timezone('utc'::text, now())
  where id = p_factory_id;

  v_hammadde_1_id := nullif(v_product.hammadde_1_id, '');
  v_hammadde_2_id := nullif(v_product.hammadde_2_id, '');
  v_hammadde_3_id := nullif(v_product.hammadde_3_id, '');
  v_hammadde_1_miktar := coalesce(v_product.hammadde_1_miktar, 0);
  v_hammadde_2_miktar := coalesce(v_product.hammadde_2_miktar, 0);
  v_hammadde_3_miktar := coalesce(v_product.hammadde_3_miktar, 0);

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
    'cleared_pending_quantity', coalesce(v_cleared_pending, 0),
    'created_input_count', v_created_input_count,
    'created_output_count', v_created_output_count,
    'deleted_obsolete_inventory_count', v_deleted_obsolete_count,
    'output_inventory_id', v_output_inventory_id
  );
end;
$function$;

grant execute on function public.assign_production_slot_product(uuid, uuid, text, integer) to anon, authenticated, service_role;
grant execute on function public.set_factory_product(uuid, uuid, text, integer) to anon, authenticated, service_role;
