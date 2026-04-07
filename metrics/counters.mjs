// metrics/counters.mjs
// Simple in-memory counters for dashboards. Not persisted; intended for local/ephemeral metrics.
// Usage: import { counters, inc } from './metrics/counters.mjs'
//   inc(counters.canary_success, `${org}:${idp}`)
//   inc(counters.api_denials_role, role)

export const counters = {
  canary_success: new Map(),   // key: `${org_id}:${idp}` -> count
  api_denials_role: new Map(), // key: role -> count
}

export function inc(map, key) {
  map.set(key, (map.get(key) ?? 0) + 1)
}
