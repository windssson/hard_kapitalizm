create or replace function public.set_factory_product(
  p_player_id uuid,
  p_factory_id uuid,
  p_product_id text,
  p_quality_level integer
) returns jsonb
language plpgsql
as $function$
declare
  v_default_brand uuid := '00000000-0000-0000-0000-000000000000'::uuid;
  v_output_brand_id uuid;
  v_factory record;
  v_product products%rowtype;
  v_max_quality integer;
  v_effective_quality integer;
  v_input_quality_level integer;
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
  v_output_brand_id := public.resolve_player_product_brand(p_player_id, p_product_id);

  v_is_same_setting :=
    v_factory.product_id = p_product_id
    and v_factory.quality_level = v_effective_quality;

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

    select coalesce(sum(quantity), 0), coalesce(sum(pending_quantity), 0)
    into v_existing_input_quantity, v_existing_input_pending
    from public.production_inventory
    where owner_kind = 'factory'
      and owner_id = p_factory_id
      and inventory_type = 'input';

    if v_existing_input_quantity > 0 then
      raise exception 'Bu fabrikada input stogu var. Urun degistirmeden once stoklari depoya aktar.';
    end if;

    if coalesce(v_existing_input_pending, 0) > 0 then
      raise exception 'Bu fabrikanin inputlari icin yoldaki urunler var. Urun degistirmeden once transferlerin tamamlanmasini bekleyin.';
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
    'existing_input_quantity', coalesce(v_existing_input_quantity, 0),
    'existing_input_pending_quantity', coalesce(v_existing_input_pending, 0),
    'existing_output_quantity', coalesce(v_existing_output_quantity, 0),
    'cleared_output_pending_quantity', coalesce(v_existing_output_pending, 0),
    'created_input_count', v_created_input_count,
    'created_output_count', v_created_output_count,
    'deleted_obsolete_inventory_count', v_deleted_obsolete_count,
    'output_inventory_id', v_output_inventory_id
  );
end;
$function$;

