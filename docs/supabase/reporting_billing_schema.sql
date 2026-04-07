-- Phase 6: Reporting and Billing (Supabase/Postgres)
-- Run AFTER foundation_tenancy_schema.sql and fleet/maintenance schemas.
-- Provides: reporting aggregates (materialized views + nightly refresh), plan tiers/limits enforcement helpers, and usage metering.

-- Create necessary extensions
create extension if not exists pgcrypto;

-- Create a dedicated billing schema to keep objects organized
create schema if not exists billing AUTHORIZATION pg_database_owner;
COMMENT ON SCHEMA billing IS 'Contains tables, functions, and views related to billing and usage metering.';

-- 0) Plan tiers
-- Helper to resolve current org id from membership or JWT claim. Prefer membership when available.
create or replace function public.current_org_id()
returns uuid
language sql
stable
as $$
  -- Try to resolve from organization_members (membership-driven orgs)
  select org_id
  from public.organization_members
  where user_id = (select auth.uid())
  order by org_id
  limit 1
$$;
DO $plan_tier$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'plan_tier') THEN
    create type billing.plan_tier as enum ('free','pro','enterprise');
  END IF;
END $plan_tier$;

create table if not exists billing.organization_billing (
  org_id uuid primary key references public.organizations(id) on delete cascade,
  plan billing.plan_tier not null default 'free',
  limits jsonb, -- optional overrides, e.g., {"positions_per_day": 20000, "geofence_count": 10}
  effective_from timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
COMMENT ON TABLE billing.organization_billing IS 'Stores the billing plan and usage limits for each organization.';
COMMENT ON COLUMN billing.organization_billing.org_id IS 'Unique identifier for the organization, also serves as the primary key.';
COMMENT ON COLUMN billing.organization_billing.plan IS 'The current billing plan tier for the organization.';
COMMENT ON COLUMN billing.organization_billing.limits IS 'JSONB column for storing custom overrides to plan-based limits.';

alter table billing.organization_billing enable row level security;
create or replace function public.set_timestamp_updated_at() returns trigger as $$
begin new.updated_at = now(); return new; end; $$ language plpgsql;
COMMENT ON FUNCTION public.set_timestamp_updated_at() IS 'A generic function to automatically update the "updated_at" timestamp on a table.';
create trigger trg_org_billing_updated_at before update on billing.organization_billing for each row execute function public.set_timestamp_updated_at();

-- RLS: admins/fleet_managers manage; members read own (consolidated policy)
drop policy if exists org_billing_select on billing.organization_billing;
create policy org_billing_select on billing.organization_billing
  for select using (
    exists (
      select 1 from public.organization_members m
      where m.org_id = organization_billing.org_id
        and m.user_id = (select auth.uid())
    )
  );

drop policy if exists org_billing_manage on billing.organization_billing;
create policy org_billing_manage on billing.organization_billing
  for insert with check (
    exists (
      select 1 from public.organization_members m
      where m.org_id = organization_billing.org_id
        and m.user_id = (select auth.uid())
        and m.role in ('admin','fleet_manager')
    )
  );

drop policy if exists org_billing_update on billing.organization_billing;
create policy org_billing_update on billing.organization_billing
  for update using (
    exists (
      select 1 from public.organization_members m
      where m.org_id = organization_billing.org_id
        and m.user_id = (select auth.uid())
        and m.role in ('admin','fleet_manager')
    )
  );

-- Helper functions (moved to billing schema and made stable)
create or replace function billing.fn_current_plan(p_org uuid)
returns billing.plan_tier language sql stable as $$
  select coalesce((select plan from billing.organization_billing where org_id = p_org), 'free'::billing.plan_tier)
$$;
COMMENT ON FUNCTION billing.fn_current_plan(uuid) IS 'Returns the current billing plan for a given organization.';

create or replace function billing.fn_limit(p_org uuid, p_key text, p_default int)
returns int language sql stable as $$
  select coalesce((select (limits ->> p_key)::int from billing.organization_billing where org_id = p_org), p_default)
$$;
COMMENT ON FUNCTION billing.fn_limit(uuid, text, int) IS 'Retrieves a specific usage limit from the organization''s limits JSONB column, with a default fallback.';

-- 1) Usage metering
create table if not exists billing.usage_counters (
  org_id uuid not null references public.organizations(id) on delete cascade,
  day date not null,
  metric text not null, -- e.g., positions, events, alerts
  count bigint not null default 0,
  primary key (org_id, day, metric)
);
COMMENT ON TABLE billing.usage_counters IS 'Stores daily usage counts for various metrics, such as telemetry positions or geofence events.';

