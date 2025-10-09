-- 001_core_compliance.sql

-- 0) Prereqs
create extension if not exists pgcrypto;
create extension if not exists postgis;

-- 1) Tenancy
create table if not exists public.orgs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  plan text not null default 'free'
);

create table if not exists public.profiles (
  id uuid primary key,                         -- equals auth.users.id
  org_id uuid not null references public.orgs(id) on delete cascade,
  role text not null check (role in ('driver','owner_op','dispatcher','broker','admin')),
  app_is_premium boolean not null default false
);

-- 2) Compliance matrix per region
create table if not exists public.compliance_matrix (
  id uuid primary key default gen_random_uuid(),
  region text not null,
  topic text not null,                         -- 'HOS','IFTA','DVIR','Privacy'
  policy jsonb not null,
  updated_at timestamptz not null default now(),
  unique(region, topic)
);

-- 3) ELD/HOS raw logs (retain raw)
create table if not exists public.hos_raw (
  id bigint generated always as identity primary key,
  org_id uuid not null references public.orgs(id) on delete cascade,
  driver_id uuid not null references public.profiles(id) on delete cascade,
  event_time timestamptz not null,
  event_type text not null,                    -- ON, OFF, SB, D, YM, PC
  payload jsonb not null
);
create index if not exists idx_hos_raw_org_driver_time on public.hos_raw (org_id, driver_id, event_time desc);

-- 4) DVIR
create table if not exists public.dvir_reports (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id) on delete cascade,
  driver_id uuid not null references public.profiles(id) on delete cascade,
  vehicle_id text not null,
  status text not null check (status in ('defects_found','no_defects','repaired')),
  defects jsonb not null default '[]'::jsonb,
  signed_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

-- 5) IFTA borders
create table if not exists public.ifta_borders (
  id serial primary key,
  state_code text not null,
  geom geography(multipolygon, 4326) not null
);

-- 6) Telemetry + confidence
create table if not exists public.telemetry_points (
  id bigint generated always as identity primary key,
  org_id uuid not null references public.orgs(id) on delete cascade,
  driver_id uuid not null references public.profiles(id) on delete cascade,
  ts timestamptz not null,
  lat double precision not null,
  lng double precision not null,
  speed_kph double precision,
  source text not null default 'device',       -- device, backfill, partner
  confidence real not null default 0.9
);
create index if not exists idx_tp_org_driver_time on public.telemetry_points (org_id, driver_id, ts desc);
create index if not exists idx_tp_geom on public.telemetry_points using gist (st_setsrid(st_makepoint(lng,lat),4326));

-- 7) Privacy & retention
create table if not exists public.org_privacy_settings (
  org_id uuid primary key references public.orgs(id) on delete cascade,
  retain_days integer not null default 180,
  driver_privacy_mode boolean not null default false,
  role_visibility jsonb not null default '{"dispatcher":["driver_location","eta"],"broker":["eta"]}'
);

-- 8) Audit log
create table if not exists public.audit_log (
  id bigint generated always as identity primary key,
  org_id uuid references public.orgs(id) on delete set null,
  actor uuid,                                  -- nullable for system/webhooks
  action text not null,
  target text,
  meta jsonb not null default '{}',
  created_at timestamptz not null default now()
);
create index if not exists idx_audit_org_time on public.audit_log (org_id, created_at desc);

-- 9) Webhook idempotency
create table if not exists public.webhook_events (
  id text primary key,                         -- provider event_id
  provider text not null,                      -- 'stripe','maps','ifta'
  received_at timestamptz not null default now(),
  signature_valid boolean not null,
  payload jsonb not null,
  processed boolean not null default false,
  error text
);

-- 10) Usage quotas / FinOps
create table if not exists public.feature_usage (
  id bigint generated always as identity primary key,
  org_id uuid not null references public.orgs(id) on delete cascade,
  feature text not null,                       -- 'maps.tiles','ai.tokens','ingest.points'
  qty numeric not null,
  occurred_at timestamptz not null default now()
);
create index if not exists idx_feature_usage_org_feature_time on public.feature_usage (org_id, feature, occurred_at desc);

create table if not exists public.plan_quotas (
  plan text primary key,                       -- 'free','pro','enterprise'
  quotas jsonb not null                        -- {"maps.tiles":100000,"ai.tokens":2000000}
);

-- 11) Broker-safe view (privacy)
create or replace view public.v_broker_positions as
select tp.org_id,
       tp.driver_id,
       tp.ts,
       case when (select driver_privacy_mode from public.org_privacy_settings s where s.org_id=tp.org_id)
            then null else tp.lat end as lat,
       case when (select driver_privacy_mode from public.org_privacy_settings s where s.org_id=tp.org_id)
            then null else tp.lng end as lng
from public.telemetry_points tp;
grant select on public.v_broker_positions to authenticated;

-- 12) RLS
alter table public.profiles enable row level security;
alter table public.hos_raw enable row level security;
alter table public.dvir_reports enable row level security;
alter table public.telemetry_points enable row level security;
alter table public.audit_log enable row level security;
alter table public.org_privacy_settings enable row level security;

-- Helper to extract org from JWT claims
create or replace function public.current_org_id() returns uuid
language sql stable as $$
  select nullif(coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''), '')::uuid
$$;

-- Profiles: self-read/update
create policy profiles_self on public.profiles
  for select
  using (id = auth.uid());
create policy profiles_self_update on public.profiles
  for update
  using (id = auth.uid())
  with check (id = auth.uid());

-- Telemetry: org isolation
create policy tp_org_rw on public.telemetry_points
  for all to authenticated
  using (org_id = public.current_org_id())
  with check (org_id = public.current_org_id());

-- HOS raw: org isolation
create policy hos_org_rw on public.hos_raw
  for all to authenticated
  using (org_id = public.current_org_id())
  with check (org_id = public.current_org_id());

-- DVIR: org isolation
create policy dvir_org_rw on public.dvir_reports
  for all to authenticated
  using (org_id = public.current_org_id())
  with check (org_id = public.current_org_id());

-- Audit: org read; writes via service role or RPC
create policy audit_org_read on public.audit_log
  for select to authenticated
  using (org_id = public.current_org_id());

-- Privacy settings: org read only
create policy privacy_org_read on public.org_privacy_settings
  for select to authenticated
  using (org_id = public.current_org_id());

-- 13) Retention helper
create or replace function public.purge_old_telemetry()
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.telemetry_points t
   using public.org_privacy_settings s
  where t.org_id=s.org_id and t.ts < now() - (s.retain_days || ' days')::interval;
$$;
revoke all on function public.purge_old_telemetry() from public;
grant execute on function public.purge_old_telemetry() to service_role;

-- 14) Usage sum RPC for quota checks
create or replace function public.sum_usage(p_org uuid, p_feature text)
returns numeric
language sql stable as $$
  select coalesce(sum(qty),0) from public.feature_usage where org_id = p_org and feature = p_feature
$$;
grant execute on function public.sum_usage(uuid,text) to anon, authenticated;

-- Seed plan quotas (optional)
insert into public.plan_quotas(plan, quotas)
values
  ('free', '{"maps.tiles": 100000, "ai.tokens": 2000000, "ingest.points": 500000}'::jsonb),
  ('pro',  '{"maps.tiles": 1000000, "ai.tokens": 10000000, "ingest.points": 5000000}'::jsonb),
  ('enterprise','{"maps.tiles": 10000000, "ai.tokens": 100000000, "ingest.points": 50000000}'::jsonb)
on conflict (plan) do nothing;
