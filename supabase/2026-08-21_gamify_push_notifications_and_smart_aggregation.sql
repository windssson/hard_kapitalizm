-- Gamify Push Notifications & Implement Smart Aggregation System
-- 1. Game-themed engaging titles and descriptions across all notification generators.
-- 2. Smart Executive Briefing aggregation for offline players (1 unified notification instead of spamming 5).
-- 3. Dynamic category summaries and anti-spam cooldown protection.

-- 1. Build Player Attention Notifications (In-game alerts & Push Queue feeder)
CREATE OR REPLACE FUNCTION public.build_player_attention_notifications(p_player_id uuid DEFAULT auth.uid())
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_player_id uuid := coalesce(p_player_id, auth.uid());
  v_keys text[] := array[]::text[];
  v_key text;
  v_count integer := 0;
  v_now timestamptz := timezone('utc', now());
  v_row record;
begin
  if v_player_id is null then
    return jsonb_build_object('success', false, 'message', 'Oyuncu bulunamadi.');
  end if;

  -- 1. Mağaza Boş Slotlar
  for v_row in
    select s.id, s.name, count(*)::int as empty_slot_count
    from public.stores s
    join public.store_slots ss on ss.store_id = s.id
    where s.player_id = v_player_id
      and s.is_active = true
      and ss.is_active = true
      and ss.product_id is null
    group by s.id, s.name
    having count(*) > 0
  loop
    v_key := 'store_empty_slots:' || v_row.id::text;
    v_keys := array_append(v_keys, v_key);
    perform public.create_player_notification(
      v_player_id,
      'warning',
      'store_blocked',
      '🏪 Boş Raflar Para Kaybettiriyor!',
      v_row.name || ' şubende vitrine çıkacak ürün bekleyen ' || v_row.empty_slot_count::text || ' boş raf var. Hemen ürün yerleştir!',
      'store',
      v_row.id,
      'warning',
      jsonb_build_object('empty_slot_count', v_row.empty_slot_count),
      v_key
    );
    v_count := v_count + 1;
  end loop;

  -- 2. Mağazada Stok Tükendi
  for v_row in
    select s.id, s.name, count(*)::int as out_of_stock_slot_count
    from public.stores s
    join public.store_slots ss on ss.store_id = s.id
    where s.player_id = v_player_id
      and s.is_active = true
      and ss.is_active = true
      and ss.product_id is not null
      and coalesce(ss.quantity, 0) <= 0
      and coalesce(ss.pending_quantity, 0) <= 0
    group by s.id, s.name
    having count(*) > 0
  loop
    v_key := 'store_out_of_stock:' || v_row.id::text;
    v_keys := array_append(v_keys, v_key);
    perform public.create_player_notification(
      v_player_id,
      'warning',
      'store_blocked',
      '🚨 Raflar Talandı Patron!',
      v_row.name || ' mağazanda ' || v_row.out_of_stock_slot_count::text || ' rafta stok sıfırlandı! Kasalara para akması için mal sevk et.',
      'store',
      v_row.id,
      'warning',
      jsonb_build_object('out_of_stock_slot_count', v_row.out_of_stock_slot_count),
      v_key
    );
    v_count := v_count + 1;
  end loop;

  -- 3. Pasif İşletmeler
  for v_row in
    select entity_kind, entity_id, entity_name
    from (
      select 'store'::text as entity_kind, s.id as entity_id, s.name as entity_name
      from public.stores s
      where s.player_id = v_player_id
        and s.is_active = false
      union all
      select 'factory'::text as entity_kind, f.id as entity_id, f.name as entity_name
      from public.factories f
      where f.player_id = v_player_id
        and f.is_active = false
      union all
      select 'field'::text as entity_kind, f.id as entity_id, f.name as entity_name
      from public.fields f
      where f.player_id = v_player_id
        and f.is_active = false
      union all
      select 'farm'::text as entity_kind, f.id as entity_id, f.name as entity_name
      from public.farms f
      where f.player_id = v_player_id
        and f.is_active = false
      union all
      select 'mine'::text as entity_kind, m.id as entity_id, m.name as entity_name
      from public.mines m
      where m.player_id = v_player_id
        and m.is_active = false
    ) inactive_entities
  loop
    v_key := 'inactive_reminder:' || v_row.entity_kind || ':' || v_row.entity_id::text;
    v_keys := array_append(v_keys, v_key);
    perform public.create_player_notification(
      v_player_id,
      'event',
      'inactive_reminder',
      '💤 Tesis Uykuda Kaldı!',
      v_row.entity_name || ' şu anda kapalı duruyor. Çarkları döndürmek için işletmeyi aktif et!',
      v_row.entity_kind,
      v_row.entity_id,
      'info',
      jsonb_build_object('reason', 'inactive'),
      v_key
    );
  end loop;

  -- 4. Fabrikada Ürün Seçili Değil
  for v_row in
    select f.id, f.name
    from public.factories f
    where f.player_id = v_player_id
      and f.is_active = true
      and f.product_id is null
  loop
    v_key := 'factory_product_missing:' || v_row.id::text;
    v_keys := array_append(v_keys, v_key);
    perform public.create_player_notification(
      v_player_id,
      'warning',
      'production_blocked',
      '🏭 Bacalar Tütmüyor Patron!',
      v_row.name || ' fabrikasında üretim bandı boş! Ne üreteceğini seç, işçiler üretime başlasın.',
      'factory',
      v_row.id,
      'warning',
      '{}'::jsonb,
      v_key
    );
    v_count := v_count + 1;
  end loop;

  -- 5. Fabrikada Hammadde Eksik
  for v_row in
    select f.id, f.name
    from public.factories f
    join public.products p on p.id = f.product_id
    where f.player_id = v_player_id
      and f.is_active = true
      and f.product_id is not null
      and exists (
        select 1
        from (
          values
            (p.hammadde_1_id, p.hammadde_1_miktar),
            (p.hammadde_2_id, p.hammadde_2_miktar),
            (p.hammadde_3_id, p.hammadde_3_miktar)
        ) as req(product_id, qty)
        left join public.production_inventory pi
          on pi.owner_kind = 'factory'
         and pi.owner_id = f.id
         and pi.inventory_type = 'input'
         and pi.product_id = req.product_id
        where req.product_id is not null
          and coalesce(req.qty, 0) > coalesce(pi.quantity, 0)
      )
  loop
    v_key := 'factory_input_missing:' || v_row.id::text;
    v_keys := array_append(v_keys, v_key);
    perform public.create_player_notification(
      v_player_id,
      'warning',
      'production_blocked',
      '⚠️ Çarklar Durdu, İşçiler Bekliyor!',
      v_row.name || ' fabrikası için hammadde tükendi. Tedarik sağla, üretimi kaçırma!',
      'factory',
      v_row.id,
      'warning',
      '{}'::jsonb,
      v_key
    );
    v_count := v_count + 1;
  end loop;

  -- 6. Fabrika Çıktı Deposu Dolu
  for v_row in
    select f.id, f.name
    from public.factories f
    left join public.production_inventory pi
      on pi.owner_kind = 'factory'
     and pi.owner_id = f.id
     and pi.inventory_type = 'output'
    where f.player_id = v_player_id
      and f.is_active = true
      and f.output_capacity > 0
    group by f.id, f.name, f.output_capacity
    having coalesce(sum(coalesce(pi.quantity, 0) + coalesce(pi.pending_quantity, 0)), 0) >= f.output_capacity
  loop
    v_key := 'factory_output_full:' || v_row.id::text;
    v_keys := array_append(v_keys, v_key);
    perform public.create_player_notification(
      v_player_id,
      'warning',
      'production_blocked',
      '📦 Fabrika Ağzına Kadar Doldu!',
      v_row.name || ' fabrikasında yer kalmadı, üretim kilitlendi! Malları depolara sevk et.',
      'factory',
      v_row.id,
      'warning',
      '{}'::jsonb,
      v_key
    );
    v_count := v_count + 1;
  end loop;

  -- 7. Boş Tarla / Çiftlik Slotu
  for v_row in
    select owner_kind, owner_id, owner_name, count(*)::int as empty_slot_count
    from (
      select ps.owner_kind, ps.owner_id, f.name as owner_name
      from public.production_slots ps
      join public.fields f on f.id = ps.owner_id
      where ps.owner_kind = 'field'
        and f.player_id = v_player_id
        and f.is_active = true
        and ps.is_active = true
        and ps.product_id is null
      union all
      select ps.owner_kind, ps.owner_id, f.name as owner_name
      from public.production_slots ps
      join public.farms f on f.id = ps.owner_id
      where ps.owner_kind = 'farm'
        and f.player_id = v_player_id
        and f.is_active = true
        and ps.is_active = true
        and ps.product_id is null
    ) slots
    group by owner_kind, owner_id, owner_name
  loop
    v_key := v_row.owner_kind || '_empty_slots:' || v_row.owner_id::text;
    v_keys := array_append(v_keys, v_key);
    perform public.create_player_notification(
      v_player_id,
      'warning',
      'production_blocked',
      '🌾 Toprak Boşta Kalmasın!',
      v_row.owner_name || ' tesisinde ekilmeyi bekleyen ' || v_row.empty_slot_count::text || ' boş slot var. Tohumları serp, kazancı kaçırma!',
      v_row.owner_kind,
      v_row.owner_id,
      'warning',
      jsonb_build_object('empty_slot_count', v_row.empty_slot_count),
      v_key
    );
    v_count := v_count + 1;
  end loop;

  -- 8. Çiftlik / Tarlada Hammadde Eksik
  for v_row in
    with active_slots as (
      select
        ps.owner_kind,
        ps.owner_id,
        case
          when ps.owner_kind = 'field' then f.name
          when ps.owner_kind = 'farm' then fa.name
        end as owner_name,
        nullif(p.hammadde_1_id, '') as h1_id,
        coalesce(p.hammadde_1_miktar, 0) as h1_qty,
        nullif(p.hammadde_2_id, '') as h2_id,
        coalesce(p.hammadde_2_miktar, 0) as h2_qty,
        nullif(p.hammadde_3_id, '') as h3_id,
        coalesce(p.hammadde_3_miktar, 0) as h3_qty
      from public.production_slots ps
      join public.products p on p.id = ps.product_id
      left join public.fields f on ps.owner_kind = 'field' and f.id = ps.owner_id
      left join public.farms fa on ps.owner_kind = 'farm' and fa.id = ps.owner_id
      where ps.owner_kind in ('field', 'farm')
        and ps.is_active = true
        and ps.product_id is not null
        and (
          (ps.owner_kind = 'field' and f.player_id = v_player_id and f.is_active = true)
          or
          (ps.owner_kind = 'farm' and fa.player_id = v_player_id and fa.is_active = true)
        )
    ),
    required_inputs as (
      select owner_kind, owner_id, owner_name, h1_id as required_product_id, sum(h1_qty)::integer as required_qty
      from active_slots
      where h1_id is not null and h1_qty > 0
      group by owner_kind, owner_id, owner_name, h1_id
      union all
      select owner_kind, owner_id, owner_name, h2_id as required_product_id, sum(h2_qty)::integer as required_qty
      from active_slots
      where h2_id is not null and h2_qty > 0
      group by owner_kind, owner_id, owner_name, h2_id
      union all
      select owner_kind, owner_id, owner_name, h3_id as required_product_id, sum(h3_qty)::integer as required_qty
      from active_slots
      where h3_id is not null and h3_qty > 0
      group by owner_kind, owner_id, owner_name, h3_id
    ),
    aggregated_requirements as (
      select owner_kind, owner_id, owner_name, required_product_id, sum(required_qty)::integer as required_qty
      from required_inputs
      group by owner_kind, owner_id, owner_name, required_product_id
    )
    select distinct ar.owner_kind, ar.owner_id, ar.owner_name
    from aggregated_requirements ar
    left join public.production_inventory pi
      on pi.owner_kind = ar.owner_kind
     and pi.owner_id = ar.owner_id
     and pi.inventory_type = 'input'
     and pi.product_id = ar.required_product_id
     and pi.quality_level = 1
    where coalesce(pi.quantity, 0) < ar.required_qty
  loop
    v_key := v_row.owner_kind || '_input_missing:' || v_row.owner_id::text;
    v_keys := array_append(v_keys, v_key);
    perform public.create_player_notification(
      v_player_id,
      'warning',
      'production_blocked',
      '🚜 Yem & Tohum Bitti!',
      v_row.owner_name || ' için üretim girdileri tükendi. Depolarından ikmal yap!',
      v_row.owner_kind,
      v_row.owner_id,
      'warning',
      '{}'::jsonb,
      v_key
    );
    v_count := v_count + 1;
  end loop;

  -- 9. Tarla / Çiftlik Çıktı Deposu Dolu
  for v_row in
    select owner_kind, owner_id, owner_name
    from (
      select 'field'::text as owner_kind, f.id as owner_id, f.name as owner_name, f.output_capacity,
             coalesce(sum(coalesce(pi.quantity, 0) + coalesce(pi.pending_quantity, 0)), 0) as used_capacity
      from public.fields f
      left join public.production_inventory pi
        on pi.owner_kind = 'field'
       and pi.owner_id = f.id
       and pi.inventory_type = 'output'
      where f.player_id = v_player_id
        and f.is_active = true
      group by f.id, f.name, f.output_capacity
      union all
      select 'farm'::text as owner_kind, f.id as owner_id, f.name as owner_name, f.output_capacity,
             coalesce(sum(coalesce(pi.quantity, 0) + coalesce(pi.pending_quantity, 0)), 0) as used_capacity
      from public.farms f
      left join public.production_inventory pi
        on pi.owner_kind = 'farm'
       and pi.owner_id = f.id
       and pi.inventory_type = 'output'
      where f.player_id = v_player_id
        and f.is_active = true
      group by f.id, f.name, f.output_capacity
    ) owners
    where output_capacity > 0 and used_capacity >= output_capacity
  loop
    v_key := v_row.owner_kind || '_output_full:' || v_row.owner_id::text;
    v_keys := array_append(v_keys, v_key);
    perform public.create_player_notification(
      v_player_id,
      'warning',
      'production_blocked',
      '🚜 Hasat Depoları Taştı!',
      v_row.owner_name || ' tesisinin çıkış ambarı doldu. Ürünleri topla ve depoya aktar!',
      v_row.owner_kind,
      v_row.owner_id,
      'warning',
      '{}'::jsonb,
      v_key
    );
    v_count := v_count + 1;
  end loop;

  -- 10. Madende Ürün Seçili Değil
  for v_row in
    select m.id, m.name
    from public.mines m
    where m.player_id = v_player_id
      and m.is_active = true
      and m.product_id is null
  loop
    v_key := 'mine_product_missing:' || v_row.id::text;
    v_keys := array_append(v_keys, v_key);
    perform public.create_player_notification(
      v_player_id,
      'warning',
      'production_blocked',
      '⛏️ Kazmalar Boşta Bekliyor!',
      v_row.name || ' madeninde çıkarılacak cevheri seç, madenciler kazmaya başlasın.',
      'mine',
      v_row.id,
      'warning',
      '{}'::jsonb,
      v_key
    );
    v_count := v_count + 1;
  end loop;

  -- 11. Maden Çıktı Deposu Dolu
  for v_row in
    select m.id, m.name
    from public.mines m
    left join public.production_inventory pi
      on pi.owner_kind = 'mine'
     and pi.owner_id = m.id
     and pi.inventory_type = 'output'
    where m.player_id = v_player_id
      and m.is_active = true
      and m.output_capacity > 0
    group by m.id, m.name, m.output_capacity
    having coalesce(sum(coalesce(pi.quantity, 0) + coalesce(pi.pending_quantity, 0)), 0) >= m.output_capacity
  loop
    v_key := 'mine_output_full:' || v_row.id::text;
    v_keys := array_append(v_keys, v_key);
    perform public.create_player_notification(
      v_player_id,
      'warning',
      'production_blocked',
      '💎 Cevherler Depolara Sığmıyor!',
      v_row.name || ' madeninde yer kalmadı. Değerli madenleri depolara sevk et.',
      'mine',
      v_row.id,
      'warning',
      '{}'::jsonb,
      v_key
    );
    v_count := v_count + 1;
  end loop;

  -- 12. Pasif Nakliye Aracı
  for v_row in
    select lc.id, lc.name, count(*)::int as inactive_vehicle_count
    from public.logistics_companies lc
    join public.logistics_vehicles lv on lv.logistics_company_id = lc.id
    where lc.player_id = v_player_id
      and lv.status = 'inactive'
    group by lc.id, lc.name
    having count(*) > 0
  loop
    v_key := 'logistics_inactive_vehicles:' || v_row.id::text;
    v_keys := array_append(v_keys, v_key);
    perform public.create_player_notification(
      v_player_id,
      'warning',
      'logistics_attention',
      '🚛 Tırlar Garajda Yatıyor!',
      v_row.name || ' şirketinde ' || v_row.inactive_vehicle_count::text || ' araç kontak kapatmış bekliyor. Yola çıkar, para kazansınlar!',
      'logistics',
      v_row.id,
      'warning',
      jsonb_build_object('inactive_vehicle_count', v_row.inactive_vehicle_count),
      v_key
    );
    v_count := v_count + 1;
  end loop;

  -- 13. Araç Yakıtı Kritik
  for v_row in
    select lc.id, lc.name, count(*)::int as low_fuel_vehicle_count
    from public.logistics_companies lc
    join public.logistics_vehicles lv on lv.logistics_company_id = lc.id
    where lc.player_id = v_player_id
      and lv.status = 'idle'
      and lv.fuel_capacity > 0
      and coalesce(lv.current_fuel, 0) <= greatest(5, ceil(lv.fuel_capacity * 0.10)::integer)
    group by lc.id, lc.name
    having count(*) > 0
  loop
    v_key := 'logistics_low_fuel:' || v_row.id::text;
    v_keys := array_append(v_keys, v_key);
    perform public.create_player_notification(
      v_player_id,
      'warning',
      'logistics_attention',
      '⛽ Şoförler Yolda Kalmak Üzere!',
      v_row.name || ' filosundaki ' || v_row.low_fuel_vehicle_count::text || ' aracın ibresi dibe vurdu. Yolda kalmadan depoları fulle!',
      'logistics',
      v_row.id,
      'warning',
      jsonb_build_object('low_fuel_vehicle_count', v_row.low_fuel_vehicle_count),
      v_key
    );
    v_count := v_count + 1;
  end loop;

  -- 14. Araç Kondisyonu Düşük
  for v_row in
    select lc.id, lc.name, count(*)::int as low_condition_vehicle_count
    from public.logistics_companies lc
    join public.logistics_vehicles lv on lv.logistics_company_id = lc.id
    where lc.player_id = v_player_id
      and lv.status = 'idle'
      and coalesce(lv.condition, 100) <= 25
    group by lc.id, lc.name
    having count(*) > 0
  loop
    v_key := 'logistics_low_condition:' || v_row.id::text;
    v_keys := array_append(v_keys, v_key);
    perform public.create_player_notification(
      v_player_id,
      'warning',
      'logistics_attention',
      '🔧 Motor İmdat Veriyor!',
      v_row.name || ' filosundaki ' || v_row.low_condition_vehicle_count::text || ' araç sanayiye çekilmeli. Yolda arıza yapmadan bakıma al!',
      'logistics',
      v_row.id,
      'warning',
      jsonb_build_object('low_condition_vehicle_count', v_row.low_condition_vehicle_count),
      v_key
    );
    v_count := v_count + 1;
  end loop;

  -- Temizleme
  update public.player_notifications
  set
    status = 'resolved',
    resolved_at = coalesce(resolved_at, v_now),
    updated_at = v_now
  where player_id = v_player_id
    and (kind = 'warning' or category = 'inactive_reminder')
    and status <> 'resolved'
    and (cardinality(v_keys) = 0 or dedupe_key <> all(v_keys));

  return jsonb_build_object('success', true, 'active_warning_count', v_count);
