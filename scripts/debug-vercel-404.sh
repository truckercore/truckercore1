#!/bin/bash
# Debug Vercel 404 issues

echo "🐛 TruckerCore Vercel 404 Debugger"
echo "=================================="
echo ""

# Check 1: File structure
echo "1️⃣ Checking file structure..."
if [ -f "pages/index.tsx" ]; then
  echo "✅ pages/index.tsx exists"
else
  echo "❌ pages/index.tsx MISSING - This is the problem!"
  exit 1
fi

if [ -f "pages/_app.tsx" ]; then
  echo "✅ pages/_app.tsx exists"
else
  echo "⚠️  pages/_app.tsx missing (recommended)"
fi

# Check 2: Package.json scripts
echo ""
echo "2️⃣ Checking package.json scripts..."
if grep -q '"build".*"next build"' package.json; then
  echo "✅ Build script configured"
else
  echo "❌ Build script missing or incorrect"
fi

# Check 3: Dependencies
echo ""
echo "3️⃣ Checking dependencies..."
if grep -q '"next"' package.json; then
  NEXT_VERSION=$(grep '"next"' package.json | sed 's/.*: "//; s/".*//')
  echo "✅ Next.js installed: $NEXT_VERSION"
else
  echo "❌ Next.js not installed"
  exit 1
fi

# Check 4: Build test
echo ""
echo "4️⃣ Testing build locally..."
npm run build > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "✅ Build succeeds locally"
else
  echo "❌ Build fails locally - fix errors first:"
  npm run build
  exit 1
fi

# Check 5: Vercel configuration
echo ""
echo "5️⃣ Checking Vercel config..."
if [ -f "vercel.json" ]; then
  echo "✅ vercel.json exists"
  if grep -q '"framework".*"nextjs"' vercel.json; then
    echo "✅ Framework set to Next.js"
  else
    echo "⚠️  Framework not explicitly set (usually auto-detected)"
  fi
else
  echo "⚠️  vercel.json missing (usually not required)"
fi

# Check 6: Environment variables
echo ""
echo "6️⃣ Checking environment variables..."
echo "Run manually: vercel env ls"
echo "Required variables:"
echo "  - NEXT_PUBLIC_SUPABASE_URL"
echo "  - NEXT_PUBLIC_SUPABASE_ANON_KEY"

echo ""
echo "=================================="
echo "✅ Debug complete!"
echo ""
echo "Next steps:"
echo "1. Fix any ❌ issues above"
echo "2. Run: git add -A && git commit -m 'fix: Resolve 404' && git push"
echo "3. Monitor: vercel logs --follow"
echo "4. Test: curl -I https://truckercore.com"}