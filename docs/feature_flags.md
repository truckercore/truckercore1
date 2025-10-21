# Feature flags registry and usage

Location
- Registry file: config/feature_flags.json (source of truth in this repo)
- Owners: Module leads; PRs required for changes; flags default to false for net-new modules.

Naming
- snake_case keys grouped by domain (e.g., saved_search_alerts, ocr_pipeline_v1).
- Include version suffixes when iterating (v1, v2) and clean up retired flags after full rollout.

Lifecycles
- Proposed → Behind-flag in sandbox → Canary cohort → Staging → Full prod → Retire or bake-in.
- Document owner, purpose, and rollback plan in the PR.

Client usage (Flutter)
- Minimal helper is provided in lib/common/feature_flags.dart.
- For idempotency and determinism, read flags at app startup and cache; allow remote overrides later.

Server usage
- Server workers/functions can read this file at build time or load flags from a service table (future).
- For canary, use percentage‑based rollout in promotion workflow and/or org‑scoped overrides.

Example
```
{
  "saved_search_alerts": false,
  "offline_store_and_forward": true
}
```

Principles
- Flags are for rollout and kill‑switches, not long‑term configuration.
- Keep the flag surface minimal and remove stale flags.
