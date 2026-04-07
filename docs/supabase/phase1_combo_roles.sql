-- Phase 1 — Feature 2: Combo Role Support (Carrier + Broker)
-- This migration updates profiles to support multiple roles and backfills existing users.

-- Assumptions:
-- - profiles table exists with columns: id (uuid pk), primary_role text
-- - You will update RLS elsewhere to enforce data isolation per role context.

alter table public.profiles
  add column if not exists roles jsonb;

-- Backfill from primary_role if roles is null
update public.profiles
set roles = case
  when primary_role is null then to_jsonb(array[]::text[])
  else to_jsonb(array[primary_role]::text[])
end
where roles is null;

-- Simple check index to query by roles contents (GIN)
create index if not exists idx_profiles_roles_gin on public.profiles using GIN (roles jsonb_path_ops);

-- Example RLS note (implement in each table as appropriate):
-- For rows that are broker-owned (e.g., loads posted by broker), enforce:
--   ... USING ( (auth.jwt() ->> 'app_primary_role') in ('broker') )
-- For carrier-mode data (e.g., assigned loads), enforce carrier access similarly.
-- In practice, scope by org and ownership and then check role claim:
--   (auth.uid() = owner_id) AND ((current_setting('request.jwt.claims', true)::jsonb -> 'app_roles') ? 'broker')

-- JWT hook embedding claims documented in README.
