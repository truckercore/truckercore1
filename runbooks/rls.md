# RLS Gate Runbook

Symptom: CI fails with “RLS leak detected”.

Steps:
1) Inspect CI logs for .github/scripts/gate_rls.sh and note offending table names.
2) Verify the table has RLS enabled and correct policies:
   - In psql: `\d+ public.<table>` then `select * from pg_policies where schemaname='public' and tablename='<table>';`
3) Ensure tenant scoping via canonical claims helpers (app.current_org_id/current_role) or auth.jwt() keys (app_org_id/app_roles) where applicable.
4) Reproduce locally using the simulator:
   - `psql "$READONLY_DATABASE_URL" -c "select public.rls_simulate('<table>','true','{\"app_org_id\":\"ORG_B\",\"app_roles\":[\"driver\"]}');"`
   - Expect 0 for cross-tenant visibility on sensitive tables.
5) If leaks exist, add/fix RLS policies via a migration in docs/sql and apply to non-prod.
6) Re-run locally: `READONLY_DATABASE_URL=... bash .github/scripts/gate_rls.sh`.
7) Open PR; CI should pass the RLS Gate.

Notes:
- Use docs/sql/rls_fixtures.sql to seed non-prod with Org A/B rows and common RLS tables for consistent results.
- Prefer policy expressions referencing app.current_org_id() over inline auth.jwt() parsing to centralize claim logic.
