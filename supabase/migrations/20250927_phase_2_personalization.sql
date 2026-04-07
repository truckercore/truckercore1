-- Migration: Phase 2 Personalization minimal extensions
-- Date: 2025-09-27

-- This migration augments the existing suggestions_log table (bigserial id schema)
-- by adding feedback columns and an updated_at trigger, and creates an RPC
-- for recording feedback that respects RLS (user can only update own rows).

-- 0) Preconditions: ensure table exists (noop if created by prior migration)
create table if not exists public.suggestions_log (
  id bigserial primary key,
  user_id uuid not null,
  org_id uuid,
  context text,
  suggestion_json jsonb,
  features_snapshot jsonb default '{}'::jsonb,
  explanation text,
  accepted boolean,
  latency_ms integer,
  ts timestamptz not null default now()
);

-- 1) Extend suggestions_log with feedback columns and updated_at
alter table public.suggestions_log
  add column if not exists feedback_type text,
  add column if not exists feedback_value jsonb,
  add column if not exists updated_at timestamptz not null default now();

-- Keep updated_at fresh on UPDATEs
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- Recreate trigger idempotently
drop trigger if exists trg_suggestions_log_touch on public.suggestions_log;
create trigger trg_suggestions_log_touch
before update on public.suggestions_log
for each row execute function public.touch_updated_at();

-- 2) Ensure RLS and policies exist (insert/select/update own)
alter table public.suggestions_log enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'suggestions_log'
      and policyname = 'insert_own_suggestions_log'
  ) then
    create policy insert_own_suggestions_log
      on public.suggestions_log for insert to authenticated
      with check (auth.uid() = user_id);
  end if;
end$$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'suggestions_log'
      and policyname = 'select_own_suggestions_log'
  ) then
    create policy select_own_suggestions_log
      on public.suggestions_log for select to authenticated
      using (auth.uid() = user_id);
  end if;
end$$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'suggestions_log'
      and policyname = 'update_own_suggestions_log'
  ) then
    create policy update_own_suggestions_log
      on public.suggestions_log for update to authenticated
      using (auth.uid() = user_id)
      with check (auth.uid() = user_id);
  end if;
end$$;

-- 3) RPC: submit_feedback (SECURITY DEFINER, but constrained by WHERE and RLS)
-- Uses bigint id to match existing table schema
create or replace function public.submit_feedback(
  log_id bigint,
  feedback_type text,
  feedback_value jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.suggestions_log
     set feedback_type = submit_feedback.feedback_type,
         feedback_value = submit_feedback.feedback_value
   where id = submit_feedback.log_id
     and user_id = auth.uid();
end;
$$;

revoke all on function public.submit_feedback(bigint, text, jsonb) from public;
grant execute on function public.submit_feedback(bigint, text, jsonb) to authenticated;
grant execute on function public.submit_feedback(bigint, text, jsonb) to service_role;
