-- Bank System: Krediler (Loans) ve Mevduatlar (Deposits)
-- Created: 2026-07-11

-- 1. Create player_loans table
CREATE TABLE IF NOT EXISTS public.player_loans (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    player_id uuid NOT NULL REFERENCES public.players(id) ON DELETE CASCADE,
    amount numeric NOT NULL,
    interest_rate numeric NOT NULL,
    total_due numeric NOT NULL,
    total_paid numeric NOT NULL DEFAULT 0,
    installments_total integer NOT NULL,
    installments_paid integer NOT NULL DEFAULT 0,
    installment_amount numeric NOT NULL,
    next_installment_due_at timestamp with time zone NOT NULL,
    status text NOT NULL DEFAULT 'active', -- 'active', 'paid', 'defaulted'
    created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Index for performance
CREATE INDEX IF NOT EXISTS idx_player_loans_player_id ON public.player_loans(player_id);
CREATE INDEX IF NOT EXISTS idx_player_loans_status ON public.player_loans(status);

-- 2. Create player_deposits table
CREATE TABLE IF NOT EXISTS public.player_deposits (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    player_id uuid NOT NULL REFERENCES public.players(id) ON DELETE CASCADE,
    amount numeric NOT NULL,
    interest_rate numeric NOT NULL,
    expected_payout numeric NOT NULL,
    locked_until timestamp with time zone NOT NULL,
    status text NOT NULL DEFAULT 'active', -- 'active', 'claimed', 'withdrawn_early'
    created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Index for performance
CREATE INDEX IF NOT EXISTS idx_player_deposits_player_id ON public.player_deposits(player_id);
CREATE INDEX IF NOT EXISTS idx_player_deposits_status ON public.player_deposits(status);

-- 3. Enable RLS
ALTER TABLE public.player_loans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.player_deposits ENABLE ROW LEVEL SECURITY;

-- 4. Create RLS Policies
DROP POLICY IF EXISTS "Players can view their own loans" ON public.player_loans;
CREATE POLICY "Players can view their own loans" ON public.player_loans
    FOR SELECT USING (auth.uid() = player_id);

DROP POLICY IF EXISTS "Players can view their own deposits" ON public.player_deposits;
CREATE POLICY "Players can view their own deposits" ON public.player_deposits
    FOR SELECT USING (auth.uid() = player_id);

-- 5. Loan limit helper function
CREATE OR REPLACE FUNCTION public.get_player_loan_limit(p_player_id uuid)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
declare
  v_level integer;
begin
  select coalesce(level, 1) into v_level from public.players where id = p_player_id;
  return v_level * 25000;
end;
$$;

-- 6. RPC: Take Loan
CREATE OR REPLACE FUNCTION public.take_loan(p_amount numeric, p_installments integer)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
declare
  v_player_id uuid := auth.uid();
  v_current_cash numeric;
  v_loan_limit numeric;
  v_active_loans_total numeric;
  v_interest_rate numeric;
  v_total_due numeric;
  v_installment_amount numeric;
  v_loan_id uuid;
begin
  if v_player_id is null then
    return jsonb_build_object('success', false, 'message', 'Oturum acilmamis.');
  end if;

  if p_amount <= 0 then
    return jsonb_build_object('success', false, 'message', 'Gecersiz kredi tutari.');
  end if;

  -- Validate installments options
  if p_installments not in (6, 12, 24, 36) then
    return jsonb_build_object('success', false, 'message', 'Gecersiz taksit secenegi. (Sadece 6, 12, 24 veya 36 taksit secilebilir)');
  end if;

  -- Set interest rates
  if p_installments = 6 then v_interest_rate := 0.05;
  elsif p_installments = 12 then v_interest_rate := 0.12;
  elsif p_installments = 24 then v_interest_rate := 0.28;
  else v_interest_rate := 0.45;
  end if;

  -- Lock player record
  select cash into v_current_cash from public.players where id = v_player_id for update;
  if v_current_cash is null then
    return jsonb_build_object('success', false, 'message', 'Oyuncu bulunamadi.');
  end if;

  -- Check loan limit
  v_loan_limit := public.get_player_loan_limit(v_player_id);

  select coalesce(sum(amount * (1.0 - (installments_paid::numeric / installments_total::numeric))), 0)
  into v_active_loans_total
  from public.player_loans
  where player_id = v_player_id and status != 'paid';

  if (v_active_loans_total + p_amount) > v_loan_limit then
    return jsonb_build_object(
      'success', false, 
      'message', format('Kredi limiti asildi. Maksimum limitiniz: %s TL. Kalan limitiniz: %s TL.', round(v_loan_limit, 2), round(greatest(0, v_loan_limit - v_active_loans_total), 2))
    );
  end if;

  v_total_due := p_amount * (1.0 + v_interest_rate);
  v_installment_amount := v_total_due / p_installments;
  v_loan_id := gen_random_uuid();

  -- Insert loan
  insert into public.player_loans (
    id, player_id, amount, interest_rate, total_due, total_paid,
    installments_total, installments_paid, installment_amount,
    next_installment_due_at, status
  ) values (
    v_loan_id, v_player_id, p_amount, v_interest_rate, v_total_due, 0,
    p_installments, 0, v_installment_amount,
    now() + interval '24 hours', 'active'
  );

  -- Add cash to player
  update public.players
  set cash = cash + p_amount
  where id = v_player_id;

  -- Log cash change
  perform public.log_player_cash_change(
    v_player_id,
    p_amount,
    v_current_cash,
    'loan_payout',
    format('%s TL Kredi Odendi (%s Taksit)', round(p_amount, 2), p_installments),
    v_loan_id,
    'loan'
  );

  return jsonb_build_object(
    'success', true,
    'message', format('%s TL tutarinda kredi basariyla alindi.', round(p_amount, 2)),
    'loan_id', v_loan_id,
    'amount', p_amount,
    'total_due', v_total_due,
    'installment_amount', v_installment_amount
  );
end;
$$;

-- 7. RPC: Pay Loan Installment (Manual prepayment)
CREATE OR REPLACE FUNCTION public.pay_loan_installment(p_loan_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
declare
  v_player_id uuid := auth.uid();
  v_current_cash numeric;
  v_amount numeric;
  v_installments_paid integer;
  v_installments_total integer;
  v_status text;
begin
  if v_player_id is null then
    return jsonb_build_object('success', false, 'message', 'Oturum acilmamis.');
  end if;

  -- Lock loan and player
  select status, installment_amount, installments_paid, installments_total
  into v_status, v_amount, v_installments_paid, v_installments_total
  from public.player_loans
  where id = p_loan_id and player_id = v_player_id for update;

  if v_status is null then
    return jsonb_build_object('success', false, 'message', 'Kredi kaydi bulunamadi.');
  end if;

  if v_status = 'paid' then
    return jsonb_build_object('success', false, 'message', 'Kredi zaten tamamen odenmis.');
  end if;

  select cash into v_current_cash from public.players where id = v_player_id for update;
  if v_current_cash < v_amount then
    return jsonb_build_object('success', false, 'message', 'Yetersiz nakit bakiye.');
  end if;

  v_installments_paid := v_installments_paid + 1;
  if v_installments_paid >= v_installments_total then
    v_status := 'paid';
  else
    v_status := 'active';
  end if;

  -- Update loan
  update public.player_loans
  set total_paid = total_paid + v_amount,
      installments_paid = v_installments_paid,
      next_installment_due_at = next_installment_due_at + interval '24 hours',
      status = v_status,
      updated_at = now()
  where id = p_loan_id;

  -- Deduct cash
  update public.players
  set cash = cash - v_amount
  where id = v_player_id;

  -- Log cash change
  perform public.log_player_cash_change(
    v_player_id,
    -v_amount,
    v_current_cash,
    'loan_payment',
    format('Kredi Taksit Odemesi (%s/%s)', v_installments_paid, v_installments_total),
    p_loan_id,
    'loan'
  );

  return jsonb_build_object(
    'success', true,
    'message', format('Taksit başarıyla ödendi. (%s/%s)', v_installments_paid, v_installments_total),
    'status', v_status
  );
end;
$$;

-- 8. RPC: Create Deposit
CREATE OR REPLACE FUNCTION public.create_deposit(p_amount numeric, p_days integer)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
declare
  v_player_id uuid := auth.uid();
  v_current_cash numeric;
  v_interest_rate numeric;
  v_expected_payout numeric;
  v_deposit_id uuid;
begin
  if v_player_id is null then
    return jsonb_build_object('success', false, 'message', 'Oturum acilmamis.');
  end if;

  if p_amount <= 0 then
    return jsonb_build_object('success', false, 'message', 'Gecersiz mevduat tutari.');
  end if;

  if p_days not in (1, 3, 7) then
    return jsonb_build_object('success', false, 'message', 'Gecersiz vade secenegi. (Sadece 1, 3 veya 7 gun secilebilir)');
  end if;

  -- Set interest rates
  if p_days = 1 then v_interest_rate := 0.01;      -- %1
  elsif p_days = 3 then v_interest_rate := 0.04;   -- %4
  else v_interest_rate := 0.10;                    -- %10
  end if;

  -- Lock player cash
  select cash into v_current_cash from public.players where id = v_player_id for update;
  if v_current_cash is null then
    return jsonb_build_object('success', false, 'message', 'Oyuncu bulunamadi.');
  end if;

  if v_current_cash < p_amount then
    return jsonb_build_object('success', false, 'message', 'Yetersiz nakit bakiye.');
  end if;

  v_expected_payout := p_amount * (1.0 + v_interest_rate);
  v_deposit_id := gen_random_uuid();

  -- Insert deposit record
  insert into public.player_deposits (
    id, player_id, amount, interest_rate, expected_payout,
    locked_until, status
  ) values (
    v_deposit_id, v_player_id, p_amount, v_interest_rate, v_expected_payout,
    now() + (p_days * interval '24 hours'), 'active'
  );

  -- Deduct cash
  update public.players
  set cash = cash - p_amount
  where id = v_player_id;

  -- Log cash change
  perform public.log_player_cash_change(
    v_player_id,
    -p_amount,
    v_current_cash,
    'deposit_placed',
    format('%s TL Vadeli Mevduat Hesabi Acildi (%s Gun, %%%s Faiz)', round(p_amount, 2), p_days, round(v_interest_rate * 100, 0)),
    v_deposit_id,
    'deposit'
  );

  return jsonb_build_object(
    'success', true,
    'message', format('%s TL tutarında mevduat hesabı açıldı.', round(p_amount, 2)),
    'deposit_id', v_deposit_id,
    'expected_payout', v_expected_payout,
    'locked_until', now() + (p_days * interval '24 hours')
  );
end;
$$;

-- 9. RPC: Claim Deposit
CREATE OR REPLACE FUNCTION public.claim_deposit(p_deposit_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
declare
  v_player_id uuid := auth.uid();
  v_current_cash numeric;
  v_amount numeric;
  v_expected_payout numeric;
  v_locked_until timestamp with time zone;
  v_status text;
begin
  if v_player_id is null then
    return jsonb_build_object('success', false, 'message', 'Oturum acilmamis.');
  end if;

  -- Lock deposit record
  select status, amount, expected_payout, locked_until
  into v_status, v_amount, v_expected_payout, v_locked_until
  from public.player_deposits
  where id = p_deposit_id and player_id = v_player_id for update;

  if v_status is null then
    return jsonb_build_object('success', false, 'message', 'Mevduat kaydi bulunamadi.');
  end if;

  if v_status != 'active' then
    return jsonb_build_object('success', false, 'message', 'Bu mevduat hesabi zaten kapatilmis.');
  end if;

  if v_locked_until > now() then
    return jsonb_build_object('success', false, 'message', 'Mevduat vadesi henüz dolmadı.');
  end if;

  -- Lock player
  select cash into v_current_cash from public.players where id = v_player_id for update;

  -- Update deposit status
  update public.player_deposits
  set status = 'claimed',
      updated_at = now()
  where id = p_deposit_id;

  -- Add cash (principal + interest)
  update public.players
  set cash = cash + v_expected_payout
  where id = v_player_id;

  -- Log cash change
  perform public.log_player_cash_change(
    v_player_id,
    v_expected_payout,
    v_current_cash,
    'deposit_claimed',
    format('Mevduat Vade Sonu Tahsilati (Net Getiri: +%s TL)', round(v_expected_payout - v_amount, 2)),
    p_deposit_id,
    'deposit'
  );

  return jsonb_build_object(
    'success', true,
    'message', format('Mevduat başarıyla tahsil edildi. %s TL hesabınıza aktarıldı.', round(v_expected_payout, 2))
  );
end;
$$;

-- 10. RPC: Withdraw Deposit Early (Faizsiz, %5 anapara kesintisi ile kapatma)
CREATE OR REPLACE FUNCTION public.withdraw_deposit_early(p_deposit_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
declare
  v_player_id uuid := auth.uid();
  v_current_cash numeric;
  v_amount numeric;
  v_payout numeric;
  v_penalty numeric;
  v_status text;
begin
  if v_player_id is null then
    return jsonb_build_object('success', false, 'message', 'Oturum acilmamis.');
  end if;

  -- Lock deposit record
  select status, amount
  into v_status, v_amount
  from public.player_deposits
  where id = p_deposit_id and player_id = v_player_id for update;

  if v_status is null then
    return jsonb_build_object('success', false, 'message', 'Mevduat kaydi bulunamadi.');
  end if;

  if v_status != 'active' then
    return jsonb_build_object('success', false, 'message', 'Bu mevduat hesabi zaten kapatilmis.');
  end if;

  -- Lock player
  select cash into v_current_cash from public.players where id = v_player_id for update;

  -- Apply 5% penalty on principal
  v_penalty := v_amount * 0.05;
  v_payout := v_amount - v_penalty;

  -- Update deposit status
  update public.player_deposits
  set status = 'withdrawn_early',
      updated_at = now()
  where id = p_deposit_id;

  -- Add cash
  update public.players
  set cash = cash + v_payout
  where id = v_player_id;

  -- Log cash change
  perform public.log_player_cash_change(
    v_player_id,
    v_payout,
    v_current_cash,
    'deposit_early_withdrawal',
    format('Mevduat Erken Kapatma (Kesinti/Ceza: -%s TL)', round(v_penalty, 2)),
    p_deposit_id,
    'deposit'
  );

  return jsonb_build_object(
    'success', true,
    'message', format('Mevduat erken kapatıldı. %%5 kesinti uygulandı. %s TL hesabınıza aktarıldı.', round(v_payout, 2))
  );
end;
$$;

-- 11. Core Bank Tick Processing (Processes active loan installments)
CREATE OR REPLACE FUNCTION public.process_bank_ticks()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
declare
  v_rec record;
  v_player_cash numeric;
  v_status text;
  v_installments_paid integer;
begin
  -- Process due active/defaulted loan installments
  for v_rec in (
    select id, player_id, installment_amount, installments_paid, installments_total, next_installment_due_at
    from public.player_loans
    where status in ('active', 'defaulted') and next_installment_due_at <= now()
  ) loop
    -- Lock player cash
    select cash into v_player_cash from public.players where id = v_rec.player_id for update;

    if v_player_cash is not null then
      v_installments_paid := v_rec.installments_paid + 1;
      
      if v_installments_paid >= v_rec.installments_total then
        v_status := 'paid';
      else
        -- If cash is negative after deduction, set status to defaulted
        if (v_player_cash - v_rec.installment_amount) < 0 then
          v_status := 'defaulted';
        else
          v_status := 'active';
        end if;
      end if;

      -- Update player cash
      update public.players
      set cash = cash - v_rec.installment_amount
      where id = v_rec.player_id;

      -- Update loan record
      update public.player_loans
      set total_paid = total_paid + v_rec.installment_amount,
          installments_paid = v_installments_paid,
          next_installment_due_at = v_rec.next_installment_due_at + interval '24 hours',
          status = v_status,
          updated_at = now()
      where id = v_rec.id;

      -- Log cash change
      perform public.log_player_cash_change(
        v_rec.player_id,
        -v_rec.installment_amount,
        v_player_cash,
        'loan_payment_auto',
        format('Otomatik Kredi Taksit Tahsilatı (%s/%s)', v_installments_paid, v_rec.installments_total),
        v_rec.id,
        'loan'
      );
    end if;
  end loop;
end;
$$;

-- 12. Schedule Cron Job (Runs every 4 hours as per user request)
select cron.unschedule('process-bank-ticks-cron') 
where exists (select 1 from cron.job where jobname = 'process-bank-ticks-cron');

select cron.schedule(
  'process-bank-ticks-cron',
  '0 */4 * * *', -- Every 4 hours
  'SELECT public.process_bank_ticks();'
);
