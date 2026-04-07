Title: Data Governance Policy (v1)

Scope
- Applies to data collected and processed by TruckerCore for operations, analytics, and AI/ML, including telemetry, facility dwell events, and broker behavior.

Guiding principles
- Prioritization: Focus on high-value feeds first: telemetry (P0), facility dwell (P1), broker behavior (P1). Optional/derived feeds are P2.
- Quality by design: Enforce schema, required fields, ranges, and idempotency at ingestion. Capture anomalies immediately with lineage.
- Security and access: Limit access by tenant (org_id) and least privilege. Encrypt at rest; avoid storing raw PII when not required.
- Lineage and auditability: Every record carries source, received_at, ingest_id, and version. Anomalies are recorded in a dedicated table.
- Retention and minimization: Retain raw events for 13 months; aggregate KPIs kept for 36 months; purge per policy or upon request.

Data feed standards
- Common columns across feeds: id (event_id), org_id, source, ingest_id, received_at (UTC), event_at (UTC), lat/lon (if applicable), meta JSONB.
- Idempotency: event_id must be globally unique; upsert on conflict to prevent duplicates.
- Timestamps: ISO-8601; server normalizes to UTC.
- Geospatial: Degrees; lat in [-90, 90], lon in [-180, 180].
- Validation: Reject hard violations; soft violations recorded as anomalies.

Priorities
- P0 Telemetry: vehicle location, speed, driver activity; SLA: <10s ingest latency, 99.9% availability.
- P1 Facility dwell: enter/exit events; SLA: <60s ingest, 99.5% availability.
- P1 Broker behavior: bids, pay terms, fall-off rate; SLA: <5m ingest.

Access control
- RLS by org_id, plus service key for ingestion functions.
- Column-level protections for PII (driver_name, phone) where applicable. Prefer hashed/ID references.

Data lineage
- ingest_id: UUID for each ingestion call; stored on all rows produced. data_anomalies records with the same ingest_id.

Monitoring and alerting
- data_monitor_get function returns per-feed health (latest event time, count, anomalies). Thresholds trigger alerts via webhook.

Idempotency and retries
- All ingest endpoints accept idempotency key event_id and perform upsert. External pulls/backfill should use exponential backoff.

Change management
- AI endpoints include rationale fields. feedback_submit collects thumbs-up/down with comments tied to context_id.

Versioning
- Policy v1; breaking schema changes go through migration files in docs/supabase with semver filenames.
