-- Alerts + HOS (from previous schema)
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

-- Minimal helper for HOS near-limit nudges (consumed by API route)
create or replace function public.hos_driving_hours_24h(org uuid, driver uuid)
returns numeric
language sql
stable
as $$
  with driving as (
    select greatest(start_time, now() - interval '24 hours') as s,
           least(end_time, now()) as e
    from public.hos_logs
    where org_id = org and driver_user_id = driver and status = 'driving'
      and end_time > now() - interval '24 hours'
  )
  select coalesce(sum(extract(epoch from (e - s))) / 3600.0, 0)
  from driving
$$;
grant execute on function public.hos_driving_hours_24h(uuid, uuid) to authenticated;
