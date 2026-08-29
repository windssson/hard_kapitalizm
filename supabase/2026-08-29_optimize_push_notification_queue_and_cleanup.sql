-- ============================================================================
-- Migration: Optimize Push Notification Queue, Add Auto-Cleanup and 10m Schedule
-- 1. Partial index on push_notification_queue for pending status
-- 2. Prune old queue and logs automatically in process_push_notification_queue
-- 3. Adjust cron schedule from 2 minutes to 10 minutes (*/10 * * * *)
-- ============================================================================

-- 1. Kısmi İndeks (Sadece bekleyen kuyruk kayıtlarını tarar, sorguyu 0.1 ms'ye indirir)
CREATE INDEX IF NOT EXISTS idx_push_queue_pending_player 
ON public.push_notification_queue (player_id) 
WHERE status = 'pending';

-- 2. process_push_notification_queue fonksiyonunu otomatik temizlik ile güncelle
CREATE OR REPLACE FUNCTION public.process_push_notification_queue()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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

  -- -------------------------------------------------------------
  -- Otomatik Temizlik (Tablo Şişmesini ve Disk Maliyetini Önler)
  -- -------------------------------------------------------------
  delete from public.push_notification_queue
  where status in ('sent', 'skipped')
    and created_at < timezone('utc', now()) - interval '3 days';

  delete from public.push_notification_logs
  where sent_at < timezone('utc', now()) - interval '14 days';

  return jsonb_build_object(
    'success', true,
    'processed_players_count', v_processed_count,
    'skipped_players_count', v_skipped_count
  );
end;
$function$;

-- 3. Cron zamanlamasını 10 dakikada bire çek (*/10 * * * *)
SELECT cron.alter_job(
  job_id := 14,
  schedule := '*/10 * * * *'
);
