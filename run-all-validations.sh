#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

echo -e "${CYAN}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                                                       ║${NC}"
echo -e "${CYAN}║        Complete Infrastructure Validation            ║${NC}"
echo -e "${CYAN}║                                                       ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""

TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

run_validation() {
  local script=$1
  local name=$2
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${MAGENTA}▶ Running: $name${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""

  ((TOTAL_CHECKS++))

  if [ ! -f "$script" ]; then
    echo -e "${RED}❌ Script not found: $script${NC}"
    ((FAILED_CHECKS++))
    echo ""
    return 1
  fi

  chmod +x "$script" 2>/dev/null || true
  if ./$script; then
    echo ""
    echo -e "${GREEN}✅ $name - PASSED${NC}"
    ((PASSED_CHECKS++))
  else
    echo ""
    echo -e "${RED}❌ $name - FAILED${NC}"
    ((FAILED_CHECKS++))
  fi
  echo ""
}

# Run validations
run_validation "validate-implementation.sh" "Implementation Validation"
run_validation "verify-setup.sh" "Setup Verification"
run_validation "scripts/health-check.sh" "Health Check"

# Status Dashboard (non-fatal)
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${MAGENTA}▶ Running: Status Dashboard${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
if [ -f "./scripts/status-dashboard.sh" ]; then
  chmod +x ./scripts/status-dashboard.sh 2>/dev/null || true
  ./scripts/status-dashboard.sh || true
else
  echo -e "${YELLOW}⚠️  Status dashboard not found${NC}"
fi

# Summary
echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                   VALIDATION SUMMARY                  ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Total Checks: ${TOTAL_CHECKS}"
echo -e "  ${GREEN}Passed: ${PASSED_CHECKS}${NC}"
echo -e "  ${RED}Failed: ${FAILED_CHECKS}${NC}"

if [ $FAILED_CHECKS -eq 0 ]; then
  echo -e "${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║                                                       ║${NC}"
  echo -e "${GREEN}║              ✅ ALL VALIDATIONS PASSED ✅             ║${NC}"
  echo -e "${GREEN}║                                                       ║${NC}"
  echo -e "${GREEN}║              Ready for Deployment! 🚀                 ║${NC}"
  echo -e "${GREEN}║                                                       ║${NC}"
  echo -e "${GREEN}╚═══════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "${CYAN}Next Steps:${NC}"
  echo -e "  1. Review the validation output above"
  echo -e "  2. Commit any remaining changes: ${YELLOW}git add . && git commit${NC}"
  echo -e "  3. Push to repository: ${YELLOW}git push origin main${NC}"
  REPO_URL=$(git remote get-url origin 2>/dev/null | sed 's/\.git$//' | sed 's/git@github.com:/https:\/\/github.com\//')
  echo -e "  4. Monitor GitHub Actions: ${BLUE}${REPO_URL:-https://github.com/<repo>}/actions${NC}"
  echo ""
  exit 0
else
  echo -e "${RED}╔═══════════════════════════════════════════════════════╗${NC}"
  echo -e "${RED}║                                                       ║${NC}"
  echo -e "${RED}║              ❌ SOME CHECKS FAILED ❌                 ║${NC}"
  echo -e "${RED}║                                                       ║${NC}"
  echo -e "${RED}║         Review output above for details               ║${NC}"
  echo -e "${RED}║                                                       ║${NC}"
  echo -e "${RED}╚═══════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "${YELLOW}Troubleshooting:${NC}"
  echo -e "  1. Review failed checks above"
  echo -e "  2. Run individual scripts for details"
  echo -e "  3. Fix issues and re-run validation"
  echo ""
  exit 1
fi
