-- docs/supabase/fleet_invites_rls_updates.sql
-- Patch to align Fleet Invites schema/RLS with the latest spec.
-- Safe to re-run. Apply in Supabase SQL editor.

create extension if not exists pgcrypto;

-- Ensure enum invite_status includes 'expired'
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'invite_status') THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_enum e
      JOIN pg_type t ON t.oid = e.enumtypid
      WHERE t.typname = 'invite_status' AND e.enumlabel = 'expired'
    ) THEN
      ALTER TYPE public.invite_status ADD VALUE 'expired';
    END IF;
  END IF;
END $$;

-- Add missing columns on driver_invites
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'driver_invites' AND column_name = 'invited_by'
  ) THEN
    ALTER TABLE public.driver_invites ADD COLUMN invited_by uuid null;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'driver_invites' AND column_name = 'accepted_at'
  ) THEN
    ALTER TABLE public.driver_invites ADD COLUMN accepted_at timestamptz null;
  END IF;
END $$;

-- Helpful composite index for org/status filters
CREATE INDEX IF NOT EXISTS idx_driver_invites_org_status ON public.driver_invites(org_id, status);

-- RLS: managers can update invites in their org (resend/revoke/expire)
-- We rely on an existing helper has_manager_role(org_id) if present; otherwise create a lightweight one.
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc WHERE proname = 'has_manager_role' AND pg_function_is_visible(oid)
  ) THEN
    CREATE OR REPLACE FUNCTION public.has_manager_role(p_org uuid)
    RETURNS boolean LANGUAGE sql STABLE AS $$
      SELECT coalesce(
        (auth.jwt() ->> 'app_org_id')::uuid = p_org
        AND (
          (auth.jwt() ->> 'app_role') IN ('admin','dispatcher','safety')
          OR (
            -- optional array form support: app_roles holds JSON array of roles
            EXISTS (
              SELECT 1
              FROM json_array_elements_text(COALESCE(NULLIF(auth.jwt() ->> 'app_roles',''), '[]')::json) r(role)
              WHERE r.role IN ('admin','dispatcher','safety')
            )
          )
        ), false);
    $$;
  END IF;
END $$;

ALTER TABLE public.driver_invites ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS invites_update_manager ON public.driver_invites;
CREATE POLICY invites_update_manager ON public.driver_invites
FOR UPDATE TO authenticated
USING (has_manager_role(org_id))
WITH CHECK (has_manager_role(org_id));

-- Update accept RPC to record accepted_at timestamp when moving to accepted
CREATE OR REPLACE FUNCTION public.accept_driver_invite(p_token text)
RETURNS TABLE(user_id uuid, org_id uuid, role public.fleet_role)
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_inv public.driver_invites%rowtype;
  v_uid uuid := auth.uid();
BEGIN
  IF p_token IS NULL OR length(p_token) < 10 THEN
    RAISE EXCEPTION 'invalid_token';
  END IF;

  SELECT * INTO v_inv
  FROM public.driver_invites
  WHERE token = p_token AND status = 'pending'
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'invite_not_found_or_used';
  END IF;

  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'auth_required';
  END IF;

  -- Upsert membership
  INSERT INTO public.fleet_members(org_id, user_id, role)
  VALUES (v_inv.org_id, v_uid, v_inv.role)
  ON CONFLICT (org_id, user_id) DO UPDATE SET role = EXCLUDED.role;

  -- Create driver profile if role=driver
  IF v_inv.role = 'driver' THEN
    INSERT INTO public.drivers(org_id, user_id, status)
    VALUES (v_inv.org_id, v_uid, 'active')
    ON CONFLICT DO NOTHING;
  END IF;

  UPDATE public.driver_invites
    SET status = 'accepted', accepted_at = now()
  WHERE id = v_inv.id;

  RETURN QUERY SELECT v_uid AS user_id, v_inv.org_id AS org_id, v_inv.role AS role;
END $$;

-- Notes:
-- - Managers can now update invites (e.g., set status='revoked' or 'expired').
-- - The accept RPC sets accepted_at.
-- - Ensure your Edge Functions use service role for administrative actions where needed.
