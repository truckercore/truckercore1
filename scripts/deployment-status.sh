#!/bin/bash
# Check deployment readiness status

echo "📋 TruckerCore Deployment Status Check"
echo "======================================="
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

total=0
ready=0

check_file() {
  local file=$1
  local description=$2
  ((total++))
  
  if [ -f "$file" ]; then
    echo -e "${GREEN}✅${NC} $description"
    ((ready++))
    return 0
  else
    echo -e "${RED}❌${NC} $description - Missing: $file"
    return 1
  fi
}

check_command() {
  local cmd=$1
  local description=$2
  ((total++))
  
  if command -v "$cmd" &> /dev/null; then
    echo -e "${GREEN}✅${NC} $description"
    ((ready++))
    return 0
  else
    echo -e "${RED}❌${NC} $description - Install: $cmd"
    return 1
  fi
}

echo "Configuration Files:"
check_file "next.config.js" "Next.js config"
check_file "vercel.json" "Vercel config"
check_file "package.json" "Package.json"
check_file "tsconfig.json" "TypeScript config"

echo ""
echo "Router Setup:"
check_file "pages/_app.tsx" "Pages Router _app"
check_file "pages/_document.tsx" "Pages Router _document"
check_file "pages/index.tsx" "Homepage"

echo ""
echo "Public Assets:"
check_file "public/favicon.ico" "Favicon"
check_file "public/logo.svg" "Logo"
check_file "public/manifest.json" "Manifest"
check_file "public/robots.txt" "Robots.txt"
check_file "public/sitemap.xml" "Sitemap"

echo ""
echo "Scripts:"
check_file "scripts/debug-vercel-404.sh" "Debug script"
check_file "scripts/validate-seo.js" "SEO validation"
check_file "scripts/test-local-routes.sh" "Route testing"
check_file "scripts/verify-production.sh" "Production verification"

echo ""
echo "Required Tools:"
check_command "node" "Node.js"
check_command "npm" "NPM"
check_command "git" "Git"
check_command "vercel" "Vercel CLI"
check_command "supabase" "Supabase CLI"

echo ""
echo "======================================="

if [ "$ready" -eq "$total" ]; then
  echo -e "${GREEN}✅ All systems ready! ($ready/$total)${NC}"
  echo ""
  echo "You can now run:"
  echo "  ./deploy.sh"
  exit 0
else
  missing=$((total - ready))
  echo -e "${RED}⚠️  Not ready: $missing item(s) missing${NC}"
  echo ""
  echo "Fix the issues above, then run this script again."
  exit 1
fi
