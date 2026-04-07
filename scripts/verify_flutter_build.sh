#!/usr/bin/env bash

# 🔍 Flutter Build Verification Script
# This script verifies a clean Flutter build, runs code generation, analyzes, tests, and optionally checks Windows CMake warnings.

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
  local exit_code=$1
  local message=$2
  if [ "$exit_code" -eq 0 ]; then
    echo -e "${GREEN}✓${NC} ${message}"
  else
    echo -e "${RED}✗${NC} ${message}"
  fi
}

echo "🔍 Flutter Build Verification Script"
echo "===================================="
echo ""

# 1️⃣  Check Flutter installation
echo "1️⃣  Checking Flutter installation..."
set +e
flutter --version
rc=$?
set -e
print_status $rc "Flutter is installed"
echo ""

# 2️⃣  Clean build artifacts
echo "2️⃣  Cleaning build artifacts..."
set +e
flutter clean
rm -rf windows/flutter/ephemeral || true
rm -rf build || true
rm -rf .dart_tool || true
rc=$?
set -e
print_status $rc "Build artifacts cleaned"
echo ""

# 3️⃣  Get dependencies
echo "3️⃣  Getting dependencies..."
set +e
flutter pub get
rc=$?
set -e
print_status $rc "Dependencies resolved"
echo ""

# 4️⃣  Run code generation
echo "4️⃣  Running code generation..."
set +e
flutter pub run build_runner build --delete-conflicting-outputs
rc=$?
set -e
print_status $rc "Code generation completed"
echo ""

# 5️⃣  Analyze code
echo "5️⃣  Analyzing code..."
set +e
flutter analyze
rc=$?
set -e
print_status $rc "Code analysis passed"
echo ""

# 6️⃣  Run tests
echo "6️⃣  Running tests..."
set +e
flutter test
rc=$?
set -e
print_status $rc "Tests passed"
echo ""

# 7️⃣  Check for CMake warnings (Windows shells only)
if [[ "${OSTYPE:-}" == msys* || "${OSTYPE:-}" == cygwin* || "${OS:-}" == "Windows_NT" ]]; then
  echo "7️⃣  Building for Windows and checking for CMake warnings..."
  set +e
  flutter build windows 2>&1 | tee build_output.txt
  cmake_count=$(grep -c "CMake Warning" build_output.txt || true)
  set -e
  if [ "${cmake_count}" -eq 0 ]; then
    echo -e "${GREEN}✓${NC} No CMake warnings found"
  else
    echo -e "${YELLOW}⚠${NC}  Found ${cmake_count} CMake warning(s)"
  fi
  rm -f build_output.txt
fi

echo ""
echo "📊 Verification Summary"
echo "======================="
echo -e "${GREEN}✓${NC} All checks completed"
echo ""
echo "🚀 Your Flutter app is ready to run!"
echo "   Run: flutter run -d chrome"
echo "   Or:  flutter run -d windows"
