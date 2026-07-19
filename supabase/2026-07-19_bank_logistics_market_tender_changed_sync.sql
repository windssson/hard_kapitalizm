-- DROP existing functions first to avoid parameter defaults or signature conflicts
DROP FUNCTION IF EXISTS public.take_loan(numeric, integer);
DROP FUNCTION IF EXISTS public.pay_loan_installment(uuid);
DROP FUNCTION IF EXISTS public.create_deposit(numeric, integer);
DROP FUNCTION IF EXISTS public.claim_deposit(uuid);
DROP FUNCTION IF EXISTS public.withdraw_deposit_early(uuid);
DROP FUNCTION IF EXISTS public.purchase_logistics_vehicle(uuid, uuid, uuid);
DROP FUNCTION IF EXISTS public.repair_logistics_vehicle(uuid, uuid);
DROP FUNCTION IF EXISTS public.start_logistics_company_construction(uuid, uuid, text);
DROP FUNCTION IF EXISTS public.start_multi_market_transfer(uuid, uuid, jsonb, uuid);
DROP FUNCTION IF EXISTS public.start_tender_delivery(uuid, uuid, uuid, integer);
DROP FUNCTION IF EXISTS public.submit_tender_bid(uuid, numeric);
DROP FUNCTION IF EXISTS public.accept_tender(uuid);


-- 1. Take Loan (changed player profile)
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
    'installment_amount', v_installment_amount,
    'changed', jsonb_build_object(
      'player', public.get_player_profile(v_player_id)
    )
  );
end;
$$;


-- 2. Pay Loan Installment (changed player profile)
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
    'status', v_status,
    'changed', jsonb_build_object(
      'player', public.get_player_profile(v_player_id)
    )
  );
end;
$$;


-- 3. Create Deposit (changed player profile)
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
    'locked_until', now() + (p_days * interval '24 hours'),
    'changed', jsonb_build_object(
      'player', public.get_player_profile(v_player_id)
    )
  );
end;
$$;


-- 4. Claim Deposit (changed player profile)
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
    'message', format('Mevduat başarıyla tahsil edildi. %s TL hesabınıza aktarıldı.', round(v_expected_payout, 2)),
    'changed', jsonb_build_object(
      'player', public.get_player_profile(v_player_id)
    )
  );
end;
$$;


-- 5. Withdraw Deposit Early (changed player profile)
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
    'message', format('Mevduat erken kapatıldı. %%5 kesinti uygulandı. %s TL hesabınıza aktarıldı.', round(v_payout, 2)),
    'changed', jsonb_build_object(
      'player', public.get_player_profile(v_player_id)
    )
  );
end;
$$;


