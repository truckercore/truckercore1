-- docs/supabase/manifest_security.sql
-- Org-scoped HMAC keys, nonce replay cache, manifest policy, and audit RPCs.
-- Idempotent and safe to re-run.

create extension if not exists pgcrypto;

-- HMAC keys per org
create table if not exists public.org_hmac_keys (
  org_id uuid not null,
  kid text not null,
  key_bytes bytea not null,
  active boolean not null default false,
  next_window boolean not null default false,
  not_before timestamptz not null default now(),
  not_after timestamptz null,
  created_at timestamptz not null default now(),
  primary key (org_id, kid)
);
create index if not exists idx_hmac_active on public.org_hmac_keys (org_id, active, next_window);

-- Nonce replay cache
create table if not exists public.manifest_nonces (
  org_id uuid not null,
  nonce text not null,
  ts timestamptz not null,
  primary key (org_id, nonce)
);

-- Org manifest policy (version & max age)
create table if not exists public.manifest_policy (
  org_id uuid primary key,
  minimum_supported_version text not null,
  max_age_seconds int not null default 300,
  updated_at timestamptz not null default now()
);

-- Key rotation & verification audit
create table if not exists public.key_audit (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  kid text null,
  action text not null check (action in ('rotation','verify_fail')),
  reason text null,
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_key_audit_org_time on public.key_audit(org_id, created_at desc);

-- RPC helpers (security definer)
create or replace function public.fn_key_rotation_audit(p_org_id uuid, p_kid text, p_reason text, p_meta jsonb default '{}'::jsonb)
returns void language sql security definer as $$
  insert into public.key_audit (org_id, kid, action, reason, meta)
  values (p_org_id, p_kid, 'rotation', p_reason, coalesce(p_meta,'{}'::jsonb));
$$;

create or replace function public.fn_verify_fail_audit(p_org_id uuid, p_kid text, p_reason text, p_meta jsonb default '{}'::jsonb)
returns void language sql security definer as $$
  insert into public.key_audit (org_id, kid, action, reason, meta)
  values (p_org_id, p_kid, 'verify_fail', p_reason, coalesce(p_meta,'{}'::jsonb));
$$;

revoke all on function public.fn_key_rotation_audit(uuid,text,text,jsonb) from public;
revoke all on function public.fn_verify_fail_audit(uuid,text,text,jsonb) from public;
grant execute on function public.fn_key_rotation_audit(uuid,text,text,jsonb) to service_role;
grant execute on function public.fn_verify_fail_audit(uuid,text,text,jsonb) to service_role;
