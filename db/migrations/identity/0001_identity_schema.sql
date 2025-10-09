begin;

-- SAML configuration per org
create table if not exists public.saml_configs (
  org_id uuid primary key,
  enabled boolean not null default false,
  sp_entity_id text not null,
  acs_urls text[] not null,
  sp_cert_pem text not null,
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

-- Map IdP group -> app role
create table if not exists public.saml_group_role_map (
  org_id uuid not null,
  idp_group text not null,
  role text not null check (role in ('corp_admin','regional_manager','location_manager','fleet_manager','dispatcher','safety','broker','driver')),
  primary key (org_id, idp_group, role)
);

-- SCIM shadow users
create table if not exists public.scim_users (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  auth_user_id uuid null,
  external_id text not null,
  user_name text not null,
  given_name text null,
  family_name text null,
  email text not null,
  active boolean not null default true,
  roles text[] not null default '{}',
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (org_id, external_id)
);

-- SCIM groups
create table if not exists public.scim_groups (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  external_id text not null,
  display_name text not null,
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (org_id, external_id)
);

-- Group members
create table if not exists public.scim_group_members (
  group_id uuid not null references public.scim_groups(id) on delete cascade,
  user_id uuid not null references public.scim_users(id) on delete cascade,
  primary key (group_id, user_id)
);

-- Org attributes synced via SCIM (optional)
create table if not exists public.org_attributes (
  org_id uuid primary key,
  billing_plan text not null default 'free',
  fleet_size_cap int not null default 0,
  updated_at timestamptz not null default now()
);

-- Identity audit trail
create table if not exists public.identity_audit (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  kind text not null check (kind in ('saml_assertion','scim_create','scim_update','scim_delete','scim_group_op')),
  actor text null,
  subject text null,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- RLS posture
alter table public.saml_configs enable row level security;
alter table public.saml_group_role_map enable row level security;
alter table public.scim_users enable row level security;
alter table public.scim_groups enable row level security;
alter table public.scim_group_members enable row level security;
alter table public.org_attributes enable row level security;
alter table public.identity_audit enable row level security;

create policy saml_cfg_read_org on public.saml_configs for select to authenticated
  using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
create policy saml_cfg_write_admin on public.saml_configs for all to authenticated
  using (
    org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','')
    and (coalesce(current_setting('request.jwt.claims', true)::json->'app_roles','[]'::json) ? 'corp_admin')
  );

create policy scim_users_read_org on public.scim_users for select to authenticated
  using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

revoke insert, update, delete on public.scim_users, public.scim_groups, public.scim_group_members, public.identity_audit from authenticated;
grant select on public.scim_groups, public.scim_group_members, public.identity_audit, public.org_attributes to authenticated;

-- helpful indexes
create index if not exists idx_scim_users_org_external on public.scim_users (org_id, external_id);
create index if not exists idx_scim_groups_org_external on public.scim_groups (org_id, external_id);

comment on table public.saml_configs is 'Per-org SAML settings';
comment on table public.scim_users is 'SCIM provisioned users (shadow)';
comment on table public.identity_audit is 'Audit records for identity flows';

commit;
