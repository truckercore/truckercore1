#!/usr/bin/env bash
set -euo pipefail
: "${SUPABASE_DB_URL:?}"
REPORT_DIR="${REPORT_DIR:-./reports}"
mkdir -p "$REPORT_DIR"
# Fetch p95 from ai_health view; fallback to 0 if unavailable
row=$(psql -At "$SUPABASE_DB_URL" -c "select coalesce(p95_ms,0) from ai_health" 2>/dev/null || echo "0")
p95=${row%%|*}
probe_ms=${MODULE_PROBE_RUNTIME_MS:-0}
cat >"$REPORT_DIR/ai_health_input.json" <<JSON
{
  "module": "ai",
  "module_probe_runtime_ms": ${probe_ms},
  "health": { "p95_ms": ${p95:-0} }
}
JSON

echo "📝 Wrote $REPORT_DIR/ai_health_input.json (p95_ms=${p95:-0}, probe_ms=$probe_ms)"
