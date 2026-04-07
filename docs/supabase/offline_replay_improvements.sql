-- Offline replay improvements: attempts, backoff, quarantine, and push digest schema

-- 1) mobile_offline_queue: attempt_count + next_attempt_at columns
ALTER TABLE IF EXISTS mobile_offline_queue
  ADD COLUMN IF NOT EXISTS attempt_count integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS next_attempt_at timestamptz NULL;

-- Optional: widen status enum or use check constraint depending on existing schema
-- Example if status is text: ensure valid values
-- ALTER TABLE mobile_offline_queue
--   ADD CONSTRAINT mobile_offline_queue_status_chk CHECK (status IN ('pending','processing','success','failed')) NOT VALID;

CREATE INDEX IF NOT EXISTS idx_mobile_offline_queue_next_attempt
  ON mobile_offline_queue (status, next_attempt_at NULLS FIRST, created_at);

-- 2) offline_quarantine table to hold malformed ops
CREATE TABLE IF NOT EXISTS offline_quarantine (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  op_id uuid,
  user_id uuid NOT NULL,
  op_type text NOT NULL,
  payload jsonb,
  dedupe_key text,
  error_text text,
  quarantined_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_offline_quarantine_user ON offline_quarantine(user_id, quarantined_at DESC);

-- 3) push_digest table for quiet hours digesting
CREATE TABLE IF NOT EXISTS push_digest (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  title text,
  body text,
  route text,
  params jsonb,
  meta jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  sent_at timestamptz NULL
);
CREATE INDEX IF NOT EXISTS idx_push_digest_user_pending ON push_digest(user_id, sent_at);
CREATE INDEX IF NOT EXISTS idx_push_digest_created ON push_digest(created_at DESC);

-- 4) profiles quiet hours columns (nullable)
ALTER TABLE IF EXISTS profiles
  ADD COLUMN IF NOT EXISTS quiet_start_hour int,
  ADD COLUMN IF NOT EXISTS quiet_end_hour int,
  ADD COLUMN IF NOT EXISTS timezone text;
