#!/bin/bash
# Comprehensive pre-deployment testing

echo "🧪 Pre-Deployment Test Suite"
echo "============================="
echo ""

TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
  local test_name=$1
  local test_command=$2
  
  echo -n "Testing: $test_name... "
  
  if eval "$test_command" > /dev/null 2>&1; then
    echo "✅ PASS"
    ((TESTS_PASSED++))
  else
    echo "❌ FAIL"
    ((TESTS_FAILED++))
  fi
}

# Configuration tests
echo "Configuration Tests:"
run_test "next.config.js syntax" "node -c next.config.js"
run_test "package.json valid" "node -e 'JSON.parse(require(\"fs\").readFileSync(\"package.json\"))'"
run_test "vercel.json valid" "node -e 'JSON.parse(require(\"fs\").readFileSync(\"vercel.json\"))'"

echo ""
echo "Build Tests:"
run_test "Clean build" "rm -rf .next && npm run build"
run_test "Production start" "timeout 10s npm run start &"

echo ""
echo "Validation Tests:"
run_test "SEO validation" "npm run validate:seo"
run_test "TypeScript check" "npm run typecheck"

echo ""
echo "File Tests:"
run_test "Homepage exists" "test -f pages/index.tsx"
run_test "Favicon exists" "test -f public/favicon.ico"
run_test "Logo exists" "test -f public/logo.svg"
run_test "Manifest exists" "test -f public/manifest.json"
run_test "Robots.txt exists" "test -f public/robots.txt"
run_test "Sitemap exists" "test -f public/sitemap.xml"

echo ""
echo "============================="
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $TESTS_FAILED"

if [ $TESTS_FAILED -eq 0 ]; then
  echo "✅ All tests passed! Ready to deploy."
  exit 0
else
  echo "❌ Some tests failed. Fix issues before deploying."
  exit 1
fi