end;
$function$;


-- 2. Logistics Transfer Completion Notification Trigger
CREATE OR REPLACE FUNCTION public.handle_logistics_transfer_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_product_name text;
begin
  if new.status = 'completed' and coalesce(old.status, '') <> 'completed' and coalesce(new.distance_km, 0) > 0 then
    select name into v_product_name
    from public.products
    where id = new.product_id;

    perform public.create_player_notification(
      new.buyer_player_id,
      'event',
      'transfer_completed',
      '🚚 Konvoy Depoya Yanaştı!',
      coalesce(v_product_name, 'Ürün') || ' sevkiyatı şehre ulaştı ve boşaltıldı. Ürünlerin hazır!',
      coalesce(new.buyer_entity_kind, case when new.buyer_store_id is not null then 'store' else 'warehouse' end),
      coalesce(new.buyer_store_id, new.buyer_warehouse_id),
      'success',
      jsonb_build_object(
        'transfer_id', new.id,
        'transfer_type', new.transfer_type,
        'product_id', new.product_id,
        'quantity', new.quantity
      ),
      'transfer_completed:' || new.id::text
    );
  end if;
  return new;
end;
$function$;


-- 3. Core function to Process, Aggregate, and Send Smart Push Notifications
CREATE OR REPLACE FUNCTION public.process_push_notification_queue()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
declare
  v_player_row record;
  v_token_row record;
  v_player_last_seen timestamp with time zone;
  v_is_online boolean;
  v_push_title text;
  v_push_message text;
  v_log_id uuid;
  v_processed_count integer := 0;
  v_skipped_count integer := 0;
  v_total_pending integer := 0;
  v_distinct_categories integer := 0;
  v_category_counts record;
  v_summary_parts text[] := array[]::text[];
  v_last_push_sent timestamp with time zone;
