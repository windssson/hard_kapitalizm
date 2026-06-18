create table if not exists public.player_product_brands (
  id uuid default gen_random_uuid() not null,
  player_id uuid not null,
  product_id text not null,
  brand_id uuid not null default '00000000-0000-0000-0000-000000000000'::uuid,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint player_product_brands_pkey primary key (id),
  constraint player_product_brands_unique unique (player_id, product_id),
  constraint player_product_brands_player_id_fkey
    foreign key (player_id) references public.players(id) on delete cascade,
  constraint player_product_brands_product_id_fkey
    foreign key (product_id) references public.products(id) on delete cascade
);

alter table public.player_product_brands enable row level security;

drop policy if exists "Players can view owned player product brands" on public.player_product_brands;
create policy "Players can view owned player product brands"
on public.player_product_brands
for select
to authenticated
using (player_id = auth.uid());

drop policy if exists "Players can insert owned player product brands" on public.player_product_brands;
create policy "Players can insert owned player product brands"
on public.player_product_brands
for insert
to authenticated
with check (player_id = auth.uid());

drop policy if exists "Players can update owned player product brands" on public.player_product_brands;
create policy "Players can update owned player product brands"
on public.player_product_brands
for update
to authenticated
using (player_id = auth.uid())
with check (player_id = auth.uid());

drop policy if exists "Players can delete owned player product brands" on public.player_product_brands;
create policy "Players can delete owned player product brands"
on public.player_product_brands
for delete
to authenticated
using (player_id = auth.uid());

alter table public.factories
  add column if not exists brand_id uuid not null
  default '00000000-0000-0000-0000-000000000000'::uuid;

alter table public.mines
  add column if not exists brand_id uuid not null
  default '00000000-0000-0000-0000-000000000000'::uuid;

alter table public.production_slots
  add column if not exists brand_id uuid not null
  default '00000000-0000-0000-0000-000000000000'::uuid;

create or replace function public.resolve_player_product_brand(
  p_player_id uuid,
  p_product_id text
) returns uuid
language sql
stable
set search_path = public
as $$
  select coalesce(
    (
      select ppb.brand_id
      from public.player_product_brands ppb
      where ppb.player_id = p_player_id
        and ppb.product_id = p_product_id
      limit 1
    ),
    '00000000-0000-0000-0000-000000000000'::uuid
  );
$$;

create or replace function public.apply_production_brand_selection()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_default_brand uuid := '00000000-0000-0000-0000-000000000000'::uuid;
  v_player_id uuid;
begin
  if coalesce(new.product_id, '') = '' then
    new.brand_id := v_default_brand;
    return new;
  end if;

  if tg_table_name = 'production_slots' then
    if new.owner_kind = 'field' then
      select f.player_id
      into v_player_id
      from public.fields f
      where f.id = new.owner_id;
    elsif new.owner_kind = 'farm' then
      select fa.player_id
      into v_player_id
      from public.farms fa
      where fa.id = new.owner_id;
    else
      v_player_id := null;
    end if;
  else
    v_player_id := new.player_id;
  end if;

  new.brand_id := public.resolve_player_product_brand(v_player_id, new.product_id);
  return new;
end;
$$;

drop trigger if exists factories_apply_brand_selection on public.factories;
create trigger factories_apply_brand_selection
before insert or update of product_id, quality_level
on public.factories
for each row
execute function public.apply_production_brand_selection();

drop trigger if exists mines_apply_brand_selection on public.mines;
create trigger mines_apply_brand_selection
before insert or update of product_id, quality_level
on public.mines
for each row
execute function public.apply_production_brand_selection();

drop trigger if exists production_slots_apply_brand_selection on public.production_slots;
create trigger production_slots_apply_brand_selection
before insert or update of product_id, quality_level
on public.production_slots
for each row
execute function public.apply_production_brand_selection();

update public.factories
set brand_id = public.resolve_player_product_brand(player_id, product_id)
where coalesce(product_id, '') <> '';

update public.mines
set brand_id = public.resolve_player_product_brand(player_id, product_id)
where coalesce(product_id, '') <> '';

update public.production_slots ps
set brand_id = case
  when ps.owner_kind = 'field' then public.resolve_player_product_brand(
    (select f.player_id from public.fields f where f.id = ps.owner_id),
    ps.product_id
  )
  when ps.owner_kind = 'farm' then public.resolve_player_product_brand(
    (select fa.player_id from public.farms fa where fa.id = ps.owner_id),
    ps.product_id
  )
  else '00000000-0000-0000-0000-000000000000'::uuid
