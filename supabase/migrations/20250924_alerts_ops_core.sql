-- 20250924_alerts_ops_core.sql
-- Purpose: Alert ops schema per spec (alert_ops, notifier suppression with org, deliveries, escalations FK),
-- org-aware notifier helpers, retention prune, and metrics views based on alert_ops.
-- Idempotent and compatible with existing repo schema. Safe to re-run.

-- 1) Ops log for alert generation, deliveries, escalations
create table if not exists public.alert_ops (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  code text not null,
  severity text not null check (severity in ('info','warning','critical','p1','p0')),
  alert_key text not null,  -- channel-agnostic key e.g. 'sso:failrate:24h'
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_alert_ops_org_time on public.alert_ops (org_id, created_at desc);
create index if not exists idx_alert_ops_key_time on public.alert_ops (alert_key, created_at desc);

alter table public.alert_ops enable row level security;
-- Read allowed for authenticated within org
create policy if not exists alert_ops_read_org on public.alert_ops
for select to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

-- 2) Notifier suppression (cooldown) — extend existing table if present
create table if not exists public.notifier_suppression (
  channel text not null,
  alert_key text not null,
  last_notified_at timestamptz not null default now(),
  level text not null default 'info', -- legacy columns kept for compatibility
  primary key (channel, alert_key)
);
-- Add new columns required by spec (non-destructive)
alter table if exists public.notifier_suppression
  add column if not exists org_id uuid,
  add column if not exists last_sent_at timestamptz,
  add column if not exists last_severity text;
-- Prefer new columns; ensure a supporting unique index on (channel, alert_key, org_id)
create unique index if not exists notifier_suppression_channel_key_org_uniq
  on public.notifier_suppression (channel, alert_key, org_id);

alter table public.notifier_suppression enable row level security;
create policy if not exists notifier_supp_read_org on public.notifier_suppression
for select to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
-- writes only via service role
revoke insert, update, delete on public.notifier_suppression from authenticated;

-- 3) Delivery tracking (per-channel)
create table if not exists public.alert_deliveries (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  channel text not null, -- 'slack'|'teams'|'email'
  alert_key text not null,
  severity text not null,
  delivered_at timestamptz not null default now(),
  meta jsonb not null default '{}'::jsonb
);
create index if not exists idx_alert_deliv_org_time on public.alert_deliveries (org_id, delivered_at desc);

alter table public.alert_deliveries enable row level security;
create policy if not exists alert_deliv_read_org on public.alert_deliveries
for select to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
revoke insert, update, delete on public.alert_deliveries from authenticated;

-- 4) Escalations link (to auto-unsnooze logic reference)
create table if not exists public.alert_escalations (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  alert_id uuid null,
  code text not null,
  from_severity text not null,
  to_severity text not null,
  escalated_at timestamptz not null default now(),
  meta jsonb not null default '{}'::jsonb
);
-- Ensure FK to alert_ops
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints tc
    WHERE tc.table_schema='public' AND tc.table_name='alert_escalations' AND tc.constraint_type='FOREIGN KEY'
      AND tc.constraint_name='alert_escalations_alert_fk'
  ) THEN
    ALTER TABLE public.alert_escalations
      ADD CONSTRAINT alert_escalations_alert_fk
      FOREIGN KEY (alert_id) REFERENCES public.alert_ops(id) ON DELETE CASCADE;
  END IF;
END $$;
create index if not exists idx_alert_escal_org_time on public.alert_escalations (org_id, escalated_at desc);

alter table public.alert_escalations enable row level security;
create policy if not exists alert_escal_read_org on public.alert_escalations
for select to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

-- 5) Utility functions (service role)
-- Org-aware cooldown check
create or replace function public.notifier_should_send(p_channel text, p_alert_key text, p_org_id uuid, p_cooldown_min int default 30)
returns boolean
language plpgsql
security definer
as $$
declare v_last record;
begin
  select * into v_last
  from public.notifier_suppression
  where channel = p_channel and alert_key = p_alert_key and org_id = p_org_id
  limit 1;

  if v_last is null then
    return true;
  end if;

  -- Prefer new column last_sent_at; fallback to legacy last_notified_at
  if (now() - coalesce(v_last.last_sent_at, v_last.last_notified_at)) > (p_cooldown_min || ' minutes')::interval then
    return true;
  end if;

  return false;
end $$;

create or replace function public.notifier_mark_sent(p_channel text, p_alert_key text, p_org_id uuid, p_severity text)
returns void
language plpgsql
security definer
as $$
begin
  insert into public.notifier_suppression(channel, alert_key, org_id, last_sent_at, last_severity, last_notified_at, level)
  values (p_channel, p_alert_key, p_org_id, now(), p_severity, now(), p_severity)
  on conflict (channel, alert_key, org_id)
  do update set last_sent_at = excluded.last_sent_at,
               last_severity = excluded.last_severity,
               last_notified_at = excluded.last_notified_at,
               level = excluded.level;
