create or replace function public.set_mine_product(
  p_player_id uuid,
  p_mine_id uuid,
  p_product_id text
) returns jsonb
language plpgsql
as $function$
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
  on conflict (owner_kind, owner_id, inventory_type, product_id, quality_level, brand_id)
  do update set
    cost = case
      when public.production_inventory.quantity = 0
        then excluded.cost
      else public.production_inventory.cost
    end
  returning id into v_output_inventory_id;

  get diagnostics v_output_row_count = row_count;

  if not v_same_setting then
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
$function$;

create or replace function public.process_mine_production_entry(
  p_player_id uuid default auth.uid(),
  p_mine_id uuid default null::uuid,
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
  v_boost_bonus_minutes numeric;
  v_effective_ticks numeric;
  v_row record;
begin
  if p_player_id is null then raise exception 'Oturum acilmamis.'; end if;
  perform pg_advisory_xact_lock(hashtext('mine_production_entry:' || p_player_id::text));
  for v_row in
    select
      m.id as mine_id,
      m.product_id,
      m.quality_level,
      m.brand_id,
      m.output_capacity,
      m.last_production_at,
      p.uretim_adedi,
      out_pi.id as output_inventory_id,
      out_pi.quantity as output_quantity,
      coalesce(out_pi.pending_quantity, 0) as output_pending_quantity
    from public.mines m
    join public.products p on p.id = m.product_id
    join public.production_inventory out_pi
      on out_pi.owner_kind = 'mine'
     and out_pi.owner_id = m.id
     and out_pi.inventory_type = 'output'
     and out_pi.product_id = m.product_id
     and out_pi.quality_level = m.quality_level
     and out_pi.brand_id = m.brand_id
    where m.player_id = p_player_id
      and (p_mine_id is null or m.id = p_mine_id)
      and m.is_active = true
      and m.product_id is not null
      and m.quality_level between 1 and 5
      and coalesce(p.uretim_adedi, 0) > 0
    order by m.created_at, m.id
  loop
    v_ticks := floor(extract(epoch from (v_now - coalesce(v_row.last_production_at, v_now))) / greatest(p_tick_minutes * 60, 60))::integer;
    v_ticks := greatest(least(v_ticks, p_max_ticks), 0);
    if v_ticks <= 0 then continue; end if;
    v_processed_count := v_processed_count + 1;
    v_processed_until := coalesce(v_row.last_production_at, v_now) + make_interval(mins => p_tick_minutes * v_ticks);
    v_available_output_capacity := greatest(v_row.output_capacity - v_row.output_quantity, 0);
    if v_available_output_capacity <= 0 then
      update public.mines set last_production_at = v_processed_until, updated_at = timezone('utc'::text, now()) where id = v_row.mine_id;
      v_skipped_count := v_skipped_count + 1;
      continue;
    end if;
    select coalesce(sum(greatest(extract(epoch from least(coalesce(bb.completed_at, bb.finish_at, v_processed_until), v_processed_until) - greatest(bb.started_at, v_row.last_production_at)) / 60.0, 0) * greatest(coalesce(bb.multiplier, 1) - 1, 0)), 0)
    into v_boost_bonus_minutes
    from public.building_boosts bb
    where bb.player_id = p_player_id and bb.building_kind = 'mine' and bb.entity_id = v_row.mine_id and bb.started_at < v_processed_until and coalesce(bb.completed_at, bb.finish_at, v_processed_until) > v_row.last_production_at;
    v_effective_ticks := greatest(0, (((p_tick_minutes * v_ticks)::numeric + coalesce(v_boost_bonus_minutes, 0)) / greatest(p_tick_minutes, 1)::numeric));
    v_rate_per_tick := coalesce(v_row.uretim_adedi, 0)::numeric / 6;
    v_raw_output := coalesce(v_row.output_pending_quantity, 0) + (v_rate_per_tick * v_effective_ticks);
    v_whole_output := floor(v_raw_output)::integer;
    if v_whole_output <= 0 then
      update public.production_inventory set pending_quantity = v_raw_output where id = v_row.output_inventory_id;
      update public.mines set last_production_at = v_processed_until, updated_at = timezone('utc'::text, now()) where id = v_row.mine_id;
      v_pending_only_count := v_pending_only_count + 1;
      continue;
    end if;
    v_output_to_produce := least(v_whole_output, v_available_output_capacity);
    v_pending_after := case when v_output_to_produce < v_whole_output then 0 else v_raw_output - v_whole_output end;
    update public.production_inventory set quantity = quantity + v_output_to_produce, pending_quantity = v_pending_after where id = v_row.output_inventory_id;
    update public.mines set last_production_at = v_processed_until, updated_at = timezone('utc'::text, now()) where id = v_row.mine_id;
    if v_output_to_produce > 0 then
      perform public.upsert_player_daily_production_stat(p_player_id, 'mine', v_row.mine_id, v_row.product_id, v_output_to_produce, 0);
      v_produced_count := v_produced_count + 1;
      v_total_produced := v_total_produced + v_output_to_produce;
    else
      v_skipped_count := v_skipped_count + 1;
    end if;
  end loop;
  return jsonb_build_object('success', true, 'processed_count', v_processed_count, 'produced_count', v_produced_count, 'pending_only_count', v_pending_only_count, 'skipped_count', v_skipped_count, 'total_produced', v_total_produced);
end;
$function$;
