-- 20250924_event_codes_metrics_spec.sql
-- Purpose: Align Event code registry and Metrics events sink with the spec in the issue.
-- Safe to re-run (idempotent) and compatible with existing event taxonomy migrations.

-- 1) Registry of event codes ---------------------------------------------------
create table if not exists public.event_codes (
  code text primary key,
  category text not null,
  severity text not null check (severity in ('info','warn','error','critical')),
  description text null,
  created_at timestamptz not null default now()
);

-- Add/align columns on existing table
alter table if exists public.event_codes
  add column if not exists category text,
  add column if not exists severity text,
  add column if not exists description text,
  add column if not exists created_at timestamptz not null default now();

-- Ensure severity CHECK exists (guarded)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'event_codes_severity_chk'
  ) THEN
    ALTER TABLE public.event_codes
      ADD CONSTRAINT event_codes_severity_chk
      CHECK (severity in ('info','warn','error','critical'));
  END IF;
END$$;

-- If an older column "domain" exists, backfill category from it
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='event_codes' AND column_name='domain'
  ) THEN
    UPDATE public.event_codes SET category = coalesce(category, domain);
  END IF;
END$$;

create index if not exists idx_event_codes_cat on public.event_codes (category);

-- 2) Metrics events (append-only) --------------------------------------------
create table if not exists public.metrics_events (
  id uuid primary key default gen_random_uuid(),
  org_id uuid null,
  event_code text not null,
  at timestamptz not null default now(),
  tags jsonb not null default '{}'::jsonb,
  data jsonb not null default '{}'::jsonb
);

-- Augment existing columns if table already exists with a different shape
alter table if exists public.metrics_events
  add column if not exists org_id uuid,
  add column if not exists event_code text,
  add column if not exists at timestamptz not null default now(),
  add column if not exists tags jsonb not null default '{}'::jsonb,
  add column if not exists data jsonb not null default '{}'::jsonb;

-- FK & hygiene (guarded)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE table_schema='public' AND table_name='metrics_events' AND constraint_type='FOREIGN KEY' AND constraint_name='fk_metrics_events_code'
  ) THEN
    ALTER TABLE public.metrics_events
      ADD CONSTRAINT fk_metrics_events_code
      FOREIGN KEY (event_code) REFERENCES public.event_codes(code) ON UPDATE CASCADE ON DELETE RESTRICT;
  END IF;
END$$;

create index if not exists idx_metrics_events_time on public.metrics_events (at desc);
create index if not exists idx_metrics_events_code_time on public.metrics_events (event_code, at desc);
create index if not exists idx_metrics_events_org_time on public.metrics_events (org_id, at desc);
-- jsonb_path_ops may not be available in all PG builds; fall back to plain GIN if necessary
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes WHERE schemaname='public' AND indexname='idx_metrics_events_tags_gin'
  ) THEN
    BEGIN
      EXECUTE 'create index idx_metrics_events_tags_gin on public.metrics_events using gin (tags jsonb_path_ops)';
    EXCEPTION WHEN others THEN
      -- fallback
      EXECUTE 'create index idx_metrics_events_tags_gin on public.metrics_events using gin (tags)';
    END;
  END IF;
END$$;

-- 3) RLS (org-scoped reads; writes via service) ------------------------------
alter table public.metrics_events enable row level security;
alter table public.event_codes enable row level security;

-- Read: authenticated can read events for their org_id (or null/org-wide)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='metrics_events' AND policyname='metrics_read_org'
  ) THEN
    CREATE POLICY metrics_read_org ON public.metrics_events
    FOR SELECT TO authenticated
    USING (
      coalesce(org_id::text,'') = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','')
      OR org_id IS NULL
    );
  END IF;
END$$;

-- Write: service role only (Edge/jobs)
revoke insert, update, delete on public.metrics_events from authenticated, anon;
grant select on public.metrics_events to authenticated;

-- Event codes: public read; writes by service role
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='event_codes' AND policyname='event_codes_read_all'
  ) THEN
    CREATE POLICY event_codes_read_all ON public.event_codes
    FOR SELECT TO authenticated USING (true);
  END IF;
END$$;
revoke insert, update, delete on public.event_codes from authenticated, anon;

