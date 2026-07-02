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
  v_warehouse_options jsonb := '[]'::jsonb;
  v_active_deliveries jsonb := '[]'::jsonb;
  v_city_name text;
  v_product_name text;
  v_product_icon text;
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
  else
    select t.*
    into v_tender
    from public.tenders t
    where t.id = p_tender_id
      and t.status = 'open';
  end if;

  if not found then
    return jsonb_build_object('success', false, 'message', 'Ihale bulunamadi.');
  end if;

  select c.name
  into v_city_name
  from public.cities c
  where c.id = v_tender.city_id;

  select p.urun_adi, p.urun_iconu
  into v_product_name, v_product_icon
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
          end,
        'can_deliver_before_deadline',
          case
            when p_player_tender_id is null then null
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
    'warehouse_options', v_warehouse_options,
    'active_deliveries', v_active_deliveries
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
  v_now timestamptz := timezone('utc'::text, now());
  v_player_tender public.player_tenders%rowtype;
  v_warehouse public.warehouses%rowtype;
  v_slot record;
  v_same_city boolean := false;
  v_remaining_quantity integer := 0;
  v_selected_quantity integer := 0;
  v_in_transit_quantity integer := 0;
  v_delivery_id uuid;
  v_finish_at timestamptz;
  v_tender_title text := 'Ihale';
  v_distance_km numeric := 0;
  v_estimated_duration_minutes integer := 5;
begin
  if v_player_id is null then
    return jsonb_build_object('success', false, 'message', 'Oturum acilmamis.');
  end if;

  if coalesce(p_quantity, 0) <= 0 then
    return jsonb_build_object('success', false, 'message', 'Teslim miktari sifirdan buyuk olmali.');
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
    return jsonb_build_object('success', false, 'message', 'Ihale suresi dolmus.');
  end if;

  select *
  into v_warehouse
  from public.warehouses
  where id = p_warehouse_id
    and player_id = v_player_id
    and is_active = true
  for update;

  if not found then
    return jsonb_build_object('success', false, 'message', 'Depo bulunamadi.');
  end if;

  select coalesce(t.title, 'Ihale')
  into v_tender_title
  from public.tenders t
  where t.id = v_player_tender.tender_id;

  select coalesce(sum(td.quantity), 0)::integer
  into v_in_transit_quantity
  from public.tender_deliveries td
  where td.player_tender_id = v_player_tender.id
    and td.status = 'in_transit';

  v_same_city := v_warehouse.city_id = v_player_tender.city_id;

  if v_same_city then
    v_distance_km := 0;
    v_estimated_duration_minutes := 5;
  else
    select round(
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
    into v_distance_km
    from public.cities sc
    join public.cities tc on tc.id = v_player_tender.city_id
    where sc.id = v_warehouse.city_id;

    v_estimated_duration_minutes := greatest(
      10,
      ceil((greatest(coalesce(v_distance_km, 0), 1) / 80.0) * 12.0)
    )::integer;
  end if;

  v_finish_at := v_now + make_interval(mins => v_estimated_duration_minutes);

  if v_finish_at > v_player_tender.deadline_at then
    return jsonb_build_object(
      'success', false,
      'message', 'Bu depodan cikacak teslimat son tarihe yetismiyor.'
    );
  end if;

  v_remaining_quantity := greatest(
    v_player_tender.required_quantity - v_player_tender.delivered_quantity - v_in_transit_quantity,
    0
  );
  if v_remaining_quantity <= 0 then
    return jsonb_build_object('success', false, 'message', 'Ihale icin bekleyen ihtiyac kalmadi.');
  end if;

  v_selected_quantity := least(p_quantity, v_remaining_quantity);

  select
    ws.id,
    ws.quantity,
    ws.quality_level
  into v_slot
  from public.warehouse_slots ws
  where ws.warehouse_id = v_warehouse.id
    and ws.product_id = v_player_tender.product_id
    and ws.quality_level >= v_player_tender.quality_level
    and coalesce(ws.quantity, 0) > 0
  order by ws.quality_level asc, ws.id asc
  for update;

  if not found then
    return jsonb_build_object('success', false, 'message', 'Depoda uygun kalite stok bulunamadi.');
  end if;

  if coalesce(v_slot.quantity, 0) <= 0 then
    return jsonb_build_object('success', false, 'message', 'Depoda kullanilabilir stok yok.');
  end if;

  v_selected_quantity := least(v_selected_quantity, v_slot.quantity);

  update public.warehouse_slots
  set quantity = quantity - v_selected_quantity,
      updated_at = v_now
  where id = v_slot.id;

  insert into public.tender_deliveries (
    player_tender_id,
    player_id,
    source_warehouse_id,
    vehicle_id,
    quantity,
    status,
    same_city,
    started_at,
    finish_at
  )
  values (
    v_player_tender.id,
    v_player_id,
    v_warehouse.id,
    p_vehicle_id,
    v_selected_quantity,
    'in_transit',
    v_same_city,
    v_now,
    v_finish_at
  )
  returning id into v_delivery_id;

  update public.player_tenders
  set updated_at = v_now
  where id = v_player_tender.id;

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
    v_player_id,
    'event',
    'tender_delivery_started',
    'Ihale Teslimati Basladi',
    format('%s icin %s adet urun yola cikarildi.', v_tender_title, v_selected_quantity),
    'player_tender',
    v_player_tender.id,
    'info',
    'unread',
    jsonb_build_object(
      'player_tender_id', v_player_tender.id,
      'tender_id', v_player_tender.tender_id,
      'delivery_id', v_delivery_id,
      'source_warehouse_id', v_warehouse.id,
      'quantity', v_selected_quantity,
      'finish_at', v_finish_at,
      'estimated_duration_minutes', v_estimated_duration_minutes,
      'distance_km', v_distance_km
    ),
    format('tender:delivery_started:%s', v_delivery_id)
  )
  on conflict (player_id, dedupe_key) do nothing;

  return jsonb_build_object(
    'success', true,
    'delivery_id', v_delivery_id,
    'player_tender_id', v_player_tender.id,
    'quantity', v_selected_quantity,
    'finish_at', v_finish_at,
    'estimated_duration_minutes', v_estimated_duration_minutes,
    'distance_km', v_distance_km,
    'message', 'Ihale teslimati yola cikti.'
  );
end;
$$;
