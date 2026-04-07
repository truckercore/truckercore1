# Data Inventory (per feature)

Track for each feature: purpose, data fields, retention, lawful basis.

Feature: Webhook Deliveries
- Purpose: deliver event notifications to subscribers.
- Data: org_id, endpoint_url, topic, payload metadata, timestamps.
- Retention: 30 days (configurable via app_settings; see supabase/migrations/2025-09-26_data_retention.sql).
- Lawful basis: contract (service operation).

Feature: Audit Logs
- Purpose: track privileged actions and auth events.
- Data: actor, action, scope (org_id/user_id), correlation_id, ts.
- Retention: 90 days (configurable).
- Lawful basis: legitimate interests/compliance.

Add new sections for additional features; avoid collecting free-form PII unless necessary.