alter table billing.usage_counters enable row level security;
-- RLS policies for usage counters
drop policy if exists usage_read on billing.usage_counters;
create policy usage_read on billing.usage_counters for select using (org_id = coalesce(public.current_org_id(), ((SELECT auth.jwt()) ->> 'org_id')::uuid));
drop policy if exists usage_upsert_admins on billing.usage_counters;
create policy usage_upsert_admins on billing.usage_counters for insert with check (org_id = coalesce(public.current_org_id(), ((SELECT auth.jwt()) ->> 'org_id')::uuid));
drop policy if exists usage_update_admins on billing.usage_counters;
create policy usage_update_admins on billing.usage_counters for update using (org_id = coalesce(public.current_org_id(), ((SELECT auth.jwt()) ->> 'org_id')::uuid));

-- Increment counter helper (called from RPCs or triggers)
create or replace function billing.fn_meter_event(p_org uuid, p_metric text, p_inc int default 1)
returns void as $$
begin
  insert into billing.usage_counters(org_id, day, metric, count)
  values (p_org, current_date, p_metric, p_inc)
  on conflict (org_id, day, metric)
  do update set count = billing.usage_counters.count + excluded.count;
end; $$ language plpgsql;
COMMENT ON FUNCTION billing.fn_meter_event(uuid, text, int) IS 'Atomically increments a usage counter for a given organization, metric, and day.';

-- Public RPC wrapper that uses JWT org_id
create or replace function public.fn_meter_event_rpc(p_metric text, p_inc int default 1)
returns void as $$
begin
  perform billing.fn_meter_event(coalesce(public.current_org_id(), ((SELECT auth.jwt()) ->> 'org_id')::uuid), p_metric, p_inc);
end; $$ language plpgsql security definer;
COMMENT ON FUNCTION public.fn_meter_event_rpc(text, int) IS 'RPC wrapper for fn_meter_event, allowing a user to increment their own organization''s usage counters.';

revoke all on function public.fn_meter_event_rpc(text,int) from public;
grant execute on function public.fn_meter_event_rpc(text,int) to authenticated;

-- 1a) Instrument telemetry ingestion: increment positions/day and enforce per-plan rate/window
-- Adds a guard in existing fn_ingest_truck_position (if present). Create a wrapper to call the base fn.
DO $ingest_wrapper$ BEGIN
  PERFORM 1 FROM pg_proc WHERE proname = 'fn_ingest_truck_position';
  IF FOUND THEN
    -- Create a guarded wrapper that checks plan limits then calls base fn.
    create or replace function public.fn_ingest_truck_position_guarded(
      p_truck_id uuid,
      p_lat double precision,
      p_lng double precision,
      p_speed_kph double precision,
      p_heading_deg double precision,
      p_odometer_km double precision,
      p_gps_ts timestamptz,
      p_source text
    ) returns void as $fn$
    declare
      v_org uuid;
      v_limit int;
      v_count bigint;
    begin
      -- Resolve org/carrier from truck
      select t.carrier_id into v_org from public.trucks t where t.id = p_truck_id;
      if v_org is null then
        raise exception 'truck not found';
      end if;
      -- Evaluate daily limit by plan
      v_limit := case billing.fn_current_plan(v_org)
        when 'free' then 20000
        when 'pro' then 200000
        when 'enterprise' then 2000000
      end;
      -- Current count
      select count from billing.usage_counters where org_id = v_org and day = current_date and metric = 'positions' into v_count;
      if coalesce(v_count,0) >= v_limit then
        raise exception 'positions/day limit reached for plan %', billing.fn_current_plan(v_org);
      end if;
      -- Proceed with base ingest
      perform public.fn_ingest_truck_position(p_truck_id, p_lat, p_lng, p_speed_kph, p_heading_deg, p_odometer_km, p_gps_ts, p_source);
      -- Meter one event
      perform billing.fn_meter_event(v_org, 'positions', 1);
    end;
    $fn$ language plpgsql security definer;
    revoke all on function public.fn_ingest_truck_position_guarded(uuid,double precision,double precision,double precision,double precision,double precision,timestamptz,text) from public;
    grant execute on function public.fn_ingest_truck_position_guarded(uuid,double precision,double precision,double precision,double precision,double precision,timestamptz,text) to authenticated;
  END IF;
