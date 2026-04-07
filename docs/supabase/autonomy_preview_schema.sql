-- Autonomy Preview Schema (v1)
-- Tables to support daily preview generation, decisions, and auditability

create table if not exists public.autonomous_previews (
  id bigserial primary key,
  org_id uuid not null,
  day date not null,
  items jsonb not null, -- array of preview items {type, load_id, confidence, why[], constraints}
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  prepared_at timestamptz,
  decided_at timestamptz,
  decided_by text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(org_id, day)
);
create index if not exists idx_autonomy_prev_org_day on public.autonomous_previews(org_id, day desc);

create table if not exists public.autonomous_actions_log (
  id bigserial primary key,
  org_id uuid not null,
  preview_id bigint references public.autonomous_previews(id) on delete cascade,
  action_type text not null, -- e.g., 'request', 'prepare_counter', 'rollback'
  load_id uuid,
  confidence numeric,
  why text[],
  constraints jsonb,
  idem text not null,
  proposed boolean,
  approved boolean,
  applied boolean,
  decided_at timestamptz,
  applied_at timestamptz,
  error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(org_id, idem)
);
create index if not exists idx_autonomy_actions_org_preview on public.autonomous_actions_log(org_id, preview_id);
create index if not exists idx_autonomy_actions_org_time on public.autonomous_actions_log(org_id, created_at desc);