-- 4) Seed recommended codes ---------------------------------------------------
insert into public.event_codes (code, category, severity, description) values
('sso.selfcheck.ok','auth/sso','info','SSO self-check passed'),
('sso.selfcheck.fail','auth/sso','warn','SSO self-check failed'),
('sso.canary.fail','auth/sso','critical','Weekly OIDC canary failure'),
('scim.run.success','auth/scim','info','Provisioning run succeeded'),
('scim.run.partial','auth/scim','warn','Provisioning run partial success'),
('scim.run.failed','auth/scim','error','Provisioning run failed'),
('alert.sent','alerts','info','Alert notification sent'),
('alert.snoozed','alerts','info','Alert snoozed'),
('alert.auto_unsnooze','alerts','warn','Snooze bypassed due to escalation'),
('alert.dedup.skipped','alerts','info','Alert duplicate suppressed'),
('export.weekly.summary.ok','export','info','Weekly pilot export success'),
('export.weekly.summary.fail','export','error','Weekly pilot export failed'),
('ops.rotation.reminder.sent','ops','info','Security key rotation reminder sent')
on conflict (code) do nothing;

-- 5) Metrics health views -----------------------------------------------------
-- 24h health (volume, distinct codes, orphans)
create or replace view public.v_event_health_24h as
with base as (
  select * from public.metrics_events where at >= now() - interval '24 hours'
),
orphans as (
  select m.event_code
  from base m
  left join public.event_codes c on c.code = m.event_code
  where c.code is null
  group by 1
)
select
  (select count(*) from base) as total_events_24h,
  (select count(distinct event_code) from base) as distinct_codes_24h,
  (select count(*) from orphans) as orphan_codes_24h;

-- Event code coverage (which codes have/haven’t fired in 7d)
create or replace view public.v_event_code_coverage as
with fired as (
  select event_code, max(at) as last_seen_at
  from public.metrics_events
  where at >= now() - interval '7 days'
  group by 1
)
select
  c.code,
  c.category,
  c.severity,
  f.last_seen_at,
  (f.last_seen_at is not null) as seen_in_7d
from public.event_codes c
left join fired f on f.event_code = c.code
order by c.category, c.code;

-- Optional org-scoped 24h summary
create or replace view public.v_event_org_24h as
select
  org_id,
  event_code,
  count(*) as n,
  min(at) as first_seen_24h,
  max(at) as last_seen_24h
from public.metrics_events
where at >= now() - interval '24 hours'
group by org_id, event_code
order by org_id, n desc;

-- 6) Retention and rollup helpers --------------------------------------------
create or replace function public.prune_metrics_events(days int default 90)
returns void language plpgsql security definer as $$
begin
  delete from public.metrics_events where at < now() - make_interval(days=>days);
end $$;
revoke all on function public.prune_metrics_events(int) from public, anon, authenticated;
grant execute on function public.prune_metrics_events(int) to service_role;

create materialized view if not exists public.mv_events_7d as
select date_trunc('hour', at) as hour, event_code, count(*) n
from public.metrics_events
where at >= now() - interval '7 days'
group by 1,2;
create index if not exists mv_events_7d_idx on public.mv_events_7d (hour, event_code);
-- Note: schedule: refresh materialized view concurrently public.mv_events_7d;

-- 7) Supabase metrics views (examples per category) ---------------------------
-- SSO/SCIM last 24h
create or replace view public.v_sso_scim_24h as
select
  coalesce(org_id, '00000000-0000-0000-0000-000000000000'::uuid) as org_id,
  sum((event_code = 'sso.selfcheck.ok')::int) as selfcheck_ok,
  sum((event_code = 'sso.selfcheck.fail')::int) as selfcheck_fail,
  sum((event_code = 'sso.canary.fail')::int) as canary_fail,
  sum((event_code = 'scim.run.success')::int) as scim_success,
  sum((event_code = 'scim.run.partial')::int) as scim_partial,
  sum((event_code = 'scim.run.failed')::int) as scim_failed
from public.metrics_events
where at >= now() - interval '24 hours'
  and event_code in ('sso.selfcheck.ok','sso.selfcheck.fail','sso.canary.fail','scim.run.success','scim.run.partial','scim.run.failed')
group by 1;

-- Alert pipeline KPIs (24h)
create or replace view public.v_alert_pipeline_24h as
select
  coalesce(org_id, '00000000-0000-0000-0000-000000000000'::uuid) as org_id,
  sum((event_code = 'alert.sent')::int) as alerts_sent,
  sum((event_code = 'alert.snoozed')::int) as alerts_snoozed,
  sum((event_code = 'alert.auto_unsnooze')::int) as auto_unsnoozed,
  sum((event_code = 'alert.dedup.skipped')::int) as alerts_deduped
from public.metrics_events
where at >= now() - interval '24 hours'
  and event_code in ('alert.sent','alert.snoozed','alert.auto_unsnooze','alert.dedup.skipped')
group by 1;

-- Done.
