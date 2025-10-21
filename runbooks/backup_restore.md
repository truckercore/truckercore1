# Backup & Restore Runbook

Purpose: Validate we can restore production backups and data integrity holds.

Steps:
- Fetch latest dump from S3 and restore into a temporary database.
- Run smoke queries (row counts, key tables present, RLS enabled on sensitive tables).
- Record duration and any errors in incident notes.

Checklist:
- [ ] `pg_restore` completed without errors
- [ ] `invoices` row count > 0
- [ ] `auth.users` present
- [ ] Sensitive tables have RLS enabled
- [ ] Drop temporary database after validation
