-- 20250924_event_metrics_alignment.sql
-- Purpose: Align Event taxonomy and Metrics events with the new spec (categories, severities p1/p0,
--          occurred_at/source/metadata fields, helper emit function, health/coverage/retention views,
--          7d materialized rollup, and prune function). Idempotent and non-destructive.

-- 1) Event taxonomy -----------------------------------------------------------------
create table if not exists public.event_codes (
  code text primary key,
  category text not null,
  severity text not null,
  description text not null,
  metadata_schema jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- Ensure required columns exist
alter table if exists public.event_codes
  add column if not exists category text,
  add column if not exists severity text,
  add column if not exists description text,
  add column if not exists metadata_schema jsonb not null default '{}'::jsonb,
  add column if not exists created_at timestamptz not null default now();

-- Broaden severity CHECK to support both legacy and new severities (info|warn|error|critical|p1|p0)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'event_codes_severity_chk') THEN
    ALTER TABLE public.event_codes DROP CONSTRAINT event_codes_severity_chk;
  END IF;
  ALTER TABLE public.event_codes
    ADD CONSTRAINT event_codes_severity_chk
    CHECK (severity in ('info','warn','error','critical','p1','p0'));
END$$;

-- RLS for event_codes (read-only for authenticated)
alter table public.event_codes enable row level security;
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='event_codes' AND policyname='event_codes_read_all'
  ) THEN
    CREATE POLICY event_codes_read_all ON public.event_codes FOR SELECT TO authenticated USING (true);
  END IF;
END$$;
revoke insert, update, delete on public.event_codes from authenticated;

-- Seed minimal taxonomy per spec
insert into public.event_codes (code, category, severity, description) values
  ('sso.fail.rate.warn','sso','warn','SSO failure rate exceeds 5% window'),
  ('sso.fail.rate.p1','sso','p1','SSO failure rate exceeds 10% window'),
  ('sso.canary.fail','sso','p1','OIDC canary consecutive failures'),
  ('scim.run.failed','scim','warn','SCIM provisioning run failed'),
  ('alerts.escalation.unsnooze','alerts','info','Auto-unsnooze due to severity escalation'),
  ('alerts.remediation.click','alerts','info','Remediation link clicked'),
  ('security.rotation.overdue','security','warn','Secret rotation overdue')
on conflict (code) do nothing;


-- 2) Metrics events sink -------------------------------------------------------------
create table if not exists public.metrics_events (
  id bigserial primary key,
  occurred_at timestamptz not null default now(),
  org_id uuid null,
  event_code text not null references public.event_codes(code) on update cascade on delete restrict,
  source text not null,                          -- 'edge','api','job','ui'
  metadata jsonb not null default '{}'::jsonb,   -- flexible payload
  actor_user_id uuid null
);

-- Augment existing table shape non-destructively
alter table if exists public.metrics_events
  add column if not exists occurred_at timestamptz not null default now(),
  add column if not exists org_id uuid,
  add column if not exists event_code text,
  add column if not exists source text,
  add column if not exists metadata jsonb not null default '{}'::jsonb,
  add column if not exists actor_user_id uuid;

-- Helpful indexes
create index if not exists idx_metrics_events_time on public.metrics_events (occurred_at desc);
create index if not exists idx_metrics_events_org on public.metrics_events (org_id, occurred_at desc);
create index if not exists idx_metrics_events_code on public.metrics_events (event_code, occurred_at desc);

-- RLS for metrics_events (org-scoped read; writes via service role only)
alter table public.metrics_events enable row level security;
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='metrics_events' AND policyname='metrics_read_org'
  ) THEN
    CREATE POLICY metrics_read_org ON public.metrics_events
    FOR SELECT TO authenticated
    USING (org_id IS NULL OR org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
  END IF;
END$$;
revoke insert, update, delete on public.metrics_events from authenticated;

-- 3) Helper to emit events (server-only) -------------------------------------------
create or replace function public.fn_emit_event(
  p_code text,
  p_org_id uuid,
  p_source text,
  p_metadata jsonb default '{}'::jsonb,
  p_actor_user_id uuid default null
) returns void
language sql
security definer
as $$
  insert into public.metrics_events (event_code, org_id, source, metadata, actor_user_id)
  values (p_code, p_org_id, p_source, coalesce(p_metadata,'{}'::jsonb), p_actor_user_id);
$$;

revoke all on function public.fn_emit_event(text,uuid,text,jsonb,uuid) from public;
grant execute on function public.fn_emit_event(text,uuid,text,jsonb,uuid) to service_role;


-- 4) Reporting views and rollups ----------------------------------------------------
-- 24h health summary
create or replace view public.v_event_health_24h as
with w as (
  select *
  from public.metrics_events
  where occurred_at >= now() - interval '24 hours'
)
select
  count(*)::bigint as total_events,
  count(distinct event_code)::int as distinct_codes,
  count(distinct org_id)::int as distinct_orgs
from w;

-- Code coverage (which codes have/haven't fired in 7d)
create or replace view public.v_event_code_coverage as
with recent as (
  select event_code, max(occurred_at) as last_seen
  from public.metrics_events
  where occurred_at >= now() - interval '7 days'
  group by event_code
)
select
  c.code,
  c.category,
  c.severity,
  r.last_seen,
  (r.event_code is null) as no_recent_events
from public.event_codes c
left join recent r on r.event_code = c.code
order by no_recent_events desc, c.category, c.code;

-- Retention status (events per day)
create or replace view public.v_event_retention_status as
select
  date_trunc('day', occurred_at) as day,
  count(*)::bigint as events
from public.metrics_events
group by 1
order by 1 desc;

-- 7d materialized rollup (hourly buckets)
create materialized view if not exists public.mv_events_7d as
select
  date_trunc('hour', occurred_at) as hour_bucket,
  org_id,
  event_code,
  count(*)::bigint as events
from public.metrics_events
where occurred_at >= now() - interval '7 days'
group by 1,2,3;

create index if not exists idx_mv_events_7d_hour on public.mv_events_7d (hour_bucket desc);
create index if not exists idx_mv_events_7d_org_code on public.mv_events_7d (org_id, event_code);

-- Refresh helper (server-only)
create or replace function public.refresh_mv_events_7d()
returns void language sql security definer as $$
  refresh materialized view concurrently public.mv_events_7d;
$$;
revoke all on function public.refresh_mv_events_7d() from public;
grant execute on function public.refresh_mv_events_7d() to service_role;

-- 5) Retention prune (return deleted count) ----------------------------------------
create or replace function public.prune_metrics_events_count(p_days int)
returns bigint
language plpgsql
security definer
as $$
declare v_count bigint; begin
  with del as (
    delete from public.metrics_events
    where occurred_at < now() - (p_days || ' days')::interval
    returning 1
  ) select count(*) into v_count from del;
  return coalesce(v_count,0);
end $$;

revoke all on function public.prune_metrics_events_count(int) from public;
grant execute on function public.prune_metrics_events_count(int) to service_role;

-- Note: An older function public.prune_metrics_events(int) may exist returning void.
-- We keep it intact to avoid breaking callers. Call *_count variant for result.
