-- TTL Sweeper for idempotency cache
-- Delete expired idempotency entries; schedule this to run every hour.
-- Safe to run in production; uses expires_at index.

begin;
  delete from public.idempotency_keys where expires_at < now();
commit;
