-- Unschedule the job if it already exists to avoid duplicates
SELECT cron.unschedule(jobid) 
FROM cron.job 
WHERE jobname = 'refresh_all_leaderboard_stats_every_12_hours';

-- Schedule the job to run every 12 hours (on the hour)
SELECT cron.schedule(
  'refresh_all_leaderboard_stats_every_12_hours',
  '0 */12 * * *',
  'SELECT public.refresh_all_leaderboard_stats();'
);
