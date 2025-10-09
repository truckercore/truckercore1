begin;

create type roadside_status as enum ('new','assigned','enroute','completed','canceled');

create table if not exists roadside_providers (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  name text not null,
  services text[] not null default '{}', -- e.g. {'tow','tire','fuel'}
  lat double precision,
  lng double precision,
  radius_km numeric default 50.0,
  created_at timestamptz default now()
);

create table if not exists roadside_requests (
  id uuid primary key default gen_random_uuid(),
  requester_user_id uuid references auth.users(id) on delete set null,
  org_id uuid, -- fleet org if any
  lat double precision not null,
  lng double precision not null,
  service_type text not null check (service_type in ('tow','tire','fuel','jump','unlock')),
  status roadside_status not null default 'new',
  created_at timestamptz default now()
);

create table if not exists roadside_assignments (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references roadside_requests(id) on delete cascade,
  provider_id uuid not null references roadside_providers(id) on delete cascade,
  tech_id text,
  assigned_at timestamptz default now(),
  unique (request_id, provider_id)
);

-- indexes
create index if not exists idx_roadside_req_status_created on roadside_requests (status, created_at desc);
create index if not exists idx_roadside_prov_loc on roadside_providers (lat, lng);

-- RLS
alter table roadside_providers  enable row level security;
alter table roadside_requests   enable row level security;
alter table roadside_assignments enable row level security;

-- Providers: org-scoped read/write
create policy roadside_providers_org_rw on roadside_providers
for all using (org_id::text = coalesce((select org_id from v_claims), ''))
with check (org_id::text = coalesce((select org_id from v_claims), ''));

-- Requester: read own requests; insert allowed to authenticated
create policy roadside_requests_self_read on roadside_requests
for select using (requester_user_id = auth.uid());

create policy roadside_requests_insert_self on roadside_requests
for insert with check (requester_user_id = auth.uid());

-- Assignments: provider org can read rows referencing their provider_id
create policy roadside_assignments_provider_read on roadside_assignments
for select using (provider_id in (select id from roadside_providers where org_id::text = coalesce((select org_id from v_claims), '')));

-- service_role may write all (edge functions)
grant select, insert, update, delete on roadside_requests, roadside_assignments, roadside_providers to service_role;

comment on table roadside_requests is 'Roadside assistance requests with minimal PII';
comment on table roadside_providers is 'Providers with service catalog and radius';

commit;
