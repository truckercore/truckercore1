-- docs/supabase/saml_config.sql
-- SAML per-tenant configuration schema, mapping table, and RLS policies.
-- Idempotent and safe to re-run.

create extension if not exists pgcrypto;

create table if not exists public.saml_configs (
  org_id uuid primary key,
  enabled boolean not null default false,
  sp_entity_id text not null,
  acs_urls text[] not null,
  sp_cert_pem text not null,
  sp_key_kid text null,
  idp_entity_id text not null,
  idp_metadata_url text null,
  idp_metadata_xml text null,
  idp_sso_url text null,
  idp_slo_url text null,
  idp_cert_pem text null,
  nameid_format text null,
  sig_alg text not null default 'rsa-sha256',
  digest_alg text not null default 'sha256',
  clock_skew_seconds int not null default 120,
  group_attr text not null default 'Groups',
  email_attr text not null default 'Email',
  name_attr text not null default 'Name',
  org_attr text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.saml_group_role_map (
  org_id uuid not null,
  idp_group text not null,
  role text not null check (role in ('corp_admin','regional_manager','location_manager','fleet_manager','dispatcher','safety','broker','driver')),
  primary key (org_id, idp_group, role)
);

alter table public.saml_configs enable row level security;
alter table public.saml_group_role_map enable row level security;

-- Helper to read JWT claims (shared pattern in repo)
create or replace function public.jwt_claim(claim text)
returns text stable language sql as $$ select coalesce(current_setting('request.jwt.claims', true)::json->>claim, '') $$;

-- Read own org config
create policy saml_cfg_read_org on public.saml_configs
for select to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

-- Admin writes (corp_admin within org)
create policy saml_cfg_write_admin on public.saml_configs
for all to authenticated
using (
  org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','') and
  (coalesce(current_setting('request.jwt.claims', true)::json->'app_roles','[]'::json) ? 'corp_admin')
) with check (
  org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','') and
  (coalesce(current_setting('request.jwt.claims', true)::json->'app_roles','[]'::json) ? 'corp_admin')
);

-- Group→role map policies
create policy saml_map_read_org on public.saml_group_role_map
for select to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

create policy saml_map_write_admin on public.saml_group_role_map
for all to authenticated
using (
  org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','') and
  (coalesce(current_setting('request.jwt.claims', true)::json->'app_roles','[]'::json) ? 'corp_admin')
) with check (
  org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','') and
  (coalesce(current_setting('request.jwt.claims', true)::json->'app_roles','[]'::json) ? 'corp_admin')
);

-- Trigger to bump updated_at on changes (optional)
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end; $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'tr_saml_configs_touch'
  ) THEN
    CREATE TRIGGER tr_saml_configs_touch BEFORE UPDATE ON public.saml_configs
    FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();
  END IF;
END $$;
