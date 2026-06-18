alter table public.production_inventory
  add column if not exists brand_id uuid not null
  default '00000000-0000-0000-0000-000000000000'::uuid;

create or replace function public.resolve_production_inventory_brand(
  p_owner_kind text,
  p_owner_id uuid,
  p_inventory_type text,
  p_product_id text,
  p_quality_level integer
) returns uuid
language plpgsql
stable
set search_path = public
as $$
declare
  v_default_brand uuid := '00000000-0000-0000-0000-000000000000'::uuid;
  v_player_id uuid;
  v_brand_id uuid;
begin
  if coalesce(p_product_id, '') = '' then
    return v_default_brand;
  end if;

  if coalesce(p_inventory_type, '') = 'input' then
    return v_default_brand;
  end if;

  case coalesce(p_owner_kind, '')
    when 'factory' then
      select brand_id into v_brand_id
      from public.factories
      where id = p_owner_id;
    when 'mine' then
      select brand_id into v_brand_id
      from public.mines
      where id = p_owner_id;
    when 'field', 'farm' then
      select ps.brand_id
      into v_brand_id
      from public.production_slots ps
      where ps.owner_kind = p_owner_kind
        and ps.owner_id = p_owner_id
        and coalesce(ps.product_id, '') = p_product_id
        and coalesce(ps.quality_level, 0) = coalesce(p_quality_level, 0)
      order by ps.slot_index, ps.id
      limit 1;
  end case;

  return coalesce(v_brand_id, v_default_brand);
end;
$$;

create or replace function public.apply_production_inventory_brand()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.brand_id := public.resolve_production_inventory_brand(
    new.owner_kind,
    new.owner_id,
    new.inventory_type,
    new.product_id,
    new.quality_level
  );
  return new;
end;
$$;

drop trigger if exists production_inventory_apply_brand on public.production_inventory;
create trigger production_inventory_apply_brand
before insert or update of owner_kind, owner_id, inventory_type, product_id, quality_level
on public.production_inventory
for each row
execute function public.apply_production_inventory_brand();

with input_rollup as (
  select
    owner_kind,
    owner_id,
    inventory_type,
    product_id,
    quality_level,
    sum(coalesce(quantity, 0))::integer as total_quantity,
    sum(coalesce(pending_quantity, 0)) as total_pending_quantity,
    case
      when sum(coalesce(quantity, 0)) <= 0 then max(coalesce(cost, 0))
      else round(
        sum(coalesce(quantity, 0) * coalesce(cost, 0))
        / sum(coalesce(quantity, 0)),
        4
      )
    end as merged_cost,
    min(id) as keeper_id
  from public.production_inventory
  where inventory_type = 'input'
  group by owner_kind, owner_id, inventory_type, product_id, quality_level
),
input_updates as (
  update public.production_inventory pi
  set
    brand_id = '00000000-0000-0000-0000-000000000000'::uuid,
    quantity = ir.total_quantity,
    pending_quantity = ir.total_pending_quantity,
    cost = ir.merged_cost
  from input_rollup ir
  where pi.id = ir.keeper_id
  returning pi.id
)
delete from public.production_inventory pi
using input_rollup ir
where pi.inventory_type = 'input'
  and pi.owner_kind = ir.owner_kind
  and pi.owner_id = ir.owner_id
  and pi.product_id = ir.product_id
  and pi.quality_level = ir.quality_level
  and pi.id <> ir.keeper_id;

update public.production_inventory
set brand_id = public.resolve_production_inventory_brand(
  owner_kind,
  owner_id,
  inventory_type,
  product_id,
  quality_level
);

alter table public.production_inventory
drop constraint if exists production_inventory_unique_item;

drop index if exists public.production_inventory_unique_item_brand;
create unique index if not exists production_inventory_unique_input_item
  on public.production_inventory (owner_kind, owner_id, inventory_type, product_id, quality_level)
  where inventory_type = 'input';

create unique index if not exists production_inventory_unique_output_item_brand
  on public.production_inventory (owner_kind, owner_id, inventory_type, product_id, quality_level, brand_id)
  where inventory_type = 'output';

drop index if exists public.idx_production_inventory_field_farm_input;
drop index if exists public.idx_production_inventory_field_farm_input_brand;
create index if not exists idx_production_inventory_field_farm_input
  on public.production_inventory (owner_kind, owner_id, product_id, quality_level)
  where owner_kind = any(array['field'::text, 'farm'::text])
    and inventory_type = 'input';

drop index if exists public.idx_production_inventory_field_farm_output;
drop index if exists public.idx_production_inventory_field_farm_output_brand;
create index if not exists idx_production_inventory_field_farm_output_brand
  on public.production_inventory (owner_kind, owner_id, product_id, quality_level, brand_id)
  where owner_kind = any(array['field'::text, 'farm'::text])
    and inventory_type = 'output';

drop index if exists public.idx_production_inventory_mine_output_active;
drop index if exists public.idx_production_inventory_mine_output_active_brand;
create index if not exists idx_production_inventory_mine_output_active_brand
  on public.production_inventory (owner_id, product_id, quality_level, brand_id)
  where owner_kind = 'mine'
    and inventory_type = 'output';

grant all on function public.resolve_production_inventory_brand(text, uuid, text, text, integer) to anon, authenticated, service_role;
grant all on function public.apply_production_inventory_brand() to anon, authenticated, service_role;
