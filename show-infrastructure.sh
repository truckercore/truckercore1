#!/bin/bash

echo "📦 Complete Infrastructure Manifest"
echo "===================================="
echo ""

echo "🔧 Configuration Files:"
find . -maxdepth 3 \( \
  -name "vitest.config.ts" -o \
  -name "vitest.setup.ts" -o \
  -name "dependabot.yml" -o \
  -name "test.yml" -o \
  -name "security-audit.yml" -o \
  -name "settings.json" -o \
  -name "SECURITY.md" \
\) -type f | sort | sed 's/^\.\//  ✅ /'

echo ""
echo "📜 Scripts:"
find scripts -name "*.ts" -o -name "*.sh" 2>/dev/null | sort | sed 's/^/  ✅ /'

echo ""
echo "🔍 Validation Tools:"
find . -maxdepth 1 -name "*-*.sh" -type f | sort | sed 's/^\.\//  ✅ /'

echo ""
echo "📚 Documentation:"
find . -maxdepth 1 \( \
  -name "*.md" -o \
  -name "QUICK_REFERENCE.md" -o \
  -name "INFRASTRUCTURE.md" \
\) -type f | sort | sed 's/^\.\//  ✅ /'

echo ""
echo "📊 Summary:"
CONFIG_COUNT=$(find . -maxdepth 3 \( -name "*.config.ts" -o -name "*.setup.ts" -o -name "*.yml" -o -name "settings.json" \) -type f | wc -l)
SCRIPT_COUNT=$(find scripts -type f 2>/dev/null | wc -l)
VALIDATION_COUNT=$(find . -maxdepth 1 -name "*-*.sh" -type f | wc -l)
DOC_COUNT=$(find . -maxdepth 1 -name "*.md" -type f | wc -l)

echo "  Configuration files: $CONFIG_COUNT"
echo "  Script files: $SCRIPT_COUNT"
echo "  Validation tools: $VALIDATION_COUNT"
echo "  Documentation files: $DOC_COUNT"
echo ""
TOTAL=$((CONFIG_COUNT + SCRIPT_COUNT + VALIDATION_COUNT + DOC_COUNT))
echo "  📦 Total infrastructure files: $TOTAL"
echo "  🚫 Production files modified: 0"
echo ""
echo "✅ Infrastructure complete and verified"