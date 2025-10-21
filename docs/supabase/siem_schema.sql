-- SIEM Streaming schema (v1)
-- Location: docs/supabase/siem_schema.sql
-- Defines per-tenant destinations and an at-least-once queue consumed by functions/siem_push.

create table if not exists public.siem_destinations (
  org_id uuid primary key,
  enabled boolean not null default false,
  endpoint text not null,
  secret text not null,
  pii_mask_enabled boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.siem_queue (
  id bigserial primary key,
  org_id uuid not null,
  payload jsonb not null,
  attempt integer not null default 0,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_siem_queue_time on public.siem_queue(created_at asc);
create index if not exists idx_siem_queue_org_time on public.siem_queue(org_id, created_at asc);

-- RLS placeholders (enable per project policy)
-- alter table public.siem_destinations enable row level security;
-- alter table public.siem_queue enable row level security;
-- Policies would restrict by org_id and service role where appropriate.
