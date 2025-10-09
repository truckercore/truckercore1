// ci/saml_probe.mjs
// Minimal ACS probe using a signed fixture (placeholder). Exits non-zero if ACS does not 200/302.
import fetch from 'node-fetch';

const url = process.env.NONPROD_ACS_URL;
if (!url) { console.error('NONPROD_ACS_URL not set'); process.exit(2); }

// Placeholder base64 SAMLResponse (should be replaced with a valid signed fixture in CI secrets)
const signedFixtureBase64 = process.env.SAML_FIXTURE_B64 || '';

const res = await fetch(url, {
  method: 'POST',
  headers: { 'content-type': 'application/x-www-form-urlencoded' },
  body: new URLSearchParams({ SAMLResponse: signedFixtureBase64, RelayState: '/app' })
});

if (res.status !== 302 && res.status !== 200) {
  console.error('ACS probe failed, status', res.status);
  process.exit(1);
}
console.log('✅ ACS probe status', res.status);
