#!/usr/bin/env bash
set -euo pipefail

# Compare staging and prod public schemas; fail if drift detected.
# Requires: STAGING_URL and PROD_URL env vars

if ! command -v pipx >/dev/null 2>&1; then
  python3 -m pip install --user pipx || true
  python3 -m pipx ensurepath || true
fi

pipx install pg-schema-diff || pip install pg-schema-diff

pg-schema-diff --source "$STAGING_URL" --target "$PROD_URL" --schema public --fail-on-diff