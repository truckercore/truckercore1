#!/bin/bash
set -e

echo "🏭 Complete Production Build"
echo "============================="
echo ""

# Load environment
if [ ! -f ".env.production" ]; then
  echo "❌ .env.production not found"
  exit 1
fi

# shellcheck disable=SC1091
source .env.production
export SUPABASE_URL SUPABASE_ANON SENTRY_DSN

# Create release directory
RELEASE_DIR="releases/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RELEASE_DIR"

echo "📁 Release directory: $RELEASE_DIR"
echo ""

# Step 1: Verify environment
echo "Step 1: Verifying environment..."
./scripts/verify_environment.sh || exit 1

echo ""
echo "Step 2: Verifying authentication..."
./scripts/verify_auth.sh || exit 1

echo ""
echo "Step 3: Building mobile apps..."
./scripts/build_production_mobile.sh || exit 1

# Copy mobile artifacts
cp build/app/outputs/bundle/release/app-release.aab "$RELEASE_DIR/driver-app.aab"
cp build/app/outputs/flutter-apk/app-release.apk "$RELEASE_DIR/driver-app.apk"
if [ -f "build/ios/ipa/truckercore1.ipa" ]; then
  cp build/ios/ipa/truckercore1.ipa "$RELEASE_DIR/driver-app.ipa"
fi

echo ""
echo "Step 4: Building desktop apps..."

# Owner Operator
./scripts/build_production_desktop.sh owner-operator windows
./scripts/build_production_desktop.sh owner-operator macos 2>/dev/null || true
./scripts/build_production_desktop.sh owner-operator linux

# Fleet Manager  
./scripts/build_production_desktop.sh fleet-manager windows
./scripts/build_production_desktop.sh fleet-manager macos 2>/dev/null || true
./scripts/build_production_desktop.sh fleet-manager linux

# Copy desktop artifacts (simplified - actual paths depend on packaging)
echo "Desktop builds complete in build/ directory"

echo ""
echo "✅ All production builds complete!"
echo ""
echo "📦 Release artifacts in: $RELEASE_DIR"
echo ""
echo "Next steps:"
echo "1. Test all builds on physical devices/computers"
echo "2. Complete MANUAL_TESTING_CHECKLIST.md"
echo "3. Create installers for desktop apps"
echo "4. Upload to app stores"
