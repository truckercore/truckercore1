-- docs/supabase/legal_download_audit.sql
-- Legal download audit table (idempotent). Safe to re-run.

create extension if not exists pgcrypto;

create table if not exists public.legal_download_audit (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  user_id uuid not null,
  doc_type text not null check (doc_type in ('quote','msa','dpa','sla','other')),
  doc_id uuid not null,
  downloaded_at timestamptz not null default now(),
  meta jsonb not null default '{}'::jsonb
);

create index if not exists idx_legal_download_audit_org_time on public.legal_download_audit (org_id, downloaded_at desc);

alter table public.legal_download_audit enable row level security;

-- Read within org only (optional; adjust as needed)
DO $$ BEGIN
  DROP POLICY IF EXISTS legal_download_audit_read_org ON public.legal_download_audit;
  CREATE POLICY legal_download_audit_read_org ON public.legal_download_audit
  FOR SELECT TO authenticated
  USING (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
END $$;

-- Inserts should be performed by service role/API only; do not grant insert/update/delete to authenticated
REVOKE INSERT, UPDATE, DELETE ON public.legal_download_audit FROM authenticated;
