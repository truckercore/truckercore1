#!/bin/bash
set -e

echo "🔍 Complete Production Readiness Validation"
echo "==========================================="
echo ""

ERRORS=0
WARNINGS=0

# ============================================================================
# 1. ENVIRONMENT VALIDATION
# ============================================================================
echo "1️⃣  Environment Configuration"
echo "-----------------------------"

if [ -f ".env.production" ]; then
  # shellcheck disable=SC1091
  source .env.production
  echo "✅ .env.production found"
  
  # Validate credentials
  if [ -z "$SUPABASE_URL" ] || [[ "$SUPABASE_URL" == *"your-project"* ]]; then
    echo "❌ SUPABASE_URL not configured"
    ((ERRORS++))
  else
    echo "✅ SUPABASE_URL configured"
    
    # Test connection
    if command -v curl >/dev/null 2>&1; then
      HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$SUPABASE_URL/rest/v1/" \
        -H "apikey: $SUPABASE_ANON")
      if [ "$HTTP_CODE" = "200" ]; then
        echo "✅ Supabase connection successful"
      else
        echo "❌ Cannot connect to Supabase (HTTP $HTTP_CODE)"
        ((ERRORS++))
      fi
    else
      echo "⚠️  curl not available; skipping connectivity check"
      ((WARNINGS++))
    fi
  fi
  
  if [ "$USE_MOCK_DATA" = "true" ]; then
    echo "❌ USE_MOCK_DATA=true (must be false for production)"
    ((ERRORS++))
  else
    echo "✅ USE_MOCK_DATA=false"
  fi
else
  echo "❌ .env.production not found"
  ((ERRORS++))
fi

echo ""

# ============================================================================
# 2. DATABASE VALIDATION
# ============================================================================
echo "2️⃣  Database & Schema"
echo "--------------------"

# Check if Supabase CLI is installed
if ! command -v supabase &> /dev/null; then
  echo "⚠️  Supabase CLI not installed (needed for migrations)"
  ((WARNINGS++))
else
  echo "✅ Supabase CLI installed"
  
  # Check migration status
  echo "   Checking migrations..."
  supabase migration list 2>/dev/null || echo "   ⚠️  Cannot check migrations"
fi

# Check for PostGIS extension
if [ -n "$DATABASE_URL" ]; then
  if command -v psql >/dev/null 2>&1; then
    POSTGIS_CHECK=$(psql "$DATABASE_URL" -tAc "SELECT COUNT(*) FROM pg_extension WHERE extname='postgis';" 2>/dev/null || echo "0")
    if [ "$POSTGIS_CHECK" = "1" ]; then
      echo "✅ PostGIS extension enabled"
    else
      echo "⚠️  PostGIS extension not enabled (needed for spatial queries)"
      ((WARNINGS++))
    fi
  else
    echo "⚠️  psql not available; skipping PostGIS check"
    ((WARNINGS++))
  fi
fi

echo ""

# ============================================================================
# 3. PERFORMANCE & SCALABILITY
# ============================================================================
echo "3️⃣  Performance & Scalability"
echo "-----------------------------"

