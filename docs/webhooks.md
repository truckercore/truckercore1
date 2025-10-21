# Webhooks (MVP)

This repository includes the schema and a delivery worker stub for org-scoped webhooks.

Acceptance supported
- Events retry on transient failures; dead letters logged and visible (schema-level: event_outbox has status + next_attempt_at; webhook_deliveries captures attempts and dead_lettered_at for visibility).
- Delivery includes X-TruckerCore-Signature with timestamp; partners can verify.

Schema
- public.event_outbox: durable queue with retry bookkeeping (status, next_attempt_at, delivery_attempts, last_error).
- public.webhook_subscriptions: per-org endpoints with secret, topics, and active flag.
- public.webhook_deliveries: attempt-by-attempt delivery log with response codes and error text.

Signature
- Headers on delivery:
  - X-TruckerCore-Event: <event_type>
  - X-TruckerCore-Timestamp: <unixEpochSeconds>
  - X-TruckerCore-Signature: sha256=<hexDigest> where hexDigest = HMAC_SHA256(secret, `${timestamp}.${body}`)
  - X-TruckerCore-Signature-Alt: sha256=<hexDigest> (optional; sent during secret rotation overlap using `secret_next`)
  - Idempotency-Key: <event id>

Worker stub
- File: api/workers/webhook_worker.ts
- Replace the DB access placeholders with supabase-js using a service role key.
- Implement exponential backoff with jitter and mark events as `dead` after max attempts (e.g., 8). Set `dead_lettered_at` for the last failed attempt.

Replay prevention
- Partners should treat `Idempotency-Key` as an idempotency token. If they receive the same key twice, they should return the prior result.

Topics
- Subscriptions may list one or more topics (e.g., `{'location.updated','alert.triggered'}`). An empty set can be treated as "subscribe to all" by your worker.

Active/pause
- Field naming: is_active (boolean). Paused subscriptions (is_active=false) are skipped by the worker.

Leasing & retries
- Workers claim rows by setting next_attempt_at to a short lease window and incrementing delivery_attempts atomically; this prevents double delivery when multiple workers run.
- Persist last_status_code and last_error on failures; after max attempts (e.g., 8), mark status='dead' and set webhook_deliveries.dead_lettered_at.

Admin operations (MVP)
- Test delivery: send a sample payload to a subscription endpoint to verify signatures.
- Replay DLQ: re-enqueue one DLQ item or a filtered set (topic, age).
- Pause/Resume: toggle is_active.

Administration
- The `webhook_subscriptions` table is RLS-locked for end users (service managed). Provide an admin UI/API protected by org admin roles to CRUD subscriptions and rotate secrets.

Testing
- Add a test endpoint that echoes signature verification and returns 200.
- Add a CI test that validates the signature format.
