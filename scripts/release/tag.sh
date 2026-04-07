#!/usr/bin/env bash
set -euo pipefail
VER=${1:-}
if [ -z "$VER" ]; then
  echo "Usage: $0 v0.x.y" >&2
  exit 1
fi

DATE=$(date +%F)
cat > "CHANGELOG_DB_${VER}.md" <<EOF
# ${VER} — ${DATE}
- DB: Ensure safety_incidents.attachments jsonb array column; add GIN index.
- RLS: unchanged.
- Feature flag: INCIDENT_ATTACHMENTS_ENABLED guards read paths via app.incident_attachments_enabled.
- Runbook: PITR pre-snapshot; idempotent migration; smoke checks; staged flag rollout.
EOF

git add "CHANGELOG_DB_${VER}.md"
git commit -m "chore(release): ${VER} db-first changelog"
git tag -a "${VER}" -m "${VER}"
# Push current branch and tags
CUR_BRANCH=$(git rev-parse --abbrev-ref HEAD)
git push origin "$CUR_BRANCH"
git push --tags
