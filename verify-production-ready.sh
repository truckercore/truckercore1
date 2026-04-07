#!/usr/bin/env bash

# Production Readiness Verification Script (root-aware)
# This script systematically checks production readiness for both the React web app (root)
# and the Flutter app contained in this repository.

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Status tracking
FAILED_ITEMS=()
WARNING_ITEMS=()

print_header() {
  echo -e "${MAGENTA}"
  cat << 'EOF'
╔═══════════════════════════════════════════════════════╗
║                                                       ║
║   TRUCKERCORE PRODUCTION READINESS VERIFICATION      ║
║                                                       ║
╚═══════════════════════════════════════════════════════╝
EOF
  echo -e "${NC}"
}

print_section() {
  echo ""
  echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
  echo -e "${CYAN}  $1${NC}"
  echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
  echo ""
}

check_item() {
  local name="$1"
  local command="$2"
  local severity="${3:-error}" # error or warning
  ((TOTAL_CHECKS++))
  printf "%-56s " "$name"
  if eval "$command" &>/dev/null; then
    echo -e "${GREEN}✓ PASS${NC}"
    ((PASSED_CHECKS++))
    return 0
  else
    if [ "$severity" = "warning" ]; then
      echo -e "${YELLOW}⚠ WARN${NC}"
      ((WARNING_CHECKS++))
      WARNING_ITEMS+=("$name")
    else
      echo -e "${RED}✗ FAIL${NC}"
      ((FAILED_CHECKS++))
      FAILED_ITEMS+=("$name")
    fi
    return 1
  fi
}

print_summary() {
  echo ""
  echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}  VERIFICATION SUMMARY${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
  echo ""
  echo -e "Total Checks:    ${TOTAL_CHECKS}"
  echo -e "Passed:          ${GREEN}${PASSED_CHECKS}${NC}"
  echo -e "Failed:          ${RED}${FAILED_CHECKS}${NC}"
  echo -e "Warnings:        ${YELLOW}${WARNING_CHECKS}${NC}"
  echo ""
  if [ ${FAILED_CHECKS} -gt 0 ]; then
    echo -e "${RED}Failed Items:${NC}"
    for item in "${FAILED_ITEMS[@]}"; do
      echo -e "  ${RED}✗${NC} $item"
    done
    echo ""
  fi
  if [ ${WARNING_CHECKS} -gt 0 ]; then
    echo -e "${YELLOW}Warning Items:${NC}"
    for item in "${WARNING_ITEMS[@]}"; do
      echo -e "  ${YELLOW}⚠${NC} $item"
    done
    echo ""
  fi
  if [ $TOTAL_CHECKS -gt 0 ]; then
    local pass_rate=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
    echo -e "Pass Rate:       ${pass_rate}%"
  fi
  echo ""
  if [ ${FAILED_CHECKS} -eq 0 ]; then
    echo -e "${GREEN}🎉 PRODUCTION READY! 🎉${NC}"
    return 0
  else
    echo -e "${RED}❌ NOT PRODUCTION READY${NC}"
    echo -e "${YELLOW}Run './fix-production-issues.sh' to auto-fix common issues${NC}"
    return 1
  fi
}

clear || true
print_header

# 1. Prerequisites
print_section "1. Prerequisites"
check_item "Node.js installed" "command -v node"
check_item "npm installed" "command -v npm"
check_item "Flutter installed" "command -v flutter" "warning"
check_item "Git installed" "command -v git"

# 2. React - Code Quality (root)
print_section "2. React - Code Quality (root)"
if [ -f "package.json" ]; then
  check_item "package.json exists" "test -f package.json"
  check_item "package-lock.json exists" "test -f package-lock.json" "warning"
  check_item "tsconfig.json exists" "test -f tsconfig.json" "warning"
  check_item "public folder exists" "test -d public"
  check_item "src folder exists" "test -d src"
  check_item "Dependencies installed" "test -d node_modules"
  check_item "TypeScript strict mode" "grep -q '\"strict\"\s*:\s*true' tsconfig.json" "warning"
  check_item "ESLint configured (optional)" "grep -q eslint package.json" "warning"
  check_item "Test script exists" "grep -q '\"test\"' package.json"
  check_item "Build script exists" "grep -q '\"build\"' package.json"
  # console.log scan
  ((TOTAL_CHECKS++))
  if ! grep -R "console\\.log" src --exclude-dir=node_modules --include='*.ts*' >/dev/null 2>&1; then
    echo -e "No console.log statements                      ${GREEN}✓ PASS${NC}"
    ((PASSED_CHECKS++))
  else
    echo -e "No console.log statements                      ${YELLOW}⚠ WARN${NC}"
    ((WARNING_CHECKS++))
    WARNING_ITEMS+=("Console.log statements found in React src/")
  fi
