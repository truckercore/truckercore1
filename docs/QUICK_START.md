# Quick Start Guide

## For Developers

### Setup (5 minutes)

```
# 1. Clone and install
git clone <repo-url>
cd truckercore1
flutter pub get

# 2. Create environment file
cp .env.example .env
# Edit .env with your Supabase credentials

# 3. Setup database
export SUPABASE_PROJECT_ID=your-project-id
export SUPABASE_ACCESS_TOKEN=your-access-token
./scripts/setup_database.sh

# 4. Create test users (in Supabase Dashboard)
# See docs/ENVIRONMENT_SETUP.md for details

# 5. Run app
flutter run
```

### Development Workflow

```
# Run tests
flutter test

# Run with hot reload
flutter run

# Build debug
flutter build apk --debug

# Verify features
./scripts/verify_features.sh

# Check pre-release status
./scripts/pre_release_check.sh
```

## For Testing

### Test Accounts
- Driver: driver@demo.com / demo123
- Owner Operator: owner@demo.com / demo123
- Fleet Manager: manager@demo.com / demo123

### Test Scenarios

Driver App
- Login as driver
- View dashboard (status, active load, HOS)
- Navigate to Loads screen
- Check HOS details
- Test offline mode (enable airplane mode)

Owner Operator Desktop
- Login as owner operator
- View fleet overview
- Check vehicle status
- View loads
- Generate reports

Fleet Manager Desktop
- Login as fleet manager
- View multi-fleet dashboard
- Manage users
- Check compliance
- View audit logs

## Building for Release

Mobile (Driver App)
```
# Android
./scripts/build_driver_app.sh
# Output: build/app/outputs/bundle/release/app-release.aab

# iOS (macOS only)
./scripts/build_driver_app.sh
# Output: build/ios/ipa/*.ipa
```

Desktop (Owner Operator & Fleet Manager)
```
# Windows
./scripts/build_desktop.sh owner-operator windows
./scripts/build_desktop.sh fleet-manager windows

# macOS
./scripts/build_desktop.sh owner-operator macos
./scripts/build_desktop.sh fleet-manager macos

# Linux
./scripts/build_desktop.sh owner-operator linux
./scripts/build_desktop.sh fleet-manager linux
```

## Troubleshooting

"Supabase not initialized"
- Check .env file exists with correct credentials
- Verify SUPABASE_URL and SUPABASE_ANON are set
- Check network connection

"No user found" after login
- Verify user exists in Supabase Dashboard
- Check user_metadata has correct role set
- Clear app data and try again

Build fails
- Run flutter clean && flutter pub get
- Check Flutter version: flutter --version
- Verify all build scripts are executable

Tests failing
- Check Supabase credentials in test environment
- Verify mock data mode: USE_MOCK_DATA=true flutter test
- Review test output for specific errors

## Support
- Documentation: docs/
- Issues: GitHub Issues
- Environment Setup: docs/ENVIRONMENT_SETUP.md
- Release Checklist: RELEASE_CHECKLIST.md
