#!/usr/bin/env bash
set -euo pipefail

# Generate CycloneDX SBOM for Node/Edge workspace
npx @cyclonedx/cyclonedx-npm --output sbom-edge.json

echo "SBOM written to sbom-edge.json"
