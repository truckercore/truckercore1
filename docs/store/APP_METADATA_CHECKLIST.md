# App Store / Google Play — Metadata & Assets Checklist

App identifiers and accounts
- [ ] Bundle ID (iOS): com.example.truckercore
- [ ] Application ID (Android): com.example.truckercore
- [ ] App name reserved in both stores
- [ ] Category, age rating questionnaires completed

Legal and policies
- [ ] Privacy Policy URL published (see docs/policies/urls.json)
- [ ] Terms/EULA URL published (see docs/policies/urls.json)
- [ ] In‑app Privacy Policy link accessible

Descriptions
- [ ] Short description / subtitle (≤80 chars)
- [ ] Long description with key features and plan gating notes
- [ ] Promo text (optional)

Assets
- [ ] App icons (iOS and Android) provided
- [ ] Screenshots: phone and tablet
- [ ] Optional preview video

Data disclosures
- [ ] App Store privacy labels (analytics, app functionality, fraud prevention)
- [ ] Google Play Data Safety: data collected/shared, security practices, deletion policy

Review notes (attach this doc)
- [ ] Reviewer creds (staging), steps (start tracking, indicator, stop)
- [ ] Permission screenshots + rationale
- [ ] Background tracking explanation + opt‑out

Tracks and rollout
- [ ] iOS TestFlight internal/external set up
- [ ] Android internal → closed → production with staged rollout
- [ ] Pre‑launch report enabled (Android)

Telemetry and diagnostics
- [ ] Sentry DSN per environment; tags include OS, app version, commit, plan tier, locale
- [ ] About/Diagnostics page show version and commit (or include in review notes)
