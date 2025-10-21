-- Phase 1 — Saved Search + Load Alerts
-- This migration creates saved_searches and load_alerts tables, enums, indexes, and RLS policies.
-- It is safe to run multiple times if you guard with IF NOT EXISTS.

-- 0) Prereqs: enable UUID extension
create extension if not exists "uuid-ossp";

-- 1) Enums
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'app_role_enum') THEN
    CREATE TYPE app_role_enum AS ENUM ('driver','owner_op','broker','fleet_admin');
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'match_type_enum') THEN
    CREATE TYPE match_type_enum AS ENUM ('load','truck');
  END IF;
END $$;

-- 1.1 Tables
CREATE TABLE IF NOT EXISTS public.saved_searches (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  org_id uuid NOT NULL,
  user_id uuid NOT NULL,
  role app_role_enum NOT NULL,
  name text NOT NULL,
  filters jsonb NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.load_alerts (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  org_id uuid NOT NULL,
  user_id uuid NOT NULL,
  saved_search_id uuid NOT NULL REFERENCES public.saved_searches(id) ON DELETE CASCADE,
  match_type match_type_enum NOT NULL,
  match_payload jsonb NOT NULL,
  load_id uuid NULL,
  truck_post_id uuid NULL,
  triggered_at timestamptz NOT NULL,
  seen boolean NOT NULL DEFAULT false,
  clicked boolean NOT NULL DEFAULT false
);

-- 1.2 Indexes
-- Saved searches: filter by owner/org and active
CREATE INDEX IF NOT EXISTS idx_saved_searches_owner_active ON public.saved_searches (org_id, user_id, is_active);
-- GIN for filters structure queries
CREATE INDEX IF NOT EXISTS idx_saved_searches_filters_gin ON public.saved_searches USING GIN (filters);

-- Load alerts: owner + recency; partial index on unseen
CREATE INDEX IF NOT EXISTS idx_load_alerts_owner_time ON public.load_alerts (org_id, user_id, triggered_at DESC);
CREATE INDEX IF NOT EXISTS idx_load_alerts_unseen ON public.load_alerts (user_id) WHERE seen = false;

-- 1.3 RLS Policies
ALTER TABLE public.saved_searches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.load_alerts ENABLE ROW LEVEL SECURITY;

-- Helper: ensure JWT claims include app_org_id for scoping
-- Policies for saved_searches
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='saved_searches' AND policyname='saved_searches_select') THEN
    CREATE POLICY saved_searches_select ON public.saved_searches
      FOR SELECT USING (
        auth.uid() = user_id AND (current_setting('request.jwt.claims', true)::jsonb ->> 'app_org_id')::uuid = org_id
      );
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='saved_searches' AND policyname='saved_searches_insert') THEN
    CREATE POLICY saved_searches_insert ON public.saved_searches
      FOR INSERT WITH CHECK (
        auth.uid() = user_id AND (current_setting('request.jwt.claims', true)::jsonb ->> 'app_org_id')::uuid = org_id
      );
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='saved_searches' AND policyname='saved_searches_update') THEN
    CREATE POLICY saved_searches_update ON public.saved_searches
      FOR UPDATE USING (
        auth.uid() = user_id AND (current_setting('request.jwt.claims', true)::jsonb ->> 'app_org_id')::uuid = org_id
      ) WITH CHECK (
        auth.uid() = user_id AND (current_setting('request.jwt.claims', true)::jsonb ->> 'app_org_id')::uuid = org_id
      );
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='saved_searches' AND policyname='saved_searches_delete') THEN
    CREATE POLICY saved_searches_delete ON public.saved_searches
      FOR DELETE USING (
        auth.uid() = user_id AND (current_setting('request.jwt.claims', true)::jsonb ->> 'app_org_id')::uuid = org_id
      );
  END IF;
END $$;

-- Policies for load_alerts
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='load_alerts' AND policyname='load_alerts_select') THEN
    CREATE POLICY load_alerts_select ON public.load_alerts
      FOR SELECT USING (
        auth.uid() = user_id AND (current_setting('request.jwt.claims', true)::jsonb ->> 'app_org_id')::uuid = org_id
      );
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='load_alerts' AND policyname='load_alerts_update') THEN
    CREATE POLICY load_alerts_update ON public.load_alerts
      FOR UPDATE USING (
        auth.uid() = user_id AND (current_setting('request.jwt.claims', true)::jsonb ->> 'app_org_id')::uuid = org_id
      ) WITH CHECK (
        auth.uid() = user_id AND (current_setting('request.jwt.claims', true)::jsonb ->> 'app_org_id')::uuid = org_id
      );
  END IF;
END $$;

-- NOTE: No INSERT policy for load_alerts; only service role should insert.
-- Ensure anon/authenticated roles do not have INSERT privilege if using PostgREST defaults.
REVOKE INSERT ON public.load_alerts FROM anon, authenticated;

-- 1.4 Optional Stage Seed Data (commented)
-- Uncomment and adapt for staging environments only.
--
-- -- Sample users (assumes profiles table exists)
-- -- INSERT INTO auth.users ... (managed outside of SQL for Supabase);
--
-- -- Sample saved searches for 2 drivers, 1 owner-op, 1 broker, 1 fleet admin
-- -- INSERT INTO public.saved_searches (org_id, user_id, role, name, filters)
-- -- VALUES
-- --   ('00000000-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111','driver','NJ -> IL reefers', '{"origin":"NJ","destination":"IL","equipment":"reefer"}'),
-- --   ... ;
--
-- -- Seed loads/truck_posts would be managed by your existing seeds (see docs/supabase/fleet_demo_seed.sql).

-- 2) Optional RPC for fast unseen count (for bell badge ≤100ms)
-- Returns a single row with count
CREATE OR REPLACE FUNCTION public.fn_unseen_alerts_count(p_user_id uuid)
RETURNS TABLE(cnt bigint)
LANGUAGE sql STABLE AS $$
  SELECT count(*)::bigint AS cnt
  FROM public.load_alerts
  WHERE user_id = p_user_id AND seen = false;
$$;

-- Grant execute on function
GRANT EXECUTE ON FUNCTION public.fn_unseen_alerts_count(uuid) TO anon, authenticated;

-- 3) Optional: View for exceptions count used by live_alerts_provider polling fallback
CREATE OR REPLACE FUNCTION public.v_exceptions_count(p_org_id text)
RETURNS TABLE(count integer)
LANGUAGE sql STABLE AS $$
  SELECT COALESCE((SELECT 0), 0) AS count; -- placeholder implementation
$$;
