-- Update pay_tax_debt to support p_amount = -1 for paying all actual debt in full
CREATE OR REPLACE FUNCTION public.pay_tax_debt(p_amount numeric)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_player_id uuid := auth.uid();
  v_current_cash numeric;
  v_current_tax numeric;
  v_paid_amount numeric;
BEGIN
  if v_player_id is null then
    return jsonb_build_object('success', false, 'message', 'Oturum acilmamis.');
  end if;

  if p_amount <= 0 and p_amount != -1 then
    return jsonb_build_object('success', false, 'message', 'Gecersiz odeme tutari.');
  end if;

  -- Lock player and tax records
  select cash into v_current_cash from public.players where id = v_player_id for update;
  if v_current_cash is null then
    return jsonb_build_object('success', false, 'message', 'Oyuncu bulunamadi.');
  end if;

  select tax_debt into v_current_tax from public.player_taxes where player_id = v_player_id for update;
  if v_current_tax is null or v_current_tax <= 0 then
    return jsonb_build_object('success', false, 'message', 'Vergi borcunuz bulunmamaktadir.');
  end if;

  if p_amount = -1 then
    v_paid_amount := v_current_tax;
  else
    v_paid_amount := p_amount;
    if v_paid_amount > v_current_tax then
      v_paid_amount := v_current_tax;
    end if;
  end if;

  if v_current_cash < v_paid_amount then
    return jsonb_build_object('success', false, 'message', 'Yetersiz nakit bakiye.');
  end if;

  update public.players
  set cash = cash - v_paid_amount
  where id = v_player_id;

  update public.player_taxes
  set tax_debt = tax_debt - v_paid_amount,
      updated_at = now()
  where player_id = v_player_id;

  perform public.log_player_cash_change(
    v_player_id,
    -v_paid_amount,
    v_current_cash,
    'tax_payment',
    format('Vergi odemesi: %s TL', round(v_paid_amount, 2)),
    null,
    'tax'
  );

  return jsonb_build_object(
    'success', true,
    'message', format('%s TL vergi borcu odendi.', round(v_paid_amount, 2)),
    'paid_amount', v_paid_amount,
    'remaining_tax_debt', v_current_tax - v_paid_amount,
    'remaining_cash', v_current_cash - v_paid_amount
  );
END;
$$;
