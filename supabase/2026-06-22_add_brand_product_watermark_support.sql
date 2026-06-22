alter table public.brand_company_products
  add column if not exists watermark_asset_id text;

drop function if exists public.get_player_brand_company_products();

create function public.get_player_brand_company_products()
returns table(
  product_id text,
  product_name text,
  product_icon text,
  max_quality_level integer,
  is_branded boolean,
  branded_at timestamptz,
  watermark_asset_id text
)
language sql
security definer
as $function$
  with company as (
    select bc.id
    from public.brand_companies bc
    where bc.player_id = auth.uid()
    limit 1
  ),
  eligible as (
    select
      ppql.product_id,
      max(ppql.max_quality_level)::integer as max_quality_level
    from public.player_product_quality_levels ppql
    where ppql.player_id = auth.uid()
    group by ppql.product_id
  ),
  branded as (
    select
      bcp.product_id,
      bcp.created_at,
      bcp.watermark_asset_id
    from public.brand_company_products bcp
    join company c on c.id = bcp.brand_company_id
    where bcp.player_id = auth.uid()
      and bcp.is_active = true
  )
  select
    p.id as product_id,
    p.urun_adi as product_name,
    p.urun_iconu as product_icon,
    coalesce(e.max_quality_level, 1) as max_quality_level,
    (b.product_id is not null) as is_branded,
    b.created_at as branded_at,
    b.watermark_asset_id
  from public.products p
  left join eligible e on e.product_id = p.id
  left join branded b on b.product_id = p.id
  where coalesce(e.max_quality_level, 0) >= 2
     or b.product_id is not null
  order by
    case when b.product_id is not null then 0 else 1 end,
    p.urun_adi asc;
$function$;

create or replace function public.set_brand_company_product_watermark(
  p_product_id text,
  p_watermark_asset_id text default null
)
returns jsonb
language plpgsql
security definer
as $function$
declare
  v_player_id uuid := auth.uid();
  v_company public.brand_companies%rowtype;
  v_product public.products%rowtype;
  v_sanitized_watermark text := nullif(btrim(coalesce(p_watermark_asset_id, '')), '');
begin
  if v_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  select *
  into v_company
  from public.brand_companies
  where player_id = v_player_id
    and is_active = true
  limit 1;

  if not found then
    raise exception 'Oyuncunun aktif marka sirketi yok.';
  end if;

  select *
  into v_product
  from public.products
  where id = p_product_id;

  if not found then
    raise exception 'Urun bulunamadi.';
  end if;

  update public.brand_company_products
  set watermark_asset_id = v_sanitized_watermark,
      updated_at = timezone('utc', now())
  where player_id = v_player_id
    and product_id = p_product_id
    and brand_company_id = v_company.id
    and is_active = true;

  if not found then
    raise exception 'Bu urun icin aktif marka patenti bulunamadi.';
  end if;

  return jsonb_build_object(
    'success', true,
    'message', case
      when v_sanitized_watermark is null then 'Urun filigrani temizlendi.'
      else 'Urun filigrani guncellendi.'
    end,
    'product_id', p_product_id,
    'product_name', v_product.urun_adi,
    'watermark_asset_id', v_sanitized_watermark
  );
end;
$function$;
