-- =====================================================================
-- HOS & ELD (counters, alerts, auto-logbook inference)
-- =====================================================================

-- Helpers to read JWT claims (stable functions)
create or replace function current_org_id() returns uuid
language sql stable as $$
  select nullif(auth.jwt()->>'app_org_id','')::uuid
$$;

create or replace function current_role() returns text
language sql stable as $$
  select coalesce(auth.jwt()->>'app_role','')
$$;

-- Rolling counters snapshot per driver (fast read for UI / alerts)
create table if not exists public.hos_counters (
  driver_id uuid primary key references public.drivers(id) on delete cascade,
  org_id uuid not null references public.orgs(id) on delete cascade,

  -- Remaining times (seconds) as of refreshed_at
  remaining_drive_s int not null default 0,      -- 11-hr rule (US)
  remaining_shift_s int not null default 0,      -- 14-hr rule (US)
  remaining_break_s int not null default 0,      -- 30-min break remaining until due
  remaining_cycle_s int not null default 0,      -- 60/70 hr cycle remaining

  last_duty_status text,
  last_status_at timestamptz,
  jurisdiction text,
  cycle_scheme text default 'US_70_8',           -- e.g., US_70_8, US_60_7, CA_South, CA_North

  refreshed_at timestamptz not null default now(),
  constraint hos_counters_org_fk check (org_id is not null)
);
comment on table public.hos_counters is 'Computed HOS counters per driver; updated by compute_hos()';

create index if not exists idx_hos_counters_org on public.hos_counters(org_id);
create index if not exists idx_hos_counters_refresh on public.hos_counters(refreshed_at);

-- Alert envelope (push to app/dispatcher)
create table if not exists public.hos_alerts (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id) on delete cascade,
  driver_id uuid not null references public.drivers(id) on delete cascade,
  code text not null,                              -- e.g., 'HOS_BREAK_DUE', 'HOS_DRIVE_NEAR_LIMIT'
  severity text not null default 'warn',          -- info|warn|p1
  message text not null,
  context jsonb,
  created_at timestamptz not null default now(),
  acknowledged_at timestamptz
);
create index if not exists idx_hos_alerts_org_created on public.hos_alerts(org_id, created_at desc);
create index if not exists idx_hos_alerts_driver_created on public.hos_alerts(driver_id, created_at desc);

-- Pending corrections: inferred logbook gaps needing review
create table if not exists public.hos_logbook_infer_queue (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id) on delete cascade,
  driver_id uuid not null references public.drivers(id) on delete cascade,
  suspected_from timestamptz not null,
  suspected_to timestamptz not null,
  inferred_status text not null,                   -- suggested duty status to fill the gap
  confidence numeric not null default 0.7 check (confidence >= 0 and confidence <= 1),
  state text not null default 'open',              -- open|applied|dismissed
  created_at timestamptz not null default now(),
  reviewed_by uuid
);
create index if not exists idx_hos_infer_org_state on public.hos_logbook_infer_queue(org_id, state);
create index if not exists idx_hos_infer_driver on public.hos_logbook_infer_queue(driver_id);

-- Minimal RPCs (stubs) for Edge Functions
create or replace function public.upsert_hos_counters(
  p_driver uuid,
  p_org uuid,
  p_remaining_drive_s int,
  p_remaining_shift_s int,
  p_remaining_break_s int,
  p_remaining_cycle_s int,
  p_last_status text,
  p_last_at timestamptz,
  p_jurisdiction text,
  p_cycle_scheme text
) returns void
language plpgsql
security definer
set search_path=public as $$
begin
  insert into public.hos_counters(driver_id, org_id, remaining_drive_s, remaining_shift_s, remaining_break_s,
                                  remaining_cycle_s, last_duty_status, last_status_at, jurisdiction, cycle_scheme)
  values (p_driver, p_org, p_remaining_drive_s, p_remaining_shift_s, p_remaining_break_s,
          p_remaining_cycle_s, p_last_status, p_last_at, p_jurisdiction, coalesce(p_cycle_scheme,'US_70_8'))
  on conflict (driver_id) do update set
    remaining_drive_s = excluded.remaining_drive_s,
    remaining_shift_s = excluded.remaining_shift_s,
    remaining_break_s = excluded.remaining_break_s,
    remaining_cycle_s = excluded.remaining_cycle_s,
    last_duty_status = excluded.last_duty_status,
    last_status_at   = excluded.last_status_at,
    jurisdiction     = excluded.jurisdiction,
    cycle_scheme     = excluded.cycle_scheme,
    refreshed_at     = now();
end $$;

