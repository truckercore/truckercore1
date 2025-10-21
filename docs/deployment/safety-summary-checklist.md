# Safety Summary Suite Deployment Checklist

## Pre-Deployment

- [ ] Supabase CLI installed (`supabase --version`)
- [ ] Project linked (`supabase link --project-ref XXX`)
- [ ] Environment variables set:
  - [ ] `SUPABASE_URL`
  - [ ] `SUPABASE_SERVICE_ROLE_KEY`
  - [ ] `SUPABASE_ANON_KEY` (optional for testing)
- [ ] Node.js >=18 installed
- [ ] Git branch clean or committed

## Database Migration

- [ ] Run `npm run deploy:safety-suite` OR manually:
  - [ ] `supabase db push`
  - [ ] Verify tables created: `safety_daily_summary`, `risk_corridor_cells`
  - [ ] Verify view created: `v_export_alerts`
  - [ ] Verify function exists: `refresh_safety_summary`
- [ ] Test RPC manually:
  ```sql
  select public.refresh_safety_summary(null, 7);
  ```

## Edge Functions

- [ ] Deploy function: `supabase functions deploy refresh-safety-summary --no-verify-jwt`
- [ ] Set secrets:
  ```bash
  supabase secrets set SUPABASE_SERVICE_ROLE_KEY=xxx
  supabase secrets set SUPABASE_URL=xxx
  ```
- [ ] Test invocation:
  ```bash
  curl -X POST "${SUPABASE_URL}/functions/v1/refresh-safety-summary" \
    -H "Authorization: Bearer ${SERVICE_KEY}"
  ```
- [ ] Schedule CRON (optional):
  ```bash
  supabase functions schedule refresh-safety-summary "0 6 * * *"
  ```

## API Routes (Next.js)

- [ ] Create `/pages/api/export-alerts.csv.ts`
- [ ] Test endpoint: `curl http://localhost:3000/api/export-alerts.csv?org_id=XXX`
- [ ] Verify CSV format and org filtering

## UI Components

- [ ] Create `components/ExportAlertsCSVButton.tsx`
- [ ] Create `components/SafetySummaryCard.tsx`
- [ ] Create `components/TopRiskCorridors.tsx`
- [ ] Add to Fleet dashboard (`apps/web/pages/fleet/index.tsx`)
- [ ] Add to Owner-Op dashboard (`apps/web/pages/owner/index.tsx`)
- [ ] Add to Enterprise reports (`apps/web/pages/enterprise/reports/risk-corridors.tsx`)

## Testing

- [ ] Run verification: `npm run verify:safety-suite`
- [ ] Manual UI tests:
  - [ ] SafetySummaryCard loads data
  - [ ] Export CSV button downloads file
  - [ ] Risk Corridors map renders
  - [ ] Top 5 table populates
- [ ] Integration tests:
  - [ ] Create test alert → wait 1 min → verify appears in summary
  - [ ] Trigger refresh → verify row count increases
  - [ ] Export CSV → verify org filtering

## Post-Deployment

- [ ] Monitor Edge Function logs: `supabase functions logs refresh-safety-summary`
- [ ] Check first CRON execution (06:00 UTC next day)
- [ ] Verify no PII in CSV exports
- [ ] Document rate limits in user docs
- [ ] Add to status dashboard if available

## Rollback Plan

If issues arise:
1. Disable CRON: `supabase functions unschedule refresh-safety-summary`
2. Revert migration: `supabase db reset` (caution: nukes all data)
3. Hide UI components via feature flag
4. Notify users of maintenance window

## Success Criteria

- [ ] All verification tests pass
- [ ] SafetySummaryCard shows 7-day data
- [ ] CSV export contains expected columns
- [ ] Risk Corridors map displays heat layer
- [ ] No 500 errors in logs for 24h
- [ ] CRON executes successfully (check next day)
