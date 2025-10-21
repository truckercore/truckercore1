-- =============================================================
-- SLI Catalog + Minimal Event Tables + 24h SLI Views + Targets
-- Governance roll-up and indexes. Safe to re-run.
-- =============================================================

-- 0) SLI catalog (idempotent) + seeds
create table if not exists public.slo_catalog (
  key text primary key,
  description text not null,
  sli_unit text not null check (sli_unit in ('ratio','ms','count')),
  owner text not null
);

insert into public.slo_catalog(key, description, sli_unit, owner) values
  ('mk_quote_conversion',     'Quotes → awarded loads %',                      'ratio','market@trucker'),
  ('mk_bid_fairness',         'Share of bids flagged/adjusted for gaming',     'ratio','market@trucker'),
  ('mk_award_rule_success',   'Award rule simulations that completed OK %',    'ratio','market@trucker'),
  ('mk_cs_sat_ratio',         'Successful txns ÷ marketplace complaints',      'ratio','market@trucker'),
  ('lm_data_freshness_ms',    'ELD→map end-to-end latency (ms)',               'ms',   'fleet@trucker'),
  ('lm_location_accuracy_m',  'Median geofence position error (meters)',       'ms',   'fleet@trucker'),
  ('lm_geofence_proc_ms',     'Geofence event processing time (ms)',           'ms',   'fleet@trucker'),
  ('lm_eta_accuracy_abs_min', 'Abs error actual-vs-pred ETA (minutes)',        'ms',   'fleet@trucker'),
  ('sec_hos_validation_ok',   'HOS logs passing validation %',                 'ratio','compliance@trucker'),
  ('sec_dqf_completeness',    'Driver DQF required docs present %',            'ratio','compliance@trucker'),
  ('sec_share_unauth_rate',   'Unauthorized share-link attempt rate',          'ratio','security@trucker'),
  ('sec_policy_violations',   'Policy/RLS lint detections (count)',            'count','security@trucker'),
  ('fin_invoice_success',     'Invoices & payroll runs generated OK %',        'ratio','finance@trucker'),
  ('fin_expense_recon_ok',    'Expenses auto-matched to trip/driver %',        'ratio','finance@trucker'),
  ('gov_retention_adherence', 'Records processed within retention window %',   'ratio','security@trucker'),
  ('gov_seed_health_ok',      'Seed health checks passed %',                   'ratio','platform@trucker'),
  ('gov_data_consistency',    'Cross-table consistency failures (count)',      'count','platform@trucker'),
  ('gov_tenant_resource_sat', 'Per-tenant resource saturation (cpu/mem io %)', 'ratio','platform@trucker')
on conflict (key) do nothing;


-- 1) Minimal event tables (idempotent) + RLS + helpful indexes
-- Marketplace
create table if not exists public.quotes (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  load_id uuid not null,
  created_at timestamptz not null default now()
);
create table if not exists public.awards (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  load_id uuid not null,
  quote_id uuid not null,
  created_at timestamptz not null default now()
);
-- NOTE: bids may already exist in repo; ensure needed columns exist
create table if not exists public.bids (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  load_id uuid not null,
  bidder_org_id uuid not null,
  flagged boolean default false,
  corrected boolean default false,
  created_at timestamptz not null default now()
);
-- Add columns if table pre-existed with different schema
alter table if exists public.bids
  add column if not exists bidder_org_id uuid,
  add column if not exists flagged boolean default false,
  add column if not exists corrected boolean default false,
  add column if not exists created_at timestamptz default now();

-- Live map / Fleet
create table if not exists public.geofence_events (
  id bigserial primary key,
  org_id uuid not null,
  vehicle_id uuid,
  fence_id uuid,
  kind text check (kind in ('enter','exit')),
  device_ts timestamptz not null,
  processed_ts timestamptz,
  created_at timestamptz not null default now()
);
create table if not exists public.eta_predictions (
  id bigserial primary key,
  org_id uuid not null,
  trip_id uuid not null,
  predicted_at timestamptz not null,
  eta_pred timestamptz not null,
  created_at timestamptz not null default now()
);
create table if not exists public.arrivals (
  id bigserial primary key,
  org_id uuid not null,
  trip_id uuid not null,
  arrived_at timestamptz not null
);

-- Compliance / Security
create table if not exists public.hos_logs (
  id bigserial primary key,
  org_id uuid not null,
  driver_id uuid,
  device_id uuid,
  log_at timestamptz not null,
  valid boolean not null
);
-- Add compatibility columns if hos_logs already exists
alter table if exists public.hos_logs
  add column if not exists log_at timestamptz,
  add column if not exists valid boolean;

