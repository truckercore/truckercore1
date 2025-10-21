-- docs/supabase/pilot_mode.sql
-- Pilot Mode flag per org, plus entitlement snapshots for before/after comparisons.
-- Idempotent and safe to re-run.

create extension if not exists pgcrypto;

-- 0) Ensure feature 'pilot_mode' exists in registry so it can be resolved via get_entitlement
insert into public.features(key, description)
values ('pilot_mode', 'Enables in-app Pilot Mode banner and pilot KPI surfaces')
on conflict (key) do update set description = excluded.description;

-- 1) Org pilot flags (explicit toggle separate from entitlements; RLS limited to same org)
create table if not exists public.org_pilot_flags (
  org_id uuid primary key,
  pilot_mode boolean not null default false,
  started_at timestamptz null,
  ended_at timestamptz null,
  updated_at timestamptz not null default now()
);

alter table public.org_pilot_flags enable row level security;
DO $$ BEGIN
  DROP POLICY IF EXISTS org_pilot_select ON public.org_pilot_flags;
  CREATE POLICY org_pilot_select ON public.org_pilot_flags FOR SELECT TO authenticated USING (
    org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','')
  );
  DROP POLICY IF EXISTS org_pilot_write ON public.org_pilot_flags;
  CREATE POLICY org_pilot_write ON public.org_pilot_flags FOR INSERT TO authenticated WITH CHECK (
    org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','')
    AND coalesce(current_setting('request.jwt.claims', true)::json->>'org_role','') in ('corp_admin')
  );
  DROP POLICY IF EXISTS org_pilot_update ON public.org_pilot_flags;
  CREATE POLICY org_pilot_update ON public.org_pilot_flags FOR UPDATE TO authenticated USING (
    org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','')
    AND coalesce(current_setting('request.jwt.claims', true)::json->>'org_role','') in ('corp_admin')
  ) WITH CHECK (
    org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','')
    AND coalesce(current_setting('request.jwt.claims', true)::json->>'org_role','') in ('corp_admin')
  );
END $$;

-- 2) Entitlements snapshot table (stores a full resolved snapshot for an org across all features)
create table if not exists public.entitlement_snapshots (
  org_id uuid not null,
  taken_at timestamptz not null default now(),
  label text null, -- e.g., 'pilot_start' | 'pilot_end' | custom
  snapshot jsonb not null,
  taken_by uuid null,
  primary key (org_id, taken_at)
);
create index if not exists idx_ent_snapshots_org on public.entitlement_snapshots(org_id, taken_at desc);

alter table public.entitlement_snapshots enable row level security;
DO $$ BEGIN
  DROP POLICY IF EXISTS ent_snap_select ON public.entitlement_snapshots;
  CREATE POLICY ent_snap_select ON public.entitlement_snapshots FOR SELECT TO authenticated USING (
    org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','')
  );
  DROP POLICY IF EXISTS ent_snap_insert ON public.entitlement_snapshots;
  CREATE POLICY ent_snap_insert ON public.entitlement_snapshots FOR INSERT TO authenticated WITH CHECK (
    org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','')
  );
END $$;

-- 3) Snapshot function: captures resolver output across all registered features for an org
create or replace function public.snapshot_entitlements(p_org_id uuid, p_label text default null)
returns void
language plpgsql
security definer
as $$
DECLARE
  rec record;
  arr jsonb := '[]'::jsonb;
BEGIN
  -- Iterate through all features and accumulate resolved entitlements
  FOR rec IN SELECT key FROM public.features LOOP
    arr := arr || jsonb_build_array(jsonb_build_object(
      'feature', rec.key,
      'result', (select to_jsonb(r) from public.get_entitlement(p_org_id, rec.key, null) r)
    ));
  END LOOP;
  INSERT INTO public.entitlement_snapshots(org_id, label, snapshot)
  VALUES (p_org_id, p_label, jsonb_build_object('features', arr, 'captured_at', now()));
END;
$$;

-- 4) Convenience helpers to start and end pilot: toggle flag + take snapshot
create or replace function public.start_pilot(p_org_id uuid)
returns void
language plpgsql
security definer
as $$
BEGIN
  INSERT INTO public.org_pilot_flags(org_id, pilot_mode, started_at, ended_at, updated_at)
  VALUES (p_org_id, true, now(), null, now())
  ON CONFLICT (org_id) DO UPDATE SET pilot_mode = true, started_at = coalesce(public.org_pilot_flags.started_at, now()), ended_at = null, updated_at = now();
  PERFORM public.snapshot_entitlements(p_org_id, 'pilot_start');
  -- Optionally grant pilot_mode via org_entitlements if not already enabled
  INSERT INTO public.org_entitlements(org_id, feature_key, value, reason)
  VALUES (p_org_id, 'pilot_mode', 'true'::jsonb, 'Pilot start')
  ON CONFLICT (org_id, feature_key) DO UPDATE SET value = 'true'::jsonb, expires_at = null, reason = 'Pilot start';
END;
$$;

create or replace function public.end_pilot(p_org_id uuid)
returns void
language plpgsql
security definer
as $$
BEGIN
  UPDATE public.org_pilot_flags SET pilot_mode = false, ended_at = now(), updated_at = now() WHERE org_id = p_org_id;
  PERFORM public.snapshot_entitlements(p_org_id, 'pilot_end');
  -- Optionally disable pilot_mode override
  INSERT INTO public.org_entitlements(org_id, feature_key, value, reason)
  VALUES (p_org_id, 'pilot_mode', 'false'::jsonb, 'Pilot end')
  ON CONFLICT (org_id, feature_key) DO UPDATE SET value = 'false'::jsonb, reason = 'Pilot end';
END;
$$;
