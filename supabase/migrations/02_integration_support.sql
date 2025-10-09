-- 02_integration_support.sql
-- Support tables for integration sync runs and mappings; accounting exports and calendar events

create table if not exists public.integration_sync_runs (
  id uuid primary key default gen_random_uuid(),
  integration_id uuid references public.integrations(id) on delete cascade,
  started_at timestamptz default now(),
  finished_at timestamptz,
  status text not null default 'pending', -- pending|running|success|failed
  error text,
  stats jsonb default '{}'::jsonb
);
create index if not exists idx_sync_runs_integration on public.integration_sync_runs(integration_id);

create table if not exists public.integration_mappings (
  id uuid primary key default gen_random_uuid(),
  integration_id uuid references public.integrations(id) on delete cascade,
  external_id text,
  local_id text,
  kind text, -- e.g., 'customer','invoice','driver'
  created_at timestamptz default now()
);
create index if not exists idx_integration_mappings_integration on public.integration_mappings(integration_id);

create table if not exists public.accounting_exports (
  id uuid primary key default gen_random_uuid(),
  org_id uuid,
  exported_at timestamptz default now(),
  status text not null default 'pending', -- pending|processing|done|failed
  format text default 'csv',
  location text, -- url/path
  error text
);
create index if not exists idx_accounting_exports_org on public.accounting_exports(org_id);

create table if not exists public.calendar_events (
  id uuid primary key default gen_random_uuid(),
  org_id uuid,
  title text not null,
  starts_at timestamptz not null,
  ends_at timestamptz,
  external_id text,
  created_at timestamptz default now()
);
create index if not exists idx_calendar_events_org on public.calendar_events(org_id);
