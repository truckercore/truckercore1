# 🚀 TruckerCore Launch Guide

This is your step-by-step guide to launching TruckerCore to production.

## Pre-Launch Phase (1-2 weeks before launch)

### Week 1: Infrastructure Setup

#### Day 1-2: Supabase Production Setup
```
bash
1. Create production Supabase project
Visit: https://app.supabase.com
2. Note your credentials
SUPABASE_URL=https://[your-project-id].supabase.co SUPABASE_ANON_KEY=[your-anon-key]
3. Setup database schema
export SUPABASE_PROJECT_ID=your-project-id export SUPABASE_ACCESS_TOKEN=your-access-token ./scripts/setup_database.sh
4. Verify tables created
Check in Supabase Dashboard > Database > Tables
``` 

**Tables to verify:**
- ✅ driver_status
- ✅ loads
- ✅ hos_records
- ✅ vehicles
- ✅ fleets

#### Day 3: Create Test Users

In Supabase Dashboard → Authentication → Users, create:

1. **Driver Test Account**
   ```json
   {
     "email": "driver.test@yourcompany.com",
     "password": "[secure-password]",
     "user_metadata": {
       "primary_role": "driver",
       "roles": ["driver"],
       "first_name": "Test",
       "last_name": "Driver"
     }
   }
   ```

2. **Owner Operator Test Account**
   ```json
   {
     "email": "owner.test@yourcompany.com",
     "password": "[secure-password]",
     "user_metadata": {
       "primary_role": "owner_operator",
       "roles": ["owner_operator"],
       "org_id": "[your-org-uuid]"
     }
   }
   ```

3. **Fleet Manager Test Account**
   ```json
   {
     "email": "manager.test@yourcompany.com",
     "password": "[secure-password]",
     "user_metadata": {
       "primary_role": "fleet_manager",
       "roles": ["fleet_manager", "owner_operator"],
       "org_id": "[your-org-uuid]"
     }
   }
   ```

#### Day 4: Sentry Setup (Optional but Recommended)
```
bash
1. Create Sentry account: https://sentry.io
2. Create new project for Flutter
3. Note your DSN
SENTRY_DSN=https://[key]@sentry.io/[project-id]
4. Test error tracking
flutter run --dart-define=SENTRY_DSN=$SENTRY_DSN
Trigger a test error to verify tracking
``` 

#### Day 5: Environment Configuration
```
bash
1. Create production environment file
cp .env.example .env.production
2. Edit with production credentials
nano .env.production
Add:
SUPABASE_URL=https://[your-project-id].supabase.co SUPABASE_ANON=[your-production-anon-key] SENTRY_DSN=https://[key]@sentry.io/[project-id] USE_MOCK_DATA=false RELEASE_CHANNEL=production
``` 

#### Day 6-7: Android Signing Setup
```
bash
1. Generate keystore
keytool -genkey -v -keystore ~/truckercore-release-key.jks
-keyalg RSA -keysize 2048 -validity 10000
-alias truckercore
2. Create key.properties
cat > android/key.properties << EOF storePassword=[your-store-password] keyPassword=[your-key-password] keyAlias=truckercore storeFile=/path/to/truckercore-release-key.jks EOF
3. Secure the files
chmod 600 android/key.properties chmod 600 ~/truckercore-release-key.jks
4. Backup keystore securely
Store in password manager or secure vault
``` 

### Week 2: Testing & Validation

#### Day 8-9: Local Testing
```
bash
1. Run final checks
./scripts/final_checks.sh
2. Run all tests
flutter test
3. Build and test locally
flutter run --dart-define=SUPABASE_URL=SUPABASE_URL \ --dart-define=SUPABASE_ANON=SUPABASE_ANON
--dart-define=USE_MOCK_DATA=false
4. Test all user flows
- Login as driver, owner operator, fleet manager
- Verify data loading
- Test offline mode (driver app)
- Test CRUD operations
``` 

#### Day 10-11: Device Testing

**Driver App (Mobile):**
```
bash
Build and install on physical devices
flutter build apk --release
--dart-define=SUPABASE_URL=SUPABASE_URL \ --dart-define=SUPABASE_ANON=SUPABASE_ANON
Install on Android device
adb install build/app/outputs/flutter-apk/app-release.apk
Test on device:
✅ Login/logout
✅ Dashboard loads
✅ Loads list works
✅ HOS tracking
✅ Offline mode (airplane mode)
✅ Data syncs when back online
✅ Settings screen
``` 

