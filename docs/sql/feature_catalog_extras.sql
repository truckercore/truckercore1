-- Feature Catalog Extras: indexes, audit trail, lifecycle, rate-limit, hygiene (idempotent)

-- Performance indexes
create index if not exists ix_feature_presentations_key_env_var_loc
  on public.feature_presentations(key, env, variant, locale)
  include (active, price_id, headline, blurb, badge, runbook_url);

create index if not exists ix_feature_overrides_org_key_active
  on public.feature_overrides(org_id, key, active)
  include (price_id, headline, blurb, tier_override);

-- Audit trail (SOC-friendly)
create table if not exists public.feature_audit(
  id bigserial primary key,
  table_name text not null,
  op text not null,
  key text,
  old jsonb,
  new jsonb,
  actor uuid default auth.uid(),
  at timestamptz default now()
);

create or replace function public.feature_audit_trg()
returns trigger language plpgsql as $$
begin
  insert into public.feature_audit(table_name, op, key, old, new)
  values (tg_table_name, tg_op, coalesce(NEW.key, OLD.key), to_jsonb(OLD), to_jsonb(NEW));
  return NEW;
end $$;

-- Attach triggers (idempotent)
DROP TRIGGER IF EXISTS fa_catalog  ON public.feature_catalog; 
CREATE TRIGGER fa_catalog  AFTER INSERT OR UPDATE OR DELETE ON public.feature_catalog       FOR EACH ROW EXECUTE FUNCTION public.feature_audit_trg();
DROP TRIGGER IF EXISTS fa_present  ON public.feature_presentations; 
CREATE TRIGGER fa_present  AFTER INSERT OR UPDATE OR DELETE ON public.feature_presentations FOR EACH ROW EXECUTE FUNCTION public.feature_audit_trg();
DROP TRIGGER IF EXISTS fa_override ON public.feature_overrides; 
CREATE TRIGGER fa_override AFTER INSERT OR UPDATE OR DELETE ON public.feature_overrides     FOR EACH ROW EXECUTE FUNCTION public.feature_audit_trg();

-- Lifecycle fields + filtered view
alter table if exists public.feature_catalog
  add column if not exists deprecated_at timestamptz,
  add column if not exists sunset_at timestamptz;

create or replace view public.v_features_active as
select *
from public.feature_catalog
where (deprecated_at is null or deprecated_at > now())
  and (sunset_at     is null or sunset_at     > now());

-- Variant hygiene view (flag too many variants)
create or replace view public.v_feature_variant_gaps as
select key, env,
       array_agg(distinct variant order by variant) as variants,
       count(*) as rows
from public.feature_presentations
where active
group by key, env
having cardinality(array_agg(distinct variant)) > 2;

-- Rate-limit table (per-user per minute)
create table if not exists public.feature_catalog_rate(
  user_id uuid not null,
  minute timestamptz not null,
  hits int not null default 0,
  primary key (user_id, minute)
);

-- Override safety: price_id must exist in stripe_price_map (if present)
DO $$ BEGIN
  IF to_regclass('public.stripe_price_map') IS NOT NULL THEN
    ALTER TABLE public.feature_overrides
      ADD CONSTRAINT IF NOT EXISTS fo_price_fk
      FOREIGN KEY (price_id) REFERENCES public.stripe_price_map(price_id);
  END IF;
EXCEPTION WHEN others THEN NULL; END $$;

-- Allow-list table for overrides (optional guard for ops)
create table if not exists public.feature_override_allow(
  org_id uuid not null,
  key text not null,
  primary key (org_id, key)
);
