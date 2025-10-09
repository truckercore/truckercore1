-- 20250923_hot_index.sql
-- Composite hot index for tenant-scoped pagination on escalation_logs
-- Safe to re-run.

create index if not exists escalation_logs_org_created_idx
  on public.escalation_logs (org_id, created_at desc);