create table if not exists public.dqf_documents (
  id bigserial primary key,
  org_id uuid not null,
  driver_id uuid not null,
  doc_type text not null,
  expires_at date,
  present boolean not null default false
);
create table if not exists public.share_link_attempts (
  id bigserial primary key,
  org_id uuid not null,
  link_id uuid,
  ok boolean not null,
  at timestamptz not null default now()
);
create table if not exists public.policy_lint_events (
  id bigserial primary key,
  org_id uuid not null,
  code text not null,
  at timestamptz not null default now()
);

-- Financial / Operational
create table if not exists public.invoices_jobs (
  id bigserial primary key,
  org_id uuid not null,
  kind text not null check (kind in ('invoice','payroll')),
  ok boolean not null,
  at timestamptz not null default now()
);
create table if not exists public.expense_matches (
  id bigserial primary key,
  org_id uuid not null,
  expense_id uuid not null,
  matched boolean not null,
  at timestamptz not null default now()
);
create table if not exists public.retention_tasks (
  id bigserial primary key,
  org_id uuid not null,
  due_by timestamptz not null,
  processed_at timestamptz,
  on_hold boolean default false
);

-- Data health / Governance
create table if not exists public.seed_health_checks (
  id bigserial primary key,
  org_id uuid,
  name text not null,
  ok boolean not null,
  at timestamptz not null default now()
);
create table if not exists public.consistency_checks (
  id bigserial primary key,
  org_id uuid,
  name text not null,
  failures int not null,
  at timestamptz not null default now()
);
create table if not exists public.tenant_resource_samples (
  id bigserial primary key,
  org_id uuid not null,
  cpu_pct numeric,
  mem_pct numeric,
  io_pct numeric,
  at timestamptz not null default now()
);

-- Enable RLS across all tables above
alter table public.quotes                  enable row level security;
alter table public.awards                  enable row level security;
alter table public.bids                    enable row level security;
alter table public.geofence_events         enable row level security;
alter table public.eta_predictions         enable row level security;
alter table public.arrivals                enable row level security;
alter table public.hos_logs                enable row level security;
alter table public.dqf_documents           enable row level security;
alter table public.share_link_attempts     enable row level security;
alter table public.policy_lint_events      enable row level security;
alter table public.invoices_jobs           enable row level security;
alter table public.expense_matches         enable row level security;
alter table public.retention_tasks         enable row level security;
alter table public.seed_health_checks      enable row level security;
alter table public.consistency_checks      enable row level security;
alter table public.tenant_resource_samples enable row level security;

-- SELECT policies
create policy if not exists org_ro_quotes          on public.quotes                  for select using (org_id = current_org_id());
create policy if not exists org_ro_awards          on public.awards                  for select using (org_id = current_org_id());
create policy if not exists org_ro_bids            on public.bids                    for select using (org_id = current_org_id());
create policy if not exists org_ro_geo             on public.geofence_events         for select using (org_id = current_org_id());
create policy if not exists org_ro_eta             on public.eta_predictions         for select using (org_id = current_org_id());
create policy if not exists org_ro_arrivals        on public.arrivals                for select using (org_id = current_org_id());
create policy if not exists org_ro_hos             on public.hos_logs                for select using (org_id = current_org_id());
create policy if not exists org_ro_dqf             on public.dqf_documents           for select using (org_id = current_org_id());
create policy if not exists org_ro_share           on public.share_link_attempts     for select using (org_id = current_org_id());
create policy if not exists org_ro_lint            on public.policy_lint_events      for select using (org_id = current_org_id());
create policy if not exists org_ro_inv             on public.invoices_jobs           for select using (org_id = current_org_id());
create policy if not exists org_ro_exp             on public.expense_matches         for select using (org_id = current_org_id());
create policy if not exists org_ro_ret             on public.retention_tasks         for select using (org_id = current_org_id());
create policy if not exists org_ro_seed            on public.seed_health_checks      for select using (org_id is null or org_id = current_org_id());
create policy if not exists org_ro_cons            on public.consistency_checks      for select using (org_id is null or org_id = current_org_id());
create policy if not exists org_ro_res             on public.tenant_resource_samples for select using (org_id = current_org_id());

