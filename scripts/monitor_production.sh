#!/bin/bash

echo "📊 TruckerCore Production Monitor"
echo "=================================="
echo ""

# Check if required tools are installed
if ! command -v curl &> /dev/null; then
  echo "❌ curl not installed"
  exit 1
fi

# Supabase health check
echo "🗄️  Database Status"
echo "------------------"
if [ -n "$SUPABASE_URL" ]; then
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$SUPABASE_URL/rest/v1/")
  if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Database: Online"
  else
    echo "❌ Database: Offline or error (HTTP $HTTP_CODE)"
  fi
else
  echo "⚠️  SUPABASE_URL not set"
fi

echo ""
echo "📱 App Versions"
echo "---------------"
VERSION=$(grep "version:" pubspec.yaml | sed 's/version: //' | tr -d ' ')
echo "Current: v$VERSION"

echo ""
echo "📈 Quick Stats (Requires Supabase access)"
echo "-----------------------------------------"
echo "Active Users: Check Supabase Dashboard"
echo "Total Loads: Check Supabase Dashboard"
echo "Active Drivers: Check Supabase Dashboard"

echo ""
echo "🔗 Useful Links"
echo "---------------"
echo "Supabase Dashboard: https://app.supabase.com"
echo "Sentry Dashboard: https://sentry.io"
echo ""
echo "For detailed monitoring, visit your dashboards above."