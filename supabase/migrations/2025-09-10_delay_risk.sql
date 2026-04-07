-- Delay Risk MVP: facility dwell priors, cache, and seeds
-- Tables: facility_dwell_stats, delay_risk_cache
-- Notes: RLS uses org_id = jwt.app_org_id; service functions can bypass.

-- 1) facility_dwell_stats: priors per facility and hour bucket
create table if not exists public.facility_dwell_stats (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  facility_id text not null,
  hour_bucket int not null check (hour_bucket between 0 and 23),
  dwell_median_minutes int not null check (dwell_median_minutes >= 0),
  dwell_p75_minutes int not null check (dwell_p75_minutes >= 0),
  updated_at timestamptz not null default now(),
  unique (org_id, facility_id, hour_bucket)
);
create index if not exists idx_facility_dwell_org_fac on public.facility_dwell_stats (org_id, facility_id);
alter table public.facility_dwell_stats enable row level security;
create policy facility_dwell_read_org on public.facility_dwell_stats for select to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
-- service managed upserts elsewhere
create policy facility_dwell_service_only on public.facility_dwell_stats for all to authenticated using (false) with check (false);

-- 2) delay_risk_cache: latest computed risk per load (or candidate)
create table if not exists public.delay_risk_cache (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  load_id text not null,
  stop_pair text null, -- e.g., 'pickup-delivery' or facility pair key
  on_time_prob numeric not null check (on_time_prob between 0 and 1),
  late_risk_score int not null check (late_risk_score between 0 and 100),
  risk_bucket text not null check (risk_bucket in ('low','medium','high')),
  late_risk_reason text not null,
  mitigations jsonb not null default '[]'::jsonb,
  freshness_seconds int not null,
  confidence numeric not null check (confidence between 0 and 1),
  computed_at timestamptz not null default now(),
  unique (org_id, load_id, coalesce(stop_pair,''))
);
create index if not exists idx_delay_risk_org_load on public.delay_risk_cache (org_id, load_id);
alter table public.delay_risk_cache enable row level security;
create policy delay_risk_read_org on public.delay_risk_cache for select to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
-- writes are service-managed by function/worker
create policy delay_risk_service_only on public.delay_risk_cache for all to authenticated using (false) with check (false);

-- 3) Optional: store last status code on outbox for observability (if not present)
alter table if exists public.event_outbox add column if not exists last_status_code int;

-- 4) Minimal seed for staging/demo (5–10 facilities and 3 cache rows)
-- Guard with DO block so it is safe to re-run
DO $$
DECLARE demo_org uuid := '00000000-0000-0000-0000-000000000000'::uuid; -- replace in staging with real org id if desired
BEGIN
  -- Seed a handful of facilities with plausible dwell medians
  perform 1 from public.facility_dwell_stats where org_id = demo_org;
  IF NOT FOUND THEN
    insert into public.facility_dwell_stats(org_id, facility_id, hour_bucket, dwell_median_minutes, dwell_p75_minutes) values
      (demo_org, 'DC-1', 8, 60, 90),
      (demo_org, 'DC-1', 17, 90, 130),
      (demo_org, 'DC-7', 9, 75, 110),
      (demo_org, 'DC-7', 16, 105, 150),
      (demo_org, 'YARD-3', 7, 30, 50),
      (demo_org, 'PORT-A', 10, 120, 180),
      (demo_org, 'PORT-A', 15, 150, 210);
  END IF;

  -- Seed a few cache rows so UI sees something on first mount
  perform 1 from public.delay_risk_cache where org_id = demo_org;
  IF NOT FOUND THEN
    insert into public.delay_risk_cache(org_id, load_id, stop_pair, on_time_prob, late_risk_score, risk_bucket, late_risk_reason, mitigations, freshness_seconds, confidence)
    values
      (demo_org, 'LOAD-001', 'pickup-delivery', 0.82, 28, 'medium', 'Traffic + dwell at DC-7', '[{"label":"Leave 45m earlier","action":"shift_departure","delta_minutes":45}]'::jsonb, 120, 0.6),
      (demo_org, 'LOAD-002', 'pickup-delivery', 0.94, 12, 'low', 'Normal conditions', '[]'::jsonb, 180, 0.7),
      (demo_org, 'LOAD-003', 'pickup-delivery', 0.61, 55, 'high', 'Severe weather on route', '[{"label":"Alternate window","action":"alternate_window","delta_minutes":30}]'::jsonb, 90, 0.5);
  END IF;
END$$;

COMMENT ON TABLE public.facility_dwell_stats IS 'Per-facility dwell priors by hour (median/p75) for delay risk heuristics';
COMMENT ON TABLE public.delay_risk_cache IS 'Latest computed delay risk per (org, load, stop_pair) for quick reads and batch UI refresh';
