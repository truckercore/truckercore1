#!/usr/bin/env bash
set -euo pipefail

# Seed minimal test data if applicable.
# Customize as needed for your project test fixtures.

if command -v supabase >/dev/null 2>&1; then
  echo "[seed] resetting DB to a clean state (supabase db reset)"
  supabase db reset >/dev/null
else
  echo "[seed] supabase CLI not found; skipping DB reset"
fi

echo "[seed] done"
