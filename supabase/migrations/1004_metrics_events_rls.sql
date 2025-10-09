-- 1004_metrics_events_rls.sql
-- Purpose: Harden RLS for metrics_events to ensure org-scoped access.
-- Idempotent: safe to run multiple times across environments where the table exists.

DO $$ BEGIN
  IF to_regclass('public.metrics_events') IS NOT NULL THEN
    -- Ensure RLS is enabled
    EXECUTE 'alter table public.metrics_events enable row level security';

    -- SELECT within same org (based on JWT claim app_org_id)
    EXECUTE $$
      create policy if not exists metrics_events_sel_org on public.metrics_events
      for select to authenticated
      using (
        coalesce(org_id::text, '') = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','')
      );
    $$;

    -- INSERT within same org (row must match JWT org)
    EXECUTE $$
      create policy if not exists metrics_events_ins_org on public.metrics_events
      for insert to authenticated
      with check (
        coalesce(org_id::text, '') = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','')
      );
    $$;

    -- Optional: UPDATE within same org (if updates are allowed)
    EXECUTE $$
      create policy if not exists metrics_events_upd_org on public.metrics_events
      for update to authenticated
      using (
        coalesce(org_id::text, '') = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','')
      )
      with check (
        coalesce(org_id::text, '') = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','')
      );
    $$;

    -- Note: Service role bypasses RLS; no special policy required for it.
  END IF;
END $$;