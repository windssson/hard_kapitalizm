-- 1. Add last_seen_at column to players table if it doesn't exist
ALTER TABLE public.players 
ADD COLUMN IF NOT EXISTS last_seen_at timestamp with time zone DEFAULT timezone('utc', now());

-- 2. Create player_push_tokens table
CREATE TABLE IF NOT EXISTS public.player_push_tokens (
  player_id uuid REFERENCES public.players(id) ON DELETE CASCADE,
  token text NOT NULL,
  device_id text,
  created_at timestamp with time zone DEFAULT timezone('utc', now()),
  updated_at timestamp with time zone DEFAULT timezone('utc', now()),
  PRIMARY KEY (player_id, token)
);

ALTER TABLE public.player_push_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage their own push tokens" ON public.player_push_tokens;
CREATE POLICY "Users can manage their own push tokens" ON public.player_push_tokens
  FOR ALL TO authenticated USING (auth.uid() = player_id) WITH CHECK (auth.uid() = player_id);

-- 3. Create push_notification_queue table
CREATE TABLE IF NOT EXISTS public.push_notification_queue (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id uuid REFERENCES public.players(id) ON DELETE CASCADE,
  notification_id uuid REFERENCES public.player_notifications(id) ON DELETE CASCADE,
  category text NOT NULL,
  title text NOT NULL,
  message text NOT NULL,
  status text DEFAULT 'pending', -- pending, sent, skipped
  created_at timestamp with time zone DEFAULT timezone('utc', now())
);

ALTER TABLE public.push_notification_queue ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own queue items" ON public.push_notification_queue;
CREATE POLICY "Users can view their own queue items" ON public.push_notification_queue
  FOR SELECT TO authenticated USING (auth.uid() = player_id);

-- 4. Create push_notification_logs table
CREATE TABLE IF NOT EXISTS public.push_notification_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id uuid REFERENCES public.players(id) ON DELETE CASCADE,
  notification_id uuid REFERENCES public.player_notifications(id) ON DELETE CASCADE,
  token text NOT NULL,
  title text NOT NULL,
  message text NOT NULL,
  sent_at timestamp with time zone DEFAULT timezone('utc', now()),
  status text DEFAULT 'sent',
  created_at timestamp with time zone DEFAULT timezone('utc', now())
);

ALTER TABLE public.push_notification_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own push notification logs" ON public.push_notification_logs;
CREATE POLICY "Users can view their own push notification logs" ON public.push_notification_logs
  FOR SELECT TO authenticated USING (auth.uid() = player_id);

