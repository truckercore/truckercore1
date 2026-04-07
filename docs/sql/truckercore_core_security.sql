-- =========================================
-- TruckerCore Core Security & Helpers
-- Safe-to-rerun (idempotent) module
-- =========================================

-- 0) Extensions
create extension if not exists "uuid-ossp";
create extension if not exists pgcrypto;

-- 1) Helper claims accessors (stable)
create or replace function current_org_id() returns uuid
language sql stable as $$
  select nullif(auth.jwt()->>'app_org_id','')::uuid
$$;

create or replace function current_role() returns text
language sql stable as $$
  select coalesce(auth.jwt()->>'app_role','')
$$;

create or replace function current_driver_id() returns uuid
language sql stable as $$
  select nullif(auth.jwt()->>'driver_id','')::uuid
$$;

create or replace function is_org_admin() returns boolean
language sql stable as $$
  select current_role() in ('fleet_admin','admin')
$$;

create or replace function is_auditor() returns boolean
language sql stable as $$
  select current_role() = 'auditor'
$$;

-- 2) Generic audit log (append-only, tamper-evident)
create table if not exists audit_log (
  id            bigserial primary key,
  at            timestamptz not null default now(),
  actor_user    uuid,
  actor_org     uuid,
  action        text not null,          -- e.g. 'insert','update','delete','export','edit_hos'
  table_name    text,
  row_pk        uuid,
  before        jsonb,
  after         jsonb,
  hash          text                     -- sha256(previous_hash || new_row_json)
);

create or replace function audit_log_chain() returns trigger
language plpgsql as $$
declare prev text;
begin
  select hash into prev from audit_log order by at desc limit 1;
  new.hash := encode(digest(coalesce(prev,'') || row_to_json(new)::text, 'sha256'),'hex');
  return new;
end $$;

drop trigger if exists tr_audit_chain on audit_log;
create trigger tr_audit_chain before insert on audit_log
for each row execute function audit_log_chain();

create or replace function audit_row_change() returns trigger
language plpgsql security definer set search_path=public as $$
begin
  insert into audit_log(actor_user, actor_org, action, table_name, row_pk, before, after)
  values (auth.uid(), current_org_id(), tg_op::text, tg_table_name,
          coalesce((new).id,(old).id),
          case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) end,
          case when tg_op in ('INSERT','UPDATE') then to_jsonb(new) end);
  return coalesce(new, old);
end $$;

-- =========================================
-- MODULE 1: Driver Retention & Satisfaction
-- =========================================

-- Drivers & trucks (minimal)
create table if not exists drivers (
  id            uuid primary key default uuid_generate_v4(),
  org_id        uuid not null,
  auth_user_id  uuid unique,                      -- optional link to auth.users.id
  full_name     text not null,
  hired_at      date,
  active        boolean not null default true,
  created_at    timestamptz default now()
);
create index if not exists idx_drivers_org on drivers(org_id);
alter table drivers enable row level security;

create policy if not exists drivers_ro on drivers for select
  using (
    org_id = current_org_id()
    and (
      is_org_admin() or is_auditor()
      or (current_role() = 'driver' and id = current_driver_id())
    )
  );

create policy if not exists drivers_self_update on drivers for update
  using (id = current_driver_id() and org_id = current_org_id())
  with check (id = current_driver_id() and org_id = current_org_id());

create policy if not exists drivers_admin_write on drivers for all
  using (org_id = current_org_id() and is_org_admin())
  with check (org_id = current_org_id() and is_org_admin());

-- Loads (simplified reference for earnings)
create table if not exists loads (
  id              uuid primary key default uuid_generate_v4(),
  org_id          uuid not null,
  ref_number      text,
  pickup_at       timestamptz,
  dropoff_at      timestamptz,
  pickup_loc      jsonb,                          -- {lat,lng,address}
  dropoff_loc     jsonb,
  created_at      timestamptz default now()
);
create index if not exists idx_loads_org on loads(org_id);
alter table loads enable row level security;
create policy if not exists loads_ro on loads for select using (org_id = current_org_id());
create policy if not exists loads_rw on loads for all using (org_id = current_org_id() and is_org_admin()) with check (org_id = current_org_id());

