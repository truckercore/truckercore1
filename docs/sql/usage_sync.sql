-- Stripe metered sync (authoritative, idempotent)
-- Prepare a view for the current open period to sync to Stripe

create or replace view public.v_usage_to_sync as
select
  m.org_id,
  m.feature_key,
  date_trunc('month', now())::date as period_start,
  m.total_units
from public.usage_monthly m
where m.period = date_trunc('month', now());

-- Guard: only sync once per (org,feature,period), idempotent on upsert
create table if not exists public.stripe_usage_sync (
  org_id uuid not null,
  feature_key text not null,
  period_start date not null,
  quantity bigint not null,
  stripe_event_id text null,
  synced_at timestamptz not null default now(),
  primary key (org_id, feature_key, period_start)
);

create or replace function public.usage_sync_mark(
  p_org uuid, p_feature text, p_period date, p_qty bigint, p_evt text
) returns void language plpgsql as $$
begin
  insert into public.stripe_usage_sync(org_id, feature_key, period_start, quantity, stripe_event_id)
  values (p_org, p_feature, p_period, p_qty, p_evt)
  on conflict (org_id, feature_key, period_start) do update
    set quantity = excluded.quantity,
        stripe_event_id = coalesce(excluded.stripe_event_id, stripe_usage_sync.stripe_event_id),
        synced_at = now();
end $$;

-- Edge job: read v_usage_to_sync, call Stripe usage records API, then mark via usage_sync_mark()
