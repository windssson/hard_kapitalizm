-- Update get_tender_detail to return average unit cost of inventory in warehouses and base sale price of the product
CREATE OR REPLACE FUNCTION public.get_tender_detail(
    p_tender_id uuid DEFAULT NULL::uuid,
    p_player_tender_id uuid DEFAULT NULL::uuid
) RETURNS jsonb AS $$
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
  v_product_base_price numeric := 0;
  v_in_transit_quantity integer := 0;
begin
  if v_player_id is null then
    return jsonb_build_object('success', false, 'message', 'Oturum bulunamadi.');
  end if;

  if p_player_tender_id is null and p_tender_id is null then
    return jsonb_build_object('success', false, 'message', 'Ihale secilmedi.');
  end if;

  if p_player_tender_id is not null then
    select pt.* into v_player_tender
    from public.player_tenders pt
    where pt.id = p_player_tender_id and pt.player_id = v_player_id;

    if not found then
      return jsonb_build_object('success', false, 'message', 'Oyuncu ihalesi bulunamadi.');
    end if;

    select coalesce(sum(td.quantity), 0)::integer
    into v_in_transit_quantity
    from public.tender_deliveries td
    where td.player_tender_id = v_player_tender.id and td.status = 'in_transit';

    select t.* into v_tender from public.tenders t where t.id = v_player_tender.tender_id;
    if not found then
      return jsonb_build_object('success', false, 'message', 'Ihale bulunamadi.');
    end if;
  else
    select t.* into v_tender
    from public.tenders t
    where t.id = p_tender_id
      and t.status = 'open'
      and t.accept_until > timezone('utc'::text, now());

    v_has_tender := found;

    if v_has_tender and v_tender.award_type = 'lowest_bid' then
      select tb.* into v_player_bid
      from public.tender_bids tb
      where tb.tender_id = v_tender.id and tb.player_id = v_player_id;
    end if;
  end if;

  if p_player_tender_id is null and not v_has_tender then
    return jsonb_build_object('success', false, 'message', 'Ihale bulunamadi.');
  end if;

  select c.name into v_city_name from public.cities c where c.id = v_tender.city_id;
  select p.urun_adi, p.urun_iconu, coalesce(p.birim_hacim, 0), coalesce(p.baz_satis_fiyati, 0)
  into v_product_name, v_product_icon, v_product_unit_volume, v_product_base_price
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
        'unit_cost', coalesce(inv.avg_cost, 0),
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
      sum(greatest(coalesce(ws.quantity, 0), 0))::integer as available_quantity,
      coalesce(
        sum(coalesce(ws.cost, 0) * greatest(coalesce(ws.quantity, 0), 0))::numeric / 
        nullif(sum(greatest(coalesce(ws.quantity, 0), 0)), 0),
        0
      )::numeric as avg_cost
    from public.warehouse_slots ws
    where ws.product_id = coalesce(v_player_tender.product_id, v_tender.product_id)
      and ws.quality_level >= coalesce(v_player_tender.quality_level, v_tender.quality_level)
      and coalesce(ws.quantity, 0) > 0
    group by ws.warehouse_id
  ) inv on inv.warehouse_id = w.id
  where w.player_id = v_player_id and w.is_active = true;

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
    where td.player_tender_id = v_player_tender.id and td.status = 'in_transit';
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
      'product_base_price', coalesce(v_product_base_price, 0),
      'quality_level', v_tender.quality_level,
      'required_quantity', v_tender.required_quantity,
      'reward_cash', v_tender.reward_cash,
      'bond_amount', v_tender.bond_amount,
      'award_type', coalesce(v_tender.award_type, 'lowest_bid'),
      'accept_until', v_tender.accept_until,
      'delivery_duration_minutes', v_tender.delivery_duration_minutes,
      'status', v_tender.status
    ),
    'player_tender', case
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
    'player_bid', case
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
$$ LANGUAGE plpgsql;
