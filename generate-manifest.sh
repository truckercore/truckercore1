#!/bin/bash

echo "📦 Infrastructure File Manifest"
echo "================================"
echo ""
echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

echo "📋 Configuration Files:"
echo "━━━━━━━━━━━━━━━━━━━━━━"
files=(
  "vitest.config.ts"
  "vitest.setup.ts"
  ".github/workflows/test.yml"
  ".github/workflows/security-audit.yml"
  ".github/dependabot.yml"
  ".vscode/settings.json"
  "SECURITY.md"
)

for file in "${files[@]}"; do
  if [ -f "$file" ]; then
    size=$(wc -c < "$file" 2>/dev/null | xargs)
    lines=$(wc -l < "$file" 2>/dev/null | xargs)
    echo "  ✅ $file"
    echo "     Size: ${size} bytes | Lines: ${lines}"
  else
    echo "  ❌ $file (MISSING)"
  fi
done

echo ""
echo "🔧 Scripts:"
echo "━━━━━━━━━━"
scripts=(
  "scripts/test-report.ts"
  "scripts/security-metrics.ts"
  "scripts/health-check.sh"
  "scripts/status-dashboard.sh"
  "validate-implementation.sh"
  "verify-setup.sh"
  "scripts/health-check.sh"
  "run-all-validations.sh"
)

for script in "${scripts[@]}"; do
  if [ -f "$script" ]; then
    size=$(wc -c < "$script" 2>/dev/null | xargs)
    lines=$(wc -l < "$script" 2>/dev/null | xargs)
    echo "  ✅ $script"
    echo "     Size: ${size} bytes | Lines: ${lines}"
  else
    echo "  ❌ $script (MISSING)"
  fi
done

echo ""
echo "📦 npm Scripts:"
echo "━━━━━━━━━━━━━━"
# List key scripts; if npm is not available, skip gracefully
if command -v npm >/dev/null 2>&1; then
  npm run 2>&1 | grep -E "(test:|coverage:|audit:|security:)" | sed 's/^/  /'
else
  echo "  (npm not installed)"
fi

echo ""
echo "📊 Summary:"
echo "━━━━━━━━━━"
config_count=$(ls -1 vitest.config.ts vitest.setup.ts .github/workflows/*.yml .github/dependabot.yml .vscode/settings.json SECURITY.md 2>/dev/null | wc -l)
script_count=$(ls -1 scripts/*.{ts,sh} *.sh 2>/dev/null | wc -l)
total=$((config_count + script_count))

echo "  Configuration files: $config_count"
echo "  Scripts: $script_count"
echo "  Total infrastructure files: $total"

echo ""
# Calculate total size (best-effort)
total_size=$(find . -maxdepth 2 -type f \
  \( -name "*.config.ts" -o -name "*.setup.ts" -o -name "*.yml" -o -name "SECURITY.md" -o -path "./.github/*" -o -path "./scripts/*" -o -name "*-check.sh" -o -name "*-validation.sh" \) 2>/dev/null -exec wc -c {} + | tail -1 | awk '{print $1}')

if [ -n "$total_size" ]; then
  echo "  Total size: $total_size bytes (~$((total_size / 1024)) KB)"
fi

echo ""
echo "✅ Manifest generation complete"