**Desktop Apps:**
```
bash
Build owner operator dashboard
./scripts/build_desktop.sh owner-operator windows
Build fleet manager
./scripts/build_desktop.sh fleet-manager windows
Test on desktop:
✅ Login works
✅ Dashboard displays data
✅ CRUD operations work
✅ Multi-window opens
✅ Reports generate
✅ Data exports work
``` 

```
bash
1. Test with realistic data volumes
Add test data in Supabase:
- 50+ vehicles
- 100+ drivers
- 500+ loads
- 1000+ HOS records
2. Monitor performance
- Load times < 2 seconds
- Smooth scrolling
- No memory leaks
- No crashes
3. Test network conditions
- Slow 3G
- Flaky connection
- Offline mode
``` 

#### Day 13-14: Security Audit
```
bash
1. Verify no secrets in code
grep -r "supabase.co" lib/ --include=".dart" grep -r "eyJ" lib/ --include=".dart"
2. Check .gitignore
cat .gitignore | grep -E ".env|key.properties"
3. Verify RLS policies in Supabase
Check each table has appropriate policies
4. Test role-based access
- Driver can only see own data
- Owner operator can see fleet data
- Fleet manager can see all fleets
5. Test authentication edge cases
- Invalid credentials
- Expired sessions
- Role changes
``` 

## Launch Week

### Day L-3: Store Submission Prep

#### Google Play (Android)
```
bash
1. Generate store assets
./scripts/generate_store_assets.sh
2. Capture screenshots (5+)
- Login screen
- Dashboard
- Loads list
- HOS view
- Settings
3. Prepare store listing
- App name: TruckerCore Driver
- Short description (80 chars)
- Full description (4000 chars)
- Category: Business
- Content rating: Everyone
- Privacy policy URL
``` 

**Google Play Console Setup:**
1. Create app: https://play.google.com/console
2. Complete store listing
3. Upload screenshots
4. Set up pricing (Free/Paid)
5. Upload AAB to Internal Testing track
6. Test with internal testers
7. Promote to Production when ready

#### Apple App Store (iOS)
```
bash
1. Setup in App Store Connect
Visit: https://appstoreconnect.apple.com
2. Prepare metadata
- App name
- Subtitle
- Description
- Keywords
- Screenshots (multiple sizes)
- App icon (1024x1024)
3. Build and upload
flutter build ipa --release
--dart-define=SUPABASE_URL=SUPABASE_URL \ --dart-define=SUPABASE_ANON=SUPABASE_ANON
Upload via Xcode or Transporter app
``` 

#### Desktop Distribution
```
bash
1. Create download page on website
2. Generate installers
./scripts/build_desktop.sh owner-operator windows ./scripts/build_desktop.sh owner-operator macos ./scripts/build_desktop.sh fleet-manager windows ./scripts/build_desktop.sh fleet-manager macos
3. Sign executables (Windows/macOS)
Windows: signtool
macOS: codesign + notarization
4. Create installation guides
5. Upload to distribution server
``` 

### Day L-2: Final Verification
```
bash
Run complete pre-launch checklist
./scripts/final_checks.sh
Review checklist
cat PRE_LAUNCH_CHECKLIST.md
Verify all items checked
- Security ✅
- Testing ✅
- Documentation ✅
- Store submissions ✅
- Monitoring setup ✅
``` 

### Day L-1: Rehearsal
```
bash
1. Do a complete dry run
./scripts/launch.sh
(Select 'no' when asked about production)
2. Verify all artifacts created
ls -la releases/
3. Test installation of all builds
- Install APK on Android
- Install desktop apps
- Verify they connect to production
4. Prepare launch announcement
- Blog post
- Email to users
- Social media posts
5. Brief support team
- How to access logs
- Common issues
- Escalation process
``` 

### Launch Day! 🚀

#### Morning (09:00)
```
bash
1. Final health check
./scripts/monitor_production.sh
2. Verify Supabase status
Visit: https://status.supabase.com
3. Verify Sentry ready
Visit: https://sentry.io
4. Open monitoring dashboards
- Supabase Dashboard
- Sentry Dashboard
- Server logs (if applicable)
``` 

