-- Migration: wrapper RPC for nightly learning job
-- Date: 2025-09-27

-- This migration intentionally avoids creating tables that may already exist.
-- It provides a SECURITY DEFINER wrapper function run_nightly_learning_job()
-- that delegates to the existing public.run_learning_job() to prevent schema
-- duplication while aligning with external callers expecting this RPC name.

-- Helper (kept here for readability; function already exists in prior migrations).
-- create or replace function public.http_header(name text)
-- returns text language sql stable as $$
--   select (current_setting('request.headers', true)::jsonb ->> name)
-- $$;

create or replace function public.run_nightly_learning_job()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Delegate to the already-defined learning job RPC to avoid duplicating logic
  return public.run_learning_job();
end;
$$;

-- Ensure service_role can execute
grant execute on function public.run_nightly_learning_job() to service_role;