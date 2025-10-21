-- Invite hygiene: indexes + expiry cleanup (idempotent)
-- Run in Supabase SQL editor or psql. Safe to run multiple times.

DO $$ BEGIN
  -- Create index on org_invites.token if table/column exist
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='org_invites' AND column_name='token'
  ) THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS org_invites_token_idx ON public.org_invites(token)';
  END IF;

  -- Create index on org_invites.expires_at if present
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='org_invites' AND column_name='expires_at'
  ) THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS org_invites_expires_at_idx ON public.org_invites(expires_at)';
  END IF;
END $$;

-- Cleanup expired, unaccepted invites and release pending seats
DO $$
DECLARE
  _has_invites boolean;
  _has_expires boolean;
  _has_accepted boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='org_invites'
  ) INTO _has_invites;

  IF NOT _has_invites THEN
    RETURN; -- nothing to do
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='org_invites' AND column_name='expires_at'
  ) INTO _has_expires;
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='org_invites' AND column_name='accepted_at'
  ) INTO _has_accepted;

  IF _has_expires AND _has_accepted THEN
    -- Adjust seats_used_pending down by the number of expired+unaccepted invites per org
    EXECUTE $$
      WITH expired AS (
        SELECT org_id, count(*) AS cnt
        FROM public.org_invites
        WHERE accepted_at IS NULL AND expires_at < now()
        GROUP BY org_id
      )
      UPDATE public.orgs o
      SET seats_used_pending = GREATEST(0, COALESCE(o.seats_used_pending,0) - e.cnt)
      FROM expired e
      WHERE o.id = e.org_id
    $$;

    -- Optionally mark invites as expired if such a column exists; otherwise delete
    IF EXISTS (
      SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='org_invites' AND column_name='expired_at'
    ) THEN
      EXECUTE $$
        UPDATE public.org_invites
        SET expired_at = now()
        WHERE accepted_at IS NULL AND expires_at < now() AND expired_at IS NULL
      $$;
    ELSE
      EXECUTE $$
        DELETE FROM public.org_invites
        WHERE accepted_at IS NULL AND expires_at < now()
      $$;
    END IF;
  END IF;
END $$;
