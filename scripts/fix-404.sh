#!/bin/bash
# Quick fix for Vercel 404 issues

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔧 TruckerCore 404 Fix Script${NC}"
echo ""

# Check 1: Homepage exists
echo -n "1. Checking for pages/index.tsx... "
if [ -f "pages/index.tsx" ]; then
  echo -e "${GREEN}✅ Found${NC}"
else
  echo -e "${RED}❌ Missing${NC}"
  echo "Creating minimal homepage..."
  mkdir -p pages
  cat > pages/index.tsx << 'EOF'
export default function Home() {
  return (
    <main style={{ minHeight: "100vh", padding: "48px 24px", background: "#0F1216", color: "#fff" }}>
      <h1>TruckerCore</h1>
      <p>Welcome to TruckerCore</p>
      <a href="https://app.truckercore.com">Launch App</a>
    </main>
  );
}
EOF
  echo -e "${GREEN}✅ Created pages/index.tsx${NC}"
fi

# Check 2: Router conflicts
echo ""
echo -n "2. Checking for router conflicts... "
if [ -d "app" ] && [ -d "pages" ]; then
  echo -e "${YELLOW}⚠️  Both app/ and pages/ exist${NC}"
  echo "   Keeping Pages Router. If you want to remove App Router, run: rm -rf app/"
else
  echo -e "${GREEN}✅ No conflicts${NC}"
fi

# Check 3: _app.tsx exists
echo ""
echo -n "3. Checking for pages/_app.tsx... "
if [ -f "pages/_app.tsx" ]; then
  echo -e "${GREEN}✅ Found${NC}"
else
  echo -e "${YELLOW}⚠️  Missing${NC}"
  echo "Creating minimal _app.tsx..."
  cat > pages/_app.tsx << 'EOF'
import type { AppProps } from "next/app";

export default function App({ Component, pageProps }: AppProps) {
  return <Component {...pageProps} />;
}
EOF
  echo -e "${GREEN}✅ Created pages/_app.tsx${NC}"
fi

# Check 4: next.config.js (remove standalone if present)
echo ""
echo -n "4. Checking next.config.js... "
if [ -f next.config.js ] && grep -q "output.*standalone" next.config.js 2>/dev/null; then
  echo -n "${YELLOW}⚠️  Found 'standalone' output${NC}\n   Removing (not needed for Vercel)... "
  # portable in-place edit
  tmpfile=$(mktemp)
  grep -v "output.*standalone" next.config.js > "$tmpfile" && mv "$tmpfile" next.config.js
  echo -e "${GREEN}✅ Fixed next.config.js${NC}"
else
  echo -e "${GREEN}✅ OK${NC}"
fi

# Check 5: Test build
echo ""
echo "5. Testing build..."
if npm run build > /dev/null 2>&1; then
  echo -e "${GREEN}✅ Build succeeds${NC}"
else
  echo -e "${RED}❌ Build fails${NC}"
fi

# Summary
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Next steps:"
echo ""
echo "  1. Commit changes:"
echo -e "     ${YELLOW}git add -A${NC}"
echo -e "     ${YELLOW}git commit -m 'fix: Resolve 404 routing issue'${NC}"
echo ""
echo "  2. Push to deploy:"
echo -e "     ${YELLOW}git push origin main${NC}"
echo ""
echo "  3. Wait 2 minutes, then test:"
echo -e "     ${YELLOW}curl -I https://truckercore.com${NC}"
echo ""