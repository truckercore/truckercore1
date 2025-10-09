#!/usr/bin/env bash
set -euo pipefail

DMG_PATH="$1"
xcrun notarytool submit "$DMG_PATH" \
  --apple-id "$APPLE_ID" \
  --team-id "$APPLE_TEAM_ID" \
  --password "$APPLE_APP_PASSWORD" \
  --wait
xcrun stapler staple "$DMG_PATH"
echo "Notarized and stapled: $DMG_PATH"
