// tests/role_guard.spec.ts
// Jest-style unit tests for the API guard mapping.
import { strict as assert } from 'node:assert'
import { guard } from '../api/middleware/guard'

function simulate(route: string, method: string, { role }: { role: string }) {
  // Map route/method into a feature key used by guard()
  const feature = (() => {
    if (route.startsWith('/admin/sso')) return 'admin:sso'
    if (route === '/promos' && method === 'POST') return 'promos:write'
    return 'unknown'
  })()
  const ok = guard(role, feature, 'test-trace')
  return { status: ok ? 200 : 403 }
}

type Case = { role: string; route: string; method: string; expect: 'allow'|'deny' }
const cases: Case[] = [
  { role: 'driver', route: '/admin/sso', method: 'GET', expect: 'deny' },
  { role: 'corp_admin', route: '/admin/sso', method: 'GET', expect: 'allow' },
  { role: 'dispatcher', route: '/promos', method: 'POST', expect: 'allow' },
]

for (const c of cases) {
  const res = simulate(c.route, c.method, { role: c.role })
  const decision = res.status < 400 ? 'allow' : 'deny'
  assert.equal(decision, c.expect, `Case ${JSON.stringify(c)} failed: got ${decision}`)
}

console.log('[TEST_PASS] role_guard')
