-- =============================================================
-- Common Helpers, Feature Registry, SLOs, DQ, Access Reviews,
-- Secrets Hygiene, Mobile Telemetry, Export Resilience,
-- Privacy Center, Disaster Drills, Sales/CS Enablement,
-- Alert Caps, Admin Retest Limits, and RPCs
-- Idempotent and safe to re-run
-- =============================================================

-- 0) Helpers (one-time)
create or replace function public.current_org_id() returns uuid
language sql stable as $$ select nullif(auth.jwt()->>'app_org_id','')::uuid $$;

create or replace function public.current_role() returns text
language sql stable as $$ select nullif(auth.jwt()->>'app_role','') $$;

create or replace function public.current_user_id() returns uuid
language sql stable as $$ select auth.uid() $$;

create or replace function public.is_admin() returns boolean
language sql stable as $$
  select coalesce(public.current_role() in ('admin','owner','fleet_admin','corp_admin'), false)
$$;

-- =============================================================
-- 1) Feature flags (per env) + RLS
-- Ensure table exists and required columns/constraints
create table if not exists public.feature_registry (
  key           text    not null,
  env           text    not null,
  description   text,
  owner         text,
  runbook_url   text,
  enabled       boolean not null default false,
  updated_by    uuid    default public.current_user_id(),
  updated_at    timestamptz not null default now(),
  primary key (key, env)
);

-- Add/align columns/checks idempotently
alter table public.feature_registry
  alter column enabled set default false;

do $$ begin
  alter table public.feature_registry
    add column if not exists description text,
    add column if not exists owner text,
    add column if not exists runbook_url text,
    add column if not exists updated_by uuid,
    add column if not exists updated_at timestamptz not null default now();
exception when others then null; end $$;

-- Constrain env to allowed values
do $$ begin
  alter table public.feature_registry
    add constraint feature_registry_env_ck check (env in ('dev','staging','prod'));
exception when duplicate_object then null; end $$;

alter table public.feature_registry enable row level security;

do $$ begin
  create policy feature_registry_ro on public.feature_registry
    for select using (true);
exception when duplicate_object then null; end $$;

do $$ begin
  create policy feature_registry_rw on public.feature_registry
    for insert with check (public.is_admin())
    , for update using (public.is_admin());
exception when duplicate_object then null; end $$;

create or replace view public.v_features_live as
select key, env, enabled, owner, runbook_url, updated_at
from public.feature_registry where enabled = true;

-- =============================================================
-- 2) SLO targets (per function/endpoint)
create table if not exists public.slo_targets (
  fn                text primary key,
  p95_ms            int  not null,
  budget_error_rate numeric not null default 0.005,
  updated_at        timestamptz not null default now()
);

-- Ensure updated_at exists (in case pre-existed without it)
alter table public.slo_targets
  add column if not exists updated_at timestamptz not null default now();

alter table public.slo_targets enable row level security;

do $$ begin
  create policy slo_targets_ro on public.slo_targets for select using (true);
exception when duplicate_object then null; end $$;

do $$ begin
  create policy slo_targets_rw on public.slo_targets
    for insert with check (public.is_admin())
    , for update using (public.is_admin());
exception when duplicate_object then null; end $$;

-- =============================================================
-- 3) Data Quality (registry + results + RLS)
create table if not exists public.dq_checks (
  id           bigserial primary key,
  org_id       uuid not null,
  code         text not null,
  description  text,
  severity     text not null default 'warn',
  schedule     text,
  active       boolean not null default true,
  created_at   timestamptz default now()
);
alter table public.dq_checks enable row level security;

do $$ begin
  create policy dq_checks_rw on public.dq_checks
    for all using (public.current_org_id() = org_id) with check (public.current_org_id() = org_id);
exception when duplicate_object then null; end $$;

create table if not exists public.dq_results (
  id            bigserial primary key,
  org_id        uuid not null,
  check_id      bigint not null references public.dq_checks(id) on delete cascade,
  ran_at        timestamptz not null default now(),
  status        text not null check (status in ('ok','warn','fail')),
  sample_count  int,
  offending_ct  int,
  details       jsonb,
  unique (check_id, ran_at)
);
alter table public.dq_results enable row level security;

do $$ begin
  create policy dq_results_ro on public.dq_results for select using (public.current_org_id() = org_id);
exception when duplicate_object then null; end $$;

do $$ begin
  create policy dq_results_rw on public.dq_results for insert with check (public.current_org_id() = org_id);
exception when duplicate_object then null; end $$;

create or replace view public.v_dq_latest as
select distinct on (check_id) * from public.dq_results order by check_id, ran_at desc;

-- =============================================================
-- 4) Access reviews & attestation
create table if not exists public.access_attestations (
  id            bigserial primary key,
  org_id        uuid not null,
  reviewer_id   uuid not null,
  period_start  date not null,
  period_end    date not null,
  submitted_at  timestamptz,
  status        text not null default 'open',
  notes         text
);
alter table public.access_attestations enable row level security;

