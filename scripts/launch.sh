#!/bin/bash
set -e

cat << "EOF"
   ______                __             ______               
  /_  __/______  _______/ /_____  _____/ ____/___  ________ 
   / / / ___/ / / / ___/ //_/ _ \/ ___/ /   / __ \/ ___/ _ \
  / / / /  / /_/ / /__/ ,< /  __/ /  / /___/ /_/ / /  /  __/
 /_/ /_/   \__,_/\___/_/|_|\___/_/   \____/\____/_/   \___/ 
                                                              
EOF

echo ""
echo "🚀 TruckerCore Launch Script"
echo "============================="
echo ""
echo "This script will guide you through the final launch process."
echo ""

# Check if everything is ready
echo "Step 1: Running final checks..."
./scripts/final_checks.sh || {
  echo ""
  echo "❌ Final checks failed. Please fix errors and try again."
  exit 1
}

echo ""
echo "Step 2: Version confirmation"
VERSION=$(cat VERSION)
echo "Current version: v$VERSION"
read -p "Is this the correct version for launch? (yes/no): " VERSION_OK

if [ "$VERSION_OK" != "yes" ]; then
  echo "Please update VERSION file and try again."
  exit 0
fi

echo ""
echo "Step 3: Environment check"
read -p "Are you deploying to PRODUCTION? (yes/no): " IS_PROD

if [ "$IS_PROD" != "yes" ]; then
  echo "Launch cancelled. Use this script only for production launches."
  exit 0
fi

echo ""
echo "Step 4: Pre-launch checklist"
echo "Have you completed all items in PRE_LAUNCH_CHECKLIST.md?"
read -p "All items checked? (yes/no): " CHECKLIST_OK

if [ "$CHECKLIST_OK" != "yes" ]; then
  echo "Please complete the pre-launch checklist first."
  exit 0
fi

echo ""
echo "Step 5: Backup verification"
read -p "Have you backed up the production database? (yes/no): " BACKUP_OK

if [ "$BACKUP_OK" != "yes" ]; then
  echo "Please backup the database before launching."
  exit 0
fi

echo ""
echo "Step 6: Building production releases..."
./scripts/release.sh || {
  echo "❌ Build failed"
  exit 1
}

echo ""
echo "Step 7: Creating git tag..."
git tag -a "v$VERSION" -m "Production release v$VERSION" || {
  echo "⚠️  Tag might already exist"
}

echo ""
echo "✅ Launch preparation complete!"
echo ""
echo "📦 Release artifacts are ready in: releases/"
echo ""
echo "🎯 Final manual steps:"
echo "   1. Test all builds on physical devices"
echo "   2. Submit mobile apps:"
echo "      - Android: Upload AAB to Google Play Console"
echo "      - iOS: Upload IPA to App Store Connect"
echo "   3. Upload desktop installers to distribution server"
echo "   4. Update website with download links"
echo "   5. Send release announcements"
echo "   6. Monitor Sentry for errors"
echo "   7. Push git tags: git push origin v$VERSION"
echo ""
echo "🎉 Congratulations on your launch!"
echo ""

# Log launch event
echo "$(date): Launched version $VERSION" >> .launch_history

read -p "Press enter to finish..." || true
