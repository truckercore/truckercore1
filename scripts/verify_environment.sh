#!/bin/bash
set -e

echo "🌍 Environment Configuration Verification"
echo "=========================================="
echo ""

ERRORS=0

# Check production environment file
if [ ! -f ".env.production" ]; then
  echo "❌ .env.production not found"
  echo "   Create it from .env.example"
  ((ERRORS++))
else
  echo "✅ .env.production exists"
  
  # Source it
  # shellcheck disable=SC1091
  source .env.production
  
  # Verify required variables
  if [ -z "$SUPABASE_URL" ] || [[ "$SUPABASE_URL" == "https://your-project.supabase.co"* ]]; then
    echo "❌ SUPABASE_URL not configured in .env.production"
    ((ERRORS++))
  else
    echo "✅ SUPABASE_URL configured"
  fi
  
  if [ -z "$SUPABASE_ANON" ] || [[ "$SUPABASE_ANON" == "your-anon-key"* ]]; then
    echo "❌ SUPABASE_ANON not configured in .env.production"
    ((ERRORS++))
  else
    echo "✅ SUPABASE_ANON configured"
  fi
  
  if [ "$USE_MOCK_DATA" = "true" ]; then
    echo "⚠️  USE_MOCK_DATA=true (should be false for production)"
    ((ERRORS++))
  else
    echo "✅ USE_MOCK_DATA=false"
  fi
  
  if [ -z "$SENTRY_DSN" ]; then
    echo "⚠️  SENTRY_DSN not set (error tracking disabled)"
  else
    echo "✅ SENTRY_DSN configured"
  fi
fi

echo ""
echo "🔐 Security Checks"
echo "------------------"

# Check gitignore
if grep -q ".env" .gitignore && grep -q ".env.production" .gitignore; then
  echo "✅ .env files in .gitignore"
else
  echo "❌ .env files NOT in .gitignore - SECURITY RISK!"
  ((ERRORS++))
fi

if grep -q "key.properties" .gitignore; then
  echo "✅ key.properties in .gitignore"
else
  echo "⚠️  key.properties should be in .gitignore"
fi

# Check for hardcoded secrets
if grep -r "eyJ" lib/ --include="*.dart" 2>/dev/null | grep -v "//" > /dev/null; then
  echo "❌ Possible hardcoded JWT tokens in code!"
  ((ERRORS++))
else
  echo "✅ No hardcoded tokens detected"
fi

# Optional: supabase URL leak check
if grep -r "supabase.co" lib/ --include="*.dart" 2>/dev/null | grep -v "//" | grep -v "http" > /dev/null; then
  echo "⚠️  Possible hardcoded Supabase URL instances detected"
else
  echo "✅ No unexpected Supabase URL usage"
fi

echo ""
echo "Summary: $ERRORS errors found"

if [ $ERRORS -eq 0 ]; then
  echo "✅ Environment configuration ready for production!"
  exit 0
else
  echo "❌ Fix errors before building for production"
  exit 1
fi
