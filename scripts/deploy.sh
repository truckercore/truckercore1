#!/bin/bash

set -e

echo "🚀 Fleet Manager Deployment Script"
echo "===================================="
echo ""

# Check environment
if [ -z "$1" ]; then
  echo "Usage: ./scripts/deploy.sh [development|staging|production]"
  exit 1
fi

ENVIRONMENT=$1
echo "📦 Deploying to: $ENVIRONMENT"
echo ""

# Load environment variables
if [ -f ".env.$ENVIRONMENT" ]; then
  set -a
  # shellcheck disable=SC2046
  export $(cat .env.$ENVIRONMENT | xargs)
  set +a
  echo "✅ Loaded environment variables"
else
  echo "❌ .env.$ENVIRONMENT file not found"
  exit 1
fi

# Run tests
echo ""
echo "🧪 Running tests..."
npm run test:ci || {
  echo "❌ Tests failed"
  exit 1
}
echo "✅ Tests passed"

# Run build
echo ""
echo "🔨 Building application..."
npm run build || {
  echo "❌ Build failed"
  exit 1
}
echo "✅ Build successful"

# Database migrations
echo ""
echo "🗄️  Running database migrations..."
if [ "$USE_MOCK_DATA" != "true" ]; then
  if command -v npx >/dev/null 2>&1; then
    npx supabase db push || {
      echo "❌ Database migrations failed"
      exit 1
    }
  else
    echo "⚠️  npx not found; skipping migrations"
  fi
  echo "✅ Database migrations complete"
else
  echo "ℹ️  Skipping migrations (using mock data)"
fi

# Deploy to Vercel/your hosting platform
echo ""
echo "🌐 Deploying to hosting platform..."

if [ "$ENVIRONMENT" = "production" ]; then
  vercel --prod
elif [ "$ENVIRONMENT" = "staging" ]; then
  vercel --scope staging
else
  vercel
fi

echo ""
echo "✅ Deployment complete!"
echo ""
echo "🎉 Application deployed to $ENVIRONMENT"
echo "📝 View logs: vercel logs"
echo "🌐 Visit: $NEXT_PUBLIC_APP_URL"
