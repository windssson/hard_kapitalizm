create table if not exists public.tenders (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text null,
  city_id uuid not null references public.cities(id) on delete restrict,
  product_id text not null references public.products(id) on delete restrict,
  quality_level integer not null check (quality_level >= 1),
  required_quantity integer not null check (required_quantity > 0),
  reward_cash numeric not null check (reward_cash >= 0),
  bond_amount numeric not null check (bond_amount >= 0),
  accept_until timestamptz not null,
  delivery_duration_minutes integer not null check (delivery_duration_minutes > 0),
  status text not null default 'open' check (status in ('open', 'closed', 'expired', 'disabled')),
  visibility text not null default 'public',
  min_player_level integer not null default 1 check (min_player_level >= 1),
  created_at timestamptz not null default timezone('utc'::text, now()),
  updated_at timestamptz not null default timezone('utc'::text, now())
);

create table if not exists public.player_tenders (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.players(id) on delete cascade,
  tender_id uuid not null references public.tenders(id) on delete restrict,
  accepted_at timestamptz not null default timezone('utc'::text, now()),
  deadline_at timestamptz not null,
  bond_paid numeric not null check (bond_paid >= 0),
  required_quantity integer not null check (required_quantity > 0),
  delivered_quantity integer not null default 0 check (delivered_quantity >= 0),
  reward_cash numeric not null check (reward_cash >= 0),
  product_id text not null references public.products(id) on delete restrict,
  quality_level integer not null check (quality_level >= 1),
  city_id uuid not null references public.cities(id) on delete restrict,
  status text not null default 'active' check (status in ('active', 'completed', 'failed', 'cancelled')),
  completed_at timestamptz null,
  failed_at timestamptz null,
  created_at timestamptz not null default timezone('utc'::text, now()),
  updated_at timestamptz not null default timezone('utc'::text, now()),
  constraint player_tenders_unique_player_tender unique (player_id, tender_id)
);

