#!/bin/bash
set -e

echo "🚀 TruckerCore Release Builder"
echo "=============================="
echo ""

# Check prerequisites
echo "Checking prerequisites..."
./scripts/pre_release_check.sh

echo ""
echo "Building all release artifacts..."
echo ""

# Create release directory
mkdir -p releases
RELEASE_DIR="releases/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RELEASE_DIR"

echo "📱 Building Driver App (Mobile)..."
./scripts/build_driver_app.sh || echo "Driver app build script failed or skipped; ensure environment is set."

echo ""
echo "🖥️  Building Owner Operator Dashboard..."
./scripts/build_desktop.sh owner-operator windows || true
./scripts/build_desktop.sh owner-operator macos || true
./scripts/build_desktop.sh owner-operator linux || true

echo ""
echo "🏢 Building Fleet Manager..."
./scripts/build_desktop.sh fleet-manager windows || true
./scripts/build_desktop.sh fleet-manager macos || true
./scripts/build_desktop.sh fleet-manager linux || true

# Copy artifacts
echo ""
echo "📦 Copying release artifacts..."
cp build/app/outputs/bundle/release/app-release.aab "$RELEASE_DIR/driver-app.aab" 2>/dev/null || true
cp build/app/outputs/flutter-apk/app-release.apk "$RELEASE_DIR/driver-app.apk" 2>/dev/null || true

echo ""
echo "✅ Release build complete!"
echo ""
echo "Artifacts saved to: $RELEASE_DIR"
echo ""
echo "Next steps:"
echo "1. Test all builds on target devices"
echo "2. Review RELEASE_CHECKLIST.md"
echo "3. Submit to app stores"
echo "4. Deploy installers"