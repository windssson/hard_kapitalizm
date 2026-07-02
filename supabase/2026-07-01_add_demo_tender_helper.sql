create or replace function public.create_demo_tender(
  p_product_id text default null,
  p_city_id uuid default null,
  p_quality_level integer default 1,
  p_required_quantity integer default 500,
  p_reward_cash numeric default 100000,
  p_bond_amount numeric default 15000,
  p_accept_minutes integer default 180,
  p_delivery_minutes integer default 120
)
returns jsonb
language plpgsql
security definer
set search_path = 'public'
as $$
declare
  v_player_id uuid := auth.uid();
  v_city_id uuid;
  v_product_id text;
  v_tender_id uuid;
begin
  if v_player_id is null then
    return jsonb_build_object('success', false, 'message', 'Oturum acilmamis.');
  end if;

  if coalesce(p_quality_level, 0) < 1 then
    return jsonb_build_object('success', false, 'message', 'Kalite seviyesi gecersiz.');
  end if;

  if coalesce(p_required_quantity, 0) <= 0 then
    return jsonb_build_object('success', false, 'message', 'Miktar gecersiz.');
  end if;

  if coalesce(p_accept_minutes, 0) <= 0 or coalesce(p_delivery_minutes, 0) <= 0 then
    return jsonb_build_object('success', false, 'message', 'Sure parametreleri gecersiz.');
  end if;

  v_city_id := p_city_id;
  if v_city_id is null then
    select c.id
    into v_city_id
    from public.cities c
    order by c.name asc
    limit 1;
  end if;

  if v_city_id is null then
    return jsonb_build_object('success', false, 'message', 'Sehir bulunamadi.');
  end if;

  v_product_id := p_product_id;
  if v_product_id is null then
    select p.id
    into v_product_id
    from public.products p
    where coalesce(p.urun_adi, '') <> ''
    order by p.urun_adi asc
    limit 1;
  end if;

  if v_product_id is null then
    return jsonb_build_object('success', false, 'message', 'Urun bulunamadi.');
  end if;

  insert into public.tenders (
    title,
    description,
    city_id,
    product_id,
    quality_level,
    required_quantity,
    reward_cash,
    bond_amount,
    accept_until,
    delivery_duration_minutes,
    status,
    visibility,
    min_player_level
  )
  values (
    'Demo Ihale',
    'MCP uzerinden olusturulan test ihalesi.',
    v_city_id,
    v_product_id,
    p_quality_level,
    p_required_quantity,
    p_reward_cash,
    p_bond_amount,
    timezone('utc'::text, now()) + make_interval(mins => p_accept_minutes),
    p_delivery_minutes,
    'open',
    'public',
    1
  )
  returning id into v_tender_id;

  return jsonb_build_object(
    'success', true,
    'tender_id', v_tender_id,
    'city_id', v_city_id,
    'product_id', v_product_id,
    'message', 'Demo ihale olusturuldu.'
  );
end;
$$;
