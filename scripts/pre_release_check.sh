#!/bin/bash
set -e

echo "🚀 Pre-Release Checklist"
echo "======================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PASS=0
FAIL=0
WARN=0

check_pass() {
  echo -e "${GREEN}✓${NC} $1"
  ((PASS++))
}

check_fail() {
  echo -e "${RED}✗${NC} $1"
  ((FAIL++))
}

check_warn() {
  echo -e "${YELLOW}⚠${NC} $1"
  ((WARN++))
}

echo "📋 Environment Configuration"
echo "----------------------------"

# Check environment variables
if [ -f ".env.production" ]; then
  check_pass ".env.production exists"
  
  if grep -q "SUPABASE_URL=" .env.production && ! grep -q "SUPABASE_URL=https://your-project" .env.production; then
    check_pass "SUPABASE_URL configured"
  else
    check_fail "SUPABASE_URL not configured properly"
  fi
  
  if grep -q "SUPABASE_ANON=" .env.production && ! grep -q "SUPABASE_ANON=your-" .env.production; then
    check_pass "SUPABASE_ANON configured"
  else
    check_fail "SUPABASE_ANON not configured properly"
  fi
else
  check_warn ".env.production not found (using dart-define instead?)"
fi

echo ""
echo "🔐 Security"
echo "-----------"

# Check for sensitive files in git
if git check-ignore .env.production > /dev/null 2>&1; then
  check_pass ".env.production is gitignored"
else
  check_fail ".env.production is NOT gitignored!"
fi

if git check-ignore android/key.properties > /dev/null 2>&1; then
  check_pass "android/key.properties is gitignored"
else
  check_warn "android/key.properties may not be gitignored"
fi

# Check for hardcoded secrets
if grep -r "supabase.co" lib/ --include="*.dart" | grep -v "// " | grep -v "http" > /dev/null; then
  check_warn "Possible hardcoded Supabase URL found in code"
else
  check_pass "No hardcoded Supabase URLs in code"
fi

echo ""
echo "🧪 Testing"
echo "----------"

# Run tests
if flutter test --no-pub > /dev/null 2>&1; then
  check_pass "All unit tests pass"
else
  check_fail "Some unit tests failing"
fi

# Check test coverage
if [ -d "coverage" ]; then
  check_pass "Test coverage exists"
else
  check_warn "No test coverage found (run: flutter test --coverage)"
fi

echo ""
echo "📱 Mobile Build Configuration"
echo "-----------------------------"

# Android
if [ -f "android/key.properties" ]; then
  check_pass "Android signing configured"
else
  check_fail "Android key.properties missing"
fi

if [ -f "android/app/build.gradle" ] || [ -f "android/app/build.gradle.kts" ]; then
  if grep -q "versionName" android/app/build.gradle 2>/dev/null; then
    VERSION=$(grep "versionName" android/app/build.gradle | head -1 | sed 's/.*versionName \"\(.*\)\".*/\1/')
    check_pass "Android version: $VERSION"
  elif grep -q "versionName" android/app/build.gradle.kts 2>/dev/null; then
    VERSION=$(grep "versionName" android/app/build.gradle.kts | head -1 | sed 's/.*versionName = \"\(.*\)\".*/\1/')
    check_pass "Android version: $VERSION"
  else
    check_warn "Android version not found"
  fi
else
  check_warn "Android app gradle not found"
fi

# iOS
if [ -f "ios/Runner.xcodeproj/project.pbxproj" ]; then
  check_pass "iOS project exists"
  if [ -f "ios/Runner/GoogleService-Info.plist" ]; then
    check_warn "GoogleService-Info.plist found (ensure it's not committed)"
  fi
else
  check_warn "iOS project not found"
fi

# Desktop

echo ""
echo "🖥️  Desktop Build Configuration"
echo "-------------------------------"

if [ -d "windows" ]; then
  check_pass "Windows build configured"
else
  check_warn "Windows build not configured"
fi

if [ -d "macos" ]; then
  check_pass "macOS build configured"
else
  check_warn "macOS build not configured"
fi

if [ -d "linux" ]; then
  check_pass "Linux build configured"
else
  check_warn "Linux build not configured"
fi

# Dependencies

echo ""
echo "📦 Dependencies"
echo "---------------"

# Check for outdated dependencies
if flutter pub outdated | grep -q "newer versions available"; then
  check_warn "Some dependencies have updates available"
else
  check_pass "All dependencies up to date"
fi

# Check for critical packages
REQUIRED_PACKAGES=("supabase_flutter" "flutter_riverpod" "go_router")
for pkg in "${REQUIRED_PACKAGES[@]}"; do
  if grep -q "  $pkg:" pubspec.yaml; then
    check_pass "$pkg dependency exists"
  else
    check_fail "$pkg dependency missing"
  fi
done

# Documentation

echo ""
echo "📄 Documentation"
echo "----------------"

if [ -f "README.md" ]; then
  check_pass "README.md exists"
else
  check_warn "README.md missing"
fi

if [ -f "RELEASE_CHECKLIST.md" ] || [ -f "docs/RELEASE_CHECKLIST.md" ]; then
  check_pass "RELEASE_CHECKLIST.md exists"
else
  check_warn "RELEASE_CHECKLIST.md missing"
fi

if [ -f "docs/ENVIRONMENT_SETUP.md" ]; then
  check_pass "Environment setup docs exist"
else
  check_warn "Environment setup docs missing"
fi

# Database

echo ""
echo "🗄️  Database"
echo "------------"

if [ -f "supabase/schema.sql" ]; then
  check_pass "Database schema exists"
else
  check_warn "Database schema not found"
fi

# Build Scripts

echo ""
echo "🚀 Build Scripts"
echo "----------------"

if [ -f "scripts/build_driver_app.sh" ] && [ -x "scripts/build_driver_app.sh" ]; then
  check_pass "Driver app build script ready"
else
  check_fail "Driver app build script missing or not executable"
fi

if [ -f "scripts/build_desktop.sh" ] && [ -x "scripts/build_desktop.sh" ]; then
  check_pass "Desktop build script ready"
else
  check_fail "Desktop build script missing or not executable"
fi

# Summary

echo ""
echo "📊 Summary"
echo "=========="
echo -e "${GREEN}Passed:${NC} $PASS"
echo -e "${YELLOW}Warnings:${NC} $WARN"
echo -e "${RED}Failed:${NC} $FAIL"
echo ""

if [ $FAIL -eq 0 ]; then
  echo -e "${GREEN}✅ Ready for release!${NC}"
  echo ""
  echo "Next steps:"
  echo "1. Review RELEASE_CHECKLIST.md"
  echo "2. Build production apps:"
  echo "   ./scripts/build_driver_app.sh"
  echo "   ./scripts/build_desktop.sh owner-operator windows"
  echo "   ./scripts/build_desktop.sh fleet-manager windows"
  echo "3. Test on physical devices"
  echo "4. Submit to app stores"
  exit 0
else
  echo -e "${RED}❌ Fix issues before release${NC}"
  exit 1
fi
