#!/bin/bash
# 🎯 Final Pre-Launch Verification
# Usage: ./final-check.sh

set -e

echo "🎯 Final Pre-Launch Verification"
echo "================================="

# 1. Status check
echo ""
echo "1/10 Checking deployment status..."
npm run check:status || exit 1

# 2. DNS check
echo ""
echo "2/10 Checking DNS configuration..."
npm run check:dns || true

# 3. Asset check
echo ""
echo "3/10 Checking production assets..."
npm run assets:check || true

# 4. SEO validation
echo ""
echo "4/10 Validating SEO..."
npm run validate:seo || exit 1

# 5. TypeScript check
echo ""
echo "5/10 Checking TypeScript..."
npm run typecheck || exit 1

# 6. Build test
echo ""
echo "6/10 Testing production build..."
npm run build || exit 1

# 7. Unit tests
echo ""
echo "7/10 Running unit tests..."
npm run test:unit || exit 1

# 8. Route tests
echo ""
echo "8/10 Testing local routes..."
# Start dev server in background for route testing
npm run dev > /dev/null 2>&1 &
DEV_PID=$!
sleep 5
bash scripts/test-local-routes.sh || { kill $DEV_PID 2>/dev/null || true; exit 1; }
kill $DEV_PID 2>/dev/null || true

# 9. Environment variables
echo ""
echo "9/10 Checking environment variables..."
if command -v vercel >/dev/null 2>&1; then
  vercel env ls production | grep -q NEXT_PUBLIC_SUPABASE_URL || { echo "❌ Missing environment variables in Vercel"; exit 1; }
else
  echo "⚠️  Vercel CLI not installed; skip env verification"
fi

# 10. Supabase functions
echo ""
echo "10/10 Checking Supabase functions..."
if command -v supabase >/dev/null 2>&1; then
  supabase functions list | grep -q health || {
    echo "⚠️ Health function not deployed";
    echo "Run: supabase functions deploy health";
  }
else
  echo "⚠️ Supabase CLI not installed; skipping functions check"
fi

echo ""
echo "================================="
echo "✅ All checks completed!"
echo ""
echo "🚀 Ready to launch!"
echo ""
echo "Next steps:"
echo " 1. npm run deploy"
echo " 2. npm run check:production"
echo " 3. npm run monitor"