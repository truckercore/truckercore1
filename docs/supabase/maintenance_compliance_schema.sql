-- Phase 5: Maintenance and Compliance Schema for TruckerCore (Supabase/Postgres)
-- Run AFTER foundation_tenancy_schema.sql. Uses org_id tenant scoping via JWT (auth.jwt()->>'org_id').
-- This schema covers: odometer/engine hours, service schedules, work orders, parts/costs, DVIR inspections/defects.

create extension if not exists pgcrypto;

-- 0) Helper to fetch org_id from JWT
create or replace function public.jwt_org_id() returns uuid language sql stable as $$
  select (auth.jwt() ->> 'org_id')::uuid
$$;

-- Ensure timestamp helper exists (normally defined in foundation schema)
create or replace function public.set_timestamp_updated_at() returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- 1) Engine hours snapshots per truck
create table if not exists public.truck_engine_hours (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  truck_id uuid not null references public.trucks(id) on delete cascade,
  hours_total double precision not null,
  source text, -- e.g., 'elm327', 'telematics', 'manual'
  reading_ts timestamptz not null default now(),
  created_at timestamptz not null default now()
);
create index if not exists idx_engine_hours_truck_ts on public.truck_engine_hours(truck_id, reading_ts desc);
alter table public.truck_engine_hours enable row level security;
DO $$ BEGIN
  CREATE POLICY "engine_hours_tenant_select" ON public.truck_engine_hours
    FOR SELECT USING (org_id = public.jwt_org_id());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "engine_hours_tenant_cud" ON public.truck_engine_hours
    FOR ALL USING (org_id = public.jwt_org_id()) WITH CHECK (org_id = public.jwt_org_id());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 2) Service catalogs and schedules
create table if not exists public.service_tasks (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  code text not null, -- e.g., 'PM-A', 'OIL-CHG', 'DOT-ANNUAL'
  name text not null,
  description text,
  default_interval_days int,          -- optional time-based interval
  default_interval_odometer_km double precision, -- optional odometer interval
  default_interval_engine_hours double precision, -- optional engine hours interval
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (org_id, code)
);
create index if not exists idx_service_tasks_org on public.service_tasks(org_id);
alter table public.service_tasks enable row level security;
create trigger trg_service_tasks_updated_at before update on public.service_tasks for each row execute function public.set_timestamp_updated_at();
DO $$ BEGIN
  CREATE POLICY "service_tasks_tenant_select" ON public.service_tasks
    FOR SELECT USING (org_id = public.jwt_org_id());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "service_tasks_tenant_cud_fleet" ON public.service_tasks
    FOR ALL USING (
      org_id = public.jwt_org_id() and exists (
        select 1 from public.user_org_memberships m where m.org_id = public.jwt_org_id() and m.user_id = auth.uid() and m.role in ('admin','fleet_manager')
      )
    ) WITH CHECK (org_id = public.jwt_org_id());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Truck service schedules (per truck assignment of a task with thresholds)
create table if not exists public.truck_service_schedules (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  truck_id uuid not null references public.trucks(id) on delete cascade,
  task_id uuid not null references public.service_tasks(id) on delete cascade,
  interval_days int,                          -- override default
  interval_odometer_km double precision,
  interval_engine_hours double precision,
  last_service_at timestamptz,                -- last performed date
  last_service_odometer_km double precision,
  last_service_engine_hours double precision,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (org_id, truck_id, task_id)
);
create index if not exists idx_truck_schedules_truck on public.truck_service_schedules(truck_id);
alter table public.truck_service_schedules enable row level security;
create trigger trg_truck_schedules_updated_at before update on public.truck_service_schedules for each row execute function public.set_timestamp_updated_at();
DO $$ BEGIN
  CREATE POLICY "truck_schedules_tenant_select" ON public.truck_service_schedules
    FOR SELECT USING (org_id = public.jwt_org_id());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "truck_schedules_tenant_cud_fleet" ON public.truck_service_schedules
    FOR ALL USING (
      org_id = public.jwt_org_id() and exists (
        select 1 from public.user_org_memberships m where m.org_id = public.jwt_org_id() and m.user_id = auth.uid() and m.role in ('admin','fleet_manager')
      )
    ) WITH CHECK (org_id = public.jwt_org_id());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 3) Work orders and items
