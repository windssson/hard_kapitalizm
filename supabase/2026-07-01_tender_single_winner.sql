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
  v_deadline_at timestamptz;
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
    return jsonb_build_object('success', false, 'message', 'Ihale artik uygun degil.');
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

  v_deadline_at := timezone('utc'::text, now()) + make_interval(mins => v_tender.delivery_duration_minutes);

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
    v_deadline_at,
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

  update public.tenders
  set status = 'closed',
      updated_at = timezone('utc'::text, now())
  where id = v_tender.id;

  perform public.log_player_cash_change(
    v_player_id,
    -v_tender.bond_amount,
    v_player.cash,
    'tender_bond_paid',
    format('Ihale teminati odendi. Tender: %s', v_tender.id),
    v_player_tender_id,
    'player_tender'
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
    v_player_id,
    'event',
    'tender_accepted',
    'Ihale Kabul Edildi',
    format('%s kabul edildi. Ihale artik baskalarina kapanmistir.', v_tender.title),
    'player_tender',
    v_player_tender_id,
    'success',
    'unread',
    jsonb_build_object(
      'player_tender_id', v_player_tender_id,
      'tender_id', v_tender.id,
      'deadline_at', v_deadline_at,
      'required_quantity', v_tender.required_quantity,
      'bond_amount', v_tender.bond_amount
    ),
    format('tender:accepted:%s', v_player_tender_id)
  )
  on conflict (player_id, dedupe_key) do nothing;

  return jsonb_build_object(
    'success', true,
    'player_tender_id', v_player_tender_id,
    'deadline_at', v_deadline_at,
    'message', 'Ihale kabul edildi ve diger oyunculara kapandi.'
  );
end;
$$;
