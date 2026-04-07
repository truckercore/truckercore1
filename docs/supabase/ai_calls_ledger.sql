-- AI Calls Ledger schema (v1)
-- Tracks AI invocations for accurate usage and cost reporting.
-- Location: docs/supabase/ai_calls_ledger.sql

create table if not exists public.ai_calls_ledger (
  id bigserial primary key,
  org_id uuid not null,
  action text not null, -- summary|explain|planner|negotiation|compliance (or feature)
  model text,
  source text not null default 'live' check (source in ('live','cache')),
  prompt_tokens integer not null default 0,
  completion_tokens integer not null default 0,
  total_tokens integer not null default 0,
  cost_cents integer not null default 0,
  trace_id text,
  created_at timestamptz not null default now()
);
create index if not exists idx_ai_ledger_org_time on public.ai_calls_ledger(org_id, created_at desc);
create index if not exists idx_ai_ledger_action_time on public.ai_calls_ledger(action, created_at desc);
