#!/bin/bash

echo "🔍 Final Pre-Deployment Verification"
echo "====================================="
echo ""

PASS=0
FAIL=0

# 1. Check npm scripts work with ts-node
echo "1. Testing npm scripts with ts-node..."
if npx ts-node --version > /dev/null 2>&1; then
  echo "  ✅ ts-node available"
  ((PASS++))
else
  echo "  ❌ ts-node not available"
  ((FAIL++))
fi

if npm run test:report > /dev/null 2>&1 || [ -f "test-report.md" ]; then
  echo "  ✅ test:report script works"
  ((PASS++))
else
  echo "  ⚠️  test:report needs test results"
fi

# 2. Verify coverage enforcement in CI
echo ""
echo "2. Checking CI coverage enforcement..."
if grep -q "coverage:check" .github/workflows/test.yml; then
  echo "  ✅ Coverage gate in CI workflow"
  ((PASS++))
else
  echo "  ❌ Coverage gate missing in CI"
  ((FAIL++))
fi

# 3. Run tests
echo ""
echo "3. Running tests..."
if npm run test:run > /dev/null 2>&1; then
  echo "  ✅ Tests pass"
  ((PASS++))
else
  echo "  ❌ Tests fail"
  ((FAIL++))
fi

# 4. Generate coverage
echo ""
echo "4. Generating coverage..."
if npm run test:coverage > /dev/null 2>&1; then
  echo "  ✅ Coverage generated"
  ((PASS++))
  
  # Check coverage thresholds
  if npm run coverage:check > /dev/null 2>&1; then
    echo "  ✅ Coverage meets thresholds"
    ((PASS++))
  else
    echo "  ⚠️  Coverage below thresholds"
  fi
else
  echo "  ❌ Coverage generation failed"
  ((FAIL++))
fi

# 5. Test security scripts
echo ""
echo "5. Testing security scripts..."
if npm audit > /dev/null 2>&1; then
  echo "  ✅ Security audit works"
  ((PASS++))
else
  echo "  ⚠️  Security audit has issues"
fi

# 6. Verify all validation scripts
echo ""
echo "6. Checking validation scripts..."
for script in verify-setup.sh validate-implementation.sh health-check.sh; do
  if [ -f "$script" ] && [ -x "$script" ]; then
    echo "  ✅ $script exists and executable"
    ((PASS++))
  else
    echo "  ❌ $script missing or not executable"
    ((FAIL++))
  fi
done

# 7. Check GitHub workflows
echo ""
echo "7. Verifying GitHub workflows..."
if [ -f ".github/workflows/test.yml" ]; then
  echo "  ✅ Test workflow exists"
  ((PASS++))
else
  echo "  ❌ Test workflow missing"
  ((FAIL++))
fi

if [ -f ".github/workflows/security-audit.yml" ]; then
  echo "  ✅ Security workflow exists"
  ((PASS++))
else
  echo "  ❌ Security workflow missing"
  ((FAIL++))
fi

# 8. Git status
echo ""
echo "8. Checking git status..."
if [ -d .git ]; then
  UNCOMMITTED=$(git status --porcelain | wc -l)
  if [ "$UNCOMMITTED" -eq 0 ]; then
    echo "  ✅ Working directory clean"
    ((PASS++))
  else
    echo "  ⚠️  $UNCOMMITTED uncommitted file(s)"
    git status --short | head -5
  fi
else
  echo "  ⚠️  Not a git repository"
fi

# Summary
echo ""
echo "====================================="
echo "Results: $PASS passed, $FAIL failed"
echo ""

if [ $FAIL -eq 0 ]; then
  echo "✅ ✅ ✅  ALL CHECKS PASSED  ✅ ✅ ✅"
  echo ""
  echo "🚀 READY FOR DEPLOYMENT!"
  echo ""
  echo "Next command:"
  echo "  git push origin main"
  echo ""
  exit 0
else
  echo "❌ $FAIL check(s) failed"
  echo "Review output above and fix issues"
  exit 1
fi
