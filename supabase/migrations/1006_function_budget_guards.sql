-- 1006_function_budget_guards.sql
-- Purpose: Define per-function latency/error-rate budgets and emit alerts on breach.
-- Idempotent and additive.

-- 1) Budgets table
create table if not exists public.function_budgets (
  fn text primary key,
  max_p95_ms integer,                 -- null = ignore latency budget
  max_err_rate_pct numeric(5,2),      -- e.g., 1.00 = 1%
  window_minutes int not null default 60,
  enabled boolean not null default true,
  updated_at timestamptz not null default now()
);

-- Seed examples (align with slo_targets defaults but can be stricter for budgets)
insert into public.function_budgets(fn, max_p95_ms, max_err_rate_pct, window_minutes, enabled) values
  ('instant-pay', 500, 1.00, 60, true),
  ('generate-ifta-report', 800, 1.00, 60, true),
  ('optimizer', 300, 1.00, 60, true)
on conflict (fn) do update
  set max_p95_ms = excluded.max_p95_ms,
      max_err_rate_pct = excluded.max_err_rate_pct,
      window_minutes = excluded.window_minutes,
      enabled = excluded.enabled,
      updated_at = now();

-- 2) Rolling error-rate and latency snapshots per window
create or replace view public.fn_window_stats as
select
  b.fn,
  b.window_minutes,
  count(*) filter (where l.created_at >= now() - make_interval(mins => b.window_minutes)) as calls,
  coalesce(
    count(*) filter (where not l.success and l.created_at >= now() - make_interval(mins => b.window_minutes))
    * 100.0 / greatest(count(*) filter (where l.created_at >= now() - make_interval(mins => b.window_minutes)), 1)
  , 0) as err_rate_pct,
  percentile_disc(0.95) within group (order by l.duration_ms)
    filter (where l.created_at >= now() - make_interval(mins => b.window_minutes)) as p95_ms
from public.function_budgets b
left join public.function_audit_log l on l.fn = b.fn
where b.enabled
group by b.fn, b.window_minutes;

-- 3) Budget check: enqueue alerts on breach (dedup/suppression honored via enqueue_alert_if_not_muted)
create or replace function public.check_function_budgets()
returns void
language sql
security definer
set search_path=public
as $$
  with breaches as (
    select s.fn,
           s.err_rate_pct,
           s.p95_ms,
           b.max_err_rate_pct,
           b.max_p95_ms,
           b.window_minutes
    from public.fn_window_stats s
    join public.function_budgets b on b.fn = s.fn and b.enabled
    where (b.max_err_rate_pct is not null and s.err_rate_pct > b.max_err_rate_pct)
       or (b.max_p95_ms is not null and s.p95_ms > b.max_p95_ms)
  )
  select public.enqueue_alert_if_not_muted(
    case when (p95_ms > max_p95_ms) then 'fn_budget_latency_breach' else 'fn_budget_error_breach' end,
    jsonb_build_object(
      'fn', fn,
      'window_minutes', window_minutes,
      'err_rate_pct', err_rate_pct,
      'max_err_rate_pct', max_err_rate_pct,
      'p95_ms', p95_ms,
      'max_p95_ms', max_p95_ms
    )
  ) from breaches;
$$;

-- Index helpful for stats
create index if not exists idx_fn_audit_by_fn_time on public.function_audit_log (fn, created_at);

-- Suggested cron (documentation):
-- Every 15 min: select public.check_function_budgets();
