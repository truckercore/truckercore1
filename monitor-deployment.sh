#!/bin/bash

REPO_URL=$(git remote get-url origin 2>/dev/null | sed 's/\.git$//' | sed 's/git@github.com:/https:\/\/github.com\//')

echo "🔍 Post-Deployment Monitoring"
echo "=============================="
echo ""
echo "Repository: ${REPO_URL:-<unknown>}"
echo ""

echo "📋 Key URLs:"
echo "  🤖 Actions:     ${REPO_URL:-<unknown>}/actions"
echo "  🔐 Security:    ${REPO_URL:-<unknown>}/security"
echo "  📦 Dependabot:  ${REPO_URL:-<unknown>}/network/updates"

echo ""
echo "✅ Immediate Checks (do these now):"
echo "  1. Visit Actions tab - verify workflow started"
echo "  2. Click on latest workflow run"
echo "  3. Verify all jobs are running/passed"
echo "  4. Check for any error messages"

echo ""
echo "⏰ Within 10 minutes:"
echo "  • Test workflow should complete"
echo "  • All Node versions (18.x, 20.x) should pass"
echo "  • Artifacts should be uploaded"
echo "  • No failed jobs"

echo ""
echo "📊 Within 1 hour:"
echo "  • Coverage reports available in artifacts"
echo "  • Test results downloadable"
echo "  • Security workflow visible in workflows list"

echo ""
echo "📅 Within 24 hours:"
echo "  • Security audit runs at 9 AM UTC tomorrow"
echo "  • Check for any security issues created"

echo ""
echo "📅 Next Monday (9 AM UTC):"
echo "  • First Dependabot PRs will appear"
echo "  • Review and merge security patches"

echo ""
echo "🔗 Quick Links:"
echo "  open ${REPO_URL:-<unknown>}/actions"