#!/bin/bash
# Verify all TruckerCore domains return correct status codes

echo "🔍 Verifying TruckerCore domains..."
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

function check_url() {
  local url=$1
  local expected=$2
  local status=$(curl -s -o /dev/null -w "%{http_code}" -L "$url")
  
  if [ "$status" -eq "$expected" ]; then
    echo -e "${GREEN}✓${NC} $url → $status"
  else
    echo -e "${RED}✗${NC} $url → $status (expected $expected)"
  fi
}

echo "Main domains:"
check_url "https://truckercore.com" 200
check_url "https://app.truckercore.com" 200
echo ""

echo "API endpoints:"
check_url "https://api.truckercore.com/health" 200
check_url "https://api.truckercore.com/" 404  # Expected: no root route
echo ""

echo "Downloads:"
check_url "https://downloads.truckercore.com" 200  # If landing page exists
# check_url "https://downloads.truckercore.com/storage/v1/object/public/downloads/TruckerCore.appinstaller" 200
echo ""

echo "Static pages:"
check_url "https://truckercore.com/about" 200
check_url "https://truckercore.com/privacy" 200
check_url "https://truckercore.com/terms" 200
check_url "https://truckercore.com/contact" 200
check_url "https://truckercore.com/downloads" 200
echo ""

echo "404 handling:"
check_url "https://truckercore.com/nonexistent-page" 404
echo ""

echo -e "${YELLOW}Note:${NC} api.truckercore.com root is expected to 404 (Edge Functions have no root route)"
echo -e "${YELLOW}Note:${NC} downloads.truckercore.com root may 404 unless landing page is deployed"
echo ""
echo "✅ Verification complete!"
