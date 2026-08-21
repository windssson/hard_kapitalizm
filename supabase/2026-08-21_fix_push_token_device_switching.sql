-- 2026-08-21: Fix Push Token Multi-Account Device Overlap
-- Ensures a device's push token is uniquely owned by the current active player.
-- When a player logs in and registers a push token, any stale bindings of that same token
-- to previous test/alt accounts on that device are automatically deleted.

CREATE OR REPLACE FUNCTION public.register_push_token(
  p_token text,
  p_device_id text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_player_id uuid := auth.uid();
begin
  if v_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  if coalesce(p_token, '') = '' then
    raise exception 'Token bos olamaz.';
  end if;

  -- Oyuncu profili henuz olusturulmadiysa sessizce don (FK violation onleme)
  if not exists (select 1 from public.players where id = v_player_id) then
    return jsonb_build_object('success', false, 'error', 'player_not_found');
  end if;

  -- Baska bir hesaptan kalan ayni cihaza ait eski token baglantisini temizle
  delete from public.player_push_tokens
  where token = p_token and player_id <> v_player_id;

  insert into public.player_push_tokens (player_id, token, device_id, updated_at)
  values (v_player_id, p_token, p_device_id, timezone('utc', now()))
  on conflict (player_id, token)
  do update set
    device_id = excluded.device_id,
    updated_at = timezone('utc', now());

  return jsonb_build_object('success', true);
end;
$function$;

-- Mevcut çakışan eski hesap token kayıtlarını temizle
DELETE FROM public.player_push_tokens
WHERE token = 'd2kYlmq2Rvi6PAJz6JoMvY:APA91bF8fV3U_jU6ZfL3fDqYqVqg2y1M4L0q_Z4...' -- or by player_id
   OR player_id = 'f32a0f95-bcb4-4ac4-bf9f-6aecf7b5be58';
