#!/usr/bin/env bash
set -euo pipefail

# linux_sign.sh
# Generates SHA256 checksums and a detached ASCII-armored GPG signature for the AppImage or archive.
# Requirements (CI secrets):
#  - GPG_PRIVATE_KEY: base64-encoded private key
#  - GPG_PASSPHRASE: passphrase for the key (optional if not needed)
# Usage:
#   scripts/sign/linux_sign.sh path/to/TruckerCore-<ver>-linux-x86_64.AppImage
#   or a .zip produced for Linux bundle

TARGET=${1:-}
if [[ -z "$TARGET" || ! -f "$TARGET" ]]; then
  echo "Usage: $0 path/to/file" >&2
  exit 1
fi

if [[ -z "${GPG_PRIVATE_KEY:-}" ]]; then
  echo "Missing GPG_PRIVATE_KEY env var" >&2
  exit 2
fi

WORKDIR=$(mktemp -d)
KEY_PATH="$WORKDIR/key.asc"
echo "$GPG_PRIVATE_KEY" | base64 --decode > "$KEY_PATH"

gpg --batch --import "$KEY_PATH"

# Create checksum
sha256sum "$TARGET" > "$TARGET.sha256"

# Detached signature
if [[ -n "${GPG_PASSPHRASE:-}" ]]; then
  gpg --batch --yes --pinentry-mode loopback --passphrase "$GPG_PASSPHRASE" \
    --armor --detach-sign --output "$TARGET.asc" "$TARGET"
else
  gpg --batch --yes --armor --detach-sign --output "$TARGET.asc" "$TARGET"
fi

# Verify signature
gpg --verify "$TARGET.asc" "$TARGET"

echo "[Linux] SHA256 and detached signature created and verified."
