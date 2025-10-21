-- =============================================================
-- Global Safety Nits (cross‑module hardening)
-- Idempotent and safe to re‑run
-- =============================================================

-- 0) Touch updated_at on UPDATE if column exists
create or replace function public.touch_updated_at() returns trigger
language plpgsql as $$
begin
  if (TG_OP = 'UPDATE') then
    if to_jsonb(NEW) ? 'updated_at' then
      NEW.updated_at := now();
    end if;
  end if;
  return NEW;
end $$;

-- Re-attach trigger to every public table that has updated_at
do $$
declare r record;
begin
  for r in
    select c.relname as t
    from pg_class c
    join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relkind='r'
      and exists (select 1 from pg_attribute a where a.attrelid=c.oid and a.attname='updated_at')
  loop
    execute format('drop trigger if exists trg_touch_updated_at on %I;', r.t);
    execute format('create trigger trg_touch_updated_at before update on %I for each row execute function public.touch_updated_at();', r.t);
  end loop;
end $$;

-- 1) Common enum helpers (avoid free‑text typos)
DO $$ BEGIN
  CREATE TYPE severity_level AS ENUM ('info','warn','p1');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 2) Tighten auth boundary: deny anon by default (RLS still applies)
revoke all on all tables    in schema public from anon;
revoke all on all sequences in schema public from anon;
revoke all on all functions in schema public from anon;

-- =============================================================
-- HOS / ELD
-- =============================================================

-- Counters must never be negative; cycle scheme sanity
alter table if exists public.hos_counters
  add constraint if not exists chk_hos_nonneg check (
    remaining_drive_s >= 0 and remaining_shift_s >= 0 and
    remaining_break_s >= 0 and remaining_cycle_s >= 0
  ),
  add constraint if not exists chk_hos_cycle_scheme
    check (cycle_scheme in ('US_70_8','US_60_7','CA_South','CA_North'));

-- Alerts: normalized severity & de-dup window
alter table if exists public.hos_alerts
  alter column severity type severity_level using severity::severity_level;

-- Note: volatile predicate is acceptable for ops; adjust if needed for your PG policy
create unique index if not exists uq_hos_alerts_5m
  on public.hos_alerts(org_id, driver_id, code)
  where created_at > now() - interval '5 minutes';

-- Faster driver/last status lookups
create index if not exists idx_hos_counters_driver on public.hos_counters(driver_id);

-- RLS: allow drivers to UPDATE acknowledgement on their own alerts
create policy if not exists hos_alerts_ack_self on public.hos_alerts
  for update using (
    driver_id in (select id from public.drivers where user_id=auth.uid())
    and org_id = (current_setting('request.jwt.claims', true)::json->>'app_org_id')::uuid
  )
  with check (
    driver_id in (select id from public.drivers where user_id=auth.uid())
    and org_id = (current_setting('request.jwt.claims', true)::json->>'app_org_id')::uuid
  );

-- Service-role ONLY short-circuit on hos_counters
create policy if not exists hos_service_insert on public.hos_counters
  for insert with check (
    (current_setting('request.jwt.claims', true)::json->>'role') in ('service','admin','fleet_admin')
    and org_id = (current_setting('request.jwt.claims', true)::json->>'app_org_id')::uuid
  );

create policy if not exists hos_service_update on public.hos_counters
  for update using (
    (current_setting('request.jwt.claims', true)::json->>'role') in ('service','admin','fleet_admin')
    and org_id = (current_setting('request.jwt.claims', true)::json->>'app_org_id')::uuid
  );

-- =============================================================
-- IFTA
-- =============================================================

-- Quarter bounds correctness
alter table if exists public.ifta_quarters
  add constraint if not exists chk_ifta_bounds check (start_date <= end_date),
  add constraint if not exists chk_ifta_quarter_window check (
    extract(quarter from start_date)::int = quarter and extract(quarter from end_date)::int = quarter
    and extract(year from start_date)::int = year and extract(year from end_date)::int = year
  );

-- Ledger numbers cannot be negative
alter table if exists public.ifta_ledger
  add constraint if not exists chk_ifta_nonneg check (miles >= 0 and gallons >= 0);

-- Materialized summary for fast export
create materialized view if not exists public.mv_ifta_summary as
select l.org_id, l.vehicle_id, q.year, q.quarter, l.jurisdiction, l.miles, l.gallons
from public.ifta_ledger l
join public.ifta_quarters q on q.id = l.ifta_quarter_id;

create index if not exists idx_mv_ifta_summary on public.mv_ifta_summary(org_id, year, quarter);

-- Fast refresh helper
create or replace function public.ifta_refresh_summary(p_org uuid, p_year int, p_quarter int)
returns void language plpgsql security definer set search_path=public as $$
begin
  refresh materialized view concurrently public.mv_ifta_summary;
end $$;

-- Fuel purchases: ensure org/vehicle coherence
create or replace function public.fp_vehicle_org_guard() returns trigger
language plpgsql as $$
declare v_org uuid;
begin
  select org_id into v_org from public.vehicles where id = new.vehicle_id;
  if new.org_id is distinct from v_org then
    raise exception 'fuel_purchases org/vehicle org mismatch';
  end if;
  return new;
end $$;

drop trigger if exists trg_fp_org_guard on public.fuel_purchases;
create trigger trg_fp_org_guard before insert or update on public.fuel_purchases
for each row execute function public.fp_vehicle_org_guard();

