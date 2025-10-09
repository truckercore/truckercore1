#!/bin/bash

echo "🔍 Post-Deployment Verification"
echo "================================"
echo ""

REPO_URL=$(git remote get-url origin 2>/dev/null | sed 's/\.git$//' | sed 's/git@github.com:/https:\/\/github.com\//')

echo "1. Check GitHub Actions:"
echo "   ${REPO_URL:-https://github.com/<user>/<repo>}/actions"
echo "   ✓ Test workflow should be running"
echo "   ✓ Should see workflow for latest commit"
echo ""

echo "2. Verify workflow execution:"
echo "   ✓ Click on workflow run"
echo "   ✓ Check Node 18.x job"
echo "   ✓ Check Node 20.x job"
echo "   ✓ Both should be green or in progress"
echo ""

echo "3. Check for errors:"
echo "   ✓ Click on any failed job (if red)"
echo "   ✓ Review error logs"
echo "   ✓ Check coverage enforcement step"
echo ""

echo "4. Verify artifacts (after completion):"
echo "   ✓ Scroll to bottom of workflow run"
echo "   ✓ Should see 'Artifacts' section"
echo "   ✓ test-results and coverage reports"
echo ""

echo "5. Security workflow:"
echo "   ✓ Should appear in workflows list"
echo "   ✓ Next run: Tomorrow 9 AM UTC"
echo "   ✓ Can manually trigger for testing"
echo ""

echo "✅ Verification checklist complete"
echo ""
echo "Next: Review post-deployment-checklist.md"