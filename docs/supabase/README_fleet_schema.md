# Fleet & Dispatch Schema: How to Apply in Supabase

This repository includes tenant-aware Supabase/Postgres schemas for foundation (organizations, roles, RLS) and fleet/dispatch.
The SQL files are located at:

- docs/supabase/foundation_tenancy_schema.sql (Phase 1: foundational orgs/roles/RLS + core entities)
- docs/supabase/fleet_dispatch_schema.sql (fleet trucks/positions/assignments/orders)
The SQL file is located at:


Apply order:
1) foundation_tenancy_schema.sql
2) fleet_dispatch_schema.sql
3) maintenance_compliance_schema.sql
4) reporting_billing_schema.sql
5) (optional) fleet_postgis_migration.sql
6) (optional) fleet_demo_seed.sql

The fleet/dispatch schema defines:
- trucks, truck_positions (history: lat, lng, speed_kph, heading_deg, accuracy_m, source, trip_id), truck_current_positions (materialized latest)
- dispatch_orders (header), dispatch_order_legs (waypoints), assignments, dispatch_stops, dispatch_events
- enums for statuses
- fn_upsert_current_truck_position() trigger + trigger to maintain current positions
- fn_ingest_truck_position(...) RPC for validated/throttled telemetry ingestion
- v_truck_current view (convenience snapshot)
- indexes, Realtime publication additions, and example RLS policies

The maintenance/compliance schema defines:
- service_tasks (catalog), truck_service_schedules, truck_engine_hours (snapshots), work_orders, work_order_items, parts_catalog
- DVIR: dvir_inspections, dvir_defects, dvir_defect_resolutions
- View v_truck_service_next_due for schedule projections (time/odometer)
- Tenant RLS and indexes across tables

The reporting/billing schema defines:
- organization_billing (plan tier: free/pro/enterprise, optional limits jsonb)
- usage_counters + fn_meter_event / fn_meter_event_rpc for metering (positions/day, events/day, etc.)
- Guarded telemetry RPC fn_ingest_truck_position_guarded enforcing per-plan daily limits (if base RPC exists)
- Materialized views: mv_daily_truck_stats (km, driving_minutes, idle_minutes), mv_daily_org_stats (org-level aggregates), view v_on_time_performance
- Refresh RPC fn_refresh_reporting for nightly refresh (via pg_cron or Supabase Scheduler)
- Secure views v_daily_truck_stats, v_daily_org_stats for RLS-friendly access
- Optional geofence insert policy enforcing per-plan geofence count

Important: The base schema (lat/lng, tenant RLS) is saved in the repo but not automatically applied to your Supabase project. There is also an optional PostGIS+geofencing migration.

You can apply them via the SQL editor, the Supabase CLI, or the provided PowerShell script.

---

## Option A: Apply via Supabase Dashboard (SQL Editor)
1) Open your Supabase project -> SQL Editor.
2) Copy the entire contents of docs/supabase/fleet_dispatch_schema.sql.
3) Paste into the SQL Editor and click Run.
4) If your project does not have PostGIS enabled, the script will enable it with `create extension if not exists postgis;`.

Notes:
- The script is idempotent where possible (create if not exists). Running it multiple times should be safe.
- If you already have your own enum types or table names, adjust the script accordingly before running.

## Option B: Apply via Supabase CLI
Prerequisites:
- Supabase CLI installed
- Logged in and linked to your project directory (`supabase link`)

Then run base schema:

```
supabase db query 
```

Optional PostGIS + geofencing migration:

```
supabase db query ./docs/supabase/fleet_postgis_migration.sql
```

Seed demo data:

```
supabase db query ./docs/supabase/fleet_demo_seed.sql
```

Alternatively, with psql (replace placeholders):

```
psql "postgres://postgres:<YOUR_PASSWORD>@<HOST>:5432/postgres" -f ./docs/supabase/fleet_dispatch_schema.sql
```

---

## Verify the installation

### Deprecation: legacy evidence columns
Deprecated: columns file_url, photo, image_url in safety_incidents are deprecated. Use attachments (JSONB array of {url,type,metadata}). New writes MUST populate attachments; old columns will be removed after the deprecation window.
Run these quick checks in the SQL Editor:

