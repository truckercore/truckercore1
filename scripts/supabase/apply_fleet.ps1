# Applies TruckerCore fleet schema and optional PostGIS migration + seeds using Supabase CLI
# Requirements:
# - Supabase CLI installed and logged in
# - Run from repository root (this script references docs/supabase/*.sql)
# - Project linked (supabase link) or provide --project-ref

param(
  [string]$ProjectRef = "",
  [switch]$WithPostGIS
)

function Run-SupabaseQuery {
  param(
    [Parameter(Mandatory=$true)][string]$File
  )
  if ($ProjectRef -ne "") {
    supabase db query $File --project-ref $ProjectRef
  } else {
    supabase db query $File
  }
  if ($LASTEXITCODE -ne 0) {
    throw "Supabase CLI failed for $File"
  }
}

Write-Host "Applying foundation (organizations, roles, RLS, core entities)..." -ForegroundColor Cyan
Run-SupabaseQuery -File "./docs/supabase/foundation_tenancy_schema.sql"
Write-Host "Applying base fleet schema (lat/lng, tenant RLS)..." -ForegroundColor Cyan
Run-SupabaseQuery -File "./docs/supabase/fleet_dispatch_schema.sql"

Write-Host "Applying maintenance & compliance schema (Phase 5)..." -ForegroundColor Cyan
Run-SupabaseQuery -File "./docs/supabase/maintenance_compliance_schema.sql"

if ($WithPostGIS) {
  Write-Host "Applying optional PostGIS + geofencing migration..." -ForegroundColor Cyan
  Run-SupabaseQuery -File "./docs/supabase/fleet_postgis_migration.sql"
}

Write-Host "Applying reporting & billing schema (Phase 6)..." -ForegroundColor Cyan
Run-SupabaseQuery -File "./docs/supabase/reporting_billing_schema.sql"

Write-Host "Seeding demo data (3 trucks, one order with legs, telemetry, optional geofence) ..." -ForegroundColor Cyan
Run-SupabaseQuery -File "./docs/supabase/fleet_demo_seed.sql"

Write-Host "Quick verification queries..." -ForegroundColor Cyan
# Simple verification via Supabase CLI
if ($ProjectRef -ne "") {
  supabase db query "select count(*) as trucks from public.trucks; select count(*) as positions from public.truck_positions; select * from public.v_truck_current limit 3;" --project-ref $ProjectRef
} else {
  supabase db query "select count(*) as trucks from public.trucks; select count(*) as positions from public.truck_positions; select * from public.v_truck_current limit 3;"
}

Write-Host "Done. If you enabled PostGIS, you can also query v_truck_current_positions_geo and v_trucks_in_geofences." -ForegroundColor Green