create table if not exists public.tender_deliveries (
  id uuid primary key default gen_random_uuid(),
  player_tender_id uuid not null references public.player_tenders(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete cascade,
  source_warehouse_id uuid not null references public.warehouses(id) on delete restrict,
  vehicle_id uuid null references public.logistics_vehicles(id) on delete set null,
  quantity integer not null check (quantity > 0),
  status text not null check (status in ('instant_completed', 'in_transit', 'completed', 'cancelled', 'failed', 'failed_late')),
  same_city boolean not null default true,
  started_at timestamptz not null default timezone('utc'::text, now()),
  finish_at timestamptz null,
  completed_at timestamptz null,
  cost numeric not null default 0 check (cost >= 0),
  created_at timestamptz not null default timezone('utc'::text, now()),
  updated_at timestamptz not null default timezone('utc'::text, now())
);

create index if not exists idx_tenders_status_accept_until
  on public.tenders(status, accept_until);
create index if not exists idx_tenders_city_id
  on public.tenders(city_id);
create index if not exists idx_tenders_product_quality
  on public.tenders(product_id, quality_level);
create index if not exists idx_tenders_min_player_level
  on public.tenders(min_player_level);

create index if not exists idx_player_tenders_player_status
  on public.player_tenders(player_id, status);
create index if not exists idx_player_tenders_deadline_status
  on public.player_tenders(deadline_at, status);
create index if not exists idx_player_tenders_tender_id
  on public.player_tenders(tender_id);

create index if not exists idx_tender_deliveries_player_status
  on public.tender_deliveries(player_id, status);
create index if not exists idx_tender_deliveries_player_tender_id
  on public.tender_deliveries(player_tender_id);
create index if not exists idx_tender_deliveries_finish_status
  on public.tender_deliveries(finish_at, status);

alter table public.tenders enable row level security;
alter table public.player_tenders enable row level security;
alter table public.tender_deliveries enable row level security;

drop policy if exists "Authenticated users can read open tenders" on public.tenders;
create policy "Authenticated users can read open tenders"
  on public.tenders
  for select
  using (
    (select auth.uid()) is not null
    and status = 'open'
  );

drop policy if exists "Players can read own player_tenders" on public.player_tenders;
create policy "Players can read own player_tenders"
  on public.player_tenders
  for select
  using ((select auth.uid()) = player_id);

drop policy if exists "Players can read own tender_deliveries" on public.tender_deliveries;
create policy "Players can read own tender_deliveries"
  on public.tender_deliveries
  for select
  using ((select auth.uid()) = player_id);

create or replace function public.ensure_open_tenders()
returns jsonb
language plpgsql
security definer
set search_path = 'public'
as $$
declare
  v_expired_count integer := 0;
begin
  update public.tenders
  set status = 'expired',
      updated_at = timezone('utc'::text, now())
  where status = 'open'
    and accept_until <= timezone('utc'::text, now());

  get diagnostics v_expired_count = row_count;

  return jsonb_build_object(
    'success', true,
    'expired_count', v_expired_count,
    'generated_count', 0
  );
end;
$$;

create or replace function public.complete_player_tender(p_player_tender_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = 'public'
as $$
declare
  v_player_tender public.player_tenders%rowtype;
  v_player_cash numeric := 0;
  v_payout numeric := 0;
begin
  select *
  into v_player_tender
  from public.player_tenders
  where id = p_player_tender_id
  for update;

  if not found then
    return jsonb_build_object('success', false, 'message', 'Oyuncu ihalesi bulunamadi.');
  end if;

  if v_player_tender.status <> 'active' then
    return jsonb_build_object('success', false, 'message', 'Ihale aktif degil.');
  end if;

  if v_player_tender.delivered_quantity < v_player_tender.required_quantity then
    return jsonb_build_object('success', false, 'message', 'Teslim miktari henuz yeterli degil.');
  end if;

  select cash
  into v_player_cash
  from public.players
  where id = v_player_tender.player_id
  for update;

  v_payout := v_player_tender.reward_cash + v_player_tender.bond_paid;

  update public.player_tenders
  set status = 'completed',
      completed_at = timezone('utc'::text, now()),
      updated_at = timezone('utc'::text, now())
  where id = v_player_tender.id;

  update public.players
  set cash = cash + v_payout
  where id = v_player_tender.player_id;

  perform public.log_player_cash_change(
    v_player_tender.player_id,
    v_player_tender.reward_cash,
    v_player_cash,
    'tender_reward_paid',
    format('Ihale odulu kazanildi. Tender: %s', v_player_tender.tender_id),
    v_player_tender.id,
    'player_tender'
  );

  perform public.log_player_cash_change(
    v_player_tender.player_id,
    v_player_tender.bond_paid,
    v_player_cash + v_player_tender.reward_cash,
    'tender_bond_refunded',
    format('Ihale teminati iade edildi. Tender: %s', v_player_tender.tender_id),
    v_player_tender.id,
    'player_tender'
  );

  return jsonb_build_object(
    'success', true,
    'player_tender_id', v_player_tender.id,
    'status', 'completed',
    'payout', v_payout,
    'message', 'Ihale tamamlandi.'
  );
end;
$$;

create or replace function public.process_player_tenders(p_player_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = 'public'
as $$
declare
  v_target_player_id uuid := coalesce(p_player_id, auth.uid());
  v_failed_count integer := 0;
begin
  if v_target_player_id is null then
    return jsonb_build_object('success', false, 'message', 'Oturum acilmamis.');
  end if;

  update public.player_tenders
  set status = 'failed',
      failed_at = timezone('utc'::text, now()),
      updated_at = timezone('utc'::text, now())
  where player_id = v_target_player_id
    and status = 'active'
    and deadline_at <= timezone('utc'::text, now())
    and delivered_quantity < required_quantity;

  get diagnostics v_failed_count = row_count;

  return jsonb_build_object(
    'success', true,
    'failed_count', v_failed_count
  );
end;
$$;

create or replace function public.process_tender_deliveries(p_player_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = 'public'
as $$
declare
  v_target_player_id uuid := coalesce(p_player_id, auth.uid());
  v_delivery record;
  v_player_tender public.player_tenders%rowtype;
  v_completed_count integer := 0;
  v_completion_result jsonb;
begin
  if v_target_player_id is null then
    return jsonb_build_object('success', false, 'message', 'Oturum acilmamis.');
  end if;

  for v_delivery in
    select *
    from public.tender_deliveries
    where player_id = v_target_player_id
      and status = 'in_transit'
      and finish_at is not null
      and finish_at <= timezone('utc'::text, now())
    order by finish_at asc
  loop
    select *
    into v_player_tender
    from public.player_tenders
    where id = v_delivery.player_tender_id
    for update;

    if not found then
      update public.tender_deliveries
      set status = 'failed',
          updated_at = timezone('utc'::text, now())
      where id = v_delivery.id;
      continue;
    end if;

    if v_player_tender.status <> 'active' then
      update public.tender_deliveries
      set status = 'failed',
          updated_at = timezone('utc'::text, now())
      where id = v_delivery.id;
      continue;
    end if;

    if v_player_tender.deadline_at < timezone('utc'::text, now()) then
      update public.tender_deliveries
      set status = 'failed_late',
          updated_at = timezone('utc'::text, now())
      where id = v_delivery.id;
      continue;
    end if;

    update public.tender_deliveries
    set status = 'completed',
        completed_at = timezone('utc'::text, now()),
        updated_at = timezone('utc'::text, now())
    where id = v_delivery.id;

    update public.player_tenders
    set delivered_quantity = least(required_quantity, delivered_quantity + v_delivery.quantity),
        updated_at = timezone('utc'::text, now())
    where id = v_player_tender.id;

    v_completed_count := v_completed_count + 1;

    select *
    into v_player_tender
    from public.player_tenders
    where id = v_player_tender.id;

    if v_player_tender.delivered_quantity >= v_player_tender.required_quantity then
      v_completion_result := public.complete_player_tender(v_player_tender.id);
    end if;
  end loop;

  return jsonb_build_object(
    'success', true,
    'completed_delivery_count', v_completed_count
  );
end;
$$;

create or replace function public.accept_tender(p_tender_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = 'public'
as $$
declare
  v_player_id uuid := auth.uid();
  v_player public.players%rowtype;
  v_tender public.tenders%rowtype;
  v_player_tender_id uuid;
begin
  if v_player_id is null then
    return jsonb_build_object('success', false, 'message', 'Oturum acilmamis.');
  end if;

  perform public.ensure_open_tenders();

  select *
  into v_player
  from public.players
  where id = v_player_id
  for update;

  if not found then
    return jsonb_build_object('success', false, 'message', 'Oyuncu bulunamadi.');
  end if;

  select *
  into v_tender
  from public.tenders
  where id = p_tender_id
  for update;

  if not found then
    return jsonb_build_object('success', false, 'message', 'Ihale bulunamadi.');
  end if;

  if v_tender.status <> 'open' then
    return jsonb_build_object('success', false, 'message', 'Ihale acik degil.');
  end if;

  if v_tender.accept_until <= timezone('utc'::text, now()) then
    return jsonb_build_object('success', false, 'message', 'Ihaleye katilim suresi doldu.');
  end if;

  if coalesce(v_player.level, 1) < v_tender.min_player_level then
    return jsonb_build_object('success', false, 'message', 'Oyuncu seviyesi yeterli degil.');
  end if;

  if exists (
    select 1
    from public.player_tenders pt
    where pt.player_id = v_player_id
      and pt.tender_id = v_tender.id
  ) then
    return jsonb_build_object('success', false, 'message', 'Bu ihaleye zaten katildin.');
  end if;

  if coalesce(v_player.cash, 0) < v_tender.bond_amount then
    return jsonb_build_object('success', false, 'message', 'Teminat icin yeterli nakit yok.');
  end if;

  update public.players
  set cash = cash - v_tender.bond_amount
  where id = v_player_id;

  insert into public.player_tenders (
    player_id,
    tender_id,
    accepted_at,
    deadline_at,
    bond_paid,
    required_quantity,
    delivered_quantity,
    reward_cash,
    product_id,
    quality_level,
    city_id,
    status
  )
  values (
    v_player_id,
    v_tender.id,
    timezone('utc'::text, now()),
    timezone('utc'::text, now()) + make_interval(mins => v_tender.delivery_duration_minutes),
    v_tender.bond_amount,
    v_tender.required_quantity,
    0,
    v_tender.reward_cash,
    v_tender.product_id,
    v_tender.quality_level,
    v_tender.city_id,
    'active'
  )
  returning id into v_player_tender_id;

  perform public.log_player_cash_change(
    v_player_id,
    -v_tender.bond_amount,
    v_player.cash,
    'tender_bond_paid',
    format('Ihale teminati odendi. Tender: %s', v_tender.id),
    v_player_tender_id,
    'player_tender'
  );

  return jsonb_build_object(
    'success', true,
    'player_tender_id', v_player_tender_id,
    'deadline_at', timezone('utc'::text, now()) + make_interval(mins => v_tender.delivery_duration_minutes),
    'message', 'Ihaleye katildin. Teslim suresi basladi.'
  );
end;
$$;

create or replace function public.get_tender_center()
returns jsonb
language plpgsql
security definer
set search_path = 'public'
as $$
declare
  v_player_id uuid := auth.uid();
  v_open_tenders jsonb := '[]'::jsonb;
  v_my_active_tenders jsonb := '[]'::jsonb;
  v_delivery_count integer := 0;
begin
  if v_player_id is null then
    return jsonb_build_object('success', false, 'message', 'Oturum acilmamis.');
  end if;

  perform public.ensure_open_tenders();
  perform public.process_tender_deliveries(v_player_id);
  perform public.process_player_tenders(v_player_id);

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'tender_id', t.id,
        'title', t.title,
        'city_id', t.city_id,
        'city_name', c.name,
        'product_id', t.product_id,
        'product_name', p.urun_adi,
        'product_icon', p.urun_iconu,
        'quality_level', t.quality_level,
        'required_quantity', t.required_quantity,
        'reward_cash', t.reward_cash,
        'bond_amount', t.bond_amount,
        'accept_until', t.accept_until,
        'delivery_duration_minutes', t.delivery_duration_minutes,
        'status', t.status,
        'min_player_level', t.min_player_level
      )
      order by t.accept_until asc
    ),
    '[]'::jsonb
  )
  into v_open_tenders
  from public.tenders t
  join public.cities c on c.id = t.city_id
  join public.products p on p.id = t.product_id
  join public.players pl on pl.id = v_player_id
  where t.status = 'open'
    and t.accept_until > timezone('utc'::text, now())
    and coalesce(pl.level, 1) >= t.min_player_level;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'player_tender_id', pt.id,
        'tender_id', pt.tender_id,
        'title', t.title,
        'city_name', c.name,
        'product_id', pt.product_id,
        'product_name', p.urun_adi,
        'product_icon', p.urun_iconu,
        'quality_level', pt.quality_level,
        'required_quantity', pt.required_quantity,
        'delivered_quantity', pt.delivered_quantity,
        'remaining_quantity', greatest(pt.required_quantity - pt.delivered_quantity, 0),
        'reward_cash', pt.reward_cash,
        'bond_paid', pt.bond_paid,
        'deadline_at', pt.deadline_at,
        'status', pt.status
      )
      order by pt.deadline_at asc
    ),
    '[]'::jsonb
  )
  into v_my_active_tenders
  from public.player_tenders pt
  join public.tenders t on t.id = pt.tender_id
  join public.cities c on c.id = pt.city_id
  join public.products p on p.id = pt.product_id
  where pt.player_id = v_player_id
    and pt.status = 'active';

  select count(*)
  into v_delivery_count
  from public.tender_deliveries td
  where td.player_id = v_player_id
    and td.status = 'in_transit';

  return jsonb_build_object(
    'success', true,
    'open_tenders', v_open_tenders,
    'my_active_tenders', v_my_active_tenders,
    'delivery_count', v_delivery_count,
    'server_time', timezone('utc'::text, now())
  );
