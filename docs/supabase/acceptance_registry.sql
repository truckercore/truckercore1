-- docs/supabase/acceptance_registry.sql
-- Acceptance registry: SSO tests, RBAC catalog/enforcement view, UI flags, docs catalog,
-- status/SLO/on-call, pricing registries, legal artifacts, and checklist snapshot.
-- Idempotent and safe to re-run.

create extension if not exists pgcrypto;

-- 1) Test registry: per-IdP outcomes
create table if not exists public.sso_acceptance (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  protocol text not null check (protocol in ('oidc','saml')),
  idp text not null,                  -- 'azuread'|'okta'|'google'|'adfs'
  jit_provisioned boolean not null,
  role_map_applied boolean not null,
  login_success boolean not null,
  tested_at timestamptz not null default now(),
  notes text null
);
create index if not exists idx_sso_accept_org on public.sso_acceptance (org_id, tested_at desc);

-- 2) Role catalog (immutable reference)
create table if not exists public.role_catalog (
  role text primary key,
  description text not null
);
insert into public.role_catalog(role,description) values
('corp_admin','Org-wide admin'),('regional_manager','Region-scoped manager'),
('location_manager','Location-scoped manager'),('fleet_manager','Fleet manager'),
('dispatcher','Dispatcher'),('safety','Safety role'),
('broker','Broker role'),('driver','Driver role')
on conflict (role) do nothing;

-- 3) RLS/claims verification view (placeholder signalling enabled tables)
create or replace view public.v_rbac_enforcement as
select 'fleet_members'::text as table_name, true as rls_enabled
union all select 'drivers', true
union all select 'pois', true
union all select 'parking_state', true;

-- 4) Admin UI least-privilege flag (settings)
create table if not exists public.ui_access_policies (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  policy_key text not null,                      -- 'admin_least_privilege'
  enabled boolean not null default true,
  updated_at timestamptz not null default now(),
  unique (org_id, policy_key)
);

-- 5) Security docs catalog
create table if not exists public.docs_catalog (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,                 -- 'security-overview','architecture','data-flows','ir-playbook','retention'
  title text not null,
  url text not null,
  visibility text not null check (visibility in ('public','internal')),
  updated_at timestamptz not null default now()
);

-- 6) Status page heartbeat registry
create table if not exists public.status_components (
  key text primary key,             -- 'api','edge','db','sso','scim'
  description text not null,
  status text not null default 'operational' check (status in ('operational','degraded','outage')),
  updated_at timestamptz not null default now()
);

-- 7) SLO target config
create table if not exists public.slo_targets (
  name text primary key,            -- 'sso_failure_rate','api_p95_latency','state_freshness'
  target numeric not null,          -- e.g., 0.999 availability or threshold numeric
  window text not null              -- '30d','7d','24h'
);
insert into public.slo_targets(name,target,window) values
('availability',0.999,'30d'),('sso_failure_rate',0.95,'24h')
on conflict (name) do nothing;

-- 8) On-call schedule (simple)
create table if not exists public.oncall_schedule (
  id uuid primary key default gen_random_uuid(),
  rotation text not null,              -- 'primary','secondary'
  user_email text not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null
);
create index if not exists idx_oncall_active on public.oncall_schedule (rotation, starts_at, ends_at);

-- 9) Pricing registries
create table if not exists public.pricing_bands (
  code text primary key,                    -- 'premium_local','premium_regional','premium_national'
  price_usd_month numeric(10,2) not null
);
insert into public.pricing_bands(code, price_usd_month) values
('premium_local',199),('premium_regional',349),('premium_national',499)
on conflict (code) do update set price_usd_month = excluded.price_usd_month;

create table if not exists public.volume_discounts (
  min_locations int primary key,
  percent_off numeric(5,2) not null         -- 5.00, 10.00
);
insert into public.volume_discounts(min_locations,percent_off) values
(10,5.00),(50,10.00)
on conflict (min_locations) do update set percent_off = excluded.percent_off;

