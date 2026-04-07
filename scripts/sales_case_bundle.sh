#!/usr/bin/env bash
set -euo pipefail
: "${FUNC_URL:?}" "${ORG_ID:?}" "${SUPABASE_DB_URL:?}"

id=$(curl -fsS -X POST "$FUNC_URL/roi/case_study.create" -H 'content-type: application/json' \
  -d "{\"org_id\":\"$ORG_ID\",\"title\":\"12-week ROI\"}" | jq -r .id)
mkdir -p sales
curl -fsS "$FUNC_URL/roi/case_study.pdf?id=$id" > "sales/${ORG_ID}-roi.html"
psql "$SUPABASE_DB_URL" -At -c \
  "copy (select kpis from roi_case_studies where id='${id}') to stdout" \
  > "sales/${ORG_ID}-kpis.json"
echo "✅ Sales bundle: sales/${ORG_ID}-roi.html + kpis.json"
