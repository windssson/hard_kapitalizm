create or replace function public.cancel_player_tender(p_player_tender_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = 'public'
as $$
declare
  v_player_id uuid := auth.uid();
  v_now timestamptz := timezone('utc'::text, now());
  v_player_tender public.player_tenders%rowtype;
  v_tender_title text := 'Ihale';
  v_cancelled_delivery_count integer := 0;
  v_cancelled_quantity integer := 0;
begin
  if v_player_id is null then
    return jsonb_build_object('success', false, 'message', 'Oturum acilmamis.');
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
    return jsonb_build_object('success', false, 'message', 'Sadece aktif ihale iptal edilebilir.');
  end if;

  select coalesce(t.title, 'Ihale')
  into v_tender_title
  from public.tenders t
  where t.id = v_player_tender.tender_id;

  select
    count(*)::integer,
    coalesce(sum(td.quantity), 0)::integer
  into v_cancelled_delivery_count, v_cancelled_quantity
  from public.tender_deliveries td
  where td.player_tender_id = v_player_tender.id
    and td.status = 'in_transit';

  update public.tender_deliveries
  set status = 'cancelled',
      updated_at = v_now
  where player_tender_id = v_player_tender.id
    and status = 'in_transit';

  update public.logistics_vehicles lv
  set status = 'idle',
      updated_at = v_now
  where exists (
    select 1
    from public.tender_deliveries td
    where td.player_tender_id = v_player_tender.id
      and td.vehicle_id = lv.id
      and td.status = 'cancelled'
  );

  update public.player_tenders
  set status = 'cancelled',
      updated_at = v_now
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
    v_player_tender.player_id,
    'warning',
    'tender_cancelled',
    'Ihale Iptal Edildi',
    format(
      '%s iptal edildi. Teminat yandi ve yoldaki %s adet sevkiyat iptal oldu.',
      v_tender_title,
      v_cancelled_quantity
    ),
    'player_tender',
    v_player_tender.id,
    'warning',
    'unread',
    jsonb_build_object(
      'player_tender_id', v_player_tender.id,
      'tender_id', v_player_tender.tender_id,
      'cancelled_delivery_count', v_cancelled_delivery_count,
      'cancelled_quantity', v_cancelled_quantity,
      'bond_paid', v_player_tender.bond_paid
    ),
    format('tender:cancelled:%s', v_player_tender.id)
  )
  on conflict (player_id, dedupe_key) do nothing;

  return jsonb_build_object(
    'success', true,
    'player_tender_id', v_player_tender.id,
    'status', 'cancelled',
    'cancelled_delivery_count', v_cancelled_delivery_count,
    'cancelled_quantity', v_cancelled_quantity,
    'message', 'Ihale iptal edildi. Teminat ve yoldaki sevkiyat yandi.'
  );
end;
$$;
