-- 1. Modify brand_companies to add leveling and customization columns
alter table public.brand_companies 
  add column if not exists brand_level integer not null default 1,
  add column if not exists brand_xp bigint not null default 0,
  add column if not exists logo_id text not null default 'logo_1.png',
  add column if not exists theme_color text not null default '#E5C05C';

-- 2. Create brand_marketing_campaigns table
create table if not exists public.brand_marketing_campaigns (
  id uuid primary key default gen_random_uuid(),
  player_id uuid references public.players(id) on delete cascade,
  campaign_type text not null, -- 'local', 'regional', 'global'
  cost_paid numeric not null,
  active_until timestamptz not null,
  sales_speed_multiplier numeric not null default 1.0,
  price_premium_multiplier numeric not null default 1.0,
  created_at timestamptz not null default timezone('utc'::text, now())
);

-- Enable RLS
alter table public.brand_marketing_campaigns enable row level security;

-- Add RLS Policies
drop policy if exists "Players can view own campaigns" on public.brand_marketing_campaigns;
create policy "Players can view own campaigns"
  on public.brand_marketing_campaigns
  for select
  to authenticated
  using (player_id = auth.uid());

drop policy if exists "Players can insert own campaigns" on public.brand_marketing_campaigns;
create policy "Players can insert own campaigns"
  on public.brand_marketing_campaigns
  for insert
  to authenticated
  with check (player_id = auth.uid());

-- 3. Function to calculate brand level dynamically
create or replace function public.calculate_brand_level(p_xp bigint) returns integer
language sql stable as $$
  select case
    when p_xp < 1000 then 1
    when p_xp < 5000 then 2
    when p_xp < 15000 then 3
    when p_xp < 40000 then 4
    else 5
  end;
$$;

-- 4. Function to start a marketing campaign
create or replace function public.start_marketing_campaign(
  p_campaign_type text
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_player_id uuid := auth.uid();
  v_cash numeric;
  v_cost numeric;
  v_duration_hours integer;
  v_speed_mult numeric;
  v_price_mult numeric;
  v_active_until timestamptz;
  v_campaign record;
  v_now timestamptz := timezone('utc'::text, now());
begin
  if v_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  -- Verify campaign type and set parameters
  if p_campaign_type = 'local' then
    v_cost := 25000;
    v_duration_hours := 24;
    v_speed_mult := 1.15; -- +15% sales speed
    v_price_mult := 1.05; -- +5% price premium tolerance
  elsif p_campaign_type = 'regional' then
    v_cost := 75000;
    v_duration_hours := 24;
    v_speed_mult := 1.30; -- +30% sales speed
    v_price_mult := 1.10; -- +10% price premium tolerance
  elsif p_campaign_type = 'global' then
    v_cost := 200000;
    v_duration_hours := 48;
    v_speed_mult := 1.50; -- +50% sales speed
    v_price_mult := 1.20; -- +20% price premium tolerance
  else
    raise exception 'Gecersiz kampanya turu: %', p_campaign_type;
  end if;

  -- Lock and check player cash
  select cash into v_cash
  from public.players
  where id = v_player_id
  for update;

  if v_cash < v_cost then
    raise exception 'Kampanya baslatmak icin yeterli nakit yok. Gereken: %₺', v_cost;
  end if;

  -- Check if same campaign type is already active
  select * into v_campaign
  from public.brand_marketing_campaigns
  where player_id = v_player_id
    and campaign_type = p_campaign_type
    and active_until > v_now
  limit 1;

  if found then
    raise exception 'Bu turde aktif bir kampanya zaten devam ediyor. Bitis: %', timezone('Europe/Istanbul', v_campaign.active_until);
  end if;

  -- Deduct cash
  update public.players
  set cash = cash - v_cost
  where id = v_player_id;

  v_active_until := v_now + make_interval(hours => v_duration_hours);

  -- Insert campaign
  insert into public.brand_marketing_campaigns (
    player_id,
    campaign_type,
    cost_paid,
    active_until,
    sales_speed_multiplier,
    price_premium_multiplier
  ) values (
    v_player_id,
    p_campaign_type,
    v_cost,
    v_active_until,
    v_speed_mult,
    v_price_mult
  );

  return jsonb_build_object(
    'success', true,
    'message', 'Pazarlama kampanyası başlatıldı.',
    'campaign_type', p_campaign_type,
    'cost_paid', v_cost,
    'active_until', v_active_until
  );
end;
$$;

-- Grant execution permissions
grant all on table public.brand_marketing_campaigns to anon, authenticated, service_role;
grant execute on function public.calculate_brand_level(bigint) to anon, authenticated, service_role;
grant execute on function public.start_marketing_campaign(text) to anon, authenticated, service_role;
