create or replace function public.generate_open_tenders(
  p_target_open_count integer default 20,
  p_max_generate integer default 20
)
returns jsonb
language plpgsql
security definer
set search_path = 'public'
as $$
declare
  v_open_count integer := 0;
  v_missing_count integer := 0;
  v_generate_count integer := 0;
  v_generated_count integer := 0;
  v_iteration integer := 0;
  v_pick record;
  v_roll double precision;
  v_quality_level integer;
  v_base_units integer;
  v_quantity_multiplier numeric;
  v_required_quantity integer;
  v_quality_multiplier numeric;
  v_difficulty_multiplier numeric;
  v_base_value numeric;
  v_reward_cash numeric;
  v_bond_ratio numeric;
  v_bond_amount numeric;
  v_accept_hours integer;
  v_delivery_hours integer;
  v_accept_until timestamptz;
  v_delivery_minutes integer;
  v_min_player_level integer;
  v_title text;
  v_description text;
begin
  if coalesce(p_target_open_count, 0) <= 0 then
    return jsonb_build_object(
      'success', true,
      'open_count', 0,
      'generated_count', 0,
      'message', 'Hedef acik ihale sayisi sifir veya negatif.'
    );
  end if;

  select count(*)
  into v_open_count
  from public.tenders t
  where t.status = 'open'
    and t.accept_until > timezone('utc'::text, now());

  v_missing_count := greatest(p_target_open_count - v_open_count, 0);
  v_generate_count := least(
    v_missing_count,
    greatest(coalesce(p_max_generate, p_target_open_count), 0)
  );

  if v_generate_count <= 0 then
    return jsonb_build_object(
      'success', true,
      'open_count', v_open_count,
      'generated_count', 0
    );
  end if;

  for v_iteration in 1..v_generate_count loop
    select
      chosen_city.id as city_id,
      chosen_city.name as city_name,
      chosen_product.id as product_id,
      chosen_product.urun_adi,
      chosen_product.baz_satis_fiyati,
      chosen_product.uretim_adedi,
      chosen_product.satis_adedi,
      chosen_product.uretim_birimi
    into v_pick
    from (
      select c.id, c.name
      from public.cities c
      order by random()
      limit 1
    ) chosen_city
    cross join lateral (
      select p.id, p.urun_adi, p.baz_satis_fiyati, p.uretim_adedi, p.satis_adedi, p.uretim_birimi
      from public.products p
      where coalesce(p.baz_satis_fiyati, 0) > 0
        and not exists (
          select 1
          from public.tenders t
          where t.status = 'open'
            and t.accept_until > timezone('utc'::text, now())
            and t.city_id = chosen_city.id
            and t.product_id = p.id
        )
      order by random()
      limit 1
    ) chosen_product;

    if not found then
      continue;
    end if;

    v_roll := random();
    if v_pick.baz_satis_fiyati < 100 then
      v_quality_level := 1;
    elsif v_pick.baz_satis_fiyati < 1000 then
      v_quality_level := case when v_roll < 0.80 then 1 else 2 end;
    elsif v_pick.baz_satis_fiyati < 10000 then
      v_quality_level := case when v_roll < 0.60 then 1 when v_roll < 0.90 then 2 else 3 end;
    else
      v_quality_level := case when v_roll < 0.45 then 1 when v_roll < 0.80 then 2 else 3 end;
    end if;

    v_base_units := greatest(
      coalesce(nullif(v_pick.satis_adedi, 0), nullif(v_pick.uretim_adedi, 0), 20),
      1
    );

    if v_pick.baz_satis_fiyati < 100 then
      v_quantity_multiplier := 3 + (random() * 3);
    elsif v_pick.baz_satis_fiyati < 1000 then
      v_quantity_multiplier := 2 + (random() * 2.5);
    elsif v_pick.baz_satis_fiyati < 10000 then
      v_quantity_multiplier := 1.2 + (random() * 1.8);
    else
      v_quantity_multiplier := 0.8 + (random() * 1.4);
    end if;

    v_required_quantity := greatest(
      1,
      least(1500, round(v_base_units * v_quantity_multiplier)::integer)
    );

    v_quality_multiplier := 1 + ((v_quality_level - 1) * 0.15);
    v_difficulty_multiplier := round((1.10 + (random() * 0.50))::numeric, 2);
    v_base_value := coalesce(v_pick.baz_satis_fiyati, 1) * v_required_quantity;
    v_reward_cash := round(v_base_value * v_quality_multiplier * v_difficulty_multiplier);
    v_bond_ratio := round((0.10 + (random() * 0.15))::numeric, 2);
    v_bond_amount := round(v_reward_cash * v_bond_ratio);

    v_accept_hours := 1 + floor(random() * 8)::integer;
    v_delivery_hours := 1 + floor(random() * 6)::integer;
    v_accept_until := timezone('utc'::text, now()) + make_interval(hours => v_accept_hours);
    v_delivery_minutes := v_delivery_hours * 60;

    v_min_player_level := case
      when v_pick.baz_satis_fiyati < 100 then 1
      when v_pick.baz_satis_fiyati < 500 then 2
      when v_pick.baz_satis_fiyati < 1000 then 4
      when v_pick.baz_satis_fiyati < 5000 then 6
      when v_pick.baz_satis_fiyati < 15000 then 10
      else 14
    end + greatest(v_quality_level - 1, 0) * 2;

    v_min_player_level := least(greatest(v_min_player_level, 1), 25);

    v_title := case coalesce(v_pick.uretim_birimi, '')
      when 'TARLA' then format('%s Belediye Gida Tedarigi', v_pick.city_name)
      when 'CIFTLIK' then format('%s Kamu Gida Programi', v_pick.city_name)
      when 'MADEN' then format('%s Sanayi Hammadde Alimi', v_pick.city_name)
      when 'FABRIKA' then format('%s Kurumsal Tedarik Ihalesi', v_pick.city_name)
      else format('%s Kamu Tedarik Ihalesi', v_pick.city_name)
    end;

    v_description := format(
      '%s icin %s adet %s kalite %s urun teslimi bekleniyor.',
      v_pick.city_name,
      v_required_quantity,
      v_quality_level,
      v_pick.urun_adi
    );

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
      v_title,
      v_description,
      v_pick.city_id,
      v_pick.product_id,
      v_quality_level,
      v_required_quantity,
      v_reward_cash,
      v_bond_amount,
      v_accept_until,
      v_delivery_minutes,
      'open',
      'public',
      v_min_player_level
    );

    v_generated_count := v_generated_count + 1;
  end loop;

  return jsonb_build_object(
    'success', true,
    'open_count', v_open_count + v_generated_count,
    'generated_count', v_generated_count,
    'target_open_count', p_target_open_count
  );
