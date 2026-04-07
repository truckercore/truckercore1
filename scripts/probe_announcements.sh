#!/usr/bin/env bash
set -euo pipefail
: "${SUPABASE_DB_URL:?}"

psql "$SUPABASE_DB_URL" -c "insert into feature_announcements(audience,title,body) values('driver','What''s New','Safer ELD, faster pay')" >/dev/null
psql -At "$SUPABASE_DB_URL" -c "select title from feature_announcements order by created_at desc limit 1" | grep -q "What's New"
echo "✅ announcements ok"