create or replace function public.process_factory_production_entry(
  p_player_id uuid default auth.uid(),
  p_factory_id uuid default null::uuid,
  p_tick_minutes integer default 10,
  p_max_ticks integer default 144
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_now timestamptz := timezone('utc'::text, now());
  v_processed_count integer := 0;
  v_produced_count integer := 0;
  v_pending_only_count integer := 0;
  v_skipped_count integer := 0;
  v_total_produced integer := 0;
  v_ticks integer;
  v_processed_until timestamptz;
  v_rate_per_tick numeric;
  v_raw_output numeric;
  v_whole_output integer;
  v_available_output_capacity integer;
  v_output_to_produce integer;
  v_pending_after numeric;
  v_h1_required integer;
  v_h2_required integer;
  v_h3_required integer;
  v_h1_quantity integer;
  v_h2_quantity integer;
  v_h3_quantity integer;
  v_h1_cost numeric;
  v_h2_cost numeric;
  v_h3_cost numeric;
  v_total_input_cost numeric;
  v_output_cost_after numeric;
  v_output_quantity_after integer;
  v_boost_bonus_minutes numeric;
  v_effective_ticks numeric;
  v_row record;
begin
  if p_player_id is null then raise exception 'Oturum acilmamis.'; end if;
  perform pg_advisory_xact_lock(hashtext('factory_production_entry:' || p_player_id::text));

  for v_row in
    select
      f.id as factory_id,
      f.product_id,
      f.quality_level,
      f.brand_id,
      f.output_capacity,
      f.last_production_at,
      p.uretim_adedi,
      nullif(p.hammadde_1_id, '') as h1_id,
      coalesce(p.hammadde_1_miktar, 0) as h1_per_unit,
      nullif(p.hammadde_2_id, '') as h2_id,
      coalesce(p.hammadde_2_miktar, 0) as h2_per_unit,
      nullif(p.hammadde_3_id, '') as h3_id,
      coalesce(p.hammadde_3_miktar, 0) as h3_per_unit,
      out_pi.id as output_inventory_id,
      out_pi.quantity as output_quantity,
      coalesce(out_pi.pending_quantity, 0) as output_pending_quantity,
      coalesce(out_pi.cost, 0) as output_cost
    from public.factories f
    join public.products p on p.id = f.product_id
    join public.production_inventory out_pi
      on out_pi.owner_kind = 'factory'
     and out_pi.owner_id = f.id
     and out_pi.inventory_type = 'output'
     and out_pi.product_id = f.product_id
     and out_pi.quality_level = f.quality_level
     and out_pi.brand_id = f.brand_id
    where f.player_id = p_player_id
      and (p_factory_id is null or f.id = p_factory_id)
      and f.is_active = true
      and f.product_id is not null
      and f.quality_level between 1 and 5
      and coalesce(p.uretim_adedi, 0) > 0
    order by f.created_at, f.id
  loop
    v_ticks := floor(extract(epoch from (v_now - coalesce(v_row.last_production_at, v_now))) / greatest(p_tick_minutes * 60, 60))::integer;
    v_ticks := greatest(least(v_ticks, p_max_ticks), 0);
    if v_ticks <= 0 then continue; end if;
    v_processed_count := v_processed_count + 1;
    v_processed_until := coalesce(v_row.last_production_at, v_now) + make_interval(mins => p_tick_minutes * v_ticks);
    v_available_output_capacity := greatest(v_row.output_capacity - v_row.output_quantity, 0);
    if v_available_output_capacity <= 0 then
      update public.factories set last_production_at = v_processed_until, updated_at = timezone('utc'::text, now()) where id = v_row.factory_id;
      v_skipped_count := v_skipped_count + 1;
      continue;
    end if;
    select coalesce(sum(greatest(extract(epoch from least(coalesce(bb.completed_at, bb.finish_at, v_processed_until), v_processed_until) - greatest(bb.started_at, v_row.last_production_at)) / 60.0,0) * greatest(coalesce(bb.multiplier, 1) - 1, 0)),0)
    into v_boost_bonus_minutes
    from public.building_boosts bb
    where bb.player_id = p_player_id and bb.building_kind = 'factory' and bb.entity_id = v_row.factory_id and bb.started_at < v_processed_until and coalesce(bb.completed_at, bb.finish_at, v_processed_until) > v_row.last_production_at;
    v_effective_ticks := greatest(0, (((p_tick_minutes * v_ticks)::numeric + coalesce(v_boost_bonus_minutes, 0)) / greatest(p_tick_minutes, 1)::numeric));
    v_rate_per_tick := coalesce(v_row.uretim_adedi, 0)::numeric / 6;
    v_raw_output := coalesce(v_row.output_pending_quantity, 0) + (v_rate_per_tick * v_effective_ticks);
    v_whole_output := floor(v_raw_output)::integer;
    if v_whole_output <= 0 then
      update public.production_inventory set pending_quantity = v_raw_output where id = v_row.output_inventory_id;
      update public.factories set last_production_at = v_processed_until, updated_at = timezone('utc'::text, now()) where id = v_row.factory_id;
      v_pending_only_count := v_pending_only_count + 1;
      continue;
    end if;
    v_output_to_produce := least(v_whole_output, v_available_output_capacity);
    if v_output_to_produce <= 0 then
      update public.factories set last_production_at = v_processed_until, updated_at = timezone('utc'::text, now()) where id = v_row.factory_id;
      v_skipped_count := v_skipped_count + 1;
      continue;
    end if;
    v_h1_required := case when v_row.h1_id is not null and v_row.h1_per_unit > 0 then ceil(v_output_to_produce * v_row.h1_per_unit)::integer else 0 end;
    v_h2_required := case when v_row.h2_id is not null and v_row.h2_per_unit > 0 then ceil(v_output_to_produce * v_row.h2_per_unit)::integer else 0 end;
    v_h3_required := case when v_row.h3_id is not null and v_row.h3_per_unit > 0 then ceil(v_output_to_produce * v_row.h3_per_unit)::integer else 0 end;
    select coalesce(quantity, 0), coalesce(cost, 0) into v_h1_quantity, v_h1_cost from public.production_inventory where owner_kind = 'factory' and owner_id = v_row.factory_id and inventory_type = 'input' and product_id = v_row.h1_id and quality_level = greatest(v_row.quality_level - 1, 1) for update;
    select coalesce(quantity, 0), coalesce(cost, 0) into v_h2_quantity, v_h2_cost from public.production_inventory where owner_kind = 'factory' and owner_id = v_row.factory_id and inventory_type = 'input' and product_id = v_row.h2_id and quality_level = greatest(v_row.quality_level - 1, 1) for update;
    select coalesce(quantity, 0), coalesce(cost, 0) into v_h3_quantity, v_h3_cost from public.production_inventory where owner_kind = 'factory' and owner_id = v_row.factory_id and inventory_type = 'input' and product_id = v_row.h3_id and quality_level = greatest(v_row.quality_level - 1, 1) for update;
    if (v_h1_required > 0 and coalesce(v_h1_quantity, 0) < v_h1_required) or (v_h2_required > 0 and coalesce(v_h2_quantity, 0) < v_h2_required) or (v_h3_required > 0 and coalesce(v_h3_quantity, 0) < v_h3_required) then
      update public.factories set last_production_at = v_processed_until, updated_at = timezone('utc'::text, now()) where id = v_row.factory_id;
      v_skipped_count := v_skipped_count + 1;
      continue;
    end if;
    if v_h1_required > 0 then update public.production_inventory set quantity = quantity - v_h1_required where owner_kind = 'factory' and owner_id = v_row.factory_id and inventory_type = 'input' and product_id = v_row.h1_id and quality_level = greatest(v_row.quality_level - 1, 1); end if;
    if v_h2_required > 0 then update public.production_inventory set quantity = quantity - v_h2_required where owner_kind = 'factory' and owner_id = v_row.factory_id and inventory_type = 'input' and product_id = v_row.h2_id and quality_level = greatest(v_row.quality_level - 1, 1); end if;
    if v_h3_required > 0 then update public.production_inventory set quantity = quantity - v_h3_required where owner_kind = 'factory' and owner_id = v_row.factory_id and inventory_type = 'input' and product_id = v_row.h3_id and quality_level = greatest(v_row.quality_level - 1, 1); end if;
    v_total_input_cost := (v_h1_required * coalesce(v_h1_cost, 0)) + (v_h2_required * coalesce(v_h2_cost, 0)) + (v_h3_required * coalesce(v_h3_cost, 0));
    v_pending_after := case when v_output_to_produce < v_whole_output then 0 else v_raw_output - v_whole_output end;
    v_output_quantity_after := v_row.output_quantity + v_output_to_produce;
    v_output_cost_after := case when v_output_quantity_after > 0 and v_output_to_produce > 0 then (((v_row.output_quantity * coalesce(v_row.output_cost, 0)) + v_total_input_cost) / v_output_quantity_after) else v_row.output_cost end;
    update public.production_inventory set quantity = v_output_quantity_after, pending_quantity = v_pending_after, cost = v_output_cost_after where id = v_row.output_inventory_id;
    update public.factories set last_production_at = v_processed_until, updated_at = timezone('utc'::text, now()) where id = v_row.factory_id;
    if v_output_to_produce > 0 then perform public.upsert_player_daily_production_stat(p_player_id, 'factory', v_row.factory_id, v_row.product_id, v_output_to_produce, v_total_input_cost); end if;
    v_produced_count := v_produced_count + 1;
    v_total_produced := v_total_produced + v_output_to_produce;
  end loop;

  return jsonb_build_object('success', true, 'processed_count', v_processed_count, 'produced_count', v_produced_count, 'pending_only_count', v_pending_only_count, 'skipped_count', v_skipped_count, 'total_produced', v_total_produced);
end;
$function$;
