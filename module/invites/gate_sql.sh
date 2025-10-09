#!/usr/bin/env bash
set -euo pipefail
: "${SUPABASE_DB_URL:?}"
psql "$SUPABASE_DB_URL" -c "select to_regclass('public.idx_driver_invites_org_email');" | grep -qi idx_driver_invites_org_email
echo "✅ invites SQL gates executed"
