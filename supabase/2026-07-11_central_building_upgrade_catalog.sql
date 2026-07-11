-- Central level 2-5 upgrade catalog for stores, warehouses, fields, farms,
-- factories and mines. Existing in-progress upgrades remain snapshot based.

create table if not exists public.building_upgrade_definitions (
  id uuid primary key default gen_random_uuid(),
  building_kind text not null,
  building_type_id uuid not null,
  from_level integer not null,
  target_level integer not null,
  required_player_level integer not null,
  cash_cost numeric not null,
  duration_seconds integer not null,
  instant_finish_enabled boolean not null default true,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint building_upgrade_definitions_kind_check check (
    building_kind in ('store', 'warehouse', 'field', 'farm', 'factory', 'mine')
  ),
  constraint building_upgrade_definitions_from_level_check check (from_level between 1 and 4),
  constraint building_upgrade_definitions_target_level_check check (target_level between 2 and 5),
  constraint building_upgrade_definitions_level_step_check check (target_level = from_level + 1),
  constraint building_upgrade_definitions_player_level_check check (required_player_level >= 1),
  constraint building_upgrade_definitions_cost_check check (cash_cost >= 0),
  constraint building_upgrade_definitions_duration_check check (duration_seconds > 0),
  constraint building_upgrade_definitions_kind_type_level_key unique (
    building_kind, building_type_id, from_level
  )
);

create table if not exists public.building_upgrade_effects (
  id uuid primary key default gen_random_uuid(),
  upgrade_definition_id uuid not null references public.building_upgrade_definitions(id) on delete cascade,
  metric_key text not null,
  operation text not null,
  value numeric not null,
  display_order smallint not null default 0,
  created_at timestamptz not null default timezone('utc', now()),
  constraint building_upgrade_effects_metric_check check (
    metric_key in (
      'store_slot_capacity', 'store_max_slot_count', 'warehouse_capacity',
      'input_capacity', 'output_capacity'
    )
  ),
  constraint building_upgrade_effects_operation_check check (operation in ('add', 'multiply', 'set')),
  constraint building_upgrade_effects_value_check check (value > 0),
  constraint building_upgrade_effects_definition_metric_key unique (upgrade_definition_id, metric_key)
);

create index if not exists building_upgrade_definitions_active_lookup_idx
  on public.building_upgrade_definitions (building_kind, building_type_id, from_level)
  where is_active;

create index if not exists building_upgrade_effects_definition_idx
  on public.building_upgrade_effects (upgrade_definition_id, display_order);

alter table public.building_upgrade_definitions enable row level security;
alter table public.building_upgrade_effects enable row level security;

drop policy if exists "Authenticated players can read upgrade definitions" on public.building_upgrade_definitions;
create policy "Authenticated players can read upgrade definitions"
  on public.building_upgrade_definitions for select to authenticated using (true);

drop policy if exists "Authenticated players can read upgrade effects" on public.building_upgrade_effects;
create policy "Authenticated players can read upgrade effects"
  on public.building_upgrade_effects for select to authenticated using (true);

revoke all on public.building_upgrade_definitions from anon;
revoke all on public.building_upgrade_effects from anon;
revoke insert, update, delete, truncate, references, trigger on public.building_upgrade_definitions from authenticated;
revoke insert, update, delete, truncate, references, trigger on public.building_upgrade_effects from authenticated;
grant select on public.building_upgrade_definitions to authenticated;
grant select on public.building_upgrade_effects to authenticated;

-- Seed every type with level transitions 1->2, 2->3, 3->4 and 4->5.
insert into public.building_upgrade_definitions (
  building_kind, building_type_id, from_level, target_level,
  required_player_level, cash_cost, duration_seconds
)
select source.building_kind, source.building_type_id, levels.from_level,
       levels.from_level + 1, source.required_player_level,
       case
         when source.building_kind = 'warehouse' then
           ceil((source.base_cost * 0.30) * power(1.10::numeric, levels.from_level - 1))
         else source.base_cost * (levels.from_level + 1)
       end,
       greatest(1, source.base_duration_minutes * (levels.from_level + 1)) * 60
