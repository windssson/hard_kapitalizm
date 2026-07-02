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
  v_my_bid_tenders jsonb := '[]'::jsonb;
  v_my_recent_tenders jsonb := '[]'::jsonb;
  v_delivery_count integer := 0;
begin
  if v_player_id is null then
    return jsonb_build_object('success', false, 'message', 'Oturum acilmamis.');
  end if;

  perform public.ensure_open_tenders();
  perform public.process_tender_deliveries(v_player_id);
  perform public.process_player_tenders(v_player_id);

  with bid_stats as (
    select
      tb.tender_id,
      count(*)::integer as bid_count,
      min(tb.bid_amount) as lowest_bid_amount
    from public.tender_bids tb
    where tb.status = 'active'
    group by tb.tender_id
  ),
  player_bid as (
    select
      tb.tender_id,
      tb.bid_amount
    from public.tender_bids tb
    where tb.player_id = v_player_id
      and tb.status = 'active'
  )
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
        'award_type', t.award_type,
        'bid_count',
          case
            when t.award_type = 'lowest_bid' then coalesce(bs.bid_count, 0)
            else 0
          end,
        'lowest_bid_amount',
          case
            when t.award_type = 'lowest_bid' then bs.lowest_bid_amount
            else null
          end,
        'has_player_bid',
          case
            when t.award_type = 'lowest_bid' then pb.tender_id is not null
            else false
          end,
        'player_bid_amount',
          case
            when t.award_type = 'lowest_bid' then pb.bid_amount
            else null
          end,
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
  left join bid_stats bs on bs.tender_id = t.id
  left join player_bid pb on pb.tender_id = t.id
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
        'completed_at', pt.completed_at,
        'failed_at', pt.failed_at,
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

  with bid_stats as (
    select
      tb.tender_id,
      count(*)::integer as bid_count,
      min(tb.bid_amount) as lowest_bid_amount
    from public.tender_bids tb
    where tb.status = 'active'
    group by tb.tender_id
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'tender_id', t.id,
        'title', t.title,
        'city_name', c.name,
        'product_name', p.urun_adi,
        'product_icon', p.urun_iconu,
        'award_type', t.award_type,
        'bid_amount', tb.bid_amount,
        'bond_paid', tb.bond_paid,
        'bid_count', coalesce(bs.bid_count, 0),
        'lowest_bid_amount', bs.lowest_bid_amount,
        'accept_until', t.accept_until,
        'status', tb.status
      )
      order by t.accept_until asc
    ),
    '[]'::jsonb
  )
  into v_my_bid_tenders
  from public.tender_bids tb
  join public.tenders t on t.id = tb.tender_id
  join public.cities c on c.id = t.city_id
  join public.products p on p.id = t.product_id
  left join bid_stats bs on bs.tender_id = t.id
  where tb.player_id = v_player_id
    and tb.status = 'active'
    and t.status = 'open'
    and t.accept_until > timezone('utc'::text, now());

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
        'completed_at', pt.completed_at,
        'failed_at', pt.failed_at,
        'status', pt.status
      )
      order by coalesce(pt.completed_at, pt.failed_at, pt.updated_at) desc
    ),
    '[]'::jsonb
  )
  into v_my_recent_tenders
  from (
    select *
    from public.player_tenders
    where player_id = v_player_id
      and status in ('completed', 'failed')
    order by coalesce(completed_at, failed_at, updated_at) desc
    limit 8
  ) pt
  join public.tenders t on t.id = pt.tender_id
  join public.cities c on c.id = pt.city_id
  join public.products p on p.id = pt.product_id;

  select count(*)
  into v_delivery_count
  from public.tender_deliveries td
  where td.player_id = v_player_id
    and td.status = 'in_transit';

  return jsonb_build_object(
    'success', true,
    'open_tenders', v_open_tenders,
    'my_active_tenders', v_my_active_tenders,
    'my_bid_tenders', v_my_bid_tenders,
    'my_recent_tenders', v_my_recent_tenders,
    'delivery_count', v_delivery_count,
    'server_time', timezone('utc'::text, now())
  );
end;
$$;