end $$;

-- Severity-aware suppression override (escalation)
create or replace function public.notifier_should_send_with_escalation(
  p_channel text, p_alert_key text, p_org_id uuid, p_current_severity text
) returns boolean
language plpgsql
security definer
as $$
declare v_last record;
declare rnk_current int;
declare rnk_last int;
begin
  select * into v_last from public.notifier_suppression
  where channel = p_channel and alert_key = p_alert_key and org_id = p_org_id
  limit 1;

  if v_last is null then return true; end if;

  rnk_current := case lower(p_current_severity)
                   when 'p0' then 4 when 'p1' then 3 when 'critical' then 3 when 'warning' then 1 else 0 end;
  rnk_last    := case lower(coalesce(v_last.last_severity, v_last.level))
                   when 'p0' then 4 when 'p1' then 3 when 'critical' then 3 when 'warning' then 1 else 0 end;

  if rnk_current > rnk_last then
    return true; -- escalate overrides cooldown
  end if;

  if (now() - coalesce(v_last.last_sent_at, v_last.last_notified_at)) > interval '30 minutes' then
    return true;
  end if;

  return false;
end $$;

revoke all on function public.notifier_should_send(text,text,uuid,int) from public, anon, authenticated;
revoke all on function public.notifier_mark_sent(text,text,uuid,text) from public, anon, authenticated;
revoke all on function public.notifier_should_send_with_escalation(text,text,uuid,text) from public, anon, authenticated;
grant execute on function public.notifier_should_send(text,text,uuid,int) to service_role;
grant execute on function public.notifier_mark_sent(text,text,uuid,text) to service_role;
grant execute on function public.notifier_should_send_with_escalation(text,text,uuid,text) to service_role;

-- 6) Retention helper (prune) — returns deleted count for alert_ops only
-- Replace legacy void variant if present to align with spec
DROP FUNCTION IF EXISTS public.prune_alert_ops(int);
create or replace function public.prune_alert_ops(p_days int default 90)
returns int
language plpgsql
security definer
as $$
declare v_count int; begin
  delete from public.alert_deliveries where delivered_at < now() - (p_days || ' days')::interval;
  delete from public.alert_escalations where escalated_at < now() - (p_days || ' days')::interval;
  delete from public.alert_ops where created_at < now() - (p_days || ' days')::interval returning 1 into v_count;
  return coalesce(v_count,0);
end $$;

revoke all on function public.prune_alert_ops(int) from public, anon, authenticated;
grant execute on function public.prune_alert_ops(int) to service_role;

-- 7) Metrics views (summary, weekly bounds, export)
-- Summary: counts by severity, last 24h
create or replace view public.v_alert_summary as
select
  org_id,
  count(*) filter (where created_at >= now() - interval '24 hours') as alerts_24h,
  count(*) filter (where severity in ('p0','p1','critical') and created_at >= now() - interval '24 hours') as high_24h,
  max(created_at) as last_alert_at
from public.alert_ops
group by org_id;

-- Weekly bounds per code
create or replace view public.v_alert_week_bounds as
select
  org_id,
  code,
  date_trunc('week', created_at)::date as week_start,
  min(created_at) as first_seen,
  max(created_at) as last_seen,
  count(*) as occurrences
from public.alert_ops
group by org_id, code, date_trunc('week', created_at)
order by org_id, week_start desc;

-- Export dataset (include payload and delivery correlation)
create or replace view public.v_alert_export as
select
  o.org_id,
  o.code,
  o.severity,
  o.alert_key,
  o.payload,
  o.created_at as window_start,
  (
    select min(d.delivered_at)
    from public.alert_deliveries d
    where d.org_id = o.org_id
      and d.alert_key = o.alert_key
      and d.delivered_at >= o.created_at
  ) as first_delivery_at
from public.alert_ops o;

-- 8) Sanity helpers (optional)
-- Tables exist + RLS check (manual):
-- select relname, relrowsecurity from pg_class where relname in ('alert_ops','notifier_suppression','alert_deliveries','alert_escalations') order by relname;
-- Views present (manual):
-- select table_name from information_schema.views where table_schema='public' and table_name in ('v_alert_week_bounds','v_alert_summary','v_alert_export') order by table_name;
-- Functions present (manual):
-- select routine_name from information_schema.routines where routine_schema='public' and routine_name in ('prune_alert_ops','notifier_should_send','notifier_mark_sent','notifier_should_send_with_escalation') order by routine_name;
