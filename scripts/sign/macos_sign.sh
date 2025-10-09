#!/usr/bin/env bash
set -euo pipefail

# macos_sign.sh
# Signs a built .app with hardened runtime, notarizes, staples, and verifies.
# Requirements (provided via env/CI secrets):
#  - MACOS_CERT_P12: base64-encoded Developer ID Application certificate (.p12)
#  - MACOS_CERT_PASSWORD: password for the .p12
#  - MACOS_TEAM_ID: Apple Team ID (e.g., ABCDE12345)
#  - MACOS_IDENTITY: Signing identity CN (optional if using SHA-1 hash)
#  - MACOS_BUNDLE_ID: Bundle identifier (e.g., com.truckercore.app)
#  - NOTARYTOOL_KEY_ID: App Store Connect API Key ID
#  - NOTARYTOOL_ISSUER_ID: App Store Connect Issuer ID
#  - NOTARYTOOL_KEY: Base64-encoded .p8 private key contents
#
# Usage:
#   scripts/sign/macos_sign.sh path/to/App.app

APP_PATH=${1:-}
if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "Usage: $0 path/to/App.app" >&2
  exit 1
fi

if [[ -z "${MACOS_CERT_P12:-}" || -z "${MACOS_CERT_PASSWORD:-}" || -z "${MACOS_TEAM_ID:-}" || -z "${MACOS_BUNDLE_ID:-}" || -z "${NOTARYTOOL_KEY_ID:-}" || -z "${NOTARYTOOL_ISSUER_ID:-}" || -z "${NOTARYTOOL_KEY:-}" ]]; then
  echo "Missing one or more required environment variables for macOS signing/notarization." >&2
  exit 2
fi

WORKDIR=$(mktemp -d)
KEYCHAIN="$WORKDIR/build.keychain-db"
P12_PATH="$WORKDIR/cert.p12"
P8_PATH="$WORKDIR/AuthKey.p8"
ZIP_PATH="$WORKDIR/app.zip"

# Decode secrets
echo "$MACOS_CERT_P12" | base64 --decode > "$P12_PATH"
echo "$NOTARYTOOL_KEY" | base64 --decode > "$P8_PATH"

# Create an ephemeral keychain
security create-keychain -p "" "$KEYCHAIN"
security set-keychain-settings "$KEYCHAIN"
security unlock-keychain -p "" "$KEYCHAIN"
security import "$P12_PATH" -k "$KEYCHAIN" -P "$MACOS_CERT_PASSWORD" -A -t cert -f pkcs12

# Ensure the key is usable by codesign
IDENTITY=${MACOS_IDENTITY:-"Developer ID Application"}
# Find the actual identity string
IDENT=$(security find-identity -v -p codesigning "$KEYCHAIN" | grep "Developer ID Application" | head -n1 | awk -F '"' '{print $2}')
if [[ -z "$IDENT" ]]; then
  echo "Failed to find Developer ID Application identity in keychain" >&2
  exit 3
fi

echo "[macOS] Codesigning with identity: $IDENT"

# Sign embedded frameworks and the app
/usr/bin/codesign \
  --force --options runtime --timestamp \
  --entitlements "macos/Runner/Release.entitlements" \
  --sign "$IDENT" \
  "$APP_PATH"

# Verify signature
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_PATH"

# Prepare notarytool keychain profile
NOTARY_PROFILE="notary-profile-$(date +%s)"
xcrun notarytool store-credentials "$NOTARY_PROFILE" \
  --apple-id "dummy@example.invalid" \
  --team-id "$MACOS_TEAM_ID" \
  --key-id "$NOTARYTOOL_KEY_ID" \
  --issuer "$NOTARYTOOL_ISSUER_ID" \
  --key "$P8_PATH" >/dev/null

# Zip the app for notarization
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

# Submit to notarization and wait
xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait --timeout 15m

# Staple ticket
echo "[macOS] Stapling ticket"
xcrun stapler staple -v "$APP_PATH"

# Gatekeeper assessment and codesign verify
spctl --assess --type execute --verbose "$APP_PATH"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo "[macOS] Signing, notarization, and verification completed."