-- Driver miles (GPS-derived; separates paid vs. deadhead)
create table if not exists driver_miles (
  id              uuid primary key default uuid_generate_v4(),
  org_id          uuid not null,
  driver_id       uuid not null references drivers(id) on delete cascade,
  load_id         uuid references loads(id) on delete set null,
  date            date not null,
  miles_paid      numeric(10,2) not null default 0,
  miles_deadhead  numeric(10,2) not null default 0,
  miles_total     numeric(10,2) generated always as (miles_paid + miles_deadhead) stored,
  source          text not null default 'gps',     -- gps/eld/manual
  created_at      timestamptz default now(),
  unique(org_id, driver_id, date, coalesce(load_id, '00000000-0000-0000-0000-000000000000'::uuid))
);
create index if not exists idx_driver_miles_org_driver_date on driver_miles(org_id, driver_id, date);
alter table driver_miles enable row level security;

create policy if not exists driver_miles_ro on driver_miles for select
  using (
    org_id = current_org_id()
    and (
      is_org_admin() or is_auditor()
      or (current_role() = 'driver' and driver_id = current_driver_id())
    )
  );

create policy if not exists driver_miles_admin_write on driver_miles for all
  using (org_id = current_org_id() and is_org_admin())
  with check (org_id = current_org_id());

-- Driver earnings breakdown
create table if not exists driver_earnings (
  id              uuid primary key default uuid_generate_v4(),
  org_id          uuid not null,
  driver_id       uuid not null references drivers(id) on delete cascade,
  load_id         uuid references loads(id) on delete set null,
  period_start    date not null,
  period_end      date not null,
  pay_type        text not null,         -- 'per_mile'|'per_load'|'bonus'
  rate_cents      bigint not null,       -- per mile or flat
  paid_miles      numeric(10,2) not null default 0,
  gross_cents     bigint not null,
  notes           text,
  created_at      timestamptz default now()
);
create index if not exists idx_driver_earnings_org_driver_period on driver_earnings(org_id, driver_id, period_start, period_end);
alter table driver_earnings enable row level security;

create policy if not exists driver_earnings_ro on driver_earnings for select
  using (
    org_id = current_org_id()
    and (
      is_org_admin() or is_auditor()
      or (current_role() = 'driver' and driver_id = current_driver_id())
    )
  );
create policy if not exists driver_earnings_admin_write on driver_earnings for all
  using (org_id = current_org_id() and is_org_admin())
  with check (org_id = current_org_id());

-- HOS counters (daily snapshot)
create table if not exists driver_hos (
  id              uuid primary key default uuid_generate_v4(),
  org_id          uuid not null,
  driver_id       uuid not null references drivers(id) on delete cascade,
  snapshot_at     timestamptz not null,
  on_duty_min     int not null default 0,
  driving_min     int not null default 0,
  rest_min        int not null default 0,
  violations      jsonb,                -- e.g., {"11hr":false,"14hr":true}
  created_at      timestamptz default now(),
  unique (org_id, driver_id, snapshot_at)
);
create index if not exists idx_driver_hos_org_driver_time on driver_hos(org_id, driver_id, snapshot_at desc);
alter table driver_hos enable row level security;
create policy if not exists driver_hos_ro on driver_hos for select
  using (org_id = current_org_id() and (is_org_admin() or is_auditor() or (current_role()='driver' and driver_id=current_driver_id())));
create policy if not exists driver_hos_admin_write on driver_hos for all
  using (org_id = current_org_id() and is_org_admin())
  with check (org_id = current_org_id());

-- Driver badges (recognition)
create table if not exists driver_badges_catalog (
  code          text primary key,                     -- 'on_time_50','safe_25k'
  title         text not null,
  description   text,
  points        int not null default 0,
  icon          text                                   -- optional storage url
);

create table if not exists driver_badges (
  id            uuid primary key default uuid_generate_v4(),
  org_id        uuid not null,
  driver_id     uuid not null references drivers(id) on delete cascade,
  badge_code    text not null references driver_badges_catalog(code) on delete restrict,
  earned_at     timestamptz not null default now(),
  source        text not null default 'auto',          -- auto/manual
  unique(org_id, driver_id, badge_code)
);
create index if not exists idx_driver_badges_org_driver on driver_badges(org_id, driver_id);
alter table driver_badges enable row level security;
create policy if not exists driver_badges_ro on driver_badges for select
  using (org_id = current_org_id() and (is_org_admin() or is_auditor() or (current_role()='driver' and driver_id=current_driver_id())));
