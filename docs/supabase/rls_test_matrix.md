# RLS Test Matrix (Outline)

Run end-to-end against a locked Supabase project. Validate key tables under different JWT roles.

Roles/claims to simulate:
- Driver (roles: ["driver"], app_org_id = <ORG>)
- Fleet Manager (roles: ["fleet_manager"], app_org_id = <ORG>)
- Broker (roles: ["broker"], app_org_id = <ORG>)

Tables/operations:
- loads: driver can read only assigned; fleet_manager read org; broker read own broker loads.
- inspection_reports: driver insert own; fleet_manager read org.
- hos_logs: driver read own; fleet_manager read org; eld_ingest via service role only.
- ownerop_expenses: owner (driver) read/write own.
- maintenance_jobs: fleet_manager org read/write.

Suggested tests:
- Insert/load via service role seeds; then attempt selects/updates using anon JWT with role claim and org claims. Expect 200 or policy error accordingly.

Note: Use PostgREST or Supabase-js with custom JWT to simulate roles in CI, or Testcontainers with Supabase CLI for local runs.