create table if not exists public.work_orders (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  truck_id uuid not null references public.trucks(id) on delete restrict,
  task_id uuid references public.service_tasks(id) on delete set null,
  status text not null default 'open',  -- open, in_progress, completed, canceled
  opened_at timestamptz not null default now(),
  closed_at timestamptz,
  odometer_km double precision,
  engine_hours double precision,
  notes text,
  created_by uuid,
  updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_work_orders_org_status on public.work_orders(org_id, status);
create index if not exists idx_work_orders_truck on public.work_orders(truck_id);
alter table public.work_orders enable row level security;
create trigger trg_work_orders_updated_at before update on public.work_orders for each row execute function public.set_timestamp_updated_at();
DO $$ BEGIN
  CREATE POLICY "work_orders_tenant_select" ON public.work_orders
    FOR SELECT USING (org_id = public.jwt_org_id());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "work_orders_tenant_cud_fleet" ON public.work_orders
    FOR ALL USING (
      org_id = public.jwt_org_id() and exists (
        select 1 from public.user_org_memberships m where m.org_id = public.jwt_org_id() and m.user_id = auth.uid() and m.role in ('admin','fleet_manager')
      )
    ) WITH CHECK (org_id = public.jwt_org_id());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Work order line items: labor/parts/other
create table if not exists public.work_order_items (
  id uuid primary key default gen_random_uuid(),
  work_order_id uuid not null references public.work_orders(id) on delete cascade,
  line_no int not null,
  kind text not null check (kind in ('labor','part','misc')),
  part_number text,
  description text,
  qty double precision,
  unit_cost_cents int,
  total_cost_cents int,
  created_at timestamptz not null default now(),
  unique (work_order_id, line_no)
);
create index if not exists idx_work_order_items_wo on public.work_order_items(work_order_id);
alter table public.work_order_items enable row level security;
DO $$ BEGIN
  CREATE POLICY "wo_items_tenant_select" ON public.work_order_items
    FOR SELECT USING (
      (select org_id from public.work_orders w where w.id = work_order_id) = public.jwt_org_id()
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "wo_items_tenant_cud_fleet" ON public.work_order_items
    FOR ALL USING (
      (select org_id from public.work_orders w where w.id = work_order_id) = public.jwt_org_id() and exists (
        select 1 from public.user_org_memberships m where m.org_id = public.jwt_org_id() and m.user_id = auth.uid() and m.role in ('admin','fleet_manager')
      )
    ) WITH CHECK (
      (select org_id from public.work_orders w where w.id = work_order_id) = public.jwt_org_id()
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Optional: simple parts catalog
create table if not exists public.parts_catalog (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  part_number text not null,
  name text,
  default_cost_cents int,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (org_id, part_number)
);
create index if not exists idx_parts_org on public.parts_catalog(org_id);
alter table public.parts_catalog enable row level security;
create trigger trg_parts_catalog_updated_at before update on public.parts_catalog for each row execute function public.set_timestamp_updated_at();
DO $$ BEGIN
  CREATE POLICY "parts_tenant_select" ON public.parts_catalog
    FOR SELECT USING (org_id = public.jwt_org_id());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "parts_tenant_cud_fleet" ON public.parts_catalog
    FOR ALL USING (
      org_id = public.jwt_org_id() and exists (
        select 1 from public.user_org_memberships m where m.org_id = public.jwt_org_id() and m.user_id = auth.uid() and m.role in ('admin','fleet_manager')
      )
    ) WITH CHECK (org_id = public.jwt_org_id());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 4) Compliance: DVIR (pre/post-trip inspections)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'dvir_type') THEN
    CREATE TYPE public.dvir_type AS ENUM ('pre_trip','post_trip');
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'dvir_defect_status') THEN
    CREATE TYPE public.dvir_defect_status AS ENUM ('open','deferred','repaired','na');
  END IF;
END $$;

create table if not exists public.dvir_inspections (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  truck_id uuid not null references public.trucks(id) on delete cascade,
  driver_id uuid references public.drivers(id) on delete set null,
  inspection_type public.dvir_type not null,
  inspection_ts timestamptz not null default now(),
  location_text text,
  lat double precision,
  lng double precision,
  notes text,
  signed_by_driver boolean default false,
  signed_by_mechanic boolean default false,
  created_at timestamptz not null default now()
);
create index if not exists idx_dvir_org_ts on public.dvir_inspections(org_id, inspection_ts desc);
alter table public.dvir_inspections enable row level security;
DO $$ BEGIN
  CREATE POLICY "dvir_tenant_select" ON public.dvir_inspections
    FOR SELECT USING (org_id = public.jwt_org_id());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "dvir_tenant_cud" ON public.dvir_inspections
    FOR ALL USING (org_id = public.jwt_org_id()) WITH CHECK (org_id = public.jwt_org_id());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

