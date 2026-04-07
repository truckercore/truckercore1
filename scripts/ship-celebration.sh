#!/bin/bash
# Ship celebration - shows after successful deployment

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
NC='\033[0m'

echo ""
echo -e "${CYAN}"
cat << "EOF"
    🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉
    
         🚢 SHIPPED TO PRODUCTION! 🚢
    
    🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉
EOF
echo -e "${NC}"

echo ""
echo -e "${GREEN}✨ TruckerCore is now LIVE! ✨${NC}"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "🌐 Your Production URLs:"
echo ""
echo "   🏠 Homepage:   ${YELLOW}https://truckercore.com${NC}"
echo "   📱 App:        ${YELLOW}https://app.truckercore.com${NC}"
echo "   🔌 API Health: ${YELLOW}https://api.truckercore.com/health${NC}"
echo "   📦 Downloads:  ${YELLOW}https://downloads.truckercore.com${NC}"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "📊 Quick Checks:"
echo ""
echo "   • Homepage:    $(curl -s -o /dev/null -w "%{http_code}" https://truckercore.com 2>/dev/null || echo "checking...")"
echo "   • App:         $(curl -s -o /dev/null -w "%{http_code}" https://app.truckercore.com 2>/dev/null || echo "checking...")"
echo "   • API Health:  $(curl -s -o /dev/null -w "%{http_code}" https://api.truckercore.com/health 2>/dev/null || echo "checking...")"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "🎯 What's Next:"
echo ""
echo "   1. ${MAGENTA}Monitor:${NC}      npm run monitor"
echo "   2. ${MAGENTA}Check Logs:${NC}   npm run monitor:logs"
echo "   3. ${MAGENTA}Lighthouse:${NC}   lighthouse https://truckercore.com --view"
echo "   4. ${MAGENTA}Share:${NC}        Tell the team in #deployments!"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}🎊 Congratulations! You've successfully shipped TruckerCore! 🎊${NC}"
echo ""
echo -e "${YELLOW}\"First, solve the problem. Then, write the code.\" - John Johnson${NC}"
echo ""