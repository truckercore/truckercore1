-- docs/sql/drift_ticket_guard.sql
create table if not exists public.drift_events(
  id bigserial primary key,
  at timestamptz not null default now(),
  tenant uuid,
  drift_key text not null,
  payload jsonb not null default '{}'::jsonb
);

create unique index if not exists uq_drift_window
on public.drift_events (tenant, drift_key, date_trunc('hour', at));