-- INSERT policies
create policy if not exists org_ins_quotes         on public.quotes                  for insert with check (org_id = current_org_id());
create policy if not exists org_ins_awards         on public.awards                  for insert with check (org_id = current_org_id());
create policy if not exists org_ins_bids           on public.bids                    for insert with check (org_id = current_org_id());
create policy if not exists org_ins_geo            on public.geofence_events         for insert with check (org_id = current_org_id());
create policy if not exists org_ins_eta            on public.eta_predictions         for insert with check (org_id = current_org_id());
create policy if not exists org_ins_arrivals       on public.arrivals                for insert with check (org_id = current_org_id());
create policy if not exists org_ins_hos            on public.hos_logs                for insert with check (org_id = current_org_id());
create policy if not exists org_ins_dqf            on public.dqf_documents           for insert with check (org_id = current_org_id());
create policy if not exists org_ins_share          on public.share_link_attempts     for insert with check (org_id = current_org_id());
create policy if not exists org_ins_lint           on public.policy_lint_events      for insert with check (org_id = current_org_id());
create policy if not exists org_ins_inv            on public.invoices_jobs           for insert with check (org_id = current_org_id());
create policy if not exists org_ins_exp            on public.expense_matches         for insert with check (org_id = current_org_id());
create policy if not exists org_ins_ret            on public.retention_tasks         for insert with check (org_id = current_org_id());
create policy if not exists org_ins_seed           on public.seed_health_checks      for insert with check (org_id is null or org_id = current_org_id());
create policy if not exists org_ins_cons           on public.consistency_checks      for insert with check (org_id is null or org_id = current_org_id());
create policy if not exists org_ins_res            on public.tenant_resource_samples for insert with check (org_id = current_org_id());

-- Suggested tenant indexes
create index if not exists idx_quotes_org_time                  on public.quotes(org_id, created_at desc);
create index if not exists idx_awards_org_time                  on public.awards(org_id, created_at desc);
create index if not exists idx_bids_org_time                    on public.bids(org_id, created_at desc);
create index if not exists idx_geo_org_time                     on public.geofence_events(org_id, created_at desc);
create index if not exists idx_eta_org_time                     on public.eta_predictions(org_id, predicted_at desc);
create index if not exists idx_arrivals_org_time                on public.arrivals(org_id, arrived_at desc);
create index if not exists idx_hos_org_time                     on public.hos_logs(org_id, log_at desc);
create index if not exists idx_dqf_org_driver                   on public.dqf_documents(org_id, driver_id);
create index if not exists idx_share_org_time                   on public.share_link_attempts(org_id, at desc);
create index if not exists idx_lint_org_time                    on public.policy_lint_events(org_id, at desc);
create index if not exists idx_inv_org_time                     on public.invoices_jobs(org_id, at desc);
create index if not exists idx_exp_org_time                     on public.expense_matches(org_id, at desc);
create index if not exists idx_retention_org_due                on public.retention_tasks(org_id, due_by desc);
create index if not exists idx_seed_health_time                 on public.seed_health_checks(org_id, at desc);
create index if not exists idx_consistency_time                 on public.consistency_checks(org_id, at desc);
create index if not exists idx_tenant_resource_time             on public.tenant_resource_samples(org_id, at desc);


-- 2) SLI Views (24h)
create or replace view public.v_sli_mk_quote_conversion_24h as
select q.org_id,
  count(distinct q.id) as quotes,
  count(distinct a.id) as awards,
  (count(distinct a.id)::numeric / greatest(count(distinct q.id),1)) as ratio
from public.quotes q
left join public.awards a
  on a.org_id=q.org_id and a.load_id=q.load_id and a.created_at> now()-interval '24h'
where q.created_at > now()-interval '24h'
group by q.org_id;

create or replace view public.v_sli_mk_bid_fairness_24h as
select org_id,
  count(*) as bids,
  sum((coalesce(flagged,false) or coalesce(corrected,false))::int) as flagged,
  (sum((coalesce(flagged,false) or coalesce(corrected,false))::int)::numeric / greatest(count(*),1)) as ratio
from public.bids
where coalesce(created_at, now()) > now()-interval '24h'
group by org_id;

create or replace view public.v_sli_mk_award_rule_success_24h as
select org_id,
  sum((status='ok')::int) as ok,
  count(*) as total,
  (sum((status='ok')::int)::numeric / greatest(count(*),1)) as ratio
from public.function_invocations
where fn='award_rules.simulate' and at > now()-interval '24h'
group by org_id;

