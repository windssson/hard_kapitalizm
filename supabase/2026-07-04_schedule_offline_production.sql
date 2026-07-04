-- 1. Create a function to process production and warnings for all players
CREATE OR REPLACE FUNCTION public.process_all_players_production()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
declare
  v_player_row record;
  v_processed_count integer := 0;
  v_failed_count integer := 0;
begin
  -- Loop through all players (including NPCs, though they don't generate warnings)
  for v_player_row in
    select id
    from public.players
  loop
    begin
      -- Step A: Process production tick (consumes materials, updates inventory, completes due upgrades/boosts)
      perform public.process_player_production_entry(v_player_row.id);
      
      -- Step B: Re-build warning notifications (detect missing raw materials, full warehouses, etc.)
      perform public.build_player_attention_notifications(v_player_row.id);
      
      v_processed_count := v_processed_count + 1;
    exception when others then
      v_failed_count := v_failed_count + 1;
    end;
  end loop;

  return jsonb_build_object(
    'success', true,
    'processed_players_count', v_processed_count,
    'failed_players_count', v_failed_count
  );
end;
$$;

-- 2. Schedule this function in pg_cron to run every 30 minutes
SELECT cron.unschedule(jobid)
FROM cron.job
WHERE jobname = 'process_all_players_production_job';

SELECT cron.schedule(
  'process_all_players_production_job',
  '*/30 * * * *',
  'select public.process_all_players_production();'
);
