-- 997_cron_heartbeats.sql
create table if not exists public.cron_heartbeats (
  key text primary key,          -- e.g., 'notify-alerts', 'rollup_chunked'
  last_seen timestamptz not null default now()
);

-- Touch heartbeat at the end of each job
create or replace function public.touch_heartbeat(p_key text)
returns void
language sql
security definer
set search_path = public
as $$
  insert into public.cron_heartbeats(key, last_seen)
  values (p_key, now())
  on conflict (key) do update
    set last_seen = excluded.last_seen;
$$;

-- Alert if a heartbeat hasn't updated within max_age minutes
-- Requires: public.alert_outbox table with columns (key text, payload jsonb)
create or replace function public.check_heartbeat(p_key text, max_age_minutes int)
returns void
language sql
security definer
set search_path = public
as $$
  with stale as (
    select 1
    from public.cron_heartbeats
    where key = p_key
      and last_seen < now() - make_interval(mins => max_age_minutes)
  )
  insert into public.alert_outbox(key, payload)
  select
    'cron_stale',
    jsonb_build_object(
      'key', p_key,
      'max_age_minutes', max_age_minutes,
      'last_seen', (select last_seen from public.cron_heartbeats where key = p_key)
    )
  where exists (select 1 from stale);
$$;
