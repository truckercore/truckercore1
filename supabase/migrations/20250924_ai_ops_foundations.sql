-- 20250924_ai_ops_foundations.sql
-- Foundations + core domain tables per issue: extensions, helper trigger, enums,
-- AI safety/HOS alerts/ETA, tracking links, IFTA + accounting sync, payroll,
-- maintenance & assets, load optimization, analytics views, RLS, and indexes.
-- Idempotent and safe to re-run.

-- 1) Extensions
create extension if not exists "uuid-ossp";
create extension if not exists pgcrypto;

-- 2) Common updated_at trigger
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

-- 3) Enums (guarded)
DO $$ BEGIN CREATE TYPE public.work_order_status AS ENUM ('open','in_progress','on_hold','closed','canceled'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.repair_priority   AS ENUM ('low','medium','high','critical'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.ai_event_kind    AS ENUM ('safety_violation','guardrail_block','policy_flag','model_latency','model_cost'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.accounting_provider AS ENUM ('quickbooks','xero'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.sync_status AS ENUM ('queued','processing','success','error','dead_letter'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.assignment_decider AS ENUM ('ai','human','ai_assisted'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 2.1 AI Safety & ETA Predictions -------------------------------------------------
create table if not exists public.ai_safety_events (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  user_id uuid null,
  event_kind public.ai_event_kind not null,
  feature text not null,
  input_tokens int null,
  output_tokens int null,
  model_name text null,
  cost_usd numeric(12,4) null,
  detail jsonb null,
  created_at timestamptz not null default now()
);

create table if not exists public.hos_dot_alerts (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  driver_id uuid not null,
  truck_id uuid null,
  alert_code text not null,
  severity int not null default 1,
  alert_at timestamptz not null default now(),
  window_start timestamptz null,
  window_end timestamptz null,
  meta jsonb null
);

create index if not exists hos_dot_alerts_driver_idx on public.hos_dot_alerts(org_id, driver_id, alert_at);

create table if not exists public.eta_predictions (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  load_id uuid not null,
  stop_sequence int not null default 1,
  predicted_at timestamptz not null default now(),
  predicted_eta timestamptz not null,
  base_eta timestamptz null,
  weather_delay_minutes int null,
  traffic_delay_minutes int null,
  model_version text null,
  source text null,
  explain jsonb null
);
create index if not exists eta_predictions_load_idx on public.eta_predictions(org_id, load_id);

create table if not exists public.stop_arrivals (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  load_id uuid not null,
  stop_sequence int not null,
  arrived_at timestamptz not null,
  created_at timestamptz not null default now()
);
create index if not exists stop_arrivals_load_idx on public.stop_arrivals(org_id, load_id);

-- 2.2 Customer-Facing Live Tracking ---------------------------------------------
create table if not exists public.tracking_links (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  load_id uuid not null,
  public_token text unique not null,
  expires_at timestamptz not null,
  created_by uuid null,
  created_at timestamptz not null default now(),
  revoked_at timestamptz null
);
create index if not exists tracking_links_token_idx on public.tracking_links(public_token);

-- 2.3 Back-Office / Accounting (IFTA, sync, payroll/settlement) -----------------
create table if not exists public.ifta_trips (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  driver_id uuid not null,
  truck_id uuid not null,
  state_code char(2) not null,
  start_odometer numeric(12,2) null,
  end_odometer numeric(12,2) null,
  miles numeric(12,2) not null,
  period_month int not null check (period_month between 1 and 12),
  period_year int not null,
  source text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
DO $$ BEGIN
  CREATE TRIGGER trg_ifta_trips_updated_at BEFORE UPDATE ON public.ifta_trips FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

create table if not exists public.ifta_fuel (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  truck_id uuid not null,
  state_code char(2) not null,
  gallons numeric(12,3) not null,
  amount_usd numeric(12,2) not null,
  purchased_at date not null,
  vendor text null,
  receipt_url text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
DO $$ BEGIN
  CREATE TRIGGER trg_ifta_fuel_updated_at BEFORE UPDATE ON public.ifta_fuel FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

create index if not exists ifta_trips_period_idx on public.ifta_trips(org_id, period_year, period_month, state_code);
create index if not exists ifta_fuel_date_idx on public.ifta_fuel(org_id, purchased_at, state_code);

create table if not exists public.accounting_sync_queue (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  provider public.accounting_provider not null,
  entity_type text not null,
  entity_id uuid not null,
  op text not null,
  status public.sync_status not null default 'queued',
  attempts int not null default 0,
  last_error text null,
  payload jsonb null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
DO $$ BEGIN
  CREATE TRIGGER trg_accounting_sync_q_updated_at BEFORE UPDATE ON public.accounting_sync_queue FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

create table if not exists public.payroll_settlements (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  driver_id uuid not null,
  period_start date not null,
  period_end date not null,
  gross_usd numeric(12,2) not null default 0,
  deductions_usd numeric(12,2) not null default 0,
  reimbursements_usd numeric(12,2) not null default 0,
  net_usd numeric(12,2) not null default 0,
  status text not null default 'pending',
  meta jsonb null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
DO $$ BEGIN
  CREATE TRIGGER trg_payroll_settlements_updated_at BEFORE UPDATE ON public.payroll_settlements FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

create index if not exists payroll_period_idx on public.payroll_settlements(org_id, period_start, period_end);

-- 2.4 Maintenance & Asset Management -------------------------------------------
create table if not exists public.assets (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  vin text unique,
  unit_number text,
  make text, model text, year int,
  in_service_date date null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
DO $$ BEGIN
  CREATE TRIGGER trg_assets_updated_at BEFORE UPDATE ON public.assets FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

create table if not exists public.work_orders (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  asset_id uuid not null references public.assets(id) on delete cascade,
  status public.work_order_status not null default 'open',
  opened_by uuid null,
  opened_at timestamptz not null default now(),
  closed_at timestamptz null,
  labor_hours numeric(10,2) not null default 0,
  labor_rate_usd numeric(10,2) not null default 0,
  parts_cost_usd numeric(12,2) not null default 0,
  total_cost_usd numeric(12,2) not null default 0,
  notes text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
DO $$ BEGIN
  CREATE TRIGGER trg_work_orders_updated_at BEFORE UPDATE ON public.work_orders FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
create index if not exists work_orders_asset_idx on public.work_orders(org_id, asset_id, status);

create table if not exists public.work_order_parts (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  work_order_id uuid not null references public.work_orders(id) on delete cascade,
  part_number text,
  description text,
  qty numeric(10,2) not null default 1,
  unit_cost_usd numeric(10,2) not null default 0,
  warranty_expires_on date null,
  created_at timestamptz not null default now()
);

create or replace function public.recalc_work_order_costs(p_work_order_id uuid)
returns void language plpgsql as $$
declare v_parts numeric(12,2);
begin
  select coalesce(sum(qty * unit_cost_usd),0) into v_parts from public.work_order_parts where work_order_id = p_work_order_id;
  update public.work_orders
  set parts_cost_usd = v_parts,
      total_cost_usd = v_parts + (labor_hours * labor_rate_usd),
      updated_at = now()
  where id = p_work_order_id;
end $$;

create or replace function public._wo_parts_after_change()
returns trigger language plpgsql as $$
begin
  perform public.recalc_work_order_costs(coalesce(new.work_order_id, old.work_order_id));
  return null;
end $$;

DROP TRIGGER IF EXISTS trg_wo_parts_aiud ON public.work_order_parts;
CREATE TRIGGER trg_wo_parts_aiud AFTER INSERT OR UPDATE OR DELETE ON public.work_order_parts
FOR EACH ROW EXECUTE FUNCTION public._wo_parts_after_change();

create table if not exists public.driver_repair_requests (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  asset_id uuid not null references public.assets(id) on delete cascade,
  driver_id uuid not null,
  priority public.repair_priority not null default 'medium',
  status text not null default 'new',
  description text not null,
  photo_urls text[] null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
DO $$ BEGIN
  CREATE TRIGGER trg_driver_repair_requests_updated_at BEFORE UPDATE ON public.driver_repair_requests FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 2.5 Load Optimization & Profit Analytics -------------------------------------
create table if not exists public.lanes (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  origin_market text not null,
  dest_market text not null,
  notes text null,
  created_at timestamptz not null default now()
);
create unique index if not exists lanes_org_origin_dest_uk on public.lanes(org_id, origin_market, dest_market);

create table if not exists public.lane_metrics_daily (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  lane_id uuid not null references public.lanes(id) on delete cascade,
  day date not null,
  loads_count int not null default 0,
  revenue_usd numeric(12,2) not null default 0,
  cost_usd numeric(12,2) not null default 0,
  miles numeric(12,2) not null default 0
);
create unique index if not exists lane_metrics_daily_uk on public.lane_metrics_daily(org_id, lane_id, day);
create index if not exists lane_metrics_daily_lane_idx on public.lane_metrics_daily(org_id, lane_id, day);

create table if not exists public.load_assignments (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  load_id uuid not null,
  driver_id uuid not null,
  decider public.assignment_decider not null default 'ai',
  score numeric(6,3) not null,
  reason jsonb null,
  assigned_at timestamptz not null default now()
);
create index if not exists assignments_load_idx on public.load_assignments(org_id, load_id);

create table if not exists public.broker_pricing (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  load_id uuid not null,
  spot_rate_usd numeric(12,2) null,
  contract_rate_usd numeric(12,2) null,
  model_rec_rate_usd numeric(12,2) null,
  model_version text null,
  inputs jsonb null,
  created_at timestamptz not null default now()
);

-- RLS enable + example org policy ------------------------------------------------
-- Helper view to resolve current user org_id (adjust to your profiles schema)
create or replace view public._me as
select u.id as user_id, p.org_id
from auth.users u
join public.profiles p on p.user_id = u.id
where u.id = auth.uid();

-- Enable RLS for all new tables
alter table public.ai_safety_events       enable row level security;
alter table public.hos_dot_alerts         enable row level security;
alter table public.eta_predictions        enable row level security;
alter table public.stop_arrivals          enable row level security;
alter table public.tracking_links         enable row level security;
alter table public.ifta_trips             enable row level security;
alter table public.ifta_fuel              enable row level security;
alter table public.accounting_sync_queue  enable row level security;
alter table public.payroll_settlements    enable row level security;
alter table public.assets                 enable row level security;
alter table public.work_orders            enable row level security;
alter table public.work_order_parts       enable row level security;
alter table public.driver_repair_requests enable row level security;
alter table public.lanes                  enable row level security;
alter table public.lane_metrics_daily     enable row level security;
alter table public.load_assignments       enable row level security;
alter table public.broker_pricing         enable row level security;

-- Example policies for ai_safety_events (pattern can be replicated as needed)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='ai_safety_events' AND policyname='sel_ai_safety_events') THEN
    CREATE POLICY sel_ai_safety_events ON public.ai_safety_events FOR SELECT USING (org_id = (select org_id from public._me));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='ai_safety_events' AND policyname='ins_ai_safety_events') THEN
    CREATE POLICY ins_ai_safety_events ON public.ai_safety_events FOR INSERT WITH CHECK (org_id = (select org_id from public._me));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='ai_safety_events' AND policyname='upd_ai_safety_events') THEN
    CREATE POLICY upd_ai_safety_events ON public.ai_safety_events FOR UPDATE USING (org_id = (select org_id from public._me));
  END IF;
END $$;

-- Analytics Views ----------------------------------------------------------------
create or replace view public.v_eta_accuracy as
select e.org_id,e.load_id,e.stop_sequence,e.predicted_at,e.predicted_eta,a.arrived_at,
extract(epoch from (a.arrived_at - e.predicted_eta))/60.0 as error_minutes,
e.weather_delay_minutes,e.traffic_delay_minutes,e.model_version
from public.eta_predictions e
join public.stop_arrivals a on a.org_id=e.org_id and a.load_id=e.load_id and a.stop_sequence=e.stop_sequence;

create or replace view public.v_tracking_link_status as
select org_id,
count(*) filter (where revoked_at is null and expires_at>now()) as active_links,
count(*) filter (where revoked_at is not null) as revoked_links,
count(*) filter (where expires_at<=now() and revoked_at is null) as expired_links
from public.tracking_links group by org_id;

create or replace view public.v_ifta_state_monthly as
select t.org_id,t.period_year,t.period_month,t.state_code,
sum(t.miles) as miles,
sum(f.gallons) as gallons,
sum(f.amount_usd) as fuel_spend_usd
from public.ifta_trips t
left join public.ifta_fuel f
  on f.org_id=t.org_id and f.state_code=t.state_code
 and extract(year from f.purchased_at)=t.period_year
 and extract(month from f.purchased_at)=t.period_month
group by 1,2,3,4;

create or replace view public.v_accounting_sync_health as
select org_id,provider,
count(*) filter (where status='queued') as queued,
count(*) filter (where status='processing') as processing,
count(*) filter (where status='success') as success,
count(*) filter (where status='error') as errors,
count(*) filter (where status='dead_letter') as dead_letters
from public.accounting_sync_queue group by 1,2;

create or replace view public.v_payroll_period_summary as
select org_id,period_start,period_end,
sum(gross_usd) as gross_usd,
sum(deductions_usd) as deductions_usd,
sum(reimbursements_usd) as reimbursements_usd,
sum(net_usd) as net_usd
from public.payroll_settlements group by 1,2,3;

create or replace view public.v_maintenance_backlog as
select org_id,
count(*) filter (where status in ('open','in_progress','on_hold')) as open_work_orders,
count(*) filter (where status='closed') as closed_work_orders_ever
from public.work_orders group by org_id;

create or replace view public.v_maintenance_costs_monthly as
select org_id,date_trunc('month',opened_at)::date as month,sum(total_cost_usd) as total_cost_usd
from public.work_orders group by 1,2;

create or replace view public.v_lane_profitability as
select lm.org_id,l.origin_market,l.dest_market,
sum(lm.revenue_usd) as revenue_usd,
sum(lm.cost_usd) as cost_usd,
sum(lm.miles) as miles,
case when sum(lm.miles)>0 then sum(lm.revenue_usd)/sum(lm.miles) end as rev_per_mile,
case when sum(lm.miles)>0 then sum(lm.cost_usd)/sum(lm.miles) end as cost_per_mile,
(sum(lm.revenue_usd)-sum(lm.cost_usd)) as gross_profit_usd
from public.lane_metrics_daily lm
join public.lanes l on l.id=lm.lane_id
group by 1,2,3;

create or replace view public.v_assignment_effectiveness as
select org_id,decider,count(*) as assignments,avg(score) as avg_score
from public.load_assignments group by 1,2;

create or replace view public.v_broker_pricing_deltas as
select org_id,
avg(model_rec_rate_usd - spot_rate_usd) as avg_delta_vs_spot,
avg(model_rec_rate_usd - contract_rate_usd) as avg_delta_vs_contract
from public.broker_pricing
where model_rec_rate_usd is not null
group by 1;
