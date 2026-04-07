# Installer Build & Code Signing Guide

This document captures the practical steps to build desktop installers for Windows, macOS, and Linux, and how to sign/notarize them for distribution. The goal is to keep builds reproducible in CI while enabling local developer builds for QA.

Note: All secrets (certificates, Apple API keys, passwords) must be stored in your CI secret store and never committed.

## Prerequisites
- Flutter 3.19+ (stable)
- Dart SDK that matches Flutter
- Platform SDKs installed and configured: Xcode (macOS), MSIX Tooling (Windows), required Linux packaging tools
- A valid version string in pubspec.yaml (e.g., 1.12.3+1123)
- Set APP_VERSION and GIT_COMMIT via --dart-define for telemetry correlation

## Common Build Flags
- --release
- --dart-define=APP_VERSION=$(git describe --tags --always)
- --dart-define=GIT_COMMIT=$(git rev-parse --short HEAD)
- --dart-define=RELEASE_CHANNEL=stable (or beta/canary)
- --dart-define=SENTRY_DSN=... (optional)

## Windows (MSIX)

We recommend MSIX for modern Windows deployments. You can also produce a standalone EXE installer using third-party tooling, but MSIX is first-class in Flutter and supports auto-updates via App Installer.

1) Prepare signing certificate
- Obtain a code signing certificate (EV recommended). For internal builds, you can use a self-signed cert.
- Export to a PFX with password.
- Store the PFX and password in CI secrets.

2) Configure msix in pubspec.yaml
Add a msix_config section (if not present). Example:

```
msix_config:
  display_name: TruckerCore
  publisher_display_name: Your Company, Inc.
  identity_name: com.yourco.truckercore
  publish_folder_path: build\windows\msix
  msix_version: 1.0.0.0
  logo_path: assets\icons\app_icon.png
  capabilities: [internetClient]
```

3) Build MSIX locally
```
flutter pub run msix:create 
```
Or via flutter build:
```
flutter build windows --release
```
Then run msix:create to package.

4) Sign MSIX
Using signtool:
```
signtool sign /fd SHA256 /a /f path\to\cert.pfx /p $Env:CERT_PWD build\windows\msix\TruckerCore.msix
```

5) App Installer (optional, for updates)
Publish an App Installer .appinstaller XML pointing to your MSIX in a CDN, and configure the update URI. See docs/APP_UPDATES_DESKTOP.md.

## macOS (codesign + notarization)

1) Credentials
- Apple Developer account
- App-specific password or App Store Connect API key (Issuer/Key ID + private key)
- Developer ID Application certificate installed on the CI runner (or use a fastlane match-like flow)

2) Build app
```
flutter build macos --release 
```
App bundle path: build/macos/Build/Products/Release/TruckerCore.app

3) Codesign
```
codesign \
  --force --deep --options runtime \
  --sign "Developer ID Application: Your Company (TEAMID)" \
  build/macos/Build/Products/Release/TruckerCore.app
```

4) Create notarization zip
```
/usr/bin/ditto -c -k --keepParent \
  build/macos/Build/Products/Release/TruckerCore.app \
  TruckerCore.app.zip
```

5) Notarize (API key or app-specific password)
Using notarytool (preferred):
```
xcrun notarytool submit TruckerCore.app.zip \
  --apple-id $APPLE_ID \
  --team-id $TEAM_ID \
  --password $APPLE_APP_PWD \
  --wait
```
or with API key:
```
xcrun notarytool submit TruckerCore.app.zip \
  --key-id $ASC_KEY_ID \
  --issuer $ASC_ISSUER_ID \
  --key $ASC_PRIVATE_KEY_PATH \
  --wait
```

6) Staple
```
xcrun stapler staple build/macos/Build/Products/Release/TruckerCore.app
```

7) Distribute
- Zip and upload, or create a DMG (create-dmg) and distribute the DMG.

## Linux

Multiple options exist; simplest are AppImage or deb/rpm packages.

### AppImage
1) Build Linux app:
```
flutter build linux --release
```
2) Package into AppImage using appimagetool or appimage-builder. Provide .desktop and icon.
3) Sign with gpg (optional):
```
gpg --detach-sign --armor TruckerCore-x86_64.AppImage
```

### Debian package (deb)
1) Use fpm to package the build output into a .deb
2) Sign the repo with GPG if hosting your own apt repo.

## CI Tips
- Use matrix builds for windows-latest, macos-latest, ubuntu-latest
- Cache Flutter and pub
- Inject signing materials at runtime; never commit them
- Emit provenance (SBOM, checksums) and upload to release artifacts

## Troubleshooting
- Codesign failures: check entitlements and TEAMID match
- Notarization rejects: open the notary log URL for specifics
- MSIX install blocked: ensure certificate trusted on the machine (for self-signed) or use a trusted CA cert
