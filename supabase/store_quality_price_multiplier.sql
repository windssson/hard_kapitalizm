create or replace function public.store_quality_price_multiplier(
  p_quality_level integer
) returns numeric
language sql
immutable
set search_path = public
as $$
  select case greatest(1, least(coalesce(p_quality_level, 1), 5))
    when 1 then 1.00::numeric
    when 2 then 1.10::numeric
    when 3 then 1.22::numeric
    when 4 then 1.35::numeric
    else 1.50::numeric
  end;
$$;

do $$
declare
  v_sql text;
begin
  select pg_get_functiondef('public.open_store_detail_page(uuid)'::regprocedure)
  into v_sql;

  v_sql := replace(
    v_sql,
    'v_price_ratio := v_slot.price / v_slot.baz_satis_fiyati;',
    'v_price_ratio := v_slot.price / (v_slot.baz_satis_fiyati * public.store_quality_price_multiplier(v_slot.quality_level));'
  );

  if position('public.store_quality_price_multiplier(v_slot.quality_level)' in v_sql) = 0 then
    raise exception 'open_store_detail_page kalite fiyat carpani patchlenemedi.';
  end if;

  execute v_sql;
end;
$$;

grant execute on function public.store_quality_price_multiplier(integer)
to anon, authenticated, service_role;