create table if not exists public.dvir_defects (
  id uuid primary key default gen_random_uuid(),
  inspection_id uuid not null references public.dvir_inspections(id) on delete cascade,
  item text not null,            -- e.g., 'Brakes', 'Lights'
  severity text,                 -- optional: 'low','medium','high'
  status public.dvir_defect_status not null default 'open',
  notes text,
  photo_url text,
  created_at timestamptz not null default now()
);
create index if not exists idx_dvir_defects_insp on public.dvir_defects(inspection_id);
alter table public.dvir_defects enable row level security;
DO $$ BEGIN
  CREATE POLICY "dvir_defects_tenant_select" ON public.dvir_defects
    FOR SELECT USING (
      (select org_id from public.dvir_inspections i where i.id = inspection_id) = public.jwt_org_id()
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "dvir_defects_tenant_cud" ON public.dvir_defects
    FOR ALL USING (
      (select org_id from public.dvir_inspections i where i.id = inspection_id) = public.jwt_org_id()
    ) WITH CHECK (
      (select org_id from public.dvir_inspections i where i.id = inspection_id) = public.jwt_org_id()
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Optional: resolution link to work orders
create table if not exists public.dvir_defect_resolutions (
  id uuid primary key default gen_random_uuid(),
  defect_id uuid not null references public.dvir_defects(id) on delete cascade,
  work_order_id uuid references public.work_orders(id) on delete set null,
  resolution_notes text,
  resolved_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists idx_dvir_resolutions_defect on public.dvir_defect_resolutions(defect_id);
alter table public.dvir_defect_resolutions enable row level security;
DO $$ BEGIN
  CREATE POLICY "dvir_resolutions_tenant_all" ON public.dvir_defect_resolutions
    FOR ALL USING (
      (select org_id from public.dvir_inspections i join public.dvir_defects d on d.inspection_id = i.id where d.id = defect_id) = public.jwt_org_id()
    ) WITH CHECK (
      (select org_id from public.dvir_inspections i join public.dvir_defects d on d.inspection_id = i.id where d.id = defect_id) = public.jwt_org_id()
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 5) Views/helpers
-- Next-due schedule projection: compute due status by odometer and days (simple heuristic)
create or replace view public.v_truck_service_next_due as
select
  s.id as schedule_id,
  s.org_id,
  s.truck_id,
  s.task_id,
  s.interval_days,
  s.interval_odometer_km,
  s.interval_engine_hours,
  s.last_service_at,
  s.last_service_odometer_km,
  s.last_service_engine_hours,
  tcp.odometer_km as current_odometer_km,
  case
    when s.interval_odometer_km is not null and s.last_service_odometer_km is not null
      then (s.last_service_odometer_km + s.interval_odometer_km) - coalesce(tcp.odometer_km, s.last_service_odometer_km)
    else null
  end as km_to_due,
  case
    when s.interval_days is not null and s.last_service_at is not null
      then (s.last_service_at + make_interval(days => s.interval_days)) - now()
    else null
  end as time_to_due
from public.truck_service_schedules s
left join public.truck_current_positions tcp on tcp.truck_id = s.truck_id;

-- 6) Realtime publication additions (if you rely on realtime)
alter publication supabase_realtime add table public.work_orders;
alter publication supabase_realtime add table public.work_order_items;
alter publication supabase_realtime add table public.truck_service_schedules;
alter publication supabase_realtime add table public.service_tasks;
alter publication supabase_realtime add table public.dvir_inspections;
alter publication supabase_realtime add table public.dvir_defects;

-- 7) Demo seed (optional): create one task, schedule, work order, and DVIR
-- Use a constant demo org (same as previous seeds) if present
with const as (
  select '00000000-0000-0000-0000-0000000000A1'::uuid as org_id
), trk as (
  select id from public.trucks where carrier_id = '00000000-0000-0000-0000-0000000000A1'::uuid limit 1
), task as (
  insert into public.service_tasks (org_id, code, name, description, default_interval_days, default_interval_odometer_km)
  select (select org_id from const), 'PM-A', 'Preventive Maintenance A', 'Oil change and inspection', 90, 16000
  where not exists (select 1 from public.service_tasks where org_id = (select org_id from const) and code = 'PM-A')
  returning id
), tsk as (
  select id from task union all select id from public.service_tasks where org_id = (select org_id from const) and code = 'PM-A' limit 1
), sch as (
  insert into public.truck_service_schedules (org_id, truck_id, task_id, interval_days, interval_odometer_km, last_service_at, last_service_odometer_km, notes)
  select (select org_id from const), (select id from trk), (select id from tsk), 90, 16000, now() - interval '80 days', 100000, 'Demo schedule'
  where exists (select 1 from trk)
  on conflict do nothing
  returning id
)
insert into public.work_orders (org_id, truck_id, task_id, status, opened_at, odometer_km, notes)
select (select org_id from const), (select id from trk), (select id from tsk), 'open', now(), 115000, 'Oil change due soon'
where exists (select 1 from trk)
  and not exists (
    select 1 from public.work_orders w where w.org_id = (select org_id from const) and w.truck_id = (select id from trk) and w.status in ('open','in_progress')
  );

-- DVIR demo
with const as (
  select '00000000-0000-0000-0000-0000000000A1'::uuid as org_id
), trk as (
  select id from public.trucks where carrier_id = '00000000-0000-0000-0000-0000000000A1'::uuid limit 1
), ins as (
  insert into public.dvir_inspections (org_id, truck_id, inspection_type, inspection_ts, location_text, notes, signed_by_driver)
  select (select org_id from const), (select id from trk), 'pre_trip', now(), 'Seattle Yard', 'Demo inspection', true
  where exists (select 1 from trk)
  returning id
)
insert into public.dvir_defects (inspection_id, item, severity, status, notes)
select (select id from ins), 'Lights', 'low', 'open', 'Left turn signal out'
where exists (select 1 from ins);