```
-- Check tables exist
select table_name from information_schema.tables
where table_schema = 'public' and table_name in (
  'trucks', 'truck_positions', 'truck_current_positions',
  'dispatch_orders', 'dispatch_order_legs', 'assignments'
);

-- Check the view
select * from public.v_truck_current limit 5;

-- Check trigger function exists
\df+ public.fn_upsert_current_truck_position

-- Insert a test truck and a position, then see current position update (base lat/lng)
insert into public.trucks (external_id, plate, make, model, year, carrier_id)
values ('T-1001','ABC123','Volvo','VNL',2020,'00000000-0000-0000-0000-0000000000A1')
returning id;

-- Use the returned id in the following insert (replace :truck_id)
insert into public.truck_positions (truck_id, lat, lng, speed_kph, heading_deg, gps_ts)
values (
  :truck_id,
  47.608013,
  -122.335167,
  88.0,
  180.0,
  now()
);

select * from public.truck_current_positions where truck_id = :truck_id;
```

If you applied the optional PostGIS migration, you can also:

```
select * from public.v_truck_current_positions_geo limit 5;
```

You should see one row in truck_current_positions reflecting your inserted position.

---

## Option C: Apply via provided PowerShell script (Windows)
Run from repository root:

- Base schema + seeds:
```
powershell -ExecutionPolicy Bypass -File .\

```

- Include optional PostGIS migration as well:
```
powershell -ExecutionPolicy Bypass -File .\

```

- If you want to target a specific project (without using supabase link):
```
powershell -ExecutionPolicy Bypass -File .\scripts\supabase\apply_fleet.ps1 -ProjectRef <your-project-ref> -WithPostGIS
```

The script uses Supabase CLI under the hood and does not store any secrets in the repo.

---

## Realtime setup
The script appends the tables to the `supabase_realtime` publication:
- trucks, truck_positions, truck_current_positions, dispatch_orders, dispatch_order_legs, assignments

If your project did not have the publication, uncomment the `create publication` line in the SQL and run it once.

## Row Level Security (RLS)
RLS is enabled with minimal example policies that allow read access to authenticated and anon roles and restrict writes to `service_role` (example). Adjust to your auth model:
- Multi-tenant: add org_id/carrier_id columns and craft policies using JWT claims (e.g., (auth.jwt() ->> 'org_id')::uuid = org_id).
- If you want user-level write access, replace the service_role checks with appropriate conditions.

## PostGIS requirement
- The schema uses geography(Point,4326). The script runs `create extension if not exists postgis;`.
- If you cannot enable PostGIS, you can modify the schema to use plain lat/lng doubles and remove GIST indexes.

## Rollback tips
If you need to drop everything created by this script:

```
drop view if exists public.v_truck_current;

drop trigger if exists trg_upsert_current_truck_position on public.truck_positions;
drop function if exists public.fn_upsert_current_truck_position();

drop table if exists public.assignments cascade;
drop table if exists public.dispatch_order_legs cascade;
drop table if exists public.dispatch_orders cascade;
drop table if exists public.truck_current_positions cascade;
drop table if exists public.truck_positions cascade;
drop table if exists public.trucks cascade;

-- enums (drop only if not used elsewhere)
-- drop type if exists public.dispatch_order_status;
-- drop type if exists public.assignment_status;
-- drop type if exists public.truck_status;
```

## After applying: Flutter integration pointers
- You can now query v_truck_current for the dashboard map/list, and use truck_current_positions for live location updates.
- Insert telemetry using the RPC: select public.fn_ingest_truck_position(...), or insert into truck_positions with a service key; the trigger will maintain truck_current_positions.
- For Riverpod providers and services, prefer select streaming on truck_current_positions (Realtime) where appropriate.
- Health status heuristic: moving if speed_kph > 2, idle if <= 2 and last gps_ts within 15 minutes, offline otherwise. Tune as needed.
- Map clustering: client-side clustering via flutter_map_marker_cluster or supercluster is sufficient up to several hundreds of markers. For thousands, consider server-side clustering using PostGIS KMeans/DBSCAN in a view.