from (
  select 'store'::text building_kind, id building_type_id,
         greatest(coalesce(required_level, 1), 1) required_player_level,
         greatest(coalesce(cost, 0), 0)::numeric base_cost,
         greatest(coalesce(construction_time_minutes, 0), 0) base_duration_minutes
  from public.store_types
  union all
  select 'warehouse', id, greatest(coalesce(required_level, 1), 1),
         greatest(coalesce(cost, 0), 0)::numeric,
         greatest(coalesce(construction_time_minutes, 0), 0)
  from public.warehouse_types
  union all
  select 'field', id, greatest(coalesce(required_level, 1), 1),
         greatest(coalesce(cost, 0), 0)::numeric,
         greatest(coalesce(construction_time_minutes, 0), 0)
  from public.field_types
  union all
  select 'farm', id, greatest(coalesce(required_level, 1), 1),
         greatest(coalesce(cost, 0), 0)::numeric,
         greatest(coalesce(construction_time_minutes, 0), 0)
  from public.farm_types
  union all
  select 'factory', id, greatest(coalesce(required_level, 1), 1),
         greatest(coalesce(cost, 0), 0)::numeric,
         greatest(coalesce(construction_time_minutes, 0), 0)
  from public.factory_types
  union all
  select 'mine', id, greatest(coalesce(required_level, 1), 1),
         greatest(coalesce(cost, 0), 0)::numeric,
         greatest(coalesce(construction_time_minutes, 0), 0)
  from public.mine_types
) source
cross join generate_series(1, 4) as levels(from_level)
on conflict (building_kind, building_type_id, from_level) do update set
  target_level = excluded.target_level,
  required_player_level = excluded.required_player_level,
  cash_cost = excluded.cash_cost,
  duration_seconds = excluded.duration_seconds,
  instant_finish_enabled = true,
  is_active = true,
  updated_at = timezone('utc', now());

insert into public.building_upgrade_effects (
  upgrade_definition_id, metric_key, operation, value, display_order
)
select d.id, effects.metric_key, effects.operation, effects.value, effects.display_order
from public.building_upgrade_definitions d
join lateral (
  select 'store_slot_capacity'::text, 'add'::text, st.slot_capacity::numeric, 10::smallint
  from public.store_types st
  where d.building_kind = 'store' and st.id = d.building_type_id and coalesce(st.slot_capacity, 0) > 0
  union all
  select 'store_max_slot_count', 'add', 2::numeric, 20::smallint
  where d.building_kind = 'store'
  union all
  select 'warehouse_capacity', 'add', wt.base_capacity::numeric, 10::smallint
  from public.warehouse_types wt
  where d.building_kind = 'warehouse' and wt.id = d.building_type_id and coalesce(wt.base_capacity, 0) > 0
  union all
  select 'input_capacity', 'multiply', 2::numeric, 10::smallint
  where d.building_kind in ('field', 'farm', 'factory')
  union all
  select 'output_capacity', 'multiply', 2::numeric, 20::smallint
  where d.building_kind in ('field', 'farm', 'factory', 'mine')
) as effects(metric_key, operation, value, display_order) on true
where d.building_kind in ('store', 'warehouse', 'field', 'farm', 'factory', 'mine')
on conflict (upgrade_definition_id, metric_key) do update set
  operation = excluded.operation,
  value = excluded.value,
  display_order = excluded.display_order;

