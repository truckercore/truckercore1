-- 20250924_privacy_alerts_catalog.sql
-- Purpose: Privacy/SSO/SCIM/Export alert codes catalog, privacy_events table with RLS,
-- retention helper, and reporting views (health/coverage/orphans/mix/bounds + cohort lint + PII lint).
-- Idempotent and compatible with existing alert_codes definitions.

-- 1) Alert codes catalog -------------------------------------------------------
create table if not exists public.alert_codes (
  code text primary key,
  category text not null,
  severity_default text not null,
  description text not null,
  created_at timestamptz not null default now()
);

-- Align shape if table already exists with a different schema
alter table if exists public.alert_codes
  add column if not exists category text,
  add column if not exists severity_default text,
  add column if not exists description text,
  add column if not exists created_at timestamptz not null default now();

-- Checks (guarded)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='alert_codes_category_chk') THEN
    ALTER TABLE public.alert_codes
      ADD CONSTRAINT alert_codes_category_chk
      CHECK (category in ('sso','scim','privacy','ops','export','security'));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='alert_codes_severity_default_chk') THEN
    ALTER TABLE public.alert_codes
      ADD CONSTRAINT alert_codes_severity_default_chk
      CHECK (severity_default in ('info','warning','critical'));
  END IF;
END $$;

-- Seed idempotently
insert into public.alert_codes (code, category, severity_default, description) values
  ('SSO_FAIL_RATE','sso','warning','SSO failure rate exceeded threshold'),
  ('SSO_CANARY_DRIFT','sso','critical','OIDC canary failed consecutively'),
  ('SSO_SELFCHECK_ABUSE','sso','warning','Self-check endpoint is being rate-limited'),
  ('SCIM_RUN_FAILED','scim','warning','SCIM provisioning run failed'),
  ('SCIM_RUN_PARTIAL','scim','warning','SCIM provisioning run partial'),
  ('PRIVACY_SMALL_COHORT','privacy','warning','Aggregate cohort below k-anonymity threshold'),
  ('PRIVACY_PII_LINT','privacy','warning','Possible PII column name in privacy_* schema'),
  ('PRIVACY_EVENT_ORPHAN','privacy','warning','Privacy event code not in catalog'),
  ('PRIVACY_INGEST_LOW','privacy','warning','Low privacy events ingestion in 24h'),
  ('PRIVACY_VIEW_EMPTY','privacy','warning','Privacy views rendering empty unexpectedly'),
  ('ROTATION_OVERDUE','security','warning','Secrets/key rotation overdue'),
  ('EXPORT_FAILURE','export','warning','Scheduled export failed'),
  ('EXPORT_LATENCY_HIGH','export','warning','Export latency exceeded SLO')
on conflict (code) do nothing;


-- 2) Base privacy events table -------------------------------------------------
create table if not exists public.privacy_events (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  code text not null references public.alert_codes(code),
  subject_id uuid null,            -- actor or pseudonymous subject
  details jsonb not null default '{}'::jsonb,
  at timestamptz not null default now()
);
create index if not exists idx_privacy_events_org_time on public.privacy_events (org_id, at desc);

-- RLS (org-scoped read, writes via service role/jobs)
alter table public.privacy_events enable row level security;
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='privacy_events' AND policyname='privacy_events_read_org'
  ) THEN
    CREATE POLICY privacy_events_read_org ON public.privacy_events
    FOR SELECT TO authenticated
    USING (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
  END IF;
END $$;
GRANT SELECT ON public.privacy_events TO authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.privacy_events FROM authenticated, anon;

-- 3) Retention helper ----------------------------------------------------------
create or replace function public.prune_privacy_events(days int default 90)
returns void language plpgsql security definer as $$
begin
  delete from public.privacy_events where at < now() - make_interval(days=>days);
end $$;
revoke all on function public.prune_privacy_events(int) from public, anon, authenticated;
-- grant to service role implicitly via Supabase; explicit grant if role exists
-- grant execute on function public.prune_privacy_events(int) to service_role;

-- 4) K-anonymity guard (24h) ---------------------------------------------------
create or replace view public.v_privacy_small_cohorts_24h as
select code, org_id, count(distinct subject_id) as cohort
from public.privacy_events
where at >= now() - interval '24 hours'
group by code, org_id
having count(distinct subject_id) < 10
order by cohort asc;

-- 5) PII lint (schema hygiene) -------------------------------------------------
create or replace view public.v_privacy_pii_lint as
select table_schema, table_name, column_name
from information_schema.columns
where table_schema = 'public'
  and table_name like 'privacy_%'
  and lower(column_name) ~ '(email|phone|ssn|password|token)'
order by 1,2,3;

-- 6) Reporting views (health, coverage, orphans, mix, weekly bounds) ----------
-- 24h health: events, distinct subjects, orgs
create or replace view public.v_privacy_health_24h as
select
  count(*)::bigint as events_24h,
  count(distinct subject_id) filter (where subject_id is not null)::bigint as subjects_24h,
  count(distinct org_id)::bigint as orgs_24h
from public.privacy_events
where at >= now() - interval '24 hours';

-- Coverage: known codes with no recent events
create or replace view public.v_privacy_code_coverage as
select c.code,
       (select count(*) from public.privacy_events e
        where e.code = c.code and e.at >= now() - interval '24 hours') as events_24h
from public.alert_codes c
order by events_24h asc, c.code;

-- Orphans (events whose code not in catalog) — should be empty
create or replace view public.v_privacy_orphans as
select e.code, count(*) n
from public.privacy_events e
left join public.alert_codes c on c.code = e.code
where c.code is null
group by e.code
order by n desc;

-- Top mix (24h)
create or replace view public.v_privacy_mix_24h as
select code, count(*) n
from public.privacy_events
where at >= now() - interval '24 hours'
group by code order by n desc;

-- Weekly bounds per code (first_seen/last_seen/occurrences)
create or replace view public.v_privacy_bounds_7d as
with windowed as (
  select org_id, code, at from public.privacy_events
  where at >= now() - interval '7 days'
),
bounds as (
  select org_id, code,
         min(at) as first_seen,
         max(at) as last_seen,
         count(*) as occurrences
  from windowed group by org_id, code
)
select * from bounds order by org_id, code;
