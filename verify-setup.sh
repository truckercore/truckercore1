#!/bin/bash
set -e

echo "🔍 Verifying Infrastructure Setup..."
echo "=================================="
echo ""

# Check configuration files
echo "📋 Checking configuration files..."
files=(
  "vitest.config.ts"
  ".github/workflows/test.yml"
  ".github/workflows/security-audit.yml"
  ".github/dependabot.yml"
  "SECURITY.md"
  ".vscode/settings.json"
  "scripts/test-report.ts"
  "scripts/security-metrics.ts"
)

for file in "${files[@]}"; do
  if [ -f "$file" ]; then
    echo "  ✅ $file"
  else
    echo "  ❌ $file (MISSING)"
  fi
done
echo ""

# Check package.json scripts
echo "📦 Checking npm scripts..."
required_scripts=(
  "test"
  "test:run"
  "test:coverage"
  "test:ci"
  "test:report"
  "audit"
  "audit:check"
  "security:metrics"
)

for script in "${required_scripts[@]}"; do
  if npm run | grep -q "  $script"; then
    echo "  ✅ npm run $script"
  else
    echo "  ❌ npm run $script (MISSING)"
  fi
done
echo ""

# Verify dependencies
echo "📚 Checking dependencies..."
deps=("vitest" "@vitest/ui" "@testing-library/react" "@testing-library/jest-dom")
for dep in "${deps[@]}"; do
  if npm list "$dep" &> /dev/null; then
    echo "  ✅ $dep"
  else
    echo "  ⚠️  $dep (not installed)"
  fi
done
echo ""

# Check Node.js version
echo "🔧 Environment info..."
echo "  Node.js: $(node --version)"
echo "  npm: $(npm --version)"
echo ""

echo "✅ Verification complete!"