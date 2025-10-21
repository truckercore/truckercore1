# Phase 0 — Foundations (Implemented in this change set)

This commit adds minimal building blocks to support the Phase 0 acceptance criteria:

- Organization scoping and roles
  - Added SQL helper function `public.has_role(text)` that checks the `app_roles` claim in the Supabase JWT.
  - Tightened RLS for `inspection_reports` insert to require `has_role('driver')` in addition to org + user checks.
  - Existing tables already enforce `org_id = jwt.app_org_id` in prior migrations.

- Eventing and data contracts
  - Introduced `public.event_outbox` table with `enqueue_event()` function implementing idempotent inserts by `(org_id, event_type, dedup_key)`.
  - Added a trigger on `alerts_events` to emit canonical `alert.triggered` events into the outbox.
  - Outbox payloads include a `schema_version` for versioned JSON schemas.

- Webhooks MVP (service-managed)
  - Created `public.webhook_subscriptions` and `public.webhook_deliveries` as a foundation for webhook delivery workers. Both are service-role only via RLS policies.

- Offline-first client foundation
  - Project already contains a simple `OfflineQueue` (lib/offline/offline_queue.dart) with store-and-forward + retry. No breaking API changes were made.
  - Extended `SupaClient` to accept `extraHeaders` for org/role propagation to Edge Functions.
  - Added `buildOrgRoleHeaders(ref)` helper to construct `x-app-org-id` and `x-app-roles` headers where needed (functions/webhooks). RLS still relies on JWT claims.

## Using the event outbox

- Insert into `alerts_events` will automatically enqueue an `alert.triggered` event with `schema_version = 1` and payload structure:

```
{
  id: <uuid>,
  severity: 'info'|'warning'|'critical',
  code: <text>,
  payload: <jsonb>,
  triggered_at: <timestamptz>
}
```

- To enqueue custom events from the app layer (service role):

```
select public.enqueue_event(
  '00000000-0000-0000-0000-000000000000'::uuid, -- org_id
  'document.uploaded',
  1,
  '{"doc_id":"...","load_id":"..."}'::jsonb,
  'doc:...' -- dedup key
);
```

## Using SupaClient with org/roles headers

```
final headers = buildOrgRoleHeaders(ref);
await supa.postJson('/functions/v1/my-func', { 'action': 'ping' }, extraHeaders: headers);
```

## Notes
- RLS for analytics, owner-operator expenses, HOS logs, inspection reports and alerts already enforce `app_org_id`. This change keeps that pattern and adds role checks where appropriate.
- Webhook delivery worker is not included here; it can read pending rows from `event_outbox`, join with `webhook_subscriptions`, sign and deliver, and record attempts in `webhook_deliveries`.


## Idempotency key usage with SupaClient

You can pass an idempotency key as a header when calling Edge Functions or APIs. A good practice is to reuse the OfflineQueue item ID so that retries are de‑duplicated server‑side.

Example
```
final qid = await offlineQueue.enqueue('document.upload', payload);
final headers = {
  ...buildOrgRoleHeaders(ref),
  'Idempotency-Key': qid,
};
await supa.postJson('/functions/v1/doc-upload', payload, extraHeaders: headers, maxRetries: 3);
```
