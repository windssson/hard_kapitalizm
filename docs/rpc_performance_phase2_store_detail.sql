create or replace function public.open_store_detail_page(
  p_store_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_player_id uuid := auth.uid();
  v_store_response jsonb;
  v_sale_result jsonb;
  v_active_boost jsonb;
  v_active_upgrade jsonb;
  v_player jsonb;
  v_has_expired_upgrade boolean := false;
  v_processed boolean := false;
  v_completed_boost_count integer := 0;
begin
  if v_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  select exists (
    select 1
    from public.building_upgrades bu
    where bu.player_id = v_player_id
      and bu.building_kind = 'store'
      and bu.entity_id = p_store_id
      and bu.status = 'in_progress'
      and bu.finish_at <= timezone('utc'::text, now())
  )
  into v_has_expired_upgrade;

  if v_has_expired_upgrade then
    perform public.complete_due_building_upgrades(100);
  end if;

  v_sale_result := public.process_store_sales_on_entry(v_player_id, p_store_id);
  v_store_response := public.get_store_detail(v_player_id, p_store_id);

  if coalesce((v_store_response ->> 'success')::boolean, false) is not true then
    return v_store_response;
  end if;

  v_active_boost := public.get_player_active_building_boost(
    'store',
    p_store_id
  );
  v_active_upgrade := public.get_player_active_building_upgrade(
    'store',
    p_store_id
  );
  v_player := public.get_player_profile(v_player_id);
  v_processed := coalesce((v_sale_result ->> 'processed')::boolean, false);
  v_completed_boost_count := coalesce(
    (v_sale_result ->> 'completed_boost_count')::integer,
    0
  );

  return jsonb_build_object(
    'success', true,
    'store', v_store_response -> 'store',
    'active_boost', v_active_boost,
    'active_upgrade', v_active_upgrade,
    'sale_result', v_sale_result,
    'changed', jsonb_build_object(
      'player', v_player,
      'history_dirty', v_processed,
      'performance_dirty', v_processed or v_completed_boost_count > 0
    )
  );
end;
$$;
