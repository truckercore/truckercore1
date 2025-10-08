#!/bin/bash
set -e

echo "🎯 Final Deployment Checks"
echo "=========================="
echo ""

ERRORS=0
WARNINGS=0

# Function to check command exists
check_command() {
  if command -v "$1" &> /dev/null; then
    echo "✅ $1 installed"
  else
    echo "❌ $1 not installed"
    ((ERRORS++))
  fi
}

# Section: Flutter environment
echo "📱 Flutter Environment"
echo "---------------------"
check_command flutter
check_command dart

if command -v flutter &> /dev/null; then
  FLUTTER_VERSION=$(flutter --version | head -1)
  echo " Version: ${FLUTTER_VERSION}"
  echo ""
  echo "Running flutter doctor..."
  if flutter doctor; then
    :
  else
    ((WARNINGS++))
  fi
fi

echo ""
echo "🔧 Build Tools"
echo "--------------"
# Android build tools
if [ -n "$ANDROID_HOME" ] || [ -n "$ANDROID_SDK_ROOT" ]; then
  echo "✅ Android SDK found at ${ANDROID_HOME:-$ANDROID_SDK_ROOT}"
else
  echo "⚠️ ANDROID_HOME/ANDROID_SDK_ROOT not set"
  ((WARNINGS++))
fi

# iOS build tools (macOS only)
if [[ "${OSTYPE}" == "darwin"* ]]; then
  if command -v xcodebuild &> /dev/null; then
    XCODE_VERSION=$(xcodebuild -version | head -1)
    echo "✅ Xcode installed: ${XCODE_VERSION}"
  else
    echo "⚠️ Xcode not installed"
    ((WARNINGS++))
  fi
fi

echo ""
echo "📝 Configuration Files"
echo "---------------------"
# Environment file
if [ -f ".env" ]; then
  echo "✅ .env file exists"
  # Check required variables
  if grep -q "^SUPABASE_URL=https://" .env && ! grep -q "SUPABASE_URL=https://your-project" .env; then
    echo "  ✅ SUPABASE_URL configured"
  else
    echo "  ❌ SUPABASE_URL not properly configured"
    ((ERRORS++))
  fi
  if grep -q "^SUPABASE_ANON=" .env && ! grep -q "SUPABASE_ANON=your-" .env; then
    echo "  ✅ SUPABASE_ANON configured"
  else
    echo "  ❌ SUPABASE_ANON not properly configured"
    ((ERRORS++))
  fi
else
  echo "⚠️ .env file not found (using dart-define?)"
  ((WARNINGS++))
fi

# .gitignore checks
if grep -q "^\.env" .gitignore; then
  echo "✅ .env in .gitignore"
else
  echo "❌ .env NOT in .gitignore - SECURITY RISK!"
  ((ERRORS++))
fi

# Android signing
if [ -f "android/key.properties" ]; then
  echo "✅ Android signing configured"
  if grep -q "key.properties" .gitignore; then
    echo "  ✅ key.properties in .gitignore"
  else
    echo "  ❌ key.properties NOT in .gitignore - SECURITY RISK!"
    ((ERRORS++))
  fi
else
  echo "⚠️ Android signing not configured"
  ((WARNINGS++))
fi

echo ""
echo "🧪 Tests"
echo "--------"
# Run tests
if flutter test --no-pub > /dev/null 2>&1; then
  echo "✅ All tests passing"
else
  echo "❌ Some tests failing"
  ((ERRORS++))
  echo "   Run 'flutter test' for details"
fi

echo ""
echo "📦 Dependencies"
echo "---------------"
# Outdated packages
echo "Checking for outdated packages..."
if flutter pub outdated | grep -q "\b(upgradable|resolvable)\b"; then
  echo "⚠️ Some packages have updates available"
  echo "   Run 'flutter pub outdated' for details"
  ((WARNINGS++))
else
  echo "✅ All packages up to date"
fi

echo ""
echo "🏗️ Build Verification"
echo "--------------------"
echo "Testing debug build..."
if flutter build apk --debug > /dev/null 2>&1; then
  echo "✅ Android debug build successful"
else
  echo "❌ Android debug build failed"
  ((ERRORS++))
fi

echo ""
echo "📊 Code Quality"
echo "---------------"
echo "Running flutter analyze..."
if flutter analyze > /dev/null 2>&1; then
  echo "✅ No analysis issues"
else
  echo "⚠️ Analysis found issues"
  echo "   Run 'flutter analyze' for details"
  ((WARNINGS++))
fi

echo "Checking code formatting..."
if ! dart format --set-exit-if-changed lib/ test/ > /dev/null 2>&1; then
  echo "⚠️ Some files need formatting"
  echo "   Run 'dart format .' to fix"
  ((WARNINGS++))
else
  echo "✅ All files properly formatted"
fi

echo ""
echo "📚 Documentation"
echo "----------------"
REQUIRED_DOCS=("README.md" "CONTRIBUTING.md" "docs/QUICK_START.md" "docs/ENVIRONMENT_SETUP.md")
for doc in "${REQUIRED_DOCS[@]}"; do
  if [ -f "$doc" ]; then
    echo "✅ $doc exists"
  else
    echo "⚠️ $doc missing"
    ((WARNINGS++))
  fi
done

echo ""
echo "🔐 Security Checks"
echo "------------------"
echo "Scanning for potential secrets in code..."
if grep -R "supabase.co" lib/ --include="*.dart" 2>/dev/null | grep -v "//" | grep -v "http" > /dev/null; then
  echo "⚠️ Possible hardcoded URLs found"
  ((WARNINGS++))
else
  echo "✅ No hardcoded URLs detected"
fi

if grep -R "eyJ" lib/ --include="*.dart" 2>/dev/null > /dev/null; then
  echo "❌ Possible hardcoded JWT tokens found!"
  ((ERRORS++))
else
  echo "✅ No hardcoded tokens detected"
fi

echo ""
echo "===================="
echo "📊 Summary"
echo "===================="
echo ""
echo "Errors: ${ERRORS}"
echo "Warnings: ${WARNINGS}"
echo ""

if [ ${ERRORS} -eq 0 ]; then
  if [ ${WARNINGS} -eq 0 ]; then
    echo "🎉 Perfect! Ready for deployment!"
    echo ""
    echo "Next steps:"
    echo "1. Review PRE_LAUNCH_CHECKLIST.md"
    echo "2. Run: ./scripts/deploy_production.sh"
    exit 0
  else
    echo "⚠️ Ready for deployment with warnings"
    echo "   Review warnings above and fix if needed"
    exit 0
  fi
else
  echo "❌ Fix errors before deployment"
  echo ""
  echo "Common fixes:"
  echo "- Configure .env with Supabase credentials"
  echo "- Fix failing tests: flutter test"
  echo "- Add missing files to .gitignore"
  echo "- Fix code issues: flutter analyze"
  exit 1
fi