create or replace function public.get_building_upgrade_quote(
  p_building_kind text,
  p_entity_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_player_id uuid := auth.uid();
  v_player_level integer;
  v_type_id uuid;
  v_name text;
  v_current_level integer;
  v_is_active boolean;
  v_input_capacity numeric := 0;
  v_output_capacity numeric := 0;
  v_slot_capacity numeric := 0;
  v_max_slot_count numeric := 0;
  v_capacity numeric := 0;
  v_definition public.building_upgrade_definitions%rowtype;
  v_effects jsonb := '[]'::jsonb;
  v_params jsonb := '{}'::jsonb;
  v_can_upgrade boolean;
  v_block_reason text;
begin
  if v_player_id is null then raise exception 'Oturum acilmamis.'; end if;
  if p_building_kind not in ('store', 'warehouse', 'field', 'farm', 'factory', 'mine') then
    raise exception 'Desteklenmeyen isletme turu: %', p_building_kind;
  end if;

  select level into v_player_level from public.players where id = v_player_id;
  if not found then raise exception 'Oyuncu bulunamadi.'; end if;

  if p_building_kind = 'store' then
    select store_type_id, name, level, is_active, slot_capacity, max_slot_count
      into v_type_id, v_name, v_current_level, v_is_active, v_slot_capacity, v_max_slot_count
    from public.stores where id = p_entity_id and player_id = v_player_id;
  elsif p_building_kind = 'warehouse' then
    select warehouse_type_id, name, level, is_active, capacity
      into v_type_id, v_name, v_current_level, v_is_active, v_capacity
    from public.warehouses where id = p_entity_id and player_id = v_player_id;
  elsif p_building_kind = 'field' then
    select field_type_id, name, level, is_active, input_capacity, output_capacity, max_slot_count
      into v_type_id, v_name, v_current_level, v_is_active, v_input_capacity, v_output_capacity, v_max_slot_count
    from public.fields where id = p_entity_id and player_id = v_player_id;
  elsif p_building_kind = 'farm' then
    select farm_type_id, name, level, is_active, input_capacity, output_capacity, max_slot_count
      into v_type_id, v_name, v_current_level, v_is_active, v_input_capacity, v_output_capacity, v_max_slot_count
    from public.farms where id = p_entity_id and player_id = v_player_id;
  elsif p_building_kind = 'factory' then
    select factory_type_id, name, level, is_active, input_capacity, output_capacity
      into v_type_id, v_name, v_current_level, v_is_active, v_input_capacity, v_output_capacity
    from public.factories where id = p_entity_id and player_id = v_player_id;
  elsif p_building_kind = 'mine' then
    select mine_type_id, name, level, is_active, output_capacity
      into v_type_id, v_name, v_current_level, v_is_active, v_output_capacity
    from public.mines where id = p_entity_id and player_id = v_player_id;
  end if;

  if v_type_id is null then raise exception 'Isletme bulunamadi veya size ait degil.'; end if;

  if v_current_level >= 5 then
    return jsonb_build_object(
      'success', true, 'can_upgrade', false, 'block_reason', 'maximum_level',
      'building_kind', p_building_kind, 'entity_id', p_entity_id,
      'building_type_id', v_type_id, 'name', v_name,
      'current_level', v_current_level, 'max_level', 5, 'effects', '[]'::jsonb
    );
  end if;

  select * into v_definition
  from public.building_upgrade_definitions
  where building_kind = p_building_kind and building_type_id = v_type_id
    and from_level = v_current_level and is_active;
  if not found then raise exception 'Bu seviye icin aktif yukseltme tanimi bulunamadi.'; end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'metric_key', e.metric_key, 'operation', e.operation, 'value', e.value,
    'previous_value', case e.metric_key
      when 'store_slot_capacity' then v_slot_capacity
      when 'store_max_slot_count' then v_max_slot_count
      when 'warehouse_capacity' then v_capacity
      when 'input_capacity' then v_input_capacity
      when 'output_capacity' then v_output_capacity end,
    'next_value', case e.metric_key
      when 'store_slot_capacity' then case e.operation when 'add' then v_slot_capacity + e.value when 'multiply' then v_slot_capacity * e.value else e.value end
      when 'store_max_slot_count' then case e.operation when 'add' then v_max_slot_count + e.value when 'multiply' then v_max_slot_count * e.value else e.value end
      when 'warehouse_capacity' then case e.operation when 'add' then v_capacity + e.value when 'multiply' then v_capacity * e.value else e.value end
      when 'input_capacity' then case e.operation when 'add' then v_input_capacity + e.value when 'multiply' then v_input_capacity * e.value else e.value end
      when 'output_capacity' then case e.operation when 'add' then v_output_capacity + e.value when 'multiply' then v_output_capacity * e.value else e.value end end
  ) order by e.display_order), '[]'::jsonb)
  into v_effects from public.building_upgrade_effects e
  where e.upgrade_definition_id = v_definition.id;

  v_can_upgrade := coalesce(v_is_active, false) and v_player_level >= v_definition.required_player_level;
  v_block_reason := case
    when not coalesce(v_is_active, false) then 'inactive'
    when v_player_level < v_definition.required_player_level then 'player_level'
    else null end;

  return jsonb_build_object(
    'success', true, 'can_upgrade', v_can_upgrade, 'block_reason', v_block_reason,
    'definition_id', v_definition.id, 'building_kind', p_building_kind,
    'entity_id', p_entity_id, 'building_type_id', v_type_id, 'name', v_name,
    'current_level', v_current_level, 'target_level', v_definition.target_level,
    'max_level', 5, 'required_player_level', v_definition.required_player_level,
    'cash_cost', v_definition.cash_cost,
    'duration_seconds', v_definition.duration_seconds,
    'duration_minutes', ceil(v_definition.duration_seconds / 60.0),
    'instant_finish_enabled', v_definition.instant_finish_enabled,
    'effects', v_effects
  );
