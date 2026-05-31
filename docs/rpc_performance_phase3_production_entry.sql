alter table public.factories
  add column if not exists last_production_at timestamptz;

alter table public.mines
  add column if not exists last_production_at timestamptz;

alter table public.production_slots
  add column if not exists last_production_at timestamptz;

update public.factories
set last_production_at = coalesce(last_production_at, updated_at, created_at, timezone('utc'::text, now()))
where last_production_at is null;

update public.mines
set last_production_at = coalesce(last_production_at, updated_at, created_at, timezone('utc'::text, now()))
where last_production_at is null;

update public.production_slots
set last_production_at = coalesce(last_production_at, updated_at, created_at, timezone('utc'::text, now()))
where last_production_at is null;

alter table public.factories
  alter column last_production_at set default timezone('utc'::text, now()),
  alter column last_production_at set not null;

alter table public.mines
  alter column last_production_at set default timezone('utc'::text, now()),
  alter column last_production_at set not null;

alter table public.production_slots
  alter column last_production_at set default timezone('utc'::text, now()),
  alter column last_production_at set not null;

create or replace function public.process_factory_production_entry(
  p_player_id uuid default auth.uid(),
  p_factory_id uuid default null,
  p_tick_minutes integer default 10,
  p_max_ticks integer default 144
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
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
  v_row record;
begin
  if p_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  perform pg_advisory_xact_lock(hashtext('factory_production_entry:' || p_player_id::text));

  for v_row in
    select
      f.id as factory_id,
      f.product_id,
      f.quality_level,
      f.output_capacity,
      coalesce(f.boost_multiplier, 1) as boost_multiplier,
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
    join public.products p
      on p.id = f.product_id
    join public.production_inventory out_pi
      on out_pi.owner_kind = 'factory'
     and out_pi.owner_id = f.id
     and out_pi.inventory_type = 'output'
     and out_pi.product_id = f.product_id
     and out_pi.quality_level = f.quality_level
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

    if v_ticks <= 0 then
      continue;
    end if;

    v_processed_count := v_processed_count + 1;
    v_processed_until := coalesce(v_row.last_production_at, v_now) + make_interval(mins => p_tick_minutes * v_ticks);
    v_available_output_capacity := greatest(v_row.output_capacity - v_row.output_quantity, 0);

    if v_available_output_capacity <= 0 then
      update public.factories
      set last_production_at = v_processed_until,
          updated_at = timezone('utc'::text, now())
      where id = v_row.factory_id;

      v_skipped_count := v_skipped_count + 1;
      continue;
    end if;

    v_rate_per_tick := (coalesce(v_row.uretim_adedi, 0)::numeric / 6) * coalesce(v_row.boost_multiplier, 1);
    v_raw_output := coalesce(v_row.output_pending_quantity, 0) + (v_rate_per_tick * v_ticks);
    v_whole_output := floor(v_raw_output)::integer;

    if v_whole_output <= 0 then
      update public.production_inventory
      set pending_quantity = v_raw_output
      where id = v_row.output_inventory_id;

      update public.factories
      set last_production_at = v_processed_until,
          updated_at = timezone('utc'::text, now())
      where id = v_row.factory_id;

      v_pending_only_count := v_pending_only_count + 1;
      continue;
    end if;

    v_output_to_produce := least(v_whole_output, v_available_output_capacity);

    if v_output_to_produce <= 0 then
      update public.factories
      set last_production_at = v_processed_until,
          updated_at = timezone('utc'::text, now())
      where id = v_row.factory_id;

      v_skipped_count := v_skipped_count + 1;
      continue;
    end if;

    v_h1_required := case when v_row.h1_id is not null and v_row.h1_per_unit > 0 then ceil(v_output_to_produce * v_row.h1_per_unit)::integer else 0 end;
    v_h2_required := case when v_row.h2_id is not null and v_row.h2_per_unit > 0 then ceil(v_output_to_produce * v_row.h2_per_unit)::integer else 0 end;
    v_h3_required := case when v_row.h3_id is not null and v_row.h3_per_unit > 0 then ceil(v_output_to_produce * v_row.h3_per_unit)::integer else 0 end;

    select coalesce(quantity, 0), coalesce(cost, 0)
    into v_h1_quantity, v_h1_cost
    from public.production_inventory
    where owner_kind = 'factory'
      and owner_id = v_row.factory_id
      and inventory_type = 'input'
      and product_id = v_row.h1_id
      and quality_level = v_row.quality_level
    for update;

    select coalesce(quantity, 0), coalesce(cost, 0)
    into v_h2_quantity, v_h2_cost
    from public.production_inventory
    where owner_kind = 'factory'
      and owner_id = v_row.factory_id
      and inventory_type = 'input'
      and product_id = v_row.h2_id
      and quality_level = v_row.quality_level
    for update;

    select coalesce(quantity, 0), coalesce(cost, 0)
    into v_h3_quantity, v_h3_cost
    from public.production_inventory
    where owner_kind = 'factory'
      and owner_id = v_row.factory_id
      and inventory_type = 'input'
      and product_id = v_row.h3_id
      and quality_level = v_row.quality_level
    for update;

    if (v_h1_required > 0 and coalesce(v_h1_quantity, 0) < v_h1_required)
       or (v_h2_required > 0 and coalesce(v_h2_quantity, 0) < v_h2_required)
       or (v_h3_required > 0 and coalesce(v_h3_quantity, 0) < v_h3_required) then
      update public.factories
      set last_production_at = v_processed_until,
          updated_at = timezone('utc'::text, now())
      where id = v_row.factory_id;

      v_skipped_count := v_skipped_count + 1;
      continue;
    end if;

    if v_h1_required > 0 then
      update public.production_inventory
      set quantity = quantity - v_h1_required
      where owner_kind = 'factory'
        and owner_id = v_row.factory_id
        and inventory_type = 'input'
        and product_id = v_row.h1_id
        and quality_level = v_row.quality_level;
    end if;

    if v_h2_required > 0 then
      update public.production_inventory
      set quantity = quantity - v_h2_required
      where owner_kind = 'factory'
        and owner_id = v_row.factory_id
        and inventory_type = 'input'
        and product_id = v_row.h2_id
        and quality_level = v_row.quality_level;
    end if;

    if v_h3_required > 0 then
      update public.production_inventory
      set quantity = quantity - v_h3_required
      where owner_kind = 'factory'
        and owner_id = v_row.factory_id
        and inventory_type = 'input'
        and product_id = v_row.h3_id
        and quality_level = v_row.quality_level;
    end if;

    v_total_input_cost := (v_h1_required * coalesce(v_h1_cost, 0))
      + (v_h2_required * coalesce(v_h2_cost, 0))
      + (v_h3_required * coalesce(v_h3_cost, 0));

    v_pending_after := case
      when v_output_to_produce < v_whole_output then 0
      else v_raw_output - v_whole_output
    end;

    v_output_quantity_after := v_row.output_quantity + v_output_to_produce;
    v_output_cost_after := case
      when v_output_quantity_after > 0 and v_output_to_produce > 0 then
        ((v_row.output_quantity * coalesce(v_row.output_cost, 0))
        + v_total_input_cost)
        / v_output_quantity_after
      else v_row.output_cost
    end;

    update public.production_inventory
    set quantity = v_output_quantity_after,
        pending_quantity = v_pending_after,
        cost = v_output_cost_after
    where id = v_row.output_inventory_id;

    update public.factories
    set last_production_at = v_processed_until,
        updated_at = timezone('utc'::text, now())
    where id = v_row.factory_id;

    v_produced_count := v_produced_count + 1;
    v_total_produced := v_total_produced + v_output_to_produce;
  end loop;

  return jsonb_build_object(
    'success', true,
    'processed_count', v_processed_count,
    'produced_count', v_produced_count,
    'pending_only_count', v_pending_only_count,
    'skipped_count', v_skipped_count,
    'total_produced', v_total_produced
  );
end;
$$;

create or replace function public.process_field_farm_production_entry(
  p_player_id uuid default auth.uid(),
  p_owner_kind text default null,
  p_owner_id uuid default null,
  p_tick_minutes integer default 10,
  p_max_ticks integer default 144
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
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
  v_owner_total_output integer;
  v_available_output_capacity integer;
  v_tentative_output integer;
  v_actual_output integer;
  v_pending_after numeric;
  v_h1_max integer;
  v_h2_max integer;
  v_h3_max integer;
  v_h1_required integer;
  v_h2_required integer;
  v_h3_required integer;
  v_h1_cost numeric;
  v_h2_cost numeric;
  v_h3_cost numeric;
  v_total_input_cost numeric;
  v_total_production_cost numeric;
  v_output_cost_after numeric;
  v_output_quantity_after integer;
  v_row record;
begin
  if p_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  perform pg_advisory_xact_lock(hashtext('field_farm_production_entry:' || p_player_id::text));

  for v_row in
    select
      ps.id as production_slot_id,
      ps.owner_kind,
      ps.owner_id,
      ps.slot_index,
      ps.product_id,
      ps.quality_level,
      coalesce(ps.boost_multiplier, 1) as boost_multiplier,
      ps.last_production_at,
      case
        when ps.owner_kind = 'field' then f.output_capacity
        when ps.owner_kind = 'farm' then fa.output_capacity
      end as owner_output_capacity,
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
    from public.production_slots ps
    join public.products p on p.id = ps.product_id
    left join public.fields f on ps.owner_kind = 'field' and f.id = ps.owner_id
    left join public.farms fa on ps.owner_kind = 'farm' and fa.id = ps.owner_id
    join public.production_inventory out_pi
      on out_pi.owner_kind = ps.owner_kind
     and out_pi.owner_id = ps.owner_id
     and out_pi.inventory_type = 'output'
     and out_pi.product_id = ps.product_id
     and out_pi.quality_level = ps.quality_level
    where ps.is_active = true
      and ps.owner_kind in ('field', 'farm')
      and ps.product_id is not null
      and ps.quality_level between 1 and 5
      and coalesce(p.uretim_adedi, 0) > 0
      and (
        (ps.owner_kind = 'field' and f.player_id = p_player_id and f.is_active = true)
        or
        (ps.owner_kind = 'farm' and fa.player_id = p_player_id and fa.is_active = true)
      )
      and (p_owner_kind is null or ps.owner_kind = p_owner_kind)
      and (p_owner_id is null or ps.owner_id = p_owner_id)
    order by ps.owner_kind, ps.owner_id, ps.slot_index, ps.id
  loop
    v_ticks := floor(extract(epoch from (v_now - coalesce(v_row.last_production_at, v_now))) / greatest(p_tick_minutes * 60, 60))::integer;
    v_ticks := greatest(least(v_ticks, p_max_ticks), 0);

    if v_ticks <= 0 then
      continue;
    end if;

    v_processed_count := v_processed_count + 1;
    v_processed_until := coalesce(v_row.last_production_at, v_now) + make_interval(mins => p_tick_minutes * v_ticks);

    select coalesce(sum(quantity), 0)::integer
    into v_owner_total_output
    from public.production_inventory
    where owner_kind = v_row.owner_kind
      and owner_id = v_row.owner_id
      and inventory_type = 'output';

    v_available_output_capacity := greatest(coalesce(v_row.owner_output_capacity, 0) - coalesce(v_owner_total_output, 0), 0);

    if v_available_output_capacity <= 0 then
      update public.production_slots
      set last_production_at = v_processed_until,
          updated_at = timezone('utc'::text, now())
      where id = v_row.production_slot_id;

      v_skipped_count := v_skipped_count + 1;
      continue;
    end if;

    v_rate_per_tick := (coalesce(v_row.uretim_adedi, 0)::numeric / 6) * coalesce(v_row.boost_multiplier, 1);
    v_raw_output := coalesce(v_row.output_pending_quantity, 0) + (v_rate_per_tick * v_ticks);
    v_whole_output := floor(v_raw_output)::integer;

    if v_whole_output <= 0 then
      update public.production_inventory
      set pending_quantity = v_raw_output
      where id = v_row.output_inventory_id;

      update public.production_slots
      set last_production_at = v_processed_until,
          updated_at = timezone('utc'::text, now())
      where id = v_row.production_slot_id;

      v_pending_only_count := v_pending_only_count + 1;
      continue;
    end if;

    v_tentative_output := least(v_whole_output, v_available_output_capacity);

    select coalesce(quantity, 0), coalesce(cost, 0)
    into v_h1_max, v_h1_cost
    from public.production_inventory
    where owner_kind = v_row.owner_kind
      and owner_id = v_row.owner_id
      and inventory_type = 'input'
      and product_id = v_row.h1_id
      and quality_level = 1
    for update;

    select coalesce(quantity, 0), coalesce(cost, 0)
    into v_h2_max, v_h2_cost
    from public.production_inventory
    where owner_kind = v_row.owner_kind
      and owner_id = v_row.owner_id
      and inventory_type = 'input'
      and product_id = v_row.h2_id
      and quality_level = 1
    for update;

    select coalesce(quantity, 0), coalesce(cost, 0)
    into v_h3_max, v_h3_cost
    from public.production_inventory
    where owner_kind = v_row.owner_kind
      and owner_id = v_row.owner_id
      and inventory_type = 'input'
      and product_id = v_row.h3_id
      and quality_level = 1
    for update;

    v_h1_max := case when v_row.h1_id is not null and v_row.h1_per_unit > 0 then floor(coalesce(v_h1_max, 0) / v_row.h1_per_unit)::integer else v_tentative_output end;
    v_h2_max := case when v_row.h2_id is not null and v_row.h2_per_unit > 0 then floor(coalesce(v_h2_max, 0) / v_row.h2_per_unit)::integer else v_tentative_output end;
    v_h3_max := case when v_row.h3_id is not null and v_row.h3_per_unit > 0 then floor(coalesce(v_h3_max, 0) / v_row.h3_per_unit)::integer else v_tentative_output end;

    v_actual_output := greatest(least(v_tentative_output, v_h1_max, v_h2_max, v_h3_max), 0);

    if v_actual_output <= 0 then
      update public.production_slots
      set last_production_at = v_processed_until,
          updated_at = timezone('utc'::text, now())
      where id = v_row.production_slot_id;

      v_skipped_count := v_skipped_count + 1;
      continue;
    end if;

    v_h1_required := case when v_row.h1_id is not null and v_row.h1_per_unit > 0 then ceil(v_actual_output * v_row.h1_per_unit)::integer else 0 end;
    v_h2_required := case when v_row.h2_id is not null and v_row.h2_per_unit > 0 then ceil(v_actual_output * v_row.h2_per_unit)::integer else 0 end;
    v_h3_required := case when v_row.h3_id is not null and v_row.h3_per_unit > 0 then ceil(v_actual_output * v_row.h3_per_unit)::integer else 0 end;

    if v_h1_required > 0 then
      update public.production_inventory
      set quantity = quantity - v_h1_required
      where owner_kind = v_row.owner_kind
        and owner_id = v_row.owner_id
        and inventory_type = 'input'
        and product_id = v_row.h1_id
        and quality_level = 1;
    end if;

    if v_h2_required > 0 then
      update public.production_inventory
      set quantity = quantity - v_h2_required
      where owner_kind = v_row.owner_kind
        and owner_id = v_row.owner_id
        and inventory_type = 'input'
        and product_id = v_row.h2_id
        and quality_level = 1;
    end if;

    if v_h3_required > 0 then
      update public.production_inventory
      set quantity = quantity - v_h3_required
      where owner_kind = v_row.owner_kind
        and owner_id = v_row.owner_id
        and inventory_type = 'input'
        and product_id = v_row.h3_id
        and quality_level = 1;
    end if;

    v_total_input_cost := (v_h1_required * coalesce(v_h1_cost, 0))
      + (v_h2_required * coalesce(v_h2_cost, 0))
      + (v_h3_required * coalesce(v_h3_cost, 0));
    v_total_production_cost := v_total_input_cost * 1.05;

    v_pending_after := case
      when v_actual_output < v_whole_output then 0
      else v_raw_output - v_whole_output
    end;

    v_output_quantity_after := v_row.output_quantity + v_actual_output;
    v_output_cost_after := case
      when v_output_quantity_after > 0 then
        (((v_row.output_quantity * coalesce(v_row.output_cost, 0)) + v_total_production_cost) / v_output_quantity_after)
      else v_row.output_cost
    end;

    update public.production_inventory
    set quantity = v_output_quantity_after,
        pending_quantity = v_pending_after,
        cost = v_output_cost_after
    where id = v_row.output_inventory_id;

    update public.production_slots
    set last_production_at = v_processed_until,
        updated_at = timezone('utc'::text, now())
    where id = v_row.production_slot_id;

    v_produced_count := v_produced_count + 1;
    v_total_produced := v_total_produced + v_actual_output;
  end loop;

  return jsonb_build_object(
    'success', true,
    'processed_count', v_processed_count,
    'produced_count', v_produced_count,
    'pending_only_count', v_pending_only_count,
    'skipped_count', v_skipped_count,
    'total_produced', v_total_produced
  );
end;
$$;

create or replace function public.process_mine_production_entry(
  p_player_id uuid default auth.uid(),
  p_mine_id uuid default null,
  p_tick_minutes integer default 10,
  p_max_ticks integer default 144
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
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
  v_row record;
begin
  if p_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  perform pg_advisory_xact_lock(hashtext('mine_production_entry:' || p_player_id::text));

  for v_row in
    select
      m.id as mine_id,
      m.output_capacity,
      coalesce(m.boost_multiplier, 1) as boost_multiplier,
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

    if v_ticks <= 0 then
      continue;
    end if;

    v_processed_count := v_processed_count + 1;
    v_processed_until := coalesce(v_row.last_production_at, v_now) + make_interval(mins => p_tick_minutes * v_ticks);
    v_available_output_capacity := greatest(v_row.output_capacity - v_row.output_quantity, 0);

    if v_available_output_capacity <= 0 then
      update public.mines
      set last_production_at = v_processed_until,
          updated_at = timezone('utc'::text, now())
      where id = v_row.mine_id;

      v_skipped_count := v_skipped_count + 1;
      continue;
    end if;

    v_rate_per_tick := (coalesce(v_row.uretim_adedi, 0)::numeric / 6) * coalesce(v_row.boost_multiplier, 1);
    v_raw_output := coalesce(v_row.output_pending_quantity, 0) + (v_rate_per_tick * v_ticks);
    v_whole_output := floor(v_raw_output)::integer;

    if v_whole_output <= 0 then
      update public.production_inventory
      set pending_quantity = v_raw_output
      where id = v_row.output_inventory_id;

      update public.mines
      set last_production_at = v_processed_until,
          updated_at = timezone('utc'::text, now())
      where id = v_row.mine_id;

      v_pending_only_count := v_pending_only_count + 1;
      continue;
    end if;

    v_output_to_produce := least(v_whole_output, v_available_output_capacity);
    v_pending_after := case
      when v_output_to_produce < v_whole_output then 0
      else v_raw_output - v_whole_output
    end;

    update public.production_inventory
    set quantity = quantity + v_output_to_produce,
        pending_quantity = v_pending_after
    where id = v_row.output_inventory_id;

    update public.mines
    set last_production_at = v_processed_until,
        updated_at = timezone('utc'::text, now())
    where id = v_row.mine_id;

    if v_output_to_produce > 0 then
      v_produced_count := v_produced_count + 1;
      v_total_produced := v_total_produced + v_output_to_produce;
    else
      v_skipped_count := v_skipped_count + 1;
    end if;
  end loop;

  return jsonb_build_object(
    'success', true,
    'processed_count', v_processed_count,
    'produced_count', v_produced_count,
    'pending_only_count', v_pending_only_count,
    'skipped_count', v_skipped_count,
    'total_produced', v_total_produced
  );
end;
$$;

create or replace function public.process_player_production_entry(
  p_player_id uuid default auth.uid(),
  p_owner_kind text default null,
  p_owner_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_boosts_result jsonb;
  v_upgrades_result jsonb;
  v_factory_result jsonb := jsonb_build_object('success', true, 'processed_count', 0, 'produced_count', 0, 'pending_only_count', 0, 'skipped_count', 0, 'total_produced', 0);
  v_field_farm_result jsonb := jsonb_build_object('success', true, 'processed_count', 0, 'produced_count', 0, 'pending_only_count', 0, 'skipped_count', 0, 'total_produced', 0);
  v_mine_result jsonb := jsonb_build_object('success', true, 'processed_count', 0, 'produced_count', 0, 'pending_only_count', 0, 'skipped_count', 0, 'total_produced', 0);
begin
  if p_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  v_boosts_result := public.complete_due_building_boosts(100);
  v_upgrades_result := public.complete_due_building_upgrades(100);

  if p_owner_kind is null or p_owner_kind = 'factory' then
    v_factory_result := public.process_factory_production_entry(
      p_player_id,
      case when p_owner_kind = 'factory' then p_owner_id else null end
    );
  end if;

  if p_owner_kind is null or p_owner_kind in ('field', 'farm') then
    v_field_farm_result := public.process_field_farm_production_entry(
      p_player_id,
      case when p_owner_kind in ('field', 'farm') then p_owner_kind else null end,
      case when p_owner_kind in ('field', 'farm') then p_owner_id else null end
    );
  end if;

  if p_owner_kind is null or p_owner_kind = 'mine' then
    v_mine_result := public.process_mine_production_entry(
      p_player_id,
      case when p_owner_kind = 'mine' then p_owner_id else null end
    );
  end if;

  return jsonb_build_object(
    'success', true,
    'completed_due_building_boosts', v_boosts_result,
    'completed_due_building_upgrades', v_upgrades_result,
    'factory', v_factory_result,
    'field_farm', v_field_farm_result,
    'mine', v_mine_result
  );
end;
$$;

create or replace function public.bootstrap_game_session()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_player_id uuid := auth.uid();
  v_player jsonb;
  v_logistics_state jsonb;
  v_production_result jsonb;
  v_transfers_result jsonb;
begin
  if v_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  perform public.ensure_player_record_exists(v_player_id);

  v_production_result := public.process_player_production_entry(v_player_id);
  v_transfers_result := public.complete_due_market_transfers(v_player_id, 100);
  v_player := public.get_player_profile(v_player_id);
  v_logistics_state := public.get_logistics_entry_state();

  return jsonb_build_object(
    'success', true,
    'player', v_player,
    'logistics_entry_state', v_logistics_state,
    'completed_due_building_boosts', v_production_result -> 'completed_due_building_boosts',
    'completed_due_building_upgrades', v_production_result -> 'completed_due_building_upgrades',
    'processed_production', v_production_result,
    'completed_due_market_transfers', v_transfers_result
  );
end;
$$;

create or replace function public.set_factory_active(
  p_factory_id uuid,
  p_is_active boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_factory public.factories%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Oturum acilmamis.';
  end if;

  update public.factories
  set is_active = p_is_active,
      updated_at = now(),
      last_production_at = timezone('utc'::text, now())
  where id = p_factory_id
    and player_id = auth.uid()
  returning *
  into v_factory;

  if not found then
    raise exception 'Fabrika bulunamadi.';
  end if;

  return jsonb_build_object(
    'success', true,
    'factory', to_jsonb(v_factory)
  );
end;
$$;

create or replace function public.set_mine_active(
  p_mine_id uuid,
  p_is_active boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_mine public.mines%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Oturum acilmamis.';
  end if;

  update public.mines
  set is_active = p_is_active,
      updated_at = now(),
      last_production_at = timezone('utc'::text, now())
  where id = p_mine_id
    and player_id = auth.uid()
  returning *
  into v_mine;

  if not found then
    raise exception 'Maden bulunamadi.';
  end if;

  return jsonb_build_object(
    'success', true,
    'mine', to_jsonb(v_mine)
  );
end;
$$;

create or replace function public.set_production_slot_active(
  p_player_id uuid,
  p_production_slot_id uuid,
  p_is_active boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_slot public.production_slots%rowtype;
  v_owner_player_id uuid;
begin
  select *
  into v_slot
  from public.production_slots
  where id = p_production_slot_id
  for update;

  if not found then
    raise exception 'Uretim slotu bulunamadi.';
  end if;

  if v_slot.owner_kind = 'field' then
    select player_id into v_owner_player_id
    from public.fields
    where id = v_slot.owner_id;
  elsif v_slot.owner_kind = 'farm' then
    select player_id into v_owner_player_id
    from public.farms
    where id = v_slot.owner_id;
  else
    raise exception 'Desteklenmeyen owner_kind: %', v_slot.owner_kind;
  end if;

  if v_owner_player_id is null or v_owner_player_id <> p_player_id then
    raise exception 'Bu slot oyuncuya ait degil.';
  end if;

  update public.production_slots
  set is_active = p_is_active,
      updated_at = timezone('utc'::text, now()),
      last_production_at = timezone('utc'::text, now())
  where id = p_production_slot_id
  returning *
  into v_slot;

  return jsonb_build_object(
    'success', true,
    'slot', to_jsonb(v_slot)
  );
end;
$$;

create or replace function public.assign_production_slot_product(
  p_player_id uuid,
  p_production_slot_id uuid,
  p_product_id text,
  p_quality_level integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $function$
declare
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

  v_input_quality_level integer := 1;
  v_inventory_id uuid;
  v_output_inventory_id uuid;
begin
  perform pg_advisory_xact_lock(hashtext('field_farm_production_lock'));

  if p_quality_level is null or p_quality_level < 1 or p_quality_level > 5 then
    raise exception 'Kalite seviyesi 1 ile 5 arasinda olmalidir.';
  end if;

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
     and v_product_unit not in ('farm', 'ciftlik', 'çiftlik') then
    raise exception 'Bu urun ciftlik urunu degil: %', p_product_id;
  end if;

  if v_slot.owner_kind = 'farm'
     and v_product_unit not in ('field', 'tarla') then
    raise exception 'Bu urun tarla urunu degil: %', p_product_id;
  end if;

  if v_accepted_product_ids is null
     or not (p_product_id = any(regexp_split_to_array(v_accepted_product_ids, '\\s*,\\s*'))) then
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
      and quality_level = v_input_quality_level;

    if not found then
      insert into public.production_inventory (
        owner_kind, owner_id, inventory_type, product_id, quality_level, quantity, pending_quantity, cost
      ) values (
        v_slot.owner_kind, v_slot.owner_id, 'input', v_hammadde_1_id, v_input_quality_level, 0, 0, 0
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
      and quality_level = v_input_quality_level;

    if not found then
      insert into public.production_inventory (
        owner_kind, owner_id, inventory_type, product_id, quality_level, quantity, pending_quantity, cost
      ) values (
        v_slot.owner_kind, v_slot.owner_id, 'input', v_hammadde_2_id, v_input_quality_level, 0, 0, 0
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
      and quality_level = v_input_quality_level;

    if not found then
      insert into public.production_inventory (
        owner_kind, owner_id, inventory_type, product_id, quality_level, quantity, pending_quantity, cost
      ) values (
        v_slot.owner_kind, v_slot.owner_id, 'input', v_hammadde_3_id, v_input_quality_level, 0, 0, 0
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
    and quality_level = p_quality_level;

  if not found then
    insert into public.production_inventory (
      owner_kind, owner_id, inventory_type, product_id, quality_level, quantity, pending_quantity, cost
    ) values (
      v_slot.owner_kind, v_slot.owner_id, 'output', p_product_id, p_quality_level, 0, 0, 0
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

create or replace function public.change_production_slot_product(
  p_player_id uuid,
  p_production_slot_id uuid,
  p_product_id text,
  p_quality_level integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_slot public.production_slots%rowtype;
  v_product public.products%rowtype;
  v_old_product public.products%rowtype;

  v_owner_player_id uuid;
  v_owner_type_id uuid;
  v_accepted_product_ids text;
  v_product_unit text;

  v_old_product_id text;
  v_old_quality_level integer;
  v_same_setting boolean;
  v_duplicate_slot_index integer;

  v_max_quality integer;
  v_existing_input_quantity integer := 0;
  v_existing_input_pending numeric := 0;
  v_existing_output_quantity integer := 0;
  v_existing_output_pending numeric := 0;

  v_created_input_count integer := 0;
  v_created_output_count integer := 0;
  v_deleted_obsolete_count integer := 0;

  v_hammadde_1_id text;
  v_hammadde_2_id text;
  v_hammadde_3_id text;

  v_hammadde_1_miktar numeric;
  v_hammadde_2_miktar numeric;
  v_hammadde_3_miktar numeric;

  v_input_quality_level integer := 1;
  v_inventory_id uuid;
  v_output_inventory_id uuid;
begin
  perform pg_advisory_xact_lock(hashtext('field_farm_production_lock'));

  if p_quality_level is null or p_quality_level < 1 or p_quality_level > 5 then
    raise exception 'Kalite seviyesi 1 ile 5 arasinda olmalidir.';
  end if;

  select *
  into v_slot
  from public.production_slots
  where id = p_production_slot_id
  for update;

  if not found then
    raise exception 'Uretim slotu bulunamadi.';
  end if;

  if coalesce(v_slot.product_id, '') = '' or coalesce(v_slot.quality_level, 0) <= 0 then
    raise exception 'Bu slotta henuz urun yok. Ilk urun secme akisini kullan.';
  end if;

  if v_slot.owner_kind not in ('field', 'farm') then
    raise exception 'Gecersiz production slot owner_kind: %', v_slot.owner_kind;
  end if;

  v_old_product_id := v_slot.product_id;
  v_old_quality_level := v_slot.quality_level;

  select *
  into v_old_product
  from public.products
  where id = v_old_product_id;

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
     and v_product_unit not in ('farm', 'ciftlik', 'çiftlik') then
    raise exception 'Bu urun ciftlik urunu degil: %', p_product_id;
  end if;

  if v_slot.owner_kind = 'farm'
     and v_product_unit not in ('field', 'tarla') then
    raise exception 'Bu urun tarla urunu degil: %', p_product_id;
  end if;

  if v_accepted_product_ids is null
     or not (p_product_id = any(regexp_split_to_array(v_accepted_product_ids, '\\s*,\\s*'))) then
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

  v_same_setting := v_old_product_id = p_product_id and v_old_quality_level = p_quality_level;

  if not v_same_setting then
    select coalesce(sum(pi.quantity), 0), coalesce(sum(pi.pending_quantity), 0)
    into v_existing_input_quantity, v_existing_input_pending
    from public.production_inventory pi
    where pi.owner_kind = v_slot.owner_kind
      and pi.owner_id = v_slot.owner_id
      and pi.inventory_type = 'input'
      and pi.product_id in (
        select unnest(array[
          nullif(v_old_product.hammadde_1_id, ''),
          nullif(v_old_product.hammadde_2_id, ''),
          nullif(v_old_product.hammadde_3_id, '')
        ])
      );

    if v_existing_input_quantity > 0 or coalesce(v_existing_input_pending, 0) > 0 then
      raise exception 'Mevcut urune ait hammadde stogu veya yoldaki hammaddeler var. Urun degistirmeden once bu hammaddeleri depoya aktar.';
    end if;

    select coalesce(quantity, 0), coalesce(pending_quantity, 0)
    into v_existing_output_quantity, v_existing_output_pending
    from public.production_inventory pi
    where pi.owner_kind = v_slot.owner_kind
      and pi.owner_id = v_slot.owner_id
      and pi.inventory_type = 'output'
      and pi.product_id = v_old_product_id
      and pi.quality_level = v_old_quality_level
    for update;

    if v_existing_output_quantity > 0 or coalesce(v_existing_output_pending, 0) > 0 then
      raise exception 'Mevcut urunun output stogu veya yoldaki urunleri var. Urun degistirmeden once bu urune ait stoklari depoya aktar.';
    end if;
  else
    v_existing_input_quantity := 0;
    v_existing_input_pending := 0;
    v_existing_output_quantity := 0;
    v_existing_output_pending := 0;
  end if;

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
      and quality_level = v_input_quality_level;

    if not found then
      insert into public.production_inventory (
        owner_kind, owner_id, inventory_type, product_id, quality_level, quantity, pending_quantity, cost
      ) values (
        v_slot.owner_kind, v_slot.owner_id, 'input', v_hammadde_1_id, v_input_quality_level, 0, 0, 0
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
      and quality_level = v_input_quality_level;

    if not found then
      insert into public.production_inventory (
        owner_kind, owner_id, inventory_type, product_id, quality_level, quantity, pending_quantity, cost
      ) values (
        v_slot.owner_kind, v_slot.owner_id, 'input', v_hammadde_2_id, v_input_quality_level, 0, 0, 0
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
      and quality_level = v_input_quality_level;

    if not found then
      insert into public.production_inventory (
        owner_kind, owner_id, inventory_type, product_id, quality_level, quantity, pending_quantity, cost
      ) values (
        v_slot.owner_kind, v_slot.owner_id, 'input', v_hammadde_3_id, v_input_quality_level, 0, 0, 0
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
    and quality_level = p_quality_level;

  if not found then
    insert into public.production_inventory (
      owner_kind, owner_id, inventory_type, product_id, quality_level, quantity, pending_quantity, cost
    ) values (
      v_slot.owner_kind, v_slot.owner_id, 'output', p_product_id, p_quality_level, 0, 0, 0
    ) returning id into v_output_inventory_id;
    v_created_output_count := 1;
  end if;

  if not v_same_setting then
    delete from public.production_inventory pi
    where pi.owner_kind = v_slot.owner_kind
      and pi.owner_id = v_slot.owner_id
      and coalesce(pi.quantity, 0) = 0
      and coalesce(pi.pending_quantity, 0) = 0
      and not exists (
        select 1
        from public.logistics_transfers lt
        where lt.seller_production_inventory_id = pi.id
           or lt.buyer_production_inventory_id = pi.id
      )
      and not (
        pi.inventory_type = 'output'
        and exists (
          select 1
          from public.production_slots ps
          where ps.owner_kind = pi.owner_kind
            and ps.owner_id = pi.owner_id
            and coalesce(ps.product_id, '') <> ''
            and ps.product_id = pi.product_id
            and ps.quality_level = pi.quality_level
        )
      )
      and not (
        pi.inventory_type = 'input'
        and pi.quality_level = v_input_quality_level
        and exists (
          select 1
          from public.production_slots ps
          join public.products pr on pr.id = ps.product_id
          where ps.owner_kind = pi.owner_kind
            and ps.owner_id = pi.owner_id
            and coalesce(ps.product_id, '') <> ''
            and (
              (nullif(pr.hammadde_1_id, '') = pi.product_id and coalesce(pr.hammadde_1_miktar, 0) > 0)
              or (nullif(pr.hammadde_2_id, '') = pi.product_id and coalesce(pr.hammadde_2_miktar, 0) > 0)
              or (nullif(pr.hammadde_3_id, '') = pi.product_id and coalesce(pr.hammadde_3_miktar, 0) > 0)
            )
        )
      );

    get diagnostics v_deleted_obsolete_count = row_count;
  end if;

  return jsonb_build_object(
    'success', true,
    'mode', 'change',
    'production_slot_id', p_production_slot_id,
    'owner_kind', v_slot.owner_kind,
    'owner_id', v_slot.owner_id,
    'owner_type_id', v_owner_type_id,
    'old_product_id', v_old_product_id,
    'old_quality_level', v_old_quality_level,
    'product_id', p_product_id,
    'product_name', v_product.urun_adi,
    'quality_level', p_quality_level,
    'input_quality_level', v_input_quality_level,
    'player_max_quality_level', v_max_quality,
    'same_setting', v_same_setting,
    'existing_output_quantity', coalesce(v_existing_output_quantity, 0),
    'cleared_output_pending_quantity', coalesce(v_existing_output_pending, 0),
    'created_input_count', v_created_input_count,
    'created_output_count', v_created_output_count,
    'deleted_obsolete_inventory_count', v_deleted_obsolete_count,
    'output_inventory_id', v_output_inventory_id
  );
end;
$function$;

create or replace function public.set_factory_product(
  p_player_id uuid,
  p_factory_id uuid,
  p_product_id text,
  p_quality_level integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_factory record;
  v_product products%rowtype;
  v_max_quality integer;
  v_effective_quality integer;
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

  select
    f.*,
    ft.accepted_product_ids
  into v_factory
  from factories f
  join factory_types ft on ft.id = f.factory_type_id
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
  from products
  where id = p_product_id;

  if not found then
    raise exception 'Urun bulunamadi: %', p_product_id;
  end if;

  if lower(trim(coalesce(v_product.uretim_birimi, ''))) not in ('factory', 'fabrika') then
    raise exception 'Bu urun fabrika urunu degil: %', p_product_id;
  end if;

  if v_factory.accepted_product_ids is null
     or not (
       p_product_id = any(regexp_split_to_array(v_factory.accepted_product_ids, '\\s*,\\s*'))
     ) then
    raise exception 'Bu fabrika turu bu urunu uretemez: %', p_product_id;
  end if;

  select coalesce(max(max_quality_level), 1)
  into v_max_quality
  from player_product_quality_levels
  where player_id = p_player_id
    and product_id = p_product_id;

  if v_max_quality is null then
    v_max_quality := 1;
  end if;

  v_effective_quality := greatest(1, least(v_max_quality, 5));

  v_is_same_setting :=
    v_factory.product_id = p_product_id
    and v_factory.quality_level = v_effective_quality;

  if not v_is_same_setting then
    select
      coalesce(sum(quantity), 0),
      coalesce(sum(pending_quantity), 0)
    into
      v_existing_quantity,
      v_cleared_pending
    from production_inventory
    where owner_kind = 'factory'
      and owner_id = p_factory_id
      and inventory_type in ('input', 'output');

    if v_existing_quantity > 0 then
      raise exception 'Bu fabrikada input/output stogu var. Urun degistirmeden once stoklari depoya aktar.';
    end if;

    if coalesce(v_cleared_pending, 0) > 0 then
      update production_inventory
      set pending_quantity = 0
      where owner_kind = 'factory'
        and owner_id = p_factory_id
        and inventory_type in ('input', 'output');
    end if;
  else
    v_existing_quantity := 0;
    v_cleared_pending := 0;
  end if;

  update factories
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
    select id
    into v_input_inventory_id
    from production_inventory
    where owner_kind = 'factory'
      and owner_id = p_factory_id
      and inventory_type = 'input'
      and product_id = v_hammadde_1_id
      and quality_level = v_effective_quality;

    if not found then
      insert into production_inventory (
        owner_kind,
        owner_id,
        inventory_type,
        product_id,
        quality_level,
        quantity,
        pending_quantity,
        cost
      )
      values (
        'factory',
        p_factory_id,
        'input',
        v_hammadde_1_id,
        v_effective_quality,
        0,
        0,
        0
      );

      v_created_input_count := v_created_input_count + 1;
    end if;
  end if;

  if v_hammadde_2_id is not null and v_hammadde_2_miktar > 0 then
    select id
    into v_input_inventory_id
    from production_inventory
    where owner_kind = 'factory'
      and owner_id = p_factory_id
      and inventory_type = 'input'
      and product_id = v_hammadde_2_id
      and quality_level = v_effective_quality;

    if not found then
      insert into production_inventory (
        owner_kind,
        owner_id,
        inventory_type,
        product_id,
        quality_level,
        quantity,
        pending_quantity,
        cost
      )
      values (
        'factory',
        p_factory_id,
        'input',
        v_hammadde_2_id,
        v_effective_quality,
        0,
        0,
        0
      );

      v_created_input_count := v_created_input_count + 1;
    end if;
  end if;

  if v_hammadde_3_id is not null and v_hammadde_3_miktar > 0 then
    select id
    into v_input_inventory_id
    from production_inventory
    where owner_kind = 'factory'
      and owner_id = p_factory_id
      and inventory_type = 'input'
      and product_id = v_hammadde_3_id
      and quality_level = v_effective_quality;

    if not found then
      insert into production_inventory (
        owner_kind,
        owner_id,
        inventory_type,
        product_id,
        quality_level,
        quantity,
        pending_quantity,
        cost
      )
      values (
        'factory',
        p_factory_id,
        'input',
        v_hammadde_3_id,
        v_effective_quality,
        0,
        0,
        0
      );

      v_created_input_count := v_created_input_count + 1;
    end if;
  end if;

  select id
  into v_output_inventory_id
  from production_inventory
  where owner_kind = 'factory'
    and owner_id = p_factory_id
    and inventory_type = 'output'
    and product_id = p_product_id
    and quality_level = v_effective_quality;

  if not found then
    insert into production_inventory (
      owner_kind,
      owner_id,
      inventory_type,
      product_id,
      quality_level,
      quantity,
      pending_quantity,
      cost
    )
    values (
      'factory',
      p_factory_id,
      'output',
      p_product_id,
      v_effective_quality,
      0,
      0,
      0
    )
    returning id into v_output_inventory_id;

    v_created_output_count := 1;
  end if;

  if not v_is_same_setting then
    delete from production_inventory pi
    where pi.owner_kind = 'factory'
      and pi.owner_id = p_factory_id
      and coalesce(pi.quantity, 0) = 0
      and coalesce(pi.pending_quantity, 0) = 0
      and not (
        pi.inventory_type = 'output'
        and pi.product_id = p_product_id
        and pi.quality_level = v_effective_quality
      )
      and not (
        pi.inventory_type = 'input'
        and pi.quality_level = v_effective_quality
        and (
          (v_hammadde_1_id is not null and pi.product_id = v_hammadde_1_id and v_hammadde_1_miktar > 0)
          or (v_hammadde_2_id is not null and pi.product_id = v_hammadde_2_id and v_hammadde_2_miktar > 0)
          or (v_hammadde_3_id is not null and pi.product_id = v_hammadde_3_id and v_hammadde_3_miktar > 0)
        )
      )
      and not exists (
        select 1
        from logistics_transfers lt
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

create or replace function public.set_mine_product(
  p_player_id uuid,
  p_mine_id uuid,
  p_product_id text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_mine record;
  v_product record;
  v_accepted_product_ids text;
  v_player_quality integer := 1;
  v_same_setting boolean := false;
  v_old_product_id text;
  v_old_quality_level integer;
  v_existing_output_quantity integer := 0;
  v_cleared_pending_quantity numeric := 0;
  v_deleted_obsolete_count integer := 0;
  v_output_inventory_id uuid;
  v_output_cost numeric := 0;
  v_output_row_count integer := 0;
begin
  if p_product_id is null or length(trim(p_product_id)) = 0 then
    raise exception 'Ürün id boş olamaz.';
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
    raise exception 'Maden bulunamadı.';
  end if;

  if v_mine.player_id <> p_player_id then
    raise exception 'Bu maden oyuncuya ait değil.';
  end if;

  select *
  into v_product
  from public.products
  where id = p_product_id;

  if not found then
    raise exception 'Ürün bulunamadı.';
  end if;

  if lower(trim(coalesce(v_product.uretim_birimi, ''))) not in ('mine', 'maden') then
    raise exception 'Bu ürün maden ürünü değil. Üretim birimi: %', v_product.uretim_birimi;
  end if;

  if v_product.baz_satis_fiyati is null or v_product.baz_satis_fiyati < 0 then
    raise exception 'Ürünün baz_satis_fiyati değeri geçerli değil.';
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
    raise exception 'Bu maden türü seçilen ürünü üretemez.';
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
  v_same_setting :=
    coalesce(v_old_product_id, '') = p_product_id
    and coalesce(v_old_quality_level, 0) = v_player_quality;

  if not v_same_setting and coalesce(v_old_product_id, '') <> '' and coalesce(v_old_quality_level, 0) > 0 then
    select coalesce(quantity, 0), coalesce(pending_quantity, 0)
    into v_existing_output_quantity, v_cleared_pending_quantity
    from public.production_inventory pi
    where pi.owner_kind = 'mine'
      and pi.owner_id = p_mine_id
      and pi.inventory_type = 'output'
      and pi.product_id = v_old_product_id
      and pi.quality_level = v_old_quality_level
    for update;

    if v_existing_output_quantity > 0 then
      raise exception 'Bu madende output stogu var. Urun degistirmeden once stoklari depoya aktar.';
    end if;

    if coalesce(v_cleared_pending_quantity, 0) > 0 then
      raise exception 'Bu madende yoldaki urunler var. Urun degistirmeden once transferlerin tamamlanmasini bekleyin.';
    end if;
  end if;

  update public.mines
  set
    product_id = p_product_id,
    quality_level = v_player_quality,
    updated_at = timezone('utc'::text, now()),
    last_production_at = timezone('utc'::text, now())
  where id = p_mine_id;

  insert into public.production_inventory (
    owner_kind,
    owner_id,
    inventory_type,
    product_id,
    quality_level,
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
    0,
    0,
    v_output_cost
  )
  on conflict (owner_kind, owner_id, inventory_type, product_id, quality_level)
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
    'cleared_pending_quantity', coalesce(v_cleared_pending_quantity, 0),
    'deleted_obsolete_inventory_count', v_deleted_obsolete_count,
    'baz_satis_fiyati', v_product.baz_satis_fiyati,
    'output_cost', v_output_cost,
    'output_inventory_id', v_output_inventory_id,
    'output_row_count', v_output_row_count
  );
end;
$function$;

create or replace function public.process_factory_production()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  return jsonb_build_object(
    'success', true,
    'skipped', true,
    'reason', 'factory_production_moved_to_player_entry',
    'processed_count', 0,
    'produced_count', 0,
    'skipped_count', 0,
    'total_produced', 0
  );
end;
$$;

create or replace function public.process_field_farm_production()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  return jsonb_build_object(
    'success', true,
    'skipped', true,
    'reason', 'field_farm_production_moved_to_player_entry',
    'processed_count', 0,
    'produced_count', 0,
    'skipped_count', 0,
    'total_produced', 0
  );
end;
$$;

create or replace function public.process_mine_production()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  return jsonb_build_object(
    'success', true,
    'skipped', true,
    'reason', 'mine_production_moved_to_player_entry',
    'processed_count', 0,
    'produced_count', 0,
    'pending_only_count', 0,
    'total_produced', 0
  );
end;
$$;