END $ingest_wrapper$;

-- 2) Reporting aggregates
-- Daily per-truck stats: miles, driving_time_min, idle_time_min based on truck_positions deltas
-- Simplified estimations using odometer and speed thresholds
create materialized view if not exists public.mv_daily_truck_stats as
with pos as (
  select p.truck_id, p.gps_ts::date as day,
         p.odometer_km,
         p.speed_kph,
         p.gps_ts
  from public.truck_positions p
),
ordered as (
  select *, lag(odometer_km) over (partition by truck_id, day order by gps_ts) as prev_odo,
            lag(gps_ts) over (partition by truck_id, day order by gps_ts) as prev_ts
  from pos
)
select truck_id,
       day,
       max(odometer_km) - min(odometer_km) as km_traveled,
       sum(case when speed_kph is not null and speed_kph > 2 then extract(epoch from (gps_ts - prev_ts))/60.0 else 0 end) as driving_minutes,
       sum(case when speed_kph is not null and speed_kph <= 2 then extract(epoch from (gps_ts - prev_ts))/60.0 else 0 end) as idle_minutes
from ordered
where prev_ts is not null
group by truck_id, day;

COMMENT ON MATERIALIZED VIEW public.mv_daily_truck_stats IS 'Aggregates daily driving and idle time metrics for each truck.';
create index if not exists idx_mv_truck_stats_day on public.mv_daily_truck_stats(day);
-- Add UNIQUE index (instead of PK) for concurrent refresh
DO $mv_truck_pk$
BEGIN
  BEGIN
    EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_daily_truck_stats ON public.mv_daily_truck_stats(truck_id, day)';
  EXCEPTION WHEN others THEN
    NULL;
  END;
END $mv_truck_pk$;

-- Daily per-org aggregates combining trucks and loads (on-time, exceptions as placeholders)
create materialized view if not exists public.mv_daily_org_stats as
with ts as (
  select t.carrier_id as org_id, s.*
  from public.trucks t
  join public.mv_daily_truck_stats s on s.truck_id = t.id
), lt as (
  select l.org_id as org_id, l.status, l.planned_dropoff_at::date as day,
         (case when l.actual_dropoff_at is not null and l.planned_dropoff_at is not null and l.actual_dropoff_at <= l.planned_dropoff_at then 1 else 0 end) as on_time_flag
  from public.loads l
)
select coalesce(ts.org_id, lt.org_id) as org_id,
       coalesce(ts.day, lt.day) as day,
       sum(coalesce(ts.km_traveled,0)) as km_traveled,
       sum(coalesce(ts.driving_minutes,0)) as driving_minutes,
       sum(coalesce(ts.idle_minutes,0)) as idle_minutes,
       sum(coalesce(lt.on_time_flag,0)) as on_time_deliveries,
       count(lt.status) filter (where lt.status = 'delivered') as deliveries
from ts
full outer join lt on lt.org_id = ts.org_id and lt.day = ts.day
group by coalesce(ts.org_id, lt.org_id), coalesce(ts.day, lt.day);

COMMENT ON MATERIALIZED VIEW public.mv_daily_org_stats IS 'Provides a high-level summary of daily metrics for each organization, including vehicle telemetry and load delivery performance.';
create index if not exists idx_mv_org_stats_day on public.mv_daily_org_stats(day);
-- Add UNIQUE index (instead of PK) for concurrent refresh
DO $mv_org_pk$
BEGIN
  BEGIN
    EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_daily_org_stats ON public.mv_daily_org_stats(org_id, day)';
  EXCEPTION WHEN others THEN
    NULL;
  END;
