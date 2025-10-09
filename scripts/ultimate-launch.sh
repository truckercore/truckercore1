#!/bin/bash
# TruckerCore Ultimate Launch Script
# Orchestrates full preflight + deploy + verify + celebration
set -euo pipefail

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}"
cat << "EOF"
╔════════════════════════════════════════════════════════╗
║            🚀 TruckerCore Ultimate Launch 🚀           ║
╚════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Stage 1: Preflight
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Stage 1/3: Preflight checks${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Comprehensive final preflight (aggregates checks)
if npm run deploy:preflight; then
  echo -e "${GREEN}✅ Preflight passed${NC}"
else
  echo -e "${YELLOW}⚠️ Preflight reported issues${NC}"
  read -p "Continue anyway? (yes/no): " cont
  if [ "$cont" != "yes" ]; then
    echo "Launch aborted. Fix issues and retry."
    exit 1
  fi
fi

# Stage 2: Deploy
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Stage 2/3: Deploy to production${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

npm run deploy

# Stage 3: Verify + Celebrate
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Stage 3/3: Verify production${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

npm run check:production || true

# Celebration
bash scripts/ship-celebration.sh || true

# Optional: Open browser
read -p "Open production site in browser? (y/n): " open_browser || true
if [ "${open_browser:-n}" = "y" ]; then
  ( open https://truckercore.com 2>/dev/null || \
    xdg-open https://truckercore.com 2>/dev/null || \
    start https://truckercore.com 2>/dev/null || \
    echo "Visit: https://truckercore.com" ) &
fi

echo -e "${GREEN}🎉 Ultimate launch complete!${NC}"