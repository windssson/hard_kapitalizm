create or replace function public.transfer_warehouse_fuel_to_logistics_company(
  p_logistics_company_id uuid,
  p_warehouse_slot_id uuid,
  p_quantity integer
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_player_id uuid := auth.uid();
  v_company record;
  v_slot record;
  v_transfer_quantity integer;
  v_company_remaining_capacity integer;
  v_new_company_fuel integer;
  v_new_company_fuel_cost numeric;
begin
  if v_player_id is null then
    raise exception 'Oturum bulunamadi.';
  end if;

  if coalesce(p_quantity, 0) <= 0 then
    raise exception 'Transfer miktari sifirdan buyuk olmali.';
  end if;

  select *
  into v_company
  from public.logistics_companies
  where id = p_logistics_company_id
    and player_id = v_player_id
  for update;

  if not found then
    raise exception 'Nakliye firmasi bulunamadi.';
  end if;

  select
    w.player_id,
    ws.id as slot_id,
    ws.product_id,
    ws.quantity as slot_quantity,
    ws.cost as slot_cost,
    ws.quality_level
  into v_slot
  from public.warehouse_slots ws
  join public.warehouses w on w.id = ws.warehouse_id
  where ws.id = p_warehouse_slot_id
  for update of ws, w;

  if not found then
    raise exception 'Depo slotu bulunamadi.';
  end if;

  if v_slot.player_id <> v_player_id then
    raise exception 'Bu depo slotu size ait degil.';
  end if;

  if coalesce(v_slot.product_id, '') <> 'YAKIT' then
    raise exception 'Secilen slot yakit icermiyor.';
  end if;

  if coalesce(v_slot.slot_quantity, 0) <= 0 then
    raise exception 'Slotta aktarilacak yakit bulunmuyor.';
  end if;

  v_company_remaining_capacity := greatest(
    coalesce(v_company.fuel_capacity, 0) - coalesce(v_company.current_fuel, 0),
    0
  );

  if v_company_remaining_capacity <= 0 then
    raise exception 'Merkez yakit deposu dolu.';
  end if;

  v_transfer_quantity := least(
    p_quantity,
    v_slot.slot_quantity,
    v_company_remaining_capacity
  );

  if v_transfer_quantity <= 0 then
    raise exception 'Aktarilabilecek yakit bulunmuyor.';
  end if;

  if p_quantity > v_transfer_quantity then
    raise exception 'Istenen miktar aktarilamiyor. Maksimum: %', v_transfer_quantity;
  end if;

  update public.warehouse_slots
  set quantity = quantity - v_transfer_quantity,
      cost = case when quantity - v_transfer_quantity > 0 then cost else 0 end,
      updated_at = timezone('utc'::text, now())
  where id = p_warehouse_slot_id;

  v_new_company_fuel := coalesce(v_company.current_fuel, 0) + v_transfer_quantity;
  v_new_company_fuel_cost := case
    when v_new_company_fuel > 0 then
      (
        coalesce(v_company.current_fuel, 0) * coalesce(v_company.fuel_cost, 0)
        + v_transfer_quantity * coalesce(v_slot.slot_cost, 0)
      ) / v_new_company_fuel
    else 0
  end;

  update public.logistics_companies
  set current_fuel = v_new_company_fuel,
      fuel_cost = v_new_company_fuel_cost,
      updated_at = timezone('utc'::text, now())
  where id = p_logistics_company_id;

  return jsonb_build_object(
    'success', true,
    'logistics_company_id', p_logistics_company_id,
    'warehouse_slot_id', p_warehouse_slot_id,
    'transferred_quantity', v_transfer_quantity,
    'company_current_fuel', v_new_company_fuel,
    'company_fuel_cost', v_new_company_fuel_cost,
    'warehouse_remaining_quantity', v_slot.slot_quantity - v_transfer_quantity
  );
end;
$function$;
