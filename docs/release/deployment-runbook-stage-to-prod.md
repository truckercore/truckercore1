# Deployment Runbook — Stage → Prod (R1)

This runbook describes the environment prerequisites, migration order, one‑liners to apply DB migrations, API smoke tests (curl), CI pre‑deploy gate, SRE dashboards/alerts, rollback/containment, and security hand‑off notes.

## Prerequisites
- Environment variables configured for API/backend and CI:
  - Database connectivity: `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_SSLMODE` (require or verify)
  - JWT: `JWT_SECRET`
  - Service role token for server‑side jobs
  - Webhook secrets: ELD, payments, eSign (and any others)
  - Storage/CDN endpoints (if used by exports/tiles)
- Postgres extensions enabled: `uuid-ossp`, `pgcrypto` (and `pg_cron` if you schedule inside DB)

## Migration order (idempotent)
Order‑safe because all migrations are additive and guarded. Recommended sequence:
1) Tenancy/foundation
2) Combo role support
3) Market intelligence
4) Enterprise features
5) Reporting/Billing schemas
6) Analytics RPCs/views

Repository locations of SQL:
- `docs/supabase/phase1_combo_roles.sql`
- `docs/supabase/phase1_saved_searches_alerts.sql`
- `docs/supabase/phase2_market_intelligence.sql`
- `docs/supabase/phase3_enterprise_features.sql`
- `docs/supabase/reporting_kpi_rpc.sql`

## Shell — apply migrations
Bash (Linux/macOS):
```bash
# Environment
export PSQL="psql 'sslmode=${DB_SSLMODE:-require} host=$DB_HOST port=${DB_PORT:-5432} dbname=$DB_NAME user=$DB_USER password=$DB_PASSWORD'"

# Apply all SQL files in this repo (adjust glob as needed)
for f in $(ls -1 docs/supabase/*.sql 2>/dev/null || true); do
  echo "Applying $f"; $PSQL -v ON_ERROR_STOP=1 -f "$f";
done

# Or explicitly by file (idempotent)
$PSQL -v ON_ERROR_STOP=1 -f docs/supabase/phase1_combo_roles.sql
$PSQL -v ON_ERROR_STOP=1 -f docs/supabase/phase1_saved_searches_alerts.sql
$PSQL -v ON_ERROR_STOP=1 -f docs/supabase/phase2_market_intelligence.sql
$PSQL -v ON_ERROR_STOP=1 -f docs/supabase/phase3_enterprise_features.sql
$PSQL -v ON_ERROR_STOP=1 -f docs/supabase/reporting_kpi_rpc.sql
```

PowerShell (Windows):
```powershell
$PSQL = "psql 'sslmode=' + ($env:DB_SSLMODE ?? 'require') + " +
        " ' host=$env:DB_HOST port=' + ($env:DB_PORT ?? '5432') + " +
        " ' dbname=$env:DB_NAME user=$env:DB_USER password=$env:DB_PASSWORD'"

Get-ChildItem -Path docs/supabase -Filter *.sql | ForEach-Object {
  Write-Host "Applying $($_.FullName)"; & psql "sslmode=$($env:DB_SSLMODE) host=$($env:DB_HOST) port=$($env:DB_PORT) dbname=$($env:DB_NAME) user=$($env:DB_USER) password=$($env:DB_PASSWORD)" -v ON_ERROR_STOP=1 -f $_.FullName
}
```

## PI smoke tests (curl)
Ensure `BASE_URL` and `JWT` are set (stage or prod).

Owner‑Op expenses (RLS by user/org):
```bash
curl -sS -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -d '{"category":"fuel","amount_usd":120.55,"incurred_on":"2025-11-02"}' \
  ${BASE_URL}/api/ownerop/expenses | jq .
```

Market intelligence (lane anomalies):
```bash
curl -sS -H "Authorization: Bearer $JWT" \
  "${BASE_URL}/api/pricing/anomalies?limit=5" | jq .
```

Verification lookup:
```bash
curl -sS -H "Authorization: Bearer $JWT" \
  "${BASE_URL}/api/vetting/lookup?dot=1234562" | jq .
```

HOS logs (7 days):
```bash
curl -sS -H "Authorization: Bearer $JWT" \
  "${BASE_URL}/api/hos/${DRIVER_ID}?from=2025-11-01&to=2025-11-07" | jq .
```

Analytics CSV (headers check):
```bash
curl -sSI -H "Authorization: Bearer $JWT" \
  "${BASE_URL}/api/analytics/export.csv?scope=fleet&from=2025-11-01&to=2025-11-07"
```

Optional RLS denial test (expect failure):
```bash
# If you expose an admin-only route; otherwise attempt an INSERT via psql with user token
set -e
curl -sS -H "Authorization: Bearer $JWT" -H "Content-Type: application/json" \
  -d '{"dot_number":"9999999"}' \
  ${BASE_URL}/api/vetting/admin_insert || echo "(expected failure)"
```

## CI gate (GitHub Actions)
See `.github/workflows/r1-predeploy-gate.yml`. It:
- Applies DB migrations to STAGE (idempotent)
- Verifies `uuid-ossp` and `pgcrypto` extensions exist
- Executes `fn_dashboard_kpis` RPC using a staged org claim
- Runs API smokes for owner-op expenses, HOS logs, and analytics CSV headers

## SRE dashboards and alerts
Chart these metrics:
- API: requests/sec, p95/p99 latency, 5xx rate, per-route breakdown
- Jobs: reporting refresh success/fail, ELD webhook deliveries, DLQ depth
- DB: slow queries (≥ 500ms), lock waits, MV refresh duration
- Security: auth failures, RLS-denied attempts (optional)
- Business: expenses/day, verification lookups/day, anomalies count, optimizer runs

Alerts:
- API p95 > 2s for 10 min (non-optimizer routes)
- Optimizer/ETA p95 > 4s for 10 min
- Job failure rate > 2% over 30 min
- DLQ size > threshold
- 5xx rate > 1% overall or > 3% on any critical route

## Rollback and containment
- Flags first: disable domain features (e.g., `dispatch_optimizer`, `eta_breach_alerts`)
- Block routes at gateway for hotfix windows
- Pause scheduled jobs/cron if pressure/fault loops detected
- Avoid destructive DB rollbacks; prefer feature toggles and route blocks

## Hand‑off notes (security & compliance)
- JWT must include `app_org_id`, `app_roles`, and admin flags used in RLS
- Security definer functions are granted only to proper roles (`authenticated`, `service_role`)
- Ensure no PII/tokens in logs; verify redaction in logging pipeline
- Validate retention policies and DSR exports in stage before prod enablement
