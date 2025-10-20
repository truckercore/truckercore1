#!/bin/sh
# Safe submodule fetch for CI / Vercel
# - Uses GITHUB_ACCESS_TOKEN (if set) to allow HTTPS access to private GitHub submodules.
# - Syncs .gitmodules and runs recursive init/update (shallow first, fallback to full).
set -eu

err() { printf "%s\n" "$*" >&2; }

# Use token for GitHub HTTPS URLs so private submodules can be cloned.
# Expect GITHUB_ACCESS_TOKEN to be set in CI/Vercel env (mark secret).
if [ -n "${GITHUB_ACCESS_TOKEN:-}" ]; then
  # Configure git to route https://github.com/ requests through our token without writing the token to disk.
  git config --global url."https://${GITHUB_ACCESS_TOKEN}:x-oauth-basic@github.com/".insteadOf "https://github.com/"
fi

# Ensure submodule URL sync (in case .gitmodules was updated)
if ! git submodule sync --recursive; then
  err "git submodule sync failed"
fi

# Try a shallow init/update first (faster). If it fails, retry without --depth.
if git submodule update --init --recursive --depth 1; then
  printf "Submodules initialized (shallow)\n"
else
  err "Shallow submodule fetch failed; retrying without --depth"
  if ! git submodule update --init --recursive; then
    err "Submodule update failed"
    exit 1
  fi
fi

# Show submodule status for debugging (safe: won't reveal secrets)
git submodule status --recursive || true
