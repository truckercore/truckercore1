#!/usr/bin/env bash
set -euo pipefail

if command -v supabase >/dev/null 2>&1; then
  echo "[reset] wiping and reapplying schema (supabase db reset)"
  supabase db reset >/dev/null
else
  echo "[reset] supabase CLI not found; nothing to reset"
fi

echo "[reset] done"
