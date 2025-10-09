-- 20250924_alerts_remediation_reporting.sql
-- Purpose: Remediation clicks + alert escalations schema, weekly metrics views,
-- export-friendly rollups, and optional notifier suppression helper.
-- All statements are idempotent and safe to re-run in Supabase.

-- 1) Remediation clicks with outcome/latency
create table if not exists public.remediation_clicks (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  code text not null,
  action text not null,                 -- 'sso_selfcheck'|'scim_dryrun'|...
  outcome text not null,                -- 'success'|'fail'|'skipped'
  latency_ms int not null default 0,
  clicked_by uuid null,
  clicked_at timestamptz not null default now()
);
create index if not exists idx_remediation_clicks_org_time on public.remediation_clicks (org_id, clicked_at desc);
alter table public.remediation_clicks enable row level security;
create policy if not exists remediation_clicks_read_org on public.remediation_clicks
for select to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
-- writes allowed via service functions only
revoke insert, update, delete on public.remediation_clicks from authenticated;

-- 2) Optional: escalation audit
create table if not exists public.alert_escalations (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  code text not null,
  from_severity text not null,
  to_severity text not null,
  at timestamptz not null default now(),
  meta jsonb not null default '{}'::jsonb
);
create index if not exists idx_alert_escalations_org_time on public.alert_escalations (org_id, at desc);
alter table public.alert_escalations enable row level security;
create policy if not exists alert_escalations_read_org on public.alert_escalations
for select to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

-- 3) Weekly alert bounds + escalation flag
create or replace view public.v_alert_weekly_bounds as
with week as (
  select org_id, code, severity, triggered_at
  from public.alerts_events
  where triggered_at >= now() - interval '7 days'
),
_bounds as (
  select org_id, code,
         min(triggered_at) as first_seen,
         max(triggered_at) as last_seen,
         count(*) as occurrences
  from week
  group by org_id, code
),
esc as (
  select org_id, code, bool_or(true) as escalation_logged
  from public.alert_escalations
  where at >= now() - interval '7 days'
  group by org_id, code
)
select b.org_id, b.code, b.first_seen, b.last_seen, b.occurrences,
       coalesce(e.escalation_logged, false) as escalation_logged
from _bounds b
left join esc e using (org_id, code);

-- 4) Weekly remediation outcomes and latency
create or replace view public.v_remediation_weekly as
select
  org_id,
  code,
  action,
  count(*) as clicks,
  count(*) filter (where outcome = 'success') as success_count,
  count(*) filter (where outcome = 'fail') as fail_count,
  round(avg(latency_ms))::int as avg_latency_ms
from public.remediation_clicks
where clicked_at >= now() - interval '7 days'
group by org_id, code, action
order by org_id, code, action;

-- 5) Weekly summary with chronic offenders (occurrences >= 5)
create or replace view public.v_alert_weekly_summary as
with bounds as (
  select * from public.v_alert_weekly_bounds
),
chronic as (
  select org_id,
         json_agg(code order by occurrences desc) filter (where occurrences >= 5) as chronic_codes
  from bounds
  group by org_id
)
select b.org_id,
       sum(b.occurrences) as total_alerts,
       max(b.last_seen) as last_alert_at,
       coalesce(c.chronic_codes, '[]'::json) as chronic_codes
from bounds b
left join chronic c using (org_id)
group by b.org_id, c.chronic_codes;

-- 6) Export-friendly combined weekly view
-- Includes bounds + remediation aggregates; carries chronic_codes for header/context
create or replace view public.v_alert_weekly_export as
select
  b.org_id,
  b.code,
  b.first_seen,
  b.last_seen,
  b.occurrences,
  b.escalation_logged,
  coalesce(r.action, '-') as action,
  coalesce(r.clicks, 0) as clicks,
  coalesce(r.success_count, 0) as success_count,
  coalesce(r.fail_count, 0) as fail_count,
  coalesce(r.avg_latency_ms, 0) as avg_latency_ms,
  s.chronic_codes
from public.v_alert_weekly_bounds b
left join public.v_remediation_weekly r
  on r.org_id = b.org_id and r.code = b.code
left join public.v_alert_weekly_summary s
  on s.org_id = b.org_id;

-- 7) Optional notifier suppression helper (30m default), bypass on recent escalation
-- Suppresses repeat posts per (org,code) if any event in alerts_events triggered within N minutes
-- but does not suppress if an escalation was logged within the same window.
create or replace function public.should_suppress_alert(p_org_id uuid, p_code text, p_minutes int default 30)
returns boolean
language plpgsql
stable
as $$
declare
  recent_event boolean;
  recent_escalation boolean;
begin
  select exists (
    select 1 from public.alerts_events e
    where e.org_id = p_org_id and e.code = p_code and e.triggered_at >= now() - make_interval(mins => p_minutes)
  ) into recent_event;

  select exists (
    select 1 from public.alert_escalations a
    where a.org_id = p_org_id and a.code = p_code and a.at >= now() - make_interval(mins => p_minutes)
  ) into recent_escalation;

  if recent_event and not recent_escalation then
    return true;  -- suppress
  end if;
  return false;   -- do not suppress
end $$;

revoke all on function public.should_suppress_alert(uuid,text,int) from public, anon, authenticated;
grant execute on function public.should_suppress_alert(uuid,text,int) to service_role;
