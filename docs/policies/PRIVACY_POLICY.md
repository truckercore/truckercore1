# Privacy Policy (TruckerCore)

Last updated: 2025-09-18

This Privacy Policy describes what data the TruckerCore apps collect, why we collect it, where it is processed, and your choices.

What we collect
- Account: email, name (if provided), organization ID, and plan tier.
- App telemetry: crash/error diagnostics, performance timings (e.g., cold start), and anonymous feature usage events. No ad tracking identifiers.
- Location (drivers only): GPS positions and derived signals (speed/activity), collected only when tracking is turned on by the driver or by dispatch policy. Background location may be collected when explicitly enabled for the driver app.

Why we collect it
- App functionality: login/session, dispatch, loads, chat, and analytics.
- Driver and fleet features: routing, compliance (HOS, inspections), and optional geofencing alerts.
- Reliability and safety: crash diagnostics and performance to improve stability.

Where data is processed and stored
- Primary storage: Supabase (PostgreSQL) in the region configured for your workspace (default US). Telemetry may be processed by Sentry (error/crash analytics) in their regional infrastructure.
- We do not sell personal data. Data is shared with service providers strictly to operate the product.

Controls
- Tracking controls: clear Start/Pause/Resume in-app; a persistent indicator shows when tracking is active.
- Privacy: You can request data export or deletion via support.
- Feature flags: geofencing, chat, and boosts are controlled by plan tier and environment; defaults are conservative (off) in production until pilot sign-off.

Retention
- GPS raw positions: retained for up to 90 days by default, with longer-lived aggregates (totals, trends). See docs/GPS_HARDENING.md.
- Telemetry: crash/error logs retained per provider defaults (e.g., 90 days) unless required for safety investigations.

Contact
- Email: support@example.com
- Website: https://www.example.com

Legal bases (if applicable)
- Consent: for background location and notifications.
- Legitimate interests: to provide core app functionality and improve reliability.

Note: Replace example URLs and contact details with your production endpoints prior to submission.