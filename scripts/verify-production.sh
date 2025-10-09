#!/bin/bash
# Comprehensive production verification

DOMAIN=${DOMAIN:-"https://truckercore.com"}
echo "🚀 Verifying Production Deployment: $DOMAIN"
echo "================================================"
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

total_checks=0
passed_checks=0

check_url() {
  local url=$1
  local expected=$2
  local description=$3
  
  ((total_checks++))
  status=$(curl -s -o /dev/null -w "%{http_code}" -L "$url")
  
  if [ "$status" -eq "$expected" ]; then
    echo -e "${GREEN}✅${NC} $description ($status)"
    ((passed_checks++))
  else
    echo -e "${RED}❌${NC} $description (got $status, expected $expected)"
  fi
}

check_header() {
  local url=$1
  local header=$2
  local description=$3
  
  ((total_checks++))
  value=$(curl -sI "$url" | grep -i "^$header:" | cut -d' ' -f2-)
  
  if [ -n "$value" ]; then
    echo -e "${GREEN}✅${NC} $description: $value"
    ((passed_checks++))
  else
    echo -e "${RED}❌${NC} $description: Header missing"
  fi
}

# Test pages
echo "📄 Testing Pages..."
check_url "$DOMAIN/" 200 "Homepage"
check_url "$DOMAIN/about" 200 "About page"
check_url "$DOMAIN/privacy" 200 "Privacy page"
check_url "$DOMAIN/terms" 200 "Terms page"
check_url "$DOMAIN/contact" 200 "Contact page"
check_url "$DOMAIN/docs" 200 "Docs page"
check_url "$DOMAIN/downloads" 200 "Downloads page"
check_url "$DOMAIN/nonexistent" 404 "404 page"

echo ""
echo "🖼️  Testing Assets..."
check_url "$DOMAIN/favicon.ico" 200 "Favicon"
check_url "$DOMAIN/logo.svg" 200 "Logo"
check_url "$DOMAIN/manifest.json" 200 "Manifest"
check_url "$DOMAIN/robots.txt" 200 "Robots.txt"
check_url "$DOMAIN/sitemap.xml" 200 "Sitemap"

echo ""
echo "🔒 Testing Security Headers..."
check_header "$DOMAIN/" "X-Frame-Options" "X-Frame-Options"
check_header "$DOMAIN/" "X-Content-Type-Options" "X-Content-Type-Options"
check_header "$DOMAIN/" "Referrer-Policy" "Referrer-Policy"

echo ""
echo "⚡ Testing Performance..."
load_time=$(curl -o /dev/null -s -w "%{time_total}" "$DOMAIN/")
load_time_ms=$(echo "$load_time * 1000" | bc)
((total_checks++))
if (( $(echo "$load_time < 2" | bc -l) )); then
  echo -e "${GREEN}✅${NC} Page load time: ${load_time_ms}ms (< 2000ms)"
  ((passed_checks++))
else
  echo -e "${YELLOW}⚠️${NC} Page load time: ${load_time_ms}ms (> 2000ms)"
fi

echo ""
echo "🔍 Testing SEO..."
((total_checks++))
if curl -s "$DOMAIN/" | grep -q "<title>TruckerCore"; then
  echo -e "${GREEN}✅${NC} Title tag present"
  ((passed_checks++))
else
  echo -e "${RED}❌${NC} Title tag missing"
fi

((total_checks++))
if curl -s "$DOMAIN/" | grep -q 'name="description"'; then
  echo -e "${GREEN}✅${NC} Meta description present"
  ((passed_checks++))
else
  echo -e "${RED}❌${NC} Meta description missing"
fi

((total_checks++))
if curl -s "$DOMAIN/" | grep -q 'property="og:'; then
  echo -e "${GREEN}✅${NC} Open Graph tags present"
  ((passed_checks++))
else
  echo -e "${RED}❌${NC} Open Graph tags missing"
fi

echo ""
echo "================================================"
echo -e "Results: ${passed_checks}/${total_checks} checks passed"

if [ "$passed_checks" -eq "$total_checks" ]; then
  echo -e "${GREEN}✅ All checks passed! Production is healthy.${NC}"
  exit 0
else
  failed=$((total_checks - passed_checks))
  echo -e "${RED}❌ ${failed} check(s) failed. Review issues above.${NC}"
  exit 1
fi
