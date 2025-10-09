begin;

create table if not exists public.shippers (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  company_name text,
  contact_email text,
  created_at timestamptz not null default now()
);

create table if not exists public.brokers (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  company_name text,
  contact_email text,
  created_at timestamptz not null default now()
);

alter table public.shippers enable row level security;
alter table public.brokers enable row level security;

create policy if not exists shippers_read_org on public.shippers
for select to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

create policy if not exists brokers_read_org on public.brokers
for select to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

commit;
