# Release Checklist

## Driver App (Mobile)

### Authentication
- [ ] Login with email/password
- [ ] Password reset flow
- [ ] Session persistence
- [ ] Role verification (driver role)
- [ ] Logout functionality

### Core Features
- [ ] View assigned loads
- [ ] Start/end shift
- [ ] Real-time location tracking
- [ ] Offline mode support
- [ ] Document upload (BOL, POD, etc.)
- [ ] HOS compliance tracking
- [ ] Route navigation integration

### Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Tested on Android physical device
- [ ] Tested on iOS physical device
- [ ] Offline functionality verified
- [ ] Performance tested (battery, memory)

### Build & Deploy
- [ ] Production build successful
- [ ] App signed properly
- [ ] App store metadata ready
- [ ] Privacy policy updated
- [ ] Terms of service updated

---

## Owner Operator Dashboard (Desktop)

### Authentication
- [ ] Login with email/password
- [ ] Role verification (owner_operator role)
- [ ] Session persistence across app restarts

### Core Features
- [ ] Fleet overview dashboard
- [ ] Vehicle status monitoring
- [ ] Driver management
- [ ] Load management (create, edit, delete)
- [ ] Route planning
- [ ] Reports and analytics
- [ ] Multi-window support
- [ ] Data export (CSV, PDF)
- [ ] Document management

### Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Tested on Windows
- [ ] Tested on macOS
- [ ] Tested on Linux
- [ ] Multi-window functionality verified
- [ ] Performance tested

### Build & Deploy
- [ ] Windows installer created
- [ ] macOS DMG created
- [ ] Linux package created
- [ ] Code signing configured
- [ ] Auto-update mechanism tested

---

## Fleet Manager (Desktop)

### Authentication
- [ ] Login with email/password
- [ ] Role verification (fleet_manager role)
- [ ] Multi-org support

### Core Features
- [ ] Multi-fleet dashboard
- [ ] Cross-fleet analytics
- [ ] User management (CRUD)
- [ ] Role assignment
- [ ] Advanced reporting
- [ ] Compliance tracking
- [ ] Audit logs
- [ ] System configuration

### Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Tested on Windows
- [ ] Tested on macOS
- [ ] Tested on Linux
- [ ] Multi-fleet scenarios tested
- [ ] Performance tested (large datasets)

### Build & Deploy
- [ ] Windows installer created
- [ ] macOS DMG created
- [ ] Linux package created
- [ ] Code signing configured
- [ ] Auto-update mechanism tested

---

## Common (All Platforms)

### Security
- [ ] Environment variables properly configured
- [ ] No secrets in codebase
- [ ] HTTPS only
- [ ] JWT validation working
- [ ] RLS policies verified in Supabase
- [ ] Input validation on all forms

### Observability
- [ ] Sentry error tracking configured
- [ ] Analytics events configured
- [ ] Performance monitoring enabled
- [ ] Crash reporting tested

### Documentation
- [ ] User manual created
- [ ] Installation guide created
- [ ] API documentation updated
- [ ] Changelog updated
