#!/bin/bash
set -e

echo "🔍 Verifying Feature Completeness..."

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_file() {
  if [ -f "$1" ]; then
    echo -e "${GREEN}✓${NC} $1 exists"
    return 0
  else
    echo -e "${RED}✗${NC} $1 missing"
    return 1
  fi
}

check_directory() {
  if [ -d "$1" ]; then
    echo -e "${GREEN}✓${NC} $1 exists"
    return 0
  else
    echo -e "${RED}✗${NC} $1 missing"
    return 1
  fi
}

check_flutter_package() {
  if grep -q "^  $1:" pubspec.yaml; then
    echo -e "${GREEN}✓${NC} Package $1 installed"
    return 0
  else
    echo -e "${YELLOW}⚠${NC} Package $1 not found in pubspec.yaml"
    return 1
  fi
}

echo ""
echo "📱 Driver App Features"
echo "====================="
check_directory "lib/features/driver"
check_file "lib/features/driver/screens/driver_dashboard.dart" || echo "  → Need driver dashboard"
check_file "lib/features/driver/screens/loads_screen.dart" || echo "  → Need loads screen"
check_file "lib/features/driver/screens/hos_screen.dart" || echo "  → Need HOS screen"

echo ""
echo "🖥️  Owner Operator Features"
echo "=========================="
check_directory "lib/features/owner_operator"
check_file "lib/features/owner_operator/screens/fleet_overview.dart" || echo "  → Need fleet overview"
check_file "lib/features/owner_operator/screens/vehicle_management.dart" || echo "  → Need vehicle management"
check_file "lib/features/owner_operator/screens/reports_screen.dart" || echo "  → Need reports screen"

echo ""
echo "🏢 Fleet Manager Features"
echo "========================="
check_directory "lib/features/fleet_manager"
check_file "lib/features/fleet_manager/screens/multi_fleet_dashboard.dart" || echo "  → Need multi-fleet dashboard"
check_file "lib/features/fleet_manager/screens/user_management.dart" || echo "  → Need user management"
check_file "lib/features/fleet_manager/screens/compliance_screen.dart" || echo "  → Need compliance screen"

echo ""
echo "🔐 Authentication"
echo "================"
check_directory "lib/core/auth"
check_file "lib/core/auth/auth_provider.dart"
check_file "lib/features/auth/screens/login_screen.dart" || echo "  → Need login screen"

echo ""
echo "📦 Critical Dependencies"
echo "======================="
check_flutter_package "supabase_flutter"
check_flutter_package "flutter_riverpod"
check_flutter_package "go_router"
check_flutter_package "geolocator" || echo "  → Need for driver location tracking"
check_flutter_package "path_provider" || echo "  → Need for offline storage"

echo ""
echo "🧪 Tests"
echo "======="
check_directory "test"
check_directory "test/integration"
check_file "test/integration/driver_app_flows_test.dart"
check_file "test/integration/desktop_flows_test.dart"

echo ""
echo "📋 Build Configuration"
echo "====================="
check_file "scripts/build_driver_app.sh"
check_file "scripts/build_desktop.sh"
check_file ".github/workflows/build-driver-app.yml"
check_file ".github/workflows/build-desktop.yml"

echo ""
echo "🎯 Release Preparation"
echo "====================="
check_file "RELEASE_CHECKLIST.md"
check_file ".env.production" || echo -e "${YELLOW}⚠${NC} Create .env.production for local testing"
check_file "android/key.properties" || echo -e "${YELLOW}⚠${NC} Configure Android signing"

echo ""
echo "✅ Verification complete!"
echo ""
echo "Run this command to execute tests:"
echo "  flutter test"
echo ""
echo "Run integration tests with:"
echo "  flutter test integration_test/"
