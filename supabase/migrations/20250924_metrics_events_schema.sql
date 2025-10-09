-- 20250924_metrics_events_schema.sql
-- Purpose: Metrics schema (events + indexes), RLS, insert RPC with dedup, load status audit trigger,
-- SSO failure-rate views, and unified ops health view. Idempotent and safe to re-run.

-- 1) Metrics events table (append-only)
create table if not exists public.metrics_events (
  id bigserial primary key,
  org_id uuid null,
  user_id uuid null,
  event_code text not null,
  subject_type text not null,
  subject_id text not null,
  payload jsonb not null default '{}'::jsonb,
  ts timestamptz not null default now()
);

-- If an older shape exists, add missing columns non-destructively
alter table if exists public.metrics_events
  add column if not exists org_id uuid,
  add column if not exists user_id uuid,
  add column if not exists event_code text,
  add column if not exists subject_type text,
  add column if not exists subject_id text,
  add column if not exists payload jsonb not null default '{}'::jsonb,
  add column if not exists ts timestamptz not null default now();

-- Helpful indexes
create index if not exists idx_metrics_code_org_ts
  on public.metrics_events (event_code, org_id, ts desc);
create index if not exists idx_metrics_ts on public.metrics_events (ts desc);

-- RLS: read for org only (admins can read all via app_roles contains "admin")
alter table public.metrics_events enable row level security;
drop policy if exists metrics_events_select_org on public.metrics_events;
create policy metrics_events_select_org on public.metrics_events
for select to authenticated
using (
  coalesce(org_id::text,'') = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','')
  or coalesce(current_setting('request.jwt.claims', true)::json->>'app_roles','') like '%"admin"%'
);

-- 2) Insert helper with optional dedup for load.status.change within 1 second
create or replace function public.fn_metrics_event_insert(
  p_org_id uuid, p_user_id uuid, p_code text, p_subject_type text, p_subject_id text, p_payload jsonb default '{}'::jsonb
) returns bigint
language plpgsql
security definer
as $$
declare v_id bigint;
begin
  if p_code = 'load.status.change' then
    if exists (
      select 1 from public.metrics_events
      where event_code = 'load.status.change'
        and subject_type = 'load'
        and subject_id = p_subject_id
        and payload->>'status' = p_payload->>'status'
        and ts >= now() - interval '1 second'
    ) then
      return null; -- burst duplicate; skip
    end if;
  end if;

  insert into public.metrics_events (org_id, user_id, event_code, subject_type, subject_id, payload)
  values (p_org_id, p_user_id, p_code, p_subject_type, p_subject_id, coalesce(p_payload,'{}'::jsonb))
  returning id into v_id;
  return v_id;
end $$;

revoke all on function public.fn_metrics_event_insert(uuid,uuid,text,text,text,jsonb) from public;
grant execute on function public.fn_metrics_event_insert(uuid,uuid,text,text,text,jsonb) to service_role;

-- 3) Load status audit trigger (no-op if status unchanged)
create or replace function public.fn_load_status_audit()
returns trigger
language plpgsql
security definer
as $$
begin
  if TG_OP = 'UPDATE' and new.status is not distinct from old.status then
    return new; -- no-op
  end if;

  if TG_OP = 'UPDATE' and new.status is distinct from old.status then
    perform public.fn_metrics_event_insert(
      new.org_id, null, 'load.status.change', 'load', new.id::text,
      jsonb_build_object('from', old.status, 'status', new.status)
    );
  end if;
  return new;
end $$;

drop trigger if exists trg_load_status_audit on public.loads;
create trigger trg_load_status_audit
after update of status on public.loads
for each row execute function public.fn_load_status_audit();

