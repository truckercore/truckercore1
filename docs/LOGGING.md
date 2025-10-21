# Logging and Auditing

- Use api/lib/logging.ts for all structured logs. It attaches correlation_id and org_id (if provided) and redacts sensitive fields.
- Include correlation IDs across services; propagate `correlation_id` in meta and headers.
- Timestamps must be ISO 8601 UTC.
- Do not log secrets or raw PII. Hash identifiers where feasible for analytics.
- Audit important events: auth success/failure, privilege changes, data exports, webhook verification results (ok/fail), and errors.
- Retention: see docs/RETENTION.md.
