-- 20250924_identity_org_export.sql
-- Purpose: Core identity/org settings, SCIM/SSO events, SOC2 evidence, export gating, and helper RPCs.
-- Safe to re-run (idempotent) in Supabase.

-- === Extensions ===
create extension if not exists "uuid-ossp";
create extension if not exists pgcrypto;

-- === Updated-at helper ===
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

-- === Enums ===
DO $$ BEGIN CREATE TYPE public.idp_kind AS ENUM ('oidc','saml'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.scim_op AS ENUM ('provision','deprovision','update','reconcile'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.audit_kind AS ENUM ('access_review','secret_rotation','rls_test','cicd_event','export','admin_change','system'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.export_level AS ENUM ('blocked','restricted','allowed'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.data_region  AS ENUM ('US','EU'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- === Org settings & IdP configs ===
create table if not exists public.org_settings (
  org_id uuid primary key,
  data_residency_region public.data_region not null default 'US',
  export_controls public.export_level not null default 'restricted',
  export_allowlist text[] null,
  saml_enabled boolean not null default false,
  oidc_enabled boolean not null default true,
  scim_enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
DO $$ BEGIN
  CREATE TRIGGER trg_org_settings_u BEFORE UPDATE ON public.org_settings FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

create table if not exists public.idp_configs (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  kind public.idp_kind not null,
  name text not null,
  -- OIDC
  oidc_issuer text null,
  oidc_client_id text null,
  oidc_client_secret text null,
  -- SAML
  saml_entity_id text null,
  saml_acs_url text null,
  saml_sp_entity_id text null,
  saml_idp_sso_url text null,
  saml_idp_cert text null,
  saml_nameid_format text null,
  -- SCIM
  scim_base_url text null,
  scim_bearer_token text null,
  -- Common
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (org_id, kind, name)
);
DO $$ BEGIN
  CREATE TRIGGER trg_idp_configs_u BEFORE UPDATE ON public.idp_configs FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- _me helper assumes profiles(user_id, org_id, is_admin)
create or replace view public._me as
select u.id as user_id, p.org_id, coalesce(p.is_admin,false) as is_admin
from auth.users u
join public.profiles p on p.user_id = u.id
where u.id = auth.uid();

-- RLS
alter table public.org_settings enable row level security;
alter table public.idp_configs  enable row level security;

DROP POLICY IF EXISTS sel_org_settings ON public.org_settings;
CREATE POLICY sel_org_settings ON public.org_settings
FOR SELECT USING (org_id = (select org_id from public._me));

DROP POLICY IF EXISTS upd_org_settings ON public.org_settings;
CREATE POLICY upd_org_settings ON public.org_settings
FOR UPDATE USING ((select is_admin from public._me) and org_id = (select org_id from public._me))
WITH CHECK (org_id = (select org_id from public._me));

DROP POLICY IF EXISTS sel_idp_configs ON public.idp_configs;
CREATE POLICY sel_idp_configs ON public.idp_configs
FOR SELECT USING (org_id = (select org_id from public._me));

DROP POLICY IF EXISTS ins_idp_configs ON public.idp_configs;
CREATE POLICY ins_idp_configs ON public.idp_configs
FOR INSERT WITH CHECK ((select is_admin from public._me) and org_id = (select org_id from public._me));

DROP POLICY IF EXISTS upd_idp_configs ON public.idp_configs;
CREATE POLICY upd_idp_configs ON public.idp_configs
FOR UPDATE USING ((select is_admin from public._me) and org_id = (select org_id from public._me));

-- === SCIM provision events ===
create table if not exists public.scim_provision_events (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  op public.scim_op not null,
  subject_type text not null,
  subject_id text not null,
  mapped_user_id uuid null,
  email text null,
  display_name text null,
  raw jsonb null,
  status text not null default 'success',
  error text null,
  occurred_at timestamptz not null default now()
);
create index if not exists scim_events_org_time_idx on public.scim_provision_events(org_id, occurred_at desc);

-- === SSO events ===
create table if not exists public.sso_events (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  idp_kind public.idp_kind not null,
  provider_name text not null,
  user_id uuid null,
  email text null,
  result text not null,
  reason text null,
  occurred_at timestamptz not null default now()
);
create index if not exists sso_events_org_time_idx on public.sso_events(org_id, occurred_at desc);

alter table public.scim_provision_events enable row level security;
alter table public.sso_events enable row level security;

DROP POLICY IF EXISTS sel_scim_events ON public.scim_provision_events;
CREATE POLICY sel_scim_events ON public.scim_provision_events FOR SELECT USING (org_id = (select org_id from public._me));
DROP POLICY IF EXISTS ins_scim_events ON public.scim_provision_events;
CREATE POLICY ins_scim_events ON public.scim_provision_events FOR INSERT WITH CHECK (org_id = (select org_id from public._me));

DROP POLICY IF EXISTS sel_sso_events ON public.sso_events;
CREATE POLICY sel_sso_events ON public.sso_events FOR SELECT USING (org_id = (select org_id from public._me));
DROP POLICY IF EXISTS ins_sso_events ON public.sso_events;
CREATE POLICY ins_sso_events ON public.sso_events FOR INSERT WITH CHECK (org_id = (select org_id from public._me));

-- Funnels / metrics views
create or replace view public.v_sso_adoption_30d as
select org_id,
       count(*) filter (where result='success')::int as sso_success,
       count(*) filter (where result='fail')::int    as sso_fail,
       count(distinct provider_name)                 as provider_count
from public.sso_events
where occurred_at >= now() - interval '30 days'
group by 1;

create or replace view public.v_scim_activity_30d as
select org_id,
       count(*) filter (where op='provision')    as users_provisioned,
       count(*) filter (where op='deprovision')  as users_deprovisioned,
       count(*) filter (where status='error')    as scim_errors
from public.scim_provision_events
where occurred_at >= now() - interval '30 days'
group by 1;

create or replace view public.v_sso_failure_rate_24h as
with a as (
  select org_id,
         count(*) filter (where result='fail')::int as failures_24h,
         count(*)::int as attempts_24h
  from public.sso_events
  where occurred_at >= now() - interval '24 hours'
  group by 1
)
select org_id, attempts_24h, failures_24h,
       case when attempts_24h = 0 then 0::numeric else failures_24h::numeric / attempts_24h end as failure_rate_24h
from a;

-- === SOC2 evidence: audit + logs ===
create table if not exists public.system_audit_events (
  id uuid primary key default gen_random_uuid(),
  org_id uuid null,
  kind public.audit_kind not null,
  actor_user_id uuid null,
  target text null,
  severity int not null default 1,
  detail jsonb null,
  occurred_at timestamptz not null default now()
);
create index if not exists system_audit_org_time_idx on public.system_audit_events(org_id, occurred_at desc);
alter table public.system_audit_events enable row level security;

DROP POLICY IF EXISTS sel_system_audit ON public.system_audit_events;
CREATE POLICY sel_system_audit ON public.system_audit_events
FOR SELECT USING (
  (org_id = (select org_id from public._me))
  or (org_id is null and exists (select 1 from public.profiles p where p.user_id = auth.uid() and p.is_admin = true))
);

DROP POLICY IF EXISTS ins_system_audit ON public.system_audit_events;
CREATE POLICY ins_system_audit ON public.system_audit_events FOR INSERT WITH CHECK (true);

-- Optional evidence tables
create table if not exists public.access_reviews (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  reviewed_at timestamptz not null default now(),
  reviewer_user_id uuid not null,
  summary text not null,
  detail jsonb null
);
create index if not exists access_reviews_org_time_idx on public.access_reviews(org_id, reviewed_at desc);

create table if not exists public.secrets_rotation_logs (
  id uuid primary key default gen_random_uuid(),
  scope text not null,
  rotated_at timestamptz not null default now(),
  rotated_by uuid null,
  meta jsonb null
);

create table if not exists public.rls_test_assertions (
  id uuid primary key default gen_random_uuid(),
  tested_at timestamptz not null default now(),
  table_name text not null,
  test_name text not null,
  passed boolean not null,
  details text null
);

create table if not exists public.cicd_audit_logs (
  id uuid primary key default gen_random_uuid(),
  pipeline text not null,
  commit_sha text not null,
  actor text null,
  status text not null,
  occurred_at timestamptz not null default now(),
  meta jsonb null
);

create or replace view public.v_soc2_evidence_7d as
select
  (select count(*) from public.access_reviews where reviewed_at      >= now()-interval '7 days') as access_reviews,
  (select count(*) from public.secrets_rotation_logs where rotated_at >= now()-interval '7 days') as secrets_rotations,
  (select count(*) from public.rls_test_assertions where tested_at    >= now()-interval '7 days' and not passed) as rls_failures,
  (select count(*) from public.cicd_audit_logs where occurred_at      >= now()-interval '7 days' and status='failed') as cicd_failures;

-- === Export gating ===
create table if not exists public.export_logs (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  actor_user_id uuid not null,
  artifact text not null,
  outcome text not null,
  reason text null,
  created_at timestamptz not null default now()
);
create index if not exists export_logs_org_time_idx on public.export_logs(org_id, created_at desc);

alter table public.export_logs enable row level security;
DROP POLICY IF EXISTS sel_export_logs ON public.export_logs;
CREATE POLICY sel_export_logs ON public.export_logs FOR SELECT USING (org_id = (select org_id from public._me));
DROP POLICY IF EXISTS ins_export_logs ON public.export_logs;
CREATE POLICY ins_export_logs ON public.export_logs FOR INSERT WITH CHECK (org_id = (select org_id from public._me));

create or replace view public.v_data_residency_watch as
select s.org_id, s.data_residency_region, 0::int as potential_violations
from public.org_settings s;

-- === Minimal RPCs to support SCIM stubs ===
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='is_active'
  ) THEN
    EXECUTE 'alter table public.profiles add column is_active boolean not null default true';
  END IF;
END $$;

create or replace function public.provision_user_for_org(p_org_id uuid, p_email text)
returns json language plpgsql security definer as $$
declare v_user_id uuid;
begin
  v_user_id := gen_random_uuid();
  insert into public.profiles (user_id, org_id, email, is_active)
  values (v_user_id, p_org_id, p_email, true);
  return json_build_object('user_id', v_user_id, 'email', p_email);
end $$;
revoke all on function public.provision_user_for_org(uuid, text) from public;
grant execute on function public.provision_user_for_org(uuid, text) to service_role;

create or replace function public.set_user_active_state(p_user_id uuid, p_active boolean)
returns void language sql security definer as $$
  update public.profiles set is_active = p_active where user_id = p_user_id;
$$;
revoke all on function public.set_user_active_state(uuid, boolean) from public;
grant execute on function public.set_user_active_state(uuid, boolean) to service_role;
