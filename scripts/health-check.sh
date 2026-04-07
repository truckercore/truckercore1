#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🏥 Infrastructure Health Check${NC}"
echo "================================"
echo ""

# Track overall status
FAILURES=0
WARNINGS=0

# Function to check file exists
check_file() {
  if [ -f "$1" ]; then
    echo -e "  ${GREEN}✅${NC} $1"
    return 0
  else
    echo -e "  ${RED}❌${NC} $1 (MISSING)"
    ((FAILURES++))
    return 1
  fi
}

# Function to check command exists
check_command() {
  if command -v "$1" &> /dev/null; then
    echo -e "  ${GREEN}✅${NC} $1 is installed"
    return 0
  else
    echo -e "  ${YELLOW}⚠️${NC}  $1 not found"
    ((WARNINGS++))
    return 1
  fi
}

# 1. Configuration Files
echo -e "${BLUE}📋 Configuration Files${NC}"
check_file "vitest.config.ts"
check_file ".github/workflows/test.yml"
check_file ".github/workflows/security-audit.yml"
check_file ".github/dependabot.yml"
check_file "SECURITY.md"
check_file ".vscode/settings.json"
check_file "scripts/test-report.ts"
check_file "scripts/security-metrics.ts"
echo ""

# 2. Required Commands
echo -e "${BLUE}🔧 Required Tools${NC}"
check_command "node"
check_command "npm"
check_command "npx"
echo ""

# 3. Node.js Version
echo -e "${BLUE}📦 Environment${NC}"
NODE_VERSION=$(node --version)
NPM_VERSION=$(npm --version)
echo -e "  ${GREEN}✅${NC} Node.js: $NODE_VERSION"
echo -e "  ${GREEN}✅${NC} npm: $NPM_VERSION"
echo ""

# 4. Dependencies
echo -e "${BLUE}📚 Key Dependencies${NC}"
DEPS=("vitest" "@vitest/ui" "@testing-library/react" "@testing-library/jest-dom" "typescript")
for dep in "${DEPS[@]}"; do
  if npm list "$dep" &> /dev/null; then
    VERSION=$(npm list "$dep" --depth=0 2>/dev/null | grep "$dep" | awk '{print $2}')
    echo -e "  ${GREEN}✅${NC} $dep $VERSION"
  else
    echo -e "  ${RED}❌${NC} $dep (NOT INSTALLED)"
    ((FAILURES++))
  fi
done
echo ""

# 5. npm Scripts
echo -e "${BLUE}🎯 npm Scripts${NC}"
SCRIPTS=("test:run" "test:coverage" "test:ci" "audit:check" "security:metrics")
for script in "${SCRIPTS[@]}"; do
  if npm run 2>&1 | grep -q "  $script"; then
    echo -e "  ${GREEN}✅${NC} npm run $script"
  else
    echo -e "  ${RED}❌${NC} npm run $script (MISSING)"
    ((FAILURES++))
  fi
done
echo ""

# 6. Test Execution
echo -e "${BLUE}🧪 Test Execution${NC}"
echo "  Running quick test..."
if npm run test:run &> /dev/null; then
  echo -e "  ${GREEN}✅${NC} Tests pass"
else
  echo -e "  ${RED}❌${NC} Tests fail"
  ((FAILURES++))
fi
echo ""

# 7. Coverage Check
echo -e "${BLUE}📊 Coverage${NC}"
if npm run test:coverage &> /dev/null; then
  if [ -f "coverage/coverage-summary.json" ]; then
    echo -e "  ${GREEN}✅${NC} Coverage report generated"
    # Extract coverage percentages (statements)
    STATEMENTS=$(cat coverage/coverage-summary.json | grep -o '"statements":{[^}]*}' | grep -o '"pct":[0-9.]*' | cut -d: -f2)
    echo -e "  ${GREEN}✅${NC} Statement coverage: ${STATEMENTS}%"
  else
    echo -e "  ${YELLOW}⚠️${NC}  Coverage report not found"
    ((WARNINGS++))
  fi
else
  echo -e "  ${RED}❌${NC} Coverage generation failed"
  ((FAILURES++))
fi
echo ""

# 8. Security Audit
echo -e "${BLUE}🔐 Security${NC}"
AUDIT_OUTPUT=$(npm audit --json 2>&1)
if echo "$AUDIT_OUTPUT" | grep -q '"vulnerabilities"'; then
  CRITICAL=$(echo "$AUDIT_OUTPUT" | grep -o '"critical":[0-9]*' | head -1 | cut -d: -f2)
  HIGH=$(echo "$AUDIT_OUTPUT" | grep -o '"high":[0-9]*' | head -1 | cut -d: -f2)
  if [ "$CRITICAL" = "0" ] && [ "$HIGH" = "0" ]; then
    echo -e "  ${GREEN}✅${NC} No critical or high vulnerabilities"
  else
    echo -e "  ${YELLOW}⚠️${NC}  Found $CRITICAL critical, $HIGH high vulnerabilities"
    ((WARNINGS++))
  fi
else
  echo -e "  ${GREEN}✅${NC} No vulnerabilities detected"
fi
echo ""

# 9. Git Status
echo -e "${BLUE}📝 Git Status${NC}"
if [ -d .git ]; then
  BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
  echo -e "  ${GREEN}✅${NC} Current branch: $BRANCH"
  UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l)
  if [ "$UNCOMMITTED" -gt 0 ]; then
    echo -e "  ${YELLOW}⚠️${NC}  $UNCOMMITTED uncommitted change(s)"
    ((WARNINGS++))
  else
    echo -e "  ${GREEN}✅${NC} Working directory clean"
  fi
else
  echo -e "  ${YELLOW}⚠️${NC}  Not a git repository"
  ((WARNINGS++))
fi
echo ""

# Summary
echo "================================"
echo -e "${BLUE}📋 Summary${NC}"
echo ""

if [ $FAILURES -eq 0 ] && [ $WARNINGS -eq 0 ]; then
  echo -e "${GREEN}🎉 All checks passed!${NC}"
  exit 0
elif [ $FAILURES -eq 0 ]; then
  echo -e "${YELLOW}⚠️  $WARNINGS warning(s) found${NC}"
  exit 0
else
  echo -e "${RED}❌ $FAILURES critical issue(s) found${NC}"
  echo -e "${YELLOW}⚠️  $WARNINGS warning(s) found${NC}"
  exit 1
fi
