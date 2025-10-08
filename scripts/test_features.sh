#!/bin/bash
set -e

echo "🧪 Testing TruckerCore Features..."

# Test with mock data
export USE_MOCK_DATA=true

echo ""
echo "1️⃣  Running unit tests..."
flutter test --coverage

echo ""
echo "2️⃣  Running integration tests..."
flutter test integration_test/

echo ""
echo "3️⃣  Building Driver App (debug)..."
flutter build apk --debug \
  --dart-define=USE_MOCK_DATA=true \
  --dart-define=DEFAULT_ROLE=driver

echo ""
echo "4️⃣  Building Owner Operator (debug)..."
flutter build linux --debug \
  --dart-define=USE_MOCK_DATA=true \
  --dart-define=DEFAULT_ROLE=owner_operator

echo ""
echo "5️⃣  Building Fleet Manager (debug)..."
flutter build linux --debug \
  --dart-define=USE_MOCK_DATA=true \
  --dart-define=DEFAULT_ROLE=fleet_manager

echo ""
echo "✅ All tests and builds completed!"}