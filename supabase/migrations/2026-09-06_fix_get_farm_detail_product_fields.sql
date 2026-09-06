-- Migration: Fix get_farm_detail to return full product details (including iscilik_maliyeti and kategori)
-- Date: 2026-09-06

CREATE OR REPLACE FUNCTION public.get_farm_detail(p_player_id uuid, p_farm_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_auth_user uuid := auth.uid();
  v_farm record;
  v_farm_type record;
  v_city_name text;
  v_slots jsonb := '[]'::jsonb;
  v_inventories jsonb := '[]'::jsonb;
  v_active_boost_multiplier numeric := 1.00;
begin
  if v_auth_user is null then
    raise exception 'Oturum bulunamadi.';
  end if;

  if v_auth_user <> p_player_id then
    raise exception 'Yetkisiz istek.';
  end if;

  select f.*, c.name as city_name
  into v_farm
  from public.farms f
  left join public.cities c on c.id = f.city_id
  where f.id = p_farm_id
    and f.player_id = p_player_id;

  if not found then
    raise exception 'Tarla bulunamadi veya oyuncuya ait degil.';
  end if;

  select *
  into v_farm_type
  from public.farm_types
  where id = v_farm.farm_type_id;

  select coalesce(bb.multiplier, 1.00)
  into v_active_boost_multiplier
  from public.building_boosts bb
  where bb.player_id = p_player_id
    and bb.building_kind = 'farm'
    and bb.entity_id = p_farm_id
    and bb.status = 'in_progress'
    and coalesce(bb.finish_at, timezone('utc'::text, now())) > timezone('utc'::text, now())
  order by bb.started_at desc
  limit 1;

  v_city_name := coalesce(v_farm.city_name, 'Bilinmeyen Sehir');

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', ps.id,
        'owner_kind', ps.owner_kind,
        'owner_id', ps.owner_id,
        'slot_index', ps.slot_index,
        'product_id', ps.product_id,
        'brand_id', ps.brand_id,
        'quality_level', ps.quality_level,
        'boost_multiplier', coalesce(v_active_boost_multiplier, 1.00),
        'is_active', ps.is_active,
        'product', case
          when p.id is null then null
          else to_jsonb(p)
        end
      )
      order by ps.slot_index
    ),
    '[]'::jsonb
  )
  into v_slots
  from public.production_slots ps
  left join public.products p on p.id = ps.product_id
  where ps.owner_kind = 'farm'
    and ps.owner_id = p_farm_id;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', pi.id,
        'owner_kind', pi.owner_kind,
        'owner_id', pi.owner_id,
        'inventory_type', pi.inventory_type,
        'product_id', pi.product_id,
        'brand_id', pi.brand_id,
        'quality_level', pi.quality_level,
        'quantity', pi.quantity,
        'pending_quantity', pi.pending_quantity,
        'cost', pi.cost,
        'product', case
          when p.id is null then null
          else to_jsonb(p)
        end
      )
      order by pi.inventory_type, pi.product_id, pi.quality_level
    ),
    '[]'::jsonb
  )
  into v_inventories
  from public.production_inventory pi
  left join public.products p on p.id = pi.product_id
  where pi.owner_kind = 'farm'
    and pi.owner_id = p_farm_id;

  return jsonb_build_object(
    'success', true,
    'farm', jsonb_build_object(
      'farm', to_jsonb(v_farm) - 'city_name',
      'farm_type', to_jsonb(v_farm_type),
      'city_name', v_city_name,
      'slots', v_slots,
      'inventories', v_inventories
    )
  );
end;
$function$;
