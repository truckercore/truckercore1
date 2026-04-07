-- docs/supabase/entitlements_schema.sql
-- Entitlements schema for plans/org/user feature flags with overrides and expiry.
-- Idempotent. Safe to re-run. Assumes a minimal orgs table exists (public.orgs with id/org_id and optional plan_id).

create extension if not exists pgcrypto;

-- 0) Ensure orgs table exists with a plan_id column (non-destructive add)
DO $$ BEGIN
  IF to_regclass('public.orgs') IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'orgs' AND column_name = 'plan_id'
    ) THEN
      EXECUTE 'ALTER TABLE public.orgs ADD COLUMN plan_id text NULL';
    END IF;
  END IF;
END $$;

-- 1) Plans
create table if not exists public.plans (
  id text primary key,
  name text not null,
  created_at timestamptz not null default now()
);

-- Seed common plans
insert into public.plans (id, name)
values
  ('free','Free'),
  ('business','Business'),
  ('enterprise','Enterprise')
on conflict (id) do update set name = excluded.name;

-- 2) Features registry
create table if not exists public.features (
  key text primary key,
  description text not null
);

-- Seed features
insert into public.features (key, description) values
  ('sso','Single Sign-On (SAML/OIDC) login support'),
  ('white_label','White-label branding and custom domain'),
  ('exec_analytics','Executive analytics bundle'),
  ('promos_unlimited','Unlimited promo campaigns'),
  ('scanners','Barcode/QR scanners and in-store devices'),
  ('api_access','API access for integrations'),
  ('webhook_pos','POS webhook integration'),
  ('iot_fusion','IoT fusion for parking/fuel sensors')
on conflict (key) do update set description = excluded.description;

-- 3) Plan entitlements (default per plan)
create table if not exists public.plan_entitlements (
  plan_id text not null references public.plans(id) on delete cascade,
  feature_key text not null references public.features(key) on delete cascade,
  value jsonb not null default 'true'::jsonb,
  primary key (plan_id, feature_key)
);

create index if not exists idx_plan_entitlements_feature on public.plan_entitlements(feature_key);

-- 4) Org-level overrides
create table if not exists public.org_entitlements (
  org_id uuid not null,
  feature_key text not null references public.features(key) on delete cascade,
  value jsonb not null,
  reason text null,
  expires_at timestamptz null,
  created_by uuid null,
  created_at timestamptz not null default now(),
  primary key (org_id, feature_key)
);
create index if not exists idx_org_entitlements_active on public.org_entitlements(feature_key, expires_at);

-- 5) Optional user-level overrides (targeted trials)
create table if not exists public.user_entitlements (
  org_id uuid not null,
  user_id uuid not null,
  feature_key text not null references public.features(key) on delete cascade,
  value jsonb not null,
  expires_at timestamptz null,
  created_at timestamptz not null default now(),
  primary key (org_id, user_id, feature_key)
);
create index if not exists idx_user_entitlements_active on public.user_entitlements(feature_key, expires_at);

-- 6) RLS
alter table public.plans enable row level security;
alter table public.features enable row level security;
alter table public.plan_entitlements enable row level security;
alter table public.org_entitlements enable row level security;
alter table public.user_entitlements enable row level security;

-- Helper to read claim value
create or replace function public.jwt_claim(claim text)
returns text
stable
language sql
as $$
  select coalesce(current_setting('request.jwt.claims', true)::json->>claim, '');
$$;

-- plans/features/plan_entitlements: read for authenticated; write only for service role or admin
DO $$ BEGIN
  DROP POLICY IF EXISTS plans_read ON public.plans;
  CREATE POLICY plans_read ON public.plans FOR SELECT TO authenticated USING (true);
  DROP POLICY IF EXISTS plans_write_admin ON public.plans;
  CREATE POLICY plans_write_admin ON public.plans FOR ALL TO authenticated USING (
    false
  ) WITH CHECK (false);
END $$;
-- Allow full access to service_role via bypass RLS at connection level; for admin role claim, add a separate policy
DO $$ BEGIN
  DROP POLICY IF EXISTS plans_write_admin_role ON public.plans;
  CREATE POLICY plans_write_admin_role ON public.plans FOR ALL TO authenticated USING (
    public.jwt_claim('role') in ('admin')
  ) WITH CHECK (public.jwt_claim('role') in ('admin'));