-- 6. Purchase Logistics Vehicle (changed player profile)
CREATE OR REPLACE FUNCTION public.purchase_logistics_vehicle(
  p_player_id uuid,
  p_logistics_company_id uuid,
  p_logistics_vehicle_type_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
declare
  v_player_cash numeric;
  v_company record;
  v_type record;
  v_vehicle_id uuid;
begin
  select cash into v_player_cash from public.players where id = p_player_id for update;
  if not found then raise exception 'Oyuncu bulunamadi.'; end if;

  select * into v_company from public.logistics_companies
  where id = p_logistics_company_id and player_id = p_player_id for update;
  if not found then raise exception 'Nakliye firmasi bulunamadi.'; end if;
  if v_company.current_vehicle_count >= v_company.max_vehicle_count then raise exception 'Filo kapasitesi dolu.'; end if;

  select * into v_type from public.logistics_vehicle_types where id = p_logistics_vehicle_type_id;
  if not found then raise exception 'Arac tipi bulunamadi.'; end if;
  if v_player_cash < coalesce(v_type.purchase_price, 0) then
    raise exception 'Oyuncunun parasi yetersiz. Gerekli: %, mevcut: %', v_type.purchase_price, v_player_cash;
  end if;

  update public.players set cash = cash - coalesce(v_type.purchase_price, 0) where id = p_player_id;
  perform public.log_player_cash_change(
    p_player_id, -coalesce(v_type.purchase_price, 0), v_player_cash,
    'vehicle_purchase',
    format('Arac alimi: %s', v_type.name),
    p_logistics_company_id, 'logistics_company'
  );

  insert into public.logistics_vehicles (
    player_id, logistics_company_id, logistics_vehicle_type_id,
    capacity, speed_kmh, fuel_capacity, current_fuel, fuel_rate, condition, status, is_available_for_rent, rental_price
  ) values (
    p_player_id, p_logistics_company_id, p_logistics_vehicle_type_id,
    coalesce(v_type.capacity, 0), coalesce(v_type.speed_kmh, 0),
    coalesce(v_type.fuel_capacity, 0), coalesce(v_type.fuel_capacity, 0),
    coalesce(v_type.fuel_rate, 0), 100, 'idle', false, 0
  ) returning id into v_vehicle_id;

  update public.logistics_companies
  set current_vehicle_count = current_vehicle_count + 1, updated_at = timezone('utc'::text, now())
  where id = p_logistics_company_id;

  insert into public.logistics_finance_entries (
    player_id, logistics_company_id, vehicle_id, entry_type, category, amount, description, metadata
  ) values (
    p_player_id, p_logistics_company_id, v_vehicle_id, 'expense', 'vehicle_purchase',
    coalesce(v_type.purchase_price, 0), 'Arac alimi',
    jsonb_build_object('logistics_vehicle_type_id', p_logistics_vehicle_type_id, 'vehicle_type_name', v_type.name)
  );

  return jsonb_build_object(
    'success', true, 'vehicle_id', v_vehicle_id,
    'purchase_price', coalesce(v_type.purchase_price, 0),
    'remaining_cash', v_player_cash - coalesce(v_type.purchase_price, 0),
    'current_vehicle_count', v_company.current_vehicle_count + 1,
    'max_vehicle_count', v_company.max_vehicle_count,
    'changed', jsonb_build_object(
      'player', public.get_player_profile(p_player_id)
    )
  );
end;
$$;


-- 7. Repair Logistics Vehicle (changed player profile)
CREATE OR REPLACE FUNCTION public.repair_logistics_vehicle(p_player_id uuid, p_vehicle_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
declare
  v_vehicle record;
  v_vehicle_type record;
  v_player_cash numeric;
  v_missing_condition integer;
  v_missing_condition_ratio numeric;
  v_total_cost numeric;
begin
  select * into v_vehicle from public.logistics_vehicles
  where id = p_vehicle_id and player_id = p_player_id for update;
  if not found then raise exception 'Arac bulunamadi.'; end if;

  select * into v_vehicle_type from public.logistics_vehicle_types
  where id = v_vehicle.logistics_vehicle_type_id;
  if not found then raise exception 'Arac tipi bulunamadi.'; end if;

  select cash into v_player_cash from public.players where id = p_player_id for update;

  v_missing_condition := greatest(100 - v_vehicle.condition, 0);
  v_missing_condition_ratio := v_missing_condition / 100.0;
  v_total_cost := v_missing_condition_ratio * (coalesce(v_vehicle_type.purchase_price, 0) / 2.0);

  if v_total_cost > v_player_cash then
    raise exception 'Yetersiz nakit. Gerekli: %, mevcut: %', v_total_cost, v_player_cash;
  end if;

  update public.players set cash = cash - v_total_cost where id = p_player_id;
  perform public.log_player_cash_change(
    p_player_id, -v_total_cost, v_player_cash,
    'vehicle_repair',
    format('Arac bakimi: %s puan kondisyon', v_missing_condition),
    p_vehicle_id, 'vehicle'
  );

  update public.logistics_vehicles set condition = 100, updated_at = timezone('utc'::text, now())
  where id = p_vehicle_id;

  insert into public.logistics_finance_entries (
    player_id, logistics_company_id, vehicle_id, entry_type, category, amount, description, metadata
  ) values (
    p_player_id, v_vehicle.logistics_company_id, p_vehicle_id, 'expense', 'maintenance', v_total_cost,
    'Arac bakim gideri',
    jsonb_build_object('missing_condition', v_missing_condition, 'vehicle_type_id', v_vehicle.logistics_vehicle_type_id)
  );

  return jsonb_build_object(
    'success', true, 'vehicle_id', p_vehicle_id,
    'repair_cost', v_total_cost, 'condition', 100,
    'remaining_cash', v_player_cash - v_total_cost,
    'changed', jsonb_build_object(
      'player', public.get_player_profile(p_player_id)
    )
  );
end;
$$;


-- 8. Start Logistics Company Construction (changed player profile)
CREATE OR REPLACE FUNCTION public.start_logistics_company_construction(p_player_id uuid, p_type_id uuid, p_name text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
declare
  v_player_level integer;
  v_player_cash numeric;
  v_cost integer;
  v_required_level integer;
  v_construction_time_minutes integer;
  v_params jsonb;
  v_construction_id uuid;
  v_started_at timestamptz := timezone('utc'::text, now());
  v_finish_at timestamptz;
  v_clean_name text := trim(p_name);
begin
  if v_clean_name is null or length(v_clean_name) = 0 then raise exception 'Yapi adi bos olamaz.'; end if;
  if p_type_id is null then raise exception 'p_type_id bos olamaz.'; end if;

  select level, cash into v_player_level, v_player_cash from public.players where id = p_player_id for update;
  if not found then raise exception 'Oyuncu bulunamadi.'; end if;

  if exists (select 1 from public.building_constructions where player_id = p_player_id and status = 'in_progress') then
    raise exception 'Oyuncunun zaten aktif bir insaati var.';
  end if;

  select coalesce(cost, 0), coalesce(required_level, 1), coalesce(construction_time_minutes, 0),
    jsonb_build_object('logistics_company_type_id', id, 'name', v_clean_name, 'cost', coalesce(cost, 0),
      'required_level', coalesce(required_level, 1), 'construction_time_minutes', coalesce(construction_time_minutes, 0),
      'level', 1, 'current_vehicle_count', 0, 'max_vehicle_count', coalesce(max_vehicle_count, 0),
      'fuel_capacity', coalesce(fuel_capacity, 0), 'current_fuel', 0, 'fuel_cost', 0)
  into v_cost, v_required_level, v_construction_time_minutes, v_params
  from public.logistics_company_types where id = p_type_id;

  if v_params is null then raise exception 'Gecerli type kaydi bulunamadi.'; end if;
  if v_player_level < v_required_level then
    raise exception 'Oyuncu seviyesi yetersiz. Gerekli seviye: %, oyuncu seviyesi: %', v_required_level, v_player_level;
  end if;
  if v_player_cash < v_cost then
    raise exception 'Oyuncunun parasi yetersiz. Gerekli: %, mevcut: %', v_cost, v_player_cash;
  end if;

  v_finish_at := v_started_at + make_interval(mins => v_construction_time_minutes);

  update public.players set cash = cash - v_cost where id = p_player_id;
  perform public.log_player_cash_change(
    p_player_id, -v_cost, v_player_cash,
    'logistics_construction',
    format('Lojistik sirket insaati: %s', v_clean_name),
    null, 'logistics_company'
  );

  insert into public.building_constructions (player_id, building_kind, params, status, started_at, finish_at, completed_at)
  values (p_player_id, 'logistics_company', v_params, 'in_progress', v_started_at, v_finish_at, null)
  returning id into v_construction_id;

  return jsonb_build_object(
    'success', true, 'construction_id', v_construction_id, 'building_kind', 'logistics_company',
    'status', 'in_progress', 'started_at', v_started_at, 'finish_at', v_finish_at,
    'cost', v_cost, 'remaining_cash', v_player_cash - v_cost, 'params', v_params,
    'changed', jsonb_build_object(
      'player', public.get_player_profile(p_player_id)
    )
  );
end;
$$;


-- 9. Start Multi Market Transfer (changed player profile)
CREATE OR REPLACE FUNCTION public.start_multi_market_transfer(
  p_buyer_warehouse_id uuid,
  p_source_city_id uuid,
  p_items jsonb,
  p_vehicle_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
declare
  v_default_brand uuid := '00000000-0000-0000-0000-000000000000'::uuid;
  v_player_id uuid := auth.uid();
  v_npc_logistics_player_id uuid;
  v_now timestamptz := timezone('utc', now());
  v_target_warehouse record;
  v_source_city public.cities;
  v_vehicle public.logistics_vehicles;
  v_transfer_id uuid;
  v_header_item jsonb;
  v_header_slot record;
  v_header_product public.products;
  v_header_source_kind text;
  v_header_product_id text;
  v_header_quality_level integer;
  v_header_brand_id uuid;
  v_header_seller_player_id uuid;
  v_header_seller_warehouse_id uuid;
  v_item jsonb;
  v_seller_slot record;
  v_seller_slot_id uuid;
  v_product public.products;
  v_item_source_kind text;
  v_item_product_id text;
  v_item_quality_level integer := 1;
  v_item_brand_id uuid;
  v_item_unit_price numeric := 0;
  v_item_unit_cost numeric := 0;
  v_item_unit_volume numeric := 0;
  v_item_city_id uuid;
  v_item_quantity integer := 0;
  v_item_reserved_capacity numeric := 0;
  v_target_used_capacity numeric := 0;
  v_total_volume numeric := 0;
  v_total_quantity integer := 0;
  v_total_price numeric := 0;
  v_distance_km numeric := 0;
  v_fuel_used numeric := 0;
  v_condition_loss numeric := 0;
  v_transport_cost numeric := 0;
  v_rental_cost numeric := 0;
  v_duration_seconds integer := 0;
  v_finish_at timestamptz := v_now;
  v_item_count integer := 0;
  v_same_city boolean := false;
  v_mode text := 'instant';
  v_is_rental boolean := false;
  v_buyer_cash numeric := 0;
  v_total_payment numeric := 0;
begin
  if v_player_id is null then raise exception 'Oturum acilmamis.'; end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'Transfer sepeti bos olamaz.';
  end if;

  v_npc_logistics_player_id := public.get_npc_logistics_player_id();

  -- Create a temporary table to store the seller totals before we delete/update the warehouse slots!
  CREATE TEMP TABLE temp_seller_totals ON COMMIT DROP AS
  select
    case when coalesce(v_item.value ->> 'source_kind', 'warehouse_slot') = 'npc_market' then v_npc_logistics_player_id
         else w.player_id end as seller_player_id,
    sum(
      greatest(coalesce((v_item.value ->> 'quantity')::integer, 0), 0)
      * greatest(coalesce(case when coalesce(v_item.value ->> 'source_kind', 'warehouse_slot') = 'npc_market'
          then (v_item.value ->> 'unit_price')::numeric else ws.price end, 0), 0)
    ) as seller_amount
  from jsonb_array_elements(p_items) v_item(value)
  left join public.warehouse_slots ws
    on coalesce(v_item.value ->> 'source_kind', 'warehouse_slot') <> 'npc_market'
   and ws.id = (case when coalesce(v_item.value ->> 'source_kind', 'warehouse_slot') = 'npc_market' then null
                     else nullif(v_item.value ->> 'seller_slot_id', '')::uuid end)
  left join public.warehouses w on w.id = ws.warehouse_id
  group by 1;

  select w.*, c.map_position_x, c.map_position_y
  into v_target_warehouse
  from public.warehouses w join public.cities c on c.id = w.city_id
  where w.id = p_buyer_warehouse_id and w.player_id = v_player_id and w.is_active = true
  for update;
  if not found then raise exception 'Hedef depo bulunamadi.'; end if;

  v_header_item := p_items -> 0;
  v_header_source_kind := coalesce(v_header_item ->> 'source_kind', 'warehouse_slot');

  if v_header_source_kind = 'npc_market' then
    v_header_product_id := coalesce(v_header_item ->> 'product_id', '');
    v_header_quality_level := greatest(coalesce((v_header_item ->> 'quality_level')::integer, 1), 1);
    v_header_brand_id := coalesce(nullif(v_header_item ->> 'brand_id', '')::uuid, v_default_brand);
    v_header_seller_player_id := v_npc_logistics_player_id;
    v_header_seller_warehouse_id := null;
    if coalesce(v_header_item ->> 'city_id', '') <> p_source_city_id::text then
      raise exception 'Transfer sehir kilidi ilk secilen sehir ile eslesmiyor.';
    end if;
    select * into v_header_product from public.products where id = v_header_product_id;
    if not found then raise exception 'Ilk NPC ilan urunu bulunamadi.'; end if;
  else
    select ws.*, w.id as seller_warehouse_id, w.name as seller_warehouse_name,
           w.player_id as seller_player_id, w.city_id, c.map_position_x, c.map_position_y
    into v_header_slot
    from public.warehouse_slots ws join public.warehouses w on w.id = ws.warehouse_id join public.cities c on c.id = w.city_id
    where ws.id = (v_header_item ->> 'seller_slot_id')::uuid for update;
    if not found then raise exception 'Ilk satici slotu bulunamadi.'; end if;
    if v_header_slot.seller_player_id = v_player_id then raise exception 'Kendi market ilaninizi satin alamazsiniz.'; end if;
    if v_header_slot.city_id <> p_source_city_id then raise exception 'Transfer sehir kilidi ilk secilen sehir ile eslesmiyor.'; end if;
    if coalesce(v_header_slot.product_id, '') = '' then raise exception 'Ilk ilanda urun bulunamadi.'; end if;
    select * into v_header_product from public.products where id = v_header_slot.product_id;
    if not found then raise exception 'Ilk ilan urunu bulunamadi.'; end if;
    v_header_product_id := v_header_slot.product_id;
    v_header_quality_level := greatest(coalesce(v_header_slot.quality_level, 1), 1);
    v_header_brand_id := coalesce(v_header_slot.brand_id, v_default_brand);
    v_header_seller_player_id := v_header_slot.seller_player_id;
    v_header_seller_warehouse_id := v_header_slot.seller_warehouse_id;
  end if;

  select * into v_source_city from public.cities where id = p_source_city_id;
  if not found then raise exception 'Kaynak sehir bulunamadi.'; end if;

  v_same_city := v_target_warehouse.city_id = p_source_city_id;
  if not v_same_city then v_mode := 'in_transit'; end if;

  insert into public.logistics_transfers (
    buyer_player_id, seller_player_id, buyer_warehouse_id, seller_warehouse_id,
    logistics_vehicle_id, vehicle_owner_player_id, is_rental, product_id, quality_level, quantity,
    unit_price, total_price, product_unit_volume, reserved_capacity_amount, distance_km,
    fuel_used, condition_loss, rental_cost, transport_cost, started_at, finish_at, status,
    transfer_type, seller_entity_kind, buyer_entity_kind, item_count, total_quantity, brand_id, created_at, updated_at
  ) values (
    v_player_id, v_header_seller_player_id, v_target_warehouse.id, v_header_seller_warehouse_id,
    p_vehicle_id, null, false, v_header_product_id, v_header_quality_level, 1,
    0, 0, 1, 0, 0, 0, 0, 0, 0, v_now, v_now, 'in_transit',
    'market_to_warehouse_multi',
    case when v_header_source_kind = 'npc_market' then 'npc_market' else 'warehouse' end,
    'warehouse', 1, 0, v_header_brand_id, v_now, v_now
  ) returning id into v_transfer_id;

  select coalesce(sum((ws.quantity + coalesce(ws.pending_quantity, 0)) * coalesce(p.birim_hacim, 0)), 0)
  into v_target_used_capacity
  from public.warehouse_slots ws left join public.products p on p.id = ws.product_id
  where ws.warehouse_id = v_target_warehouse.id;

  for v_item in select value from jsonb_array_elements(p_items) loop
    v_seller_slot_id := null;
    v_item_quantity := greatest(coalesce((v_item ->> 'quantity')::integer, 0), 0);
    if v_item_quantity <= 0 then raise exception 'Transfer miktari 0 dan buyuk olmalidir.'; end if;
    v_item_source_kind := coalesce(v_item ->> 'source_kind', 'warehouse_slot');
    v_item_city_id := nullif(v_item ->> 'city_id', '')::uuid;
    if v_item_city_id is null or v_item_city_id <> p_source_city_id then
      raise exception 'Sepetteki tum ilanlar ayni sehirde olmalidir.';
    end if;

    if v_item_source_kind = 'npc_market' then
      v_item_product_id := coalesce(v_item ->> 'product_id', '');
      v_item_quality_level := greatest(coalesce((v_item ->> 'quality_level')::integer, 1), 1);
      v_item_brand_id := coalesce(nullif(v_item ->> 'brand_id', '')::uuid, v_default_brand);
      v_item_unit_price := greatest(coalesce((v_item ->> 'unit_price')::numeric, 0), 0);
      v_item_unit_cost := greatest(coalesce((v_item ->> 'unit_cost')::numeric, v_item_unit_price), 0);
      select * into v_product from public.products where id = v_item_product_id;
      if not found then raise exception 'NPC urunu bulunamadi.'; end if;
      v_item_unit_volume := coalesce((v_item ->> 'unit_volume')::numeric, coalesce(v_product.birim_hacim, 0));
      v_item_reserved_capacity := v_item_quantity * v_item_unit_volume;
    else
      select ws.*, w.id as seller_warehouse_id, w.name as seller_warehouse_name, w.player_id as seller_player_id, w.city_id
      into v_seller_slot
      from public.warehouse_slots ws join public.warehouses w on w.id = ws.warehouse_id
      where ws.id = (v_item ->> 'seller_slot_id')::uuid for update;
      if not found then raise exception 'Satici slotu bulunamadi.'; end if;
      v_seller_slot_id := v_seller_slot.id;
      if v_seller_slot.seller_player_id = v_player_id then raise exception 'Kendi market ilaninizi satin alamazsiniz.'; end if;
      if v_seller_slot.city_id <> p_source_city_id then raise exception 'Sepetteki tum ilanlar ayni sehirde olmalidir.'; end if;
      if coalesce(v_seller_slot.is_available_for_sale, false) = false or coalesce(v_seller_slot.price, 0) <= 0 then
        raise exception 'Secilen slot satisa uygun degil.';
      end if;
      if coalesce(v_seller_slot.quantity, 0) < v_item_quantity then raise exception 'Satici stokunda yeterli urun yok.'; end if;
      select * into v_product from public.products where id = v_seller_slot.product_id;
      if not found then raise exception 'Urun bulunamadi.'; end if;
      v_item_product_id := v_seller_slot.product_id;
      v_item_quality_level := v_seller_slot.quality_level;
      v_item_brand_id := coalesce(v_seller_slot.brand_id, v_default_brand);
      v_item_unit_price := coalesce(v_seller_slot.price, 0);
      v_item_unit_cost := coalesce(v_seller_slot.cost, 0);
      v_item_unit_volume := coalesce(v_product.birim_hacim, 0);
      v_item_reserved_capacity := v_item_quantity * v_item_unit_volume;
    end if;

    if v_target_used_capacity + coalesce(v_target_warehouse.reserved_capacity, 0) + v_total_volume + v_item_reserved_capacity > coalesce(v_target_warehouse.capacity, 0) then
      raise exception 'Hedef depoda yeterli kapasite yok.';
    end if;

    -- 1. Insert into logistics_transfer_items first while seller slot is still present.
    insert into public.logistics_transfer_items (
      transfer_id, source_warehouse_slot_id, target_warehouse_slot_id, product_id, quality_level, brand_id,
      quantity, unit_cost, unit_price, total_cost, total_price, product_unit_volume, reserved_capacity_amount,
      status, created_at, updated_at
    ) values (
      v_transfer_id, v_seller_slot_id, null, v_item_product_id, v_item_quality_level, v_item_brand_id,
      v_item_quantity, v_item_unit_cost, v_item_unit_price,
      v_item_quantity * v_item_unit_cost, v_item_quantity * v_item_unit_price,
      v_item_unit_volume, v_item_reserved_capacity, 'in_transit', v_now, v_now
    );

    -- 2. Then update/delete the seller slot. If it gets deleted, ON DELETE SET NULL handles it correctly.
    if v_item_source_kind <> 'npc_market' then
      update public.warehouse_slots set quantity = quantity - v_item_quantity, updated_at = v_now where id = v_seller_slot_id;
      if coalesce(v_seller_slot.quantity, 0) - v_item_quantity <= 0 and coalesce(v_seller_slot.pending_quantity, 0) <= 0 then
        delete from public.warehouse_slots where id = v_seller_slot_id;
      end if;
    end if;

    v_item_count := v_item_count + 1;
    v_total_quantity := v_total_quantity + v_item_quantity;
    v_total_volume := v_total_volume + v_item_reserved_capacity;
    v_total_price := v_total_price + (v_item_quantity * v_item_unit_price);
  end loop;

  if v_item_count <= 0 then raise exception 'Transfer icin kalem bulunamadi.'; end if;

  if not v_same_city then
    if p_vehicle_id is null then raise exception 'Sehirler arasi transfer icin arac secilmelidir.'; end if;
    select * into v_vehicle
    from public.logistics_vehicles
    where id = p_vehicle_id and (player_id = v_player_id or (player_id = v_npc_logistics_player_id and is_available_for_rent = true)) and status = 'idle'
    for update;
    if not found then raise exception 'Secilen arac kullanima uygun degil.'; end if;
    v_distance_km := round(
      (
        6371 * 2 * asin(
          sqrt(
            power(sin(radians(coalesce(v_target_warehouse.map_position_x, 0) - coalesce(v_source_city.map_position_x, 0)) / 2), 2)
            + cos(radians(coalesce(v_source_city.map_position_x, 0)))
            * cos(radians(coalesce(v_target_warehouse.map_position_x, 0)))
            * power(sin(radians(coalesce(v_target_warehouse.map_position_y, 0) - coalesce(v_source_city.map_position_y, 0)) / 2), 2)
          )
        )
      )::numeric,
      2
    );
    if coalesce(v_vehicle.capacity, 0) < ceil(v_total_volume) then raise exception 'Secilen aracin kapasitesi bu transfer icin yetersiz.'; end if;
    if coalesce(v_vehicle.speed_kmh, 0) <= 0 then raise exception 'Secilen aracin hizi gecersiz.'; end if;
    v_is_rental := v_vehicle.player_id = v_npc_logistics_player_id;
    v_duration_seconds := greatest(60, ceil((greatest(v_distance_km, 1) / v_vehicle.speed_kmh) * 120)::integer);
    v_finish_at := v_now + make_interval(secs => v_duration_seconds);
    v_fuel_used := round(v_distance_km * coalesce(v_vehicle.fuel_rate, 0), 2);
    v_condition_loss := greatest(1, ceil(v_distance_km / 25.0));
    v_transport_cost := case
      when v_is_rental then round(v_distance_km * coalesce(v_vehicle.rental_price, 0), 2)
      else round(v_fuel_used * coalesce(v_vehicle.fuel_cost, 0), 2)
    end;
    v_rental_cost := case when v_is_rental then v_transport_cost else 0 end;
    if coalesce(v_vehicle.current_fuel, 0) < ceil(v_fuel_used) then raise exception 'Aracta yeterli yakit yok.'; end if;
    if coalesce(v_vehicle.condition, 0) <= 0 then raise exception 'Aracin bakimi yetersiz.'; end if;
    update public.logistics_vehicles
    set status = 'on_route', current_fuel = greatest(current_fuel - ceil(v_fuel_used), 0),
        condition = greatest(condition - ceil(v_condition_loss), 0), updated_at = v_now
    where id = v_vehicle.id;
  end if;

  v_total_payment := v_total_price + v_rental_cost;

  select cash into v_buyer_cash from public.players where id = v_player_id for update;
  if coalesce(v_buyer_cash, 0) < v_total_payment then raise exception 'Yeterli nakit yok.'; end if;

  update public.players set cash = cash - v_total_payment where id = v_player_id;
  perform public.log_player_cash_change(
    v_player_id, -v_total_payment, v_buyer_cash,
    'market_purchase',
    format('Pazar alimi: %s kalem, %s adet (nakliye: %s TL)', v_item_count, v_total_quantity, round(v_rental_cost + v_transport_cost, 0)),
    v_transfer_id, 'logistics_transfer'
  );

  update public.players p
  set cash = cash + st.seller_amount
  from temp_seller_totals st
  where p.id = st.seller_player_id and st.seller_player_id is not null and coalesce(st.seller_amount, 0) > 0;

  -- Log seller revenues (non-NPC sellers only)
  perform public.log_player_cash_change(
    st.seller_player_id, st.seller_amount,
    (select cash - st.seller_amount from public.players where id = st.seller_player_id),
    'market_sale',
    format('Pazar satisi: %s TL', round(st.seller_amount, 0)),
    v_transfer_id, 'logistics_transfer'
  )
  from temp_seller_totals st
  where st.seller_player_id is not null
    and st.seller_player_id <> v_npc_logistics_player_id
    and coalesce(st.seller_amount, 0) > 0;

  if v_is_rental and v_vehicle.player_id is not null then
    update public.players set cash = cash + v_rental_cost where id = v_vehicle.player_id;
    perform public.log_player_cash_change(
      v_vehicle.player_id, v_rental_cost,
      (select cash - v_rental_cost from public.players where id = v_vehicle.player_id),
      'vehicle_rental_income',
      format('Arac kiralama geliri: %s km, %s TL', round(v_distance_km, 0), round(v_rental_cost, 0)),
      p_vehicle_id, 'vehicle'
    );
  end if;

  update public.warehouses
  set reserved_capacity = coalesce(reserved_capacity, 0) + v_total_volume, updated_at = v_now
  where id = v_target_warehouse.id;

  update public.logistics_transfers
  set logistics_vehicle_id = p_vehicle_id,
      vehicle_owner_player_id = case when p_vehicle_id is not null then v_vehicle.player_id else null end,
      is_rental = v_is_rental, quantity = greatest(v_total_quantity, 1), total_price = v_total_price,
      product_unit_volume = greatest(v_total_volume, 0.0001), reserved_capacity_amount = v_total_volume,
      distance_km = v_distance_km, fuel_used = v_fuel_used, condition_loss = v_condition_loss,
      rental_cost = v_rental_cost, transport_cost = v_transport_cost, finish_at = v_finish_at,
      item_count = v_item_count, total_quantity = v_total_quantity, updated_at = v_now
  where id = v_transfer_id;

  if v_same_city then
    perform public.complete_logistics_transfer(v_transfer_id);
  end if;

  return jsonb_build_object(
    'success', true, 'transfer_id', v_transfer_id, 'mode', v_mode,
    'item_count', v_item_count, 'total_quantity', v_total_quantity,
    'reserved_capacity_amount', v_total_volume, 'transport_cost', v_transport_cost, 'finish_at', v_finish_at,
    'changed', jsonb_build_object(
      'player', public.get_player_profile(v_player_id)
    )
  );
end;
$$;


-- 10. Start Tender Delivery (changed player profile)
CREATE OR REPLACE FUNCTION public.start_tender_delivery(
  p_player_tender_id uuid,
  p_warehouse_id uuid,
  p_vehicle_id uuid,
  p_quantity integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
declare
  v_default_vehicle_id constant uuid := '00000000-0000-0000-0000-000000000000'::uuid;
  v_player_id uuid := auth.uid();
  v_now timestamptz := timezone('utc'::text, now());
  v_player_tender public.player_tenders%rowtype;
  v_warehouse public.warehouses%rowtype;
  v_slot record;
  v_same_city boolean := false;
  v_remaining_quantity integer := 0;
  v_selected_quantity integer := 0;
  v_in_transit_quantity integer := 0;
  v_delivery_id uuid;
  v_finish_at timestamptz;
  v_tender_title text := 'Ihale';
  v_distance_km numeric := 0;
  v_estimated_duration_minutes integer := 5;
  v_transport_cost numeric := 0;
  v_product_unit_volume numeric := 0;
  v_total_volume numeric := 0;
  v_cash_before numeric := 0;
  v_vehicle_option record;
begin
  if v_player_id is null then
    return jsonb_build_object('success', false, 'message', 'Oturum acilmamis.');
  end if;

  if coalesce(p_quantity, 0) <= 0 then
    return jsonb_build_object('success', false, 'message', 'Teslim miktari sifirdan buyuk olmali.');
  end if;

  select *
  into v_player_tender
  from public.player_tenders
  where id = p_player_tender_id
    and player_id = v_player_id
  for update;

  if not found then
    return jsonb_build_object('success', false, 'message', 'Oyuncu ihalesi bulunamadi.');
  end if;

  if v_player_tender.status <> 'active' then
    return jsonb_build_object('success', false, 'message', 'Ihale aktif degil.');
  end if;

  if v_player_tender.deadline_at <= v_now then
    return jsonb_build_object('success', false, 'message', 'Ihale suresi dolmus.');
  end if;

  select *
  into v_warehouse
  from public.warehouses
  where id = p_warehouse_id
    and player_id = v_player_id
    and is_active = true
  for update;

  if not found then
    return jsonb_build_object('success', false, 'message', 'Depo bulunamadi.');
  end if;

  select coalesce(t.title, 'Ihale')
  into v_tender_title
  from public.tenders t
  where t.id = v_player_tender.tender_id;

  select coalesce(sum(td.quantity), 0)::integer
  into v_in_transit_quantity
  from public.tender_deliveries td
  where td.player_tender_id = v_player_tender.id
    and td.status = 'in_transit';

  v_same_city := v_warehouse.city_id = v_player_tender.city_id;

  v_remaining_quantity := greatest(
    v_player_tender.required_quantity - v_player_tender.delivered_quantity - v_in_transit_quantity,
    0
  );
  if v_remaining_quantity <= 0 then
    return jsonb_build_object('success', false, 'message', 'Ihale icin bekleyen ihtiyac kalmadi.');
  end if;

  v_selected_quantity := least(p_quantity, v_remaining_quantity);

  select
    ws.id,
    ws.quantity,
    ws.quality_level
  into v_slot
  from public.warehouse_slots ws
  where ws.warehouse_id = v_warehouse.id
    and ws.product_id = v_player_tender.product_id
    and ws.quality_level >= v_player_tender.quality_level
    and coalesce(ws.quantity, 0) > 0
  order by ws.quality_level asc, ws.id asc
  for update;

  if not found then
    return jsonb_build_object('success', false, 'message', 'Depoda uygun kalite stok bulunamadi.');
  end if;

  if coalesce(v_slot.quantity, 0) <= 0 then
    return jsonb_build_object('success', false, 'message', 'Depoda kullanilabilir stok yok.');
  end if;

  v_selected_quantity := least(v_selected_quantity, v_slot.quantity);

  select coalesce(p.birim_hacim, 0)
  into v_product_unit_volume
  from public.products p
  where p.id = v_player_tender.product_id;

  v_total_volume := greatest(v_selected_quantity * greatest(v_product_unit_volume, 0), 0.0001);

  if v_same_city then
    v_distance_km := 0;
    v_estimated_duration_minutes := 5;
    v_transport_cost := 0;
  else
    if p_vehicle_id is null or p_vehicle_id = v_default_vehicle_id then
      return jsonb_build_object(
        'success', false,
        'message', 'Sehirler arasi teslimatta arac secmelisin.'
      );
    end if;

    select *
    into v_vehicle_option
    from public.get_route_transfer_vehicle_options(
      v_warehouse.city_id,
      v_player_tender.city_id,
      v_total_volume
    ) opt
    where opt.vehicle_id = p_vehicle_id
      and opt.can_select = true
    limit 1;

    if not found then
      return jsonb_build_object(
        'success', false,
        'message', 'Secilen arac bu teslimat icin artik uygun degil.'
      );
    end if;

    v_distance_km := coalesce(v_vehicle_option.distance_km, 0);
    v_estimated_duration_minutes := greatest(
      1,
      ceil(coalesce(v_vehicle_option.estimated_duration_seconds, 0) / 60.0)
    )::integer;
    v_transport_cost := coalesce(v_vehicle_option.total_price, 0);
  end if;

  v_finish_at := v_now + make_interval(mins => v_estimated_duration_minutes);

  if v_finish_at > v_player_tender.deadline_at then
    return jsonb_build_object(
      'success', false,
      'message', 'Bu depodan cikacak teslimat son tarihe yetismiyor.'
    );
  end if;

  if not v_same_city then
    select coalesce(cash, 0)
    into v_cash_before
    from public.players
    where id = v_player_id
    for update;

    if v_cash_before < v_transport_cost then
      return jsonb_build_object(
        'success', false,
        'message', 'Secilen arac icin yeterli nakit yok.'
      );
    end if;

    if v_transport_cost > 0 then
      update public.players
      set cash = cash - v_transport_cost
      where id = v_player_id;

      perform public.log_player_cash_change(
        v_player_id,
        -v_transport_cost,
        v_cash_before,
        'tender_delivery_transport_paid',
        format('Ihale teslimati nakliye bedeli odendi. Tender: %s', v_player_tender.tender_id),
        v_player_tender.id,
        'player_tender'
      );
    end if;

    update public.logistics_vehicles
    set status = 'on_route',
        current_fuel = greatest(current_fuel - ceil(coalesce(v_vehicle_option.fuel_needed, 0)), 0),
        condition = greatest(condition - ceil(coalesce(v_vehicle_option.condition_needed, 0)), 0),
        updated_at = v_now
    where id = p_vehicle_id;
  end if;

  update public.warehouse_slots
  set quantity = quantity - v_selected_quantity,
      updated_at = v_now
  where id = v_slot.id;

  insert into public.tender_deliveries (
    player_tender_id,
    player_id,
    source_warehouse_id,
    vehicle_id,
    quantity,
    status,
    same_city,
    started_at,
    finish_at,
    cost
  )
  values (
    v_player_tender.id,
    v_player_id,
    v_warehouse.id,
    case when v_same_city then null else p_vehicle_id end,
    v_selected_quantity,
    'in_transit',
    v_same_city,
    v_now,
    v_finish_at,
    v_transport_cost
  )
  returning id into v_delivery_id;

  update public.player_tenders
  set updated_at = v_now
  where id = v_player_tender.id;

  insert into public.player_notifications (
    player_id,
    kind,
    category,
    title,
    message,
    entity_kind,
    entity_id,
    severity,
    status,
    meta,
    dedupe_key
  )
  values (
    v_player_id,
    'event',
    'tender_delivery_started',
    'Ihale Teslimati Basladi',
    format('%s icin %s adet urun yola cikarildi.', v_tender_title, v_selected_quantity),
    'player_tender',
    v_player_tender.id,
    'info',
    'unread',
    jsonb_build_object(
      'player_tender_id', v_player_tender.id,
      'tender_id', v_player_tender.tender_id,
      'delivery_id', v_delivery_id,
      'source_warehouse_id', v_warehouse.id,
      'vehicle_id', case when v_same_city then null else p_vehicle_id end,
      'quantity', v_selected_quantity,
      'finish_at', v_finish_at,
      'estimated_duration_minutes', v_estimated_duration_minutes,
      'distance_km', v_distance_km,
      'transport_cost', v_transport_cost
    ),
    format('tender:delivery_started:%s', v_delivery_id)
  )
  on conflict (player_id, dedupe_key) do nothing;

  return jsonb_build_object(
    'success', true,
    'delivery_id', v_delivery_id,
    'player_tender_id', v_player_tender.id,
    'quantity', v_selected_quantity,
    'finish_at', v_finish_at,
    'estimated_duration_minutes', v_estimated_duration_minutes,
    'distance_km', v_distance_km,
    'transport_cost', v_transport_cost,
    'message', 'Ihale teslimati yola cikti.',
    'changed', jsonb_build_object(
      'player', public.get_player_profile(v_player_id)
    )
  );
end;
$$;


-- 11. Submit Tender Bid (changed player profile)
CREATE OR REPLACE FUNCTION public.submit_tender_bid(p_tender_id uuid, p_bid_amount numeric)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
declare
  v_player_id uuid := auth.uid();
  v_player public.players%rowtype;
  v_tender public.tenders%rowtype;
  v_existing_bid public.tender_bids%rowtype;
  v_bid_id uuid;
  v_now timestamptz := timezone('utc'::text, now());
  v_message text := 'Teklif kaydedildi.';
begin
  if v_player_id is null then
    return jsonb_build_object('success', false, 'message', 'Oturum acilmamis.');
  end if;

  if coalesce(p_bid_amount, 0) <= 0 then
    return jsonb_build_object('success', false, 'message', 'Teklif sifirdan buyuk olmali.');
  end if;

  select * into v_player from public.players where id = v_player_id for update;
  if not found then
    return jsonb_build_object('success', false, 'message', 'Oyuncu bulunamadi.');
  end if;

  select * into v_tender from public.tenders where id = p_tender_id for update;
  if not found then
    return jsonb_build_object('success', false, 'message', 'Ihale bulunamadi.');
  end if;

  if v_tender.award_type <> 'lowest_bid' then
    return jsonb_build_object('success', false, 'message', 'Bu ihale teklif usulu degil.');
  end if;

  if v_tender.status <> 'open' or v_tender.accept_until <= v_now then
    return jsonb_build_object('success', false, 'message', 'Ihale teklif almiyor.');
  end if;

  if coalesce(v_player.level, 1) < v_tender.min_player_level then
    return jsonb_build_object('success', false, 'message', 'Oyuncu seviyesi yeterli degil.');
  end if;

  if p_bid_amount > coalesce(v_tender.reward_cash, 0) then
    return jsonb_build_object(
      'success', false,
      'message', format('Teklif tavan odulu gecemez. En fazla %s verebilirsin.', v_tender.reward_cash)
    );
  end if;

  if exists (
    select 1 from public.player_tenders pt
    where pt.player_id = v_player_id and pt.tender_id = v_tender.id
  ) then
    return jsonb_build_object('success', false, 'message', 'Bu ihale zaten sana atanmis.');
  end if;

  select * into v_existing_bid
  from public.tender_bids tb
  where tb.player_id = v_player_id
    and tb.tender_id = v_tender.id
  for update;

  if found then
    update public.tender_bids
    set bid_amount = p_bid_amount, updated_at = v_now
    where id = v_existing_bid.id
    returning id into v_bid_id;
    v_message := 'Teklif guncellendi.';
  else
    if coalesce(v_player.cash, 0) < v_tender.bond_amount then
      return jsonb_build_object('success', false, 'message', 'Teminat icin yeterli nakit yok.');
    end if;

    update public.players set cash = cash - v_tender.bond_amount where id = v_player_id;

    insert into public.tender_bids (
      tender_id, player_id, bid_amount, bond_paid, status, submitted_at, created_at, updated_at
    )
    values (
      v_tender.id, v_player_id, p_bid_amount, v_tender.bond_amount, 'active', v_now, v_now, v_now
    )
    returning id into v_bid_id;

    perform public.log_player_cash_change(
      v_player_id,
      -v_tender.bond_amount,
      v_player.cash,
      'tender_bid_bond_paid',
      format('Ihale teklif teminati odendi. Tender: %s', v_tender.id),
      v_bid_id,
      'tender_bid'
    );
  end if;

  return jsonb_build_object(
    'success', true,
    'tender_bid_id', v_bid_id,
    'bid_amount', p_bid_amount,
    'bond_amount', v_tender.bond_amount,
    'message', v_message,
    'changed', jsonb_build_object(
      'player', public.get_player_profile(v_player_id)
    )
  );
end;
$$;


-- 12. Accept Tender (changed player profile)
CREATE OR REPLACE FUNCTION public.accept_tender(p_tender_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
declare
  v_player_id uuid := auth.uid();
  v_player public.players%rowtype;
  v_tender public.tenders%rowtype;
  v_player_tender_id uuid;
  v_deadline_at timestamptz;
begin
  if v_player_id is null then
    return jsonb_build_object('success', false, 'message', 'Oturum acilmamis.');
  end if;

  perform public.ensure_open_tenders();

  select * into v_player from public.players where id = v_player_id for update;
  if not found then
    return jsonb_build_object('success', false, 'message', 'Oyuncu bulunamadi.');
  end if;

  select * into v_tender from public.tenders where id = p_tender_id for update;
  if not found then
    return jsonb_build_object('success', false, 'message', 'Ihale bulunamadi.');
  end if;

  if v_tender.award_type <> 'first_claim' then
    return jsonb_build_object('success', false, 'message', 'Bu ihale teklif usulu ile calisiyor.');
  end if;

  if v_tender.status <> 'open' then
    return jsonb_build_object('success', false, 'message', 'Ihale artik uygun degil.');
  end if;

  if v_tender.accept_until <= timezone('utc'::text, now()) then
    return jsonb_build_object('success', false, 'message', 'Ihaleye katilim suresi doldu.');
  end if;

  if coalesce(v_player.level, 1) < v_tender.min_player_level then
    return jsonb_build_object('success', false, 'message', 'Oyuncu seviyesi yeterli degil.');
  end if;

  if exists (
    select 1 from public.player_tenders pt
    where pt.player_id = v_player_id and pt.tender_id = v_tender.id
  ) then
    return jsonb_build_object('success', false, 'message', 'Bu ihaleye zaten katildin.');
  end if;

  if coalesce(v_player.cash, 0) < v_tender.bond_amount then
    return jsonb_build_object('success', false, 'message', 'Teminat icin yeterli nakit yok.');
  end if;

  update public.players set cash = cash - v_tender.bond_amount where id = v_player_id;

  v_deadline_at := timezone('utc'::text, now()) + make_interval(mins => v_tender.delivery_duration_minutes);

  insert into public.player_tenders (
    player_id, tender_id, accepted_at, deadline_at, bond_paid, required_quantity,
    delivered_quantity, reward_cash, product_id, quality_level, city_id, status
  )
  values (
    v_player_id, v_tender.id, timezone('utc'::text, now()), v_deadline_at, v_tender.bond_amount,
    v_tender.required_quantity, 0, v_tender.reward_cash, v_tender.product_id, v_tender.quality_level,
    v_tender.city_id, 'active'
  )
  returning id into v_player_tender_id;

  update public.tenders set status = 'closed', updated_at = timezone('utc'::text, now()) where id = v_tender.id;

  perform public.log_player_cash_change(
    v_player_id,
    -v_tender.bond_amount,
    v_player.cash,
    'tender_bond_paid',
    format('Ihale teminati odendi. Tender: %s', v_tender.id),
    v_player_tender_id,
    'player_tender'
  );

  insert into public.player_notifications (
    player_id,
    kind,
    category,
    title,
    message,
    entity_kind,
    entity_id,
    severity,
    status,
    meta,
    dedupe_key
  )
  values (
    v_player_id,
    'event',
    'tender_accepted',
    'Ihale Kabul Edildi',
    format('%s kabul edildi. Ihale artik baskalarina kapanmistir.', v_tender.title),
    'player_tender',
    v_player_tender_id,
    'success',
    'unread',
    jsonb_build_object(
      'player_tender_id', v_player_tender_id,
      'tender_id', v_tender.id,
      'deadline_at', v_deadline_at,
      'required_quantity', v_tender.required_quantity,
      'bond_amount', v_tender.bond_amount
    ),
    format('tender:accepted:%s', v_player_tender_id)
  )
  on conflict (player_id, dedupe_key) do nothing;

  return jsonb_build_object(
    'success', true,
    'player_tender_id', v_player_tender_id,
    'deadline_at', v_deadline_at,
    'message', 'Ihale kabul edildi ve sana atandi.',
    'changed', jsonb_build_object(
      'player', public.get_player_profile(v_player_id)
    )
  );
end;
$$;