end;
$$;

create or replace function public.get_tender_detail(
  p_tender_id uuid default null,
  p_player_tender_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = 'public'
as $$
declare
  v_player_id uuid := auth.uid();
  v_player_tender public.player_tenders%rowtype;
  v_tender public.tenders%rowtype;
  v_warehouse_options jsonb := '[]'::jsonb;
begin
  if v_player_id is null then
    return jsonb_build_object('success', false, 'message', 'Oturum acilmamis.');
  end if;

  if p_player_tender_id is not null then
    select *
    into v_player_tender
    from public.player_tenders
    where id = p_player_tender_id
      and player_id = v_player_id;

    if not found then
      return jsonb_build_object('success', false, 'message', 'Oyuncu ihalesi bulunamadi.');
    end if;

    select *
    into v_tender
    from public.tenders
    where id = v_player_tender.tender_id;
  else
    select *
    into v_tender
    from public.tenders
    where id = p_tender_id;
  end if;

  if not found then
    return jsonb_build_object('success', false, 'message', 'Ihale bulunamadi.');
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'warehouse_id', w.id,
        'warehouse_name', w.name,
        'city_id', w.city_id,
        'city_name', c.name,
        'available_quantity', inv.available_quantity,
        'same_city', (w.city_id = coalesce(v_player_tender.city_id, v_tender.city_id)),
        'estimated_duration_minutes', case when w.city_id = coalesce(v_player_tender.city_id, v_tender.city_id) then 0 else null end,
        'can_deliver_before_deadline',
          case
            when p_player_tender_id is null then null
            when w.city_id = v_player_tender.city_id then true
            else false
          end,
        'recommended',
          case
            when w.city_id = coalesce(v_player_tender.city_id, v_tender.city_id) then true
            else false
          end
      )
      order by
        case when w.city_id = coalesce(v_player_tender.city_id, v_tender.city_id) then 0 else 1 end,
        inv.available_quantity desc,
        w.name asc
    ),
    '[]'::jsonb
  )
  into v_warehouse_options
  from public.warehouses w
  join public.cities c on c.id = w.city_id
  join (
    select
      ws.warehouse_id,
      sum(greatest(coalesce(ws.quantity, 0), 0))::integer as available_quantity
    from public.warehouse_slots ws
    where ws.product_id = coalesce(v_player_tender.product_id, v_tender.product_id)
      and ws.quality_level >= coalesce(v_player_tender.quality_level, v_tender.quality_level)
      and coalesce(ws.quantity, 0) > 0
    group by ws.warehouse_id
  ) inv on inv.warehouse_id = w.id
  where w.player_id = v_player_id
    and w.is_active = true;

  return jsonb_build_object(
    'success', true,
    'tender', jsonb_build_object(
      'id', v_tender.id,
      'title', v_tender.title,
      'description', v_tender.description,
      'city_id', v_tender.city_id,
      'product_id', v_tender.product_id,
      'quality_level', v_tender.quality_level,
      'required_quantity', v_tender.required_quantity,
      'reward_cash', v_tender.reward_cash,
      'bond_amount', v_tender.bond_amount,
      'accept_until', v_tender.accept_until,
      'delivery_duration_minutes', v_tender.delivery_duration_minutes,
      'status', v_tender.status
    ),
    'player_tender',
      case
        when p_player_tender_id is null then null
        else jsonb_build_object(
          'id', v_player_tender.id,
          'accepted_at', v_player_tender.accepted_at,
          'deadline_at', v_player_tender.deadline_at,
          'required_quantity', v_player_tender.required_quantity,
          'delivered_quantity', v_player_tender.delivered_quantity,
          'remaining_quantity', greatest(v_player_tender.required_quantity - v_player_tender.delivered_quantity, 0),
          'status', v_player_tender.status
        )
      end,
    'warehouse_options', v_warehouse_options
  );
