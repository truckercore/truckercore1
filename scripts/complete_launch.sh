#!/bin/bash
set -e

echo "🚀 TruckerCore Complete Launch System"
echo "======================================"
echo ""

# Step 1: Validate
echo "Step 1: Running validation..."
./scripts/validate_production_ready.sh || {
  echo ""
  echo "❌ Validation failed. Fix errors before launching."
  exit 1
}

echo ""
echo "✅ Validation passed!"
echo ""

# Step 2: Confirm
read -p "Ready to build production apps? (yes/no): " BUILD_CONFIRM
if [ "$BUILD_CONFIRM" != "yes" ]; then
  echo "Launch cancelled."
  exit 0
fi

# Step 3: Build
echo ""
echo "Step 2: Building production apps..."
./scripts/build_all_production.sh

echo ""
echo "✅ Build complete!"
echo ""

# Step 4: Launch
read -p "Ready to execute final launch? (yes/no): " LAUNCH_CONFIRM
if [ "$LAUNCH_CONFIRM" != "yes" ]; then
  echo "Launch cancelled. Builds are ready in releases/ directory."
  exit 0
fi

echo ""
echo "Step 3: Executing launch..."
./scripts/launch.sh

echo ""
echo "🎉 Launch complete!"
echo ""
echo "Next steps:"
echo "1. Monitor systems: ./scripts/monitor_production.sh"
echo "2. Check metrics: ./scripts/metrics_dashboard.sh"
echo "3. Submit to app stores"
echo "4. Update website"
echo "5. Send announcements"
