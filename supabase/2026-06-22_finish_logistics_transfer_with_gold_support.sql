CREATE OR REPLACE FUNCTION public.finish_logistics_transfer_with_gold(p_transfer_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_player_id uuid := auth.uid();
  v_player_gold numeric;
  v_gold_cost integer;
  v_transfer logistics_transfers%rowtype;
  v_remaining_minutes float;
BEGIN
  -- 1. Oturum kontrolü
  if v_player_id is null then
    return jsonb_build_object('success', false, 'message', 'Oturum acilmamis.');
  end if;

  -- 2. Transfer kaydını kontrol et
  SELECT * INTO v_transfer FROM public.logistics_transfers 
  WHERE id = p_transfer_id AND buyer_player_id = v_player_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Transfer kaydı bulunamadı.');
  END IF;

  IF v_transfer.status = 'completed' THEN
    RETURN jsonb_build_object('success', false, 'message', 'Bu transfer zaten tamamlanmış.');
  END IF;

  IF v_transfer.status <> 'in_transit' THEN
    RETURN jsonb_build_object('success', false, 'message', 'Bu transfer tamamlanabilir durumda değil.');
  END IF;

  -- 3. Dinamik maliyet hesapla (Her 10 dk için 1 altın/yıldız, yukarı yuvarla)
  v_remaining_minutes := EXTRACT(EPOCH FROM (v_transfer.finish_at - timezone('utc'::text, now()))) / 60.0;
  
  IF v_remaining_minutes <= 0 THEN
    v_gold_cost := 0;
  ELSE
    v_gold_cost := ceil(v_remaining_minutes / 10.0);
  END IF;

  -- 4. Oyuncunun altınını kontrol et
  SELECT gold INTO v_player_gold FROM public.players WHERE id = v_player_id FOR UPDATE;
  
  IF v_player_gold < v_gold_cost THEN
    RETURN jsonb_build_object('success', false, 'message', 'Yetersiz altın/yıldız. Gereken: ' || v_gold_cost);
  END IF;

  -- 5. Altını düş
  IF v_gold_cost > 0 THEN
    UPDATE public.players SET gold = gold - v_gold_cost WHERE id = v_player_id;
  END IF;

  -- 6. Transferin bitiş süresini geçmişe çek
  UPDATE public.logistics_transfers 
  SET finish_at = timezone('utc'::text, now()) - interval '1 second'
  WHERE id = p_transfer_id;

  -- 7. Mevcut tamamlama fonksiyonunu çağır
  RETURN public.complete_logistics_transfer(p_transfer_id);
END;
$function$;
