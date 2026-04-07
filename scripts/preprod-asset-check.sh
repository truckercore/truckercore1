#!/bin/bash
# Pre-production asset verification

echo "🎨 Pre-Production Asset Checklist"
echo "=================================="
echo ""

# Check file sizes (placeholders are typically small)
echo "Checking asset file sizes..."
echo ""

check_asset() {
  local file=$1
  local min_size=$2
  
  if [ -f "$file" ]; then
    size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
    if [ "$size" -lt "$min_size" ]; then
      echo "⚠️  $file is only ${size} bytes (likely placeholder)"
      return 1
    else
      echo "✅ $file (${size} bytes)"
      return 0
    fi
  else
    echo "❌ $file - MISSING"
    return 1
  fi
}

issues=0

check_asset "public/favicon.ico" 1000 || ((issues++))
check_asset "public/logo.svg" 500 || ((issues++))
check_asset "public/icon-192.png" 5000 || ((issues++))
check_asset "public/icon-512.png" 15000 || ((issues++))
check_asset "public/apple-touch-icon.png" 8000 || ((issues++))
check_asset "public/og-image.png" 20000 || ((issues++))

echo ""
echo "=================================="

if [ $issues -gt 0 ]; then
  echo "⚠️  Found $issues placeholder asset(s)"
  echo ""
  echo "Action required before production launch:"
  echo "1. Create professional logo (recommend Figma or Adobe Illustrator)"
  echo "2. Generate icons using https://realfavicongenerator.net/"
  echo "3. Create OG image (1200x630px) for social sharing"
  echo "4. Re-run this script to verify"
  exit 1
else
  echo "✅ All assets ready for production!"
  exit 0
fi