create or replace function public.hos_alert(
  p_org uuid, p_driver uuid, p_code text, p_severity text, p_message text, p_context jsonb
) returns uuid
language plpgsql
security definer
set search_path=public as $$
declare rid uuid;
begin
  insert into public.hos_alerts(org_id, driver_id, code, severity, message, context)
  values (p_org, p_driver, p_code, coalesce(p_severity,'warn'), p_message, p_context)
  returning id into rid;
  return rid;
end $$;

create or replace function public.hos_queue_infer(
  p_org uuid, p_driver uuid, p_from timestamptz, p_to timestamptz, p_status text, p_conf numeric
) returns uuid
language plpgsql
security definer
set search_path=public as $$
declare rid uuid;
begin
  insert into public.hos_logbook_infer_queue(org_id, driver_id, suspected_from, suspected_to, inferred_status, confidence)
  values (p_org, p_driver, p_from, p_to, p_status, coalesce(p_conf,0.7))
  returning id into rid;
  return rid;
end $$;

-- RLS
alter table public.hos_counters enable row level security;
alter table public.hos_alerts enable row level security;
alter table public.hos_logbook_infer_queue enable row level security;

-- Org isolation
create policy hos_counters_isolation on public.hos_counters
  for select using (org_id = current_org_id());
create policy hos_alerts_isolation on public.hos_alerts
  for select using (org_id = current_org_id());
create policy hos_infer_isolation on public.hos_logbook_infer_queue
  for select using (org_id = current_org_id());

-- Driver self-access
create policy hos_counters_driver_self on public.hos_counters
  for select using (driver_id in (select d.id from public.drivers d where d.user_id = auth.uid()));
create policy hos_alerts_driver_self on public.hos_alerts
  for select using (driver_id in (select d.id from public.drivers d where d.user_id = auth.uid()));

-- Writes limited to admins/service role
create policy hos_write_admin on public.hos_counters
  for insert with check ((current_role() in ('admin','fleet_admin')) and org_id = current_org_id());
create policy hos_write_admin_upd on public.hos_counters
  for update using (org_id = current_org_id() and current_role() in ('admin','fleet_admin'));

create policy hos_alerts_write on public.hos_alerts
  for insert with check (org_id = current_org_id() and current_role() in ('admin','fleet_admin'));

create policy hos_infer_write on public.hos_logbook_infer_queue
  for insert with check (org_id = current_org_id() and current_role() in ('admin','fleet_admin'));
create policy hos_infer_update on public.hos_logbook_infer_queue
  for update using (org_id = current_org_id() and current_role() in ('admin','fleet_admin'));

-- =====================================================================
-- IFTA (quarters, ledger rollup, fuel purchases)
-- =====================================================================

create table if not exists public.ifta_quarters (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id) on delete cascade,
  year int not null check (year >= 2000),
  quarter int not null check (quarter between 1 and 4),
  start_date date not null,
  end_date date not null,
  unique (org_id, year, quarter)
);
create index if not exists idx_ifta_quarters_org on public.ifta_quarters(org_id);

create table if not exists public.fuel_purchases (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id) on delete cascade,
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  purchased_at timestamptz not null,
  gallons numeric not null check (gallons >= 0),
  price_cents int,
  station_name text,
  jurisdiction text,
  source text,
  raw jsonb
);
create index if not exists idx_fuel_purchases_org_date on public.fuel_purchases(org_id, purchased_at);

create table if not exists public.ifta_ledger (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id) on delete cascade,
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  ifta_quarter_id uuid not null references public.ifta_quarters(id) on delete cascade,
  jurisdiction text not null,
  miles numeric not null default 0,
  gallons numeric not null default 0,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique (vehicle_id, ifta_quarter_id, jurisdiction)
);
create index if not exists idx_ifta_ledger_org_q on public.ifta_ledger(org_id, ifta_quarter_id);

create or replace view public.v_ifta_summary as
select l.org_id, l.vehicle_id, q.year, q.quarter, l.jurisdiction, l.miles, l.gallons
from public.ifta_ledger l
join public.ifta_quarters q on q.id = l.ifta_quarter_id;

