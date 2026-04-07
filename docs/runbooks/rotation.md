# Secrets Rotation Runbook

This runbook covers rotating webhook secrets and API keys without downtime.

## Webhooks
1. Set a new secret with an overlap window (24–72h typical):
   - POST /v1/orgs/:orgId/webhooks/:id/rotate-secret
   - Body: { "secret_next": "<new-secret>", "overlap_minutes": 1440 }
2. Validate by sending a test delivery and confirming receiver accepts both signatures.
3. Monitor deliveries; if healthy, commit:
   - POST /v1/orgs/:orgId/webhooks/:id/commit-secret
4. Inform subscriber to update stored secret; remove the old secret from their config.

Notes:
- During overlap, worker sends X-TruckerCore-Signature and X-TruckerCore-Signature-Alt.

## API Keys
1. Create a replacement key for the same org/principal.
2. Allow a dual-valid window up to 24h; monitor traffic split.
3. Revoke the old key and record an audit entry.

## Verification
- Spot-check logs with the redaction scanner (npm run scan:logs -- latest.log).
- Ensure no secret values appear in logs/metrics.