## Need help tailoring?
Open an issue or request:
- Organization-aware RLS (carrier_id/org_id) and policies.
- Seed scripts (a few trucks, orders, legs, and sample telemetry).
- Edge Functions for secured writes to truck_positions and order lifecycle.


## Troubleshooting

- Error 42703: column "org_id" does not exist when running foundation_tenancy_schema.sql
  - Cause: your project has older versions of tables (drivers, trucks, terminals, driver_truck_assignments, loads) created without org_id. When the script applies RLS policies referencing org_id, Postgres raises 42703.
  - Fix: re-run docs/supabase/foundation_tenancy_schema.sql from this repo. It now includes ALTER TABLE ... ADD COLUMN IF NOT EXISTS for org_id on those tables before applying policies. Apply Foundation first, then the other schemas.
  - Verify columns now exist:
```
select table_name, column_name from information_schema.columns
where table_schema='public' and table_name in ('drivers','trucks','terminals','driver_truck_assignments','loads') and column_name='org_id';
```

- Error 42601: syntax error at or near "not" when running CREATE POLICY IF NOT EXISTS (Postgres 14)
  - Cause: PG14 does not support IF NOT EXISTS for CREATE POLICY.
  - Fix: our migrations wrap CREATE POLICY statements in anonymous DO blocks that catch duplicate_object, e.g.:
```
DO $$ BEGIN
  CREATE POLICY "example_policy" ON public.example
    FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
```
  - If you pasted earlier SQL with IF NOT EXISTS, replace with the DO-block pattern and re-run.


---

## RLS performance remediation (auth_rls_initplan) and duplicate index cleanup
Supabase’s Database Linter may warn that policies calling `auth.jwt()` / `auth.uid()` directly are re-evaluated per row. The recommended pattern is to wrap calls as `(select auth.jwt())` and `(select auth.uid())`. We provide a ready-to-run remediation script:

- File: docs/supabase/rls_perf_fix.sql
- What it does:
  - Replaces RLS policies that reference `auth.jwt()` / `auth.uid()` with `(select auth.jwt())` / `(select auth.uid())` on core tables (organizations, organization_members, trucks, truck_positions, truck_current_positions, dispatch_orders, dispatch_order_legs, assignments, dispatch_stops, dispatch_events, usage_counters, organization_billing, and optional geofences).
  - Reduces multiple permissive policies on `dispatch_stops` by splitting `FOR ALL` into distinct INSERT/UPDATE/DELETE policies and keeping a single SELECT policy, improving performance.
  - Removes duplicate indexes reported by the linter (guarded and safe to run multiple times), e.g., `dispatch_order_legs_order_id_seq_key`, `pings_device_ts_idx`.
- How to run (SQL Editor):
  1) Open docs/supabase/rls_perf_fix.sql, copy all contents.
  2) Paste into your Supabase SQL Editor and click Run.
- CLI:
```
supabase db query ./docs/supabase/rls_perf_fix.sql
```
- Verify:
  - Re-run the Database Linter; the `auth_rls_initplan` warnings should be cleared for the covered tables.
  - For `multiple_permissive_policies`, `dispatch_stops` should now have only one permissive SELECT policy per role/action.
  - For `duplicate_index`, the listed duplicates will be dropped if they exist.

If your project includes additional tables (devices, profiles, documents, fuel_logs, truck_stop_*), share their existing policy names and we’ll extend the remediation script to cover them.


- Error 42P01: relation "public.usage_counters" does not exist when running rls_perf_fix.sql
  - Cause: The remediation script updated policies on usage_counters before the table was created (usage_counters is created by reporting_billing_schema.sql in Phase 6).
  - Fix options:
    1) Apply Phase 6 first: run docs/supabase/reporting_billing_schema.sql, then re-run docs/supabase/rls_perf_fix.sql; or
    2) Use the patched rls_perf_fix.sql (in this repo) which now guards usage_counters policy changes behind a table-existence check, and can be run safely anytime.
  - Verify:
```
select table_name from information_schema.tables where table_schema='public' and table_name='usage_counters';
```