create or replace view public.v_sli_mk_cs_sat_ratio_24h as
select a.org_id,
  count(distinct a.id) as success_txns,
  greatest(1, (select count(*) from public.tickets t where t.org_id=a.org_id and t.created_at>now()-interval '24h' and t.category='marketplace')) as tickets,
  (count(distinct a.id)::numeric / greatest(1,(select count(*) from public.tickets t where t.org_id=a.org_id and t.created_at>now()-interval '24h' and t.category='marketplace'))) as ratio
from public.awards a
where a.created_at>now()-interval '24h'
group by a.org_id;

create or replace view public.v_sli_lm_data_freshness_24h as
select org_id,
  percentile_disc(0.5) within group (order by (extract(epoch from (ingest_ts - device_ts))*1000)) as p50_ms,
  percentile_disc(0.95) within group (order by (extract(epoch from (ingest_ts - device_ts))*1000)) as p95_ms
from public.live_map_ingest
where ingest_ts > now()-interval '24h'
group by org_id;

create or replace view public.v_sli_lm_location_accuracy_24h as
select org_id,
  percentile_disc(0.5) within group (order by value) as median_m,
  percentile_disc(0.95) within group (order by value) as p95_m
from public.sli_events
where key='lm_location_accuracy_m' and at > now()-interval '24h'
group by org_id;

create or replace view public.v_sli_lm_geofence_proc_24h as
select org_id,
  percentile_disc(0.95) within group (order by greatest(0,(extract(epoch from(coalesce(processed_ts,now()) - device_ts))*1000))) as p95_ms
from public.geofence_events
where created_at > now()-interval '24h'
group by org_id;

create or replace view public.v_sli_lm_eta_accuracy_24h as
with joined as (
  select e.org_id, e.trip_id, e.eta_pred, a.arrived_at,
         abs(extract(epoch from (a.arrived_at - e.eta_pred))/60.0) as abs_min
  from public.eta_predictions e
  join public.arrivals a on a.org_id=e.org_id and a.trip_id=e.trip_id
  where e.predicted_at > now()-interval '24h'
)
select org_id,
  percentile_disc(0.5) within group (order by abs_min) as p50_min,
  percentile_disc(0.95) within group (order by abs_min) as p95_min
from joined
group by org_id;

create or replace view public.v_sli_sec_hos_validation_24h as
select org_id,
  sum(coalesce(valid,false)::int) as ok, count(*) as total,
  (sum(coalesce(valid,false)::int)::numeric / greatest(count(*),1)) as ratio
from public.hos_logs
where coalesce(log_at, now()) > now()-interval '24h'
group by org_id;

-- DQF completeness (requires dqf_required)
create table if not exists public.dqf_required(doc_type text primary key);
create or replace view public.v_sli_sec_dqf_completeness as
with req as (select doc_type from public.dqf_required),
driver_ok as (
  select d.org_id, d.driver_id, bool_and(d.present) as all_present
  from (
    select q.org_id, q.driver_id, r.doc_type,
      exists (
        select 1 from public.dqf_documents dd
        where dd.org_id=q.org_id and dd.driver_id=q.driver_id
          and dd.doc_type=r.doc_type and dd.present
          and (dd.expires_at is null or dd.expires_at >= current_date)
      ) as present
    from (select distinct org_id, driver_id from public.dqf_documents) q
    cross join req r
  ) d group by d.org_id, d.driver_id
)
select org_id,
  sum((all_present)::int) as ok, count(*) as total,
  (sum((all_present)::int)::numeric / greatest(count(*),1)) as ratio
from driver_ok
group by org_id;

create or replace view public.v_sli_sec_share_unauth_rate_24h as
select org_id,
  sum((not ok)::int)::numeric / greatest(count(*),1) as ratio
from public.share_link_attempts
where at > now()-interval '24h'
group by org_id;

create or replace view public.v_sli_sec_policy_violations_24h as
select org_id, count(*) as violations
from public.policy_lint_events
where at > now()-interval '24h'
group by org_id;

create or replace view public.v_sli_fin_invoice_success_24h as
select org_id,
  sum(ok::int) as ok, count(*) as total,
  (sum(ok::int)::numeric / greatest(count(*),1)) as ratio
from public.invoices_jobs
where at > now()-interval '24h'
group by org_id;

create or replace view public.v_sli_fin_expense_recon_24h as
select org_id,
  sum(matched::int) as ok, count(*) as total,
  (sum(matched::int)::numeric / greatest(count(*),1)) as ratio
from public.expense_matches
where at > now()-interval '24h'
group by org_id;