create or replace function public.ifta_rollup(p_org uuid, p_year int, p_quarter int)
returns int
language plpgsql
security definer
set search_path=public as $$
declare qid uuid; cnt int:=0;
begin
  select id into qid from public.ifta_quarters
  where org_id=p_org and year=p_year and quarter=p_quarter;
  if qid is null then
    raise exception 'IFTA quarter not found for org=% and %Q%', p_org, p_year || '-' || p_quarter;
  end if;

  -- Merge miles from precomputed tmp_ifta_miles(vehicle_id, jurisdiction, miles)
  insert into public.ifta_ledger(org_id, vehicle_id, ifta_quarter_id, jurisdiction, miles, gallons)
  select p_org, m.vehicle_id, qid, m.jurisdiction, m.miles, 0
  from public.tmp_ifta_miles m
  on conflict (vehicle_id, ifta_quarter_id, jurisdiction) do update
    set miles = excluded.miles, updated_at = now();
  GET DIAGNOSTICS cnt = ROW_COUNT;

  -- Merge gallons from fuel_purchases within quarter window
  update public.ifta_ledger l
     set gallons = coalesce(g.gallons, 0), updated_at=now()
  from (
    select vehicle_id, jurisdiction, sum(gallons) as gallons
    from public.fuel_purchases
    where org_id = p_org
      and purchased_at::date between (select start_date from public.ifta_quarters where id=qid)
                                 and (select end_date   from public.ifta_quarters where id=qid)
    group by vehicle_id, jurisdiction
  ) g
  where l.ifta_quarter_id = qid
    and l.vehicle_id = g.vehicle_id and l.jurisdiction = g.jurisdiction;

  return cnt;
end $$;

-- RLS
alter table public.ifta_quarters enable row level security;
alter table public.fuel_purchases enable row level security;
alter table public.ifta_ledger enable row level security;

create policy ifta_q_org on public.ifta_quarters for select using (org_id = current_org_id());
create policy ifta_fp_org on public.fuel_purchases for select using (org_id = current_org_id());
create policy ifta_led_org on public.ifta_ledger for select using (org_id = current_org_id());

create policy ifta_q_write on public.ifta_quarters for insert with check (org_id = current_org_id() and current_role() in ('admin','fleet_admin'));
create policy ifta_led_write on public.ifta_ledger for insert with check (org_id = current_org_id() and current_role() in ('admin','fleet_admin'));
create policy ifta_led_upd on public.ifta_ledger for update using (org_id = current_org_id() and current_role() in ('admin','fleet_admin'));
create policy fuel_purchases_write on public.fuel_purchases for insert with check (org_id = current_org_id() and current_role() in ('admin','fleet_admin'));

-- =====================================================================
-- DQF (Driver Qualification Files)
-- =====================================================================

create table if not exists public.driver_quals (
  driver_id uuid primary key references public.drivers(id) on delete cascade,
  org_id uuid not null references public.orgs(id) on delete cascade,

  med_card_expiry date,
  license_class text,
  endorsements text[],
  last_training_at date,
  status text not null default 'pending'           -- pending|active|suspended
);
create index if not exists idx_driver_quals_org on public.driver_quals(org_id);

create table if not exists public.driver_docs (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references public.drivers(id) on delete cascade,
  org_id uuid not null references public.orgs(id) on delete cascade,
  type text not null,                               -- 'license','med_card','mvr','training','other'
  url text not null,
  issued_at date,
  expires_at date,
  meta jsonb,
  uploaded_by uuid,
  created_at timestamptz default now()
);
create index if not exists idx_driver_docs_driver on public.driver_docs(driver_id);
create index if not exists idx_driver_docs_org on public.driver_docs(org_id);
create index if not exists idx_driver_docs_exp on public.driver_docs(expires_at);

create or replace view public.v_dqf_expiring_soon as
select d.driver_id, d.type, d.expires_at, dq.status, d.org_id
from public.driver_docs d
left join public.driver_quals dq on dq.driver_id = d.driver_id
where d.expires_at is not null and d.expires_at <= current_date + 30;

create table if not exists public.dqf_notices (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id) on delete cascade,
  driver_id uuid not null references public.drivers(id) on delete cascade,
  doc_type text not null,
  expires_at date,
  sent_at timestamptz,
  created_at timestamptz default now(),
  unique(org_id, driver_id, doc_type, expires_at)
);

-- RLS
alter table public.driver_quals enable row level security;
alter table public.driver_docs enable row level security;
alter table public.dqf_notices enable row level security;

create policy dqf_quals_org on public.driver_quals for select using (org_id = current_org_id());
create policy dqf_docs_org  on public.driver_docs  for select using (org_id = current_org_id());
create policy dqf_notices_org on public.dqf_notices for select using (org_id = current_org_id());

create policy dqf_quals_self on public.driver_quals
  for select using (driver_id in (select id from public.drivers where user_id = auth.uid()));
create policy dqf_docs_self on public.driver_docs
  for select using (driver_id in (select id from public.drivers where user_id = auth.uid()));

