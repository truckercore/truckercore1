-- docs/supabase/roadside_rls.sql
-- Roadside providers/package RLS policies (essentials). Idempotent and safe to re-run.
-- Helpers expect JWT claims: app_org_id, app_roles (array), sub (user id)

create extension if not exists pgcrypto;

-- Convenience claim helper (shared pattern)
create or replace function public.jwt_claim(claim text)
returns text stable language sql as $$ select coalesce(current_setting('request.jwt.claims', true)::json->>claim, '') $$;

-- Enable RLS on all roadside tables (ignore if some not present)
DO $$ BEGIN
  EXECUTE 'alter table public.roadside_providers enable row level security';
EXCEPTION WHEN undefined_table THEN NULL; END $$;
DO $$ BEGIN
  EXECUTE 'alter table public.roadside_locations enable row level security';
EXCEPTION WHEN undefined_table THEN NULL; END $$;
DO $$ BEGIN
  EXECUTE 'alter table public.roadside_services enable row level security';
EXCEPTION WHEN undefined_table THEN NULL; END $$;
DO $$ BEGIN
  EXECUTE 'alter table public.roadside_pricing enable row level security';
EXCEPTION WHEN undefined_table THEN NULL; END $$;
DO $$ BEGIN
  EXECUTE 'alter table public.roadside_techs enable row level security';
EXCEPTION WHEN undefined_table THEN NULL; END $$;
DO $$ BEGIN
  EXECUTE 'alter table public.roadside_requests enable row level security';
EXCEPTION WHEN undefined_table THEN NULL; END $$;
DO $$ BEGIN
  EXECUTE 'alter table public.roadside_jobs enable row level security';
EXCEPTION WHEN undefined_table THEN NULL; END $$;
DO $$ BEGIN
  EXECUTE 'alter table public.roadside_chat enable row level security';
EXCEPTION WHEN undefined_table THEN NULL; END $$;
DO $$ BEGIN
  EXECUTE 'alter table public.roadside_provider_stats enable row level security';
EXCEPTION WHEN undefined_table THEN NULL; END $$;

-- Providers scoped by org (corp_admin/provider_admin can CRUD)
DO $$ BEGIN
  DROP POLICY IF EXISTS providers_read_org ON public.roadside_providers;
  CREATE POLICY providers_read_org ON public.roadside_providers
  FOR SELECT TO authenticated
  USING (org_id::text = public.jwt_claim('app_org_id'));
EXCEPTION WHEN undefined_table THEN NULL; END $$;

DO $$ BEGIN
  DROP POLICY IF EXISTS providers_write_admin ON public.roadside_providers;
  CREATE POLICY providers_write_admin ON public.roadside_providers
  FOR ALL TO authenticated
  USING (
    org_id::text = public.jwt_claim('app_org_id')
    AND (
      (coalesce(current_setting('request.jwt.claims', true)::json->'app_roles','[]'::json) ? 'provider_admin')
      OR (coalesce(current_setting('request.jwt.claims', true)::json->'app_roles','[]'::json) ? 'corp_admin')
    )
  ) WITH CHECK (
    org_id::text = public.jwt_claim('app_org_id')
    AND (
      (coalesce(current_setting('request.jwt.claims', true)::json->'app_roles','[]'::json) ? 'provider_admin')
      OR (coalesce(current_setting('request.jwt.claims', true)::json->'app_roles','[]'::json) ? 'corp_admin')
    )
  );
EXCEPTION WHEN undefined_table THEN NULL; END $$;

-- Child tables (locations/services/pricing/techs) scoped via provider -> org
DO $$ BEGIN
  DROP POLICY IF EXISTS child_read_org_locations ON public.roadside_locations;
  CREATE POLICY child_read_org_locations ON public.roadside_locations
  FOR SELECT TO authenticated
  USING (exists (
    select 1 from public.roadside_providers p
    where p.id = provider_id and p.org_id::text = public.jwt_claim('app_org_id')
  ));
