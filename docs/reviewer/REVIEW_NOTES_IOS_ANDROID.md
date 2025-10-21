# Reviewer Notes (iOS and Android)

Last updated: 2025-09-18

Demo credentials (staging)
- Email: reviewer@example.com
- Password: provided in review notes (or create via "Sign up" and follow onboarding)

Primary flows to test
1) Start the app and log in with the demo account.
2) Navigate to Driver Dashboard.
3) Start tracking using the card with Start/Pause/Resume controls.
   - A persistent indicator shows tracking is active.
4) Pause tracking and verify indicator turns off.
5) Visit Preferences, update pickups window, and save.
6) Return to Dashboard; cards update accordingly.

Permissions and background modes
- iOS:
  - Info.plist includes NSLocationWhenInUseUsageDescription and NSLocationAlwaysAndWhenInUseUsageDescription (for background tracking, if enabled), NSMotionUsageDescription only if activity recognition is used.
  - UIBackgroundModes includes "location"; background fetch is disabled unless explicitly used.
- Android:
  - Manifest requests ACCESS_FINE_LOCATION (and ACCESS_COARSE_LOCATION if used), ACCESS_BACKGROUND_LOCATION for background tracking (with in-app education flow), FOREGROUND_SERVICE_LOCATION, and POST_NOTIFICATIONS (if notifications shown). A persistent foreground service notification is displayed while tracking.

Privacy and controls
- In-app privacy policy link is in the Settings/About area (planned) and available via: docs/policies/PRIVACY_POLICY.md (public URL in urls.json).
- "When we track": Only while the driver has started tracking or while a shift is active according to fleet policy. Clear controls and a visible indicator are present. Users can pause at any time.

Telemetry
- Crash/error telemetry (Sentry) is configured via environment per build. We attach tags: OS, app version, commit, plan tier, and locale.

Geofencing and plan metering (P1 alignment)
- When enabled by flag, entering/exiting configured zones generates events subject to plan limits. If limits are reached, toggles will show clear messaging and events are blocked gracefully.

Reviewer screenshots
- Include permissions prompts with rationale, tracking on indicator, Start/Pause/Resume controls, and the privacy policy link.

Notes
- Country targeting: we recommend starting with primary markets only while background tracking policies are reviewed for other regions.
- Disable background tracking by default until the pilot is approved; use feature flags to enable.