-- 4) SSO failure-rate metrics views (expects events 'sso.login.attempt' & 'sso.login.fail')
-- 15m window failure rate per org/idp
create or replace view public.v_sso_fail_rate as
with w as (
  select
    org_id,
    (payload->>'idp')::text as idp,
    date_trunc('minute', ts) as window_start,
    count(*) filter (where event_code='sso.login.attempt') as attempts,
    count(*) filter (where event_code='sso.login.fail') as failures
  from public.metrics_events
  where event_code in ('sso.login.attempt','sso.login.fail')
    and ts >= now() - interval '1 hour'
  group by 1,2,3
)
select
  org_id, idp, window_start,
  attempts, failures,
  case when attempts = 0 then 0.0 else failures::numeric / attempts end as failure_rate
from w
order by window_start desc;

-- 24h rollup view for alert jobs
create or replace view public.v_sso_failure_rate_24h as
select
  org_id,
  count(*) filter (where event_code='sso.login.attempt' and ts >= now() - interval '24 hours') as attempts_24h,
  count(*) filter (where event_code='sso.login.fail' and ts >= now() - interval '24 hours') as failures_24h,
  case when count(*) filter (where event_code='sso.login.attempt' and ts >= now() - interval '24 hours') = 0
       then 0.0
       else (count(*) filter (where event_code='sso.login.fail' and ts >= now() - interval '24 hours'))::numeric
            / (count(*) filter (where event_code='sso.login.attempt' and ts >= now() - interval '24 hours'))::numeric
  end as failure_rate_24h
from public.metrics_events
where event_code in ('sso.login.attempt','sso.login.fail')
group by 1
order by failure_rate_24h desc nulls last;

-- 5) Unified ops health snapshot (best-effort joins)
-- Note: invoices amount column may vary; coalesce amount_cents/amount_due_usd
create or replace view public.v_ops_health as
with
loads_agg as (
  select
    org_id,
    count(*) as loads_total,
    count(*) filter (where status in ('accepted','enroute_pickup','at_pickup','picked','enroute_delivery','at_delivery')) as loads_assigned,
    count(*) filter (where status in ('delivered','completed')) as loads_completed
  from public.loads
  group by 1
),
ar_rollup as (
  select
    org_id,
    sum(coalesce((case when exists (select 1 from information_schema.columns where table_schema='public' and table_name='invoices' and column_name='amount_cents') then amount_cents end), 0))
      filter (where status = 'issued') as ar_issued_cents,
    sum(coalesce((case when exists (select 1 from information_schema.columns where table_schema='public' and table_name='invoices' and column_name='amount_cents') then amount_cents end), 0))
      filter (where status = 'paid') as ar_paid_cents
  from public.invoices
  group by 1
),
sso_15m as (
  select org_id,
         avg(failure_rate) as sso_failure_rate_15m
  from public.v_sso_fail_rate
  group by 1
),
parking_fresh as (
  -- Guard: only compute if tables exist
  select p.org_id,
         avg(case when ps.last_update >= now() - interval '30 minutes' then 1.0 else 0.0 end) as parking_freshness_30m
  from public.pois p
  join public.parking_state ps on ps.poi_id = p.id
  group by 1
)
select
  coalesce(l.org_id, a.org_id, s.org_id, pf.org_id) as org_id,
  l.loads_total, l.loads_assigned, l.loads_completed,
  a.ar_issued_cents, a.ar_paid_cents,
  s.sso_failure_rate_15m,
  pf.parking_freshness_30m
from loads_agg l
full join ar_rollup a on a.org_id = l.org_id
full join sso_15m s on s.org_id = coalesce(l.org_id,a.org_id)
full join parking_fresh pf on pf.org_id = coalesce(l.org_id,a.org_id,s.org_id);

-- 6) Optional: add NOT VALID FK on documents(load_id) -> loads(id) if not present
DO $$
BEGIN
  IF to_regclass('public.documents') IS NOT NULL AND to_regclass('public.loads') IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.table_constraints tc
      WHERE tc.table_schema='public' AND tc.table_name='documents' AND tc.constraint_name='fk_documents_load'
    ) THEN
      ALTER TABLE public.documents
        ADD CONSTRAINT fk_documents_load
        FOREIGN KEY (load_id) REFERENCES public.loads(id) NOT VALID;
    END IF;
  END IF;
END$$;