do $$ begin
  create policy access_attestations_rw on public.access_attestations
    for all using (public.current_org_id() = org_id) with check (public.current_org_id() = org_id);
exception when duplicate_object then null; end $$;

create table if not exists public.access_items (
  id               bigserial primary key,
  attestation_id   bigint not null references public.access_attestations(id) on delete cascade,
  item_type        text not null,
  item_id          text not null,
  label            text,
  active           boolean not null,
  last_used_at     timestamptz,
  acknowledged     boolean not null default false
);
alter table public.access_items enable row level security;

do $$ begin
  create policy access_items_rw on public.access_items
    for all using (
      exists (select 1 from public.access_attestations a where a.id = public.access_items.attestation_id and a.org_id = public.current_org_id())
    ) with check (
      exists (select 1 from public.access_attestations a where a.id = public.access_items.attestation_id and a.org_id = public.current_org_id())
    );
exception when duplicate_object then null; end $$;

-- =============================================================
-- 5) Secret rotation tracking escalation
create table if not exists public.secret_escalations (
  id            bigserial primary key,
  key           text not null,
  org_id        uuid,
  opened_at     timestamptz not null default now(),
  status        text not null default 'open',
  severity      text not null default 'p2',
  notes         text
);
alter table public.secret_escalations enable row level security;

do $$ begin
  create policy secret_escalations_ro on public.secret_escalations for select using (true);
exception when duplicate_object then null; end $$;

do $$ begin
  create policy secret_escalations_rw on public.secret_escalations
    for insert with check (public.is_admin())
    , for update using (public.is_admin());
exception when duplicate_object then null; end $$;

-- =============================================================
-- 6) Mobile telemetry
create table if not exists public.mobile_heartbeat (
  id            bigserial primary key,
  org_id        uuid,
  user_id       uuid,
  app_version   text not null,
  platform      text not null,
  device_model  text,
  cold_start_ms int,
  crash_rate_7d numeric,
  created_at    timestamptz not null default now()
);
alter table public.mobile_heartbeat enable row level security;

do $$ begin
  create policy mobile_heartbeat_ro on public.mobile_heartbeat
    for select using (org_id is null or org_id = public.current_org_id());
exception when duplicate_object then null; end $$;

do $$ begin
  create policy mobile_heartbeat_ins on public.mobile_heartbeat
    for insert with check (
      (org_id is null or org_id = public.current_org_id()) and (user_id is null or user_id = public.current_user_id())
    );
exception when duplicate_object then null; end $$;

-- =============================================================
-- 7) Export jobs and artifacts
create table if not exists public.export_jobs (
  id             uuid primary key default gen_random_uuid(),
  org_id         uuid not null,
  kind           text not null,
  requested_by   uuid,
  status         text not null default 'queued',
  attempts       int not null default 0,
  message        text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
alter table public.export_jobs enable row level security;

do $$ begin
  create policy export_jobs_rw on public.export_jobs
    for all using (org_id = public.current_org_id()) with check (org_id = public.current_org_id());
exception when duplicate_object then null; end $$;

create table if not exists public.export_artifacts (
  id             bigserial primary key,
  job_id         uuid not null references public.export_jobs(id) on delete cascade,
  filename       text not null,
  bytes          bigint not null,
  sha256_hex     text not null,
  storage_url    text not null,
  created_at     timestamptz not null default now()
);
alter table public.export_artifacts enable row level security;

do $$ begin
  create policy export_artifacts_ro on public.export_artifacts
    for select using (exists (select 1 from public.export_jobs j where j.id = public.export_artifacts.job_id and j.org_id = public.current_org_id()));
exception when duplicate_object then null; end $$;

-- =============================================================
-- 8) Privacy preferences + requests
create table if not exists public.user_privacy_preferences (
  user_id     uuid primary key,
  org_id      uuid not null,
  personalization boolean not null default false,
  marketing_opt_in boolean not null default false,
  updated_at  timestamptz not null default now()
);
alter table public.user_privacy_preferences enable row level security;

do $$ begin
  create policy upp_self_rw on public.user_privacy_preferences
    for all using (user_id = public.current_user_id()) with check (user_id = public.current_user_id());
exception when duplicate_object then null; end $$;

do $$ begin
  create policy upp_admin_ro on public.user_privacy_preferences
    for select using (public.is_admin() and org_id = public.current_org_id());
exception when duplicate_object then null; end $$;

create table if not exists public.privacy_requests (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null,
  user_id     uuid not null,
  type        text not null check (type in ('export','delete')),
  status      text not null default 'open',
  submitted_at timestamptz not null default now(),
  processed_at timestamptz,
  notes       text
);
alter table public.privacy_requests enable row level security;

do $$ begin
  create policy prw_self on public.privacy_requests
    for insert with check (user_id = public.current_user_id() and org_id = public.current_org_id());
exception when duplicate_object then null; end $$;

do $$ begin
  create policy prw_self_ro on public.privacy_requests
    for select using (user_id = public.current_user_id() and org_id = public.current_org_id());
exception when duplicate_object then null; end $$;

