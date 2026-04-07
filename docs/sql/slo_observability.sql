-- =============================================================
-- SLO Observability Pack (Safe to re-run)
-- Catalog, targets (global/tenant), SLI events, RPC timing,
-- multi-window burn, alerts, rate limiting & governance views.
-- =============================================================

-- Extensions (idempotent)
create extension if not exists pgcrypto;

-- 0) Helpers (claims & roles) — idempotent
create or replace function public.current_org_id() returns uuid
language sql stable as $$
  select nullif(auth.jwt()->>'app_org_id','')::uuid
$$;

create or replace function public.current_role() returns text
language sql stable as $$
  select nullif(auth.jwt()->>'app_role','')
$$;

create or replace function public.current_user_id() returns uuid
language sql stable as $$
  select auth.uid()
$$;

create or replace function public.is_admin() returns boolean
language sql stable as $$
  select coalesce(public.current_role() in ('owner','admin','fleet_admin'), false)
$$;

-- 1) SLO Catalog & Targets (global + per-tenant overrides)
create table if not exists public.slo_catalog (
  key         text primary key,
  description text,
  sli_unit    text not null,          -- 'ms','ratio','count'
  owner       text,
  created_at  timestamptz default now()
);
alter table public.slo_catalog enable row level security;
create policy if not exists slo_catalog_ro on public.slo_catalog for select using (true);
create policy if not exists slo_catalog_rw on public.slo_catalog for all using (public.is_admin()) with check (public.is_admin());

create table if not exists public.slo_targets_global (
  key           text primary key references public.slo_catalog(key) on delete cascade,
  p95_ms        int,
  success_ratio numeric,
  window        text default '24h',
  updated_at    timestamptz default now()
);
alter table public.slo_targets_global enable row level security;
create policy if not exists slo_targets_global_ro on public.slo_targets_global for select using (true);
create policy if not exists slo_targets_global_rw on public.slo_targets_global for all using (public.is_admin()) with check (public.is_admin());

create table if not exists public.slo_targets_tenant (
  org_id        uuid not null,
  key           text not null references public.slo_catalog(key) on delete cascade,
  p95_ms        int,
  success_ratio numeric,
  window        text default '24h',
  updated_at    timestamptz default now(),
  primary key (org_id, key)
);
alter table public.slo_targets_tenant enable row level security;
create index if not exists idx_slo_targets_tenant_org on public.slo_targets_tenant(org_id);
create policy if not exists slo_targets_tenant_ro on public.slo_targets_tenant for select using (public.current_org_id() = org_id);
create policy if not exists slo_targets_tenant_rw on public.slo_targets_tenant for all using (public.is_admin() and public.current_org_id() = org_id)
  with check (public.is_admin() and public.current_org_id() = org_id);

-- 2) Generic SLI Events (multi-tenant)
create table if not exists public.sli_events (
  id         bigserial primary key,
  org_id     uuid not null,
  key        text not null references public.slo_catalog(key) on delete cascade,
  at         timestamptz not null default now(),
  value      numeric not null,
  labels     jsonb,
  source     text,
  created_at timestamptz default now()
);
alter table public.sli_events enable row level security;
create index if not exists idx_sli_events_org_at on public.sli_events(org_id, at desc);
create index if not exists idx_sli_events_key_org_at on public.sli_events(key, org_id, at desc);
create policy if not exists sli_events_ro on public.sli_events for select using (public.current_org_id() = org_id);
create policy if not exists sli_events_ins on public.sli_events for insert with check (public.current_org_id() = org_id);

-- Live Map latency SLI (derived)
create table if not exists public.live_map_ingest (
  id         bigserial primary key,
  org_id     uuid not null,
  vehicle_id uuid,
  device_ts  timestamptz not null,
  ingest_ts  timestamptz not null default now(),
  latency_ms int generated always as (
    greatest(0, (extract(epoch from (ingest_ts - device_ts))*1000)::int)
  ) stored
);
alter table public.live_map_ingest enable row level security;
create index if not exists idx_live_map_org_ingest on public.live_map_ingest(org_id, ingest_ts desc);
create policy if not exists live_map_ro on public.live_map_ingest for select using (public.current_org_id() = org_id);
create policy if not exists live_map_ins on public.live_map_ingest for insert with check (public.current_org_id() = org_id);

-- 3) RPC Timing (per-call SLIs)
do $$
begin
  alter table if exists public.function_invocations add column if not exists org_id uuid;
exception when undefined_table then
  create table public.function_invocations (
    id bigserial primary key,
    at timestamptz not null default now(),
    fn text not null,
    ms int not null,
    status text not null check (status in ('ok','error')),
    org_id uuid,
    user_id uuid,
    detail jsonb
  );
end $$;
alter table public.function_invocations enable row level security;
create index if not exists idx_fninv_org_at on public.function_invocations(org_id, at desc);
create policy if not exists fninv_ro on public.function_invocations for select using (org_id is null or public.current_org_id() = org_id);
create policy if not exists fninv_ins on public.function_invocations for insert with check (org_id is null or public.current_org_id() = org_id);

