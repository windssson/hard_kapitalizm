do $$
declare
  fn record;
  updated_def text;
begin
  for fn in
    select p.oid, p.proname
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prokind = 'f'
      and p.proname in (
        'get_market_transfer_vehicle_options',
        'get_market_transfer_vehicle_options_for_store',
        'get_transfer_vehicle_options',
        'start_market_to_store_transfer',
        'start_production_to_warehouse_transfer',
        'start_store_to_warehouse_transfer',
        'start_warehouse_to_production_transfer',
        'start_warehouse_to_store_transfer',
        'start_warehouse_to_warehouse_transfer'
      )
  loop
    updated_def := pg_get_functiondef(fn.oid);
    updated_def := replace(
      updated_def,
      '5.0::numeric as v_rental_price',
      '3.0::numeric as v_rental_price'
    );
    updated_def := replace(
      updated_def,
      'ceil(v_distance_km * 5.0) as v_rental_cost',
      'ceil(v_distance_km * 3.0) as v_rental_cost'
    );
    updated_def := replace(
      updated_def,
      'v_rental_cost := ceil(v_distance_km * 5.0);',
      'v_rental_cost := ceil(v_distance_km * 3.0);'
    );
    execute updated_def;
  end loop;
end
$$;
