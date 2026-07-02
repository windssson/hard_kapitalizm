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
  v_default_vehicle_id constant uuid := '00000000-0000-0000-0000-000000000000'::uuid;
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
  v_transport_cost numeric := 0;
  v_product_unit_volume numeric := 0;
  v_total_volume numeric := 0;
  v_cash_before numeric := 0;
  v_vehicle_option record;
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

  select coalesce(p.birim_hacim, 0)
  into v_product_unit_volume
  from public.products p
  where p.id = v_player_tender.product_id;

  v_total_volume := greatest(v_selected_quantity * greatest(v_product_unit_volume, 0), 0.0001);

  if v_same_city then
    v_distance_km := 0;
    v_estimated_duration_minutes := 5;
    v_transport_cost := 0;
  else
    if p_vehicle_id is null or p_vehicle_id = v_default_vehicle_id then
      return jsonb_build_object(
        'success', false,
        'message', 'Sehirler arasi teslimatta arac secmelisin.'
      );
    end if;

    select *
    into v_vehicle_option
    from public.get_route_transfer_vehicle_options(
      v_warehouse.city_id,
      v_player_tender.city_id,
      v_total_volume
    ) opt
    where opt.vehicle_id = p_vehicle_id
      and opt.can_select = true
    limit 1;

    if not found then
      return jsonb_build_object(
        'success', false,
        'message', 'Secilen arac bu teslimat icin artik uygun degil.'
      );
    end if;

    v_distance_km := coalesce(v_vehicle_option.distance_km, 0);
    v_estimated_duration_minutes := greatest(
      1,
      ceil(coalesce(v_vehicle_option.estimated_duration_seconds, 0) / 60.0)
    )::integer;
    v_transport_cost := coalesce(v_vehicle_option.total_price, 0);

  end if;

  v_finish_at := v_now + make_interval(mins => v_estimated_duration_minutes);

  if v_finish_at > v_player_tender.deadline_at then
    return jsonb_build_object(
      'success', false,
      'message', 'Bu depodan cikacak teslimat son tarihe yetismiyor.'
    );
  end if;

  if not v_same_city then
    select coalesce(cash, 0)
    into v_cash_before
    from public.players
    where id = v_player_id
    for update;

    if v_cash_before < v_transport_cost then
      return jsonb_build_object(
        'success', false,
        'message', 'Secilen arac icin yeterli nakit yok.'
      );
    end if;

    if v_transport_cost > 0 then
      update public.players
      set cash = cash - v_transport_cost
      where id = v_player_id;

      perform public.log_player_cash_change(
        v_player_id,
        -v_transport_cost,
        v_cash_before,
        'tender_delivery_transport_paid',
        format('Ihale teslimati nakliye bedeli odendi. Tender: %s', v_player_tender.tender_id),
        v_player_tender.id,
        'player_tender'
      );
    end if;

    update public.logistics_vehicles
    set status = 'on_route',
        current_fuel = greatest(current_fuel - ceil(coalesce(v_vehicle_option.fuel_needed, 0)), 0),
        condition = greatest(condition - ceil(coalesce(v_vehicle_option.condition_needed, 0)), 0),
        updated_at = v_now
    where id = p_vehicle_id;
  end if;

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
    finish_at,
    cost
  )
  values (
    v_player_tender.id,
    v_player_id,
    v_warehouse.id,
    case when v_same_city then null else p_vehicle_id end,
    v_selected_quantity,
    'in_transit',
    v_same_city,
    v_now,
    v_finish_at,
    v_transport_cost
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
      'vehicle_id', case when v_same_city then null else p_vehicle_id end,
      'quantity', v_selected_quantity,
      'finish_at', v_finish_at,
      'estimated_duration_minutes', v_estimated_duration_minutes,
      'distance_km', v_distance_km,
      'transport_cost', v_transport_cost
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
    'transport_cost', v_transport_cost,
    'message', 'Ihale teslimati yola cikti.'
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
  v_tender_title text := 'Ihale';
begin
  if v_target_player_id is null then
    return jsonb_build_object('success', false, 'message', 'Oturum acilmamis.');
  end if;

  for v_delivery in
    select td.*, t.title as tender_title
    from public.tender_deliveries td
    join public.player_tenders pt on pt.id = td.player_tender_id
    join public.tenders t on t.id = pt.tender_id
    where td.player_id = v_target_player_id
      and td.status = 'in_transit'
      and td.finish_at is not null
      and td.finish_at <= timezone('utc'::text, now())
    order by td.finish_at asc
  loop
    v_tender_title := coalesce(v_delivery.tender_title, 'Ihale');

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
      if v_delivery.vehicle_id is not null then
        update public.logistics_vehicles
        set status = 'idle',
            updated_at = timezone('utc'::text, now())
        where id = v_delivery.vehicle_id;
      end if;
      continue;
    end if;

    if v_player_tender.status <> 'active' then
      update public.tender_deliveries
      set status = 'failed',
          updated_at = timezone('utc'::text, now())
      where id = v_delivery.id;
      if v_delivery.vehicle_id is not null then
        update public.logistics_vehicles
        set status = 'idle',
            updated_at = timezone('utc'::text, now())
        where id = v_delivery.vehicle_id;
      end if;
      continue;
    end if;

    if v_player_tender.deadline_at < timezone('utc'::text, now()) then
      update public.tender_deliveries
      set status = 'failed_late',
          updated_at = timezone('utc'::text, now())
      where id = v_delivery.id;

      if v_delivery.vehicle_id is not null then
        update public.logistics_vehicles
        set status = 'idle',
            updated_at = timezone('utc'::text, now())
        where id = v_delivery.vehicle_id;
      end if;

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
        v_player_tender.player_id,
        'warning',
        'tender_delivery_late',
        'Ihale Teslimati Gecikti',
        format('%s teslimati son tarihten sonra ulasti ve sayilmadi.', v_tender_title),
        'player_tender',
        v_player_tender.id,
        'warning',
        'unread',
        jsonb_build_object(
          'player_tender_id', v_player_tender.id,
          'tender_id', v_player_tender.tender_id,
          'delivery_id', v_delivery.id,
          'quantity', v_delivery.quantity
        ),
        format('tender:delivery_late:%s', v_delivery.id)
      )
      on conflict (player_id, dedupe_key) do nothing;
      continue;
    end if;

    update public.tender_deliveries
    set status = 'completed',
        completed_at = timezone('utc'::text, now()),
        updated_at = timezone('utc'::text, now())
    where id = v_delivery.id;

    if v_delivery.vehicle_id is not null then
      update public.logistics_vehicles
      set status = 'idle',
          updated_at = timezone('utc'::text, now())
      where id = v_delivery.vehicle_id;
    end if;

    update public.player_tenders
    set delivered_quantity = least(required_quantity, delivered_quantity + v_delivery.quantity),
        updated_at = timezone('utc'::text, now())
    where id = v_player_tender.id;

    v_completed_count := v_completed_count + 1;

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
      v_player_tender.player_id,
      'event',
      'tender_delivery_completed',
      'Ihale Teslimati Ulasti',
      format('%s icin %s adet teslim edildi.', v_tender_title, v_delivery.quantity),
      'player_tender',
      v_player_tender.id,
      'info',
      'unread',
      jsonb_build_object(
        'player_tender_id', v_player_tender.id,
        'tender_id', v_player_tender.tender_id,
        'delivery_id', v_delivery.id,
        'quantity', v_delivery.quantity
      ),
      format('tender:delivery_completed:%s', v_delivery.id)
    )
    on conflict (player_id, dedupe_key) do nothing;

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