end;
$$;

create or replace function public.start_tender_delivery(
  p_player_tender_id uuid,
  p_warehouse_id uuid,
  p_vehicle_id uuid default null,
  p_quantity integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = 'public'
as $$
declare
  v_player_id uuid := auth.uid();
  v_player_tender public.player_tenders%rowtype;
  v_warehouse public.warehouses%rowtype;
  v_requested_quantity integer := 0;
  v_remaining_quantity integer := 0;
  v_available_quantity integer := 0;
  v_same_city boolean := false;
  v_now timestamptz := timezone('utc'::text, now());
  v_delivery_id uuid;
  v_slot record;
  v_consume integer := 0;
begin
  if v_player_id is null then
    return jsonb_build_object('success', false, 'message', 'Oturum acilmamis.');
  end if;

  if coalesce(p_quantity, 0) <= 0 then
    return jsonb_build_object('success', false, 'message', 'Gecersiz teslim miktari.');
  end if;

  select *
  into v_player_tender
  from public.player_tenders
  where id = p_player_tender_id
    and player_id = v_player_id
  for update;

  if not found then
    return jsonb_build_object('success', false, 'message', 'Oyuncu ihalesi bulunamadi.');
  end if;

  if v_player_tender.status <> 'active' then
    return jsonb_build_object('success', false, 'message', 'Ihale aktif degil.');
  end if;

  if v_player_tender.deadline_at <= v_now then
    return jsonb_build_object('success', false, 'message', 'Teslim suresi doldu.');
  end if;

  select *
  into v_warehouse
  from public.warehouses
  where id = p_warehouse_id
    and player_id = v_player_id
    and is_active = true
  for update;

  if not found then
    return jsonb_build_object('success', false, 'message', 'Kaynak depo bulunamadi.');
  end if;

  v_same_city := v_warehouse.city_id = v_player_tender.city_id;
  if not v_same_city then
    return jsonb_build_object(
      'success', false,
      'message', 'Sehirler arasi ihale teslimati foundation asamasinda henuz aktif degil.'
    );
  end if;

  v_remaining_quantity := greatest(v_player_tender.required_quantity - v_player_tender.delivered_quantity, 0);
  if v_remaining_quantity <= 0 then
    return jsonb_build_object('success', false, 'message', 'Ihale zaten tamamlandi.');
  end if;

  v_requested_quantity := least(p_quantity, v_remaining_quantity);

  select coalesce(sum(ws.quantity), 0)::integer
  into v_available_quantity
  from public.warehouse_slots ws
  where ws.warehouse_id = v_warehouse.id
    and ws.product_id = v_player_tender.product_id
    and ws.quality_level >= v_player_tender.quality_level
    and coalesce(ws.quantity, 0) > 0;

  if v_available_quantity < v_requested_quantity then
    return jsonb_build_object('success', false, 'message', 'Depoda yeterli uygun stok yok.');
  end if;

  for v_slot in
    select ws.id, ws.quantity
    from public.warehouse_slots ws
    where ws.warehouse_id = v_warehouse.id
      and ws.product_id = v_player_tender.product_id
      and ws.quality_level >= v_player_tender.quality_level
      and coalesce(ws.quantity, 0) > 0
    order by ws.quality_level asc, ws.id asc
  loop
    exit when v_requested_quantity <= 0;

    v_consume := least(v_slot.quantity, v_requested_quantity);

    update public.warehouse_slots
    set quantity = quantity - v_consume
    where id = v_slot.id;

    delete from public.warehouse_slots
    where id = v_slot.id
      and quantity <= 0;

    v_requested_quantity := v_requested_quantity - v_consume;
  end loop;

  insert into public.tender_deliveries (
    player_tender_id,
    player_id,
    source_warehouse_id,
    vehicle_id,
    quantity,
    status,
    same_city,
    started_at,
    finish_at,
    completed_at,
    cost
  )
  values (
    v_player_tender.id,
    v_player_id,
    v_warehouse.id,
    null,
    least(p_quantity, v_remaining_quantity),
    'instant_completed',
    true,
    v_now,
    v_now,
    v_now,
    0
  )
  returning id into v_delivery_id;

  update public.player_tenders
  set delivered_quantity = least(required_quantity, delivered_quantity + least(p_quantity, v_remaining_quantity)),
      updated_at = v_now
  where id = v_player_tender.id;

  select *
  into v_player_tender
  from public.player_tenders
  where id = v_player_tender.id;

  if v_player_tender.delivered_quantity >= v_player_tender.required_quantity then
    perform public.complete_player_tender(v_player_tender.id);
  end if;

  return jsonb_build_object(
    'success', true,
    'delivery_id', v_delivery_id,
    'same_city', true,
    'status', 'instant_completed',
    'message', 'Teslimat aninda tamamlandi.'
  );
end;
$$;
