#!/bin/bash
# Wrapper script: Pre-Production Asset Checklist
# Delegates to the detailed asset checker if present.

if [ -f "scripts/preprod-asset-check.sh" ]; then
  bash scripts/preprod-asset-check.sh
  exit $?
fi

# Fallback: inline minimal checks
echo "🎨 Pre-Production Asset Checklist (fallback)"
required=(
  "public/favicon.ico"
  "public/logo.svg"
  "public/icon-192.png"
  "public/icon-512.png"
  "public/apple-touch-icon.png"
  "public/og-image.png"
)

issues=0
for f in "${required[@]}"; do
  if [ -f "$f" ]; then
    echo "✅ $f"
  else
    echo "❌ $f - MISSING"
    ((issues++))
  fi
done

if [ $issues -gt 0 ]; then
  echo "\n⚠️  $issues asset(s) missing. Please add real brand assets before launch."
  exit 1
else
  echo "\n✅ All assets ready for production!"
  exit 0
fi
