-- Migration: pg_cron schedules for rollups and maintenance
-- Date: 2025-09-27

create extension if not exists pg_cron;

-- Nightly rollup + maintain (03:11 UTC ~ per spec example)
-- Create job only if name not already present
select cron.schedule('rollup_old_raw_daily', '11 3 * * *', $$select public.rollup_old_raw();$$)
where not exists (select 1 from cron.job where jobname = 'rollup_old_raw_daily');

-- Daily VACUUM/ANALYZE partitions at 03:33 UTC
select cron.schedule('vac_analyze_behavior_partitions', '33 3 * * *', $$
DO $$
DECLARE r record; BEGIN
  FOR r IN SELECT inhrelid::regclass AS child
           FROM pg_inherits WHERE inhparent = 'public.behavior_events'::regclass LOOP
    EXECUTE format('VACUUM (ANALYZE) %s;', r.child);
  END LOOP;
  FOR r IN SELECT inhrelid::regclass AS child
           FROM pg_inherits WHERE inhparent = 'public.suggestions_log'::regclass LOOP
    EXECUTE format('VACUUM (ANALYZE) %s;', r.child);
  END LOOP;
END $$;$$)
where not exists (select 1 from cron.job where jobname = 'vac_analyze_behavior_partitions');
