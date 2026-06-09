create table if not exists public.player_daily_production_stats (
  production_date date not null,
  player_id uuid not null references auth.users (id) on delete cascade,
  owner_kind text not null,
  owner_id uuid not null,
  product_id text not null,
  produced_quantity bigint not null default 0,
  created_at timestamptz not null default timezone('utc'::text, now()),
  updated_at timestamptz not null default timezone('utc'::text, now()),
  constraint player_daily_production_stats_pk primary key (
    production_date,
    player_id,
    owner_kind,
    owner_id,
    product_id
  ),
  constraint player_daily_production_stats_owner_kind_check check (
    owner_kind in ('factory', 'field', 'farm', 'mine')
  ),
  constraint player_daily_production_stats_quantity_check check (
    produced_quantity >= 0
  )
);

create index if not exists idx_player_daily_production_stats_owner
  on public.player_daily_production_stats (
    player_id,
    owner_kind,
    owner_id,
    production_date desc
  );

create index if not exists idx_player_daily_production_stats_product
  on public.player_daily_production_stats (
    player_id,
    product_id,
    production_date desc
  );

alter table public.player_daily_production_stats enable row level security;

drop policy if exists "player_daily_production_stats_select_own" on public.player_daily_production_stats;
create policy "player_daily_production_stats_select_own"
on public.player_daily_production_stats
for select
to authenticated
using (player_id = auth.uid());

create or replace function public.upsert_player_daily_production_stat(
  p_player_id uuid,
  p_owner_kind text,
  p_owner_id uuid,
  p_product_id text,
  p_quantity bigint,
  p_production_date date default (timezone('utc'::text, now()))::date
)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if p_player_id is null then
    raise exception 'Oyuncu bulunamadi.';
  end if;

  if p_owner_kind not in ('factory', 'field', 'farm', 'mine') then
    raise exception 'Gecersiz uretim birimi: %', coalesce(p_owner_kind, 'null');
  end if;

  if p_owner_id is null then
    raise exception 'Uretim birimi kimligi bos olamaz.';
  end if;

  if p_product_id is null then
    raise exception 'Urun kimligi bos olamaz.';
  end if;

  if coalesce(p_quantity, 0) <= 0 then
    return;
  end if;

  insert into public.player_daily_production_stats (
    production_date,
    player_id,
    owner_kind,
    owner_id,
    product_id,
    produced_quantity
  )
  values (
    coalesce(p_production_date, (timezone('utc'::text, now()))::date),
    p_player_id,
    p_owner_kind,
    p_owner_id,
    p_product_id,
    p_quantity
  )
  on conflict (
    production_date,
    player_id,
    owner_kind,
    owner_id,
    product_id
  )
  do update set
    produced_quantity =
      public.player_daily_production_stats.produced_quantity + excluded.produced_quantity,
    updated_at = timezone('utc'::text, now());
end;
$function$;

create or replace function public.get_player_daily_production_stats(
  p_owner_kind text default null,
  p_owner_id uuid default null,
  p_date_from date default ((timezone('utc'::text, now()))::date - 6),
  p_date_to date default (timezone('utc'::text, now()))::date
)
returns table (
  production_date date,
  owner_kind text,
  owner_id uuid,
  product_id text,
  product_name text,
  product_icon text,
  base_sale_price numeric,
  produced_quantity bigint
)
language sql
security invoker
set search_path to 'public'
as $function$
  select
    s.production_date,
    s.owner_kind,
    s.owner_id,
    s.product_id,
    coalesce(p.urun_adi, 'Urun') as product_name,
    coalesce(p.urun_iconu, '') as product_icon,
    coalesce(p.baz_satis_fiyati, 0) as base_sale_price,
    s.produced_quantity
  from public.player_daily_production_stats s
  left join public.products p on p.id = s.product_id
  where s.player_id = auth.uid()
    and (p_owner_kind is null or s.owner_kind = p_owner_kind)
    and (p_owner_id is null or s.owner_id = p_owner_id)
    and s.production_date between coalesce(p_date_from, s.production_date)
      and coalesce(p_date_to, s.production_date)
  order by s.production_date desc, s.owner_kind, product_name;
$function$;

comment on table public.player_daily_production_stats is
'Gunluk uretim kayitlari. Her satir production_date + player + owner + product kombinasyonu icin birikir.';

comment on function public.upsert_player_daily_production_stat(uuid, text, uuid, text, bigint, date) is
'Uretim tamamlandiginda gunluk adet sayacini upsert eder. process_*_production_entry fonksiyonlari icinden cagrilmasi hedeflenir.';

comment on function public.get_player_daily_production_stats(text, uuid, date, date) is
'Oyuncunun gunluk uretim kayitlarini uretim birimi ve tarih araligina gore listeler.';
