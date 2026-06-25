create or replace function public.bulk_update_store_slot_prices(
  p_player_id uuid,
  p_store_id uuid,
  p_markup_percent numeric
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_store record;
  v_slot record;
  v_update_result jsonb;
  v_new_price numeric;
  v_examined_slot_count integer := 0;
  v_updated_slot_count integer := 0;
  v_failed_slot_count integer := 0;
  v_affected_slot_ids uuid[] := '{}'::uuid[];
begin
  if p_markup_percent not in (25, 30, 50) then
    raise exception 'Desteklenmeyen kar marji. Sadece 25, 30 veya 50 kullanilabilir.';
  end if;

  select s.*
  into v_store
  from public.stores s
  where s.id = p_store_id
  for update;

  if not found then
    raise exception 'Magaza bulunamadi.';
  end if;

  if v_store.player_id <> p_player_id then
    raise exception 'Bu magaza oyuncuya ait degil.';
  end if;

  for v_slot in
    select ss.*
    from public.store_slots ss
    where ss.store_id = p_store_id
      and coalesce(ss.is_active, true) = true
      and coalesce(ss.product_id, '') <> ''
      and coalesce(ss.quality_level, 0) > 0
      and coalesce(ss.cost, 0) > 0
    order by ss.slot_index, ss.id
  loop
    v_examined_slot_count := v_examined_slot_count + 1;
    v_new_price := round(
      (coalesce(v_slot.cost, 0) * (1 + (p_markup_percent / 100.0)))::numeric,
      2
    );

    v_update_result := public.set_store_slot_price(
      p_player_id,
      v_slot.id,
      v_new_price
    );

    if coalesce((v_update_result ->> 'success')::boolean, false) then
      v_updated_slot_count := v_updated_slot_count + 1;
      v_affected_slot_ids := array_append(v_affected_slot_ids, v_slot.id);
    else
      v_failed_slot_count := v_failed_slot_count + 1;
    end if;
  end loop;

  return jsonb_build_object(
    'success', true,
    'store_id', p_store_id,
    'markup_percent', p_markup_percent,
    'examined_slot_count', v_examined_slot_count,
    'updated_slot_count', v_updated_slot_count,
    'failed_slot_count', v_failed_slot_count,
    'store_slot_ids', coalesce(to_jsonb(v_affected_slot_ids), '[]'::jsonb),
    'message', case
      when v_updated_slot_count > 0
        then format('Magaza fiyatlari maliyet +%%%s olarak guncellendi.', p_markup_percent)
      else 'Guncellenecek uygun magaza slotu bulunamadi.'
    end
  );
end;
$function$;
