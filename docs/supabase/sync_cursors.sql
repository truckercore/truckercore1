-- docs/supabase/sync_cursors.sql
-- Sync cursors table to track per-user incremental sync positions. Idempotent.

create extension if not exists pgcrypto;

create table if not exists public.sync_cursors (
  user_id uuid primary key,
  org_id uuid not null,
  cursor jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.sync_cursors enable row level security;

create or replace function public.jwt_claim(claim text)
returns text stable language sql as $$ select coalesce(current_setting('request.jwt.claims', true)::json->>claim, '') $$;

create policy if not exists sync_cursors_rw_self on public.sync_cursors
for all to authenticated
using (user_id::text = public.jwt_claim('sub'))
with check (user_id::text = public.jwt_claim('sub'));
