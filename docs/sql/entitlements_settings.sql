-- Catalog
create table if not exists public.feature_catalog (
  key text primary key,
  description text,
  default_enabled boolean not null default false
);

-- Org/role entitlements
create table if not exists public.entitlements (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  role text not null,  -- 'driver','owner_op','fleet_admin','broker','shipper','3pl','admin'
  feature_key text not null references public.feature_catalog(key) on delete cascade,
  enabled boolean not null,
  source text not null default 'plan',  -- plan|promo|manual
  starts_at timestamptz default now(),
  ends_at timestamptz,
  unique (org_id, role, feature_key)
);

-- Per-user overrides
create table if not exists public.user_overrides (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  feature_key text not null references public.feature_catalog(key) on delete cascade,
  enabled boolean not null,
  reason text,
  starts_at timestamptz default now(),
  ends_at timestamptz,
  unique (user_id, feature_key)
);

-- Org settings
create table if not exists public.org_settings (
  org_id uuid primary key,
  currency text default 'USD',
  locale text default 'en',
  units text default 'imperial',   -- imperial|metric
  timezone text default 'America/New_York'
);

-- Resolver RPC: default -> org/role -> user
create or replace function public.resolve_entitlements_and_settings(
  p_org_id uuid,
  p_user_id uuid,
  p_role text
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  settings jsonb;
  feats jsonb := '{}'::jsonb;
begin
  select jsonb_build_object(
    'currency', currency,
    'locale', locale,
    'units', units,
    'timezone', timezone
  ) into settings
  from public.org_settings where org_id = p_org_id;

  if settings is null then
    settings := jsonb_build_object('currency','USD','locale','en','units','imperial','timezone','America/New_York');
  end if;

  -- Catalog defaults
  select coalesce(jsonb_object_agg(fc.key, to_jsonb(fc.default_enabled)),'{}'::jsonb)
  into feats
  from public.feature_catalog fc;

  -- Org/role entitlements (active window)
  select feats || coalesce(jsonb_object_agg(e.feature_key, to_jsonb(e.enabled)),'{}'::jsonb)
  into feats
  from public.entitlements e
  where e.org_id = p_org_id and e.role = p_role
    and coalesce(e.starts_at <= now(), true)
    and coalesce(e.ends_at > now(), true);

  -- Per-user overrides (active window)
  select feats || coalesce(jsonb_object_agg(uo.feature_key, to_jsonb(uo.enabled)),'{}'::jsonb)
  into feats
  from public.user_overrides uo
  where uo.user_id = p_user_id
    and coalesce(uo.starts_at <= now(), true)
    and coalesce(uo.ends_at > now(), true);

  -- Feature canary + global kill-switch overlay
  feats := (
    select jsonb_object_agg(c.fk,
      case
        when coalesce(fr.disabled_globally,false) then false
        when coalesce(array_length(fr.canary_orgs,1),0) > 0
             then ((feats->>c.fk)::boolean) and (p_org_id = any(fr.canary_orgs))
        else (feats->>c.fk)::boolean
      end)
    from (select key as fk from public.feature_catalog) c
    left join public.feature_rollouts fr on fr.feature_key = c.fk
  );

  return jsonb_build_object('settings', settings, 'features', feats);
end $$;

-- RLS read-only (writes via admin APIs only)
alter table public.entitlements enable row level security;
alter table public.user_overrides enable row level security;
alter table public.org_settings enable row level security;

drop policy if exists entitlements_ro on public.entitlements;
create policy entitlements_ro on public.entitlements
for select to authenticated
using ((auth.jwt()->>'app_org_id')::uuid = org_id);

drop policy if exists org_settings_ro on public.org_settings;
create policy org_settings_ro on public.org_settings
for select to authenticated
using ((auth.jwt()->>'app_org_id')::uuid = org_id);

drop policy if exists user_overrides_ro on public.user_overrides;
create policy user_overrides_ro on public.user_overrides
for select to authenticated
using (
  auth.uid() = user_id
  or (coalesce(auth.jwt()->'app_roles','[]'::json) ? 'admin')
  or (coalesce(auth.jwt()->'app_roles','[]'::json) ? 'fleet_admin')
);

-- Seed features
insert into public.feature_catalog(key, description, default_enabled) values
  ('ai.prescriptive','Prescriptive AI recommendations', false),
  ('community.forums','Driver forums/community', true),
  ('billing.invoices','Create and pay invoices', true),
  ('market.tenders','Create/respond to tenders', true)
on conflict (key) do nothing;
