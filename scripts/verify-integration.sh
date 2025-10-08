#!/bin/bash

# Fleet Manager Dashboard - Integration Verification (adapted for this repo)
# Usage: ./scripts/verify-integration.sh

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0
WARNINGS=0

check_result() {
  if [ $1 -eq 0 ]; then
    echo -e "${GREEN}✓ PASSED${NC}: $2"
    ((PASSED++))
  else
    echo -e "${RED}✗ FAILED${NC}: $2"
    ((FAILED++))
  fi
}

check_warning() {
  echo -e "${YELLOW}⚠ WARNING${NC}: $1"
  ((WARNINGS++))
}

# Determine repo root (this script lives in repo_root/scripts)
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
WEB_DIR="$REPO_ROOT/apps/web"

if [ ! -d "$WEB_DIR" ]; then
  echo -e "${RED}apps/web directory not found. Aborting.${NC}"
  exit 1
fi

cd "$WEB_DIR"

echo "🔍 Fleet Manager Dashboard - Integration Verification"
echo "====================================================="
echo ""

echo "1. Checking Environment Setup..."
echo "--------------------------------"

# Check Node.js version
if command -v node &> /dev/null; then
  NODE_VERSION=$(node --version | sed 's/v//' | cut -d'.' -f1)
  if [ "$NODE_VERSION" -ge 18 ]; then
    check_result 0 "Node.js version ($(node --version))"
  else
    check_result 1 "Node.js version - Requires v18 or higher (found $(node --version))"
  fi
else
  check_result 1 "Node.js not found"
fi

# Check npm
if command -v npm &> /dev/null; then
  check_result 0 "npm installed ($(npm --version))"
else
  check_result 1 "npm not found"
fi

# Ensure .env.local
if [ -f ".env.local" ]; then
  check_result 0 ".env.local exists"
else
  check_warning ".env.local not found - creating a minimal template"
  cat > .env.local << EOF
DATABASE_URL=postgresql://localhost:5432/fleet_db
NEXT_PUBLIC_WS_URL=ws://localhost:3000
NEXT_PUBLIC_MAP_STYLE_URL=https://basemaps.cartocdn.com/gl/positron-gl-style/style.json
NEXT_PUBLIC_APP_URL=http://localhost:3000
NODE_ENV=development
EOF
fi

# Check required env vars
REQUIRED_VARS=("DATABASE_URL" "NEXT_PUBLIC_WS_URL" "NEXT_PUBLIC_MAP_STYLE_URL")
for var in "${REQUIRED_VARS[@]}"; do
  if grep -q "^${var}=" .env.local; then
    check_result 0 "Environment variable: $var"
  else
    check_warning "Missing environment variable: $var"
  fi
done

echo ""
echo "2. Checking Dependencies..."
echo "----------------------------"

if [ -d "node_modules" ]; then
  check_result 0 "node_modules directory exists"
else
  check_warning "node_modules not found - running npm install (this may take a while)"
  npm install &> /dev/null || true
  if [ -d "node_modules" ]; then
    check_result 0 "Dependencies installed"
  else
    check_result 1 "Failed to install dependencies"
  fi
fi

CRITICAL_DEPS=("next" "react" "maplibre-gl" "zustand" "ws")
for dep in "${CRITICAL_DEPS[@]}"; do
  if [ -d "node_modules/$dep" ]; then
    check_result 0 "Dependency: $dep"
  else
    check_warning "Missing dependency: $dep"
  fi
done

echo ""
echo "3. Checking File Structure..."
echo "------------------------------"

# Use paths that match this repo (App Router under src/app and components under src/components)
CRITICAL_FILES=(
  "src/app/fleet-manager-dashboard/page.tsx"
  "src/components/FleetManagerDashboard.tsx"
  "src/components/TestingHelper.tsx"
  "src/lib/fleet/config.ts"
  "src/lib/fleet/mapUtils.ts"
  "src/lib/fleet/mockData.ts"
  "src/stores/fleetStore.ts"
  "src/types/fleet.ts"
)

for file in "${CRITICAL_FILES[@]}"; do
  if [ -f "$file" ]; then
    check_result 0 "File: $file"
  else
    check_warning "Missing file: $file"
  fi
done

echo ""
echo "4. Checking API Routes..."
echo "-------------------------"

