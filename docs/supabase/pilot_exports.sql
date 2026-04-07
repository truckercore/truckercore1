-- docs/supabase/pilot_exports.sql
-- Pilot Summary exports and helper functions. Idempotent and safe to re-run.

create extension if not exists pgcrypto;

-- 1) Export snapshots table: stores filter JSON and entitlement snapshot ids for traceability
create table if not exists public.export_snapshots (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  created_by uuid null,
  filters jsonb not null default '{}'::jsonb,
  entitlement_snapshot_ids uuid[] not null default '{}'::uuid[],
  url text null, -- optional link to generated file (PDF/HTML)
  notes text null,
  created_at timestamptz not null default now()
);
create index if not exists idx_export_snapshots_org_ts on public.export_snapshots(org_id, created_at desc);

-- 2) RLS: allow org members to insert/select their org's rows; service_role has bypass
alter table public.export_snapshots enable row level security;
DO $$ BEGIN
  DROP POLICY IF EXISTS export_snapshots_read ON public.export_snapshots;
  CREATE POLICY export_snapshots_read ON public.export_snapshots
  FOR SELECT TO authenticated
  USING (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

  DROP POLICY IF EXISTS export_snapshots_insert ON public.export_snapshots;
  CREATE POLICY export_snapshots_insert ON public.export_snapshots
  FOR INSERT TO authenticated
  WITH CHECK (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
END $$;

-- 3) Helper: return recent entitlement snapshot ids if an entitlement_snapshots table/function exists.
-- If prior snapshot functions were installed (snapshot_entitlements), use them; otherwise, return empty array.
create or replace function public.entitlement_snapshot_ids(p_org_id uuid)
returns uuid[]
stable
language plpgsql
as $$
DECLARE
  v_ids uuid[] := array[]::uuid[];
  has_table boolean := false;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema='public' AND table_name='entitlement_snapshots'
  ) INTO has_table;

  IF has_table THEN
    SELECT coalesce(array_agg(id ORDER BY created_at desc), array[]::uuid[])
    INTO v_ids
    FROM public.entitlement_snapshots
    WHERE org_id = p_org_id
      AND created_at >= now() - interval '90 days';
  END IF;

  RETURN v_ids;
END;
$$;

-- 4) Helper: create an export snapshot row and return it
-- If entitlement_snapshots exist, attach recent IDs; otherwise empty.
create or replace function public.create_pilot_export(
  p_org_id uuid,
  p_filters jsonb,
  p_url text default null,
  p_notes text default null
) returns public.export_snapshots
language plpgsql
security definer
set search_path = public
as $$
DECLARE
  v_row public.export_snapshots;
  v_user uuid := null;
BEGIN
  -- Try to read actor from JWT
  BEGIN
    v_user := (current_setting('request.jwt.claims', true)::json->>'sub')::uuid;
  EXCEPTION WHEN others THEN
    v_user := null;
  END;

  INSERT INTO public.export_snapshots(org_id, created_by, filters, entitlement_snapshot_ids, url, notes)
  VALUES (
    p_org_id,
    v_user,
    coalesce(p_filters, '{}'::jsonb),
    public.entitlement_snapshot_ids(p_org_id),
    p_url,
    p_notes
  )
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;