-- 4) Error-Budget Ledger & Multi-Window Burn
create table if not exists public.slo_rollups_daily (
  day       date not null,
  org_id    uuid not null,
  key       text not null references public.slo_catalog(key),
  good      bigint not null default 0,
  total     bigint not null default 0,
  p95_ms    int,
  updated_at timestamptz default now(),
  primary key (day, org_id, key)
);
alter table public.slo_rollups_daily enable row level security;
create index if not exists idx_slo_rollups_org_day on public.slo_rollups_daily(org_id, day desc);
create policy if not exists slo_rollups_ro  on public.slo_rollups_daily for select using (public.current_org_id() = org_id);
create policy if not exists slo_rollups_ins on public.slo_rollups_daily for insert with check (public.current_org_id() = org_id);
create policy if not exists slo_rollups_upd on public.slo_rollups_daily for update using (public.current_org_id() = org_id);

-- 24h status (RPC-focused; extend with sli_events as needed)
create or replace view public.v_slo_status_24h as
select
  st.org_id,
  sg.key,
  coalesce(st.p95_ms, sg.p95_ms)               as target_p95,
  coalesce(st.success_ratio, sg.success_ratio) as target_ratio,
  percentile_disc(0.95) within group (order by i.ms) as p95_obs,
  sum((i.status='ok')::int)::numeric / greatest(count(*),1) as success_ratio_obs
from public.slo_catalog sc
join public.slo_targets_global sg on sg.key = sc.key
left join public.slo_targets_tenant st on st.key = sg.key
left join public.function_invocations i on i.org_id = st.org_id
  and sc.key like 'rpc_%' and i.fn = substring(sc.key from 5)
where i.at > now() - interval '24 hours' or i.id is null
group by st.org_id, sg.key, st.p95_ms, st.success_ratio, sg.p95_ms, sg.success_ratio;

-- Pure events status for keys in sli_events
create or replace view public.v_slo_status_events_24h as
select
  e.org_id, e.key,
  coalesce(st.p95_ms, sg.p95_ms)               as target_p95,
  coalesce(st.success_ratio, sg.success_ratio) as target_ratio,
  percentile_disc(0.95) within group (order by e.value) as p95_obs,
  null::numeric as success_ratio_obs
from public.sli_events e
join public.slo_targets_global sg on sg.key = e.key
left join public.slo_targets_tenant st on st.key = e.key and st.org_id = e.org_id
where e.at > now() - interval '24 hours'
group by e.org_id, e.key, sg.p95_ms, st.p95_ms, sg.success_ratio, st.success_ratio;

-- Multi-window burn (5m & 60m) for RPCs
create or replace view public.v_slo_burn_multiwindow as
with i5 as (
  select org_id, fn as key, sum((status='error')::int) as err, count(*) as tot
  from public.function_invocations
  where at > now() - interval '5 minutes'
  group by 1,2
),
i60 as (
  select org_id, fn as key, sum((status='error')::int) as err, count(*) as tot
  from public.function_invocations
  where at > now() - interval '60 minutes'
  group by 1,2
)
select
  coalesce(i5.org_id, i60.org_id) as org_id,
  'rpc_'||coalesce(i5.key, i60.key) as key,
  i5.err::numeric/greatest(i5.tot,1)  as err5,
  i60.err::numeric/greatest(i60.tot,1) as err60
from i5 full join i60 using (org_id,key);

-- 5) Alerts (de-dupe, caps, state)
create table if not exists public.slo_alerts (
  id        bigserial primary key,
  org_id    uuid not null,
  key       text not null,
  severity  text not null check (severity in ('info','warn','p1','p2')),
  opened_at timestamptz not null default now(),
  closed_at timestamptz,
  message   text,
  unique (org_id, key, date_trunc('hour', opened_at))
);
alter table public.slo_alerts enable row level security;
create index if not exists idx_slo_alerts_org_open on public.slo_alerts(org_id, opened_at desc);
create policy if not exists slo_alerts_ro on public.slo_alerts for select using (public.current_org_id() = org_id);
create policy if not exists slo_alerts_rw on public.slo_alerts for all using (public.is_admin() and public.current_org_id() = org_id)
  with check (public.is_admin() and public.current_org_id() = org_id);

-- alert_caps already exists elsewhere; ensure with RLS if missing
create table if not exists public.alert_caps (
  org_id uuid not null,
  code   text not null,
  day    date not null default current_date,
  sent   int  not null default 0,
  cap    int  not null default 5,
  primary key (org_id, code, day)
);
alter table public.alert_caps enable row level security;
create policy if not exists alert_caps_rw on public.alert_caps for all using (public.current_org_id() = org_id) with check (public.current_org_id() = org_id);

-- 6) Resource Isolation (per-tenant rate limit & tiers)
create table if not exists public.org_rate_limiter (
  org_id      uuid primary key,
  tokens      int not null default 60,
  refreshed_at timestamptz not null default now()
);
alter table public.org_rate_limiter enable row level security;
create policy if not exists org_rate_limit_rw on public.org_rate_limiter for all using (public.current_org_id() = org_id)
  with check (public.current_org_id() = org_id);

