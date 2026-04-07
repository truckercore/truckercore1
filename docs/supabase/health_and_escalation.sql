-- Supabase SQL snippets for health probe, RLS examples, escalation audit, backoff, and reporting

-- Health table + RLS
create table if not exists public.health (
  id bigint primary key generated always as identity,
  ok boolean not null default true,
  message text default 'alive'
);

insert into public.health (ok, message)
values (true, 'boot')
on conflict do nothing;

alter table public.health enable row level security;

create policy if not exists "anon can read health"
  on public.health for select
  to anon
  using (true);

-- Example RLS for KPI view/table (adjust to your tenant model)
-- Enable RLS and allow authenticated users to read their org-scoped KPIs.
-- Replace predicate with your actual tenant/role logic.
-- alter table public.fleet_kpis enable row level security;
-- create policy if not exists "fleet managers can read KPIs"
--   on public.fleet_kpis for select
--   to authenticated
--   using (
--     auth.uid() = fleet_manager_id
--   );

-- Escalation audit: WARN → P1 auto‑unsnooze log
create table if not exists public.escalation_events (
  id bigint generated always as identity primary key,
  alert_id uuid not null,
  from_severity text not null check (from_severity in ('INFO','WARN','P2','P1')),
  to_severity   text not null check (to_severity   in ('INFO','WARN','P2','P1')),
  reason        text,
  actor         text not null,  -- 'system' or 'user:<uid>'
  occurred_at   timestamptz not null default now()
);

alter table public.alerts
  add column if not exists escalation_logged boolean not null default false;

create index if not exists iee_alert_id on public.escalation_events(alert_id);
create index if not exists iee_time on public.escalation_events(occurred_at desc);

alter table public.escalation_events enable row level security;
create policy if not exists "admins can read audit"
  on public.escalation_events for select
  using (
    exists (select 1 from public.user_roles ur
            where ur.user_id = auth.uid()
              and ur.role in ('admin','security'))
  );
revoke all on public.escalation_events from anon, authenticated;

-- Write audit on auto‑unsnooze (SQL fragment)
-- insert into public.escalation_events(alert_id, from_severity, to_severity, reason, actor)
-- values (_alert_id, 'WARN', 'P1', 'auto-unsnooze: threshold breach', 'system');
-- update public.alerts set escalation_logged = true where id = _alert_id;

-- Retest backoff (15s → 60s → 5m)
create table if not exists public.alert_retest_state (
  alert_id uuid primary key,
  tries int not null default 0,
  next_at timestamptz not null default now()
);

-- Remediation actions (outcome + latency)
create table if not exists public.remediation_actions (
  id bigint generated always as identity primary key,
  alert_id uuid not null,
  action_key text not null,          -- e.g., 'sso_selfcheck', 'scim_dryrun'
  clicked_by uuid references auth.users(id),
  clicked_at timestamptz not null default now(),
  outcome text,                      -- 'resolved' | 'no_effect' | 'escalated'
  outcome_latency_ms int,
  notes text
);

create index if not exists ira_alert_time on public.remediation_actions(alert_id, clicked_at desc);

alter table public.remediation_actions enable row level security;
create policy if not exists "ops/admin read"
  on public.remediation_actions for select
  using (
    exists (select 1 from public.user_roles ur
            where ur.user_id = auth.uid()
              and ur.role in ('admin','sre','ops'))
  );

-- Quarterly effectiveness view
create or replace view public.remediation_effectiveness_qtr as
select
  action_key,
  count(*)                                  as attempts,
  count(*) filter (where outcome='resolved') as resolved,
  round(avg(outcome_latency_ms)::numeric,0)  as avg_ms,
  percentile_cont(0.95) within group (order by outcome_latency_ms) as p95_ms
from public.remediation_actions
where clicked_at >= date_trunc('quarter', now())
group by 1
order by resolved desc, avg_ms asc;

-- Weekly report bounds (first_seen / last_seen)
-- Replace table/columns as needed.
with windowed as (
  select org_id, code, severity, triggered_at
  from public.alerts_events
  where triggered_at >= now() - interval '7 days'
),
_bounds as (
  select org_id, code,
         min(triggered_at) as first_seen,
         max(triggered_at) as last_seen,
         count(*) as occurrences
  from windowed
  group by org_id, code
),
sev_latest as (
  select distinct on (org_id, code) org_id, code, severity, triggered_at
  from windowed
  order by org_id, code, triggered_at desc
)
select b.org_id, b.code, b.first_seen, b.last_seen, b.occurrences, sl.severity as last_severity
from _bounds b
left join sev_latest sl using (org_id, code)
order by b.org_id, b.code;
