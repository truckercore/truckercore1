#!/bin/bash
set -e

echo "🖥️  Production Desktop Build"
echo "============================="
echo ""

# Parameters
ROLE=$1
PLATFORM=$2

if [ -z "$ROLE" ] || [ -z "$PLATFORM" ]; then
  echo "Usage: ./scripts/build_production_desktop.sh [owner-operator|fleet-manager] [windows|macos|linux|all]"
  exit 1
fi

# Configuration
VERSION=$(cat VERSION)
BUILD_NUMBER=$(date +%Y%m%d%H%M)
GIT_COMMIT=$(git rev-parse --short HEAD)

echo "Building: $ROLE"
echo "Platform: $PLATFORM"
echo "Version: $VERSION"
echo "Build: $BUILD_NUMBER"
echo ""

# Verify environment
if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_ANON" ]; then
  echo "❌ Environment variables not set"
  exit 1
fi

# Set default role
if [ "$ROLE" = "owner-operator" ]; then
  DEFAULT_ROLE="owner_operator"
  APP_NAME="TruckerCore Owner Operator"
elif [ "$ROLE" = "fleet-manager" ]; then
  DEFAULT_ROLE="fleet_manager"
  APP_NAME="TruckerCore Fleet Manager"
else
  echo "❌ Invalid role: $ROLE"
  exit 1
fi

# Clean
echo "🧹 Cleaning..."
flutter clean
flutter pub get

# Build function
build_platform() {
  local platform=$1
  echo ""
  echo "Building for $platform..."
  echo ""
  
  flutter build $platform \
    --release \
    --build-number=$BUILD_NUMBER \
    --dart-define=SUPABASE_URL="$SUPABASE_URL" \
    --dart-define=SUPABASE_ANON="$SUPABASE_ANON" \
    --dart-define=SENTRY_DSN="$SENTRY_DSN" \
    --dart-define=APP_VERSION="$VERSION" \
    --dart-define=GIT_COMMIT="$GIT_COMMIT" \
    --dart-define=RELEASE_CHANNEL="production" \
    --dart-define=USE_MOCK_DATA="false" \
    --dart-define=DEFAULT_ROLE="$DEFAULT_ROLE"
  
  if [ $? -eq 0 ]; then
    echo "✅ $platform build successful"
  else
    echo "❌ $platform build failed"
    return 1
  fi
}

# Build based on platform
case $PLATFORM in
  windows)
    build_platform "windows"
    BUILD_PATH="build/windows/x64/runner/Release"
    echo ""
    echo "📦 Windows build: $BUILD_PATH"
    echo "   Create installer: Use Inno Setup or NSIS"
    ;;
    
  macos)
    if [[ "$OSTYPE" != "darwin"* ]]; then
      echo "❌ macOS builds require macOS"
      exit 1
    fi
    build_platform "macos"
    BUILD_PATH="build/macos/Build/Products/Release"
    echo ""
    echo "📦 macOS build: $BUILD_PATH"
    echo "   Create DMG: Use create-dmg or appdmg"
    echo "   Sign and notarize for distribution"
    ;;
    
  linux)
    build_platform "linux"
    BUILD_PATH="build/linux/x64/release/bundle"
    echo ""
    echo "📦 Linux build: $BUILD_PATH"
    echo "   Create package: Use AppImage, snap, or .deb"
    ;;
    
  all)
    echo "Building for all platforms..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
      build_platform "macos"
    fi
    build_platform "windows"
    build_platform "linux"
    ;;
    
  *)
    echo "❌ Invalid platform: $PLATFORM"
    exit 1
    ;;
esac

echo ""
echo "✅ Desktop build complete!"
echo ""
echo "Next steps:"
echo "1. Test the build on target platform"
echo "2. Create installer/package"
echo "3. Sign the executable (Windows/macOS)"
echo "4. Test installation process"
