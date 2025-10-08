#!/bin/bash
set -e

# Driver App Build Script
echo "🚀 Building Driver App..."

# Environment variables
export APP_VERSION="1.0.0"
export GIT_COMMIT=$(git rev-parse --short HEAD)
export RELEASE_CHANNEL="production"

# Supabase credentials (set these in CI/CD secrets)
: ${SUPABASE_URL:?"SUPABASE_URL not set"}
: ${SUPABASE_ANON:?"SUPABASE_ANON not set"}
: ${SENTRY_DSN:?"SENTRY_DSN not set"}

echo "📦 Building for production..."
echo "Version: $APP_VERSION"
echo "Commit: $GIT_COMMIT"

# Clean previous builds
flutter clean
flutter pub get

# Build Android
echo "🤖 Building Android APK & AAB..."
flutter build apk \
  --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON="$SUPABASE_ANON" \
  --dart-define=SENTRY_DSN="$SENTRY_DSN" \
  --dart-define=APP_VERSION="$APP_VERSION" \
  --dart-define=GIT_COMMIT="$GIT_COMMIT" \
  --dart-define=RELEASE_CHANNEL="$RELEASE_CHANNEL" \
  --dart-define=USE_MOCK_DATA="false"

flutter build appbundle \
  --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON="$SUPABASE_ANON" \
  --dart-define=SENTRY_DSN="$SENTRY_DSN" \
  --dart-define=APP_VERSION="$APP_VERSION" \
  --dart-define=GIT_COMMIT="$GIT_COMMIT" \
  --dart-define=RELEASE_CHANNEL="$RELEASE_CHANNEL" \
  --dart-define=USE_MOCK_DATA="false"

# Build iOS (macOS only)
if [[ "$OSTYPE" == "darwin"* ]]; then
  echo "🍎 Building iOS IPA..."
  flutter build ipa \
    --release \
    --dart-define=SUPABASE_URL="$SUPABASE_URL" \
    --dart-define=SUPABASE_ANON="$SUPABASE_ANON" \
    --dart-define=SENTRY_DSN="$SENTRY_DSN" \
    --dart-define=APP_VERSION="$APP_VERSION" \
    --dart-define=GIT_COMMIT="$GIT_COMMIT" \
    --dart-define=RELEASE_CHANNEL="$RELEASE_CHANNEL" \
    --dart-define=USE_MOCK_DATA="false"
fi

echo "✅ Driver App build complete!"
echo "📍 APK: build/app/outputs/flutter-apk/app-release.apk"
echo "📍 AAB: build/app/outputs/bundle/release/app-release.aab"
if [[ "$OSTYPE" == "darwin"* ]]; then
  echo "📍 IPA: build/ios/ipa/*.ipa"
fi
