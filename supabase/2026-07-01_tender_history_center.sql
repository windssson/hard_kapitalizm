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
  v_my_recent_tenders jsonb := '[]'::jsonb;
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
    'my_recent_tenders', v_my_recent_tenders,
    'delivery_count', v_delivery_count,
    'server_time', timezone('utc'::text, now())
  );
end;
$$;
