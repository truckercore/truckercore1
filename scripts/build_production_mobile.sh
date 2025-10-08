#!/bin/bash
set -e

echo "📱 Production Mobile Build"
echo "=========================="
echo ""

# Configuration
VERSION=$(cat VERSION)
BUILD_NUMBER=$(date +%Y%m%d%H%M)
GIT_COMMIT=$(git rev-parse --short HEAD)

echo "Version: $VERSION"
echo "Build: $BUILD_NUMBER"
echo "Commit: $GIT_COMMIT"
echo ""

# Verify environment
if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_ANON" ]; then
  echo "❌ Environment variables not set"
  echo "Run: source .env.production"
  exit 1
fi

if [ -z "$SENTRY_DSN" ]; then
  echo "⚠️  SENTRY_DSN not set (error tracking will be disabled)"
  read -p "Continue anyway? (yes/no): " CONTINUE
  if [ "$CONTINUE" != "yes" ]; then
    exit 1
  fi
fi

echo "🧹 Cleaning previous builds..."
flutter clean
flutter pub get

# ============================================================================
# ANDROID BUILD
# ============================================================================
echo ""
echo "🤖 Building Android..."
echo ""

# Check Android signing
if [ ! -f "android/key.properties" ]; then
  echo "❌ android/key.properties not found"
  echo "Create it with your keystore credentials"
  exit 1
fi

# Build AAB (for Play Store)
echo "Building Android App Bundle (AAB)..."
flutter build appbundle \
  --release \
  --build-number=$BUILD_NUMBER \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON="$SUPABASE_ANON" \
  --dart-define=SENTRY_DSN="$SENTRY_DSN" \
  --dart-define=APP_VERSION="$VERSION" \
  --dart-define=GIT_COMMIT="$GIT_COMMIT" \
  --dart-define=RELEASE_CHANNEL="production" \
  --dart-define=USE_MOCK_DATA="false"

AAB_PATH="build/app/outputs/bundle/release/app-release.aab"
if [ -f "$AAB_PATH" ]; then
  echo "✅ AAB created: $AAB_PATH"
  AAB_SIZE=$(du -h "$AAB_PATH" | cut -f1)
  echo "   Size: $AAB_SIZE"
else
  echo "❌ AAB build failed"
  exit 1
fi

# Build APK (for direct distribution/testing)
echo ""
echo "Building Android APK..."
flutter build apk \
  --release \
  --build-number=$BUILD_NUMBER \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON="$SUPABASE_ANON" \
  --dart-define=SENTRY_DSN="$SENTRY_DSN" \
  --dart-define=APP_VERSION="$VERSION" \
  --dart-define=GIT_COMMIT="$GIT_COMMIT" \
  --dart-define=RELEASE_CHANNEL="production" \
  --dart-define=USE_MOCK_DATA="false"

APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
if [ -f "$APK_PATH" ]; then
  echo "✅ APK created: $APK_PATH"
  APK_SIZE=$(du -h "$APK_PATH" | cut -f1)
  echo "   Size: $APK_SIZE"
else
  echo "❌ APK build failed"
  exit 1
fi

# ============================================================================
# iOS BUILD (macOS only)
# ============================================================================
if [[ "$OSTYPE" == "darwin"* ]]; then
  echo ""
  echo "🍎 Building iOS..."
  echo ""
  
  # Build IPA
  flutter build ipa \
    --release \
    --build-number=$BUILD_NUMBER \
    --dart-define=SUPABASE_URL="$SUPABASE_URL" \
    --dart-define=SUPABASE_ANON="$SUPABASE_ANON" \
    --dart-define=SENTRY_DSN="$SENTRY_DSN" \
    --dart-define=APP_VERSION="$VERSION" \
    --dart-define=GIT_COMMIT="$GIT_COMMIT" \
    --dart-define=RELEASE_CHANNEL="production" \
    --dart-define=USE_MOCK_DATA="false"
  
  IPA_PATH="build/ios/ipa/truckercore1.ipa"
  if [ -f "$IPA_PATH" ]; then
    echo "✅ IPA created: $IPA_PATH"
    IPA_SIZE=$(du -h "$IPA_PATH" | cut -f1)
    echo "   Size: $IPA_SIZE"
  else
    echo "⚠️  IPA build may have failed (check build/ios/archive)"
  fi
else
  echo ""
  echo "⚠️  Skipping iOS build (not on macOS)"
fi

echo ""
echo "✅ Mobile builds complete!"
echo ""
echo "📦 Artifacts:"
echo "   Android AAB: $AAB_PATH"
echo "   Android APK: $APK_PATH"
if [[ "$OSTYPE" == "darwin"* ]]; then
  echo "   iOS IPA: $IPA_PATH"
fi
echo ""
echo "Next steps:"
echo "1. Test APK on physical Android device"
echo "2. Test IPA on physical iOS device (via TestFlight or direct install)"
echo "3. Upload AAB to Google Play Console"
echo "4. Upload IPA to App Store Connect"
