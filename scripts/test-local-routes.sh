#!/bin/bash
# Test all routes locally before deployment

BASE_URL=${BASE_URL:-"http://localhost:3000"}
echo "🧪 Testing local routes on $BASE_URL"
echo "Make sure 'npm run dev' is running in another terminal"
echo ""

routes=(
  "/"
  "/about"
  "/privacy"
  "/terms"
  "/contact"
  "/docs"
  "/downloads"
  "/nonexistent-page"
)

for route in "${routes[@]}"; do
  status=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL$route")
  if [ "$route" = "/nonexistent-page" ]; then
    expected=404
  else
    expected=200
  fi
  
  if [ "$status" -eq "$expected" ]; then
    echo "✅ $route → $status"
  else
    echo "❌ $route → $status (expected $expected)"
  fi
done

echo ""
echo "Testing static assets..."
assets=(
  "/favicon.ico"
  "/logo.svg"
  "/manifest.json"
  "/robots.txt"
  "/sitemap.xml"
)

for asset in "${assets[@]}"; do
  status=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL$asset")
  if [ "$status" -eq 200 ]; then
    echo "✅ $asset → $status"
  else
    echo "❌ $asset → $status"
  fi
done

echo ""
echo "✅ Local testing complete!"