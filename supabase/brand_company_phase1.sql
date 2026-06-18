create table if not exists public.brand_companies (
  id uuid default gen_random_uuid() not null,
  player_id uuid not null,
  brand_name text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint brand_companies_pkey primary key (id),
  constraint brand_companies_player_unique unique (player_id),
  constraint brand_companies_player_fkey
    foreign key (player_id) references public.players(id) on delete cascade
);

create table if not exists public.brand_company_products (
  id uuid default gen_random_uuid() not null,
  brand_company_id uuid not null,
  player_id uuid not null,
  product_id text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint brand_company_products_pkey primary key (id),
  constraint brand_company_products_unique unique (player_id, product_id),
  constraint brand_company_products_company_fkey
    foreign key (brand_company_id) references public.brand_companies(id) on delete cascade,
  constraint brand_company_products_player_fkey
    foreign key (player_id) references public.players(id) on delete cascade,
  constraint brand_company_products_product_fkey
    foreign key (product_id) references public.products(id) on delete cascade
);

alter table public.brand_companies enable row level security;
alter table public.brand_company_products enable row level security;

drop policy if exists "Players can view own brand companies" on public.brand_companies;
create policy "Players can view own brand companies"
on public.brand_companies
for select
to authenticated
using (player_id = auth.uid());

drop policy if exists "Players can insert own brand companies" on public.brand_companies;
create policy "Players can insert own brand companies"
on public.brand_companies
for insert
to authenticated
with check (player_id = auth.uid());

drop policy if exists "Players can update own brand companies" on public.brand_companies;
create policy "Players can update own brand companies"
on public.brand_companies
for update
to authenticated
using (player_id = auth.uid())
with check (player_id = auth.uid());

drop policy if exists "Players can view own brand company products" on public.brand_company_products;
create policy "Players can view own brand company products"
on public.brand_company_products
for select
to authenticated
using (player_id = auth.uid());

drop policy if exists "Players can insert own brand company products" on public.brand_company_products;
create policy "Players can insert own brand company products"
on public.brand_company_products
for insert
to authenticated
with check (player_id = auth.uid());

drop policy if exists "Players can update own brand company products" on public.brand_company_products;
create policy "Players can update own brand company products"
on public.brand_company_products
for update
to authenticated
using (player_id = auth.uid())
with check (player_id = auth.uid());

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
      select bc.id
      from public.brand_company_products bcp
      join public.brand_companies bc on bc.id = bcp.brand_company_id
      where bcp.player_id = p_player_id
        and bcp.product_id = p_product_id
        and bcp.is_active = true
        and bc.is_active = true
      limit 1
    ),
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

create or replace function public.get_player_brand_company()
returns jsonb
language sql
security definer
set search_path = public
as $$
  select to_jsonb(bc)
  from public.brand_companies bc
  where bc.player_id = auth.uid()
  limit 1;
$$;

create or replace function public.get_player_brand_company_products()
returns table(
  product_id text,
  product_name text,
  product_icon text,
  max_quality_level integer,
  is_branded boolean,
  branded_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  with company as (
    select bc.id
    from public.brand_companies bc
    where bc.player_id = auth.uid()
    limit 1
  ),
  eligible as (
    select
      ppql.product_id,
      max(ppql.max_quality_level)::integer as max_quality_level
    from public.player_product_quality_levels ppql
    where ppql.player_id = auth.uid()
    group by ppql.product_id
  ),
  branded as (
    select
      bcp.product_id,
      bcp.created_at
    from public.brand_company_products bcp
    join company c on c.id = bcp.brand_company_id
    where bcp.player_id = auth.uid()
      and bcp.is_active = true
  )
  select
    p.id as product_id,
    p.urun_adi as product_name,
    p.urun_iconu as product_icon,
    coalesce(e.max_quality_level, 1) as max_quality_level,
    (b.product_id is not null) as is_branded,
    b.created_at as branded_at
  from public.products p
  left join eligible e on e.product_id = p.id
  left join branded b on b.product_id = p.id
  where coalesce(e.max_quality_level, 0) >= 5
     or b.product_id is not null
  order by
    case when b.product_id is not null then 0 else 1 end,
    p.urun_adi asc;
$$;

create or replace function public.create_brand_company(
  p_brand_name text
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_player_id uuid := auth.uid();
  v_brand_company public.brand_companies%rowtype;
begin
  if v_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  if nullif(trim(coalesce(p_brand_name, '')), '') is null then
    raise exception 'Marka adi bos olamaz.';
  end if;

  select *
  into v_brand_company
  from public.brand_companies
  where player_id = v_player_id
  limit 1;

  if found then
    raise exception 'Oyuncunun zaten bir marka sirketi var.';
  end if;

  insert into public.brand_companies (
    player_id,
    brand_name,
    is_active
  ) values (
    v_player_id,
    trim(p_brand_name),
    true
  )
  returning * into v_brand_company;

  return jsonb_build_object(
    'success', true,
    'message', 'Marka sirketi kuruldu.',
    'brand_company_id', v_brand_company.id,
    'brand_name', v_brand_company.brand_name
  );
end;
$$;

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
  v_max_quality integer := 0;
  v_product public.products%rowtype;
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

  return jsonb_build_object(
    'success', true,
    'message', 'Urun marka altina alindi.',
    'product_id', p_product_id,
    'product_name', v_product.urun_adi,
    'brand_company_id', v_company.id,
    'brand_name', v_company.brand_name
  );
end;
$$;

grant all on table public.brand_companies to anon, authenticated, service_role;
grant all on table public.brand_company_products to anon, authenticated, service_role;
grant all on function public.get_player_brand_company() to anon, authenticated, service_role;
grant all on function public.get_player_brand_company_products() to anon, authenticated, service_role;
grant all on function public.create_brand_company(text) to anon, authenticated, service_role;
grant all on function public.patent_brand_company_product(text) to anon, authenticated, service_role;
grant all on function public.resolve_player_product_brand(uuid, text) to anon, authenticated, service_role;
