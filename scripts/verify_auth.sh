#!/bin/bash
set -e

echo "🔐 Authentication & Authorization Verification"
echo "=============================================="
echo ""

# Check Supabase connection
if [ -z "$SUPABASE_URL" ]; then
  echo "⚠️  SUPABASE_URL not set"
  echo "Set it with: export SUPABASE_URL=your-url"
  exit 1
fi

if [ -z "$SUPABASE_ANON" ]; then
  echo "⚠️  SUPABASE_ANON not set"
  echo "Set it with: export SUPABASE_ANON=your-key"
  exit 1
fi

echo "✅ Environment variables configured"
echo ""

echo "📋 Manual Verification Checklist:"
echo ""
echo "1. JWT Claims Configuration"
echo "   In Supabase Dashboard → Authentication → Users:"
echo ""
echo "   Driver User Metadata:"
echo '   {"primary_role": "driver", "roles": ["driver"], "org_id": "uuid"}'
echo ""
echo "   Owner Operator User Metadata:"
echo '   {"primary_role": "owner_operator", "roles": ["owner_operator"], "org_id": "uuid"}'
echo ""
echo "   Fleet Manager User Metadata:"
echo '   {"primary_role": "fleet_manager", "roles": ["fleet_manager"], "org_id": "uuid"}'
echo ""

read -p "Have you verified user metadata is correctly set? (yes/no): " USER_META_OK
if [ "$USER_META_OK" != "yes" ]; then
  echo "Please configure user metadata in Supabase Dashboard first."
  exit 1
fi

echo ""
echo "2. Test Authentication Flow"
echo ""

# Build and run auth test
flutter test test/integration/auth_test.dart --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON=$SUPABASE_ANON || {
  echo "❌ Auth tests failed"
  exit 1
}

echo "✅ Authentication tests passed"
echo ""

echo "3. Session Persistence Test"
echo "   Manual test required:"
echo "   a) Login to app"
echo "   b) Close app completely"
echo "   c) Reopen app"
echo "   d) Verify still logged in"
echo ""

read -p "Have you verified session persistence? (yes/no): " SESSION_OK
if [ "$SESSION_OK" != "yes" ]; then
  echo "Please test session persistence before continuing."
  exit 1
fi

echo ""
echo "✅ All authentication checks passed!"