end;
$$;

create or replace function public.ensure_open_tenders()
returns jsonb
language plpgsql
security definer
set search_path = 'public'
as $$
declare
  v_expired_count integer := 0;
  v_open_count integer := 0;
begin
  update public.tenders
  set status = 'expired',
      updated_at = timezone('utc'::text, now())
  where status = 'open'
    and accept_until <= timezone('utc'::text, now());

  get diagnostics v_expired_count = row_count;

  select count(*)
  into v_open_count
  from public.tenders t
  where t.status = 'open'
    and t.accept_until > timezone('utc'::text, now());

  return jsonb_build_object(
    'success', true,
    'expired_count', v_expired_count,
    'open_count', v_open_count,
    'generation_skipped', true
  );
end;
$$;

create or replace function public.maintain_open_tenders()
returns jsonb
language plpgsql
security definer
set search_path = 'public'
as $$
declare
  v_expire_result jsonb := '{}'::jsonb;
  v_generation_result jsonb := '{}'::jsonb;
begin
  v_expire_result := public.ensure_open_tenders();
  v_generation_result := public.generate_open_tenders(50, 50);

  return jsonb_build_object(
    'success', true,
    'expire_result', v_expire_result,
    'generation_result', v_generation_result
  );
end;
$$;

select cron.unschedule(jobid)
from cron.job
where jobname = 'maintain_open_tenders_every_30_minutes';

select cron.schedule(
  'maintain_open_tenders_every_30_minutes',
  '*/30 * * * *',
  'select public.maintain_open_tenders();'
);
