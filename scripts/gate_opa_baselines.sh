#!/usr/bin/env bash
set -euo pipefail
: "${SUPABASE_DB_URL:?}"

exec_orgs=$(psql -At "$SUPABASE_DB_URL" -c "select org_id from entitlements where feature_key='exec_analytics' and enabled=true")
defaults=$(psql -At "$SUPABASE_DB_URL" -c "select key from ai_roi_baseline_defaults")
map=$(psql -At "$SUPABASE_DB_URL" -c "select org_id||':'||key from v_ai_roi_baseline_effective")

mkdir -p reports policy/opa

jq -n --argfile a <(printf '%s\n' $exec_orgs | jq -R . | jq -s .) \
      --argfile d <(printf '%s\n' $defaults | jq -R . | jq -s .) \
      --argfile m <(printf '%s\n' $map | jq -R . | jq -s .) '
{
  exec_analytics_orgs: $a,
  baseline_defaults: $d,
  effective_baselines: ( $m | map( split(":") ) | reduce .[] as $p ({}; .[$p[0]] = true ) )
}' > reports/opa_input_baselines.json

opa eval --format pretty --fail-defined \
  -i reports/opa_input_baselines.json \
  -d policy/opa/roi_baseline_guard.rego \
  'data.truckercore.roi.deny'
