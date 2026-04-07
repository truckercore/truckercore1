-- =============================================================
-- Usage Ops Watch: cron health, freshness lag, quota breach views,
-- and PII scrub logging. Idempotent and safe to re-run.
-- =============================================================

-- 1) Cron health ledger (generic)
create table if not exists public.cron_runs (
  id bigserial primary key,
  job text not null,
  ts timestamptz not null default now(),
  ok boolean not null default true,
  note text
);
create index if not exists idx_cron_runs_job_ts on public.cron_runs(job, ts desc);

-- Helper to mark a cron success/failure
create or replace function public.cron_mark(p_job text, p_ok boolean default true, p_note text default null)
returns void language sql as $$
  insert into public.cron_runs(job, ok, note) values (p_job, coalesce(p_ok,true), p_note)
$$;

-- 2) Cron health view (last 48h + latest per job)
create or replace view public.v_cron_health as
with last_48h as (
  select * from public.cron_runs where ts >= now() - interval '48 hours'
), latest as (
  select distinct on (job) job, ts, ok, note from public.cron_runs order by job, ts desc
)
select 'recent' as kind, job, ts, ok, note from last_48h
union all
select 'latest' as kind, job, ts, ok, note from latest
order by kind, job, ts desc;

-- 3) MV freshness lag for usage rollup (based on cron_runs entry)
-- Convention: job name 'usage-rollup-incremental'
create or replace view public.v_usage_refresh_lag as
select
  now() - coalesce((select ts from public.cron_runs where job='usage-rollup-incremental' order by ts desc limit 1), now() - interval '100 years') as lag,
  (extract(epoch from (now() - coalesce((select ts from public.cron_runs where job='usage-rollup-incremental' order by ts desc limit 1), now() - interval '100 years'))) / 3600.0) as lag_hours
;

-- 4) Quota breach views (current month)
create or replace view public.v_usage_quota_breaches_current as
with used as (
  select org_id, feature_key,
         sum(units) as used_units
  from public.usage_events
  where date_trunc('month', at) = date_trunc('month', now())
  group by 1,2
), q as (
  select org_id, feature_key, soft_limit, hard_limit
  from public.usage_quotas
  where period_start = date_trunc('month', now())::date
)
select u.org_id, u.feature_key, u.used_units, q.soft_limit, q.hard_limit,
  case
    when q.hard_limit is not null and u.used_units > q.hard_limit then 'hard_limit_exceeded'
    when q.soft_limit is not null and u.used_units > q.soft_limit then 'soft_limit_exceeded'
    else 'ok'
  end as status
from used u
join q on q.org_id=u.org_id and q.feature_key=u.feature_key
where (q.hard_limit is not null and u.used_units > q.hard_limit)
   or (q.soft_limit is not null and u.used_units > q.soft_limit);

create or replace view public.v_usage_quota_breaches_counts as
select
  count(*) filter (where status='hard_limit_exceeded') as hard_breaches,
  count(*) filter (where status='soft_limit_exceeded') as soft_breaches
from public.v_usage_quota_breaches_current;

-- 5) PII scrubbing log + wrapper
create table if not exists public.usage_pii_scrub_log (
  id bigserial primary key,
  ran_at timestamptz not null default now(),
  days_old int not null,
  affected_rows bigint not null
);

create or replace function public.usage_scrub_user_ids_log(days_old int default 90)
returns bigint language plpgsql as $$
declare n bigint;
begin
  n := public.usage_scrub_user_ids(days_old);
  insert into public.usage_pii_scrub_log(days_old, affected_rows) values (days_old, coalesce(n,0));
  return n;
end $$;

-- Candidates currently eligible for PII scrub (informational)
create or replace view public.v_usage_pii_candidates as
select count(*) as candidates
from public.usage_events
where user_id is not null
  and at < now() - make_interval(days=>90);
