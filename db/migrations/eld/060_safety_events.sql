begin;

create table if not exists public.safety_events (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null,
  vehicle_id uuid,
  org_id uuid not null,
  event_type text not null check (event_type in ('fatigue','distraction','coaching')),
  confidence numeric check (confidence >= 0 and confidence <= 1),
  captured_at timestamptz not null default now(),
  source text,
  metadata jsonb not null default '{}'::jsonb
);

alter table public.safety_events enable row level security;

-- RLS: driver can see own events
create policy if not exists safety_events_driver_read on public.safety_events
for select to authenticated
using (driver_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'sub',''));

-- RLS: org managers/users can read by org scope
create policy if not exists safety_events_org_read on public.safety_events
for select to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

commit;