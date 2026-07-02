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
  v_tender_title text := 'Ihale';
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

  select coalesce(t.title, 'Ihale')
  into v_tender_title
  from public.tenders t
  where t.id = v_player_tender.tender_id;

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
    'tender_completed',
    'Ihale Tamamlandi',
    format('%s basariyla tamamlandi. Odul ve teminat hesabina aktarildi.', v_tender_title),
    'player_tender',
    v_player_tender.id,
    'success',
    'unread',
    jsonb_build_object(
      'player_tender_id', v_player_tender.id,
      'tender_id', v_player_tender.tender_id,
      'required_quantity', v_player_tender.required_quantity,
      'delivered_quantity', v_player_tender.delivered_quantity,
      'reward_cash', v_player_tender.reward_cash,
      'bond_paid', v_player_tender.bond_paid
    ),
    format('tender:completed:%s', v_player_tender.id)
  )
  on conflict (player_id, dedupe_key) do nothing;

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
  v_failed record;
begin
  if v_target_player_id is null then
    return jsonb_build_object('success', false, 'message', 'Oturum acilmamis.');
  end if;

  for v_failed in
    update public.player_tenders pt
    set status = 'failed',
        failed_at = timezone('utc'::text, now()),
        updated_at = timezone('utc'::text, now())
    from public.tenders t
    where pt.player_id = v_target_player_id
      and pt.status = 'active'
      and pt.deadline_at <= timezone('utc'::text, now())
      and pt.delivered_quantity < pt.required_quantity
      and t.id = pt.tender_id
    returning pt.id,
      pt.player_id,
      pt.tender_id,
      pt.required_quantity,
      pt.delivered_quantity,
      t.title
  loop
    v_failed_count := v_failed_count + 1;

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
      v_failed.player_id,
      'warning',
      'tender_failed',
      'Ihale Basarisiz Oldu',
      format(
        '%s zamaninda tamamlanamadi. %s/%s adet teslim edildi, teminat yandi.',
        coalesce(v_failed.title, 'Ihale'),
        coalesce(v_failed.delivered_quantity, 0),
        coalesce(v_failed.required_quantity, 0)
      ),
      'player_tender',
      v_failed.id,
      'warning',
      'unread',
      jsonb_build_object(
        'player_tender_id', v_failed.id,
        'tender_id', v_failed.tender_id,
        'required_quantity', v_failed.required_quantity,
        'delivered_quantity', v_failed.delivered_quantity
      ),
      format('tender:failed:%s', v_failed.id)
    )
    on conflict (player_id, dedupe_key) do nothing;
  end loop;

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
    format('%s kabul edildi. Teslim suresi basladi.', v_tender.title),
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
    'message', 'Ihaleye katildin. Teslim suresi basladi.'
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
  v_delivery_id uuid;
  v_finish_at timestamptz;
  v_tender_title text := 'Ihale';
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

  v_same_city := v_warehouse.city_id = v_player_tender.city_id;

  if not v_same_city then
    return jsonb_build_object(
      'success', false,
      'message', 'Sehirler arasi ihale teslimati foundation asamasinda henuz aktif degil.'
    );
  end if;

  v_remaining_quantity := greatest(v_player_tender.required_quantity - v_player_tender.delivered_quantity, 0);
  if v_remaining_quantity <= 0 then
    return jsonb_build_object('success', false, 'message', 'Ihale zaten tamamlanmis.');
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

  v_finish_at := v_now;

  insert into public.tender_deliveries (
    player_tender_id,
    player_id,
    warehouse_id,
    vehicle_id,
    quantity,
    status,
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
    format('%s icin %s adet urun depodan cikti.', v_tender_title, v_selected_quantity),
    'player_tender',
    v_player_tender.id,
    'info',
    'unread',
    jsonb_build_object(
      'player_tender_id', v_player_tender.id,
      'tender_id', v_player_tender.tender_id,
      'delivery_id', v_delivery_id,
      'warehouse_id', v_warehouse.id,
      'quantity', v_selected_quantity
    ),
    format('tender:delivery_started:%s', v_delivery_id)
  )
  on conflict (player_id, dedupe_key) do nothing;

  if v_same_city then
    perform public.process_tender_deliveries(v_player_id);
  end if;

  return jsonb_build_object(
    'success', true,
    'delivery_id', v_delivery_id,
    'player_tender_id', v_player_tender.id,
    'quantity', v_selected_quantity,
    'finish_at', v_finish_at,
    'message', 'Ihale teslimati baslatildi.'
  );
end;
$$;
