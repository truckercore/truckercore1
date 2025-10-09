-- supabase/verify/ops_preflight.sql
-- Ops preflight: deeper DB sanity (ad-hoc or target). Safe to run anytime.
-- Usage:
--   supabase db query supabase/verify/ops_preflight.sql
-- Or via Makefile:
--   make ops-preflight

\echo '== Versions & basics =='
select version(), current_user, current_schema, now();

\echo '== Timeouts/locks (session defaults) =='
show statement_timeout;
show lock_timeout;

\echo '== RLS enabled for tenant tables =='
select relname, relrowsecurity
from pg_class
where relname in ('alerts','escalation_logs','retests','remediations')
order by relname;

\echo '== Partition health (parent + child counts) =='
select inhparent::regclass as parent, count(*) as partitions
from pg_inherits
group by 1
order by 1;

\echo '== Index presence for hot paths on edge_request_log (parent partitioned indexes) =='
select indexname, indexdef
from pg_indexes
where schemaname='public' and tablename='edge_request_log'
order by indexname;

\echo '== Maintenance schedule freshness (last successful nightly_maintenance run) =='
select (now()-max(ran_at)) as since_last_ok
from public.ops_maintenance_log
where task='nightly_maintenance' and ok is true;

\echo '== Explain plan: edge_request_log (expect Partition pruning and index scans on ts/compound) =='
explain analyze
select count(*) from public.edge_request_log
where ts >= date_trunc('month', now());

\echo '== Explain plan: hot feed (org + recency) — replace :ORG_UUID then run manually if desired =='
-- Tip: You can set a variable in psql: \set ORG_UUID '00000000-0000-0000-0000-000000000000'
-- Then run the EXPLAIN below. If running via Supabase CLI without variables, this is informational only.
-- explain analyze
-- select title from public.escalation_logs
-- where org_id = :'ORG_UUID'::uuid
-- order by created_at desc
-- limit 25;