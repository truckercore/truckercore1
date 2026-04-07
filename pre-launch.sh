#!/bin/bash
# TruckerCore Pre-Launch Sequence
set -e

echo "🚀 TruckerCore Pre-Launch Sequence"
echo "==================================="
echo ""

# Step 1: Status check
echo "1/8: Checking deployment status..."
npm run check:status || exit 1

# Step 2: Asset verification
echo ""
echo "2/8: Verifying assets..."
if ! npm run assets:check; then
  echo "⚠️  Some assets need attention (see above)"
  read -p "Continue anyway? (yes/no): " cont
  [ "$cont" != "yes" ] && exit 1
fi

# Step 3: Pre-deploy tests
echo ""
echo "3/8: Running pre-deploy tests..."
npm run test:predeploy || exit 1

# Step 4: Build validation
echo ""
echo "4/8: Validating build..."
npm run validate:build || exit 1

# Step 5: Environment variables
echo ""
echo "5/8: Checking environment variables..."
if ! vercel env ls production | grep -q NEXT_PUBLIC_SUPABASE_URL; then
  echo "❌ Missing environment variables"
  echo "Run: vercel env add NEXT_PUBLIC_SUPABASE_URL production"
  exit 1
fi

# Step 6: Domain configuration
echo ""
echo "6/8: Checking domain configuration..."
if ! vercel domains ls | grep -q truckercore.com; then
  echo "⚠️  Domain not configured in Vercel"
  echo "Run: vercel domains add truckercore.com"
fi

# Step 7: Supabase functions
echo ""
echo "7/8: Checking Supabase functions..."
if command -v supabase >/dev/null 2>&1; then
  if ! supabase functions list | grep -q health; then
    echo "⚠️  Health function not deployed"
    echo "Run: supabase functions deploy health"
  fi
else
  echo "⚠️  Supabase CLI not installed; skipping function checks"
fi

# Step 8: Final confirmation
echo ""
echo "8/8: Final checks complete!"
echo ""
echo "✅ Ready to deploy to production"
echo ""
echo "Next steps:"
echo "1. npm run deploy"
echo "2. npm run check:production"
echo "3. npm run monitor"
echo ""
read -p "Deploy now? (yes/no): " deploy_now

if [ "$deploy_now" = "yes" ]; then
  npm run deploy
else
  echo "Deployment postponed. Run 'npm run deploy' when ready."
fi
