#!/usr/bin/env bash
set -euo pipefail

DB="${READONLY_DATABASE_URL:?READONLY_DATABASE_URL required}"

# Seed check
SEED=$(psql "$DB" -Atc "select count(*) from orgs where name like 'E2E_%';")
if [ "${SEED:-0}" -le 0 ]; then
  echo "::error ::Seed fixtures missing (E2E orgs)"
  exit 1
fi

# Sensitive tables RLS fast-fail
SENSITIVE=${SENSITIVE_TABLES:-"profiles,drivers,tenders,invoices,invoice_items,expenses,route_logs"}
IFS=',' read -ra TBL <<< "$SENSITIVE"
for t in "${TBL[@]}"; do
  CNT=$(psql "$DB" -Atc \
   "select rls_simulate('${t}','true','{\"app_org_id\":\"ORG_B\",\"app_role\":\"driver\"}')")
  if [ "${CNT:-0}" -ne 0 ]; then
    echo "::error ::RLS leak on ${t} (${CNT} rows)"
    exit 1
  fi
done

# Then run your full suite:
bash .github/scripts/gate_rls_cases.sh
