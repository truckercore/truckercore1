-- docs/supabase/orgs_min_hardening.sql
-- Minimal org RLS hardening + helper. Run top-to-bottom in Supabase SQL editor.
-- Idempotent where possible.

-- 0) Sanity checks — core objects presence (copy-run these to verify):
-- select to_regclass('public.organizations');
-- select to_regclass('public.org_memberships');
-- select to_regclass('public.loads');
-- select to_regclass('public.route_logs');
-- select to_regclass('public.telemetry_events');
-- select to_regclass('connectors.connector_runs');

-- 1) Enable RLS and add policies
-- 1.a organizations: restrict reads to members or matching app_org_id claim
alter table if exists public.organizations enable row level security;
create policy if not exists orgs_read_member on public.organizations
for select to authenticated
using (
  -- Allow when app_org_id claim matches
  id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','')
  OR
  -- Or when user is a member of the org
  exists (
    select 1 from public.org_memberships m
    where m.org_id = organizations.id
      and m.user_id = auth.uid()
      and coalesce(m.active, true)
  )
);

-- 1.b org_memberships: a user can read their own memberships; (writes via admin/service)
alter table if exists public.org_memberships enable row level security;
create policy if not exists org_memberships_read_self on public.org_memberships
for select to authenticated
using (user_id = auth.uid());

-- Optional: allow members to see all memberships within same org (commented out)
-- create policy if not exists org_memberships_read_org on public.org_memberships
-- for select to authenticated
-- using (exists (
--   select 1 from public.org_memberships m2
--   where m2.org_id = org_memberships.org_id and m2.user_id = auth.uid() and coalesce(m2.active,true)
-- ));

-- 1.c loads: org-scoped read/write (WITH CHECK) using app_org_id claim
alter table if exists public.loads enable row level security;
create policy if not exists loads_rw_org on public.loads
for all to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''))
with check (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

-- If you prefer read-only for non-members, split into select/update policies instead of FOR ALL.

-- 1.d (Optional) route_logs and telemetry_events read restricted by org
alter table if exists public.route_logs enable row level security;
create policy if not exists route_logs_read_org on public.route_logs
for select to authenticated
using (coalesce((route_logs.org_id)::text,'') = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

alter table if exists public.telemetry_events enable row level security;
create policy if not exists telemetry_read_org on public.telemetry_events
for select to authenticated
using (coalesce((telemetry_events.org_id)::text,'') = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

-- 2) Tighten connectors.connector_runs (service-only writes via RPC/functions)
revoke all on table connectors.connector_runs from anon;
revoke all on table connectors.connector_runs from authenticated;
alter table if exists connectors.connector_runs enable row level security;
-- No client policies created; service-role uses privileged key through Edge Functions.

-- 3) NOTIFY-friendly helper to switch org in-session for Edge Functions
-- This sets request.jwt.claims->app_org_id for the current DB session (request scope),
-- and emits a NOTIFY so listeners/observability can track switches.
create or replace function public.app_switch_org(p_org uuid)
returns void
language plpgsql
security definer
as $$
begin
  -- Validate membership
  if not exists (
    select 1 from public.org_memberships m
    where m.org_id = p_org and m.user_id = auth.uid() and coalesce(m.active,true)
  ) then
    raise exception 'not_member_of_org' using errcode = '28000';
  end if;

  -- Update request-scoped JWT claims so subsequent queries in this request see app_org_id
  perform set_config(
    'request.jwt.claims',
    jsonb_set(
      coalesce(current_setting('request.jwt.claims', true)::jsonb, '{}'::jsonb),
      '{app_org_id}',
      to_jsonb(p_org)
    )::text,
    true
  );

  -- Emit NOTIFY for observability / optional out-of-band processing
  perform pg_notify(
    'app_org_switched',
    json_build_object('user_id', auth.uid(), 'org_id', p_org, 'at', now())::text
  );
end;
$$;

grant execute on function public.app_switch_org(uuid) to authenticated, anon;

-- 4) RLS Smoke Test (manual steps; run in SQL editor)
-- -- Setup two users and two orgs (replace UUIDs with real ones) --
-- with u as (
--   select '00000000-0000-0000-0000-000000000001'::uuid as u1,
--          '00000000-0000-0000-0000-000000000002'::uuid as u2
-- )
-- insert into public.organizations(id, name)
--   values ('11111111-1111-1111-1111-111111111111','Org A')
--   on conflict (id) do nothing;
-- insert into public.organizations(id, name)
--   values ('22222222-2222-2222-2222-222222222222','Org B')
--   on conflict (id) do nothing;
-- insert into public.org_memberships(org_id, user_id, role, active) values
--   ('11111111-1111-1111-1111-111111111111', (select u1 from u), 'member', true)
--   on conflict (org_id, user_id) do nothing;
-- insert into public.org_memberships(org_id, user_id, role, active) values
--   ('22222222-2222-2222-2222-222222222222', (select u2 from u), 'member', true)
--   on conflict (org_id, user_id) do nothing;
--
-- -- As u1 with app_org_id=Org A: insert/select/update on public.loads should succeed and remain org-scoped.
-- -- As u2 with app_org_id=Org B: reading loads from Org A should return zero rows.
-- -- Use PostgREST or Supabase client with user JWTs set to test policies.

-- 5) Notes
-- - app_switch_org is safe to call at the start of an Edge Function after you validate the org selection.
--   It affects only the current DB session/transaction and does not permanently change the user's JWT.
-- - Keep connector writes through service-role functions to avoid exposing staging/core tables to clients.
