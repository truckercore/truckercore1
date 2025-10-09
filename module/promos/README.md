# Promos Module

Purpose: Issue/Redeem promotions via Edge Functions.

Endpoints
- POST /functions/v1/promotions-issue-qr — returns a one-time token
- POST /functions/v1/promotions-redeem — approves a redemption with subtotal/cashier context

How to run gates
- Full gate: scripts/run_gate.sh promos full
- Probe only: scripts/run_gate.sh promos probe

Env vars required
- FUNC_URL (default http://localhost:54321/functions/v1)
- SUPABASE_DB_URL (psql connection string)
- TEST_JWT (Bearer token for user path)
- SERVICE_TOKEN (Bearer token for service path)

Artifacts
- Probe metrics are written to reports/promos_issue_qr_probe.json and aggregated in reports/probes.csv.
