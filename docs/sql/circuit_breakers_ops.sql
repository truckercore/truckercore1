-- Operationalize circuit breakers with stateful schema and an alerting view

-- Ensure table exists with desired columns
create table if not exists public.circuit_breakers (
  key text primary key,
  state text not null check (state in ('closed','open','half_open','tripped')),
  reason text,
  tripped_at timestamptz,
  updated_at timestamptz not null default now()
);

-- Backward-compatible alterations (if an older shape exists)
alter table public.circuit_breakers
  add column if not exists state text;

-- Set default state for rows missing it
update public.circuit_breakers set state = coalesce(state, 'closed') where state is null;

-- Enforce check constraint if missing (Postgres doesn't support IF NOT EXISTS on constraints easily)
-- This will try to add; if exists, ignore at migration time.
do $$ begin
  begin
    alter table public.circuit_breakers add constraint circuit_breakers_state_check
      check (state in ('closed','open','half_open','tripped'));
  exception when duplicate_object then
    null;
  end;
end $$;

alter table public.circuit_breakers
  add column if not exists updated_at timestamptz not null default now();

-- View for alerting/monitoring
create or replace view public.v_circuit_breakers as
select key, state, reason, tripped_at, updated_at
from public.circuit_breakers;
