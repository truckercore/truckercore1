# Environment Setup Guide

## Prerequisites

1. Supabase Project
   - Create a project at https://supabase.com
   - Note your project URL and anon key
   - Note your project ID (for CLI)

2. Sentry Account (optional, for error tracking)
   - Create project at https://sentry.io
   - Note your DSN

## Local Development Setup

### 1. Clone and Install

```bash
git clone <your-repo>
cd truckercore1
flutter pub get
```

### 2. Configure Environment

Create `.env` file:

```bash
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON=your-anon-key-here
SENTRY_DSN=your-sentry-dsn # optional
USE_MOCK_DATA=false
```

### 3. Setup Database

```bash
export SUPABASE_PROJECT_ID=your-project-id
export SUPABASE_ACCESS_TOKEN=your-access-token
./scripts/setup_database.sh
```

### 4. Create Test Users

In Supabase Dashboard → Authentication → Users:

Driver Account:
- Email: driver@demo.com
- Password: demo123
- User Metadata:

```json
{ "primary_role": "driver", "roles": ["driver"] }
```

Owner Operator Account:
- Email: owner@demo.com
- Password: demo123
- User Metadata:

```json
{ "primary_role": "owner_operator", "roles": ["owner_operator"] }
```

Fleet Manager Account:
- Email: manager@demo.com
- Password: demo123
- User Metadata:

```json
{ "primary_role": "fleet_manager", "roles": ["fleet_manager", "owner_operator"] }
```

### 5. Run Application

```bash
# Mobile (Driver App)
flutter run -d <device-id>

# Desktop (Owner Operator)
flutter run -d macos --dart-define=DEFAULT_ROLE=owner_operator

# Desktop (Fleet Manager)
flutter run -d macos --dart-define=DEFAULT_ROLE=fleet_manager
```

## Production Deployment

### 1. Set GitHub Secrets

In your repo → Settings → Secrets:

```bash
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON=your-production-anon-key
SENTRY_DSN=your-production-sentry-dsn
ANDROID_KEYSTORE_PASSWORD=your-keystore-password
ANDROID_KEY_PASSWORD=your-key-password
```

### 2. Build Production Apps

```bash
# Driver App (Mobile)
./scripts/build_driver_app.sh

# Owner Operator (Desktop)
./scripts/build_desktop.sh owner-operator windows

# Fleet Manager (Desktop)
./scripts/build_desktop.sh fleet-manager windows
```

### 3. Deploy
- Android: Upload AAB to Google Play Console
- iOS: Upload IPA to App Store Connect
- Windows: Distribute installer via your website or Microsoft Store
- macOS: Notarize and distribute DMG
- Linux: Distribute AppImage or .deb package

## Testing

```bash
# Run all tests
./scripts/test_features.sh

# Verify features
./scripts/verify_features.sh

# Check feature status
dart run scripts/feature_status.dart
```

## Summary

You now have:
1. Complete authentication system with login and password reset
2. Real data providers connected to Supabase
3. Data models for Driver, Owner Operator, and Fleet Manager
4. Database schema with RLS policies
5. Database setup scripts
6. Complete environment setup documentation

Next immediate steps:

```bash
# 1) Setup your Supabase project (follow docs/ENVIRONMENT_SETUP.md)
# 2) Run database setup
./scripts/setup_database.sh
# 3) Create test users in Supabase Dashboard
# 4) Test locally
flutter run --dart-define=USE_MOCK_DATA=false
# 5) Build for production
./scripts/build_driver_app.sh
./scripts/build_desktop.sh owner-operator windows
./scripts/build_desktop.sh fleet-manager windows
```