-- 20250924_alert_deliveries_retries.sql
-- Purpose: Robust alert delivery retries (columns + due index), exponential backoff + fail RPC,
-- suppression window policy, delivery integrity (dedupe + signing endpoints), and ops views.
-- All statements are idempotent and safe to re-run.

-- 1) Extend alert_deliveries with retry/health columns and helpful fields
alter table if exists public.alert_deliveries
  add column if not exists attempts int not null default 0,
  add column if not exists next_attempt_at timestamptz not null default now(),
  add column if not exists dead_letter boolean not null default false,
  add column if not exists last_error text,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists alert_id uuid,
  add column if not exists code text,
  add column if not exists target text;

-- Due index for dispatcher (process pending)
create index if not exists alert_deliveries_due_idx
  on public.alert_deliveries (next_attempt_at)
  where delivered_at is null and dead_letter = false;

-- 2) Backoff and fail helper RPCs (service-only)
create or replace function public.alert_delivery_backoff(p_attempts int)
returns interval language sql immutable as $$
  select least((power(2, greatest(p_attempts,0)) * 10)::int, 3600)::text::interval
$$;

-- Note: Repository uses UUID PK for alert_deliveries; implementing UUID variant
create or replace function public.alert_delivery_fail(p_id uuid, p_err text, p_max_attempts int default 10)
returns void language plpgsql security definer as $$
begin
  update public.alert_deliveries
  set attempts = attempts + 1,
      last_error = left(p_err, 2000),
      next_attempt_at = now() + public.alert_delivery_backoff(attempts),
      dead_letter = (attempts + 1) >= p_max_attempts
  where id = p_id and delivered_at is null;
end $$;

revoke all on function public.alert_delivery_fail(uuid,text,int) from public, anon, authenticated;
grant execute on function public.alert_delivery_fail(uuid,text,int) to service_role;

-- 3) Suppression window policy (server-side, tunable)
create table if not exists public.notifier_suppression_policy (
  code text primary key,
  window interval not null default interval '30 minutes',
  priority int not null default 100
);

create or replace function public.notifier_window_for(p_code text)
returns interval language sql stable as $$
  select coalesce((select window from public.notifier_suppression_policy where code = p_code),
                  interval '30 minutes')
$$;

-- 4) Delivery integrity: dedupe index (5-minute window) + signing endpoints
-- Ensure supporting columns exist above (alert_id, code, created_at)
create unique index if not exists alert_deliveries_dedupe_5m
on public.alert_deliveries (alert_id, channel, code, date_trunc('minute', created_at))
where created_at >= now() - interval '5 minutes';

create table if not exists public.notifier_endpoints (
  id bigserial primary key,
  channel text not null,
  target text not null,
  signing_secret text,
  active boolean not null default true,
  unique (channel, target)
);

alter table public.notifier_endpoints enable row level security;
create policy if not exists endpoints_read_admin on public.notifier_endpoints
for select to authenticated using (true); -- tighten if needed
revoke insert, update, delete on public.notifier_endpoints from authenticated;

-- 5) Ops views (delivery health and failures); guard optional alert_metrics stream
create or replace view public.v_alert_delivery_24h as
select
  count(*) as sent_total,
  sum((delivered_at is not null)::int) as delivered,
  sum((dead_letter)::int) as dead_lettered,
  round(100.0 * sum((delivered_at is not null)::int) / nullif(count(*),0), 2) as success_pct
from public.alert_deliveries
where created_at >= now() - interval '24 hours';

create or replace view public.v_alert_delivery_failures_24h as
select code, channel, coalesce(target,'') target,
       count(*) filter (where delivered_at is null and dead_letter=false) as pending,
       count(*) filter (where dead_letter=true) as dlq,
       max(last_error) as last_error
from public.alert_deliveries
where created_at >= now() - interval '24 hours'
group by code, channel, target
order by dlq desc, pending desc;

-- Create suppression savings view if alert_metrics exists; otherwise create an empty-compatible view
DO $$
BEGIN
  IF to_regclass('public.alert_metrics') IS NOT NULL THEN
    EXECUTE $$
      create or replace view public.v_notifier_suppression_savings_7d as
      select code,
             count(*) filter (where suppressed=true) as suppressed_msgs,
             count(*) filter (where suppressed=false) as sent_msgs
      from public.alert_metrics
      where at >= now() - interval '7 days'
      group by code
      order by suppressed_msgs desc;
    $$;
  ELSE
    EXECUTE $$
      create or replace view public.v_notifier_suppression_savings_7d as
      select cast(null as text) as code,
             0::bigint as suppressed_msgs,
             0::bigint as sent_msgs
      where false;
    $$;
  END IF;
END $$;

-- Notes:
-- - Dispatcher should iterate due rows (next_attempt_at <= now(), delivered_at is null, dead_letter=false),
--   attempt delivery, and call alert_delivery_fail(id, err) on failure; on success set delivered_at = now().
-- - notifier_endpoints.signing_secret can be used to HMAC sign outbound payloads per target.