END $mv_org_pk$;

-- On-time performance detail view (non-materialized for drilldown)
create or replace view public.v_on_time_performance as
select l.id as load_id, l.org_id as org_id, l.reference_number,
       l.planned_pickup_at, l.actual_pickup_at,
       l.planned_dropoff_at, l.actual_dropoff_at,
       (case when l.actual_dropoff_at is not null and l.planned_dropoff_at is not null and l.actual_dropoff_at <= l.planned_dropoff_at then true else false end) as on_time
from public.loads l
where l.status in ('en_route','delivered');

-- 3) Refresh machinery
-- Prefer pg_cron if available; otherwise, refresh via Supabase Scheduled Functions calling this RPC.
create or replace function billing.fn_refresh_reporting()
returns void as $$
begin
  refresh materialized view concurrently public.mv_daily_truck_stats;
  refresh materialized view concurrently public.mv_daily_org_stats;
end; $$ language plpgsql security definer;
COMMENT ON FUNCTION billing.fn_refresh_reporting() IS 'Refreshes the materialized views concurrently to provide up-to-date reporting data.';
revoke all on function billing.fn_refresh_reporting() from public;
grant execute on function billing.fn_refresh_reporting() to service_role; -- usually invoked by server job

-- Optional: Create a cron job (requires pg_cron extension enabled by Supabase team)
DO $cron$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.schedule(
      'refresh_reporting_nightly',
      '5 3 * * *',
      'CALL billing.fn_refresh_reporting();'
    );
  END IF;
END $cron$;

-- 4) RLS for materialized views: Postgres does not support RLS on MV; expose via security definer views
create or replace view public.v_daily_truck_stats as
select s.truck_id, s.day, s.km_traveled, s.driving_minutes, s.idle_minutes
from public.mv_daily_truck_stats s
where exists (
  select 1 from public.trucks t where t.id = s.truck_id and t.carrier_id = coalesce(public.current_org_id(), ((SELECT auth.jwt()) ->> 'org_id')::uuid)
);
COMMENT ON VIEW public.v_daily_truck_stats IS 'A security-definer view that provides row-level security for the daily truck stats materialized view.';

create or replace view public.v_daily_org_stats as
select org_id, day, km_traveled, driving_minutes, idle_minutes, on_time_deliveries, deliveries
from public.mv_daily_org_stats where org_id = coalesce(public.current_org_id(), ((SELECT auth.jwt()) ->> 'org_id')::uuid);
COMMENT ON VIEW public.v_daily_org_stats IS 'A security-definer view that provides row-level security for the daily organization stats materialized view.';

-- 5) Limits examples for geofences count enforcement (if geofences exist)
DO $geofence$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='geofences') THEN
    -- Create a check function used in RLS policies: deny insert if over limit
    CREATE OR REPLACE FUNCTION billing.fn_check_geofence_limit() RETURNS boolean AS $body$
    DECLARE
      v_org uuid;
      v_limit int;
      v_cnt bigint;
    BEGIN
      v_org := coalesce(public.current_org_id(), ((SELECT auth.jwt()) ->> 'org_id')::uuid);
      v_limit := case billing.fn_current_plan(v_org)
        when 'free' then 5
        when 'pro' then 100
        when 'enterprise' then 1000
      end;
      SELECT count(*) INTO v_cnt FROM public.geofences g WHERE g.carrier_id = v_org;
      IF v_cnt >= v_limit THEN RETURN false; END IF;
      RETURN true;
    END; $body$ LANGUAGE plpgsql STABLE;
    COMMENT ON FUNCTION billing.fn_check_geofence_limit() IS 'Checks if an organization is at its geofence creation limit based on their billing plan.';

    -- Add or replace policy to use the check on insert
    DROP POLICY IF EXISTS geofences_tenant_insert ON public.geofences;
    CREATE POLICY geofences_tenant_insert ON public.geofences
      FOR INSERT WITH CHECK (
        coalesce(public.current_org_id(), ((SELECT auth.jwt()) ->> 'org_id')::uuid) = carrier_id AND billing.fn_check_geofence_limit()
      );
  END IF;
END $geofence$;