create policy if not exists driver_badges_admin on driver_badges for all
  using (org_id = current_org_id() and is_org_admin())
  with check (org_id = current_org_id());

-- Driver communications (chat threads minimal)
create table if not exists driver_threads (
  id            uuid primary key default uuid_generate_v4(),
  org_id        uuid not null,
  subject       text,
  created_by    uuid not null,                           -- auth.user
  created_at    timestamptz default now()
);
create table if not exists driver_messages (
  id            uuid primary key default uuid_generate_v4(),
  org_id        uuid not null,
  thread_id     uuid not null references driver_threads(id) on delete cascade,
  sender_user   uuid not null,                           -- auth.user
  sender_role   text not null,
  message       text not null,
  created_at    timestamptz default now()
);
create index if not exists idx_driver_messages_thread on driver_messages(thread_id, created_at);
alter table driver_threads enable row level security;
alter table driver_messages enable row level security;

create policy if not exists threads_ro on driver_threads for select using (org_id = current_org_id());
create policy if not exists threads_rw on driver_threads for all using (org_id = current_org_id()) with check (org_id = current_org_id());

create policy if not exists msgs_ro on driver_messages for select using (org_id = current_org_id());
create policy if not exists msgs_rw on driver_messages for insert with check (org_id = current_org_id());
create policy if not exists msgs_admin_upd_del on driver_messages for update using (org_id = current_org_id() and is_org_admin()) with check (org_id = current_org_id());
create policy if not exists msgs_admin_del on driver_messages for delete using (org_id = current_org_id() and is_org_admin());

-- Audit triggers (key tables)
create trigger if not exists tr_audit_driver_miles after insert or update or delete on driver_miles
for each row execute function audit_row_change();
create trigger if not exists tr_audit_driver_earnings after insert or update or delete on driver_earnings
for each row execute function audit_row_change();
create trigger if not exists tr_audit_badges after insert or update or delete on driver_badges
for each row execute function audit_row_change();

-- Views: Driver dashboard (actual vs promised)
create or replace view v_driver_dashboard as
select
  d.id as driver_id, d.full_name, dm.date,
  dm.miles_paid, dm.miles_deadhead, dm.miles_total,
  coalesce(e.gross_cents,0) as earnings_cents
from drivers d
left join driver_miles dm on dm.driver_id = d.id and dm.org_id = d.org_id
left join lateral (
  select sum(gross_cents) as gross_cents
  from driver_earnings de
  where de.driver_id = d.id and de.org_id = d.org_id
    and dm.date between de.period_start and de.period_end
) e on true
where d.org_id = current_org_id();

-- =========================================
-- MODULE 2: Cost & Inefficiency
-- =========================================

-- Route choices + outcomes (for optimization analytics)
create table if not exists route_choices (
  id            uuid primary key default uuid_generate_v4(),
  org_id        uuid not null,
  driver_id     uuid references drivers(id) on delete set null,
  load_id       uuid references loads(id) on delete set null,
  planned_path  jsonb not null,                 -- polyline/waypoints
  chosen_path   jsonb,                          -- post-optimization
  estimated_fuel_gal numeric(10,2),
  actual_fuel_gal    numeric(10,2),
  estimated_cost_cents bigint,
  actual_cost_cents    bigint,
  deadhead_miles  numeric(10,2),
  started_at      timestamptz,
  completed_at    timestamptz,
  created_at      timestamptz default now()
);
create index if not exists idx_route_choices_org on route_choices(org_id, created_at desc);
alter table route_choices enable row level security;
create policy if not exists route_choices_ro on route_choices for select using (org_id = current_org_id());
create policy if not exists route_choices_rw on route_choices for all using (org_id = current_org_id() and is_org_admin()) with check (org_id = current_org_id());

-- Maintenance logs
create table if not exists maintenance_logs (
  id            uuid primary key default uuid_generate_v4(),
  org_id        uuid not null,
  truck_vin     text not null,
  odometer_mi   int,
  service_type  text not null,                 -- 'oil','brake','tire','inspection','oem'
  notes         text,
  service_at    timestamptz not null,
  next_due_mi   int,
  next_due_at   date,
  created_at    timestamptz default now()
);
create index if not exists idx_maint_org_vin on maintenance_logs(org_id, truck_vin, service_at desc);
alter table maintenance_logs enable row level security;
create policy if not exists maint_ro on maintenance_logs for select using (org_id = current_org_id());
create policy if not exists maint_rw on maintenance_logs for all using (org_id = current_org_id() and is_org_admin()) with check (org_id = current_org_id());