-- 5. RPC function to register push token
CREATE OR REPLACE FUNCTION public.register_push_token(p_token text, p_device_id text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
declare
  v_player_id uuid := auth.uid();
begin
  if v_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  if coalesce(p_token, '') = '' then
    raise exception 'Token bos olamaz.';
  end if;

  insert into public.player_push_tokens (player_id, token, device_id, updated_at)
  values (v_player_id, p_token, p_device_id, timezone('utc', now()))
  on conflict (player_id, token)
  do update set
    device_id = excluded.device_id,
    updated_at = timezone('utc', now());

  return jsonb_build_object('success', true);
end;
$$;

-- 6. RPC function to update player heartbeat (online presence)
CREATE OR REPLACE FUNCTION public.update_player_heartbeat()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
declare
  v_player_id uuid := auth.uid();
  v_now timestamp with time zone := timezone('utc', now());
begin
  if v_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  update public.players
  set last_seen_at = v_now
  where id = v_player_id;

  return jsonb_build_object('success', true, 'last_seen_at', v_now);
end;
$$;

-- 7. Trigger function to queue new notifications
CREATE OR REPLACE FUNCTION public.trg_push_notification_on_insert_func()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
begin
  -- If notification is active/unread, insert into queue to process push notification
  if new.status = 'unread' then
    insert into public.push_notification_queue (
      player_id,
      notification_id,
      category,
      title,
      message
    )
    values (
      new.player_id,
      new.id,
      new.category,
      new.title,
      new.message
    );
  end if;
  return new;
end;
$$;

DROP TRIGGER IF EXISTS trg_push_notification_on_insert ON public.player_notifications;

CREATE TRIGGER trg_push_notification_on_insert
  AFTER INSERT ON public.player_notifications
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_push_notification_on_insert_func();

-- 8. Core function to process, aggregate, and send push notifications for offline players
CREATE OR REPLACE FUNCTION public.process_push_notification_queue()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
declare
  v_player_row record;
  v_group_row record;
  v_token_row record;
  v_player_last_seen timestamp with time zone;
  v_is_online boolean;
  v_push_title text;
  v_push_message text;
  v_log_id uuid;
  v_processed_count integer := 0;
  v_skipped_count integer := 0;
begin
  -- 1. Loop through all players who have pending push notifications
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
      -- Player is online, skip push notifications (they will see it in-game)
      update public.push_notification_queue
      set status = 'skipped'
      where player_id = v_player_row.player_id
        and status = 'pending';
      v_skipped_count := v_skipped_count + 1;
    else
      -- Player is offline, group notifications by category to prevent duplicate pushes
      for v_group_row in
        select category, count(*) as alert_count
        from public.push_notification_queue
        where player_id = v_player_row.player_id
          and status = 'pending'
        group by category
      loop
        -- 2. Format title and message based on aggregation count and category
        if v_group_row.alert_count = 1 then
          -- Only 1 alert, send original details
          select title, message, notification_id
          into v_push_title, v_push_message, v_log_id
          from public.push_notification_queue
          where player_id = v_player_row.player_id
            and category = v_group_row.category
            and status = 'pending'
          limit 1;
          
          -- Deduplication Check: Skip if this specific notification was already pushed
          if exists (
            select 1 from public.push_notification_logs
            where player_id = v_player_row.player_id
              and notification_id = v_log_id
          ) then
            -- Mark as skipped (already sent)
            update public.push_notification_queue
            set status = 'skipped'
            where player_id = v_player_row.player_id
              and category = v_group_row.category
              and status = 'pending';
            continue;
          end if;

        else
          -- Multiple alerts of same category: AGGREGATE
          v_log_id := null; -- No single notification ID for aggregated push
          
          case v_group_row.category
            when 'production_blocked' then
              v_push_title := 'Üretim Sorunları';
              v_push_message := format('Birden fazla üretim işletmenizde sorun var (Hammadde eksik veya depo dolu).', v_group_row.alert_count);
            when 'store_blocked' then
              v_push_title := 'Mağaza Stok Uyarıları';
              v_push_message := format('%s adet mağazanızda stok veya boş raf sorunları mevcut.', v_group_row.alert_count);
            when 'logistics_attention' then
              v_push_title := 'Lojistik Uyarısı';
              v_push_message := format('Lojistik şirketlerinizde %s adet araçta yakıt veya bakım sorunu var.', v_group_row.alert_count);
            when 'transfer_completed' then
              v_push_title := 'Transferler Tamamlandı';
              v_push_message := format('%s adet transferiniz başarıyla tamamlandı.', v_group_row.alert_count);
            when 'arge_completed' then
              v_push_title := 'AR-GE Tamamlandı';
              v_push_message := format('%s adet AR-GE araştırması başarıyla tamamlandı.', v_group_row.alert_count);
            when 'upgrade_completed' then
              v_push_title := 'Yükseltmeler Tamamlandı';
              v_push_message := format('%s adet bina yükseltmesi tamamlandı.', v_group_row.alert_count);
            when 'construction_completed' then
              v_push_title := 'İnşaatlar Tamamlandı';
              v_push_message := format('%s adet yeni işletme inşaatı tamamlandı.', v_group_row.alert_count);
            else
              v_push_title := 'Yeni Olaylar';
              v_push_message := format('%s adet yeni bildiriminiz var.', v_group_row.alert_count);
          end case;

          -- Deduplication Check for Aggregated Pushes:
          -- To prevent spamming the exact same message repeatedly, check if same aggregated push log was created in last 5 minutes
          if exists (
            select 1 from public.push_notification_logs
            where player_id = v_player_row.player_id
              and title = v_push_title
              and message = v_push_message
              and sent_at >= timezone('utc', now()) - interval '5 minutes'
          ) then
            -- Skip sending same aggregated push again so soon
            update public.push_notification_queue
            set status = 'skipped'
            where player_id = v_player_row.player_id
              and category = v_group_row.category
              and status = 'pending';
            continue;
          end if;
        end if;

        -- 3. Loop through player's registered push tokens and create delivery logs (simulate push sending)
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

        -- Mark these queue items as sent
        update public.push_notification_queue
        set status = 'sent'
        where player_id = v_player_row.player_id
          and category = v_group_row.category
          and status = 'pending';

        v_processed_count := v_processed_count + 1;
      end loop;
    end if;
  end loop;

  return jsonb_build_object(
    'success', true,
    'processed_groups_count', v_processed_count,
    'skipped_players_count', v_skipped_count
  );
end;
$$;

-- 9. Schedule the queue processor in pg_cron to run every 2 minutes
SELECT cron.unschedule(jobid)
FROM cron.job
WHERE jobname = 'process_push_notification_queue_job';

SELECT cron.schedule(
  'process_push_notification_queue_job',
  '*/2 * * * *',
  'select public.process_push_notification_queue();'
);
