#!/bin/bash
# save as: validate-implementation.sh

echo "🔍 Final Implementation Validation"
echo "===================================="
echo ""

# 1. File Structure Check
echo "📁 Checking file structure..."
files=(
  "vitest.config.ts:Vitest configuration"
  "vitest.setup.ts:Vitest setup file"
  ".github/workflows/test.yml:Test CI workflow"
  ".github/workflows/security-audit.yml:Security workflow"
  ".github/dependabot.yml:Dependabot config"
  "SECURITY.md:Security policy"
  ".vscode/settings.json:VSCode settings"
  "scripts/test-report.ts:Test reporter"
  "scripts/security-metrics.ts:Security metrics"
  "scripts/health-check.sh:Health checker"
)

for item in "${files[@]}"; do
  file="${item%%:*}"
  desc="${item##*:}"
  if [ -f "$file" ]; then
    echo "  ✅ $desc"
  else
    echo "  ❌ $desc - MISSING: $file"
  fi
done
echo ""

# 2. npm Scripts Check
echo "📦 Validating npm scripts..."
required=(
  "test:run"
  "test:coverage"
  "test:ci"
  "test:report"
  "coverage:check"
  "audit:check"
  "security:metrics"
)

for script in "${required[@]}"; do
  if npm run 2>&1 | grep -q "  $script"; then
    echo "  ✅ npm run $script"
  else
    echo "  ❌ npm run $script - MISSING"
  fi
done
echo ""

# 3. Quick Functionality Test
echo "🧪 Testing functionality..."

# Test execution
if npm run test:run > /dev/null 2>&1; then
  echo "  ✅ Tests execute successfully"
else
  echo "  ⚠️  Tests had failures (review output)"
fi

# Coverage generation
if npm run test:coverage > /dev/null 2>&1; then
  if [ -f "coverage/coverage-summary.json" ]; then
    echo "  ✅ Coverage reports generated"
  else
    echo "  ❌ Coverage report missing"
  fi
else
  echo "  ⚠️  Coverage generation issues"
fi

# Security audit
if npm audit --json > /dev/null 2>&1; then
  echo "  ✅ Security audit runs"
else
  echo "  ⚠️  Security audit issues"
fi

echo ""

# 4. GitHub Actions Check
echo "🤖 Checking GitHub Actions..."
if [ -d ".github/workflows" ]; then
  workflow_count=$(ls -1 .github/workflows/*.yml 2>/dev/null | wc -l)
  echo "  ✅ Found $workflow_count workflow(s)"
  ls -1 .github/workflows/*.yml | sed 's/^/    - /'
else
  echo "  ❌ .github/workflows directory missing"
fi
echo ""

# 5. Git Status
echo "📝 Git status..."
if [ -d .git ]; then
  BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
  echo "  ℹ️  Current branch: $BRANCH"
  
  UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l)
  if [ "$UNCOMMITTED" -eq 0 ]; then
    echo "  ✅ Working directory clean"
  else
    echo "  ⚠️  $UNCOMMITTED uncommitted file(s)"
  fi
else
  echo "  ⚠️  Not a git repository"
fi
echo ""

echo "===================================="
echo "✅ Validation Complete!"
echo ""
echo "Next steps:"
echo "  1. Review any warnings above"
echo "  2. Commit and push changes"
echo "  3. Monitor GitHub Actions"
echo "  4. Share with team"