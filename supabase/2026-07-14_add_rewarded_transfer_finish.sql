CREATE OR REPLACE FUNCTION public.finish_logistics_transfer_with_ad_reward(
  p_transfer_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_player_id uuid := auth.uid();
  v_transfer public.logistics_transfers%ROWTYPE;
  v_remaining_seconds integer;
BEGIN
  IF v_player_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Oturum acilmamis.');
  END IF;

  SELECT *
  INTO v_transfer
  FROM public.logistics_transfers
  WHERE id = p_transfer_id
    AND buyer_player_id = v_player_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Transfer kaydi bulunamadi.');
  END IF;

  IF v_transfer.status = 'completed' THEN
    RETURN jsonb_build_object('success', false, 'message', 'Bu transfer zaten tamamlanmis.');
  END IF;

  IF v_transfer.status <> 'in_transit' THEN
    RETURN jsonb_build_object(
      'success',
      false,
      'message',
      'Bu transfer reklam odulu ile tamamlanabilir durumda degil.'
    );
  END IF;

  v_remaining_seconds := GREATEST(
    CEIL(EXTRACT(EPOCH FROM (v_transfer.finish_at - timezone('utc'::text, now()))))::integer,
    0
  );

  IF v_remaining_seconds > 600 THEN
    RETURN jsonb_build_object(
      'success',
      false,
      'message',
      'Reklamla hizli tamamlama sadece son 10 dakika icindeki transferlerde kullanilabilir.'
    );
  END IF;

  UPDATE public.logistics_transfers
  SET finish_at = timezone('utc'::text, now()) - interval '1 second'
  WHERE id = p_transfer_id;

  RETURN public.complete_logistics_transfer(p_transfer_id);
END;
$function$;
