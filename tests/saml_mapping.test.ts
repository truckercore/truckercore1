// tests/saml_mapping.test.ts
// Basic mapping unit test for SAML group→role mapping
import { strict as assert } from 'node:assert'
import okta from './fixtures/saml_okta_min.json' assert { type: 'json' }

function mapRoles(attrs: any, mapping: Record<string,string[]>) {
  const groups = new Set<string>((attrs?.Attributes?.Groups ?? []) as string[])
  const roles = new Set<string>()
  for (const [group, rs] of Object.entries(mapping)) {
    if (groups.has(group)) (rs as string[]).forEach(r => roles.add(r))
  }
  return Array.from(roles)
}

const mapping: Record<string,string[]> = { 'TC-Corp-Admins': ['corp_admin'], 'TC-Dispatch': ['dispatcher'] }
assert.deepEqual(mapRoles(okta, mapping).sort(), ['corp_admin','dispatcher'].sort())

console.log('[TEST_PASS] saml_mapping')