begin
  -- Loop through all players who have pending push notifications
  for v_player_row in
    select distinct player_id
    from public.push_notification_queue
    where status = 'pending'
  loop
    -- Check if player is online
    select last_seen_at into v_player_last_seen
    from public.players
    where id = v_player_row.player_id;

    v_is_online := (v_player_last_seen is not null and (timezone('utc', now()) - v_player_last_seen) <= interval '1 minute');

    if v_is_online then
      -- Player is online in-app, skip push notifications
      update public.push_notification_queue
      set status = 'skipped'
      where player_id = v_player_row.player_id
        and status = 'pending';
      v_skipped_count := v_skipped_count + 1;
      continue;
    end if;

    -- Anti-spam Cooldown: Don't send non-instant aggregated pushes more than once every 20 minutes to same offline player
    select max(sent_at) into v_last_push_sent
    from public.push_notification_logs
    where player_id = v_player_row.player_id;

    if v_last_push_sent is not null and (timezone('utc', now()) - v_last_push_sent) < interval '20 minutes' then
      -- Player was notified recently; keep in queue or skip duplicate
      continue;
    end if;

    -- Analyze player's pending notifications
    select count(*), count(distinct category)
    into v_total_pending, v_distinct_categories
    from public.push_notification_queue
    where player_id = v_player_row.player_id
      and status = 'pending';

    if v_total_pending = 0 then
      continue;
    end if;

    -- -------------------------------------------------------------
    -- CASE 1: Single notification in queue -> Send exact original alert
    -- -------------------------------------------------------------
    if v_total_pending = 1 then
      select title, message, notification_id
      into v_push_title, v_push_message, v_log_id
      from public.push_notification_queue
      where player_id = v_player_row.player_id
        and status = 'pending'
      limit 1;

    -- -------------------------------------------------------------
    -- CASE 2: Multiple notifications, but ALL from SAME category -> Focused Aggregation
    -- -------------------------------------------------------------
    elsif v_distinct_categories = 1 then
      select category into v_category_counts
      from public.push_notification_queue
      where player_id = v_player_row.player_id
        and status = 'pending'
      limit 1;

      v_log_id := null;

      case v_category_counts.category
        when 'production_blocked' then
          v_push_title := format('⚠️ %s Tesiste Çarklar Durdu!', v_total_pending);
          v_push_message := format('%s üretim işletmende hammadde tükendi veya depolar taştı! Çarkların dönmesi için hemen müdahale et.', v_total_pending);
        when 'store_blocked' then
          v_push_title := format('🚨 %s Mağazada Raflar Talandı!', v_total_pending);
          v_push_message := format('%s şubende ürünler tükendi! Müşterileri kaçırmamak ve kasaları doldurmak için mal sevk et.', v_total_pending);
        when 'logistics_attention' then
          v_push_title := format('⛽ %s Nakliye Aracında Alarm!', v_total_pending);
          v_push_message := format('Filondaki %s araçta yakıt bitti veya bakıma ihtiyaç var. Sevkiyatların aksamaması için ilgilen!', v_total_pending);
        when 'transfer_completed' then
          v_push_title := format('🚚 %s Sevkiyat Depoya Ulaştı!', v_total_pending);
          v_push_message := format('%s adet konvoyun hedefe vardı ve mallar boşaltıldı. Ürünlerin kullanıma hazır!', v_total_pending);
        when 'arge_completed' then
          v_push_title := format('💡 %s Yeni Teknoloji Keşfedildi!', v_total_pending);
          v_push_message := format('Laboratuvarların %s araştırmayı tamamladı! Ürün kaliten ve pazar gücün arttı.', v_total_pending);
        when 'upgrade_completed' then
          v_push_title := format('⭐ %s Tesis Seviye Atladı!', v_total_pending);
          v_push_message := format('%s binanın kapasitesi ve verimi katlandı! Şirketin büyümeye devam ediyor.', v_total_pending);
        when 'construction_completed' then
          v_push_title := format('🏢 %s Yeni Tesisin Açılışı Hazır!', v_total_pending);
          v_push_message := format('%s yeni işletmenin inşaatı bitti, kurdele kesilmeye hazır! Tesisleri devreye al.', v_total_pending);
        else
          v_push_title := '💼 Şirketinde Yeni Gelişmeler Var!';
          v_push_message := format('%s adet yeni operasyonel gelişme seni bekliyor. Şirketinin başına geç!', v_total_pending);
      end case;

    -- -------------------------------------------------------------
    -- CASE 3: Multi-Category Events -> 1 Single Executive Briefing Push!
    -- -------------------------------------------------------------
    else
      v_log_id := null;
      v_summary_parts := array[]::text[];

      for v_category_counts in
        select category, count(*) as cat_count
        from public.push_notification_queue
        where player_id = v_player_row.player_id
          and status = 'pending'
        group by category
        order by cat_count desc
      loop
        case v_category_counts.category
          when 'production_blocked' then
            v_summary_parts := array_append(v_summary_parts, format('%s tesiste üretim durdu', v_category_counts.cat_count));
          when 'store_blocked' then
            v_summary_parts := array_append(v_summary_parts, format('%s mağazada raflar boşaldı', v_category_counts.cat_count));
          when 'logistics_attention' then
            v_summary_parts := array_append(v_summary_parts, format('%s araç bakım/yakıt bekliyor', v_category_counts.cat_count));
          when 'transfer_completed' then
            v_summary_parts := array_append(v_summary_parts, format('%s sevkiyat ulaştı', v_category_counts.cat_count));
          when 'construction_completed' then
            v_summary_parts := array_append(v_summary_parts, format('%s yeni bina tamamlandı', v_category_counts.cat_count));
          when 'upgrade_completed' then
            v_summary_parts := array_append(v_summary_parts, format('%s tesis seviye atladı', v_category_counts.cat_count));
          when 'arge_completed' then
            v_summary_parts := array_append(v_summary_parts, format('%s buluş keşfedildi', v_category_counts.cat_count));
          else
            v_summary_parts := array_append(v_summary_parts, format('%s bildirim', v_category_counts.cat_count));
        end case;
      end loop;

      v_push_title := '👔 Şirket Raporu Masanda Patron!';
      v_push_message := array_to_string(v_summary_parts, ', ') || '. Hemen şirketin başına geç!';
    end if;

    -- Deduplication check: Avoid sending the exact same title & message if sent in last 10 minutes
    if not exists (
      select 1 from public.push_notification_logs
      where player_id = v_player_row.player_id
        and title = v_push_title
        and message = v_push_message
        and sent_at >= timezone('utc', now()) - interval '10 minutes'
    ) then
      -- Loop through player's registered push tokens and create delivery logs
      for v_token_row in
        select token
        from public.player_push_tokens
        where player_id = v_player_row.player_id
      loop
        insert into public.push_notification_logs (
          player_id,
          notification_id,
          token,
          title,
          message,
          status
        )
        values (
          v_player_row.player_id,
          v_log_id,
          v_token_row.token,
          v_push_title,
          v_push_message,
          'sent'
        );
      end loop;
    end if;

    -- Mark all pending queue items for this player as 'sent'
    update public.push_notification_queue
    set status = 'sent'
    where player_id = v_player_row.player_id
      and status = 'pending';

    v_processed_count := v_processed_count + 1;
  end loop;

  return jsonb_build_object(
    'success', true,
    'processed_players_count', v_processed_count,
    'skipped_players_count', v_skipped_count
  );
end;
$$;
