-- 1016_anomaly_quota_pii.sql
-- Purpose: per-tenant anomaly model tuning (thresholds), quota auto-tuning suggestions,
--          basic PII redaction rules and audit/export retention utilities.
-- All objects are idempotent. SECURITY DEFINER functions set search_path=public and avoid dynamic SQL.

-- 1) Per-tenant anomaly thresholds (generic; can be used by anomaly checkers)
create table if not exists public.tenant_anomaly_thresholds (
  tenant_id uuid not null,
  code text not null,                        -- e.g., 'bid_price', 'bid_velocity', 'api_latency_kind'
  iqr_multiplier numeric(6,3) null,         -- e.g., 1.5 for IQR rule
  velocity_threshold int null,              -- e.g., bids per 10m
  p95_ms_threshold int null,                -- e.g., p95 latency for kind
  updated_at timestamptz not null default now(),
  primary key (tenant_id, code)
);

-- Helper to read thresholds, with sensible defaults
create or replace function public.get_anomaly_thresholds(
  p_tenant uuid,
  p_code text
) returns table(code text, iqr_multiplier numeric, velocity_threshold int, p95_ms_threshold int)
language sql
stable
set search_path=public
as $$
  select
    coalesce(t.code, p_code) as code,
    coalesce(t.iqr_multiplier, 1.5) as iqr_multiplier,
    coalesce(t.velocity_threshold, 20) as velocity_threshold,
    coalesce(t.p95_ms_threshold, 5000) as p95_ms_threshold
  from public.tenant_anomaly_thresholds t
  where t.tenant_id = p_tenant and t.code = p_code
  union all
  select p_code, 1.5::numeric, 20::int, 5000::int
  where not exists (
    select 1 from public.tenant_anomaly_thresholds t2 where t2.tenant_id=p_tenant and t2.code=p_code
  )
  limit 1;
$$;

-- 2) Per-tenant quotas (suggestions only; non-enforcing)
create table if not exists public.tenant_quotas (
  tenant_id uuid primary key,
  daily_posts_limit int not null default 100,
  daily_bids_limit int not null default 500,
  soft_pct numeric not null default 0.80,
  updated_at timestamptz not null default now()
);

create table if not exists public.tenant_counters_daily (
  tenant_id uuid not null,
  day date not null default current_date,
  posts int not null default 0,
  bids int not null default 0,
  primary key (tenant_id, day)
);
create index if not exists idx_counters_tenant_day on public.tenant_counters_daily(tenant_id, day desc);

-- Rolling 30d usage
create or replace view public.tenant_usage_30d as
select
  tenant_id,
  max(day) as last_day,
  max(posts) as max_posts,
  max(bids) as max_bids,
  percentile_cont(0.95) within group (order by posts) as p95_posts,
  percentile_cont(0.95) within group (order by bids) as p95_bids,
  sum(posts) as posts_30d,
  sum(bids) as bids_30d
from public.tenant_counters_daily
where day >= current_date - interval '30 days'
group by tenant_id;

-- Suggestions view comparing p95 to current limits
create or replace view public.tenant_quota_suggestions as
select
  u.tenant_id,
  q.daily_posts_limit,
  q.daily_bids_limit,
  u.p95_posts,
  u.p95_bids,
  -- Suggest 20% headroom over 95th percentile, min 1
  greatest(1, ceil(coalesce(u.p95_posts,0) * 1.2))::int as suggested_posts_limit,
  greatest(1, ceil(coalesce(u.p95_bids,0) * 1.2))::int as suggested_bids_limit
from public.tenant_usage_30d u
left join public.tenant_quotas q on q.tenant_id = u.tenant_id;

-- Emitter: enqueue suggestions as advisory alerts (dedup covers repeats)
create or replace function public.suggest_quota_updates()
returns void
language sql
security definer
set search_path=public
as $$
  insert into public.alert_outbox(key, payload, dedupe_key, suppress_until)
  select 'quota_tuning_suggestion',
         jsonb_build_object(
           'tenant_id', s.tenant_id,
           'p95_posts', s.p95_posts,
           'p95_bids', s.p95_bids,
           'current_posts_limit', s.daily_posts_limit,
           'current_bids_limit', s.daily_bids_limit,
           'suggested_posts_limit', s.suggested_posts_limit,
           'suggested_bids_limit', s.suggested_bids_limit
         ),
         'quota:'||s.tenant_id::text||':'||public.json_sha256(
           jsonb_build_object('sp',s.suggested_posts_limit,'sb',s.suggested_bids_limit)
         ),
         now() + interval '1 day'
  from public.tenant_quota_suggestions s
  -- Only emit when suggestions exceed current limits
  where (s.suggested_posts_limit > coalesce(s.daily_posts_limit,0)
      or s.suggested_bids_limit  > coalesce(s.daily_bids_limit,0));
$$;

-- 3) PII Redaction rules and helpers
create table if not exists public.pii_redaction_rules (
  id bigserial primary key,
  key text not null unique,           -- field name to remove at top-level (simple helper)
  note text
);

-- Redact top-level keys present in rules
create or replace function public.redact_json(j jsonb)
returns jsonb
language sql
stable
set search_path=public
as $$
  select coalesce(
    (
      select jsonb_object_agg(k, v)
      from (
        select key as k, value as v
        from jsonb_each(j)
        where key not in (select key from public.pii_redaction_rules)
      ) s
    ), '{}'::jsonb
  );
$$;

-- 4) Retention: audit/events
create or replace function public.purge_function_audit_log(p_days int default 180)
returns int
language plpgsql
security definer
set search_path=public
as $$
declare v_count int; begin
  delete from public.function_audit_log where created_at < now() - (p_days || ' days')::interval;
  get diagnostics v_count = row_count;
  return v_count;
end; $$;

create or replace function public.purge_alerts_events(p_days int default 180)
returns int
language plpgsql
security definer
set search_path=public
as $$
declare v_count int; begin
  delete from public.alerts_events where triggered_at < now() - (p_days || ' days')::interval;
  get diagnostics v_count = row_count;
  return v_count;
end; $$;

-- Seed example redaction rules (safe to re-run)
insert into public.pii_redaction_rules(key, note) values
  ('ssn', 'Remove social security numbers if present'),
  ('credit_card', 'Remove credit card numbers if present'),
  ('password', 'Remove passwords')
on conflict (key) do nothing;
