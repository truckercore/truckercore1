#!/usr/bin/env bash
set -euo pipefail
: "${SUPABASE_DB_URL:?}"
psql "$SUPABASE_DB_URL" -c "select to_regclass('public.eld_sessions');"
psql "$SUPABASE_DB_URL" -c "select to_regclass('public.hos_duty_status');"
psql "$SUPABASE_DB_URL" -c "select to_regclass('public.dvir_reports');"
echo "✅ ELD SQL gate"