-- =============================================================
-- DQF
-- =============================================================

-- Prevent duplicate doc type/expiry per driver
create unique index if not exists uq_driver_docs_one_type_window
  on public.driver_docs(driver_id, type, coalesce(expires_at, to_date('9999-12-31','YYYY-MM-DD')));

-- Driver quals status sanity
alter table if exists public.driver_quals
  add constraint if not exists chk_dqf_status check (status in ('pending','active','suspended'));

-- Expiring soon (TZ-aware via current_date + 30)
create or replace view public.v_dqf_expiring_soon as
select d.driver_id, d.type, d.expires_at, dq.status, d.org_id
from public.driver_docs d
left join public.driver_quals dq on dq.driver_id = d.driver_id
where d.expires_at is not null and d.expires_at <= (current_date + 30);

-- Notify only once per (driver, doc_type, expiration)
create unique index if not exists uq_dqf_notice_once
  on public.dqf_notices(org_id, driver_id, doc_type, expires_at);

-- =============================================================
-- Safety / CSA
-- =============================================================

-- BASIC category allow-list
DO $$ BEGIN
  CREATE TYPE csa_basic AS ENUM
    ('Unsafe Driving','HOS Compliance','Driver Fitness','Controlled Substances/Alcohol','Vehicle Maintenance','HM Compliance','Crash Indicator');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

alter table if exists public.safety_event_mapping
  alter column basic type csa_basic using basic::csa_basic,
  add constraint if not exists chk_sem_weight check (weight >= 0);

-- Prevent duplicate open coaching task for same driver/basic
create unique index if not exists uq_coach_open
  on public.coaching_tasks(org_id, driver_id, basic)
  where status in ('open','in_progress');

-- Threshold-driven task creator
create or replace function public.coaching_tasks_autocreate(p_org uuid, p_basic csa_basic, p_window int, p_threshold numeric)
returns int language plpgsql security definer set search_path=public as $$
declare cnt int:=0;
begin
  insert into public.coaching_tasks(org_id, driver_id, basic, reason, due_at)
  select s.org_id, s.driver_id, s.basic,
         format('Score %.2f ≥ threshold %.2f over %s days', s.score, p_threshold, p_window),
         now() + interval '7 days'
  from public.driver_safety_scores s
  left join public.coaching_tasks t
    on t.org_id=s.org_id and t.driver_id=s.driver_id and t.basic=s.basic
   and t.status in ('open','in_progress')
  where s.org_id=p_org and s.basic=p_basic and s.window_days=p_window and s.score >= p_threshold
    and t.id is null;
  GET DIAGNOSTICS cnt = ROW_COUNT; return cnt;
end $$;

-- =============================================================
-- Core Security Hygiene
-- =============================================================

-- Inventory SECURITY DEFINER funcs and check pinned search_path
create or replace view public.v_secdef_hygiene as
select n.nspname, p.proname,
       p.prosecdef as is_sd,
       (pg_get_functiondef(p.oid) ilike '% set search_path=public %') as pinned
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.prosecdef=true;

-- Detect permissive RLS policies (true USING / missing WITH CHECK)
create or replace view public.v_rls_lint as
select p.schemaname, p.tablename, p.policyname, p.cmd,
       (p.qual is null or p.qual ~* '^\s*true\s*$') as is_true_using,
       (p.with_check is null or p.with_check ~* '^\s*true\s*$') as is_true_check
from pg_policies p where p.schemaname='public';

-- =============================================================
-- Helpful Indexes (hot paths)
-- =============================================================

-- HOS: last status lookups by driver/time (use event_time column in this repo)
create index if not exists idx_telematics_events_driver_time on public.telematics_events(driver_id, event_time desc);

-- IFTA: purchases by vehicle/time
create index if not exists idx_fuel_purchases_vehicle_time on public.fuel_purchases(vehicle_id, purchased_at desc);

-- Safety: scores by (org,basic,window)
create index if not exists idx_safety_scores_org_basic_win on public.driver_safety_scores(org_id, basic, window_days);

-- DQF: fast "documents by driver & type"
create index if not exists idx_driver_docs_type on public.driver_docs(driver_id, type);

-- =============================================================
-- Post-deploy quick sanity checks (non-fatal selects)
-- =============================================================
-- RLS sanity: cross-tenant must return 0
select count(*) as leak_count from public.hos_counters where org_id <> (current_setting('request.jwt.claims', true)::json->>'app_org_id')::uuid;

-- HOS counters consistency
select count(*) as hos_counters_bad
from public.hos_counters
where remaining_drive_s < 0 or remaining_shift_s < 0 or remaining_break_s < 0 or remaining_cycle_s < 0;

-- IFTA: each ledger row must belong to vehicle’s org
select count(*) as ifta_org_mismatch
from public.ifta_ledger l
join public.vehicles v on v.id=l.vehicle_id
where l.org_id <> v.org_id;

-- DQF: duplicate open coaching tasks should be zero
select count(*) as dup_open from public.coaching_tasks
where (org_id, driver_id, basic) in (
  select org_id, driver_id, basic from public.coaching_tasks
  where status in ('open','in_progress')
  group by org_id, driver_id, basic having count(*) > 1
);

-- SecDef hygiene
select * from public.v_secdef_hygiene where not pinned;
