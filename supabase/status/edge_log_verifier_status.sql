-- supabase/status/edge_log_verifier_status.sql
create or replace view public.edge_log_verifier_status as
with cfg as (
  select 30::int as retention_days  -- display default; CI uses env param for verification
), run as (
  select now() as checked_at
)
select
  (select min(ts) from public.edge_request_log) as oldest_ts,
  (select max(ts) from public.edge_request_log) as newest_ts,
  (select count(*) from public.edge_request_log, cfg
     where ts < now() - (select retention_days from cfg) * interval '1 day') as rows_beyond_window,
  (select retention_days from cfg) as retention_days,
  now() as checked_at
from run;