else
  echo -e "${YELLOW}package.json not found at repo root; skipping React checks${NC}"
fi

# 3. React - Testing
print_section "3. React - Testing"
if [ -f "package.json" ]; then
  check_item "Tests can run (CI mode)" "npm test -- --passWithNoTests --watchAll=false" "warning"
  check_item "Test files exist" "find src -type f \( -name '*.test.tsx' -o -name '*.test.ts' \) | grep -q ." "warning"
fi

# 4. React - Performance
print_section "4. React - Performance"
if [ -f "package.json" ]; then
  check_item "Build succeeds" "npm run build"
  if [ -d build ]; then
    BUILD_SIZE=$(du -sh build 2>/dev/null | awk '{print $1}')
    echo -e "Build size: ${BUILD_SIZE:-unknown}"
    check_item "Service worker exists (public/build)" "test -f public/service-worker.js -o -f build/service-worker.js" "warning"
    check_item "Manifest exists" "test -f public/manifest.json -o -f build/manifest.json" "warning"
  fi
fi

# 5. React - PWA Features
print_section "5. React - PWA Features"
if [ -d "public" ]; then
  check_item "manifest.json in public" "test -f public/manifest.json"
  check_item "192x192 icon exists" "test -f public/logo192.png" "warning"
  check_item "512x512 icon exists" "test -f public/logo512.png" "warning"
fi
if [ -d "src" ]; then
  check_item "serviceWorkerRegistration.ts present" "test -f src/serviceWorkerRegistration.ts"
fi

# 6. Flutter - Code Quality
print_section "6. Flutter - Code Quality"
# Flutter project detected if pubspec.yaml exists at root
if [ -f "pubspec.yaml" ]; then
  check_item "pubspec.yaml exists" "test -f pubspec.yaml"
  check_item "lib/main.dart exists" "test -f lib/main.dart"
  check_item ".env exists (optional)" "test -f .env" "warning"
  check_item "Dependencies resolved" "flutter pub get"
  check_item "build_runner listed (for generation)" "grep -q 'build_runner' pubspec.yaml" "warning"
fi

# 7. Flutter - Testing
print_section "7. Flutter - Testing"
if [ -f "pubspec.yaml" ]; then
  check_item "Flutter analyze passes" "flutter analyze"
  check_item "Tests directory exists" "test -d test" "warning"
  check_item "Flutter tests pass" "flutter test" "warning"
fi

# 8. Flutter - Build Verification (Windows policy)
print_section "8. Flutter - Build Verification"
if [ -f "windows/CMakeLists.txt" ]; then
  check_item "CMake policies configured (CMP0175)" "grep -q 'CMP0175' windows/CMakeLists.txt"
  check_item "CMake policies configured (CMP0153)" "grep -q 'CMP0153' windows/CMakeLists.txt"
fi

# 9. CI/CD Configuration
print_section "9. CI/CD Configuration"
check_item "GitHub Actions directory" "test -d .github/workflows"
check_item "React CI workflow" "test -f .github/workflows/react-ci.yml"
check_item "Flutter CI workflow" "test -f .github/workflows/flutter-ci.yml"
check_item "Dependabot/renovate present (renovate.json or dependabot.yml)" "test -f renovate.json -o -f .github/dependabot.yml" "warning"

# 10. Documentation
print_section "10. Documentation"
check_item "Root README exists" "test -f README.md"
check_item "React README exists (src/README.md)" "test -f src/README.md" "warning"
check_item "Flutter Build Guide exists" "test -f docs/FLUTTER_BUILD_GUIDE.md" "warning"
check_item "Production checklist exists" "test -f PRODUCTION_READY_CHECKLIST.md -o -f FINAL_PRODUCTION_CHECKLIST.md" "warning"
check_item "Deployment guide exists" "test -f DEPLOYMENT_CHECKLIST.md -o -f post-deployment-checklist.md" "warning"

# 11. Security
print_section "11. Security"
if [ -f "package.json" ]; then
  check_item "No .env in git (root)" "! git ls-files | grep -q '^.env$'"
  check_item "npm audit (production)" "npm audit --omit=dev" "warning"
fi
check_item ".gitignore exists" "test -f .gitignore"
check_item "node_modules ignored" "grep -q 'node_modules' .gitignore"
check_item ".env ignored" "grep -q '\\.env' .gitignore"

# 12. Git Repository
print_section "12. Git Repository"
check_item "Git initialized" "test -d .git"
check_item "Remote configured" "git remote -v | grep -q ." "warning"
check_item "No uncommitted changes" "git diff-index --quiet HEAD --" "warning"

print_summary
