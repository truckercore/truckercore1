-- docs/sql/feature_canary.sql

create table if not exists public.feature_catalog (
  key text primary key,
  description text not null
);

create table if not exists public.feature_rollouts (
  feature_key text primary key references public.feature_catalog(key) on delete cascade,
  canary_orgs uuid[] default '{}',
  disabled_globally boolean not null default false,
  updated_at timestamptz not null default now()
);
alter table public.feature_rollouts enable row level security;
-- Org admins can read; edits via service/admin only
create policy feature_rollouts_read on public.feature_rollouts
for select to authenticated using (true);
revoke insert, update, delete on public.feature_rollouts from authenticated;

-- Resolver overlay (apply inside resolve_entitlements_and_settings after computing feats)
-- Example snippet to apply in resolver function body:
-- feats := (
--   select jsonb_object_agg(c.fk,
--     case
--       when coalesce(fr.disabled_globally,false) then false
--       when coalesce(array_length(fr.canary_orgs,1),0) > 0
--            then ((feats->>c.fk)::boolean) and (p_org_id = any(fr.canary_orgs))
--       else (feats->>c.fk)::boolean
--     end)
--   from (select key as fk from public.feature_catalog) c
--   left join public.feature_rollouts fr on fr.feature_key = c.fk
-- );
