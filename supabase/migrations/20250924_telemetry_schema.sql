-- 20250924_telemetry_schema.sql
-- Telemetry schema bundle: sessions, GPS samples, GNSS/battery/clock events,
-- prompts, idling, trip segments, data transfer, privacy, metrics, RLS,
-- retention, and SLO views. Designed to be idempotent and compatible with an
-- existing gps_samples table by adding missing columns instead of destructive changes.

-- Enable PostGIS for geography/geometry types
create extension if not exists postgis;

-- ===== Tenancy helper (JWT) =====
create or replace function public.jwt_org_id() returns uuid
language sql stable as $$
  select (current_setting('request.jwt.claims', true)::jsonb->>'app_org_id')::uuid
$$;

-- ===== Sessions =====
create table if not exists public.telemetry_sessions (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  driver_id uuid,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  mode text not null check (mode in ('foreground','background')),
  team_handoff boolean default false,
  meta jsonb
);
create index if not exists telemetry_sessions_org_time_idx on public.telemetry_sessions (org_id, started_at desc);

-- ===== GPS samples =====
-- If table doesn't exist, create with the desired schema. If it exists (legacy),
-- non-destructively add missing columns for forward compatibility.
create table if not exists public.gps_samples (
  session_id uuid not null,
  seq bigint not null,
  observed_at timestamptz not null,
  location geography(Point,4326) not null,
  speed_kph numeric, heading_deg numeric, accuracy_m numeric,
  gnss_state text check (gnss_state in ('good','low','lost')),
  snapped_road_id text,
  snapped_conf numeric check (snapped_conf between 0 and 1),
  source text not null default 'device',
  primary key (session_id, seq)
);
-- Add missing columns in case an earlier simple gps_samples table exists
alter table if exists public.gps_samples
  add column if not exists session_id uuid,
  add column if not exists seq bigint,
  add column if not exists observed_at timestamptz,
  add column if not exists location geography(Point,4326),
  add column if not exists speed_kph numeric,
  add column if not exists heading_deg numeric,
  add column if not exists accuracy_m numeric,
  add column if not exists gnss_state text,
  add column if not exists snapped_road_id text,
  add column if not exists snapped_conf numeric,
  add column if not exists source text;
-- Constrain/checks where possible without breaking legacy rows
alter table if exists public.gps_samples
  add constraint if not exists gps_samples_gnss_state_chk check (gnss_state in ('good','low','lost')),
  add constraint if not exists gps_samples_snapped_conf_chk check (snapped_conf between 0 and 1);
-- Provide a partial unique index to emulate (session_id,seq) uniqueness if no PK
create unique index if not exists gps_samples_session_seq_uniq on public.gps_samples (session_id, seq) where session_id is not null and seq is not null;
-- Helpful indexes
create index if not exists gps_samples_time_idx on public.gps_samples (observed_at desc);
-- Only create GIST if location exists
DO $$
BEGIN
  IF EXISTS (select 1 from information_schema.columns where table_schema='public' and table_name='gps_samples' and column_name='location') THEN
    EXECUTE 'create index if not exists gps_samples_loc_gix on public.gps_samples using gist (location)';
  END IF;
END $$;

-- ===== GNSS health events =====
create table if not exists public.gnss_health_events (
  session_id uuid not null references public.telemetry_sessions(id) on delete cascade,
  observed_at timestamptz not null,
  kind text not null check (kind in ('drift','low_signal','loss')),
  accuracy_m numeric,
  heading_deg numeric,
  inferred boolean default false,
  primary key (session_id, observed_at, kind)
);
create index if not exists gnss_health_time_idx on public.gnss_health_events (observed_at desc);

-- ===== Battery stats =====
create table if not exists public.battery_stats (
  session_id uuid not null references public.telemetry_sessions(id) on delete cascade,
  observed_at timestamptz not null,
  battery_pct numeric check (battery_pct between 0 and 100),
  charging boolean,
  low_power_toggle boolean,
  sampling_profile text,
  primary key (session_id, observed_at)
);
create index if not exists battery_stats_time_idx on public.battery_stats (observed_at desc);

-- ===== Contribution prompts =====
create table if not exists public.contribution_prompts (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  driver_id uuid,
  at timestamptz not null,
  kind text not null check (kind in ('parking','weigh','feedback')),
  location geography(Point,4326),
  corridor_tag text,
  result text check (result in ('accepted','dismissed','ignored')),
  reward_cents int default 0
);
create index if not exists contribution_prompts_org_time_idx on public.contribution_prompts (org_id, at desc);

