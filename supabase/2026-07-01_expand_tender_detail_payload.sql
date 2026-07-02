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
  v_city_name text;
  v_product_name text;
  v_product_icon text;
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
          'remaining_quantity', greatest(v_player_tender.required_quantity - v_player_tender.delivered_quantity, 0),
          'status', v_player_tender.status
        )
      end,
    'warehouse_options', v_warehouse_options
  );
end;
$$;
