#!/bin/bash
set -e

echo "🚀 TruckerCore Production Deployment"
echo "====================================="
echo ""

# Verify pre-launch checklist
if [ ! -f "PRE_LAUNCH_CHECKLIST.md" ]; then
  echo "❌ PRE_LAUNCH_CHECKLIST.md not found!"
  echo "Please complete the pre-launch checklist first."
  exit 1
fi

echo "⚠️  WARNING: This will deploy to production!"
echo ""
read -p "Have you completed the pre-launch checklist? (yes/no): " CONFIRMED

if [ "$CONFIRMED" != "yes" ]; then
  echo "Deployment cancelled."
  exit 0
fi

echo ""
echo "Starting deployment process..."
echo ""

# Run pre-release checks
echo "1️⃣  Running pre-release checks..."
./scripts/pre_release_check.sh || {
  echo "❌ Pre-release checks failed!"
  exit 1
}

# Backup current release (if exists)
if [ -d "releases/current" ]; then
  echo ""
  echo "2️⃣  Backing up current release..."
  BACKUP_DIR="releases/backup_$(date +%Y%m%d_%H%M%S)"
  mkdir -p "$BACKUP_DIR"
  cp -r releases/current/* "$BACKUP_DIR/"
  echo "✅ Backup saved to: $BACKUP_DIR"
fi

# Build production releases
echo ""
echo "3️⃣  Building production releases..."
./scripts/release.sh || {
  echo "❌ Build failed!"
  exit 1
}

# Run smoke tests
echo ""
echo "4️⃣  Running smoke tests..."
export SMOKE_TEST=true
flutter test || {
  echo "⚠️  Some tests failed. Continue anyway? (yes/no)"
  read CONTINUE
  if [ "$CONTINUE" != "yes" ]; then
    exit 1
  fi
}

# Tag release
echo ""
echo "5️⃣  Tagging release..."
VERSION=$(grep "version:" pubspec.yaml | sed 's/version: //')

git tag -a "v$VERSION" -m "Production release v$VERSION" || echo "Tag already exists"

echo ""
echo "✅ Production build complete!"
echo ""
echo "📦 Release artifacts ready in: releases/"
echo ""
echo "Next manual steps:"
echo "1. Test all builds on physical devices"
echo "2. Submit mobile apps to app stores:"
echo "   - Android: Google Play Console"
echo "   - iOS: App Store Connect"
echo "3. Upload desktop installers to distribution server"
echo "4. Update website with download links"
echo "5. Notify users of new release"
echo "6. Monitor error tracking (Sentry)"
