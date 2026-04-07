-- 20250923_tc_quality.sql
-- Purpose: Consolidated, idempotent schema for quality/security dashboard + health.
-- Safe to re-run; uses IF NOT EXISTS and CREATE OR REPLACE.

-- 1) Public health ping view (anon/auth readable)
create or replace view public.health_ping_view as
select now() as now;

revoke all on public.health_ping_view from public;
granted := (select 1);
grant select on public.health_ping_view to anon, authenticated;

-- 2) Base tables for dashboard (alerts, escalation_logs, retests, remediations)
create table if not exists public.alerts (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  severity text check (severity in ('low','medium','high','critical')) default 'low',
  status text check (status in ('open','ack','resolved')) default 'open',
  created_at timestamptz not null default now()
);

create index if not exists alerts_created_at_idx on public.alerts (created_at desc);

create table if not exists public.escalation_logs (
  id uuid primary key default gen_random_uuid(),
  alert_id uuid not null references public.alerts(id) on delete cascade,
  org_id uuid,
  title text not null,
  status text check (status in ('open','investigating','mitigated','closed')) default 'open',
  owner_id uuid,
  owner_name text,
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists escalation_logs_created_at_idx on public.escalation_logs (created_at desc);
create index if not exists escalation_logs_alert_idx on public.escalation_logs (alert_id);
create index if not exists escalation_logs_org_idx on public.escalation_logs (org_id);

create table if not exists public.retests (
  id uuid primary key default gen_random_uuid(),
  alert_id uuid not null references public.alerts(id) on delete cascade,
  retest_status text check (retest_status in ('pending','scheduled','passed','failed')) default 'pending',
  next_retest_at date,
  last_retested_at date,
  created_at timestamptz not null default now()
);

create index if not exists retests_next_idx on public.retests (next_retest_at nulls last);
create index if not exists retests_alert_idx on public.retests (alert_id);

create table if not exists public.remediations (
  id uuid primary key default gen_random_uuid(),
  alert_id uuid not null references public.alerts(id) on delete cascade,
  fix_title text not null,
  deployed_at date not null,
  verification_status text check (verification_status in ('unverified','verified_pass','verified_fail')) default 'unverified',
  created_at timestamptz not null default now()
);

create index if not exists remediations_deployed_idx on public.remediations (deployed_at);

-- 3) Views for cards
create or replace view public.retests_view as
select
  r.id,
  r.alert_id,
  a.title as alert_title,
  r.retest_status,
  r.next_retest_at,
  r.last_retested_at
from public.retests r
join public.alerts a on a.id = r.alert_id;

create or replace view public.remediation_effectiveness_quarterly as
with base as (
  select
    extract(year from r.deployed_at)::int as year,
    extract(quarter from r.deployed_at)::int as quarter,
    count(*) as total,
    count(*) filter (where r.verification_status = 'verified_pass') as passed
  from public.remediations r
  group by 1,2
)
select
  year,
  quarter,
  total,
  passed,
  case when total > 0 then (passed::decimal / total) else 0 end as pass_rate
from base
order by year, quarter;

-- 4) RLS enablement (keep permissive sample policies; tighten per-tenant later)
alter table public.alerts enable row level security;
alter table public.escalation_logs enable row level security;
alter table public.retests enable row level security;
alter table public.remediations enable row level security;

-- Sample permissive policies (idempotent creation)
do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='alerts' and policyname='alerts_all_read') then
    create policy alerts_all_read on public.alerts for select using (true);
    create policy alerts_all_write on public.alerts for insert with check (true);
    create policy alerts_all_update on public.alerts for update using (true);
  end if;

  if not exists (select 1 from pg_policies where schemaname='public' and tablename='escalation_logs' and policyname='escalations_all_read') then
    create policy escalations_all_read on public.escalation_logs for select using (true);
    create policy escalations_all_write on public.escalation_logs for insert with check (true);
    create policy escalations_all_update on public.escalation_logs for update using (true);
  end if;

  if not exists (select 1 from pg_policies where schemaname='public' and tablename='retests' and policyname='retests_all_read') then
    create policy retests_all_read on public.retests for select using (true);
    create policy retests_all_write on public.retests for insert with check (true);
    create policy retests_all_update on public.retests for update using (true);
  end if;

  if not exists (select 1 from pg_policies where schemaname='public' and tablename='remediations' and policyname='remediations_all_read') then
    create policy remediations_all_read on public.remediations for select using (true);
    create policy remediations_all_write on public.remediations for insert with check (true);
    create policy remediations_all_update on public.remediations for update using (true);
  end if;
end $$;

-- 5) Edge helper RPC for health function
create or replace function public.edge_health_now()
returns timestamptz language sql stable
as $$ select now() $$;