EXCEPTION WHEN undefined_table THEN NULL; END $$;

DO $$ BEGIN
  DROP POLICY IF EXISTS child_write_admin_locations ON public.roadside_locations;
  CREATE POLICY child_write_admin_locations ON public.roadside_locations
  FOR ALL TO authenticated
  USING (
    exists (
      select 1 from public.roadside_providers p
      where p.id = provider_id and p.org_id::text = public.jwt_claim('app_org_id')
    )
    AND (
      (coalesce(current_setting('request.jwt.claims', true)::json->'app_roles','[]'::json) ? 'provider_admin')
      OR (coalesce(current_setting('request.jwt.claims', true)::json->'app_roles','[]'::json) ? 'corp_admin')
    )
  ) WITH CHECK (
    exists (
      select 1 from public.roadside_providers p
      where p.id = provider_id and p.org_id::text = public.jwt_claim('app_org_id')
    )
    AND (
      (coalesce(current_setting('request.jwt.claims', true)::json->'app_roles','[]'::json) ? 'provider_admin')
      OR (coalesce(current_setting('request.jwt.claims', true)::json->'app_roles','[]'::json) ? 'corp_admin')
    )
  );
EXCEPTION WHEN undefined_table THEN NULL; END $$;

-- Duplicate for services/pricing/techs
DO $$ BEGIN
  DROP POLICY IF EXISTS child_read_org_services ON public.roadside_services;
  CREATE POLICY child_read_org_services ON public.roadside_services
  FOR SELECT TO authenticated
  USING (exists (select 1 from public.roadside_providers p where p.id = provider_id and p.org_id::text = public.jwt_claim('app_org_id')));
  DROP POLICY IF EXISTS child_write_admin_services ON public.roadside_services;
  CREATE POLICY child_write_admin_services ON public.roadside_services
  FOR ALL TO authenticated
  USING (exists (select 1 from public.roadside_providers p where p.id = provider_id and p.org_id::text = public.jwt_claim('app_org_id'))
         AND ((coalesce(current_setting('request.jwt.claims', true)::json->'app_roles','[]'::json) ? 'provider_admin')
              OR (coalesce(current_setting('request.jwt.claims', true)::json->'app_roles','[]'::json) ? 'corp_admin')))
  WITH CHECK (exists (select 1 from public.roadside_providers p where p.id = provider_id and p.org_id::text = public.jwt_claim('app_org_id'))
         AND ((coalesce(current_setting('request.jwt.claims', true)::json->'app_roles','[]'::json) ? 'provider_admin')
              OR (coalesce(current_setting('request.jwt.claims', true)::json->'app_roles','[]'::json) ? 'corp_admin')));
EXCEPTION WHEN undefined_table THEN NULL; END $$;

DO $$ BEGIN
  DROP POLICY IF EXISTS child_read_org_pricing ON public.roadside_pricing;
  CREATE POLICY child_read_org_pricing ON public.roadside_pricing
  FOR SELECT TO authenticated
  USING (exists (select 1 from public.roadside_providers p where p.id = provider_id and p.org_id::text = public.jwt_claim('app_org_id')));
  DROP POLICY IF EXISTS child_write_admin_pricing ON public.roadside_pricing;
  CREATE POLICY child_write_admin_pricing ON public.roadside_pricing
  FOR ALL TO authenticated
  USING (exists (select 1 from public.roadside_providers p where p.id = provider_id and p.org_id::text = public.jwt_claim('app_org_id'))
         AND ((coalesce(current_setting('request.jwt.claims', true)::json->'app_roles','[]'::json) ? 'provider_admin')
              OR (coalesce(current_setting('request.jwt.claims', true)::json->'app_roles','[]'::json) ? 'corp_admin')))
  WITH CHECK (exists (select 1 from public.roadside_providers p where p.id = provider_id and p.org_id::text = public.jwt_claim('app_org_id'))
         AND ((coalesce(current_setting('request.jwt.claims', true)::json->'app_roles','[]'::json) ? 'provider_admin')
              OR (coalesce(current_setting('request.jwt.claims', true)::json->'app_roles','[]'::json) ? 'corp_admin')));
