-- =============================================================
-- Feature Catalog Pack (server-driven upsell/catalog)
-- Safe to re-run (idempotent)
-- =============================================================

-- 0) Helpers (skip if already present)
create or replace function public.app_role() returns text
language sql stable as $$ select coalesce(auth.jwt()->>'app_role','') $$;

create or replace function public.app_org() returns uuid
language sql stable as $$ select nullif(auth.jwt()->>'app_org_id','')::uuid $$;

-- 1) Canonical features (one row per feature key)
create table if not exists public.feature_catalog (
  key              text primary key,          -- e.g., 'fleet.ai_capacity'
  tier             text not null check (tier in ('free','premium','ai')),
  is_experimental  boolean not null default false,
  owner            text,
  created_at       timestamptz default now(),
  updated_at       timestamptz default now()
);

-- 2) Presentation & pricing by environment (prod/staging/dev) and variant (A/B) + i18n
create table if not exists public.feature_presentations (
  id            uuid primary key default gen_random_uuid(),
  key           text references public.feature_catalog(key) on delete cascade,
  env           text not null check (env in ('prod','staging','dev')),
  variant       text not null default 'A',                -- 'A' | 'B' | ...
  locale        text not null default 'en',               -- i18n code
  headline      text not null,
  blurb         text,
  badge         text,                                     -- 'Premium', 'AI', etc.
  price_id      text,                                     -- Stripe price for checkout
  runbook_url   text,
  active        boolean not null default true,
  updated_at    timestamptz default now(),
  unique(key, env, variant, locale)
);

-- 3) Optional per-org overrides (for pilots/enterprise)
create table if not exists public.feature_overrides (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null,
  key           text not null references public.feature_catalog(key) on delete cascade,
  tier_override text,
  price_id      text,
  headline      text,
  blurb         text,
  active        boolean not null default true,
  updated_at    timestamptz default now(),
  unique(org_id, key)
);

-- 4) Price→tier mapping (create only if missing to avoid conflicts)
do $$ begin
  if to_regclass('public.stripe_price_map') is null then
    create table public.stripe_price_map (
      price_id   text primary key,
      tier       text not null check (tier in ('free','premium','ai')),
      ai_enabled boolean not null default false
    );
  end if;
exception when others then null; end $$;

-- 5) Resolved view (base preferences in-view; org overrides applied in API layer)
create or replace view public.v_feature_catalog_resolved as
with prefs as (
  select 'prod'::text as env, 'A'::text as variant, 'en'::text as locale
)
select
  c.key, c.tier, c.is_experimental, c.owner,
  coalesce(po.headline, p.headline)  as headline,
  coalesce(po.blurb, p.blurb)        as blurb,
  coalesce(po.price_id, p.price_id)  as price_id,
  coalesce(po.active, p.active)      as active,
  coalesce(po.tier_override, null)   as tier_override,
  p.badge, p.env, p.variant, p.locale,
  p.runbook_url
from public.feature_catalog c
join prefs pr on true
join lateral (
  select * from public.feature_presentations fp
  where fp.key = c.key and fp.env = pr.env and fp.active
  order by (fp.locale = pr.locale) desc, (fp.variant = pr.variant) desc
  limit 1
) p on true
left join public.feature_overrides po
  on po.key = c.key and po.active = true;

-- 6) RLS
alter table public.feature_catalog enable row level security;
alter table public.feature_presentations enable row level security;
alter table public.feature_overrides enable row level security;
alter table public.stripe_price_map enable row level security;

-- READ for everyone (safe catalogue data)
drop policy if exists fc_read on public.feature_catalog;
create policy fc_read on public.feature_catalog for select using (true);

drop policy if exists fp_read on public.feature_presentations;
create policy fp_read on public.feature_presentations for select using (true);

drop policy if exists spm_read on public.stripe_price_map;
create policy spm_read on public.stripe_price_map for select using (true);

-- Overrides are org-scoped read
drop policy if exists fo_read on public.feature_overrides;
create policy fo_read on public.feature_overrides for select using (public.app_org() = org_id);

-- Writes: admin/service role only (edge functions should use service role)
drop policy if exists fc_admin_write on public.feature_catalog;
create policy fc_admin_write on public.feature_catalog
for all using (public.app_role() in ('admin','fleet_admin'))
with check (public.app_role() in ('admin','fleet_admin'));

drop policy if exists fp_admin_write on public.feature_presentations;
create policy fp_admin_write on public.feature_presentations
for all using (public.app_role() in ('admin','fleet_admin'))
with check (public.app_role() in ('admin','fleet_admin'));

drop policy if exists fo_admin_write on public.feature_overrides;
create policy fo_admin_write on public.feature_overrides
for all using (public.app_role() in ('admin','fleet_admin'))
with check (public.app_role() in ('admin','fleet_admin'));

drop policy if exists spm_admin_write on public.stripe_price_map;
create policy spm_admin_write on public.stripe_price_map
for all using (public.app_role() in ('admin','fleet_admin'))
with check (public.app_role() in ('admin','fleet_admin'));

-- 7) Touch updated_at triggers
create or replace function public.touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists fp_u on public.feature_presentations;
create trigger fp_u before update on public.feature_presentations
for each row execute function public.touch_updated_at();

drop trigger if exists fo_u on public.feature_overrides;
create trigger fo_u before update on public.feature_overrides
for each row execute function public.touch_updated_at();

-- 8) Seeds (examples; safe to re-run)
insert into public.feature_catalog(key, tier, is_experimental, owner) values
 ('driver.ai_route','ai',true,'ml'),
 ('fleet.ai_capacity','ai',false,'ml'),
 ('broker.ai_matching','ai',true,'ml'),
 ('driver.load_board','premium',false,'growth')
on conflict do nothing;

insert into public.feature_presentations(key, env, variant, locale, headline, blurb, badge, price_id, runbook_url) values
 ('fleet.ai_capacity','prod','A','en','AI Capacity Forecasting','Predict lane imbalances 3–72h out','AI','price_ai_123','https://docs/runbooks/ai'),
 ('driver.load_board','prod','A','en','Load Board','Find and book loads faster','Premium','price_prem_456','https://docs/runbooks/premium')
on conflict do nothing;

-- 9) KPI view (observability)
create or replace view public.v_feature_catalog_kpis as
select
  (select count(*) from public.feature_catalog) as features,
  (select count(*) from public.feature_presentations where active) as active_presentations,
  (select count(*) from public.feature_overrides where active) as active_overrides,
  (select count(*) from public.feature_presentations fp
     left join public.stripe_price_map spm on spm.price_id = fp.price_id
     where fp.price_id is not null and spm.price_id is null) as unmapped_prices;