end;
$function$;

create or replace function public.start_catalog_building_upgrade(
  p_player_id uuid,
  p_building_kind text,
  p_entity_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_now timestamptz := timezone('utc', now());
  v_player public.players%rowtype;
  v_quote jsonb;
  v_upgrade_id uuid;
  v_finish_at timestamptz;
  v_params jsonb;
  v_effect jsonb;
  v_metric text;
  v_previous numeric;
  v_next numeric;
  v_increase numeric;
begin
  if p_player_id is null or p_player_id <> auth.uid() then raise exception 'Gecersiz oyuncu.'; end if;
  if public.is_player_tax_blocked(p_player_id) then
    raise exception 'Vergi borcu limiti asildigi icin yukseltme baslatilamaz.';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_building_kind || ':' || p_entity_id::text, 0));
  select * into v_player from public.players where id = p_player_id for update;
  if not found then raise exception 'Oyuncu bulunamadi.'; end if;

  if exists (
    select 1 from public.building_upgrades
    where player_id = p_player_id and building_kind = p_building_kind
      and entity_id = p_entity_id and status = 'in_progress'
  ) then raise exception 'Bu isletme icin zaten devam eden bir yukseltme var.'; end if;

  if p_building_kind = 'warehouse' and exists (
    select 1 from public.building_upgrades
    where player_id = p_player_id and status = 'in_progress'
  ) then
    return jsonb_build_object('success', false, 'message', 'Ayni anda sadece tek yukseltme baslatabilirsin.');
  end if;

  v_quote := public.get_building_upgrade_quote(p_building_kind, p_entity_id);
  if coalesce((v_quote->>'can_upgrade')::boolean, false) = false then
    return jsonb_build_object(
      'success', false,
      'message', case v_quote->>'block_reason'
        when 'maximum_level' then 'Bu isletme maksimum seviyede.'
        when 'inactive' then 'Pasif isletmede yukseltme baslatilamaz.'
        when 'player_level' then format('Oyuncu seviyesi yetersiz. Gerekli seviye: %s.', v_quote->>'required_player_level')
        else 'Yukseltme baslatilamaz.' end,
      'block_reason', v_quote->>'block_reason'
    );
  end if;

  if v_player.cash < (v_quote->>'cash_cost')::numeric then
    return jsonb_build_object('success', false, 'message', 'Yetersiz bakiye.',
      'required_cash', (v_quote->>'cash_cost')::numeric, 'current_cash', v_player.cash);
  end if;

  v_params := jsonb_build_object(
    'definition_id', v_quote->>'definition_id', 'name', v_quote->>'name',
    'building_type_id', v_quote->>'building_type_id',
    'duration_seconds', (v_quote->>'duration_seconds')::integer,
    'duration_minutes', (v_quote->>'duration_minutes')::integer,
    'upgrade_cost', (v_quote->>'cash_cost')::numeric,
    'effects', v_quote->'effects', 'max_level', 5
  );

  for v_effect in select value from jsonb_array_elements(v_quote->'effects') loop
    v_metric := v_effect->>'metric_key';
    v_previous := coalesce((v_effect->>'previous_value')::numeric, 0);
    v_next := coalesce((v_effect->>'next_value')::numeric, v_previous);
    v_increase := v_next - v_previous;
    if v_metric = 'store_slot_capacity' then
      v_params := v_params || jsonb_build_object('slot_capacity_increase', v_increase, 'previous_slot_capacity', v_previous, 'next_slot_capacity', v_next);
    elsif v_metric = 'store_max_slot_count' then
      v_params := v_params || jsonb_build_object('max_slot_increase', v_increase, 'previous_max_slot_count', v_previous, 'next_max_slot_count', v_next);
    elsif v_metric = 'warehouse_capacity' then
      v_params := v_params || jsonb_build_object('capacity_increase', v_increase, 'previous_capacity', v_previous, 'next_capacity', v_next);
    elsif v_metric = 'input_capacity' then
      v_params := v_params || jsonb_build_object('input_capacity_increase', v_increase, 'previous_input_capacity', v_previous, 'next_input_capacity', v_next);
    elsif v_metric = 'output_capacity' then
      v_params := v_params || jsonb_build_object('output_capacity_increase', v_increase, 'previous_output_capacity', v_previous, 'next_output_capacity', v_next);
    end if;
  end loop;

  update public.players set cash = cash - (v_quote->>'cash_cost')::numeric where id = p_player_id;
  perform public.log_player_cash_change(
    p_player_id, -(v_quote->>'cash_cost')::numeric, v_player.cash,
    'building_upgrade',
    format('%s yukseltme: %s Seviye %s->%s', p_building_kind, v_quote->>'name', v_quote->>'current_level', v_quote->>'target_level'),
    p_entity_id, p_building_kind
  );

  v_finish_at := v_now + make_interval(secs => (v_quote->>'duration_seconds')::integer);
  insert into public.building_upgrades (
    player_id, building_kind, entity_id, current_level, target_level,
    params, status, started_at, finish_at, created_at, updated_at
  ) values (
    p_player_id, p_building_kind, p_entity_id,
    (v_quote->>'current_level')::integer, (v_quote->>'target_level')::integer,
    v_params, 'in_progress', v_now, v_finish_at, v_now, v_now
  ) returning id into v_upgrade_id;

  return v_quote || jsonb_build_object(
    'success', true, 'upgrade_id', v_upgrade_id, 'finish_at', v_finish_at,
    'upgrade_cost', (v_quote->>'cash_cost')::numeric,
    'remaining_cash', v_player.cash - (v_quote->>'cash_cost')::numeric
  );
