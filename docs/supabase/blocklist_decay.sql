-- docs/supabase/blocklist_decay.sql
-- Severity-weighted exponential decay score for IP blocklist, plus schema tweaks and active view.
-- Idempotent and safe to re-run.

-- Extend ip_blocklist with severity, max_minutes cap, and shadow_mode flag if missing
DO $$ BEGIN
  IF to_regclass('public.ip_blocklist') IS NULL THEN
    EXECUTE 'CREATE TABLE public.ip_blocklist (
      ip inet primary key,
      severity text not null default ''med'' check (severity in (''low'',''med'',''high'',''critical'')),
      reason text not null,
      created_at timestamptz not null default now(),
      max_minutes int not null default 10080,
      shadow_mode boolean not null default false
    )';
  ELSE
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='ip_blocklist' AND column_name='severity') THEN
      EXECUTE 'ALTER TABLE public.ip_blocklist ADD COLUMN severity text not null default ''med''';
      EXECUTE 'ALTER TABLE public.ip_blocklist ADD CONSTRAINT ip_blocklist_severity_chk CHECK (severity in (''low'',''med'',''high'',''critical''))';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='ip_blocklist' AND column_name='max_minutes') THEN
      EXECUTE 'ALTER TABLE public.ip_blocklist ADD COLUMN max_minutes int not null default 10080';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='ip_blocklist' AND column_name='shadow_mode') THEN
      EXECUTE 'ALTER TABLE public.ip_blocklist ADD COLUMN shadow_mode boolean not null default false';
    END IF;
  END IF;
END $$;

-- Severity-weighted exponential decay function returning score in [0,1]
CREATE OR REPLACE FUNCTION public.fn_block_active_score(
  p_created_at timestamptz,
  p_severity text,                -- 'low'|'med'|'high'|'critical'
  p_now timestamptz DEFAULT now(),
  p_cap_minutes int DEFAULT 10080
) RETURNS double precision
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_half_life_min int;
  v_age_min double precision := extract(epoch from (p_now - p_created_at)) / 60.0;
  v_cap_min int := greatest(0, p_cap_minutes);
  v_age_capped double precision := least(v_age_min, v_cap_min);
  v_score double precision;
BEGIN
  v_half_life_min := CASE lower(p_severity)
    WHEN 'low' THEN 60       -- 1h
    WHEN 'med' THEN 240      -- 4h
    WHEN 'high' THEN 720     -- 12h
    WHEN 'critical' THEN 1440 -- 24h
    ELSE 240
  END;
  v_score := power(0.5, v_age_capped / v_half_life_min);
  RETURN v_score;
END $$;

-- Convenience view: compute active score; consumers can apply threshold (e.g., > 0.1)
CREATE OR REPLACE VIEW public.v_ip_block_active AS
SELECT
  ip,
  severity,
  reason,
  shadow_mode,
  public.fn_block_active_score(COALESCE(created_at, now()), severity, now(), max_minutes) AS score,
  created_at
FROM public.ip_blocklist;
