-- supabase/seed/cron_jobs.sql
-- Example: nightly rollups and regular vacuum/analyze
select cron.schedule('rollups_hourly', '15 * * * *', $$call public.run_rollups();$$);
select cron.schedule('analyze_nightly', '0 3 * * *', $$vacuum analyze;$$);
