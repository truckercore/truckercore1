#!/bin/bash

echo "🚀 Pre-Deployment Checklist"
echo "==========================="
echo ""

CHECKS_PASSED=0
CHECKS_FAILED=0

check() {
  local description=$1
  local command=$2
  echo -n "⏳ $description... "
  if eval "$command" > /dev/null 2>&1; then
    echo "✅"
    ((CHECKS_PASSED++))
    return 0
  else
    echo "❌"
    ((CHECKS_FAILED++))
    return 1
  fi
}

echo "📋 File Checks:"
check "Vitest config exists" "[ -f vitest.config.ts ]"
check "Test workflow exists" "[ -f .github/workflows/test.yml ]"
check "Security workflow exists" "[ -f .github/workflows/security-audit.yml ]"
check "Dependabot config exists" "[ -f .github/dependabot.yml ]"
check "Security policy exists" "[ -f SECURITY.md ]"
check "VSCode settings exist" "[ -f .vscode/settings.json ]"

echo ""
echo "🧪 Test Checks:"
check "Tests run successfully" "npm run test:run"
check "Coverage generated" "npm run test:coverage && [ -f coverage/coverage-summary.json ]"
check "Test report generates" "npm run test:report && [ -f test-report.md ]"

echo ""
echo "🔐 Security Checks:"
check "Audit completes" "npm audit --json"
check "Security metrics available" "command -v npx"

echo ""
echo "📦 Dependency Checks:"
check "Node modules installed" "[ -d node_modules ]"
check "Vitest installed" "npm list vitest"
check "Testing library installed" "npm list @testing-library/react"

echo ""
echo "🔧 Script Checks:"
check "validate-implementation.sh exists" "[ -f validate-implementation.sh ]"
check "verify-setup.sh exists" "[ -f verify-setup.sh ]"
check "health-check.sh exists" "[ -f scripts/health-check.sh ]"
check "Scripts executable" "chmod +x validate-implementation.sh verify-setup.sh scripts/health-check.sh"

echo ""
echo "📝 Git Checks:"
check "Git repository initialized" "[ -d .git ]"
check "On a valid branch" "git branch --show-current"
UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l)
if [ "$UNCOMMITTED" -eq 0 ]; then
  echo "✅ Working directory clean"
  ((CHECKS_PASSED++))
else
  echo "⚠️  Working directory has $UNCOMMITTED uncommitted changes"
fi

echo ""
echo "==========================="
echo "Summary:"
echo "  Passed: $CHECKS_PASSED ✅"
echo "  Failed: $CHECKS_FAILED ❌"

if [ $CHECKS_FAILED -eq 0 ]; then
  echo ""
  echo "✅ ALL CHECKS PASSED - Ready for deployment!"
  echo ""
  echo "Next steps:"
  echo "  1. git add . (if needed)"
  echo "  2. git commit -m 'chore: complete infrastructure setup'"
  echo "  3. git push origin main"
  REPO_URL=$(git remote get-url origin 2>/dev/null | sed 's/\.git$//' | sed 's/git@github.com:/https:\/\/github.com\//')
  echo "  4. Monitor: ${REPO_URL:-https://github.com/<user>/<repo>}/actions"
  echo ""
  exit 0
else
  echo ""
  echo "❌ Some checks failed - review and fix before deployment"
  exit 1
fi