create or replace function public.take_token(p_org_id uuid, p_capacity int default 60, p_refill_per_min int default 60)
returns boolean
language plpgsql
security definer
set search_path=public
as $$
declare
  nowts timestamptz := now();
begin
  insert into public.org_rate_limiter(org_id, tokens, refreshed_at)
  values (p_org_id, p_capacity-1, nowts)
  on conflict (org_id) do update set
    tokens = greatest(0, least(p_capacity,
      public.org_rate_limiter.tokens + floor(extract(epoch from (nowts - public.org_rate_limiter.refreshed_at))/60.0)*p_refill_per_min) - 1),
    refreshed_at = nowts;
  return (select tokens >= 0 from public.org_rate_limiter where org_id = p_org_id);
end
$$;

create table if not exists public.org_tiers (
  org_id     uuid primary key,
  tier       text not null check (tier in ('standard','gold','platinum')),
  notes      text,
  updated_at timestamptz default now()
);
alter table public.org_tiers enable row level security;
create policy if not exists org_tiers_ro on public.org_tiers for select using (public.current_org_id() = org_id);
create policy if not exists org_tiers_rw on public.org_tiers for all using (public.is_admin() and public.current_org_id() = org_id)
  with check (public.is_admin() and public.current_org_id() = org_id);

-- 7) Governance Views (exec-ready)
create or replace view public.v_slo_governance_24h as
with tgt as (
  select
    st.org_id,
    sg.key,
    coalesce(st.p95_ms, sg.p95_ms) as target_p95,
    coalesce(st.success_ratio, sg.success_ratio) as target_ratio
  from public.slo_targets_global sg
  left join public.slo_targets_tenant st on st.key = sg.key
)
select
  t.org_id, t.key,
  t.target_p95, t.target_ratio,
  s.p95_obs, s.success_ratio_obs
from tgt t
left join public.v_slo_status_24h s on s.key = t.key and (s.org_id is not distinct from t.org_id);

-- 8) Safe RPCs (no dynamic SQL, pinned, RLS respected)
create or replace function public.record_sli_event(p_key text, p_value numeric, p_labels jsonb)
returns void
language sql
security definer
set search_path=public
as $$
  insert into public.sli_events(org_id, key, value, labels, source)
  values (public.current_org_id(), p_key, p_value, p_labels, 'db')
$$;

create or replace function public.upsert_slo_target_tenant(p_org uuid, p_key text, p_p95 int, p_success numeric, p_window text)
returns void
language plpgsql
security definer
set search_path=public
as $$
begin
  if not public.is_admin() or p_org is distinct from public.current_org_id() then
    raise exception 'forbidden' using errcode='42501';
  end if;
  insert into public.slo_targets_tenant(org_id,key,p95_ms,success_ratio,window)
  values (p_org,p_key,p_p95,p_success,coalesce(p_window,'24h'))
  on conflict (org_id,key) do update set
    p95_ms = excluded.p95_ms,
    success_ratio = excluded.success_ratio,
    window = excluded.window,
    updated_at = now();
end
$$;

create or replace function public.guard_rate_limit(p_org uuid, p_capacity int default 60, p_refill int default 60)
returns void
language plpgsql
security definer
set search_path=public
as $$
declare ok boolean;
begin
  ok := public.take_token(p_org, p_capacity, p_refill);
  if not ok then raise exception 'rate_limited' using errcode='54000'; end if;
end
$$;

-- 9) Index hygiene
create index if not exists idx_sli_events_by_key_org_time on public.sli_events(key, org_id, at desc);
create index if not exists idx_function_invocations_by_fn_org_time on public.function_invocations(fn, org_id, at desc);
create index if not exists idx_slo_rollups_key_org_day on public.slo_rollups_daily(key, org_id, day desc);

-- 10) Minimal seeds (safe for staging)
insert into public.slo_catalog(key, description, sli_unit, owner) values
  ('live_map_latency','Latency from device to DB ingest','ms','platform@trucker'),
  ('rpc_get_quote','RPC execution time for get_quote','ms','market@trucker'),
  ('rpc_award_quote','RPC execution time for award','ms','market@trucker')
on conflict (key) do nothing;

insert into public.slo_targets_global(key,p95_ms,success_ratio,window) values
  ('live_map_latency', 5000, null,  '24h'),
  ('rpc_get_quote',     800, 0.995, '24h'),
  ('rpc_award_quote',  1200, 0.995, '24h')
on conflict (key) do nothing;

-- Tiny Grafana queries (examples)
-- Burn-rate 5m vs 1h for a key: select * from public.v_slo_burn_multiwindow where key='rpc_get_quote';
-- Governance gap (p95 over target): select key, p95_obs, target_p95 from public.v_slo_governance_24h where p95_obs > target_p95;

-- CI gate (concept): fail if any tenant’s 24h p95 exceeds target by >10%
-- select 1 from public.v_slo_governance_24h where p95_obs > target_p95 * 1.10 limit 1;