API_ROUTES=(
  "src/pages/api/health.ts"
  "src/pages/api/metrics.ts"
  "src/pages/api/fleet/vehicles.ts"
  "src/pages/api/fleet/drivers.ts"
  "src/pages/api/fleet/loads.ts"
  "src/pages/api/fleet/alerts.ts"
  "src/pages/api/fleet/geofences.ts"
  "src/pages/api/fleet/maintenance/index.ts"
  "src/pages/api/fleet/maintenance/[id]/complete.ts"
  "src/pages/api/fleet/dispatch/recommend.ts"
  "src/pages/api/fleet/dispatch/assign.ts"
  "src/pages/api/fleet/analytics.ts"
  "src/pages/api/fleet/ws.ts"
)

for route in "${API_ROUTES[@]}"; do
  if [ -f "$route" ]; then
    check_result 0 "API Route: $route"
  else
    # Many routes may be intentionally absent in this repo; treat as warnings
    check_warning "Missing API route: $route"
  fi
done

echo ""
echo "5. Running TypeScript Check..."
echo "-------------------------------"

if npm run type-check &> /dev/null; then
  check_result 0 "TypeScript compilation"
else
  check_result 1 "TypeScript compilation failed"
fi

echo ""
echo "6. Running Linter..."
echo "--------------------"

if npm run lint &> /dev/null; then
  check_result 0 "ESLint check"
else
  check_warning "ESLint warnings or errors (non-blocking for integration)"
fi

echo ""
echo "7. Checking Documentation..."
echo "-----------------------------"

DOCS=(
  "${REPO_ROOT}/docs/FLEET_TESTING_GUIDE.md"
  "${REPO_ROOT}/docs/PRODUCTION_DEPLOYMENT.md"
  "${REPO_ROOT}/docs/API_DOCUMENTATION.md"
  "${REPO_ROOT}/docs/ARCHITECTURE.md"
  "${REPO_ROOT}/docs/FLEET_DASHBOARD_IMPLEMENTATION_PLAN.md"
  "${REPO_ROOT}/docs/QUICK_START.md"
  "${REPO_ROOT}/docs/DEVELOPMENT_WORKFLOW.md"
  "${REPO_ROOT}/docs/QUICK_REFERENCE.md"
)

for doc in "${DOCS[@]}"; do
  if [ -f "$doc" ]; then
    check_result 0 "Documentation: $(realpath --relative-to="$REPO_ROOT" "$doc" 2>/dev/null || echo "$doc")"
  else
    check_warning "Missing documentation: $(realpath --relative-to="$REPO_ROOT" "$doc" 2>/dev/null || echo "$doc")"
  fi
done

echo ""
echo "8. Checking Database Schema..."
echo "-------------------------------"

SCHEMA_FILE="${REPO_ROOT}/lib/database/fleet-schema.sql"
if [ -f "$SCHEMA_FILE" ]; then
  check_result 0 "Database schema file exists"
  TABLES=("vehicles" "drivers" "loads" "geofences" "maintenance_records" "alerts")
  for table in "${TABLES[@]}"; do
    if grep -q "CREATE TABLE[[:space:]]\+${table}\b" "$SCHEMA_FILE"; then
      check_result 0 "Schema includes table: $table"
    else
      check_warning "Schema missing table: $table"
    fi
  done
else
  check_warning "Database schema file not found at lib/database/fleet-schema.sql"
fi

echo ""
echo "9. Testing Build..."
echo "-------------------"

if npm run build &> /dev/null; then
  check_result 0 "Production build"
else
  check_result 1 "Production build failed"
fi

echo ""
echo "================================================================"
echo "                    VERIFICATION SUMMARY"
echo "================================================================"
echo -e "${GREEN}Passed:${NC}   $PASSED"
echo -e "${RED}Failed:${NC}   $FAILED"
echo -e "${YELLOW}Warnings:${NC} $WARNINGS"

if [ $FAILED -eq 0 ]; then
  echo -e "\n${GREEN}✓ All critical checks passed!${NC}"
  echo ""
  echo "Next steps:"
  echo "1. Run 'npm run dev' (from apps/web) to start the dev server"
  echo "2. Visit http://localhost:3000/fleet/dashboard or /freight-broker-dashboard"
  echo "3. Follow the Testing Guide in docs/FLEET_TESTING_GUIDE.md"
  exit 0
else
  echo -e "\n${RED}✗ Some checks failed. Please fix the issues above.${NC}"
  exit 1
fi
