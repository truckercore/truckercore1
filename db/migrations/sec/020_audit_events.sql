begin;

create table if not exists public.audit_events (
  id bigserial primary key,
  actor uuid,
  action text not null,
  entity text not null,
  entity_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.audit_events enable row level security;

-- Org-scoped reads can be added later if entity/entity_id are org-linked; default: no public writes
revoke insert, update, delete on public.audit_events from authenticated;

commit;
