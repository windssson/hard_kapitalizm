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
  v_tier_roll double precision;
  v_tier_type integer; -- 1: Yerel/Hızlı, 2: Kurumsal/Belediye, 3: Stratejik/Mega
  v_target_min_revenue numeric;
  v_target_max_revenue numeric;
  v_target_revenue numeric;
  v_quality_level integer;
  v_quality_multiplier numeric;
  v_wholesale_markup numeric;
  v_unit_price numeric;
  v_required_quantity integer;
  v_reward_cash numeric;
  v_bond_amount numeric;
  v_award_type text;
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
      chosen_product.uretim_birimi,
      chosen_product.kategori
    into v_pick
    from (
      select c.id, c.name
      from public.cities c
      order by random()
      limit 1
    ) chosen_city
    cross join lateral (
      select p.id, p.urun_adi, p.baz_satis_fiyati, p.uretim_birimi, p.kategori
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

    -- 1. Tier Belirleme
    v_tier_roll := random();
    if v_tier_roll < 0.45 then
      -- Tier 1: Yerel & Flaş Tedarik (Küçük Ölçek)
      v_tier_type := 1;
      v_target_min_revenue := 50000;
      v_target_max_revenue := 250000;
      v_accept_hours := 1 + floor(random() * 3)::integer; -- 1 - 3 saat
      v_delivery_hours := 3 + floor(random() * 6)::integer; -- 3 - 8 saat
      v_quality_level := 1;
      v_min_player_level := 1;
    elsif v_tier_roll < 0.80 then
      -- Tier 2: Kurumsal & Belediye Tedariği (Orta Ölçek)
      v_tier_type := 2;
      v_target_min_revenue := 300000;
      v_target_max_revenue := 1500000;
      v_accept_hours := 3 + floor(random() * 5)::integer; -- 3 - 7 saat
      v_delivery_hours := 8 + floor(random() * 16)::integer; -- 8 - 24 saat
      v_quality_level := case when random() < 0.70 then 2 else 1 end;
      v_min_player_level := 3 + floor(random() * 4)::integer; -- Seviye 3 - 6
    else
      -- Tier 3: Stratejik, Askeri & Mega İhracat (Büyük Ölçek)
      v_tier_type := 3;
      v_target_min_revenue := 2000000;
      v_target_max_revenue := 10000000;
      v_accept_hours := 6 + floor(random() * 12)::integer; -- 6 - 18 saat
      v_delivery_hours := 24 + floor(random() * 24)::integer; -- 24 - 48 saat
      v_quality_level := case when random() < 0.50 then 3 when random() < 0.85 then 2 else 1 end;
      v_min_player_level := 7 + floor(random() * 6)::integer; -- Seviye 7 - 12
    end if;

    -- 2. Fiyat ve Kârlılık Katsayıları
    v_quality_multiplier := 1 + ((v_quality_level - 1) * 0.20);
    v_wholesale_markup := round((1.25 + (random() * 0.20))::numeric, 2); -- %25 - %45 garantili kâr marjı
    v_unit_price := coalesce(v_pick.baz_satis_fiyati, 50) * v_quality_multiplier * v_wholesale_markup;

    -- Hedef ciro
    v_target_revenue := v_target_min_revenue + (random() * (v_target_max_revenue - v_target_min_revenue));

    -- Mantıklı Adet Hesaplama
    v_required_quantity := greatest(round(v_target_revenue / v_unit_price)::integer, 10);

    -- Temiz yuvarlak adet formatlaması
    if v_required_quantity >= 10000 then
      v_required_quantity := (round(v_required_quantity / 1000.0) * 1000)::integer;
    elsif v_required_quantity >= 1000 then
      v_required_quantity := (round(v_required_quantity / 100.0) * 100)::integer;
    elsif v_required_quantity >= 100 then
      v_required_quantity := (round(v_required_quantity / 10.0) * 10)::integer;
    else
      v_required_quantity := (round(v_required_quantity / 5.0) * 5)::integer;
    end if;
    v_required_quantity := greatest(v_required_quantity, 10);

    -- Toplam Ödül ve Teminat
    v_reward_cash := round(v_required_quantity * v_unit_price);
    v_bond_amount := round(v_reward_cash * 0.10); -- Standart %10 teminat
    v_award_type := case when random() < 0.45 then 'first_claim' else 'lowest_bid' end;

    v_accept_until := timezone('utc'::text, now()) + make_interval(hours => v_accept_hours);
    v_delivery_minutes := v_delivery_hours * 60;

    -- 3. Gerçekçi Başlık ve Açıklamalar
    if v_tier_type = 1 then
      case coalesce(v_pick.uretim_birimi, '')
        when 'TARLA' then
          v_title := format('%s Restoran ve Oteller Birliği Alımı', v_pick.city_name);
          v_description := format('%s bölgesi turizm ve yeme-içme tesisleri için toptan %s adet %s kalite %s tedarik ihalesi.', v_pick.city_name, v_required_quantity, v_quality_level, v_pick.urun_adi);
        when 'CIFTLIK' then
          v_title := format('%s İlçe Yemekhaneleri Besi Alımı', v_pick.city_name);
          v_description := format('%s ilçe merkezindeki yemekhaneler için acil %s adet %s kalite %s tedariği.', v_pick.city_name, v_required_quantity, v_quality_level, v_pick.urun_adi);
        when 'MADEN' then
          v_title := format('%s Sanayi Sitesi Maden Tedariği', v_pick.city_name);
          v_description := format('%s küçük sanayi sitesi atölyeleri için toptan %s adet %s kalite %s alımı.', v_pick.city_name, v_required_quantity, v_quality_level, v_pick.urun_adi);
        when 'FABRIKA' then
          v_title := format('%s İmalatçı Tedarik İhalesi', v_pick.city_name);
          v_description := format('%s bölgesindeki yerel üreticiler için %s adet %s kalite %s temini.', v_pick.city_name, v_required_quantity, v_quality_level, v_pick.urun_adi);
        else
          v_title := format('%s Yerel Tedarik İhalesi', v_pick.city_name);
          v_description := format('%s için acil %s adet %s kalite %s teslimi beklenmektedir.', v_pick.city_name, v_required_quantity, v_quality_level, v_pick.urun_adi);
      end case;
    elsif v_tier_type = 2 then
      case coalesce(v_pick.uretim_birimi, '')
        when 'TARLA' then
          v_title := format('%s BŞB Sosyal Yardım Gıda Alımı', v_pick.city_name);
          v_description := format('%s Büyükşehir Belediyesi sosyal yardım paketleri ve aşevleri için %s adet %s kalite %s alım ihalesi.', v_pick.city_name, v_required_quantity, v_quality_level, v_pick.urun_adi);
        when 'CIFTLIK' then
          v_title := format('%s Kamu Hastaneleri Gıda Konsorsiyumu', v_pick.city_name);
          v_description := format('%s ili kamu sağlık tesisleri ve hastaneler için %s adet %s kalite %s tedarik programı.', v_pick.city_name, v_required_quantity, v_quality_level, v_pick.urun_adi);
        when 'MADEN' then
          v_title := format('%s Organize Sanayi Hammadde Alımı', v_pick.city_name);
          v_description := format('%s Organize Sanayi Bölgesi metal ve maden işleme hatları için %s adet %s kalite %s ihalesi.', v_pick.city_name, v_required_quantity, v_quality_level, v_pick.urun_adi);
        when 'FABRIKA' then
          v_title := format('%s Altyapı ve İnşaat Tedarik Paketi', v_pick.city_name);
          v_description := format('%s kentsel gelişim ve sanayi projeleri kapsamında %s adet %s kalite %s alımı yapılacaktır.', v_pick.city_name, v_required_quantity, v_quality_level, v_pick.urun_adi);
        else
          v_title := format('%s Kurumsal Tedarik İhalesi', v_pick.city_name);
          v_description := format('%s kamu ve kurumsal projeleri için %s adet %s kalite %s alımı.', v_pick.city_name, v_required_quantity, v_quality_level, v_pick.urun_adi);
      end case;
    else
      case coalesce(v_pick.uretim_birimi, '')
        when 'TARLA' then
          v_title := format('%s Uluslararası Tarım İhracat Konsorsiyumu', v_pick.city_name);
          v_description := format('%s lojistik merkezinden yurt dışına sevk edilmek üzere stratejik %s adet %s kalite %s ihracat partisi.', v_pick.city_name, v_required_quantity, v_quality_level, v_pick.urun_adi);
        when 'CIFTLIK' then
          v_title := format('%s MSB Stratejik İaşe Rezerv Alımı', v_pick.city_name);
          v_description := format('Milli Savunma Bakanlığı ve AFAD stratejik iaşe stokları için %s ili teslimatlı %s adet %s kalite %s tedariği.', v_pick.city_name, v_required_quantity, v_quality_level, v_pick.urun_adi);
        when 'MADEN' then
          v_title := format('%s Devlet Demiryolları ve Ağır Sanayi Alımı', v_pick.city_name);
          v_description := format('Ulusal altyapı ve ağır sanayi tesisleri için %s teslimatlı yüksek hacimli %s adet %s kalite %s alım ihalesi.', v_pick.city_name, v_required_quantity, v_quality_level, v_pick.urun_adi);
        when 'FABRIKA' then
          v_title := format('%s Liman Bölgesi Küresel İhracat Partisi', v_pick.city_name);
          v_description := format('%s Limanı üzerinden global pazara ihraç edilecek %s adet %s kalite %s mega tedarik kontratı.', v_pick.city_name, v_required_quantity, v_quality_level, v_pick.urun_adi);
        else
          v_title := format('%s Stratejik Mega Tedarik İhalesi', v_pick.city_name);
          v_description := format('%s için yüksek hacimli uluslararası standartta %s adet %s kalite %s alım kontratı.', v_pick.city_name, v_required_quantity, v_quality_level, v_pick.urun_adi);
      end case;
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
      award_type,
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
      v_award_type,
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
