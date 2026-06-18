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
        'get_npc_rental_vehicle_option',
        'get_production_input_transfer_vehicle_options',
        'get_production_output_transfer_vehicle_options',
        'get_store_to_warehouse_vehicle_options',
        'get_store_transfer_vehicle_options',
        'get_transfer_vehicle_options',
        'start_market_to_store_transfer',
        'start_production_to_warehouse_transfer',
        'start_store_to_warehouse_transfer',
        'start_warehouse_to_production_transfer',
        'start_warehouse_to_store_transfer',
        'start_warehouse_to_warehouse_transfer'
      )
  loop
    updated_def := replace(pg_get_functiondef(fn.oid), '/ 4.0', '/ 6.0');
    execute updated_def;
  end loop;
end
$$;
