# Basic Sentry APM Integration

This project includes a minimal, non‑disruptive Sentry performance tracing setup for the Flutter app.

What’s included:
- Conditional Sentry initialization in lib/main.dart (only active when SENTRY_DSN is provided).
- Auto performance tracing enabled with a conservative sampling rate (10% in release builds, 100% in debug).
- Navigation tracing via SentryNavigatorObserver wired into GoRouter (MaterialApp.router) and dashboard MaterialApps.
- No PII collection by default; screenshots disabled.
- Optional profiles sampling (disabled by default; can be enabled via dart-define).

How to enable
- Provide a Sentry DSN at build time:
  - flutter run --dart-define=SENTRY_DSN="https://<key>@o<org>.ingest.sentry.io/<project>"
  - Optionally set a profiles sample rate: --dart-define=SENTRY_PROFILES_SAMPLE_RATE=0.1
  - Other optional tags already wired via --dart-define (if present): APP_VERSION, GIT_COMMIT, RELEASE_CHANNEL

Defaults
- tracesSampleRate: 0.1 in release, 1.0 in debug
- enableAutoPerformanceTracing: true
- profilesSampleRate: 0.0 (off) unless overridden via SENTRY_PROFILES_SAMPLE_RATE
- attachScreenshot: false
- sendDefaultPii: false

Notes
- If SENTRY_DSN is not provided, Sentry is not initialized and the app behaves as before.
- Navigation spans are collected via SentryNavigatorObserver for:
  - Main app router (GoRouter)
  - Dashboard MaterialApp instances (including the UnknownDashboard fallback)
- HTTP span auto‑instrumentation is not enabled to minimize risk; can be added later via SentryHttpClient or dio integration if needed.

Troubleshooting
- Verify DSN is passed correctly (String.fromEnvironment reads dart‑defines at compile/run time).
- To validate in development, run with --verbose and check logs in Sentry project for new transactions.
- If performance overhead is a concern, lower tracesSampleRate or disable via removing SENTRY_DSN.
