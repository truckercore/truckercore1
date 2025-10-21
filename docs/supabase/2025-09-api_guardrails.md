# API Guardrails: Consistency, RLS strictness, and Tenant Isolation (2025‑09)

This document outlines practical measures to keep data access safe and consistent across Edge Functions and database objects.

## 1) Consistency: status enums/checks and broker_id
- Use the canonical load statuses: `draft, assigned, in_transit, delivered, canceled`.
- Keep the DB as the source of truth using a single CHECK constraint (see `docs/supabase/2025-09-phaseA_status_broker_rls.sql`).
- Client and Edge responses should only surface the canonical set. Avoid legacy `open`/`pending` in APIs; map them to `draft` during the zero‑downtime swap.
- Use `broker_id` everywhere (no `brokerage_id`). Drop legacy indexes/columns once views and code are migrated.

## 2) RLS strictness: avoid broad ORs and service-role shortcuts
- Policies MUST scope by tenant key only (e.g., `broker_id = current_broker_id()`), not `OR` chains like `(broker_id=...) OR (auth.role() = 'service')`.
- Use `--no-verify-jwt` only for local/dev. In production, Edge Functions should:
  - Read `Authorization: Bearer <JWT>` and extract tenant claims (broker/org IDs), or
  - Use a server-only service role client for cross-tenant jobs that don’t expose user data.
- If a function uses the service role client (`supabaseAdmin`), ensure it doesn’t expose cross-tenant data. Prefer server-to-server usage and add a header guard (e.g., an HMAC or 
  `X-Internal-Auth`) when invoked by your backend only.

## 3) API patterns for tenant enforcement
- Require a tenant identifier either from JWT claims or an explicit header for server-to-server calls.
- Validate inputs with clear 400s. Return 402 for premium gates, and 403 for RLS/tenant mismatch when applicable.
- Include `x-request-id` in responses and logs. Prefer idempotency keys for mutating operations.

## 4) Zero‑downtime migrations
- Use the `add_v2 → backfill → repoint views → swap` pattern. See `docs/supabase/2025-09-zero_downtime_swap_template.sql`.
- Never change enum types directly if a view depends on the column. Prefer TEXT + CHECK constraints.

## 5) Verification & audits
- Use `docs/supabase/2025-09-consistency_rls_policy_audit.sql` to:
  - Surface non‑canonical statuses
  - Detect policies with `OR` in `qual`/`with_check`
  - Find lingering `brokerage_id` artifacts
  - Confirm RLS enabled and indexes in place

## 6) Future: tenancy helper for Edge Functions (Deno)
Create a helper to extract tenant IDs from JWT or headers, and call it from all functions touching tenant data. Example shape:

```ts
// functions/lib/tenancy.ts
export function getBrokerIdFromAuth(req: Request): string | null {
  const h = req.headers.get('x-broker-id');
  if (h) return h; // server-to-server path
  const auth = req.headers.get('authorization') || req.headers.get('Authorization');
  if (!auth?.startsWith('Bearer ')) return null;
  try {
    const token = auth.slice('Bearer '.length);
    const payload = JSON.parse(atob(token.split('.')[1]));
    return (payload['broker_id'] as string) ?? null;
  } catch {
    return null;
  }
}
```

Use it alongside DB RLS (never instead of RLS). Reject requests without a tenant in production paths.
