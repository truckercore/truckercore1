#!/usr/bin/env bash
set -euo pipefail
: "${FUNC_URL:?}" : "${ORG_ID:?}"

# Invalid (expired) assertion (unsigned; time window in the past) -> expect 400
XML_EXPIRED='<Response><Assertion><Conditions NotBefore="2000-01-01T00:00:00Z" NotOnOrAfter="2000-01-02T00:00:00Z"></Conditions></Assertion></Response>'
resp_expired=$(printf "%s" "$XML_EXPIRED" | base64 -w0 2>/dev/null || printf "%s" "$XML_EXPIRED" | base64)
code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${FUNC_URL%/}/saml-acs?org_id=${ORG_ID}" \
  -F "SAMLResponse=${resp_expired}")
[ "$code" = "400" ] || { echo "❌ expected 400 for expired (got $code)"; exit 6; }

# Wrong audience (unsigned; audience mismatch) -> expect 403 based on audience parsing
XML_BAD_AUD='<Response><Assertion><Conditions><AudienceRestriction><Audience>urn:wrong:aud</Audience></AudienceRestriction></Conditions></Assertion></Response>'
resp_bad_aud=$(printf "%s" "$XML_BAD_AUD" | base64 -w0 2>/dev/null || printf "%s" "$XML_BAD_AUD" | base64)
code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${FUNC_URL%/}/saml-acs?org_id=${ORG_ID}" \
  -F "SAMLResponse=${resp_bad_aud}")
[ "$code" = "403" ] || { echo "❌ expected 403 for bad audience (got $code)"; exit 7; }

echo "✅ SAML negative cases OK"