end;
$function$;

-- Add warehouse completion to the common snapshot-based completion function.
create or replace function public.complete_building_upgrade(p_player_id uuid, p_upgrade_id uuid)
returns jsonb language plpgsql security definer set search_path = public
as $function$
declare
  v_now timestamptz := timezone('utc', now());
  v_upgrade public.building_upgrades%rowtype;
  v_slot_capacity_increase integer := 0;
  v_max_slot_increase integer := 0;
  v_input_capacity_increase integer := 0;
  v_output_capacity_increase integer := 0;
  v_capacity_increase numeric := 0;
  v_exp_result jsonb;
begin
  select * into v_upgrade from public.building_upgrades
  where id = p_upgrade_id and player_id = p_player_id for update;
  if not found then raise exception 'Yukseltme bulunamadi.'; end if;
  if v_upgrade.status <> 'in_progress' then raise exception 'Bu yukseltme tamamlanabilir durumda degil.'; end if;
  if v_upgrade.finish_at > v_now then raise exception 'Yukseltme henuz bitmedi.'; end if;

  if v_upgrade.building_kind = 'store' then
    v_slot_capacity_increase := coalesce((v_upgrade.params->>'slot_capacity_increase')::integer, 0);
    v_max_slot_increase := coalesce((v_upgrade.params->>'max_slot_increase')::integer, 0);
    update public.stores set level=v_upgrade.target_level,
      slot_capacity=slot_capacity+v_slot_capacity_increase,
      max_slot_count=max_slot_count+v_max_slot_increase, updated_at=v_now
    where id=v_upgrade.entity_id and player_id=p_player_id;
    update public.store_slots set capacity=capacity+v_slot_capacity_increase, updated_at=v_now
    where store_id=v_upgrade.entity_id;
  elsif v_upgrade.building_kind = 'warehouse' then
    v_capacity_increase := coalesce((v_upgrade.params->>'capacity_increase')::numeric, 0);
    update public.warehouses set level=v_upgrade.target_level,
      capacity=capacity+v_capacity_increase, updated_at=v_now
    where id=v_upgrade.entity_id and player_id=p_player_id;
  elsif v_upgrade.building_kind = 'field' then
    v_input_capacity_increase := coalesce((v_upgrade.params->>'input_capacity_increase')::integer, 0);
    v_output_capacity_increase := coalesce((v_upgrade.params->>'output_capacity_increase')::integer, 0);
    update public.fields set level=v_upgrade.target_level,
      input_capacity=input_capacity+v_input_capacity_increase,
      output_capacity=output_capacity+v_output_capacity_increase, updated_at=v_now
    where id=v_upgrade.entity_id and player_id=p_player_id;
  elsif v_upgrade.building_kind = 'farm' then
    v_input_capacity_increase := coalesce((v_upgrade.params->>'input_capacity_increase')::integer, 0);
    v_output_capacity_increase := coalesce((v_upgrade.params->>'output_capacity_increase')::integer, 0);
    update public.farms set level=v_upgrade.target_level,
      input_capacity=input_capacity+v_input_capacity_increase,
      output_capacity=output_capacity+v_output_capacity_increase, updated_at=v_now
    where id=v_upgrade.entity_id and player_id=p_player_id;
  elsif v_upgrade.building_kind = 'factory' then
    v_input_capacity_increase := coalesce((v_upgrade.params->>'input_capacity_increase')::integer, 0);
    v_output_capacity_increase := coalesce((v_upgrade.params->>'output_capacity_increase')::integer, 0);
    update public.factories set level=v_upgrade.target_level,
      input_capacity=input_capacity+v_input_capacity_increase,
      output_capacity=output_capacity+v_output_capacity_increase, updated_at=v_now
    where id=v_upgrade.entity_id and player_id=p_player_id;
  elsif v_upgrade.building_kind = 'mine' then
    v_output_capacity_increase := coalesce((v_upgrade.params->>'output_capacity_increase')::integer, 0);
    update public.mines set level=v_upgrade.target_level,
      output_capacity=output_capacity+v_output_capacity_increase, updated_at=v_now
    where id=v_upgrade.entity_id and player_id=p_player_id;
  elsif v_upgrade.building_kind = 'arge_center' then
    update public.arge_centers set level=v_upgrade.target_level,
      max_concurrent_researches=coalesce((v_upgrade.params->>'next_concurrent_researches')::integer,max_concurrent_researches),
      duration_reduction_pct=coalesce((v_upgrade.params->>'next_duration_reduction_pct')::numeric,duration_reduction_pct), updated_at=v_now
    where id=v_upgrade.entity_id and player_id=p_player_id;
  else raise exception 'Desteklenmeyen yukseltme turu: %', v_upgrade.building_kind;
  end if;

  if not found then raise exception 'Yukseltilecek isletme bulunamadi.'; end if;
  update public.building_upgrades set status='completed', completed_at=v_now, updated_at=v_now where id=p_upgrade_id;

  v_exp_result := public.grant_player_experience(
    p_player_id,
    public.calculate_experience_reward('building_upgrade_completed', jsonb_build_object('building_kind',v_upgrade.building_kind,'target_level',v_upgrade.target_level)),
    'building_upgrade_completed',
    jsonb_build_object('upgrade_id',p_upgrade_id,'building_kind',v_upgrade.building_kind,'entity_id',v_upgrade.entity_id,'target_level',v_upgrade.target_level)
  );
  return jsonb_build_object('success',true,'upgrade_id',p_upgrade_id,'building_kind',v_upgrade.building_kind,
    'entity_id',v_upgrade.entity_id,'target_level',v_upgrade.target_level,
    'slot_capacity_increase',v_slot_capacity_increase,'max_slot_increase',v_max_slot_increase,
    'input_capacity_increase',v_input_capacity_increase,'output_capacity_increase',v_output_capacity_increase,
    'capacity_increase',v_capacity_increase,'completed_at',v_now,'experience',v_exp_result);
