-- =========================================================================================
-- MIGRATION: 2026-09-01_create_high_perf_notification_system.sql
-- Yüksek Performanslı Bildirim Sistemi (Oyun İçi Realtime + FCM Asenkron Push pg_net)
-- =========================================================================================

-- 1. Bildirim Tablosu
CREATE TABLE IF NOT EXISTS public.player_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id uuid NOT NULL REFERENCES public.players(id) ON DELETE CASCADE,
  title text NOT NULL,
  message text NOT NULL,
  category text NOT NULL DEFAULT 'system',
  entity_type text DEFAULT NULL,
  entity_id uuid DEFAULT NULL,
  is_read boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now())
);

-- RLS Güvenliği
ALTER TABLE public.player_notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Players can select own notifications" ON public.player_notifications;
CREATE POLICY "Players can select own notifications"
  ON public.player_notifications
  FOR SELECT
  TO authenticated
  USING (player_id = auth.uid());

DROP POLICY IF EXISTS "Players can update own notifications" ON public.player_notifications;
CREATE POLICY "Players can update own notifications"
  ON public.player_notifications
  FOR UPDATE
  TO authenticated
  USING (player_id = auth.uid())
  WITH CHECK (player_id = auth.uid());

DROP POLICY IF EXISTS "Players can delete own notifications" ON public.player_notifications;
CREATE POLICY "Players can delete own notifications"
  ON public.player_notifications
  FOR DELETE
  TO authenticated
  USING (player_id = auth.uid());

DROP POLICY IF EXISTS "Service role full access on player_notifications" ON public.player_notifications;
CREATE POLICY "Service role full access on player_notifications"
  ON public.player_notifications
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- 2. Yüksek Performanslı İndeksler
CREATE INDEX IF NOT EXISTS idx_player_notifications_unread 
  ON public.player_notifications (player_id, created_at DESC) 
  WHERE is_read = false;

CREATE INDEX IF NOT EXISTS idx_player_notifications_feed 
  ON public.player_notifications (player_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_player_notifications_category 
  ON public.player_notifications (player_id, category, created_at DESC);

-- 3. Supabase Realtime Yayınını Etkinleştir
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'player_notifications'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.player_notifications;
  END IF;
END $$;

-- 4. Ana Bildirim Dağıtıcı (Dispatcher)
CREATE OR REPLACE FUNCTION public.send_game_notification(
  p_player_id uuid,
  p_title text,
  p_message text,
  p_category text DEFAULT 'system',
  p_entity_type text DEFAULT NULL,
  p_entity_id uuid DEFAULT NULL,
  p_send_push boolean DEFAULT true
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_notification_id uuid;
  v_token_row record;
BEGIN
  IF p_player_id IS NULL OR p_title IS NULL OR p_message IS NULL THEN
    RETURN NULL;
  END IF;

  -- 1. Oyun içi bildirimi ekle (Supabase Realtime bunu bağlı istemcilere anında yayar)
  INSERT INTO public.player_notifications (
    player_id,
    title,
    message,
    category,
    entity_type,
    entity_id,
    is_read,
    created_at
  ) VALUES (
    p_player_id,
    p_title,
    p_message,
    coalesce(p_category, 'system'),
    p_entity_type,
    p_entity_id,
    false,
    timezone('utc'::text, now())
  ) RETURNING id INTO v_notification_id;

  -- 2. Otomatik budama: Oyuncu başına en yeni 50 bildirimi tut, eskileri temizle
  DELETE FROM public.player_notifications
  WHERE player_id = p_player_id
    AND id NOT IN (
      SELECT id FROM public.player_notifications
      WHERE player_id = p_player_id
      ORDER BY created_at DESC
      LIMIT 50
    );

  -- 3. FCM Push Gönderimi (pg_net ile asenkron non-blocking HTTP çağrısı)
  IF p_send_push THEN
    FOR v_token_row IN
      SELECT token
      FROM public.player_push_tokens
      WHERE player_id = p_player_id
    LOOP
      PERFORM net.http_post(
        url := 'https://lpiixtfxldhoyyppavyn.supabase.co/functions/v1/send-push',
        headers := jsonb_build_object('Content-Type', 'application/json'),
        body := jsonb_build_object(
          'token', v_token_row.token,
          'title', p_title,
          'message', p_message,
          'player_id', p_player_id::text
        )
      );
    END LOOP;
  END IF;

  RETURN v_notification_id;
END;
$function$;

-- 5. Okundu ve Yönetim RPC'leri
CREATE OR REPLACE FUNCTION public.get_player_notifications(
  p_limit integer DEFAULT 30,
  p_offset integer DEFAULT 0,
  p_category text DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  player_id uuid,
  title text,
  message text,
  category text,
  entity_type text,
  entity_id uuid,
  is_read boolean,
  created_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT
    pn.id,
    pn.player_id,
    pn.title,
    pn.message,
    pn.category,
    pn.entity_type,
    pn.entity_id,
    pn.is_read,
    pn.created_at
  FROM public.player_notifications pn
  WHERE pn.player_id = auth.uid()
    AND (p_category IS NULL OR p_category = 'all' OR pn.category = p_category)
  ORDER BY pn.created_at DESC
  LIMIT greatest(1, least(p_limit, 100))
  OFFSET greatest(0, p_offset);
$function$;

CREATE OR REPLACE FUNCTION public.get_unread_notification_count()
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT count(*)::integer
  FROM public.player_notifications
  WHERE player_id = auth.uid()
    AND is_read = false;
$function$;

CREATE OR REPLACE FUNCTION public.mark_notification_read(p_notification_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  IF auth.uid() IS NULL OR p_notification_id IS NULL THEN
    RETURN false;
  END IF;

  UPDATE public.player_notifications
  SET is_read = true
  WHERE id = p_notification_id
    AND player_id = auth.uid();

  RETURN true;
END;
$function$;

CREATE OR REPLACE FUNCTION public.mark_all_notifications_read()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN false;
  END IF;

  UPDATE public.player_notifications
  SET is_read = true
  WHERE player_id = auth.uid()
    AND is_read = false;

  RETURN true;
END;
$function$;

CREATE OR REPLACE FUNCTION public.clear_player_notifications(p_only_read boolean DEFAULT false)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN false;
  END IF;

  IF p_only_read THEN
    DELETE FROM public.player_notifications
    WHERE player_id = auth.uid()
      AND is_read = true;
  ELSE
    DELETE FROM public.player_notifications
    WHERE player_id = auth.uid();
  END IF;

  RETURN true;
END;
$function$;

-- 6. Yetkilendirme
REVOKE ALL ON FUNCTION public.send_game_notification(uuid, text, text, text, text, uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.send_game_notification(uuid, text, text, text, text, uuid, boolean) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.get_player_notifications(integer, integer, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_player_notifications(integer, integer, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.get_unread_notification_count() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_unread_notification_count() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.mark_notification_read(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_notification_read(uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.mark_all_notifications_read() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_all_notifications_read() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.clear_player_notifications(boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.clear_player_notifications(boolean) TO authenticated, service_role;
