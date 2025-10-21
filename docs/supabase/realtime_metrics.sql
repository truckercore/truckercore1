-- docs/supabase/realtime_metrics.sql
-- Realtime heartbeat metric (subscriptions/active org) and event latency schemas + RPCs.
-- Idempotent and safe to re-run.

create extension if not exists pgcrypto;

-- Heartbeat: per-org active subscription counters and last ping
create table if not exists public.realtime_heartbeat (
  org_id uuid primary key,
  active_subscriptions int not null default 0,
  last_ping_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.realtime_heartbeat enable row level security;
create policy if not exists hb_read_org on public.realtime_heartbeat
  for select to authenticated
  using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
-- writes via service/edge only
revoke insert, update, delete on public.realtime_heartbeat from authenticated;

-- Event latency measures (publisher timestamp vs receipt)
create table if not exists public.realtime_latency (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  channel text not null,
  event_type text not null,
  published_at timestamptz not null,
  received_at timestamptz not null default now(),
  latency_ms int generated always as (greatest(0, round(extract(epoch from (received_at - published_at)) * 1000))) stored,
  ok boolean not null default true,
  meta jsonb not null default '{}'::jsonb
);
create index if not exists idx_rtl_org_time on public.realtime_latency (org_id, received_at desc);
alter table public.realtime_latency enable row level security;
create policy if not exists rtl_read_org on public.realtime_latency
  for select to authenticated
  using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
revoke insert, update, delete on public.realtime_latency from authenticated;

-- Helper RPCs (service role)
create or replace function public.fn_heartbeat_ping(p_org_id uuid, p_active int)
returns void language sql security definer as $$
  insert into public.realtime_heartbeat (org_id, active_subscriptions, last_ping_at, updated_at)
  values (p_org_id, p_active, now(), now())
  on conflict (org_id) do update
  set active_subscriptions = excluded.active_subscriptions,
      last_ping_at = excluded.last_ping_at,
      updated_at = now();
$$;
revoke all on function public.fn_heartbeat_ping(uuid,int) from public;
grant execute on function public.fn_heartbeat_ping(uuid,int) to service_role;

create or replace function public.fn_realtime_latency_log(
  p_org_id uuid, p_channel text, p_event_type text, p_published_at timestamptz, p_ok boolean, p_meta jsonb default '{}'::jsonb
) returns uuid language sql security definer as $$
  insert into public.realtime_latency (org_id, channel, event_type, published_at, ok, meta)
  values (p_org_id, p_channel, p_event_type, p_published_at, p_ok, p_meta)
  returning id;
$$;
revoke all on function public.fn_realtime_latency_log(uuid,text,text,timestamptz,boolean,jsonb) from public;
grant execute on function public.fn_realtime_latency_log(uuid,text,text,timestamptz,boolean,jsonb) to service_role;

-- Optional: view for active org heartbeat + latency summary
create or replace view public.v_realtime_org_health as
select
  h.org_id,
  h.active_subscriptions,
  h.last_ping_at,
  max(l.received_at) as last_event_at,
  avg(nullif(l.latency_ms,0)) filter (where l.received_at >= now() - interval '1 day') as avg_latency_ms_24h
from public.realtime_heartbeat h
left join public.realtime_latency l on l.org_id = h.org_id and l.received_at >= now() - interval '7 days'
group by h.org_id, h.active_subscriptions, h.last_ping_at;
