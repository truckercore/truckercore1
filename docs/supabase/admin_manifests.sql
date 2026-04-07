-- docs/supabase/admin_manifests.sql
-- Signed manifest columns and verification helpers. Idempotent and safe to re-run.

create extension if not exists pgcrypto;

-- 1) Ensure admin_manifests table exists (optional placeholder); if it exists, alter it.
-- NOTE: If your deployment already has public.admin_manifests, this will just alter columns.
DO $$ BEGIN
  IF to_regclass('public.admin_manifests') IS NULL THEN
    EXECUTE 'CREATE TABLE public.admin_manifests (
      id uuid primary key default gen_random_uuid(),
      created_at timestamptz not null default now(),
      updated_at timestamptz not null default now()
    )';
  END IF;
END $$;

-- 2) Add signed manifest columns
ALTER TABLE IF EXISTS public.admin_manifests
  ADD COLUMN IF NOT EXISTS manifest jsonb NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS manifest_sig text NOT NULL DEFAULT '';

-- 3) Optional index on a stable manifest field (e.g., version)
DO $$ BEGIN
  BEGIN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_admin_manifests_version ON public.admin_manifests ((manifest->>''version''))';
  EXCEPTION WHEN others THEN
    -- ignore if expression index not supported in this env
    NULL;
  END;
END $$;

-- 4) Verification function using HMAC SHA-256 with HEX encoding
CREATE OR REPLACE FUNCTION public.fn_verify_manifest_sig(
  p_manifest jsonb,
  p_sig text,
  p_secret text
) RETURNS boolean
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT encode(hmac(convert_to(p_manifest::text, 'utf8'), convert_to(p_secret, 'utf8'), 'sha256'), 'hex') = p_sig
$$;

-- 5) Wrapper that raises on mismatch
CREATE OR REPLACE FUNCTION public.fn_assert_manifest_sig(
  p_manifest jsonb,
  p_sig text,
  p_secret text
) RETURNS void
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  IF NOT public.fn_verify_manifest_sig(p_manifest, p_sig, p_secret) THEN
    RAISE EXCEPTION 'manifest_signature_mismatch';
  END IF;
END;
$$;
