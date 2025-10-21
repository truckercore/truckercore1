-- =============================================================
-- Pack Post-Deploy Greenline (idempotent)
-- Verifies RLS, SecDef pinning, adds helpful indexes & grants,
-- retention wrappers, SLO burn view, and minimal seeds.
-- =============================================================

-- 1) RLS Greenline for pack tables
create or replace view public.v_pack_rls_greenline as
select c.relname as table_name,
       c.relrowsecurity as rls_on,
       exists (
         select 1
         from pg_policies p
         where p.schemaname='public'
           and p.tablename = c.relname
           and p.cmd in ('select','all')
       ) as has_select_policy
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind = 'r'
  and c.relname in (
    'feature_registry','slo_targets','dq_checks','dq_results','access_attestations',
    'access_items','secret_escalations','mobile_heartbeat','export_jobs','export_artifacts',
    'user_privacy_preferences','privacy_requests','drill_history','pilot_kpi_snapshots',
    'deck_jobs','alert_caps','admin_action_limits'
  );

-- 2) SecDef pinning check for this pack's RPCs
create or replace view public.v_pack_secdef_pinning as
select n.nspname as schema,
       p.proname as function,
       p.prosecdef as security_definer,
       (pg_get_functiondef(p.oid) ilike '% set search_path=public %') as pinned
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.prosecdef = true
  and p.proname in ('upsert_feature_flag','enqueue_export','record_mobile_heartbeat');

-- 3) Pack-specific RLS lint (no TRUE policies on pack tables)
create or replace view public.v_pack_rls_lint as
select p.tablename,
       p.policyname,
       p.cmd,
       (p.qual is null or p.qual ~* '^\s*true\s*$')  as is_true_using,
       (p.with_check is null or p.with_check ~* '^\s*true\s*$') as is_true_check
from pg_policies p
where p.schemaname='public'
  and p.tablename in (select table_name from public.v_pack_rls_greenline);

-- 4) Index hygiene
create index if not exists idx_export_jobs_org_created on public.export_jobs(org_id, created_at desc);
create index if not exists idx_privacy_requests_org_created on public.privacy_requests(org_id, created_at desc);
create index if not exists idx_mobile_heartbeat_org_created on public.mobile_heartbeat(org_id, created_at desc);
create index if not exists idx_export_jobs_status on public.export_jobs(status);
create index if not exists idx_deck_jobs_status on public.deck_jobs(status);
-- Optional JSONB path index (commented):
-- create index if not exists idx_dq_results_details_gin on public.dq_results using gin(details jsonb_path_ops);

-- 5) Grants & ownership (principle of least privilege)
revoke all on all tables    in schema public from public;
revoke all on all sequences in schema public from public;
revoke all on all functions in schema public from public;

-- Allow authenticated role to execute only safe RPCs
grant execute on function public.upsert_feature_flag(text,text,boolean,text,text,text) to authenticated;
grant execute on function public.enqueue_export(text)                                 to authenticated;
grant execute on function public.record_mobile_heartbeat(text,text,int,numeric)      to authenticated;

-- Deny anon for these RPCs
revoke execute on function public.upsert_feature_flag(text,text,boolean,text,text,text) from anon;
revoke execute on function public.enqueue_export(text)                                  from anon;
revoke execute on function public.record_mobile_heartbeat(text,text,int,numeric)        from anon;

-- 6) Data retention & partitions
-- Try to ensure monthly partitions for audit_log and function_invocations if helpers exist
do $$
begin
  begin perform audit_log_part_ensure(date_trunc('month', now())::date); exception when undefined_function then null; end;
  begin perform fninv_part_ensure(date_trunc('month', now())::date);    exception when undefined_function then null; end;
end $$;

-- Provide a compatibility wrapper prune_old_partitions() that calls prune_partitions() if available
create or replace function public.prune_old_partitions()
returns int language plpgsql as $$
declare n int := 0;
begin
  begin
    n := public.prune_partitions();
  exception when undefined_function then
    n := 0;
  end;
  return n;
end $$;

-- 7) SLO targets sanity + burn view (24h window)
create or replace view public.v_pack_slo_burn as
select t.fn,
       t.p95_ms,
       t.budget_error_rate,
       percentile_disc(0.95) within group (order by i.ms) as p95_obs,
       sum((i.status = 'error')::int)::numeric / greatest(count(*), 1) as err_rate
from public.slo_targets t
left join public.function_invocations i using (fn)
where i.at > now() - interval '24 hours'
group by t.fn, t.p95_ms, t.budget_error_rate
order by p95_obs desc nulls last;

-- 8) Minimal seeds (safe for staging)
insert into public.feature_registry(key,env,enabled,description,owner,runbook_url)
values ('roi','staging',true,'ROI views','eng@acme','https://example.com/runbooks/roi')
on conflict (key,env) do nothing;

insert into public.slo_targets(fn,p95_ms,budget_error_rate)
values ('export_pilot_summary',1200,0.02), ('sso.login',800,0.005)
on conflict (fn) do nothing;

-- Create an export job to verify RLS + indexes (no-op if function missing)
do $$
begin
  begin perform public.enqueue_export('pilot_summary'); exception when undefined_function then null; end;
end $$;

-- 9) Helper: temp table for RLS probe (example usage in CI scripts)
-- (Not creating permanent objects for probe here; see CI script for runtime checks)
