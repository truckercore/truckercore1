-- docs/supabase/sso_scim_health.sql
-- SSO/SCIM health tables, RLS, and helper functions. Idempotent and safe to re-run.

create extension if not exists pgcrypto;

-- Per-org SSO health and telemetry
create table if not exists public.sso_health (
  org_id uuid primary key,
  last_success_at timestamptz,
  last_error_at timestamptz,
  last_error_code text,
  last_self_check_at timestamptz,
  self_check_ok boolean,
  idp text,
  attempts_24h int not null default 0,
  failures_24h int not null default 0,
  updated_at timestamptz not null default now()
);

alter table public.sso_health enable row level security;
DO $$ BEGIN
  DROP POLICY IF EXISTS sso_health_read_org ON public.sso_health;
  CREATE POLICY sso_health_read_org ON public.sso_health
  FOR SELECT TO authenticated
  USING (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
END $$;

-- writes only via service role (Edge)
GRANT SELECT ON public.sso_health TO authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.sso_health FROM authenticated;

-- SCIM provisioning audit snapshots
create table if not exists public.scim_audit (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  idp text not null,
  run_started_at timestamptz not null default now(),
  run_finished_at timestamptz,
  status text not null default 'running' check (status in ('running','success','partial','failed')),
  created_count int not null default 0,
  updated_count int not null default 0,
  deactivated_count int not null default 0,
  error_count int not null default 0,
  errors jsonb not null default '[]'::jsonb,
  meta jsonb not null default '{}'::jsonb
);
create index if not exists idx_scim_audit_org_time on public.scim_audit (org_id, run_started_at desc);

alter table public.scim_audit enable row level security;
DO $$ BEGIN
  DROP POLICY IF EXISTS scim_audit_read_org ON public.scim_audit;
  CREATE POLICY scim_audit_read_org ON public.scim_audit
  FOR SELECT TO authenticated
  USING (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
END $$;

GRANT SELECT ON public.scim_audit TO authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.scim_audit FROM authenticated;

-- Optional helper functions
-- Update SSO success timestamp
create or replace function public.fn_sso_mark_success(p_org_id uuid, p_idp text)
returns void language sql security definer as $$
  insert into public.sso_health(org_id, last_success_at, idp, attempts_24h, updated_at, self_check_ok)
  values (p_org_id, now(), p_idp, 1, now(), true)
  on conflict (org_id) do update
  set last_success_at = excluded.last_success_at,
      idp = excluded.idp,
      attempts_24h = public.sso_health.attempts_24h + 1,
      failures_24h = public.sso_health.failures_24h,
      updated_at = now(),
      self_check_ok = true;
$$;

-- Update SSO error snapshot
create or replace function public.fn_sso_mark_error(p_org_id uuid, p_idp text, p_code text)
returns void language sql security definer as $$
  insert into public.sso_health(org_id, last_error_at, last_error_code, idp, attempts_24h, failures_24h, updated_at, self_check_ok)
  values (p_org_id, now(), p_code, p_idp, 1, 1, now(), false)
  on conflict (org_id) do update
  set last_error_at = excluded.last_error_at,
      last_error_code = excluded.last_error_code,
      idp = excluded.idp,
      attempts_24h = public.sso_health.attempts_24h + 1,
      failures_24h = public.sso_health.failures_24h + 1,
      updated_at = now(),
      self_check_ok = false;
$$;

-- Begin/finish SCIM audit run
create or replace function public.fn_scim_run_begin(p_org_id uuid, p_idp text, p_meta jsonb default '{}'::jsonb)
returns uuid language sql security definer as $$
  insert into public.scim_audit(org_id, idp, meta) values (p_org_id, p_idp, p_meta)
  returning id;
$$;

create or replace function public.fn_scim_run_finish(p_run_id uuid, p_status text,
  p_created int, p_updated int, p_deactivated int, p_errors int, p_errs jsonb)
returns void language sql security definer as $$
  update public.scim_audit
  set run_finished_at = now(),
      status = p_status,
      created_count = p_created,
      updated_count = p_updated,
      deactivated_count = p_deactivated,
      error_count = p_errors,
      errors = p_errs
  where id = p_run_id;
$$;

revoke all on function public.fn_sso_mark_success(uuid,text) from public;
revoke all on function public.fn_sso_mark_error(uuid,text,text) from public;
revoke all on function public.fn_scim_run_begin(uuid,text,jsonb) from public;
revoke all on function public.fn_scim_run_finish(uuid,text,int,int,int,int,jsonb) from public;
grant execute on function public.fn_sso_mark_success(uuid,text) to service_role;
grant execute on function public.fn_sso_mark_error(uuid,text,text) to service_role;
grant execute on function public.fn_scim_run_begin(uuid,text,jsonb) to service_role;
grant execute on function public.fn_scim_run_finish(uuid,text,int,int,int,int,jsonb) to service_role;

-- Rotation reminders (optional)
create table if not exists public.rotation_reminders (
  org_id uuid not null,
  kind text not null check (kind in ('oidc_client_secret','scim_token')),
  last_rotated_at timestamptz not null default now(),
  primary key (org_id, kind)
);

alter table public.rotation_reminders enable row level security;
DO $$ BEGIN
  DROP POLICY IF EXISTS rotation_reminders_read ON public.rotation_reminders;
  CREATE POLICY rotation_reminders_read ON public.rotation_reminders FOR SELECT TO authenticated USING (
    org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','')
  );
  DROP POLICY IF EXISTS rotation_reminders_write ON public.rotation_reminders;
  CREATE POLICY rotation_reminders_write ON public.rotation_reminders FOR INSERT TO authenticated WITH CHECK (
    org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','')
  );
  DROP POLICY IF EXISTS rotation_reminders_update ON public.rotation_reminders;
  CREATE POLICY rotation_reminders_update ON public.rotation_reminders FOR UPDATE TO authenticated USING (
    org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','')
  ) WITH CHECK (
    org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','')
  );
END $$;
