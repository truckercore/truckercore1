#!/bin/bash
# TruckerCore Production Deployment Script
# Usage: ./deploy.sh [--skip-tests] [--force]

set -e  # Exit on error

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parse arguments
SKIP_TESTS=false
FORCE=false

for arg in "$@"; do
  case $arg in
    --skip-tests)
      SKIP_TESTS=true
      shift
      ;;
    --force)
      FORCE=true
      shift
      ;;
    --help)
      echo "Usage: ./deploy.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --skip-tests    Skip test suite (faster, but risky)"
      echo "  --force         Skip confirmation prompts"
      echo "  --help          Show this help message"
      exit 0
      ;;
  esac
done

echo -e "${BLUE}"
cat << "EOF"
╔════════════════════════════════════════╗
║   TruckerCore Production Deployment    ║
╚════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Confirmation
if [ "$FORCE" = false ]; then
  echo -e "${YELLOW}⚠️  You are about to deploy to PRODUCTION${NC}"
  echo ""
  read -p "Are you sure you want to continue? (yes/no): " confirm
  if [ "$confirm" != "yes" ]; then
    echo "Deployment cancelled."
    exit 0
  fi
  echo ""
fi

# Step 1: Pre-flight checks
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 1/12: Pre-flight Checks${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

bash scripts/deployment-status.sh || {
  echo -e "${RED}❌ Pre-flight checks failed${NC}"
  exit 1
}

# Step 2: DNS Verification
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 2/13: DNS Verification${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if ! npm run dns:check; then
  echo -e "${YELLOW}⚠️ DNS not fully configured${NC}"
  if [ "$FORCE" = false ]; then
    read -p "Continue anyway? (yes/no): " dns_confirm
    if [ "$dns_confirm" != "yes" ]; then
      echo "Deployment cancelled. Fix DNS first."
      echo "Run: npm run dns:guide"
      exit 1
    fi
  fi
fi

# Step 2: Git status check
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 2/12: Git Status Check${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ -n "$(git status --porcelain)" ]; then
  echo -e "${YELLOW}⚠️  You have uncommitted changes${NC}"
  git status --short
  echo ""
  if [ "$FORCE" = false ]; then
    read -p "Commit these changes before deploying? (yes/no): " commit_confirm
    if [ "$commit_confirm" = "yes" ]; then
      git add -A
      read -p "Commit message: " commit_msg
      git commit -m "$commit_msg"
    fi
  fi
else
  echo -e "${GREEN}✅ Working directory clean${NC}"
fi

# Step 3: Branch check
CURRENT_BRANCH=$(git branch --show-current)
echo ""
echo "Current branch: $CURRENT_BRANCH"

if [ "$CURRENT_BRANCH" != "main" ] && [ "$FORCE" = false ]; then
  echo -e "${YELLOW}⚠️  You're not on 'main' branch${NC}"
  read -p "Deploy from '$CURRENT_BRANCH' anyway? (yes/no): " branch_confirm
  if [ "$branch_confirm" != "yes" ]; then
    echo "Deployment cancelled. Switch to 'main' branch first."
    exit 0
  fi
fi

# Step 4: Dependencies check
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 3/12: Dependencies${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ ! -d "node_modules" ]; then
  echo "Installing dependencies..."
  npm install
else
  echo -e "${GREEN}✅ Dependencies already installed${NC}"
fi

# Step 5: Clean build
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 4/12: Clean Build${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

rm -rf .next node_modules/.cache
echo "Building production bundle..."
npm run build || {
  echo -e "${RED}❌ Build failed${NC}"
  exit 1
}

# Step 6: SEO validation
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 5/12: SEO Validation${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

npm run validate:seo || {
  echo -e "${RED}❌ SEO validation failed${NC}"
  exit 1
}

# Step 7: TypeScript check
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 6/12: TypeScript Check${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

npm run typecheck || {
  echo -e "${RED}❌ TypeScript errors found${NC}"
  exit 1
}

# Step 8: Test suite
if [ "$SKIP_TESTS" = false ]; then
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Step 7/12: Test Suite${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  
  npm run test:unit || {
    echo -e "${YELLOW}⚠️  Some tests failed${NC}"
    if [ "$FORCE" = false ]; then
      read -p "Continue deployment anyway? (yes/no): " test_confirm
      if [ "$test_confirm" != "yes" ]; then
        echo "Deployment cancelled."
        exit 1
      fi
    fi
  }
else
  echo -e "${YELLOW}⚠️  Skipping tests (--skip-tests flag)${NC}"
fi

# Step 9: Local route testing
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 8/12: Local Route Testing${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo "Starting production server..."
npm run start > /dev/null 2>&1 &
SERVER_PID=$!
sleep 5

bash scripts/test-local-routes.sh || {
  kill $SERVER_PID 2>/dev/null
  echo -e "${RED}❌ Route tests failed${NC}"
  exit 1
}

kill $SERVER_PID 2>/dev/null
echo -e "${GREEN}✅ All routes working${NC}"

# Step 10: Git push
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 9/12: Push to Repository${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ -n "$(git log @{u}.. 2>/dev/null)" ]; then
  echo "Pushing to remote..."
  git push origin "$CURRENT_BRANCH" || {
    echo -e "${RED}❌ Git push failed${NC}"
    exit 1
  }
else
  echo -e "${GREEN}✅ Already up to date with remote${NC}"
fi

# Step 11: Deploy Supabase functions
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 10/12: Deploy Supabase Functions${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if command -v supabase &> /dev/null; then
  echo "Deploying health function..."
  supabase functions deploy health || echo -e "${YELLOW}⚠️  Health function deployment failed (non-critical)${NC}"
  
  echo "Deploying refresh-safety-summary function..."
  supabase functions deploy refresh-safety-summary || echo -e "${YELLOW}⚠️  Refresh function deployment failed (non-critical)${NC}"
else
  echo -e "${YELLOW}⚠️  Supabase CLI not found, skipping function deployment${NC}"
fi

# Step 12: Wait for Vercel deployment
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 11/12: Wait for Vercel Deployment${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo "Waiting for Vercel to deploy..."
echo "(This usually takes 60-90 seconds)"

for i in {1..90}; do
  echo -n "."
  sleep 1
done
echo ""

# Step 13: Verify production
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 12/12: Verify Production${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

bash scripts/verify-production.sh || {
  echo -e "${RED}❌ Production verification failed${NC}"
  echo ""
  echo "Deployment completed but verification failed."
  echo "Check https://vercel.com for deployment status"
  exit 1
}

# Success!
echo ""
echo -e "${GREEN}"
cat << "EOF"
╔════════════════════════════════════════╗
║     ✅ DEPLOYMENT SUCCESSFUL! 🎉       ║
╚════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo "Production URL: https://truckercore.com"
echo "App URL: https://app.truckercore.com"
echo "API Health: https://api.truckercore.com/health"
echo ""
echo "Next steps:"
echo "1. Monitor logs: vercel --logs --follow"
echo "2. Run Lighthouse: lighthouse https://truckercore.com --view"
echo "3. Check Sentry: https://sentry.io"
echo "4. Setup monitoring: bash scripts/setup-monitoring.sh"
echo ""
echo "Deployment completed at: $(date)"