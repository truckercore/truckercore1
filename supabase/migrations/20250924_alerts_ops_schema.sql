-- 20250924_alerts_ops_schema.sql
-- Purpose: Alert ops schema and notifier helpers per spec (remediation clicks, escalations, suppression, retention)
-- Also provides weekly metrics views. Idempotent and compatible with existing tables in this repo.

-- 1) Remediation clicks
create table if not exists public.remediation_clicks (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  alert_id uuid null,                -- added to support per-alert joins; nullable for backfill compatibility
  code text not null,                -- normalized alert code
  user_id uuid null,                 -- added; nullable for backfill compatibility
  action text not null,              -- 'sso_selfcheck' | 'scim_dryrun' | 'rotation_start' | ...
  outcome text null,                 -- 'success' | 'fail' | null (pending)
  latency_ms int null,
  clicked_at timestamptz not null default now()
);
-- Ensure newly required columns exist (non-destructive)
alter table if exists public.remediation_clicks
  add column if not exists alert_id uuid,
  add column if not exists user_id uuid,
  alter column outcome drop not null,
  alter column latency_ms drop not null;

-- Helpful indexes
create index if not exists remediation_clicks_alert_time_idx
  on public.remediation_clicks (alert_id, clicked_at desc);
create index if not exists remediation_clicks_org_time_idx
  on public.remediation_clicks (org_id, clicked_at desc);

-- RLS
alter table public.remediation_clicks enable row level security;
create policy if not exists remediation_clicks_read_org on public.remediation_clicks
for select to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

-- Allow authenticated insert only for own org and own user id (sub)
create policy if not exists remediation_clicks_insert_self on public.remediation_clicks
for insert to authenticated
with check (
  org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','')
  and user_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'sub','')
);

-- Idempotency: one click per (alert,user) per minute
create unique index if not exists remediation_clicks_uniq_minute
on public.remediation_clicks (alert_id, user_id, date_trunc('minute', clicked_at));

-- 2) Alert escalations (audits)
create table if not exists public.alert_escalations (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  alert_id uuid null,
  code text not null,
  from_severity text not null,       -- 'INFO'|'WARN'|'P2'|'P1'|'P0'
  to_severity text not null,
  escalated_at timestamptz not null default now(),
  meta jsonb not null default '{}'::jsonb
);
-- Backward-compatible alterations
alter table if exists public.alert_escalations
  add column if not exists alert_id uuid,
  add column if not exists escalated_at timestamptz;
-- If old column "at" exists and escalated_at is null, leave as-is (no destructive data migration here)
create index if not exists alert_escalations_alert_time_idx
  on public.alert_escalations (alert_id, escalated_at desc);
create index if not exists alert_escalations_org_time_idx
  on public.alert_escalations (org_id, escalated_at desc);

alter table public.alert_escalations enable row level security;
create policy if not exists alert_escalations_read_org on public.alert_escalations
for select to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
revoke insert, update, delete on public.alert_escalations from authenticated;

-- 3) Notifier suppression (dedupe)
create table if not exists public.notifier_suppression (
  channel text not null,
  alert_key text not null,
  last_notified_at timestamptz not null default now(),
  level text not null default 'info', -- 'info'|'warn'|'crit'
  primary key (channel, alert_key)
);
create index if not exists notifier_suppression_last_idx
  on public.notifier_suppression (last_notified_at desc);

create or replace function public.notifier_should_send(
  p_channel text, p_alert_key text, p_window interval default interval '30 minutes'
) returns boolean
language plpgsql stable as $$
declare ts timestamptz;
begin
  select last_notified_at into ts
  from public.notifier_suppression
  where channel=p_channel and alert_key=p_alert_key;
  if ts is null then return true; end if;
  return (now() - ts) >= p_window;
end $$;

create or replace function public.notifier_mark_sent(
  p_channel text, p_alert_key text, p_level text default 'info'
) returns void
language sql as $$
  insert into public.notifier_suppression (channel, alert_key, last_notified_at, level)
  values (p_channel, p_alert_key, now(), p_level)
  on conflict (channel, alert_key) do update
    set last_notified_at=excluded.last_notified_at,
        level = greatest(excluded.level, public.notifier_suppression.level);
