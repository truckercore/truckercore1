# Versions and Upgrade Guide

Pinned toolchain and important dependencies for deterministic CI builds. Update with caution and follow the bump guide below.

## Current Versions (CI)
- Flutter: 3.35.1
- Dart: 3.9.0
- DevTools: 2.48.0
- Android Gradle Plugin (AGP): 8.x (see android/build.gradle)
- Gradle: see android/gradle/wrapper/gradle-wrapper.properties
- Kotlin: per android/build.gradle
- Java: 17 (recommended)
- Node: 18 LTS (only when hacking on Edge Functions locally)

## How to bump versions
1. Create a PR with:
   - Update Flutter version in .github/workflows/ci.yml (subosito/flutter-action flutter-version) and README.md.
   - If Android toolchain is bumped, update AGP/Gradle/Kotlin versions in android/ and run a local build.
   - If Node is required for functions, document any new minimum in this file.
2. Run locally:
   - dart format .
   - flutter pub get
   - flutter analyze
   - flutter test --coverage
   - Optionally run platform builds (web/Android) to smoke check.
3. CI must pass analyze, tests, coverage check, and build smoke.
4. Update CHANGELOG.md with:
   - What changed (versions), why, and rollback steps.
5. After merge, tag the commit if it’s a release boundary.

## Rollback plan
- Revert the PR.
- If Android build tools changed, restore previous AGP/Gradle wrapper and invalidate caches.
- If Flutter channel caused regressions, reinstall prior pinned version and rerun CI.
