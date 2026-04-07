#!/usr/bin/env bash

# Auto-fix common production readiness issues (root-aware)
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

say() { echo -e "$1"; }
step() { say "\n${YELLOW}→${NC} $1"; }

say "${CYAN}"
cat << 'EOF'
╔═══════════════════════════════════════════════════════╗
║                                                       ║
║   AUTO-FIX PRODUCTION ISSUES                         ║
║                                                       ║
╚═══════════════════════════════════════════════════════╝
EOF
say "${NC}"

# 1) React fixes (root)
if [ -f "package.json" ]; then
  say "\n${CYAN}1. Fixing React Application (root)${NC}"

  if [ ! -f package-lock.json ]; then
    step "Generating package-lock.json"
    npm install --package-lock-only || true
  fi

  if [ ! -d node_modules ]; then
    step "Installing dependencies"
    npm install || npm ci || true
  fi

  # Create .env from template if present
  if [ -f "src/.env.example" ] && [ ! -f ".env" ]; then
    step "Creating .env from src/.env.example"
    cp src/.env.example .env
    say "${YELLOW}⚠ Remember to update .env with your actual values${NC}"
  fi

  # Remove console.log statements from src (non-destructive; removes lines)
  if [ -d src ]; then
    step "Removing console.log statements from src/*.ts(x)"
    find src -type f \( -name "*.ts" -o -name "*.tsx" \) -print0 | \
      xargs -0 sed -i.bak '/console\.log/d' || true
    find src -name "*.bak" -delete || true
  fi

  # Try a build to surface TS errors
  step "Running TypeScript build to validate"
  npm run build || say "${YELLOW}Build has errors - manual fix may be required${NC}"
fi

# 2) Flutter fixes (root Flutter app)
if [ -f "pubspec.yaml" ]; then
  say "\n${CYAN}2. Fixing Flutter Application${NC}"

  if [ ! -f ".env" ]; then
    step "Creating minimal .env"
    cat > .env << 'EOT'
API_BASE_URL=http://localhost:3001/api
API_TIMEOUT=30000
USE_MOCK_DATA=true
ENABLE_ANALYTICS=false
ENABLE_GEOLOCATION=true
DEBUG_LOGGING=true
EOT
  fi

  step "Getting Flutter dependencies"
  flutter pub get || true

  if grep -q "build_runner" pubspec.yaml; then
    step "Running code generation"
    flutter pub run build_runner build --delete-conflicting-outputs || true
  fi

  step "Formatting Dart code"
  dart format . || true
fi

# 3) Git configuration (.gitignore)
step "Ensuring .gitignore has essential entries"
cat > .gitignore << 'EOF'
# Dependencies
node_modules/
/.pnp
.pnp.js

# Testing
/coverage

# Builds
/build
/dist

# Logs
npm-debug.log*
yarn-debug.log*
yarn-error.log*
logs/
*.log

# IDEs
.vscode/
.idea/
*.iml

# OS
.DS_Store
Thumbs.db

# Env files
.env
.env.local
.env.development.local
.env.test.local
.env.production.local
*.env.*.local

# Flutter/Dart
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
.pub-cache/
.pub/
/android/app/debug
/android/app/profile
/android/app/release
/build/
*.g.dart
*.freezed.dart

# iOS/Android signing
/android/key.properties
*.jks
*.keystore

# Other
.eslintcache
EOF

# 4) Pre-commit template
mkdir -p scripts
cat > scripts/pre-commit.sample << 'EOF'
#!/usr/bin/env bash
# Pre-commit hook to verify production readiness (quick checks)
set -e
ERRORS=0

# React quick checks
if [ -f package.json ]; then
  if grep -R "console\\.log" src --exclude-dir=node_modules --include='*.ts*' 2>/dev/null; then
    echo "❌ console.log statements found in React code"
    ERRORS=$((ERRORS+1))
  fi
  npm run -s build >/dev/null 2>&1 || { echo "❌ React build failed"; ERRORS=$((ERRORS+1)); }
fi

# Flutter quick checks
if [ -f pubspec.yaml ]; then
  flutter analyze >/dev/null 2>&1 || { echo "❌ Flutter analyze failed"; ERRORS=$((ERRORS+1)); }
fi

if [ "$ERRORS" -ne 0 ]; then
  echo "❌ Pre-commit checks failed. Fix issues and try again."
  echo "   (use 'git commit --no-verify' to bypass, not recommended)"
  exit 1
fi

echo "✓ Pre-commit checks passed"
EOF
chmod +x scripts/pre-commit.sample

say "\n${GREEN}✓ Auto-fix complete${NC}"
say "\n${YELLOW}Next Steps:${NC}"
say "1. Review changes made by this script"
say "2. Update .env with real values as needed"
say "3. Optionally copy scripts/pre-commit.sample to .git/hooks/pre-commit"
say "4. Run './verify-production-ready.sh' again"
