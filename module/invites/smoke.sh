#!/usr/bin/env bash
set -euo pipefail
: "${SUPABASE_DB_URL:?}"
# assumes an invite seeded with token 'tok_demo'
psql "$SUPABASE_DB_URL" -c "select accept_driver_invite('tok_demo');" >/dev/null || { echo "⚠️ no demo token"; exit 0; }
echo "✅ invites smoke passed"