# Check if clustering is implemented
if grep -q "Supercluster" lib/features/fleet/widgets/*.dart 2>/dev/null; then
  echo "✅ Map clustering implemented"
else
  echo "⚠️  Map clustering not found (performance issue with 500+ vehicles)"
  ((WARNINGS++))
fi

# Check for spatial indexes
if [ -n "$DATABASE_URL" ]; then
  if command -v psql >/dev/null 2>&1; then
    INDEX_COUNT=$(psql "$DATABASE_URL" -tAc "SELECT COUNT(*) FROM pg_indexes WHERE indexname LIKE '%location%';" 2>/dev/null || echo "0")
    if [ "$INDEX_COUNT" -gt "0" ]; then
      echo "✅ Spatial indexes found ($INDEX_COUNT)"
    else
      echo "⚠️  No spatial indexes found (query performance will be poor)"
      ((WARNINGS++))
    fi
  else
    echo "⚠️  psql not available; skipping spatial index check"
    ((WARNINGS++))
  fi
fi

echo ""

# ============================================================================
# 4. ERROR HANDLING & RESILIENCE
# ============================================================================
echo "4️⃣  Error Handling & Resilience"
echo "-------------------------------"

if [ -f "lib/core/error/error_handler.dart" ]; then
  echo "✅ Error handler implemented"
else
  echo "⚠️  Global error handler not found"
  ((WARNINGS++))
fi

if grep -q "ErrorRecoveryStrategy" lib/core/providers/*.dart 2>/dev/null; then
  echo "✅ Recovery strategies implemented"
else
  echo "⚠️  Error recovery strategies not found"
  ((WARNINGS++))
fi

echo ""

# ============================================================================
# 5. TESTING INFRASTRUCTURE
# ============================================================================
echo "5️⃣  Testing Infrastructure"
echo "--------------------------"

# Check for CI/CD
if [ -f ".github/workflows/ci.yml" ]; then
  echo "✅ CI/CD pipeline configured"
else
  echo "⚠️  No CI/CD pipeline found"
  ((WARNINGS++))
fi

# Run tests
echo "   Running tests..."
if flutter test --no-pub 2>/dev/null; then
  echo "✅ All tests passing"
else
  echo "❌ Some tests failing"
  ((ERRORS++))
fi

# Check test coverage
if [ -d "coverage" ]; then
  if command -v lcov >/dev/null 2>&1; then
    COVERAGE=$(lcov --summary coverage/lcov.info 2>/dev/null | grep "lines" | awk '{print $2}' || echo "0%")
    echo "   Test coverage: $COVERAGE"
    COVERAGE_NUM=$(echo "$COVERAGE" | sed 's/%//')
    if [ "${COVERAGE_NUM%.*}" -ge 80 ]; then
      echo "✅ Test coverage >80%"
    else
      echo "⚠️  Test coverage <80%"
      ((WARNINGS++))
    fi
  else
    echo "⚠️  lcov not installed; skipping coverage summary"
    ((WARNINGS++))
  fi
fi

echo ""

# ============================================================================
# 6. SECURITY VALIDATION
# ============================================================================
echo "6️⃣  Security Validation"
echo "-----------------------"

# Check for hardcoded secrets
SECRETS_FOUND=0
if grep -r "supabase.co" lib/ --include="*.dart" 2>/dev/null | grep -v "//" | grep "http" > /dev/null; then
  echo "⚠️  Possible hardcoded URLs in code"
  ((WARNINGS++))
  ((SECRETS_FOUND++))
fi

if grep -r "eyJ" lib/ --include="*.dart" 2>/dev/null | grep -v "//" > /dev/null; then
  echo "❌ Hardcoded JWT tokens found in code!"
  ((ERRORS++))
  ((SECRETS_FOUND++))
fi

if [ $SECRETS_FOUND -eq 0 ]; then
  echo "✅ No hardcoded secrets detected"
fi

# Check gitignore
GITIGNORE_OK=true
for pattern in ".env" ".env.production" "key.properties" "*.jks"; do
  if ! grep -q "$pattern" .gitignore 2>/dev/null; then
    echo "⚠️  $pattern not in .gitignore"
    ((WARNINGS++))
    GITIGNORE_OK=false
  fi
done

if [ "$GITIGNORE_OK" = true ]; then
  echo "✅ Security files properly gitignored"
fi

echo ""

# ============================================================================
# 7. MOBILE SPECIFIC
# ============================================================================
echo "7️⃣  Mobile Features"
echo "-------------------"

# Check for location tracking
if grep -q "geolocator" pubspec.yaml; then
  echo "✅ GPS tracking dependency added"
else
  echo "⚠️  GPS tracking not configured"
  ((WARNINGS++))
fi

# Check for background location
if grep -q "LocationSettings" lib/features/driver/providers/*.dart 2>/dev/null; then
  echo "✅ Background location configured"
else
  echo "⚠️  Background location not found"
  ((WARNINGS++))
fi

# Check Android signing
if [ -f "android/key.properties" ]; then
  echo "✅ Android signing configured"
else
  echo "⚠️  Android key.properties not found"
  ((WARNINGS++))
fi

echo ""

# ============================================================================
# 8. MONITORING & OBSERVABILITY
# ============================================================================
echo "8️⃣  Monitoring & Observability"
echo "------------------------------"

if grep -q "sentry_flutter" pubspec.yaml; then
  echo "✅ Sentry error tracking configured"
else
  echo "⚠️  Error tracking not configured"
  ((WARNINGS++))
fi

if [ -n "$SENTRY_DSN" ]; then
  echo "✅ SENTRY_DSN configured"
else
  echo "⚠️  SENTRY_DSN not set"
  ((WARNINGS++))
fi

echo ""

# ============================================================================
# 9. DOCUMENTATION
# ============================================================================
echo "9️⃣  Documentation"
echo "-----------------"

DOC_COUNT=0
for doc in "README.md" "CONTRIBUTING.md" "docs/LAUNCH_GUIDE.md" "PRODUCTION_READY_CHECKLIST.md"; do
  if [ -f "$doc" ]; then
    ((DOC_COUNT++))
  fi
done

echo "   Found $DOC_COUNT/4 critical docs"
if [ $DOC_COUNT -eq 4 ]; then
  echo "✅ All critical documentation present"
else
  echo "⚠️  Some documentation missing"
  ((WARNINGS++))
fi

echo ""

# ============================================================================
# 10. BUILD VALIDATION
# ============================================================================
echo "🔟 Build System"
echo "---------------"

SCRIPT_COUNT=0
for script in "build_production_mobile.sh" "build_production_desktop.sh" "launch.sh" "migrate_database.sh"; do
  if [ -f "scripts/$script" ] && [ -x "scripts/$script" ]; then
    ((SCRIPT_COUNT++))
  fi
done

echo "   Found $SCRIPT_COUNT/4 critical scripts"
if [ $SCRIPT_COUNT -eq 4 ]; then
  echo "✅ All build scripts present and executable"
else
  echo "⚠️  Some build scripts missing or not executable"
  ((WARNINGS++))
fi

echo ""

# ============================================================================
# SUMMARY
# ============================================================================
echo "============================================"
echo "📊 VALIDATION SUMMARY"
echo "============================================"
echo ""
echo "Errors:   $ERRORS"
echo "Warnings: $WARNINGS"
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
  echo "🎉 PERFECT! System is 100% production-ready!"
  echo ""
  echo "✅ All checks passed"
  echo "✅ All features validated"
  echo "✅ All security measures in place"
  echo ""
  echo "🚀 Ready to launch:"
  echo "   ./scripts/launch.sh"
  exit 0
elif [ $ERRORS -eq 0 ]; then
  echo "⚠️  READY with warnings"
  echo ""
  echo "System is production-ready but has $WARNINGS warnings."
  echo "Review warnings above and fix if needed."
  echo ""
  echo "✅ Can proceed to launch:"
  echo "   ./scripts/launch.sh"
  exit 0
else
  echo "❌ NOT READY for production"
  echo ""
  echo "Found $ERRORS critical errors that must be fixed."
  echo "Please resolve errors above before launching."
  echo ""
  echo "Common fixes:"
  echo "1. Configure .env.production with real credentials"
  echo "2. Run database migrations: ./scripts/migrate_database.sh up"
  echo "3. Fix failing tests: flutter test"
  echo "4. Remove hardcoded secrets from code"
  exit 1
fi
