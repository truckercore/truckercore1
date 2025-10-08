#!/bin/bash
set -e

echo "🗄️  Database Migration Tool"
echo "=========================="

ACTION=$1
VERSION=$2

if [ -z "$ACTION" ]; then
  echo "Usage: ./scripts/migrate_database.sh [up|down|status] [version]"
  exit 1
fi

# Check Supabase CLI
if ! command -v supabase &> /dev/null; then
  echo "❌ Supabase CLI not installed"
  echo "Install: brew install supabase/tap/supabase (macOS) or see CLI releases"
  exit 1
fi

case $ACTION in
  up)
    echo "📈 Running migrations..."
    supabase db push
    echo "✅ Migrations complete"
    ;;
  down)
    if [ -z "$VERSION" ]; then
      echo "❌ Version required for rollback"
      echo "Usage: ./scripts/migrate_database.sh down [version]"
      exit 1
    fi
    ROLLBACK_FILE="supabase/migrations/rollback/${VERSION}_rollback.sql"
    if [ ! -f "$ROLLBACK_FILE" ]; then
      echo "❌ Rollback file not found: $ROLLBACK_FILE"
      exit 1
    fi
    echo "⚠️  Rolling back using $ROLLBACK_FILE"
    if [ -z "$DATABASE_URL" ]; then
      echo "❌ DATABASE_URL not set (required for direct psql rollback)"
      exit 1
    fi
    psql "$DATABASE_URL" < "$ROLLBACK_FILE"
    echo "✅ Rollback complete"
    ;;
  status)
    echo "📊 Migration Status:"
    supabase migration list || supabase db status || true
    ;;
  *)
    echo "❌ Invalid action: $ACTION"
    echo "Usage: ./scripts/migrate_database.sh [up|down|status]"
    exit 1
    ;;
fi