END $$;

DO $$ BEGIN
  DROP POLICY IF EXISTS features_read ON public.features;
  CREATE POLICY features_read ON public.features FOR SELECT TO authenticated USING (true);
  DROP POLICY IF EXISTS features_write_admin_role ON public.features;
  CREATE POLICY features_write_admin_role ON public.features FOR ALL TO authenticated USING (
    public.jwt_claim('role') in ('admin')
  ) WITH CHECK (public.jwt_claim('role') in ('admin'));
END $$;

DO $$ BEGIN
  DROP POLICY IF EXISTS plan_ent_read ON public.plan_entitlements;
  CREATE POLICY plan_ent_read ON public.plan_entitlements FOR SELECT TO authenticated USING (true);
  DROP POLICY IF EXISTS plan_ent_write_admin_role ON public.plan_entitlements;
  CREATE POLICY plan_ent_write_admin_role ON public.plan_entitlements FOR ALL TO authenticated USING (
    public.jwt_claim('role') in ('admin')
  ) WITH CHECK (public.jwt_claim('role') in ('admin'));
END $$;

-- org_entitlements/user_entitlements: select where org_id = jwt.app_org_id; insert/update restricted to corp_admin or service_role
DO $$ BEGIN
  DROP POLICY IF EXISTS org_ent_select ON public.org_entitlements;
  CREATE POLICY org_ent_select ON public.org_entitlements FOR SELECT TO authenticated USING (
    org_id::text = public.jwt_claim('app_org_id')
  );
  DROP POLICY IF EXISTS org_ent_write ON public.org_entitlements;
  CREATE POLICY org_ent_write ON public.org_entitlements FOR INSERT TO authenticated WITH CHECK (
    org_id::text = public.jwt_claim('app_org_id') AND public.jwt_claim('org_role') in ('corp_admin')
  );
  DROP POLICY IF EXISTS org_ent_update ON public.org_entitlements;
  CREATE POLICY org_ent_update ON public.org_entitlements FOR UPDATE TO authenticated USING (
    org_id::text = public.jwt_claim('app_org_id') AND public.jwt_claim('org_role') in ('corp_admin')
  ) WITH CHECK (
    org_id::text = public.jwt_claim('app_org_id') AND public.jwt_claim('org_role') in ('corp_admin')
  );
  DROP POLICY IF EXISTS org_ent_delete ON public.org_entitlements;
  CREATE POLICY org_ent_delete ON public.org_entitlements FOR DELETE TO authenticated USING (
    org_id::text = public.jwt_claim('app_org_id') AND public.jwt_claim('org_role') in ('corp_admin')
  );
END $$;

DO $$ BEGIN
  DROP POLICY IF EXISTS user_ent_select ON public.user_entitlements;
  CREATE POLICY user_ent_select ON public.user_entitlements FOR SELECT TO authenticated USING (
    org_id::text = public.jwt_claim('app_org_id')
  );
  DROP POLICY IF EXISTS user_ent_write ON public.user_entitlements;
  CREATE POLICY user_ent_write ON public.user_entitlements FOR INSERT TO authenticated WITH CHECK (
    org_id::text = public.jwt_claim('app_org_id') AND public.jwt_claim('org_role') in ('corp_admin')
  );
  DROP POLICY IF EXISTS user_ent_update ON public.user_entitlements;
  CREATE POLICY user_ent_update ON public.user_entitlements FOR UPDATE TO authenticated USING (
    org_id::text = public.jwt_claim('app_org_id') AND public.jwt_claim('org_role') in ('corp_admin')
  ) WITH CHECK (
    org_id::text = public.jwt_claim('app_org_id') AND public.jwt_claim('org_role') in ('corp_admin')
  );
  DROP POLICY IF EXISTS user_ent_delete ON public.user_entitlements;
  CREATE POLICY user_ent_delete ON public.user_entitlements FOR DELETE TO authenticated USING (
    org_id::text = public.jwt_claim('app_org_id') AND public.jwt_claim('org_role') in ('corp_admin')
  );
END $$;

