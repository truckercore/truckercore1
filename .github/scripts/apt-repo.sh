#!/usr/bin/env bash
set -euo pipefail
REPO_DIR="repo/apt"
DIST="stable"
ARCHES=("amd64" "arm64")

mkdir -p "$REPO_DIR/dists/$DIST/main/binary-amd64" "$REPO_DIR/dists/$DIST/main/binary-arm64" "$REPO_DIR/pool/main"
cp artifacts/*.deb "$REPO_DIR/pool/main/"

for arch in "${ARCHES[@]}"; do
  apt-ftparchive packages "$REPO_DIR/pool/main" > "$REPO_DIR/dists/$DIST/main/binary-$arch/Packages"
  gzip -fk "$REPO_DIR/dists/$DIST/main/binary-$arch/Packages"
done

apt-ftparchive release "$REPO_DIR/dists/$DIST" > "$REPO_DIR/dists/$DIST/Release"
gpg --batch --yes --pinentry-mode loopback --passphrase "$DEB_GPG_PASSPHRASE" \
  -abs -o "$REPO_DIR/dists/$DIST/Release.gpg" "$REPO_DIR/dists/$DIST/Release"

echo "Apt repo ready at $REPO_DIR"
