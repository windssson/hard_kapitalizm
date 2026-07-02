create table if not exists public.tender_bids (
  id uuid primary key default gen_random_uuid(),
  tender_id uuid not null references public.tenders(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete cascade,
  bid_amount numeric not null check (bid_amount > 0),
  bond_paid numeric not null check (bond_paid >= 0),
  status text not null default 'active' check (status in ('active', 'won', 'lost', 'cancelled')),
  submitted_at timestamptz not null default timezone('utc'::text, now()),
  resolved_at timestamptz,
  created_at timestamptz not null default timezone('utc'::text, now()),
  updated_at timestamptz not null default timezone('utc'::text, now()),
  constraint tender_bids_unique_player_tender unique (player_id, tender_id)
);

create index if not exists idx_tender_bids_tender_status
  on public.tender_bids(tender_id, status, bid_amount, submitted_at);

create index if not exists idx_tender_bids_player_status
  on public.tender_bids(player_id, status);

alter table public.tender_bids enable row level security;

drop policy if exists "Players can read own tender_bids" on public.tender_bids;
create policy "Players can read own tender_bids"
  on public.tender_bids
  for select
  to authenticated
  using ((select auth.uid()) = player_id);

create or replace function public.submit_tender_bid(
  p_tender_id uuid,
  p_bid_amount numeric
)
returns jsonb
language plpgsql
security definer
set search_path = 'public'
as $$
declare
  v_player_id uuid := auth.uid();
  v_player public.players%rowtype;
  v_tender public.tenders%rowtype;
  v_existing_bid public.tender_bids%rowtype;
  v_bid_id uuid;
  v_now timestamptz := timezone('utc'::text, now());
  v_message text := 'Teklif kaydedildi.';
begin
  if v_player_id is null then
    return jsonb_build_object('success', false, 'message', 'Oturum acilmamis.');
  end if;

  if coalesce(p_bid_amount, 0) <= 0 then
    return jsonb_build_object('success', false, 'message', 'Teklif sifirdan buyuk olmali.');
  end if;

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
    return jsonb_build_object('success', false, 'message', 'Ihale teklif almiyor.');
  end if;

  if v_tender.accept_until <= v_now then
    return jsonb_build_object('success', false, 'message', 'Teklif suresi doldu.');
  end if;

  if coalesce(v_player.level, 1) < v_tender.min_player_level then
    return jsonb_build_object('success', false, 'message', 'Oyuncu seviyesi yeterli degil.');
  end if;

  if p_bid_amount > coalesce(v_tender.reward_cash, 0) then
    return jsonb_build_object(
      'success', false,
      'message', format('Teklif tavan odulu gecemez. En fazla %s verebilirsin.', v_tender.reward_cash)
    );
  end if;

  if exists (
    select 1
    from public.player_tenders pt
    where pt.player_id = v_player_id
      and pt.tender_id = v_tender.id
  ) then
    return jsonb_build_object('success', false, 'message', 'Bu ihale zaten sana atanmis.');
  end if;

  select *
  into v_existing_bid
  from public.tender_bids tb
  where tb.player_id = v_player_id
    and tb.tender_id = v_tender.id
  for update;

  if found then
    update public.tender_bids
    set bid_amount = p_bid_amount,
        updated_at = v_now
    where id = v_existing_bid.id
    returning id into v_bid_id;

    v_message := 'Teklif guncellendi.';
  else
    if coalesce(v_player.cash, 0) < v_tender.bond_amount then
      return jsonb_build_object('success', false, 'message', 'Teminat icin yeterli nakit yok.');
    end if;

    update public.players
    set cash = cash - v_tender.bond_amount
    where id = v_player_id;

    insert into public.tender_bids (
      tender_id,
      player_id,
      bid_amount,
      bond_paid,
      status,
      submitted_at,
      created_at,
      updated_at
    )
    values (
      v_tender.id,
      v_player_id,
      p_bid_amount,
      v_tender.bond_amount,
      'active',
      v_now,
      v_now,
      v_now
    )
    returning id into v_bid_id;

    perform public.log_player_cash_change(
      v_player_id,
      -v_tender.bond_amount,
      v_player.cash,
      'tender_bid_bond_paid',
      format('Ihale teklif teminati odendi. Tender: %s', v_tender.id),
      v_bid_id,
      'tender_bid'
    );
  end if;

  return jsonb_build_object(
    'success', true,
    'tender_bid_id', v_bid_id,
    'bid_amount', p_bid_amount,
    'bond_amount', v_tender.bond_amount,
    'message', v_message
  );
end;
$$;

create or replace function public.ensure_open_tenders()
returns jsonb
language plpgsql
security definer
set search_path = 'public'
as $$
declare
  v_now timestamptz := timezone('utc'::text, now());
  v_expired_count integer := 0;
  v_closed_count integer := 0;
  v_tender public.tenders%rowtype;
  v_winning_bid public.tender_bids%rowtype;
  v_losing_bid public.tender_bids%rowtype;
  v_player_tender_id uuid;
  v_deadline_at timestamptz;
  v_player_cash numeric;
begin
  for v_tender in
    select *
    from public.tenders
    where status = 'open'
      and accept_until <= v_now
    order by accept_until asc
    for update
  loop
    select *
    into v_winning_bid
    from public.tender_bids tb
    where tb.tender_id = v_tender.id
      and tb.status = 'active'
    order by tb.bid_amount asc, tb.submitted_at asc, tb.created_at asc
    limit 1
    for update;

    if not found then
      update public.tenders
      set status = 'expired',
          updated_at = v_now
      where id = v_tender.id;

      v_expired_count := v_expired_count + 1;
      continue;
    end if;

    v_deadline_at := v_now + make_interval(mins => v_tender.delivery_duration_minutes);

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
      v_winning_bid.player_id,
      v_tender.id,
      v_now,
      v_deadline_at,
      v_winning_bid.bond_paid,
      v_tender.required_quantity,
      0,
      v_winning_bid.bid_amount,
      v_tender.product_id,
      v_tender.quality_level,
      v_tender.city_id,
      'active'
    )
    returning id into v_player_tender_id;

    update public.tender_bids
    set status = 'won',
        resolved_at = v_now,
        updated_at = v_now
    where id = v_winning_bid.id;

    update public.tenders
    set status = 'closed',
        updated_at = v_now
    where id = v_tender.id;

    insert into public.player_notifications (
      player_id,
      kind,
      category,
      title,
      message,
      entity_kind,
      entity_id,
      severity,
      status,
      meta,
      dedupe_key
    )
    values (
      v_winning_bid.player_id,
      'event',
      'tender_won',
      'Ihaleyi Kazandin',
      format('%s icin verdigin teklif en dusuk teklif oldu. Teslim sureci basladi.', v_tender.title),
      'player_tender',
      v_player_tender_id,
      'success',
      'unread',
      jsonb_build_object(
        'player_tender_id', v_player_tender_id,
        'tender_id', v_tender.id,
        'bid_amount', v_winning_bid.bid_amount,
        'bond_paid', v_winning_bid.bond_paid,
        'deadline_at', v_deadline_at
      ),
      format('tender:won:%s', v_player_tender_id)
    )
    on conflict (player_id, dedupe_key) do nothing;

    for v_losing_bid in
      select *
      from public.tender_bids tb
      where tb.tender_id = v_tender.id
        and tb.status = 'active'
        and tb.id <> v_winning_bid.id
      for update
    loop
      select cash
      into v_player_cash
      from public.players
      where id = v_losing_bid.player_id
      for update;

      update public.players
      set cash = cash + v_losing_bid.bond_paid
      where id = v_losing_bid.player_id;

      update public.tender_bids
      set status = 'lost',
          resolved_at = v_now,
          updated_at = v_now
      where id = v_losing_bid.id;

      perform public.log_player_cash_change(
        v_losing_bid.player_id,
        v_losing_bid.bond_paid,
        v_player_cash,
        'tender_bid_bond_refunded',
        format('Ihale teklif teminati iade edildi. Tender: %s', v_tender.id),
        v_losing_bid.id,
        'tender_bid'
      );

      insert into public.player_notifications (
        player_id,
        kind,
        category,
        title,
        message,
        entity_kind,
        entity_id,
        severity,
        status,
        meta,
        dedupe_key
      )
      values (
        v_losing_bid.player_id,
        'warning',
        'tender_lost',
        'Ihale Baska Firmaya Gitti',
        format('%s daha dusuk bir teklifle kapandi. Teminatin hesabina iade edildi.', v_tender.title),
        'tender_bid',
        v_losing_bid.id,
        'warning',
        'unread',
        jsonb_build_object(
          'tender_id', v_tender.id,
          'tender_bid_id', v_losing_bid.id,
          'bond_paid', v_losing_bid.bond_paid
        ),
        format('tender:lost:%s', v_losing_bid.id)
      )
      on conflict (player_id, dedupe_key) do nothing;
    end loop;

    v_closed_count := v_closed_count + 1;
  end loop;

  return jsonb_build_object(
    'success', true,
    'expired_count', v_expired_count,
    'closed_count', v_closed_count
  );