create or replace view public.v_sli_gov_retention_adherence_24h as
select org_id,
  sum( (not on_hold and processed_at is not null and processed_at <= due_by)::int ) as ontime,
  sum( (not on_hold)::int ) as eligible,
  (sum( (not on_hold and processed_at is not null and processed_at <= due_by)::int )::numeric / greatest(sum((not on_hold)::int),1)) as ratio
from public.retention_tasks
where due_by > now()-interval '24h'
group by org_id;

create or replace view public.v_sli_gov_seed_health_ok_24h as
select coalesce(org_id,'00000000-0000-0000-0000-000000000000'::uuid) as org_id,
  sum(ok::int) as ok, count(*) as total,
  (sum(ok::int)::numeric / greatest(count(*),1)) as ratio
from public.seed_health_checks
where at > now()-interval '24h'
group by coalesce(org_id,'00000000-0000-0000-0000-000000000000'::uuid);

create or replace view public.v_sli_gov_data_consistency_24h as
select coalesce(org_id,'00000000-0000-0000-0000-000000000000'::uuid) as org_id,
  sum(failures) as failures
from public.consistency_checks
where at > now()-interval '24h'
group by coalesce(org_id,'00000000-0000-0000-0000-000000000000'::uuid);

create or replace view public.v_sli_gov_tenant_resource_sat_24h as
select org_id,
  greatest(avg(coalesce(cpu_pct,0)), avg(coalesce(mem_pct,0)), avg(coalesce(io_pct,0))) as sat_ratio
from public.tenant_resource_samples
where at > now()-interval '24h'
group by org_id;


-- 3) Global targets and governance roll-up
create table if not exists public.slo_targets_global (
  key text primary key references public.slo_catalog(key),
  p95_ms int,
  success_ratio numeric,
  window text not null
);

insert into public.slo_targets_global(key, p95_ms, success_ratio, window) values
  ('lm_data_freshness_ms',    5000,  null,'24h'),
  ('lm_geofence_proc_ms',     1500,  null,'24h'),
  ('lm_eta_accuracy_abs_min',   10,  null,'24h'),
  ('mk_award_rule_success',   null,  0.995,'24h'),
  ('mk_quote_conversion',     null,  0.40, '7d'),
  ('sec_hos_validation_ok',   null,  0.98, '24h'),
  ('fin_invoice_success',     null,  0.995,'24h'),
  ('fin_expense_recon_ok',    null,  0.90, '24h'),
  ('gov_retention_adherence', null,  0.995,'24h')
on conflict (key) do nothing;

create or replace view public.v_sli_governance_24h as
select org_id,'mk_quote_conversion' as key, ratio, null::int as p95 from public.v_sli_mk_quote_conversion_24h
union all select org_id,'mk_bid_fairness', ratio, null from public.v_sli_mk_bid_fairness_24h
union all select org_id,'mk_award_rule_success', ratio, null from public.v_sli_mk_award_rule_success_24h
union all select org_id,'mk_cs_sat_ratio', ratio, null from public.v_sli_mk_cs_sat_ratio_24h
union all select org_id,'lm_data_freshness_ms', null, p95_ms from public.v_sli_lm_data_freshness_24h
union all select org_id,'lm_location_accuracy_m', null, p95_m from public.v_sli_lm_location_accuracy_24h
union all select org_id,'lm_geofence_proc_ms', null, p95_ms from public.v_sli_lm_geofence_proc_24h
union all select org_id,'lm_eta_accuracy_abs_min', null, p95_min from public.v_sli_lm_eta_accuracy_24h
union all select org_id,'sec_hos_validation_ok', ratio, null from public.v_sli_sec_hos_validation_24h
union all select org_id,'sec_dqf_completeness', ratio, null from public.v_sli_sec_dqf_completeness
union all select org_id,'sec_share_unauth_rate', ratio, null from public.v_sli_sec_share_unauth_rate_24h
union all select org_id,'sec_policy_violations', null, cast(violations as int) from public.v_sli_sec_policy_violations_24h
union all select org_id,'fin_invoice_success', ratio, null from public.v_sli_fin_invoice_success_24h
union all select org_id,'fin_expense_recon_ok', ratio, null from public.v_sli_fin_expense_recon_24h
union all select org_id,'gov_retention_adherence', ratio, null from public.v_sli_gov_retention_adherence_24h
union all select org_id,'gov_seed_health_ok', ratio, null from public.v_sli_gov_seed_health_ok_24h
union all select org_id,'gov_data_consistency', null, cast(failures as int) from public.v_sli_gov_data_consistency_24h
union all select org_id,'gov_tenant_resource_sat', sat_ratio, null from public.v_sli_gov_tenant_resource_sat_24h;
