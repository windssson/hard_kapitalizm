-- Trigger to send push notification via Supabase Edge Function when a log is inserted

CREATE OR REPLACE FUNCTION public.trg_send_push_notification_on_log_insert_func()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
declare
  v_payload jsonb;
begin
  -- Build payload with token, title, message, player_id
  v_payload := jsonb_build_object(
    'token', new.token,
    'title', new.title,
    'message', new.message,
    'player_id', new.player_id
  );

  -- Call the Supabase Edge Function asynchronously using pg_net
  perform net.http_post(
    url := 'https://lpiixtfxldhoyyppavyn.supabase.co/functions/v1/send-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json'
    ),
    body := v_payload
  );

  return new;
end;
$$;

DROP TRIGGER IF EXISTS trg_send_push_notification_on_log_insert ON public.push_notification_logs;

CREATE TRIGGER trg_send_push_notification_on_log_insert
  AFTER INSERT ON public.push_notification_logs
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_send_push_notification_on_log_insert_func();