end;
$$;

create or replace function public.get_tender_detail(
  p_tender_id uuid default null,
  p_player_tender_id uuid default null
)
returns jsonb
language plpgsql
security invoker
as $$
declare
  v_player_id uuid := auth.uid();
  v_tender public.tenders%rowtype;
  v_player_tender public.player_tenders%rowtype;
  v_player_bid public.tender_bids%rowtype;
  v_has_tender boolean := false;
  v_warehouse_options jsonb := '[]'::jsonb;
  v_active_deliveries jsonb := '[]'::jsonb;
  v_city_name text;
  v_product_name text;
  v_product_icon text;
  v_product_unit_volume numeric := 0;
  v_in_transit_quantity integer := 0;
begin
  if v_player_id is null then
    return jsonb_build_object('success', false, 'message', 'Oturum bulunamadi.');
  end if;

  if p_player_tender_id is null and p_tender_id is null then
    return jsonb_build_object('success', false, 'message', 'Ihale secilmedi.');
  end if;

  if p_player_tender_id is not null then
    select pt.*
    into v_player_tender
    from public.player_tenders pt
    where pt.id = p_player_tender_id
      and pt.player_id = v_player_id;

    if not found then
      return jsonb_build_object('success', false, 'message', 'Oyuncu ihalesi bulunamadi.');
    end if;

    select coalesce(sum(td.quantity), 0)::integer
    into v_in_transit_quantity
    from public.tender_deliveries td
    where td.player_tender_id = v_player_tender.id
      and td.status = 'in_transit';

    select t.*
    into v_tender
    from public.tenders t
    where t.id = v_player_tender.tender_id;

    if not found then
      return jsonb_build_object('success', false, 'message', 'Ihale bulunamadi.');
    end if;
  else
    select t.*
    into v_tender
    from public.tenders t
    where t.id = p_tender_id
      and t.status = 'open'
      and t.accept_until > timezone('utc'::text, now());

    v_has_tender := found;

    if v_has_tender then
      select tb.*
      into v_player_bid
      from public.tender_bids tb
      where tb.tender_id = v_tender.id
        and tb.player_id = v_player_id;
    end if;
  end if;

  if p_player_tender_id is null and not v_has_tender then
    return jsonb_build_object('success', false, 'message', 'Ihale bulunamadi.');
  end if;

  select c.name
  into v_city_name
  from public.cities c
  where c.id = v_tender.city_id;

  select p.urun_adi, p.urun_iconu, coalesce(p.birim_hacim, 0)
  into v_product_name, v_product_icon, v_product_unit_volume
  from public.products p
  where p.id = v_tender.product_id;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'warehouse_id', w.id,
        'warehouse_name', w.name,
        'city_id', w.city_id,
        'city_name', c.name,
        'available_quantity', inv.available_quantity,
        'same_city', (w.city_id = coalesce(v_player_tender.city_id, v_tender.city_id)),
        'distance_km',
          case
            when w.city_id = coalesce(v_player_tender.city_id, v_tender.city_id) then 0
            else round(
              (
                6371 * 2 * asin(
                  sqrt(
                    power(
                      sin(radians(coalesce(tc.map_position_x, 0) - coalesce(sc.map_position_x, 0)) / 2),
                      2
                    ) +
                    cos(radians(coalesce(sc.map_position_x, 0))) *
                    cos(radians(coalesce(tc.map_position_x, 0))) *
                    power(
                      sin(radians(coalesce(tc.map_position_y, 0) - coalesce(sc.map_position_y, 0)) / 2),
                      2
                    )
                  )
                )
              )::numeric,
              2
            )
          end,
        'estimated_duration_minutes',
          case
            when w.city_id = coalesce(v_player_tender.city_id, v_tender.city_id) then 5
            else null
          end,
        'can_deliver_before_deadline',
          case
            when p_player_tender_id is null then null
            when w.city_id <> v_player_tender.city_id then null
            else
              v_player_tender.deadline_at >= timezone('utc'::text, now()) +
                make_interval(
                  mins =>
                    case
                      when w.city_id = v_player_tender.city_id then 5
                      else greatest(
                        10,
                        ceil(
                          (
                            6371 * 2 * asin(
                              sqrt(
                                power(
                                  sin(radians(coalesce(tc.map_position_x, 0) - coalesce(sc.map_position_x, 0)) / 2),
                                  2
                                ) +
                                cos(radians(coalesce(sc.map_position_x, 0))) *
                                cos(radians(coalesce(tc.map_position_x, 0))) *
                                power(
                                  sin(radians(coalesce(tc.map_position_y, 0) - coalesce(sc.map_position_y, 0)) / 2),
                                  2
                                )
                              )
                            )
                          ) / 80.0 * 12.0
                        )
                      )::integer
                    end
                )
          end,
        'recommended',
          case
            when p_player_tender_id is null then (w.city_id = v_tender.city_id)
            when w.city_id = v_player_tender.city_id then true
            when
              (
                v_player_tender.deadline_at >= timezone('utc'::text, now()) +
                  make_interval(
                    mins =>
                      case
                        when w.city_id = v_player_tender.city_id then 5
                        else greatest(
                          10,
                          ceil(
                            (
                              6371 * 2 * asin(
                                sqrt(
                                  power(
                                    sin(radians(coalesce(tc.map_position_x, 0) - coalesce(sc.map_position_x, 0)) / 2),
                                    2
                                  ) +
                                  cos(radians(coalesce(sc.map_position_x, 0))) *
                                  cos(radians(coalesce(tc.map_position_x, 0))) *
                                  power(
                                    sin(radians(coalesce(tc.map_position_y, 0) - coalesce(sc.map_position_y, 0)) / 2),
                                    2
                                  )
                                )
                              )
                            ) / 80.0 * 12.0
                          )
                        )::integer
                      end
                  )
              )
              then true
            else false
          end
      )
      order by
        case
          when p_player_tender_id is null then case when w.city_id = v_tender.city_id then 0 else 1 end
          when w.city_id = v_player_tender.city_id then 0
          when
            v_player_tender.deadline_at >= timezone('utc'::text, now()) +
              make_interval(
                mins =>
                  case
                    when w.city_id = v_player_tender.city_id then 5
                    else greatest(
                      10,
                      ceil(
                        (
                          6371 * 2 * asin(
                            sqrt(
                              power(
                                sin(radians(coalesce(tc.map_position_x, 0) - coalesce(sc.map_position_x, 0)) / 2),
                                2
                              ) +
                              cos(radians(coalesce(sc.map_position_x, 0))) *
                              cos(radians(coalesce(tc.map_position_x, 0))) *
                              power(
                                sin(radians(coalesce(tc.map_position_y, 0) - coalesce(sc.map_position_y, 0)) / 2),
                                2
                              )
                            )
                          )
                        ) / 80.0 * 12.0
                      )
                    )::integer
                  end
              ) then 1
          else 2
        end,
        inv.available_quantity desc,
        w.name asc
    ),
    '[]'::jsonb
  )
  into v_warehouse_options
  from public.warehouses w
  join public.cities c on c.id = w.city_id
  join public.cities sc on sc.id = w.city_id
  join public.cities tc on tc.id = coalesce(v_player_tender.city_id, v_tender.city_id)
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

  if p_player_tender_id is not null then
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', td.id,
          'source_warehouse_id', td.source_warehouse_id,
          'source_warehouse_name', w.name,
          'source_city_name', c.name,
          'quantity', td.quantity,
          'status', td.status,
          'same_city', td.same_city,
          'started_at', td.started_at,
          'finish_at', td.finish_at
        )
        order by td.finish_at asc nulls last, td.created_at asc
      ),
      '[]'::jsonb
    )
    into v_active_deliveries
    from public.tender_deliveries td
    join public.warehouses w on w.id = td.source_warehouse_id
    join public.cities c on c.id = w.city_id
    where td.player_tender_id = v_player_tender.id
      and td.status = 'in_transit';
  end if;

  return jsonb_build_object(
    'success', true,
    'tender', jsonb_build_object(
      'id', v_tender.id,
      'title', v_tender.title,
      'description', v_tender.description,
      'city_id', v_tender.city_id,
      'city_name', coalesce(v_city_name, '-'),
      'product_id', v_tender.product_id,
      'product_name', coalesce(v_product_name, '-'),
      'product_icon', coalesce(v_product_icon, 'default.webp'),
      'product_unit_volume', coalesce(v_product_unit_volume, 0),
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
          'in_transit_quantity', v_in_transit_quantity,
          'remaining_quantity', greatest(v_player_tender.required_quantity - v_player_tender.delivered_quantity - v_in_transit_quantity, 0),
          'status', v_player_tender.status
        )
      end,
    'player_bid',
      case
        when p_player_tender_id is not null or v_player_bid.id is null then null
        else jsonb_build_object(
          'id', v_player_bid.id,
          'bid_amount', v_player_bid.bid_amount,
          'bond_paid', v_player_bid.bond_paid,
          'status', v_player_bid.status,
          'submitted_at', v_player_bid.submitted_at,
          'updated_at', v_player_bid.updated_at
        )
      end,
    'warehouse_options', v_warehouse_options,
    'active_deliveries', v_active_deliveries
  );
end;
$$;