-- ===== Idling/dwell detection =====
create table if not exists public.idle_events (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  session_id uuid not null references public.telemetry_sessions(id) on delete cascade,
  start_at timestamptz not null,
  end_at timestamptz,
  center geography(Point,4326),
  avg_speed_kph numeric,
  classified_as text check (classified_as in ('yard','stop','unknown')),
  confidence numeric check (confidence between 0 and 1),
  ble_wifi_hint boolean default false
);
create index if not exists idle_events_org_time_idx on public.idle_events (org_id, start_at desc);
create index if not exists idle_events_center_gix on public.idle_events using gist (center);

-- ===== Clock skew events =====
create table if not exists public.clock_skew_events (
  session_id uuid not null references public.telemetry_sessions(id) on delete cascade,
  at timestamptz not null,
  device_offset_ms int not null,
  severity text not null check (severity in ('warn','drop')),
  primary key (session_id, at)
);
create index if not exists clock_skew_time_idx on public.clock_skew_events (at desc);

-- ===== Trip segments =====
create table if not exists public.trip_segments (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.telemetry_sessions(id) on delete cascade,
  seg_index int not null,
  start_at timestamptz not null,
  end_at timestamptz,
  stops jsonb,
  manually_adjusted boolean default false
);
create unique index if not exists trip_segments_unique on public.trip_segments (session_id, seg_index);

-- ===== Data transfer batches =====
create table if not exists public.data_transfer_batches (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.telemetry_sessions(id) on delete cascade,
  sent_at timestamptz not null,
  bytes int not null,
  count_samples int not null,
  network text not null check (network in ('wifi','cell','roaming','offline')),
  compressed boolean default true,
  retries int default 0
);
create index if not exists data_transfer_time_idx on public.data_transfer_batches (sent_at desc);

-- ===== Privacy events =====
create table if not exists public.privacy_events (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  driver_id uuid,
  at timestamptz not null,
  kind text not null check (kind in ('background_on','background_off','pause','reminder','banner_shown')),
  surface text check (surface in ('in_app','tray','notif')),
  acknowledged boolean
);
create index if not exists privacy_events_org_time_idx on public.privacy_events (org_id, at desc);

-- ===== Map clustering metrics =====
create table if not exists public.map_cluster_metrics (
  at timestamptz not null,
  zoom int not null,
  total_points int not null,
  clusters int not null,
  reps int not null,
  ms int not null,
  primary key (at, zoom)
);

-- ===== Guardrail SLO snapshots =====
create table if not exists public.guardrail_metrics (
  at timestamptz primary key default now(),
  sampling_hit_rate numeric,
  eta_p50_ms int,
  eta_p90_ms int,
  battery_drain_pct_per_hr numeric,
  parking_freshness_min int,
  gnss_low_rate numeric,
  clock_skew_rate numeric
);

-- ===== Optional: org-scoped BLE/Wi‑Fi hint table (opt-in) =====
create table if not exists public.ble_wifi_hints (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  label text,
  bssid text,     -- MAC-like identifier for Wi‑Fi AP
  ssid text,      -- Network name
  ble_uuid text,  -- BLE beacon UUID if applicable
  poi_id uuid null, -- optional link to a POI
  created_at timestamptz not null default now(),
  meta jsonb not null default '{}'::jsonb
);
create index if not exists ble_wifi_hints_org_idx on public.ble_wifi_hints(org_id);

-- ===== RLS =====
alter table public.telemetry_sessions enable row level security;
alter table public.gps_samples enable row level security;
alter table public.gnss_health_events enable row level security;
alter table public.battery_stats enable row level security;
alter table public.contribution_prompts enable row level security;
alter table public.idle_events enable row level security;
alter table public.clock_skew_events enable row level security;
alter table public.trip_segments enable row level security;
alter table public.data_transfer_batches enable row level security;
alter table public.privacy_events enable row level security;

-- telemetry_sessions policies (org-scoped)
create policy if not exists t_s_read on public.telemetry_sessions for select using (org_id = jwt_org_id());
create policy if not exists t_s_write on public.telemetry_sessions for insert with check (org_id = jwt_org_id());

-- Create policies for session-scoped tables only if session_id column exists
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['gps_samples','gnss_health_events','battery_stats','idle_events','clock_skew_events','trip_segments','data_transfer_batches']
  LOOP
    IF EXISTS (
      SELECT 1 FROM information_schema.columns c
      WHERE c.table_schema='public' AND c.table_name=t AND c.column_name='session_id'
    ) THEN
      EXECUTE format('create policy if not exists %I_read on public.%I for select using (exists (select 1 from public.telemetry_sessions s where s.id=%I.session_id and s.org_id = jwt_org_id()))', t, t, t);
      EXECUTE format('create policy if not exists %I_insert on public.%I for insert with check (exists (select 1 from public.telemetry_sessions s where s.id=%I.session_id and s.org_id = jwt_org_id()))', t, t, t);
    END IF;
  END LOOP;
