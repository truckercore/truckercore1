-- 20250924_identity_pkce_scim.sql
-- Idempotent identity/PKCE/SCIM/session/residency foundations

-- 0) Utilities: masking helper
create or replace function public.mask_email(p_email text)
returns text language sql immutable as $$
  select case
    when p_email is null then null
    when position('@' in p_email) = 0 then p_email
    else left(p_email, 2) || '***@' || split_part(p_email, '@', 2)
  end
$$;

-- 1) OIDC PKCE + state/nonce tracking
create table if not exists public.oidc_auth_flow (
  id uuid primary key default gen_random_uuid(),
  org_id uuid null,
  client_id text not null,
  state text not null unique,
  nonce text not null,
  code_challenge text not null,
  code_challenge_method text not null check (code_challenge_method in ('S256','plain')),
  redirect_uri text not null,
  created_at timestamptz not null default now(),
  used_at timestamptz null
);
create index if not exists idx_oidc_auth_flow_state on public.oidc_auth_flow(state);
alter table public.oidc_auth_flow enable row level security;
drop policy if exists oidc_flow_insert_any on public.oidc_auth_flow;
create policy oidc_flow_insert_any on public.oidc_auth_flow for insert to anon, authenticated with check (true);
drop policy if exists oidc_flow_read_self on public.oidc_auth_flow;
create policy oidc_flow_read_self on public.oidc_auth_flow for select to service_role using (true);

-- 2) App config secrets + rotation logging
create table if not exists public.app_secrets (
  key text primary key,
  value text not null,
  rotated_at timestamptz not null default now()
);

create table if not exists public.system_audit_events (
  id uuid primary key default gen_random_uuid(),
  kind text not null,
  org_id uuid null,
  actor text null,
  detail jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_system_audit_events_time on public.system_audit_events(created_at desc);
alter table public.system_audit_events enable row level security;
drop policy if exists sae_read_service on public.system_audit_events;
create policy sae_read_service on public.system_audit_events for select to service_role using (true);
drop policy if exists sae_read_org on public.system_audit_events;
create policy sae_read_org on public.system_audit_events for select to authenticated using (true);

-- 3) Role mapping rules + SSO event log
create table if not exists public.role_mappings (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  rules jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
create unique index if not exists idx_role_mappings_org on public.role_mappings(org_id);
alter table public.role_mappings enable row level security;
drop policy if exists rolemap_read_org on public.role_mappings;
create policy rolemap_read_org on public.role_mappings for select to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
drop policy if exists rolemap_write_service on public.role_mappings;
create policy rolemap_write_service on public.role_mappings for all to service_role using (true) with check (true);

create table if not exists public.sso_events (
  id uuid primary key default gen_random_uuid(),
  org_id uuid null,
  provider text not null,
  subject text not null,
  outcome text not null check (outcome in ('success','failure')),
  detail jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_sso_events_org_time on public.sso_events (org_id, created_at desc);
alter table public.sso_events enable row level security;
drop policy if exists sso_events_read_org on public.sso_events;
create policy sso_events_read_org on public.sso_events for select to authenticated
using (org_id is null or org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
drop policy if exists sso_events_write_service on public.sso_events;
create policy sso_events_write_service on public.sso_events for insert to service_role with check (true);

-- 4) SCIM provisioning events + idempotency
create table if not exists public.scim_provision_events (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  request_id text not null,
  external_id text not null,
  action text not null check (action in ('create','update','deprovision')),
  payload jsonb not null,
  status text not null default 'accepted' check (status in ('accepted','duplicate','failed','applied')),
  created_at timestamptz not null default now(),
  applied_at timestamptz null,
  unique (org_id, request_id)
);
create index if not exists idx_scim_ext on public.scim_provision_events (org_id, external_id);
alter table public.scim_provision_events enable row level security;
drop policy if exists scim_org_rw on public.scim_provision_events;
create policy scim_org_rw on public.scim_provision_events for all to service_role using (true) with check (true);

-- 5) Sessions (revocation on deprovision)
create table if not exists public.app_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  org_id uuid null,
  created_at timestamptz not null default now(),
  revoked_at timestamptz null
);
create index if not exists idx_app_sessions_user on public.app_sessions(user_id, revoked_at);
alter table public.app_sessions enable row level security;
drop policy if exists sessions_self_read on public.app_sessions;
create policy sessions_self_read on public.app_sessions for select to authenticated
using (user_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'sub',''));
drop policy if exists sessions_service_rw on public.app_sessions;
create policy sessions_service_rw on public.app_sessions for all to service_role using (true) with check (true);

-- 6) Residency controls
create table if not exists public.export_policies (
  org_id uuid primary key,
  region text not null,
  updated_at timestamptz not null default now()
);
alter table public.export_policies enable row level security;
drop policy if exists export_policy_read_org on public.export_policies;
create policy export_policy_read_org on public.export_policies for select to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

-- 7) Secrets rotation feed (optional dedicated)
create table if not exists public.secrets_rotation_logs (
  id uuid primary key default gen_random_uuid(),
  secret_key text not null,
  rotated_by text not null default 'system',
  rotated_at timestamptz not null default now(),
  note text null
);
alter table public.secrets_rotation_logs enable row level security;
drop policy if exists secrets_ro_read_service on public.secrets_rotation_logs;
create policy secrets_ro_read_service on public.secrets_rotation_logs for select to service_role using (true);
drop policy if exists secrets_ro_insert_service on public.secrets_rotation_logs;
create policy secrets_ro_insert_service on public.secrets_rotation_logs for insert to service_role with check (true);

-- RPC grant helpers (safe even if functions do not exist yet in some envs)
-- Wrap in DO blocks to avoid errors if functions are absent
do $$ begin
  perform 1 from pg_proc where proname = 'state_parking_in_bbox' and pg_get_function_identity_arguments(oid) = 'double precision, double precision, double precision, double precision, numeric';
  if found then
    revoke all on function public.state_parking_in_bbox(double precision,double precision,double precision,double precision,numeric) from public;
    grant execute on function public.state_parking_in_bbox(double precision,double precision,double precision,double precision,numeric) to authenticated, anon;
  end if;
end $$;

do $$ begin
  perform 1 from pg_proc where proname = 'state_weigh_in_bbox' and pg_get_function_identity_arguments(oid) = 'double precision, double precision, double precision, double precision, numeric';
  if found then
    revoke all on function public.state_weigh_in_bbox(double precision,double precision,double precision,double precision,numeric) from public;
    grant execute on function public.state_weigh_in_bbox(double precision,double precision,double precision,double precision,numeric) to authenticated, anon;
  end if;
end $$;
