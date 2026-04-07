-- Function failures materialized by hour
create table if not exists public.function_failures_hourly (
  ts timestamptz primary key,
  failures int not null default 0
);

create or replace function public.refresh_function_failures_hourly()
returns void language sql security definer set search_path=public as $$
  insert into public.function_failures_hourly(ts, failures)
  select date_trunc('hour', created_at) as ts,
         count(*) filter (where not success) as failures
  from public.function_audit_log
  where created_at >= now() - interval '48 hours'
  group by 1
  on conflict (ts) do update set failures = excluded.failures;
$$;

-- Simple rules & outbox for alerts (transport-agnostic)
create table if not exists public.alert_rules (
  id bigserial primary key,
  key text unique not null,               -- e.g., 'fn_failures_gt_N'
  threshold int not null default 5,
  window_minutes int not null default 60,
  enabled boolean not null default true
);

create table if not exists public.alert_outbox (
  id bigserial primary key,
  key text not null,
  payload jsonb not null,
  created_at timestamptz not null default now(),
  delivered_at timestamptz
);

create or replace function public.check_function_failure_alerts()
returns void language plpgsql security definer set search_path=public as $$
begin
  -- ensure hourly snapshot is fresh
  perform public.refresh_function_failures_hourly();

  -- find threshold breaches in the last rule.window
  insert into public.alert_outbox(key, payload)
  select 'fn_failures_gt_N' as key,
         jsonb_build_object(
           'window_minutes', r.window_minutes,
           'threshold', r.threshold,
           'since', (now() - make_interval(mins => r.window_minutes))::timestamptz,
           'failures', coalesce((
             select sum(f.failures)
             from public.function_failures_hourly f
             where f.ts >= now() - make_interval(mins => r.window_minutes)
           ),0)
         ) as payload
  from public.alert_rules r
  where r.enabled
    and r.key = 'fn_failures_gt_N'
    and coalesce((
      select sum(failures)
      from public.function_failures_hourly
      where ts >= now() - make_interval(mins => r.window_minutes)
    ),0) > r.threshold;
end;
$$;

-- Default rule (safe to run repeatedly)
insert into public.alert_rules(key, threshold, window_minutes, enabled)
values ('fn_failures_gt_N', 5, 60, true)
on conflict (key) do update set threshold = excluded.threshold, window_minutes = excluded.window_minutes, enabled = excluded.enabled;
