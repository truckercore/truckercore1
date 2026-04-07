-- 20250924_e2e_artifacts.sql
-- Purpose: E2E artifacts schema for Playwright/k6/Deno/Flutter runs and supporting RLS.
-- Safe to re-run (idempotent) for Supabase.

-- Stores latest auth storage blob per env/project for Playwright
create table if not exists public.e2e_auth_storage (
  id uuid primary key default gen_random_uuid(),
  env text not null default 'local',         -- local|stage|prod|ci
  project text not null default 'web',       -- web|admin|portal
  storage jsonb not null,                    -- Playwright storageState JSON
  updated_at timestamptz not null default now(),
  unique (env, project)
);
alter table public.e2e_auth_storage enable row level security;
create policy if not exists e2e_auth_storage_read on public.e2e_auth_storage for select to authenticated using (true);
-- writes allowed for service role (CI) only
revoke insert, update, delete on public.e2e_auth_storage from authenticated;

-- Track e2e runs (Playwright/k6/Edge/Deno)
create table if not exists public.e2e_runs (
  id uuid primary key default gen_random_uuid(),
  suite text not null,                       -- playwright|k6|deno|flutter
  project text not null,                     -- chromium|firefox|webkit or k6-smoke etc.
  env text not null default 'ci',
  status text not null check (status in ('passed','failed','flaky')),
  specs_total int not null default 0,
  specs_failed int not null default 0,
  duration_ms int not null default 0,
  artifact_url text null,
  created_at timestamptz not null default now()
);
create index if not exists idx_e2e_runs_time on public.e2e_runs (created_at desc);
alter table public.e2e_runs enable row level security;
create policy if not exists e2e_runs_read on public.e2e_runs for select to authenticated using (true);
revoke insert, update, delete on public.e2e_runs from authenticated;

-- Network fence allowlist for CI observability (optional)
create table if not exists public.e2e_network_allow (
  id uuid primary key default gen_random_uuid(),
  pattern text not null,                     -- glob/regex string
  note text null,
  created_at timestamptz not null default now()
);
alter table public.e2e_network_allow enable row level security;
create policy if not exists e2e_net_allow_read on public.e2e_network_allow for select to authenticated using (true);
revoke insert, update, delete on public.e2e_network_allow from authenticated;

-- Test DB lifecycle logs
create table if not exists public.test_db_runs (
  id uuid primary key default gen_random_uuid(),
  env text not null default 'ci',
  script text not null,                      -- reset_and_seed.sql etc.
  status text not null check (status in ('ok','error')),
  duration_ms int not null default 0,
  error text null,
  created_at timestamptz not null default now()
);
create index if not exists idx_test_db_runs_time on public.test_db_runs (created_at desc);
alter table public.test_db_runs enable row level security;
create policy if not exists test_db_runs_read on public.test_db_runs for select to authenticated using (true);
revoke insert, update, delete on public.test_db_runs from authenticated;

-- Remediation: third-party mock calls captured (optional)
create table if not exists public.mock_calls (
  id bigserial primary key,
  source text not null,                      -- dot511|noaa|custom
  path text not null,
  ts timestamptz not null default now(),
  payload jsonb not null
);
create index if not exists idx_mock_calls_time on public.mock_calls (ts desc);
