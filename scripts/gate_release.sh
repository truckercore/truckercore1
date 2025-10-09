#!/usr/bin/env bash
set -euo pipefail

echo "== Decisions & IAM =="
make probe_decisions_echo
make probe_jwks_rotation
make scim_contract

echo "== Perf & Reliability =="
make gate_perf
make gate_p99_err
make probe_quality_alerts
make probe_ops_health

echo "== AI Explainability =="
make probe_ai_factors
psql "${SUPABASE_DB_URL:?}" -At -c \
"select case when min(pct_with_required) >= 98 then 'ok' else 'fail' end
 from v_ai_factor_coverage_7d" | grep -q ok

echo "== Slow RPC hygiene =="
curl -fsS "${FUNC_URL:?}/ops/cron.slow_rpc_alert" >/dev/null

echo "✅ All release gates passed"