end
where coalesce(ps.product_id, '') <> '';

create or replace function public.get_producible_products_for_owner_type(
  p_player_id uuid,
  p_owner_kind text,
  p_type_id uuid
) returns table(
  id text,
  urun_adi text,
  urun_iconu text,
  birim_hacim numeric,
  birim_agirlik numeric,
  hammadde_1_id text,
  hammadde_1_miktar numeric,
  hammadde_2_id text,
  hammadde_2_miktar numeric,
  hammadde_3_id text,
  hammadde_3_miktar numeric,
  uretim_birimi text,
  baz_satis_fiyati numeric,
  uretim_adedi integer,
  satis_adedi integer,
  en_dusuk_fiyat numeric,
  en_yuksek_fiyat numeric,
  ortalama_fiyat numeric,
  satici_sayisi integer,
  piyasadaki_stok integer,
  created_at timestamptz,
  max_quality_level integer,
  preferred_brand_id uuid
) language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner_kind text := lower(trim(coalesce(p_owner_kind, '')));
  v_accepted_product_ids text;
  v_allowed_units text[];
  v_auth_player_id uuid;
begin
  v_auth_player_id := auth.uid();

  if v_auth_player_id is null then
    raise exception 'Oturum bulunamadi.';
  end if;

  if p_player_id is null or p_player_id <> v_auth_player_id then
    raise exception 'Gecersiz oyuncu kimligi.';
  end if;

  if p_type_id is null then
    raise exception 'Isletme turu bos olamaz.';
  end if;

  case v_owner_kind
    when 'field' then
      select ft.accepted_product_ids
      into v_accepted_product_ids
      from public.field_types ft
      where ft.id = p_type_id;
      v_allowed_units := array['farm', 'ciftlik', 'çiftlik'];
    when 'farm' then
      select ft.accepted_product_ids
      into v_accepted_product_ids
      from public.farm_types ft
      where ft.id = p_type_id;
      v_allowed_units := array['field', 'tarla'];
    when 'factory' then
      select ft.accepted_product_ids
      into v_accepted_product_ids
      from public.factory_types ft
      where ft.id = p_type_id;
      v_allowed_units := array['factory', 'fabrika'];
    when 'mine' then
      select mt.accepted_product_ids
      into v_accepted_product_ids
      from public.mine_types mt
      where mt.id = p_type_id;
      v_allowed_units := array['mine', 'maden'];
    else
      raise exception 'Desteklenmeyen owner_kind: %', p_owner_kind;
  end case;

  if not found then
    raise exception 'Isletme turu bulunamadi.';
  end if;

  if coalesce(trim(v_accepted_product_ids), '') = '' then
    return;
  end if;

  return query
  with quality_levels as (
    select
      ppql.product_id,
      max(ppql.max_quality_level)::integer as max_quality_level
    from public.player_product_quality_levels ppql
    where ppql.player_id = p_player_id
    group by ppql.product_id
  )
  select
    p.id,
    p.urun_adi,
    p.urun_iconu,
    p.birim_hacim,
    p.birim_agirlik,
    p.hammadde_1_id,
    p.hammadde_1_miktar,
    p.hammadde_2_id,
    p.hammadde_2_miktar,
    p.hammadde_3_id,
    p.hammadde_3_miktar,
    p.uretim_birimi,
    p.baz_satis_fiyati,
    p.uretim_adedi,
    p.satis_adedi,
    p.en_dusuk_fiyat,
    p.en_yuksek_fiyat,
    p.ortalama_fiyat,
    p.satici_sayisi,
    p.piyasadaki_stok,
    p.created_at,
    coalesce(ql.max_quality_level, 1) as max_quality_level,
    public.resolve_player_product_brand(p_player_id, p.id) as preferred_brand_id
  from public.products p
  left join quality_levels ql on ql.product_id = p.id
  where p.id = any(regexp_split_to_array(v_accepted_product_ids, '\s*,\s*'))
    and lower(trim(coalesce(p.uretim_birimi, ''))) = any(v_allowed_units)
  order by p.urun_adi asc;
end;
$$;

grant all on table public.player_product_brands to anon, authenticated, service_role;
grant all on function public.resolve_player_product_brand(uuid, text) to anon, authenticated, service_role;
grant all on function public.get_producible_products_for_owner_type(uuid, text, uuid) to anon, authenticated, service_role;