$$;

create or replace function public.notifier_should_send_with_escalation(
  p_channel text, p_alert_key text, p_alert_id uuid,
  p_window interval default interval '30 minutes'
) returns boolean
language plpgsql stable as $$
declare suppressed boolean; declare escalated boolean; begin
  suppressed := not public.notifier_should_send(p_channel, p_alert_key, p_window);
  select exists (
    select 1 from public.alert_escalations
    where alert_id = p_alert_id
      and escalated_at >= now() - p_window
  ) into escalated;
  return (not suppressed) or escalated;
end $$;

-- 4) Retention helper (server-only)
create or replace function public.prune_alert_ops(days int default 90)
returns void language plpgsql security definer as $$
begin
  delete from public.remediation_clicks where clicked_at   < now() - make_interval(days=>days);
  delete from public.alert_escalations  where escalated_at < now() - make_interval(days=>days);
end $$;
revoke all on function public.prune_alert_ops(int) from public, anon, authenticated;
grant execute on function public.prune_alert_ops(int) to service_role;

-- 5) Metrics views
-- Weekly bounds per alert code
create or replace view public.v_alert_week_bounds as
with windowed as (
  select org_id, code, severity, triggered_at
  from public.alerts_events
  where triggered_at >= date_trunc('week', now() - interval '7 days')
),
bounds as (
  select org_id, code,
         min(triggered_at) as first_seen,
         max(triggered_at) as last_seen,
         count(*)          as occurrences
  from windowed
  group by 1,2
),
lastsev as (
  select distinct on (org_id, code)
    org_id, code, severity, triggered_at
  from windowed
  order by org_id, code, triggered_at desc
)
select b.org_id, b.code, b.first_seen, b.last_seen, b.occurrences, l.severity as last_severity
from bounds b
left join lastsev l using (org_id, code);

-- Remediation outcome funnel (window = last 7d)
create or replace view public.v_remediation_outcomes as
with w as (
  select * from public.remediation_clicks
  where clicked_at >= now() - interval '7 days'
)
select
  org_id,
  code,
  count(*)                                             as clicks,
  count(*) filter (where outcome = 'success')         as successes,
  count(*) filter (where outcome = 'fail')            as failures,
  round(avg(latency_ms)::numeric, 0)                  as avg_latency_ms,
  max(clicked_at)                                     as last_click_at
from w
group by 1,2;

-- Summary tiles (last 7d)
create or replace view public.v_alert_summary as
select
  (select count(*) from public.alerts_events where triggered_at >= now() - interval '7 days') as alerts_7d,
  (select count(*) from public.alert_escalations where escalated_at >= now() - interval '7 days') as escalations_7d,
  (select count(*) from public.remediation_clicks where clicked_at >= now() - interval '7 days') as remediations_7d;

-- Export view (weekly windowed join)
create or replace view public.v_alert_export as
with bounds as (
  select * from public.v_alert_week_bounds
),
remed as (
  select org_id, code,
         count(*) as clicks_7d,
         count(*) filter (where outcome='success') as success_7d
  from public.remediation_clicks
  where clicked_at >= now() - interval '7 days'
  group by 1,2
)
select
  b.org_id, b.code, b.first_seen, b.last_seen, b.occurrences,
  coalesce(r.clicks_7d,0) as clicks_7d,
  coalesce(r.success_7d,0) as success_7d
from bounds b
left join remed r using (org_id, code)
order by b.org_id, b.code;

-- 6) Sanity helpers (optional)
-- RLS status
-- select relname, relrowsecurity from pg_class where relname in ('remediation_clicks','alert_escalations') order by relname;
-- Explain plans to verify index usage
-- explain analyze select * from public.remediation_clicks where clicked_at >= now() - interval '7 days' order by clicked_at desc limit 100;
-- explain analyze select * from public.alert_escalations where escalated_at >= now() - interval '7 days' order by escalated_at desc limit 100;
