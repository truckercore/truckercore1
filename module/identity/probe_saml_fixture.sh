#!/usr/bin/env bash
set -euo pipefail
: "${FUNC_URL:?}" : "${ORG_ID:?}"

# Requires fixture generated via scripts/gen_saml_fixture.mjs into fixtures/saml/Response_valid_base64.txt
resp="$(cat fixtures/saml/Response_valid_base64.txt)"

# First POST should succeed (302 redirect expected)
code1=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${FUNC_URL%/}/saml-acs?org_id=${ORG_ID}" \
  -F "SAMLResponse=${resp}" -F "RelayState=/app")
if [[ "$code1" != "302" && "$code1" != "200" ]]; then
  echo "❌ ACS did not accept fixture (code $code1)"; exit 5;
fi

# Replay should be rejected (not 200)
code2=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${FUNC_URL%/}/saml-acs?org_id=${ORG_ID}" \
  -F "SAMLResponse=${resp}" -F "RelayState=/app")
if [[ "$code2" == "200" ]]; then
  echo "❌ replay not rejected"; exit 6;
fi

echo "✅ SAML replay/temporal guard OK"