# TruckerCore Quick Reference

## 🔧 Essential Commands

### Development
```
bash
Setup
flutter pub get cp .env.example .env
Run app
flutter run
Run tests
flutter test
Format code
dart format .
Analyze code
flutter analyze
``` 

### Building
```
bash
Driver App (Mobile)
./scripts/build_driver_app.sh
Desktop Apps
./scripts/build_desktop.sh owner-operator windows ./scripts/build_desktop.sh fleet-manager macos
``` 

### Deployment
```
bash
Pre-flight checks
./scripts/final_checks.sh
Full release build
./scripts/release.sh
Launch to production
./scripts/launch.sh
``` 

### Monitoring
```
bash
Check production health
./scripts/monitor_production.sh
View logs
flutter logs
``` 

## 🔑 Key Files

| File | Purpose |
|------|---------|
| `.env` | Local environment config |
| `.env.production` | Production environment config |
| `android/key.properties` | Android signing config |
| `pubspec.yaml` | Dependencies |
| `lib/main.dart` | App entry point |
| `lib/app_router.dart` | Navigation |

## 📱 Test Accounts
```
bash
Driver
driver.test@company.com / [password]
Owner Operator
owner.test@company.com / [password]
Fleet Manager
manager.test@company.com / [password]
``` 

## 🌐 Important URLs
```
bash
Supabase Dashboard
https://app.supabase.com/project/[your-project-id]
Sentry Dashboard
https://sentry.io/organizations/[your-org]/issues/
Google Play Console
https://play.google.com/console
App Store Connect
https://appstoreconnect.apple.com
``` 

## 🚨 Emergency Procedures

### App Crashes
1. Check Sentry for error details
2. Identify affected versions/devices
3. Create hotfix branch
4. Test fix thoroughly
5. Release emergency update

### API Down
1. Check Supabase status
2. Review database logs
3. Check rate limits
4. Contact Supabase support if needed

### Data Issues
1. Stop writes if critical
2. Assess data integrity
3. Restore from backup if needed
4. Investigate root cause
5. Implement safeguards

## 📞 Support Contacts

**Technical:**
- Supabase: support@supabase.com
- Sentry: support@sentry.io

**App Stores:**
- Apple: developer.apple.com/contact
- Google: support.google.com/googleplay/android-developer

## 🔄 Common Tasks

### Add New User
```
sql
-- In Supabase SQL Editor
INSERT INTO auth.users (email, encrypted_password, email_confirmed_at, raw_user_meta_data)
VALUES (
  'user@example.com',
  crypt('password', gen_salt('bf')),
  NOW(),
  '{"primary_role": "driver", "roles": ["driver"]}'::jsonb
);
``` 

### Reset User Password
```
bash
In Supabase Dashboard
Auth > Users > [user] > Reset Password
``` 

### View Recent Errors
```
bash
Sentry
Issues > Sort by "Last Seen"
App logs
flutter logs | grep ERROR
``` 

### Database Backup
```
bash
Supabase Dashboard
Database > Backups > Create Backup
``` 

## 📊 Key Metrics

### Health Indicators
- ✅ Error rate < 1%
- ✅ Crash-free rate > 99%
- ✅ API response time < 2s
- ✅ App rating > 4.0

### Growth Metrics
- Daily Active Users (DAU)
- Monthly Active Users (MAU)
- Day 1 Retention
- Day 7 Retention

## 🎯 Version Numbers

Current: v1.0.0

Format: MAJOR.MINOR.PATCH
- MAJOR: Breaking changes
- MINOR: New features
- PATCH: Bug fixes

## ⚙️ Feature Flags

Edit in `.env`:
```
bash
USE_MOCK_DATA=false # Use real API
DEBUG_LOGGING=false # Verbose logs
ENABLE_EXPERIMENTAL=false # Beta features
``` 

## 🔐 Security Checklist

- [ ] No secrets in code
- [ ] .env files in .gitignore
- [ ] RLS policies enabled
- [ ] SSL/HTTPS only
- [ ] Regular security audits

---