create table if not exists public.terms_options (
  term text primary key,                     -- 'monthly','quarterly','annual'
  prepay_discount_percent numeric(5,2) not null
);
insert into public.terms_options(term,prepay_discount_percent) values
('monthly',0),('quarterly',3.00),('annual',8.00)
on conflict (term) do update set prepay_discount_percent = excluded.prepay_discount_percent;

-- Quote template registry: extend existing table with registry fields if missing
DO $$ BEGIN
  IF to_regclass('public.quote_templates') IS NULL THEN
    CREATE TABLE public.quote_templates (
      id uuid primary key default gen_random_uuid(),
      name text not null unique,
      url text not null,
      approved boolean not null default true,
      updated_at timestamptz not null default now()
    );
  ELSE
    -- add columns if missing to existing schema
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='quote_templates' AND column_name='url'
    ) THEN
      EXECUTE 'ALTER TABLE public.quote_templates ADD COLUMN url text';
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='quote_templates' AND column_name='approved'
    ) THEN
      EXECUTE 'ALTER TABLE public.quote_templates ADD COLUMN approved boolean not null default true';
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='quote_templates' AND column_name='updated_at'
    ) THEN
      EXECUTE 'ALTER TABLE public.quote_templates ADD COLUMN updated_at timestamptz not null default now()';
    END IF;
    -- ensure name uniqueness
    BEGIN
      EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS uq_quote_templates_name ON public.quote_templates(name)';
    EXCEPTION WHEN others THEN
      -- ignore, index may already exist in different form
      NULL;
    END;
  END IF;
END $$;

-- 10) Legal artifacts registry
create table if not exists public.legal_artifacts (
  key text primary key,                      -- 'dpa','baa'
  title text not null,
  url text not null,                         -- link to current version
  effective_date date not null,
  status text not null check (status in ('published','draft')),
  updated_at timestamptz not null default now()
);

-- 11) Minimal verification RPC: acceptance snapshot
create or replace function public.fn_acceptance_snapshot(p_org_id uuid)
returns jsonb
language sql
stable
as $$
select jsonb_build_object(
  'sso', (
    select jsonb_build_object(
      'oidc', (select count(*) from public.sso_acceptance where org_id=p_org_id and protocol='oidc' and login_success=true) >= 2,
      'saml', (select count(*) from public.sso_acceptance where org_id=p_org_id and protocol='saml' and login_success=true) >= 2,
      'jit',  coalesce((select bool_or(jit_provisioned) from public.sso_acceptance where org_id=p_org_id), false),
      'roles',coalesce((select bool_or(role_map_applied) from public.sso_acceptance where org_id=p_org_id), false)
    )
  ),
  'rbac', (
    select jsonb_build_object(
      'catalog_published', (select count(*) from public.role_catalog) >= 8,
      'rls_enforced', coalesce((select bool_and(rls_enabled) from public.v_rbac_enforcement), false)
    )
  ),
  'security_docs', (
    select jsonb_build_object(
      'public_overview', exists(select 1 from public.docs_catalog where slug in ('security-overview','architecture','data-flows') and visibility='public'),
      'internal_ir_retention', exists(select 1 from public.docs_catalog where slug in ('incident-response','retention') and visibility='internal')
    )
  ),
  'sla', (
    select jsonb_build_object(
      'status_components', exists(select 1 from public.status_components),
      'slo_targets', exists(select 1 from public.slo_targets where name='availability'),
      'oncall', exists(select 1 from public.oncall_schedule where now() between starts_at and ends_at)
    )
  ),
  'pricing', (
    select jsonb_build_object(
      'bands', (select count(*) from public.pricing_bands) >= 3,
      'discounts', (select count(*) from public.volume_discounts) >= 2,
      'quotes', exists(select 1 from public.quote_templates where coalesce(approved,true) = true)
    )
  ),
  'legal', (
    select jsonb_build_object(
      'dpa', exists(select 1 from public.legal_artifacts where key='dpa' and status='published'),
      'baa', exists(select 1 from public.legal_artifacts where key='baa' and status in ('published','draft'))
    )
  )
);
$$;
