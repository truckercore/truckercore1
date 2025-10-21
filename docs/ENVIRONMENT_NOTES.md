# Environment & Configuration Hardening

This app centralizes configuration via the AppConfig provider. For mobile/web builds, pass secrets via `--dart-define`.

Recommended defines:
- SUPABASE_URL
- SUPABASE_ANON
  - Prefer SUPABASE_ANON for all mobile/Flutter builds (via --dart-define or .env).
  - Legacy fallback: SUPABASE_ANON_KEY is still accepted for backward compatibility.
  - Deprecation: SUPABASE_ANON_KEY is deprecated and will be removed in a future release.
- MAPBOX_TOKEN (optional for map tiles)

Example (Android):
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR.supabase.co \
  --dart-define=SUPABASE_ANON=ey... \
  --dart-define=MAPBOX_TOKEN=pk.xxx

Do not commit secrets. Keep them out of source control.

## Android specifics (SDK 36 readiness)
- Ensure INTERNET permission (AndroidManifest.xml).
- If using local dev endpoints over HTTP, set a network security config allowing cleartext for `10.0.2.2` and reference it in the Application tag.
- Location permissions: request runtime permissions if adding background/foreground location. Foreground service is required for persistent background updates on SDK 34+.
- Notifications: request POST_NOTIFICATIONS permission on Android 13+ if used.
- exported flags: all activities with intent-filters should declare `android:exported`.

## iOS/macOS
- Add NSLocationWhenInUseUsageDescription if you add live location.

## Web
- Set NEXT_PUBLIC_* variables for Next.js app (`NEXT_PUBLIC_BASE_URL`, `NEXT_PUBLIC_MAPBOX_TOKEN`) in Vercel/host.
- Continue using NEXT_PUBLIC_SUPABASE_ANON_KEY for web clients.
- On server/Edge Functions, SUPABASE_ANON is preferred; legacy SUPABASE_ANON_KEY will log a deprecation warning if used.

> Note: Any references to SUPABASE_ANON_KEY in this repository are for documentation or fallback purposes only and are deprecated.
