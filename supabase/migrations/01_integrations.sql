-- 01_integrations.sql
-- Creates core integrations table
create table if not exists public.integrations (
  id uuid primary key default gen_random_uuid(),
  provider text not null,            -- e.g., 'tms', 'quickbooks', 'xero', 'google_calendar'
  org_id uuid,                       -- nullable if single-tenant demo
  status text not null default 'disconnected', -- 'connected' | 'disconnected' | 'error'
  settings jsonb default '{}'::jsonb,
  last_sync_at timestamptz,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Indexed by org/provider
create index if not exists idx_integrations_org on public.integrations(org_id);
create index if not exists idx_integrations_provider on public.integrations(provider);
