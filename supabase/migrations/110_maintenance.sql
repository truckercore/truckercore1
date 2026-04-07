-- Simple maintenance scaffolding
create table if not exists public.maintenance_tasks (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id),
  vehicle_id uuid not null references public.vehicles(id),
  kind text not null,
  due_miles int,
  due_date date,
  notes text,
  completed boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists idx_maint_org_vehicle on public.maintenance_tasks(org_id, vehicle_id);
alter table public.maintenance_tasks enable row level security;
create policy maintenance_org_rw on public.maintenance_tasks
for all to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''))
with check (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
