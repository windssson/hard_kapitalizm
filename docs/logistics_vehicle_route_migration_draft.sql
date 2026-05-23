begin;

alter table public.logistics_vehicles
add column if not exists route_city_a_id uuid references public.cities(id),
add column if not exists route_city_b_id uuid references public.cities(id);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'logistics_vehicles_route_city_pair_check'
  ) then
    alter table public.logistics_vehicles
    add constraint logistics_vehicles_route_city_pair_check
    check (
      (route_city_a_id is null and route_city_b_id is null) or
      (
        route_city_a_id is not null and
        route_city_b_id is not null and
        route_city_a_id <> route_city_b_id
      )
    );
  end if;
end $$;

create index if not exists idx_logistics_vehicles_route_city_a_id
on public.logistics_vehicles(route_city_a_id);

create index if not exists idx_logistics_vehicles_route_city_b_id
on public.logistics_vehicles(route_city_b_id);

comment on column public.logistics_vehicles.route_city_a_id is
'Aracin atanmis rota ciftindeki birinci sehir. Rota cift yonludur.';

comment on column public.logistics_vehicles.route_city_b_id is
'Aracin atanmis rota ciftindeki ikinci sehir. Rota cift yonludur.';

commit;
