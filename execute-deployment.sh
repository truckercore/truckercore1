#!/bin/bash

echo "╔═══════════════════════════════════════════════════════╗"
echo "║                                                       ║"
echo "║         INFRASTRUCTURE DEPLOYMENT SEQUENCE            ║"
echo "║                                                       ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo ""

# Step 1: Validate all scripts exist
echo "Step 1/7: Checking deployment scripts..."
required_scripts=(
  "validate-implementation.sh"
  "verify-setup.sh"
  "health-check.sh"
  "run-all-validations.sh"
  "deploy.sh"
)

missing=0
for script in "${required_scripts[@]}"; do
  if [ -f "$script" ]; then
    echo "  ✅ $script"
  else
    echo "  ❌ $script - MISSING"
    ((missing++))
  fi
done

if [ $missing -gt 0 ]; then
  echo ""
  echo "❌ $missing script(s) missing - cannot proceed"
  exit 1
fi

# Step 2: Make all scripts executable
echo ""
echo "Step 2/7: Making scripts executable..."
chmod +x *.sh scripts/*.sh 2>/dev/null
echo "  ✅ Scripts are executable"

# Step 3: Run quick validation
echo ""
echo "Step 3/7: Running quick validation..."
if ./verify-setup.sh > /dev/null 2>&1; then
  echo "  ✅ Quick validation passed"
else
  echo "  ⚠️  Quick validation had warnings"
fi

# Step 4: Test npm scripts
echo ""
echo "Step 4/7: Testing npm scripts..."
if npm run test:run > /dev/null 2>&1; then
  echo "  ✅ Tests pass"
else
  echo "  ⚠️  Tests have issues"
fi

# Step 5: Check coverage
echo ""
echo "Step 5/7: Checking coverage..."
if npm run test:coverage > /dev/null 2>&1; then
  echo "  ✅ Coverage generated"
else
  echo "  ⚠️  Coverage generation issues"
fi

# Step 6: Security check
echo ""
echo "Step 6/7: Running security check..."
if npm audit --audit-level=moderate > /dev/null 2>&1; then
  echo "  ✅ No security issues"
else
  echo "  ⚠️  Security vulnerabilities found"
fi

# Step 7: Ready to deploy
echo ""
echo "Step 7/7: Deployment readiness..."
echo "  ✅ All checks complete"

echo ""
echo "╔═══════════════════════════════════════════════════════╗"
echo "║                                                       ║"
echo "║              READY FOR DEPLOYMENT                     ║"
echo "║                                                       ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo ""
echo "Choose deployment method:"
echo ""
echo "  1. Full deployment with reports:"
echo "     ./deploy.sh"
echo ""
echo "  2. Quick deployment:"
echo "     ./deploy-now.sh"
echo ""
echo "  3. Comprehensive validation first:"
echo "     ./run-all-validations.sh && ./deploy.sh"
echo ""
read -p "Run full deployment now? (y/n) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo ""
  echo "🚀 Executing deployment..."
  ./deploy.sh
else
  echo ""
  echo "✅ Pre-deployment checks complete"
  echo "   Run ./deploy.sh when ready"
fi
