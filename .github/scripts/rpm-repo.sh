#!/usr/bin/env bash
set -euo pipefail
REPO_DIR="repo/rpm"
mkdir -p "$REPO_DIR/packages"
cp artifacts/*.rpm "$REPO_DIR/packages/" || true

createrepo_c "$REPO_DIR"
gpg --batch --yes --pinentry-mode loopback --passphrase "$RPM_GPG_PASSPHRASE" \
  --detach-sign --armor "$REPO_DIR/repodata/repomd.xml"

echo "RPM repo ready at $REPO_DIR"
