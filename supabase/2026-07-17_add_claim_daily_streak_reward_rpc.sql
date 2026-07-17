-- Migration to define the claim_daily_streak_reward RPC function.

CREATE OR REPLACE FUNCTION public.claim_daily_streak_reward(
  p_reward_cash numeric,
  p_reward_gold numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_player_id uuid := auth.uid();
  v_current_cash numeric;
  v_current_gold numeric;
BEGIN
  IF v_player_id IS NULL THEN
    RAISE EXCEPTION 'Oturum acilmamis.';
  END IF;

  -- Update player cash and gold
  UPDATE public.players
  SET cash = cash + p_reward_cash,
      gold = gold + p_reward_gold
  WHERE id = v_player_id
  RETURNING cash, gold INTO v_current_cash, v_current_gold;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Oyuncu bulunamadi.';
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Gunluk giris odulu alindi.',
    'new_cash', v_current_cash,
    'new_gold', v_current_gold
  );
END;
$$;
