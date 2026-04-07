#!/usr/bin/env bash
set -euo pipefail

# Generate CycloneDX SBOM for desktop/mobile app (placeholder tool invocation)
# Install cyclonedx-bom via your platform tooling, or adjust accordingly.
cyclonedx-bom -o sbom-desktop.json || {
  echo "cyclonedx-bom not installed; please install or adjust toolchain" >&2
  exit 1
}

echo "SBOM written to sbom-desktop.json"
