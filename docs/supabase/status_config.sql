-- Status Config schema (v1)
-- Location: docs/supabase/status_config.sql

create table if not exists public.status_config (
  id boolean primary key default true, -- singleton row trick
  read_only_mode boolean not null default false,
  state text not null default 'nominal' check (state in ('nominal','degraded','incident')),
  message text,
  updated_at timestamptz not null default now()
);

-- Ensure exactly one row exists
insert into public.status_config(id, read_only_mode, state, message)
values (true, false, 'nominal', null)
on conflict (id) do nothing;
