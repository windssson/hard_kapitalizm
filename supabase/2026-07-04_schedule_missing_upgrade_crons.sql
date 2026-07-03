-- Schedule missing cron jobs for building and warehouse upgrades.
-- This ensures they complete automatically in the background even if the player is offline.

-- Unschedule first if exists to prevent duplicates
SELECT cron.unschedule(jobid)
FROM cron.job
WHERE jobname IN ('complete_due_building_upgrades_every_30_min', 'complete_due_warehouse_upgrades_every_30_min');

-- Schedule building upgrades check every 30 minutes
SELECT cron.schedule(
  'complete_due_building_upgrades_every_30_min',
  '*/30 * * * *',
  'select public.complete_due_building_upgrades();'
);

-- Schedule warehouse upgrades check every 30 minutes
SELECT cron.schedule(
  'complete_due_warehouse_upgrades_every_30_min',
  '*/30 * * * *',
  'select public.complete_due_warehouse_upgrades();'
);
