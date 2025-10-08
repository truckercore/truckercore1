#!/bin/bash

echo "📊 TruckerCore Production Metrics"
echo "=================================="
echo ""

# Supabase metrics (if DATABASE_URL is set)
if [ -n "$DATABASE_URL" ]; then
  if command -v psql >/dev/null 2>&1; then
    echo "📈 Database Metrics:"
    echo "-------------------"
    
    # Total vehicles
    VEHICLE_COUNT=$(psql "$DATABASE_URL" -tAc "SELECT COUNT(*) FROM vehicles;" 2>/dev/null || echo "N/A")
    echo "Total Vehicles: $VEHICLE_COUNT"
    
    # Active drivers
    DRIVER_COUNT=$(psql "$DATABASE_URL" -tAc "SELECT COUNT(*) FROM driver_status WHERE status IN ('on_duty', 'driving');" 2>/dev/null || echo "N/A")
    echo "Active Drivers: $DRIVER_COUNT"
    
    # Active loads
    LOAD_COUNT=$(psql "$DATABASE_URL" -tAc "SELECT COUNT(*) FROM loads WHERE status = 'in_transit';" 2>/dev/null || echo "N/A")
    echo "Active Loads: $LOAD_COUNT"
    
    # Recent location updates (last hour)
    LOCATION_UPDATES=$(psql "$DATABASE_URL" -tAc "SELECT COUNT(*) FROM driver_locations WHERE timestamp > NOW() - INTERVAL '1 hour';" 2>/dev/null || echo "N/A")
    echo "Location Updates (1h): $LOCATION_UPDATES"
    
    echo ""
  else
    echo "⚠️  psql not installed; skipping DB metrics"
  fi
fi

# Performance metrics
echo "⚡ Performance:"
echo "--------------"

# Check response time (if app is running)
if [ -n "$SUPABASE_URL" ]; then
  if command -v curl >/dev/null 2>&1; then
    START=$(date +%s%N)
    curl -s -o /dev/null "$SUPABASE_URL/rest/v1/" -H "apikey: $SUPABASE_ANON"
    END=$(date +%s%N)
    RESPONSE_TIME=$(( ($END - $START) / 1000000 ))
    echo "API Response Time: ${RESPONSE_TIME}ms"
    
    if [ $RESPONSE_TIME -lt 500 ]; then
      echo "✅ Excellent (<500ms)"
    elif [ $RESPONSE_TIME -lt 1000 ]; then
      echo "✅ Good (<1s)"
    elif [ $RESPONSE_TIME -lt 2000 ]; then
      echo "⚠️  Acceptable (<2s)"
    else
      echo "❌ Slow (>2s)"
    fi
  else
    echo "⚠️  curl not installed; skipping API response check"
  fi
fi

echo ""

# System health
echo "🏥 System Health:"
echo "----------------"

# Check Supabase status
if [ -n "$SUPABASE_URL" ]; then
  if command -v curl >/dev/null 2>&1; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$SUPABASE_URL/rest/v1/")
    if [ "$HTTP_CODE" = "200" ]; then
      echo "✅ Supabase: Online"
    else
      echo "❌ Supabase: Issues detected (HTTP $HTTP_CODE)"
    fi
  else
    echo "⚠️  curl not installed; skipping status check"
  fi
fi

echo ""
echo "For detailed metrics, visit:"
echo "- Supabase Dashboard: https://app.supabase.com"
echo "- Sentry Dashboard: https://sentry.io"