-- 7) Resolver function
-- Returns enabled, config, source ('user'|'org'|'plan'|'default') for a given org/feature/user.
create or replace function public.get_entitlement(p_org_id uuid, p_feature_key text, p_user_id uuid default null)
returns table(enabled boolean, config jsonb, source text)
stable
language plpgsql
as $$
DECLARE
  v_val jsonb;
  v_source text;
  v_plan text;
BEGIN
  -- user override if active
  SELECT ue.value INTO v_val
  FROM public.user_entitlements ue
  WHERE ue.org_id = p_org_id AND ue.user_id = p_user_id AND ue.feature_key = p_feature_key
    AND (ue.expires_at is null OR ue.expires_at > now())
  LIMIT 1;
  IF v_val IS NOT NULL THEN
    RETURN QUERY SELECT (CASE WHEN v_val = 'true'::jsonb THEN true WHEN v_val = 'false'::jsonb THEN false ELSE true END) AS enabled,
                         (CASE WHEN v_val IN ('true','false') THEN '{}'::jsonb ELSE v_val END) as config,
                         'user'::text as source;
    RETURN;
  END IF;

  -- org override if active
  SELECT oe.value INTO v_val
  FROM public.org_entitlements oe
  WHERE oe.org_id = p_org_id AND oe.feature_key = p_feature_key
    AND (oe.expires_at is null OR oe.expires_at > now())
  LIMIT 1;
  IF v_val IS NOT NULL THEN
    RETURN QUERY SELECT (CASE WHEN v_val = 'true'::jsonb THEN true WHEN v_val = 'false'::jsonb THEN false ELSE true END) AS enabled,
                         (CASE WHEN v_val IN ('true','false') THEN '{}'::jsonb ELSE v_val END) as config,
                         'org'::text as source;
    RETURN;
  END IF;

  -- plan default via org.plan_id (support either public.orgs.id or orgs.org_id PK naming)
  -- Attempt to read from public.orgs.plan_id by matching either id or org_id to p_org_id
  SELECT plan_id INTO v_plan FROM public.orgs WHERE (id = p_org_id OR org_id = p_org_id) LIMIT 1;
  IF v_plan IS NOT NULL THEN
    SELECT pe.value INTO v_val
    FROM public.plan_entitlements pe
    WHERE pe.plan_id = v_plan AND pe.feature_key = p_feature_key
    LIMIT 1;
  END IF;
  IF v_val IS NOT NULL THEN
    RETURN QUERY SELECT (CASE WHEN v_val = 'true'::jsonb THEN true WHEN v_val = 'false'::jsonb THEN false ELSE true END) AS enabled,
                         (CASE WHEN v_val IN ('true','false') THEN '{}'::jsonb ELSE v_val END) as config,
                         'plan'::text as source;
    RETURN;
  END IF;

  -- default false
  RETURN QUERY SELECT false as enabled, '{}'::jsonb as config, 'default'::text as source;
END;
$$;

-- 8) Helpful view to list resolved entitlements for an org across all features
create or replace view public.org_resolved_entitlements as
select
  o_id as org_id,
  f.key as feature_key,
  (r).enabled as enabled,
  (r).config as config,
  (r).source as source
from (
  select (case when id is null then org_id else id end) as o_id from public.orgs
) orgs_any
cross join public.features f
cross join lateral (
  select * from public.get_entitlement(orgs_any.o_id, f.key, null)
) r;

-- 9) Optional: seed baseline plan entitlements
-- Free: minimal
insert into public.plan_entitlements(plan_id, feature_key, value)
select 'free', f.key, 'false'::jsonb from public.features f
on conflict (plan_id, feature_key) do nothing;
-- Business: enable most except advanced
insert into public.plan_entitlements(plan_id, feature_key, value)
values
  ('business','promos_unlimited','true'::jsonb),
  ('business','scanners','true'::jsonb),
  ('business','api_access','true'::jsonb),
  ('business','webhook_pos','true'::jsonb)
on conflict (plan_id, feature_key) do nothing;
-- Enterprise: enable all
insert into public.plan_entitlements(plan_id, feature_key, value)
select 'enterprise', f.key, 'true'::jsonb from public.features f
on conflict (plan_id, feature_key) do nothing;