-- Fuel prices (competitor & own)
create table if not exists fuel_prices (
  id            uuid primary key default uuid_generate_v4(),
  org_id        uuid,                            -- null = public competitor feed
  station_id    text not null,
  region        text,
  price_cents   int not null,
  captured_at   timestamptz not null default now(),
  source        text not null                    -- 'competitor','own'
);
create index if not exists idx_fuel_station_time on fuel_prices(station_id, captured_at desc);
alter table fuel_prices enable row level security;
create policy if not exists fuel_public_ro on fuel_prices for select using (org_id is null or org_id = current_org_id());
create policy if not exists fuel_org_rw on fuel_prices for all using (org_id = current_org_id() and is_org_admin()) with check (org_id = current_org_id());

-- Parking status (crowd/IoT)
create table if not exists parking_status (
  id            uuid primary key default uuid_generate_v4(),
  poi_id        text not null,                   -- truck stop id
  org_id        uuid,                            -- null = public crowd/IoT
  capacity      int,
  occupied      int,
  observed_at   timestamptz not null default now(),
  source        text not null                    -- 'iot','crowd','partner'
);
create index if not exists idx_parking_poi_time on parking_status(poi_id, observed_at desc);
alter table parking_status enable row level security;
create policy if not exists parking_ro on parking_status for select using (org_id is null or org_id = current_org_id());
create policy if not exists parking_rw on parking_status for all using (org_id = current_org_id() and is_org_admin()) with check (org_id = current_org_id());

-- Expenses (for ROI views)
create table if not exists expenses (
  id            uuid primary key default uuid_generate_v4(),
  org_id        uuid not null,
  driver_id     uuid references drivers(id) on delete set null,
  load_id       uuid references loads(id) on delete set null,
  category      text not null,                   -- 'fuel','toll','maint','parking','other'
  amount_cents  bigint not null,
  occurred_at   timestamptz not null,
  meta          jsonb,
  receipt_url   text,
  created_at    timestamptz default now()
);
create index if not exists idx_expenses_org_time on expenses(org_id, occurred_at desc);
alter table expenses enable row level security;
create policy if not exists expenses_ro on expenses for select using (
  org_id = current_org_id() and (is_org_admin() or is_auditor() or (current_role()='driver' and driver_id=current_driver_id()))
);
create policy if not exists expenses_rw on expenses for all using (org_id = current_org_id() and is_org_admin()) with check (org_id = current_org_id());

-- Analytics-ready views (examples)
create or replace view v_fleet_costs as
select
  l.org_id,
  date_trunc('week', coalesce(rc.completed_at, e.occurred_at)) as week,
  sum(e.amount_cents) as total_expense_cents,
  sum(case when e.category='fuel' then e.amount_cents else 0 end) as fuel_cents,
  sum(rc.deadhead_miles)::numeric as deadhead_miles
from loads l
left join route_choices rc on rc.load_id = l.id and rc.org_id = l.org_id
left join expenses e on e.load_id = l.id and e.org_id = l.org_id
group by 1,2
having l.org_id = current_org_id();

-- =========================================
-- MODULE 3: Compliance & Liability
-- =========================================

-- Inspection reports (pre/post trip) with storage linkage
create table if not exists inspection_reports (
  id            uuid primary key default uuid_generate_v4(),
  org_id        uuid not null,
  driver_id     uuid references drivers(id) on delete set null,
  truck_vin     text,
  type          text not null,                   -- 'pre_trip'|'post_trip'
  reported_at   timestamptz not null default now(),
  issues        jsonb,                           -- array of {code,desc,severity,photo_path}
  storage_paths text[],                          -- Supabase Storage object paths
  status        text not null default 'submitted', -- 'submitted'|'approved'|'rejected'
  created_at    timestamptz default now()
);
create index if not exists idx_insp_org_time on inspection_reports(org_id, reported_at desc);
alter table inspection_reports enable row level security;

create policy if not exists insp_ro on inspection_reports for select
  using (org_id = current_org_id() and (is_org_admin() or is_auditor() or (current_role()='driver' and driver_id=current_driver_id())));