create policy dqf_quals_write on public.driver_quals
  for insert with check (org_id = current_org_id() and current_role() in ('admin','fleet_admin'));
create policy dqf_quals_upd on public.driver_quals
  for update using (org_id = current_org_id() and current_role() in ('admin','fleet_admin'));

create policy dqf_docs_write on public.driver_docs
  for insert with check (org_id = current_org_id() and current_role() in ('admin','fleet_admin'));
create policy dqf_docs_upd on public.driver_docs
  for update using (org_id = current_org_id() and current_role() in ('admin','fleet_admin'));
create policy dqf_notices_write on public.dqf_notices
  for insert with check (org_id = current_org_id() and current_role() in ('admin','fleet_admin'));

-- =====================================================================
-- Safety / CSA (BASIC mapping, scores, coaching workflow)
-- =====================================================================

create table if not exists public.safety_event_mapping (
  code text primary key,
  basic text not null,                  -- 'Unsafe Driving','HOS Compliance','Crash Indicator',...
  weight numeric not null default 1.0,
  decay_days int not null default 180
);
create table if not exists public.driver_safety_scores (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id) on delete cascade,
  driver_id uuid not null references public.drivers(id) on delete cascade,
  basic text not null,
  window_days int not null default 90,
  score numeric not null,
  events int not null default 0,
  refreshed_at timestamptz not null default now(),
  unique (driver_id, basic, window_days)
);
create index if not exists idx_safety_scores_org on public.driver_safety_scores(org_id);
create index if not exists idx_safety_scores_driver on public.driver_safety_scores(driver_id);

create table if not exists public.coaching_tasks (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id) on delete cascade,
  driver_id uuid not null references public.drivers(id) on delete cascade,
  basic text not null,
  reason text not null,
  status text not null default 'open',            -- open|in_progress|done|dismissed
  created_at timestamptz not null default now(),
  due_at timestamptz,
  closed_at timestamptz
);
create index if not exists idx_coaching_tasks_org_status on public.coaching_tasks(org_id, status);
create index if not exists idx_coaching_tasks_driver on public.coaching_tasks(driver_id);

create table if not exists public.coaching_outcomes (
  id uuid primary key default gen_random_uuid(),
  coaching_task_id uuid not null references public.coaching_tasks(id) on delete cascade,
  note text,
  action text,
  created_by uuid,
  created_at timestamptz default now()
);

create or replace function public.refresh_safety_scores(p_org uuid, p_window int default 90)
returns int language plpgsql security definer set search_path=public as $$
declare cnt int:=0;
begin
  -- Expect tmp_scores(org_id, driver_id, basic, window_days, score, events) precomputed
  insert into public.driver_safety_scores(org_id, driver_id, basic, window_days, score, events)
  select org_id, driver_id, basic, p_window, score, events
  from public.tmp_scores where org_id = p_org and window_days = p_window
  on conflict (driver_id, basic, window_days) do update
    set score = excluded.score, events = excluded.events, refreshed_at = now();
  GET DIAGNOSTICS cnt = ROW_COUNT;
  return cnt;
end $$;

-- RLS
alter table public.safety_event_mapping enable row level security;
alter table public.driver_safety_scores enable row level security;
alter table public.coaching_tasks enable row level security;
alter table public.coaching_outcomes enable row level security;

create policy map_read on public.safety_event_mapping for select using (current_role() in ('admin','fleet_admin'));
create policy map_write on public.safety_event_mapping for all using (false) with check (current_role() in ('admin','fleet_admin'));

create policy scores_org on public.driver_safety_scores for select using (org_id = current_org_id());
create policy scores_self on public.driver_safety_scores
  for select using (driver_id in (select id from public.drivers where user_id = auth.uid()));

create policy coach_org on public.coaching_tasks for select using (org_id = current_org_id());
create policy coach_self on public.coaching_tasks
  for select using (driver_id in (select id from public.drivers where user_id = auth.uid()));

create policy coach_write on public.coaching_tasks
  for insert with check (org_id = current_org_id() and current_role() in ('admin','fleet_admin'));
create policy coach_upd on public.coaching_tasks
  for update using (org_id = current_org_id() and current_role() in ('admin','fleet_admin'));

create policy outcome_read on public.coaching_outcomes
  for select using (coaching_task_id in (select id from public.coaching_tasks where org_id = current_org_id()));
create policy outcome_write on public.coaching_outcomes
  for insert with check (
    coaching_task_id in (select id from public.coaching_tasks where org_id = current_org_id() and current_role() in ('admin','fleet_admin'))
  );