end;
$function$;

-- Compatibility wrappers keep existing Flutter and cron callers working.
create or replace function public.start_warehouse_upgrade(p_player_id uuid, p_warehouse_id uuid)
returns jsonb language sql security definer set search_path = public
as $function$
  select public.start_catalog_building_upgrade(p_player_id, 'warehouse', p_warehouse_id);
$function$;

create or replace function public.start_building_upgrade(
  p_player_id uuid,
  p_building_kind text,
  p_entity_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_now timestamptz := timezone('utc', now());
  v_player public.players%rowtype;
  v_arge public.arge_centers%rowtype;
  v_target_level integer;
  v_duration_minutes integer;
  v_upgrade_cost numeric;
  v_upgrade_id uuid;
  v_finish_at timestamptz;
begin
  if p_building_kind in ('store', 'warehouse', 'field', 'farm', 'factory', 'mine') then
    return public.start_catalog_building_upgrade(p_player_id, p_building_kind, p_entity_id);
  end if;

  if p_building_kind <> 'arge_center' then
    raise exception 'Bu building_kind icin yukseltme destegi yok: %', p_building_kind;
  end if;
  if p_player_id is null or p_player_id <> auth.uid() then raise exception 'Gecersiz oyuncu.'; end if;
  if public.is_player_tax_blocked(p_player_id) then
    raise exception 'Vergi borcu limiti asildigi icin yukseltme baslatilamaz.';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('arge_center:' || p_entity_id::text, 0));
  select * into v_player from public.players where id = p_player_id for update;
  if not found then raise exception 'Oyuncu bulunamadi.'; end if;
  select * into v_arge from public.arge_centers
  where id = p_entity_id and player_id = p_player_id for update;
  if not found then raise exception 'AR-GE merkezi bulunamadi veya size ait degil.'; end if;
  if not coalesce(v_arge.is_active, false) then raise exception 'Pasif AR-GE merkezinde yukseltme baslatilamaz.'; end if;
  if exists (select 1 from public.building_upgrades where player_id=p_player_id
    and building_kind='arge_center' and entity_id=p_entity_id and status='in_progress') then
    raise exception 'Bu isletme icin zaten devam eden bir yukseltme var.';
  end if;

  v_target_level := coalesce(v_arge.level, 1) + 1;
  v_duration_minutes := greatest(1, 60 * v_target_level);
  v_upgrade_cost := greatest(0, 25000 * v_target_level);
  if v_player.cash < v_upgrade_cost then
    raise exception 'Yetersiz bakiye. Gerekli: %, Mevcut: %', v_upgrade_cost, v_player.cash;
  end if;

  update public.players set cash=cash-v_upgrade_cost where id=p_player_id;
  perform public.log_player_cash_change(p_player_id,-v_upgrade_cost,v_player.cash,'building_upgrade',
    format('AR-GE yukseltme: %s Seviye %s->%s',v_arge.name,v_arge.level,v_target_level),p_entity_id,'arge_center');
  v_finish_at := v_now + make_interval(mins => v_duration_minutes);
  insert into public.building_upgrades (
    player_id,building_kind,entity_id,current_level,target_level,params,status,started_at,finish_at,created_at,updated_at
  ) values (
    p_player_id,'arge_center',p_entity_id,v_arge.level,v_target_level,
    jsonb_build_object('name',v_arge.name,'duration_minutes',v_duration_minutes,'upgrade_cost',v_upgrade_cost,
      'slot_capacity_increase',0,'max_slot_increase',0,'input_capacity_increase',0,'output_capacity_increase',0,
      'previous_concurrent_researches',coalesce(v_arge.max_concurrent_researches,1),
      'next_concurrent_researches',case when v_target_level>=6 then 4 when v_target_level>=4 then 3 when v_target_level>=2 then 2 else 1 end,
      'previous_duration_reduction_pct',coalesce(v_arge.duration_reduction_pct,0),
      'next_duration_reduction_pct',case when v_target_level=2 then 5 when v_target_level=3 then 10 when v_target_level=4 then 15 when v_target_level=5 then 20 when v_target_level>=6 then 25 else 0 end),
    'in_progress',v_now,v_finish_at,v_now,v_now
  ) returning id into v_upgrade_id;
  return jsonb_build_object('success',true,'upgrade_id',v_upgrade_id,'building_kind','arge_center',
    'entity_id',p_entity_id,'current_level',v_arge.level,'target_level',v_target_level,
    'duration_minutes',v_duration_minutes,'upgrade_cost',v_upgrade_cost,'finish_at',v_finish_at);
end;
$function$;

create or replace function public.finish_warehouse_upgrade_with_gold(p_player_id uuid, p_upgrade_id uuid)
returns jsonb language sql security definer set search_path = public
as $function$
  select public.finish_building_upgrade_with_gold(p_player_id, p_upgrade_id);
$function$;

create or replace function public.complete_due_warehouse_upgrades(p_limit integer default 100)
returns jsonb language sql security definer set search_path = public
as $function$
  select public.complete_due_building_upgrades(p_limit);
$function$;

revoke all on function public.get_building_upgrade_quote(text, uuid) from public, anon;
revoke all on function public.start_catalog_building_upgrade(uuid, text, uuid) from public, anon;
grant execute on function public.get_building_upgrade_quote(text, uuid) to authenticated;
grant execute on function public.start_catalog_building_upgrade(uuid, text, uuid) to authenticated;
