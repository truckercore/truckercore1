#!/usr/bin/env bash
set -euo pipefail
: "${SUPABASE_DB_URL:?}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; source "$DIR/../../scripts/lib_probe.sh"
# Synthetic: create then accept
T=$(openssl rand -hex 8)
ID=$(psql -At "$SUPABASE_DB_URL" -c "insert into driver_invites(org_id,email,token) values ('00000000-0000-0000-0000-0000000000F1','probe+$T@example.com','$T') returning id;")
t0=$(date +%s%3N); psql -At "$SUPABASE_DB_URL" -c "select accept_driver_invite('$T');" >/dev/null; dt=$(( $(date +%s%3N) - t0 ))
echo "$dt" | compute_p95 "invites" "accept" >/dev/null
P95=$(sed -n 's/.*"p95_ms":\([0-9]*\).*/\1/p' "$REPORT_DIR/invites_accept_probe.json")
[ -n "$P95" ] && [ "$P95" -le "${INVITES_P95_MS:-800}" ] || { echo "❌ p95=${P95}ms"; exit 4; }
echo "✅ invites probe SLO ok"
