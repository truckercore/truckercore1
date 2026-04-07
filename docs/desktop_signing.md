# Desktop Signing, Notarization, and Verification

This document describes how we sign and verify desktop artifacts for macOS, Windows, and Linux, and how CI integrates the required secrets.

## Overview
- CI workflow: .github/workflows/release-desktop.yml builds desktop apps on macOS, Windows, and Linux.
- If signing secrets are present, platform-specific signing runs automatically and the build will fail if verification does.
- Artifacts are uploaded with checksums and, on Linux, detached GPG signatures. SBOM is optionally attached.

## macOS
- Build: `flutter build macos --release`
- Entitlements: macos/Runner/Release.entitlements enables hardened runtime-safe capabilities (network client) and disables debug entitlements. We sign with `--options runtime`.
- Signing and Notarization:
  - Script: `scripts/sign/macos_sign.sh <path/to/App.app>`
  - Imports the Developer ID Application certificate (P12) into a temporary keychain.
  - Codesigns the .app with hardened runtime and the above entitlements.
  - Submits a zipped app to Apple Notary service via `notarytool` using an App Store Connect API key, waits for success, then staples the ticket.
  - Verifies with both `spctl --assess` and `codesign --verify --deep --strict --verbose=2`.

- Required CI secrets:
  - `MACOS_CERT_P12`: base64 P12 (Developer ID Application)
  - `MACOS_CERT_PASSWORD`: P12 password
  - `MACOS_TEAM_ID`: Apple Team ID
  - `MACOS_BUNDLE_ID`: Bundle ID (e.g., com.truckercore.app)
  - `NOTARYTOOL_KEY_ID`, `NOTARYTOOL_ISSUER_ID`, `NOTARYTOOL_KEY` (base64 .p8)

- Local verification commands:
```
spctl --assess --type execute --verbose path/to/App.app
codesign --verify --deep --strict --verbose=2 path/to/App.app
```

- Cert source and runner type:
  - Cert: Apple Developer ID Application certificate in an HSM-backed keychain where possible; for CI we import a P12 during the job.
  - Runner: `macos-latest` GitHub-hosted runner. Notarization relies on App Store Connect API key (OIDC not available; use secrets).

## Windows
- Build: `flutter build windows --release`
- Signing:
  - Script: `scripts/sign/windows_sign.ps1`
  - Signs the EXE (and MSIX if present) with `signtool sign /tr <timestamp>` using SHA256 and verifies with `signtool verify /pa /v`.
- Required CI secrets:
  - `WIN_CERT_PFX`: base64 PFX (code signing cert)
  - `WIN_CERT_PASSWORD`: PFX password
  - `TIMESTAMP_URL`: e.g., `http://timestamp.acs.microsoft.com` or `http://timestamp.digicert.com`
- SmartScreen reputation accumulates over time as the signed file is downloaded and executed by users.
- Cert source and runner type:
  - Cert: EV Code Signing cert stored in an HSM or cloud KMS (preferred). In CI we currently accept a PFX secret; long-term recommendation is Azure Key Vault/HSM with GitHub OIDC.
  - Runner: `windows-latest` GitHub-hosted runner with Windows SDK tools (signtool) available.

- Verification commands:
```
signtool verify /pa /v path\to\AppInstaller.msix
signtool verify /pa /all /v path\to\App.exe
```

## Linux
- Build: `flutter build linux --release` then zipped bundle for distribution, or build an AppImage using linuxdeploy/appimagetool in a future iteration.
- Signing and checksums:
  - Script: `scripts/sign/linux_sign.sh <artifact>` produces `<artifact>.sha256` and a detached ASCII signature `<artifact>.asc` and verifies it.
- Required CI secrets:
  - `GPG_PRIVATE_KEY`: base64-encoded private key
  - `GPG_PASSPHRASE`: (optional) passphrase
- Verification commands:
```
sha256sum -c AppImage.sha256
gpg --verify path/to/AppImage.asc path/to/AppImage
```
- Cert source and runner type:
  - Key: Project-maintained GPG key pair stored in GitHub Secrets; imported during the job only.
  - Runner: `ubuntu-latest`.

## CI Hardening
- Artifact naming: `TruckerCore-<version>-<platform>-<arch>.<ext>` plus `.sha256` and `.asc` (Linux).
- Reproducibility: Toolchain pinned via Flutter action channel; no signed artifacts cached.
- Post-build verification: If codesign/spctl/signtool/gpg verify steps fail, jobs fail.
- SBOM: optional via `anchore/sbom-action`.

## Install, Update, Uninstall
- macOS: distribute as a signed, notarized `.app` within a `.zip` or `.dmg`. App translocation-safe (no hard-coded absolute paths). Gatekeeper must pass.
- Windows: distribute signed MSIX or installer. Our CI verifies signatures; SmartScreen reputation improves after release.
- Linux: provide zipped bundle and/or AppImage with checksums and detached signature. Test on Ubuntu LTS and Fedora.

## Auto-updates (strategy)
- macOS: Sparkle for outside-App-Store distributions (not yet integrated).
- Windows: MSIX/App Installer auto-updates or a custom updater (not yet integrated).
- Linux: AppImageUpdate or repo-based updates (not yet integrated).

## Runtime Validation
- Multi-monitor, HiDPI scaling, light/dark modes, locale/timezone, proxies: manual/QA checks. CI smoke launches the app to assert dependencies.
- Inputs: Keyboard-only navigation and basic a11y pass; drag-and-drop is supported on desktop (see CsvImportDropzone).
- Files/OS integrations: Open/save dialogs, URL launching, printing support (printing/pdf deps in pubspec).
- Performance: First frame time logged at startup; Sentry breadcrumb includes elapsed_ms.

## Crash and Diagnostics
- Sentry initialized when SENTRY_DSN is provided; FlutterError and zone uncaught exceptions captured.
- Include build/version in About dialog (roadmap) and crash reports (Sentry tags recommended).

## Supply Chain & Provenance (optional)
- Checksums and GPG signatures are uploaded alongside artifacts.
- SBOM published as `sbom-<runner>.spdx.json`.
- Consider GitHub Attestations/SLSA for artifact provenance in a future iteration.

## Putting It Together
- For tagged releases (`v*`) or manual dispatch with `version`, CI builds the three platforms.
- If signing secrets exist, macOS will sign/notarize/staple; Windows will code-sign; Linux will produce checksums and a detached GPG signature.
- Post-build verification runs. Artifacts are uploaded with versioned names plus `.sha256` and, on Linux, `.asc`.
