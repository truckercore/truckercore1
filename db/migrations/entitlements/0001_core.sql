begin;

create table if not exists entitlements (
  org_id uuid not null,
  feature_key text not null,                      -- e.g., 'ai_predictive_hos', 'roi_reports'
  enabled boolean not null default false,
  monthly_quota int,
  updated_at timestamptz not null default now(),
  primary key (org_id, feature_key)
);

create or replace function entitlements_check(p_org uuid, p_feature text)
returns boolean language sql stable as $$
  select coalesce((select enabled from entitlements where org_id = p_org and feature_key = p_feature limit 1), false);
$$;

commit;
