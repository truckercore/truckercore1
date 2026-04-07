#!/bin/bash

# Quick test script for development - runs only changed files

set -e

echo "🚀 Quick Test Runner"
echo ""

# Check for changed files
CHANGED_FILES=$(git diff --name-only --diff-filter=ACMR HEAD | grep -E '\.(ts|tsx)$' || true)

if [ -z "$CHANGED_FILES" ]; then
  echo "ℹ️  No changed TypeScript files detected"
  echo "Running last modified tests..."
  npm run test:quick
else
  echo "📝 Changed files:"
  echo "$CHANGED_FILES" | sed 's/^/  - /'
  echo ""
  echo "🧪 Running tests for changed files..."
  npm run test:related $CHANGED_FILES
fi

echo ""
echo "✅ Quick tests complete!"
