-- Gamify Tender Notifications
-- 1. accept_tender: "🏆 İhaleyi Kaptın Patron!"
-- 2. complete_player_tender: "💰 İhale Kasayı Doldurdu!"
-- 3. process_player_tenders: "⏱️ İhale Süresi Doldu!"
-- 4. cancel_player_tender: "🛑 İhale Feshedildi"

CREATE OR REPLACE FUNCTION public.accept_tender(p_tender_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
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

  select * into v_player from public.players where id = v_player_id for update;
  if not found then
    return jsonb_build_object('success', false, 'message', 'Oyuncu bulunamadi.');
  end if;

  select * into v_tender from public.tenders where id = p_tender_id for update;
  if not found then
    return jsonb_build_object('success', false, 'message', 'Ihale bulunamadi.');
  end if;

  if v_tender.award_type <> 'first_claim' then
    return jsonb_build_object('success', false, 'message', 'Bu ihale teklif usulu ile calisiyor.');
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
    select 1 from public.player_tenders pt
    where pt.player_id = v_player_id and pt.tender_id = v_tender.id
  ) then
    return jsonb_build_object('success', false, 'message', 'Bu ihaleye zaten katildin.');
  end if;

  if coalesce(v_player.level, 1) < v_tender.min_player_level or coalesce(v_player.cash, 0) < v_tender.bond_amount then
    return jsonb_build_object('success', false, 'message', 'Teminat icin yeterli nakit yok.');
  end if;

  update public.players set cash = cash - v_tender.bond_amount where id = v_player_id;

  v_deadline_at := timezone('utc'::text, now()) + make_interval(mins => v_tender.delivery_duration_minutes);

  insert into public.player_tenders (
    player_id, tender_id, accepted_at, deadline_at, bond_paid, required_quantity,
    delivered_quantity, reward_cash, product_id, quality_level, city_id, status
  )
  values (
    v_player_id, v_tender.id, timezone('utc'::text, now()), v_deadline_at, v_tender.bond_amount,
    v_tender.required_quantity, 0, v_tender.reward_cash, v_tender.product_id, v_tender.quality_level,
    v_tender.city_id, 'active'
  )
  returning id into v_player_tender_id;

  update public.tenders set status = 'closed', updated_at = timezone('utc'::text, now()) where id = v_tender.id;

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
    '🏆 İhaleyi Kaptın Patron!',
    format('%s ihalesi şirketinize bağlandı! Hemen teslimata başla, süreyi kaçırma.', v_tender.title),
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
    'message', 'Ihale kabul edildi ve sana atandi.',
    'changed', jsonb_build_object(
      'player', public.get_player_profile(v_player_id)
    )
  );
end;
$function$;


CREATE OR REPLACE FUNCTION public.complete_player_tender(p_player_tender_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
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
    '💰 İhale Kasayı Doldurdu!',
    format('%s teslimatı başarıyla bitti! Hakediş ve teminat hesabına aktarıldı.', v_tender_title),
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
$function$;


CREATE OR REPLACE FUNCTION public.process_player_tenders(p_player_id uuid default null)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
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
      '⏱️ İhale Süresi Doldu!',
      format(
        '%s zamanında tamamlanamadı. %s/%s adet teslim edildi, teminat yandı.',
        coalesce(v_failed.title, 'İhale'),
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
$function$;