EXCEPTION WHEN undefined_table THEN NULL; END $$;

DO $$ BEGIN
  DROP POLICY IF EXISTS child_read_org_techs ON public.roadside_techs;
  CREATE POLICY child_read_org_techs ON public.roadside_techs
  FOR SELECT TO authenticated
  USING (exists (select 1 from public.roadside_providers p where p.id = provider_id and p.org_id::text = public.jwt_claim('app_org_id')));
  DROP POLICY IF EXISTS child_write_admin_techs ON public.roadside_techs;
  CREATE POLICY child_write_admin_techs ON public.roadside_techs
  FOR ALL TO authenticated
  USING (exists (select 1 from public.roadside_providers p where p.id = provider_id and p.org_id::text = public.jwt_claim('app_org_id'))
         AND ((coalesce(current_setting('request.jwt.claims', true)::json->'app_roles','[]'::json) ? 'provider_admin')
              OR (coalesce(current_setting('request.jwt.claims', true)::json->'app_roles','[]'::json) ? 'corp_admin')))
  WITH CHECK (exists (select 1 from public.roadside_providers p where p.id = provider_id and p.org_id::text = public.jwt_claim('app_org_id'))
         AND ((coalesce(current_setting('request.jwt.claims', true)::json->'app_roles','[]'::json) ? 'provider_admin')
              OR (coalesce(current_setting('request.jwt.claims', true)::json->'app_roles','[]'::json) ? 'corp_admin')));
EXCEPTION WHEN undefined_table THEN NULL; END $$;

-- Requests visibility: requester, assigned provider org, fleet org
DO $$ BEGIN
  DROP POLICY IF EXISTS requests_read_scoped ON public.roadside_requests;
  CREATE POLICY requests_read_scoped ON public.roadside_requests
  FOR SELECT TO authenticated
  USING (
    requester_user_id::text = public.jwt_claim('sub')
    OR org_id::text = public.jwt_claim('app_org_id')
    OR exists (select 1 from public.roadside_providers p where p.id = assigned_provider_id and p.org_id::text = public.jwt_claim('app_org_id'))
  );
EXCEPTION WHEN undefined_table THEN NULL; END $$;

-- Jobs visibility: provider org, requester user, fleet org
DO $$ BEGIN
  DROP POLICY IF EXISTS jobs_read_scoped ON public.roadside_jobs;
  CREATE POLICY jobs_read_scoped ON public.roadside_jobs
  FOR SELECT TO authenticated
  USING (
    exists (select 1 from public.roadside_providers p where p.id = provider_id and p.org_id::text = public.jwt_claim('app_org_id'))
    OR exists (
      select 1 from public.roadside_requests r where r.id = request_id
      and (r.requester_user_id::text = public.jwt_claim('sub') OR r.org_id::text = public.jwt_claim('app_org_id'))
    )
  );
EXCEPTION WHEN undefined_table THEN NULL; END $$;

-- Chat visibility: participants tied to request via jobs and org/requester checks
DO $$ BEGIN
  DROP POLICY IF EXISTS chat_read_scoped ON public.roadside_chat;
  CREATE POLICY chat_read_scoped ON public.roadside_chat
  FOR SELECT TO authenticated
  USING (exists (
    select 1 from public.roadside_requests r
    join public.roadside_jobs j on j.request_id = r.id
    where r.id = roadside_chat.request_id and (
      r.requester_user_id::text = public.jwt_claim('sub')
      or r.org_id::text = public.jwt_claim('app_org_id')
      or exists (select 1 from public.roadside_providers p where p.id = j.provider_id and p.org_id::text = public.jwt_claim('app_org_id'))
    )
  ));
EXCEPTION WHEN undefined_table THEN NULL; END $$;
