# TruckerCore - One Page Overview

## What Is It?

**TruckerCore** is a complete fleet management system with three applications:
1. **Driver App** (Mobile) - For truck drivers
2. **Owner Operator Dashboard** (Desktop) - For fleet owners
3. **Fleet Manager** (Desktop) - For multi-fleet management

## Tech Stack

- **Frontend:** Flutter 3.24.0
- **Backend:** Supabase (PostgreSQL + Real-time)
- **State:** Riverpod
- **Auth:** Supabase Auth (JWT + RLS)
- **Monitoring:** Sentry

## Quick Start (5 min)

```bash
git clone <repo>
cd truckercore1
flutter pub get
cp .env.example .env
# Edit .env with your Supabase credentials
flutter run
```

---

Build for Production
```bash
# Mobile
./scripts/build_driver_app.sh

# Desktop
./scripts/build_desktop.sh owner-operator windows
./scripts/build_desktop.sh fleet-manager macos
```

Launch
```bash
./scripts/final_checks.sh  # Verify readiness
./scripts/launch.sh        # Launch to production
```

---

## Key Features

### Driver App
- ✅ HOS tracking
- ✅ Load management
- ✅ Offline support
- ✅ Real-time updates

### Owner Operator
- ✅ Fleet dashboard
- ✅ Vehicle/driver management
- ✅ Reports & analytics
- ✅ Load assignment

### Fleet Manager
- ✅ Multi-fleet view
- ✅ User management
- ✅ Compliance tracking
- ✅ Audit logging

## Documentation
- Full Docs: [docs/INDEX.md](INDEX.md)
- Quick Start: [docs/QUICK_START.md](QUICK_START.md)
- Launch Guide: [docs/LAUNCH_GUIDE.md](LAUNCH_GUIDE.md)

## Support
- Issues: GitHub Issues
- Email: support@truckercore.com
- Docs: https://docs.truckercore.com

## Status
✅ Production Ready - v1.0.0

All features complete, tested, and documented. Ready for launch.

See docs/INDEX.md for complete documentation.
