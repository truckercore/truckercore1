# Release Checklist (Lightweight)

- Pre-flight
  - [ ] CHANGELOG updated and version bumped.
  - [ ] All CI pipelines green on main.
  - [ ] Secrets set in CI/CD for this release.
- Build with dart-define for SUPABASE_URL, SUPABASE_ANON, MAPBOX_TOKEN.
  - [ ] For Flutter/mobile builds, prefer SUPABASE_ANON; legacy SUPABASE_ANON_KEY is supported but deprecated.
  - [ ] For Web/Next.js, continue using NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY.
- Environment validation
  - [ ] SUPABASE_URL present and correct.
  - [ ] SUPABASE_ANON present; if falling back to SUPABASE_ANON_KEY, note deprecation in release notes.
  - [ ] Any required third-party tokens present (e.g., MAPBOX_TOKEN, STRIPE_PUBLIC_KEY).
- QA smoke
  - [ ] App launches and Supabase initializes before any client calls.
  - [ ] Sign-in, basic navigation, and one read/write operation complete successfully.
- Tag-gated signing (if applicable)
  - [ ] Signing keys/keystores available and configured for the tagged release.
  - [ ] Platform-specific signing verified (Android/iOS).

# Edge Functions Runtime

- Environment variables
  - [ ] SUPABASE_URL set.
  - [ ] SUPABASE_ANON preferred; fallback to SUPABASE_ANON_KEY logs deprecation warning.
- Observability
  - [ ] Logs verified for no deprecation warnings in steady state.
  - [ ] Basic function invocation smoke-tested (200/OK, expected payload).
- Deployment
  - [ ] Version/tag matches app release.
  - [ ] Rollback plan documented.

# CI Artifacts

- [ ] Mobile build artifacts archived (APK/AAB/IPA as applicable).
- [ ] Web build output produced and uploaded to target environment.
- [ ] Source maps uploaded where required.
- [ ] Checksums/signatures generated and stored.

# Release Notes

- [ ] Document environment variable standardization:
  - SUPABASE_ANON is now preferred.
  - SUPABASE_ANON_KEY is deprecated and retained for backward compatibility.
  - NEXT_PUBLIC_SUPABASE_ANON_KEY remains unchanged for web.
- [ ] Note any migration or manual steps.
- [ ] Acknowledge non-applicable features as N/A.

# Post-Release

- [ ] Monitor error rates, performance, and logs for 24–48 hours.
- [ ] Confirm analytics/events flowing as expected.
- [ ] Close milestone and triage any follow-up issues.