#### Launch (10:00)
```
bash
Execute launch script
./scripts/launch.sh
Follow prompts and verify each step
``` 

**Manual steps after script:**

1. **Submit mobile apps** (if not done in L-3)
   - Upload to Google Play: Production track
   - Submit to App Store: For review

2. **Publish desktop installers**
   - Upload to website
   - Update download links
   - Verify downloads work

3. **Update website**
   - Publish landing page
   - Enable download buttons
   - Publish documentation

4. **Send announcements**
   - Email existing users
   - Post on social media
   - Publish blog post

5. **Monitor systems** (First 2 hours)
   - Watch Sentry for errors
   - Check Supabase metrics
   - Monitor user signups
   - Check support channels

#### Afternoon (14:00)

**4-hour check:**
- ✅ No critical errors in Sentry
- ✅ Users able to sign up
- ✅ All APIs responding
- ✅ No support escalations

**If issues found:**
```
bash
Check logs
flutter logs # For mobile ./scripts/monitor_production.sh
View Sentry errors
Visit: https://sentry.io/[your-project]/issues
Rollback if needed
Revert to previous version
Notify users
``` 

#### Evening (18:00)

**End of day review:**
- Total signups: _____
- Critical errors: _____
- Support tickets: _____
- App store status: _____

**Team debrief:**
- What went well?
- What issues occurred?
- What needs immediate attention?

## Post-Launch (Week 1)

### Daily Tasks
```
bash
Morning check (09:00)
./scripts/monitor_production.sh
Review metrics:
- Daily active users
- Error rate (should be < 1%)
- API response times
- Crash rate
Check support channels:
- Email support
- In-app feedback
- App store reviews
- Social media mentions
``` 

### Week 1 Checklist

- [ ] Monitor Sentry daily for new errors
- [ ] Respond to app store reviews
- [ ] Address critical bugs within 24h
- [ ] Collect user feedback
- [ ] Track key metrics:
  - Daily Active Users (DAU)
  - Retention (Day 1, Day 7)
  - Crash-free rate (target: >99%)
  - Average session duration
- [ ] Plan hotfix release if needed

### Common Post-Launch Issues

**High crash rate:**
```
bash
Check Sentry for patterns
Identify affected device/OS versions
Prepare hotfix
Test thoroughly
Release emergency update
``` 

**Slow API responses:**
```
bash
Check Supabase metrics
Identify slow queries
Add database indexes
Optimize queries
Enable caching
``` 

**User confusion:**
```
bash
Collect feedback
Identify pain points
Update onboarding
Add tooltips/help text
Create tutorial videos
``` 

## Success Metrics


- [ ] 100+ signups
- [ ] 4.0+ star rating
- [ ] <1% error rate
- [ ] >95% crash-free rate
- [ ] <2s average load time

- [ ] 500+ active users
- [ ] 4.5+ star rating
- [ ] <0.5% error rate
- [ ] >99% crash-free rate
- [ ] 50%+ Day 7 retention

## Emergency Contacts

**Technical Issues:**
- Lead Developer: [email/phone]
- DevOps: [email/phone]
- Database Admin: [email/phone]

**Business Issues:**
- Product Owner: [email/phone]
- Customer Support Lead: [email/phone]
- Marketing Lead: [email/phone]

**External Services:**
- Supabase Support: https://supabase.com/support
- Sentry Support: https://sentry.io/support
- App Store Support: https://developer.apple.com/contact
- Google Play Support: https://support.google.com/googleplay/android-developer

## Rollback Procedure

If critical issues require rollback:
```
bash
1. Stop new deployments
2. Identify last stable version
3. Restore from backup:
git checkout v[previous-version]
4. Rebuild and redeploy
./scripts/release.sh
5. Notify users
6. Investigate root cause
7. Fix and prepare new release
8. Test thoroughly
9. Redeploy
``` 


**Next steps:**
1. Monitor for first week
2. Collect user feedback
3. Plan version 1.1 features
4. Iterate and improve

---

**Remember:** A launch is just the beginning. The real work is in iteration, user support, and continuous improvement.

**Good luck! 🚛💨**