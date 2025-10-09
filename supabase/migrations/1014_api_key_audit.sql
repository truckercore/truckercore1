-- 1014_api_key_audit.sql
-- Audit events for privileged API key actions (create/rotate/revoke).

-- Use function_audit_log if present; otherwise create a minimal audit table.
DO $$ BEGIN
  IF to_regclass('public.function_audit_log') IS NULL THEN
    CREATE TABLE IF NOT EXISTS public.function_audit_log (
      id bigserial primary key,
      fn text not null,
      actor uuid null,
      payload_sha256 text not null,
      success boolean not null default true,
      error text null,
      duration_ms integer null,
      actor_ip text null,
      user_agent text null,
      created_at timestamptz not null default now()
    );
    CREATE INDEX IF NOT EXISTS idx_fn_audit_fn_time ON public.function_audit_log(fn, created_at desc);
  END IF;
END $$;

-- Helper to compute sha256 of JSONB (stable fingerprint)
create or replace function public._json_sha256(j jsonb)
returns text language sql immutable as $$
  select encode(digest(coalesce(j::text,'')::bytea, 'sha256'), 'hex')
$$;

-- RPC to record API key lifecycle events
create or replace function public.audit_api_key_action(
  p_action text,          -- 'create'|'rotate'|'revoke'
  p_actor uuid,           -- user id performing action (service role may pass null)
  p_key_id uuid,          -- id of the api key (or token) impacted
  p_meta jsonb default '{}'::jsonb,  -- optional metadata (reason, scope)
  p_ip text default null,
  p_ua text default null
)
returns void
language sql
security definer
set search_path=public
as $$
  insert into public.function_audit_log(fn, actor, payload_sha256, success, error, duration_ms, actor_ip, user_agent)
  values (
    'api_keys',
    p_actor,
    public._json_sha256(jsonb_build_object('action', p_action, 'key_id', p_key_id, 'meta', coalesce(p_meta,'{}'::jsonb))),
    true,
    null,
    null,
    p_ip,
    p_ua
  );
$$;

-- Optional: a dedicated table for human-friendly audit browsing
create table if not exists public.api_key_audit (
  id bigserial primary key,
  action text not null check (action in ('create','rotate','revoke')),
  actor uuid null,
  key_id uuid not null,
  meta jsonb not null default '{}'::jsonb,
  actor_ip text null,
  user_agent text null,
  created_at timestamptz not null default now()
);

create or replace function public.api_key_audit_log(
  p_action text,
  p_actor uuid,
  p_key_id uuid,
  p_meta jsonb default '{}'::jsonb,
  p_ip text default null,
  p_ua text default null
) returns void language sql security definer set search_path=public as $$
  insert into public.api_key_audit(action, actor, key_id, meta, actor_ip, user_agent)
  values (p_action, p_actor, p_key_id, coalesce(p_meta,'{}'::jsonb), p_ip, p_ua);
$$;