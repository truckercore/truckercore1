-- Phase 4 — Analytics & Compliance schema

-- 1.1 analytics_snapshots
create table if not exists public.analytics_snapshots (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  date_bucket date not null,
  scope text not null check (scope in ('fleet','broker')),
  total_loads int not null default 0,
  total_miles numeric(10,1) not null default 0,
  revenue_usd numeric(12,2) not null default 0,
  cost_usd numeric(12,2) not null default 0,
  avg_ppm numeric(8,4),
  on_time_pct numeric(5,2),
  created_at timestamptz not null default now(),
  unique (org_id, date_bucket, scope)
);
create index if not exists idx_analytics_org_date on public.analytics_snapshots (org_id, date_bucket desc);
alter table public.analytics_snapshots enable row level security;
create policy analytics_snapshots_read on public.analytics_snapshots for select to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

-- 1.2 ownerop_expenses
create table if not exists public.ownerop_expenses (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  user_id uuid not null,
  load_id uuid null,
  category text not null check (category in ('fuel','tolls','repairs','tires','insurance','permits','parking','detention','lumper','other')),
  amount_usd numeric(12,2) not null check (amount_usd >= 0),
  miles numeric(8,1) null,
  notes text,
  incurred_on date not null,
  created_at timestamptz not null default now()
);
create index if not exists idx_ownerop_expenses_user_date on public.ownerop_expenses (user_id, incurred_on desc);
alter table public.ownerop_expenses enable row level security;
create policy ownerop_expenses_rw on public.ownerop_expenses
for all to authenticated
using (user_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'sub','')
   and org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''))
with check (user_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'sub','')
   and org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

-- 1.3 hos_logs + inspection_reports
create table if not exists public.hos_logs (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  driver_user_id uuid not null,
  start_time timestamptz not null,
  end_time timestamptz not null,
  status text not null check (status in ('off','sleeper','driving','on')),
  source text not null default 'manual' check (source in ('manual','eld_certified')),
  eld_provider text null,
  created_at timestamptz not null default now()
);
create index if not exists idx_hos_driver_time on public.hos_logs (driver_user_id, start_time desc);
alter table public.hos_logs enable row level security;
create policy hos_logs_read_driver on public.hos_logs for select to authenticated
using (
  org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','') and
  (
    driver_user_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'sub','')
    or (coalesce(current_setting('request.jwt.claims', true)::json->'app_roles','[]'::json) ? 'fleet_manager')
  )
);

create table if not exists public.inspection_reports (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  driver_user_id uuid not null,
  vehicle_id uuid not null,
  type text not null check (type in ('pre_trip','post_trip')),
  defects jsonb not null default '[]'::jsonb,
  certified_safe boolean not null default true,
  signed_at timestamptz not null,
  created_at timestamptz not null default now()
);
create index if not exists idx_inspection_driver_time on public.inspection_reports (driver_user_id, signed_at desc);
alter table public.inspection_reports enable row level security;
create policy inspection_read_org on public.inspection_reports for select to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
create policy inspection_insert_driver on public.inspection_reports for insert to authenticated
with check (
  org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','') and
  driver_user_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'sub','')
);

-- 1.4 alerts_events
create table if not exists public.alerts_events (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  severity text not null check (severity in ('info','warning','critical')),
  code text not null,
  payload jsonb not null,
  triggered_at timestamptz not null default now(),
  acknowledged boolean not null default false,
  acknowledged_by uuid null,
  acknowledged_at timestamptz null
);
create index if not exists idx_alerts_org_time on public.alerts_events (org_id, triggered_at desc);
alter table public.alerts_events enable row level security;
create policy alerts_read_org on public.alerts_events for select to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
create policy alerts_ack_org on public.alerts_events for update to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''))
with check (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
