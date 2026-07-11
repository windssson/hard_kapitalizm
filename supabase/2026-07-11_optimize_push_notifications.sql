-- Optimize push notification trigger to run on INSERT and UPDATE, support instant pushes for tenders/transfers, and queue aggregated warnings.

CREATE OR REPLACE FUNCTION public.trg_push_notification_on_insert_func()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
declare
  v_player_last_seen timestamp with time zone;
  v_is_online boolean := false;
  v_token_row record;
  v_is_instant boolean := false;
  v_should_process boolean := false;
begin
  -- Trigger should run:
  -- A. On INSERT, if status is 'unread'
  -- B. On UPDATE, if status becomes 'unread' (i.e. was not unread, or dedupe_key/updated_at changed and status is unread)
  if tg_op = 'INSERT' and new.status = 'unread' then
    v_should_process := true;
  elsif tg_op = 'UPDATE' and new.status = 'unread' then
    if old.status is null or old.status <> 'unread' or old.updated_at <> new.updated_at then
      v_should_process := true;
    end if;
  end if;

  if v_should_process then
    -- Determine if this is a high-priority instant notification category
    if new.category in ('transfer_completed', 'tender_completed', 'tender_failed', 'tender_warning', 'tender_awarded') then
      v_is_instant := true;
    end if;

    -- Check if player is online
    select last_seen_at into v_player_last_seen
    from public.players
    where id = new.player_id;

    v_is_online := (v_player_last_seen is not null and (timezone('utc', now()) - v_player_last_seen) <= interval '1 minute');

    if v_is_instant then
      if v_is_online then
        -- Insert as skipped (since player is online in-app)
        insert into public.push_notification_queue (
          player_id,
          notification_id,
          category,
          title,
          message,
          status
        )
        values (
          new.player_id,
          new.id,
          new.category,
          new.title,
          new.message,
          'skipped'
        );
      else
        -- Player is offline, send INSTANTLY!
        -- 1. Insert into queue as 'sent'
        insert into public.push_notification_queue (
          player_id,
          notification_id,
          category,
          title,
          message,
          status
        )
        values (
          new.player_id,
          new.id,
          new.category,
          new.title,
          new.message,
          'sent'
        );

        -- 2. Send to all registered tokens of the player immediately
        for v_token_row in
          select token
          from public.player_push_tokens
          where player_id = new.player_id
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
            new.player_id,
            new.id,
            v_token_row.token,
            new.title,
            new.message,
            'sent'
          );
        end loop;
      end if;
    else
      -- Non-instant (aggregated) notification: queue as 'pending'
      -- Avoid inserting duplicate pending items for same notification ID
      if not exists (
        select 1 from public.push_notification_queue
        where notification_id = new.id
          and status = 'pending'
      ) then
        insert into public.push_notification_queue (
          player_id,
          notification_id,
          category,
          title,
          message,
          status
        )
        values (
          new.player_id,
          new.id,
          new.category,
          new.title,
          new.message,
          'pending'
        );
      end if;
    end if;
  end if;

  return new;
end;
$$;

-- Drop and recreate trigger to fire on INSERT and UPDATE
DROP TRIGGER IF EXISTS trg_push_notification_on_insert ON public.player_notifications;

CREATE TRIGGER trg_push_notification_on_insert
  AFTER INSERT OR UPDATE ON public.player_notifications
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_push_notification_on_insert_func();