create policy if not exists insp_rw on inspection_reports for insert with check (org_id = current_org_id() and (is_org_admin() or (current_role()='driver' and driver_id=current_driver_id())));
create policy if not exists insp_admin_update on inspection_reports for update using (org_id = current_org_id() and is_org_admin()) with check (org_id = current_org_id());
create policy if not exists insp_admin_delete on inspection_reports for delete using (org_id = current_org_id() and is_org_admin());

create trigger if not exists tr_audit_inspections after insert or update or delete on inspection_reports
for each row execute function audit_row_change();

-- Telematics events (behavior & HOS)
create table if not exists telematics_events (
  id            uuid primary key default uuid_generate_v4(),
  org_id        uuid not null,
  driver_id     uuid references drivers(id) on delete set null,
  truck_vin     text,
  event_time    timestamptz not null,
  type          text not null,                   -- 'hard_brake','overspeed','hos_over','geo'
  severity      int,
  meta          jsonb,
  created_at    timestamptz default now()
);
create index if not exists idx_telematics_org_time on telematics_events(org_id, event_time desc);
-- Optional JSONB GIN index for meta-heavy queries
create index if not exists idx_telematics_meta on telematics_events using gin(meta);
alter table telematics_events enable row level security;
create policy if not exists telem_ro on telematics_events for select using (org_id = current_org_id());
create policy if not exists telem_rw on telematics_events for all using (org_id = current_org_id() and is_org_admin()) with check (org_id = current_org_id());

-- IFTA aggregations (per jurisdiction)
create table if not exists fuel_receipts (
  id            uuid primary key default uuid_generate_v4(),
  org_id        uuid not null,
  driver_id     uuid references drivers(id) on delete set null,
  station_id    text,
  jurisdiction  text,                             -- e.g., 'TX','ON'
  gallons       numeric(10,3) not null,
  amount_cents  bigint not null,
  purchased_at  timestamptz not null,
  created_at    timestamptz default now()
);
create index if not exists idx_fuel_receipts_org_time on fuel_receipts(org_id, purchased_at desc);
alter table fuel_receipts enable row level security;
create policy if not exists fuel_receipts_ro on fuel_receipts for select using (org_id = current_org_id() and (is_org_admin() or is_auditor() or (current_role()='driver' and driver_id=current_driver_id())));
create policy if not exists fuel_receipts_rw on fuel_receipts for all using (org_id = current_org_id() and is_org_admin()) with check (org_id = current_org_id());

-- IFTA view (feed export fn)
create or replace view v_ifta_miles_fuel as
select
  dm.org_id,
  date_trunc('quarter', dm.date)::date as quarter_start,
  dm.driver_id,
  dm.date,
  (dm.miles_total)::numeric as miles_total,
  fr.jurisdiction,
  coalesce(sum(fr.gallons) filter (where date_trunc('quarter', fr.purchased_at)=date_trunc('quarter', dm.date)), 0)::numeric as gallons_quarter
from driver_miles dm
left join fuel_receipts fr
  on fr.org_id = dm.org_id and fr.driver_id = dm.driver_id
group by 1,2,3,4,6
having dm.org_id = current_org_id();

-- =========================================
-- MODULE 4: Technical Glue (Edge RPC stubs + policies)
-- =========================================

-- calculate_ifta_report()     -- runs off v_ifta_miles_fuel
-- predict_parking_fill()      -- writes to parking_status
-- optimize_route()            -- writes to route_choices, updates expenses (fuel estimates)
-- sync_badges()               -- awards into driver_badges based on rules

-- Optional: register a minimal RPC to expose org-scoped “what’s live” badges/leaderboards
create or replace view v_driver_leaderboard as
select
  db.org_id,
  db.driver_id,
  d.full_name,
  sum(coalesce(bc.points,0)) as points,
  count(*) as badges
from driver_badges db
left join driver_badges_catalog bc on bc.code = db.badge_code
left join drivers d on d.id = db.driver_id
group by 1,2,3
having db.org_id = current_org_id()
order by points desc nulls last;

-- Notes & wiring tips
-- Audit: add audit_row_change() triggers to any additional tables you want traced (e.g., loads, route_choices).
-- Storage: for inspection photos/files, enforce Storage policies to align with inspection_reports.org_id and driver ownership.
-- Edge security: validate requests with JWT/HMAC; use service-role only on server-to-server paths; keep all client writes org-scoped via RLS.
