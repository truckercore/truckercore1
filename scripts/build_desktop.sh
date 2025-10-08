#!/bin/bash
set -e

# Desktop Build Script
# Usage: ./scripts/build_desktop.sh [owner-operator|fleet-manager] [windows|macos|linux]

ROLE=$1
PLATFORM=$2

if [ -z "$ROLE" ] || [ -z "$PLATFORM" ]; then
  echo "Usage: ./scripts/build_desktop.sh [owner-operator|fleet-manager] [windows|macos|linux]"
  exit 1
fi

echo "🚀 Building $ROLE for $PLATFORM..."

# Environment variables
export APP_VERSION="1.0.0"
export GIT_COMMIT=$(git rev-parse --short HEAD)
export RELEASE_CHANNEL="production"

# Supabase credentials
: ${SUPABASE_URL:?"SUPABASE_URL not set"}
: ${SUPABASE_ANON:?"SUPABASE_ANON not set"}
: ${SENTRY_DSN:?"SENTRY_DSN not set"}

# Set default role for the build
if [ "$ROLE" = "owner-operator" ]; then
  DEFAULT_ROLE="owner_operator"
  APP_NAME="TruckerCore Owner Operator"
elif [ "$ROLE" = "fleet-manager" ]; then
  DEFAULT_ROLE="fleet_manager"
  APP_NAME="TruckerCore Fleet Manager"
else
  echo "Invalid role: $ROLE"
  exit 1
fi

echo "📦 Building $APP_NAME..."
echo "Platform: $PLATFORM"
echo "Version: $APP_VERSION"
echo "Commit: $GIT_COMMIT"

# Clean
flutter clean
flutter pub get

# Build based on platform
case $PLATFORM in
  windows)
    echo "🪟 Building Windows installer..."
    flutter build windows \
      --release \
      --dart-define=SUPABASE_URL="$SUPABASE_URL" \
      --dart-define=SUPABASE_ANON="$SUPABASE_ANON" \
      --dart-define=SENTRY_DSN="$SENTRY_DSN" \
      --dart-define=APP_VERSION="$APP_VERSION" \
      --dart-define=GIT_COMMIT="$GIT_COMMIT" \
      --dart-define=RELEASE_CHANNEL="$RELEASE_CHANNEL" \
      --dart-define=USE_MOCK_DATA="false" \
      --dart-define=DEFAULT_ROLE="$DEFAULT_ROLE"
    
    # Package as installer (requires Inno Setup or similar)
    echo "📦 Creating Windows installer..."
    # Add your Windows packaging command here
    ;;
    
  macos)
    echo "🍎 Building macOS installer..."
    flutter build macos \
      --release \
      --dart-define=SUPABASE_URL="$SUPABASE_URL" \
      --dart-define=SUPABASE_ANON="$SUPABASE_ANON" \
      --dart-define=SENTRY_DSN="$SENTRY_DSN" \
      --dart-define=APP_VERSION="$APP_VERSION" \
      --dart-define=GIT_COMMIT="$GIT_COMMIT" \
      --dart-define=RELEASE_CHANNEL="$RELEASE_CHANNEL" \
      --dart-define=USE_MOCK_DATA="false" \
      --dart-define=DEFAULT_ROLE="$DEFAULT_ROLE"
    
    # Create DMG
    echo "📦 Creating macOS DMG..."
    # Add your macOS packaging command here
    ;;
    
  linux)
    echo "🐧 Building Linux package..."
    flutter build linux \
      --release \
      --dart-define=SUPABASE_URL="$SUPABASE_URL" \
      --dart-define=SUPABASE_ANON="$SUPABASE_ANON" \
      --dart-define=SENTRY_DSN="$SENTRY_DSN" \
      --dart-define=APP_VERSION="$APP_VERSION" \
      --dart-define=GIT_COMMIT="$GIT_COMMIT" \
      --dart-define=RELEASE_CHANNEL="$RELEASE_CHANNEL" \
      --dart-define=USE_MOCK_DATA="false" \
      --dart-define=DEFAULT_ROLE="$DEFAULT_ROLE"
    
    # Create AppImage or .deb
    echo "📦 Creating Linux package..."
    # Add your Linux packaging command here
    ;;
    
  *)
    echo "Invalid platform: $PLATFORM"
    exit 1
    ;;
esac

# In case the above case statement failed, fallback; otherwise
# if we reached here, build was successful
if [ $? -eq 0 ]; then
  echo "✅ Build complete for $APP_NAME on $PLATFORM!"
fi
