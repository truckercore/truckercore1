#!/bin/bash
# TruckerCore - Final comprehensive check before production deployment
# Usage: bash scripts/final-deployment-check.sh

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
cat << "EOF"
╔════════════════════════════════════════════════╗
║   TruckerCore Final Deployment Verification    ║
╚════════════════════════════════════════════════╝
EOF
echo -e "${NC}\n"

CHECKS_PASSED=0
CHECKS_FAILED=0

run_check() {
  local check_name="$1"
  local check_command="$2"
  local index="$3"
  local total="$4"
  echo -ne "${BLUE}[${index}/${total}]${NC} ${check_name}... "
  if eval "$check_command" > /dev/null 2>&1; then
    echo -e "${GREEN}✅${NC}"
    CHECKS_PASSED=$((CHECKS_PASSED+1))
    return 0
  else
    echo -e "${RED}❌${NC}"
    CHECKS_FAILED=$((CHECKS_FAILED+1))
    return 1
  fi
}

# Define checks
CHECK_NAMES=(
  "DNS configuration"
  "Deployment status files"
  "SEO validation"
  "TypeScript compilation"
  "Production build"
  "Unit tests"
  "Asset verification"
  "Environment variables (Vercel)"
  "Git status clean"
  "On main branch"
)

TOTAL_CHECKS=${#CHECK_NAMES[@]}
INDEX=1

echo "Running pre-deployment checks..."
# 1. DNS configuration (cross-platform wrapper already exists)
run_check "${CHECK_NAMES[0]}" "npm run dns:check" "$INDEX" "$TOTAL_CHECKS"; INDEX=$((INDEX+1))

# 2. Deployment status files
run_check "${CHECK_NAMES[1]}" "npm run check:status" "$INDEX" "$TOTAL_CHECKS"; INDEX=$((INDEX+1))

# 3. SEO validation
run_check "${CHECK_NAMES[2]}" "npm run validate:seo" "$INDEX" "$TOTAL_CHECKS"; INDEX=$((INDEX+1))

# 4. TypeScript compilation
run_check "${CHECK_NAMES[3]}" "npm run typecheck" "$INDEX" "$TOTAL_CHECKS"; INDEX=$((INDEX+1))

# 5. Production build
run_check "${CHECK_NAMES[4]}" "npm run build" "$INDEX" "$TOTAL_CHECKS"; INDEX=$((INDEX+1))

# 6. Unit tests
run_check "${CHECK_NAMES[5]}" "npm run test:unit" "$INDEX" "$TOTAL_CHECKS"; INDEX=$((INDEX+1))

# 7. Asset verification (favicon + logo at minimum)
run_check "${CHECK_NAMES[6]}" "test -f public/favicon.ico && test -f public/logo.svg" "$INDEX" "$TOTAL_CHECKS"; INDEX=$((INDEX+1))

# 8. Environment variables (Vercel) – optional if CLI is installed
if command -v vercel >/dev/null 2>&1; then
  run_check "${CHECK_NAMES[7]}" "vercel env ls production | grep -q NEXT_PUBLIC_SUPABASE_URL" "$INDEX" "$TOTAL_CHECKS"
else
  echo -e "${YELLOW}[${INDEX}/${TOTAL_CHECKS}] Vercel CLI not installed – skipping env check${NC}"
fi
INDEX=$((INDEX+1))

# 9. Git status clean
run_check "${CHECK_NAMES[8]}" "test -z \"$(git status --porcelain)\"" "$INDEX" "$TOTAL_CHECKS"; INDEX=$((INDEX+1))

# 10. On main branch
run_check "${CHECK_NAMES[9]}" "[ \"$(git branch --show-current)\" = 'main' ]" "$INDEX" "$TOTAL_CHECKS"; INDEX=$((INDEX+1))

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
if [ "$CHECKS_FAILED" -eq 0 ]; then
  echo -e "${GREEN}✅ All checks passed! (${CHECKS_PASSED}/${TOTAL_CHECKS})${NC}"
  echo ""
  echo "🚀 Ready for production deployment!"
  echo ""
  echo "Run: npm run deploy"
  echo ""
  exit 0
else
  echo -e "${RED}❌ ${CHECKS_FAILED} check(s) failed${NC}"
  echo -e "${GREEN}✅ ${CHECKS_PASSED} check(s) passed${NC}"
  echo ""
  echo "Fix the failed checks before deploying."
  echo ""
  exit 1
fi
