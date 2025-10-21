# Data Retention and Purge

Retention of operational logs and webhook deliveries is managed via Supabase migration `2025-09-26_data_retention.sql`.

- Configure retention days in `public.app_settings` keys:
  - `retention.webhook_deliveries.days` (default 30)
  - `retention.audit_logs.days` (default 90)
- Run purge function: `select public.purge_old_data();`
- Schedule via pg_cron or external scheduler (see commented example in the migration).
- Align retention with compliance requirements documented in docs/DATA_INVENTORY.md.
