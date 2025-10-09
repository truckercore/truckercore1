#!/usr/bin/env bash
# One-step rollback helper
# Usage:
#   SUPABASE_DB_URL=postgres://... ./scripts/release/undo.sh [feature_flag_key]
# Behavior:
# - If a feature flag key is provided, it disables the flag.
# - Inserts a 60m maintenance window (mute alerts) as a guardrail.
# - Prints pre/post verification checks.
set -euo pipefail

if ! command -v psql >/dev/null 2>&1; then
  echo "psql not found. Please install PostgreSQL client." >&2
  exit 1
fi

if [ -z "${SUPABASE_DB_URL:-}" ]; then
  echo "SUPABASE_DB_URL not set. Export it and re-run." >&2
  exit 1
fi

FLAG_KEY=${1:-}

echo "[rollback] Starting rollback with guardrails…"
if [ -n "$FLAG_KEY" ]; then
  echo "[rollback] Disabling feature flag '$FLAG_KEY'"
  psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -c "select public.set_feature_flag('$FLAG_KEY', false, 'Rollback via undo.sh');" || true
fi

# Mute alerts for 60 minutes
echo "[rollback] Inserting 60m maintenance window (alerts mute)"
psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -c "insert into public.maintenance_windows(starts_at, ends_at, note) values (now(), now()+interval '60 minutes', 'rollback mute');" || true

echo "[rollback] Done. Next steps:"
echo "- Pre-checks:"
echo "  • Ops Dashboard /admin/ops reachable"
echo "  • Edge health: functions/healthz ok:true"
echo "  • Env check: GET /api/ops/envcheck -> ok"
echo "- Post-checks (after rollback settles):"
echo "  • SLO burn panels no longer red (slo_burn_1h, slo_burn_7d)"
echo "  • Alert backlog drains (ops_alerts_pending pending=0)"
echo "  • Canary pass (Edge Pre-Check/Deploy Gate)")
