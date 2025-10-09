#!/bin/bash

set -e

echo "╔═══════════════════════════════════════════════════════╗"
echo "║                                                       ║"
echo "║           🚀 DEPLOYING INFRASTRUCTURE 🚀              ║"
echo "║                                                       ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo ""

# Final verification
echo "Running final verification..."
./final-verification.sh

echo ""
echo "Showing infrastructure..."
./show-infrastructure.sh

echo ""
echo "Git status:"
git status --short || true

echo ""
BRANCH=$(git branch --show-current 2>/dev/null || echo "")
if [ -z "$BRANCH" ]; then
  echo "⚠️  Not a git repository or branch not detected."
  exit 1
fi

echo "Current branch: $BRANCH"

echo ""
read -p "Deploy to origin/$BRANCH? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Deployment cancelled"
  exit 1
fi

# Commit if needed
if [ $(git status --porcelain | wc -l) -gt 0 ]; then
  echo ""
  echo "Committing changes..."
  git add .
  git commit -m "chore: deploy infrastructure with CI enforcement

✅ Infrastructure complete:
- Vitest with CI coverage gates
- GitHub Actions workflows
- Dependabot configuration
- Security monitoring
- Validation tooling

All checks passed - ready for production"
fi

# Push
echo ""
echo "Pushing to origin/$BRANCH..."
git push origin "$BRANCH"

echo ""
echo "╔═══════════════════════════════════════════════════════╗"
echo "║                                                       ║"
echo "║            ✅ DEPLOYMENT SUCCESSFUL! ✅               ║"
echo "║                                                       ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo ""

REPO_URL=$(git remote get-url origin 2>/dev/null | sed 's/\.git$//' | sed 's/git@github.com:/https:\/\/github.com\//')
if [ -n "$REPO_URL" ]; then
  echo "🔗 Monitor deployment:"
  echo "   $REPO_URL/actions"
fi

echo ""
echo "📋 Next steps:"
echo "   1. Watch workflow run in GitHub Actions"
  echo "   2. Verify artifacts are generated"
  echo "   3. Review post-deployment-checklist.md"
  echo "   4. Share QUICK_REFERENCE.md with team"

echo ""
echo "🎉 Infrastructure deployment complete!"