END $$;

-- contribution_prompts and privacy_events (org-scoped)
create policy if not exists cpr_read on public.contribution_prompts for select using (org_id = jwt_org_id());
create policy if not exists cpr_write on public.contribution_prompts for insert with check (org_id = jwt_org_id());
create policy if not exists prv_read on public.privacy_events for select using (org_id = jwt_org_id());
create policy if not exists prv_write on public.privacy_events for insert with check (org_id = jwt_org_id());

-- ===== Retention helper (default 30d) =====
create or replace function public.prune_telemetry(days int default 30) returns void
language plpgsql security definer as $$
begin
  delete from public.gps_samples where observed_at < now() - make_interval(days=>days);
  delete from public.gnss_health_events where observed_at < now() - make_interval(days=>days);
  delete from public.battery_stats where observed_at < now() - make_interval(days=>days);
  delete from public.clock_skew_events where at < now() - make_interval(days=>days);
  delete from public.data_transfer_batches where sent_at < now() - make_interval(days=>days);
  delete from public.contribution_prompts where at < now() - make_interval(days=>days);
  delete from public.privacy_events where at < now() - make_interval(days=>days);
  delete from public.idle_events where coalesce(end_at,start_at) < now() - make_interval(days=>days);
end $$;
revoke all on function public.prune_telemetry(int) from public, anon, authenticated;

-- ===== Metrics & SLO views =====
create or replace view public.v_gnss_low_rate as
select s.id as session_id,
       100.0 * (sum(case when e.kind in ('low_signal','loss') then 1 else 0 end)) / nullif(count(*),0) as gnss_low_rate_pct
from public.telemetry_sessions s
left join public.gnss_health_events e on e.session_id = s.id
group by s.id;

create or replace view public.v_sampling_hit_rate as
with minutes as (
  select s.id,
         extract(epoch from coalesce(s.ended_at, now()) - s.started_at)/60.0 as minutes,
         case when s.mode='foreground' then 60.0 else 12.0 end as target_per_min
  from public.telemetry_sessions s
)
select m.id as session_id,
       count(g.*) as actual_points,
       round(m.minutes * m.target_per_min)::int as expected_points,
       100.0 * count(g.*) / nullif(round(m.minutes * m.target_per_min),0) as hit_rate_pct
from minutes m
left join public.gps_samples g on g.session_id = m.id
group by m.id, m.minutes, m.target_per_min;

create or replace view public.v_battery_drain_per_hr as
select b.session_id,
       (max(b.battery_pct) - min(b.battery_pct)) / greatest(extract(epoch from (max(b.observed_at)-min(b.observed_at)))/3600.0, 0.1) as drain_pct_per_hr
from public.battery_stats b
group by b.session_id;

create or replace view public.v_clock_skew_rate as
select s.id as session_id,
       100.0 * sum(case when c.severity='drop' then 1 else 0 end) / nullif(count(c.*),0) as skew_drop_rate_pct
from public.telemetry_sessions s
left join public.clock_skew_events c on c.session_id = s.id
group by s.id;

-- Parking freshness (placeholder; join to your tables if present)
-- create or replace view public.v_parking_freshness_min as
-- select org_id, extract(epoch from (now() - max(observed_at)))/60.0 as freshness_min
-- from public.parking_status p join public.truck_stops t on t.id=p.stop_id group by org_id;

create or replace view public.v_map_cluster_perf as
select zoom,
       percentile_cont(0.95) within group (order by ms) as p95_ms,
       avg(clusters) as avg_clusters,
       avg(reps) as avg_reps
from public.map_cluster_metrics
where at >= now() - interval '1 day'
group by zoom;

create or replace view public.v_guardrails_24h as
select
  avg(vs.hit_rate_pct) as sampling_hit_rate_pct,
  avg(vb.drain_pct_per_hr) as battery_drain_pct_per_hr,
  avg(vg.gnss_low_rate_pct) as gnss_low_rate_pct,
  avg(vc.skew_drop_rate_pct) as clock_skew_drop_rate_pct
from public.telemetry_sessions s
left join public.v_sampling_hit_rate vs on vs.session_id = s.id
left join public.v_battery_drain_per_hr vb on vb.session_id = s.id
left join public.v_gnss_low_rate vg on vg.session_id = s.id
left join public.v_clock_skew_rate vc on vc.session_id = s.id
where s.started_at >= now() - interval '24 hours';