do $$ begin
  create policy prw_admin on public.privacy_requests
    for all using (public.is_admin() and org_id = public.current_org_id());
exception when duplicate_object then null; end $$;

-- =============================================================
-- 9) Disaster Drills (restore/failover MTTR tracking)
create table if not exists public.drill_history (
  id           bigserial primary key,
  org_id       uuid,
  service      text not null,
  type         text not null,
  started_at   timestamptz not null,
  resolved_at  timestamptz,
  mttr_ms      bigint generated always as (
    case when resolved_at is not null then (extract(epoch from (resolved_at - started_at))*1000)::bigint end
  ) stored,
  notes        text
);
alter table public.drill_history enable row level security;

do $$ begin
  create policy drill_ro on public.drill_history for select using (org_id is null or org_id = public.current_org_id());
exception when duplicate_object then null; end $$;

do $$ begin
  create policy drill_rw on public.drill_history
    for insert with check (public.is_admin())
    , for update using (public.is_admin());
exception when duplicate_object then null; end $$;

-- =============================================================
-- 10) Sales/CS Enablement (pilot KPI snapshots & deck jobs)
create table if not exists public.pilot_kpi_snapshots (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null,
  pilot_id      uuid not null,
  taken_at      timestamptz not null default now(),
  roi_pct       numeric,
  ontime_pct    numeric,
  fuel_saved_gal numeric,
  detention_hours numeric,
  payload       jsonb
);
alter table public.pilot_kpi_snapshots enable row level security;

do $$ begin
  create policy pilot_kpis_rw on public.pilot_kpi_snapshots
    for all using (org_id = public.current_org_id()) with check (org_id = public.current_org_id());
exception when duplicate_object then null; end $$;

create table if not exists public.deck_jobs (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null,
  pilot_id      uuid not null,
  status        text not null default 'queued',
  artifact_url  text,
  message       text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
alter table public.deck_jobs enable row level security;

do $$ begin
  create policy deck_jobs_rw on public.deck_jobs
    for all using (org_id = public.current_org_id()) with check (org_id = public.current_org_id());
exception when duplicate_object then null; end $$;

-- =============================================================
-- 11) Alert Spam Caps (per-code per-org per-day)
create table if not exists public.alert_caps (
  org_id   uuid not null,
  code     text not null,
  day      date not null default current_date,
  sent     int  not null default 0,
  cap      int  not null default 5,
  primary key (org_id, code, day)
);
alter table public.alert_caps enable row level security;

do $$ begin
  create policy alert_caps_rw on public.alert_caps
    for all using (org_id = public.current_org_id()) with check (org_id = public.current_org_id());
exception when duplicate_object then null; end $$;

-- =============================================================
-- 12) Admin Retest Rate-limit (SSO/SCIM)
create table if not exists public.admin_action_limits(
  org_id       uuid not null,
  action       text not null,        -- 'sso_retest','scim_retest'
  tokens       int  not null default 3,
  refreshed_at timestamptz not null default now(),
  primary key (org_id, action)
);
alter table public.admin_action_limits enable row level security;

do $$ begin
  create policy admin_action_limits_rw on public.admin_action_limits
    for all using (org_id = public.current_org_id()) with check (org_id = public.current_org_id());
exception when duplicate_object then null; end $$;

-- =============================================================
-- 13) RPCs (safe patterns)
-- 13.a) Upsert feature flag (admins only)
create or replace function public.upsert_feature_flag(
  p_key text, p_env text, p_enabled boolean, p_desc text, p_owner text, p_runbook text
) returns void
language plpgsql security definer set search_path=public as $$
begin
  if not public.is_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  insert into public.feature_registry(key, env, enabled, description, owner, runbook_url, updated_by)
  values (p_key, p_env, p_enabled, p_desc, p_owner, p_runbook, public.current_user_id())
  on conflict (key, env) do update set
    enabled    = excluded.enabled,
    description= excluded.description,
    owner      = excluded.owner,
    runbook_url= excluded.runbook_url,
    updated_by = public.current_user_id(),
    updated_at = now();
end $$;

-- 13.b) Enqueue export job (org-scoped)
create or replace function public.enqueue_export(p_kind text)
returns uuid language plpgsql security definer set search_path=public as $$
declare jid uuid := gen_random_uuid();
begin
  insert into public.export_jobs(id, org_id, kind, requested_by, status)
  values (jid, public.current_org_id(), p_kind, public.current_user_id(), 'queued');
  return jid;
end $$;

-- 13.c) Record mobile telemetry (user-scoped)
create or replace function public.record_mobile_heartbeat(
  p_app_version text, p_platform text, p_cold_start_ms int, p_crash_rate numeric
) returns void
language sql security definer set search_path=public as $$
  insert into public.mobile_heartbeat(org_id, user_id, app_version, platform, cold_start_ms, crash_rate_7d)
  values (public.current_org_id(), public.current_user_id(), p_app_version, p_platform, p_cold_start_ms, p_crash_rate)
$$;

-- End of common_ops.sql
