# Deployment Readiness Checklist

## Pre-Flight

- [ ] All environment variables set in Vercel/hosting dashboard
  - `NEXT_PUBLIC_SUPABASE_URL`
  - `NEXT_PUBLIC_SUPABASE_ANON_KEY`
  - `SUPABASE_SERVICE_ROLE_KEY` (server-only, not exposed to client)
  - `SENTRY_DSN` (optional)
  - `STRIPE_SECRET_KEY` (if using Stripe)
  - `MAPBOX_TOKEN` (if using Mapbox)
- [ ] Domain DNS configured and pointing to Vercel/hosting
  - `truckercore.com` → Vercel
  - `app.truckercore.com` → Vercel (or separate project)
- [ ] SSL certificates provisioned and active
- [ ] Homepage route exists (`pages/index.tsx` or `app/page.tsx`)
- [ ] All tests pass locally
  - `npm run test`
  - `npm run test:unit`
  - `npm run typecheck`
- [ ] Build succeeds locally
  - `npm run build`
- [ ] Database migrations applied
  - `supabase db push` (or manual migration run)
- [ ] Row-Level Security (RLS) policies enabled on all tables
- [ ] Supabase Edge Functions deployed
  - `refresh-safety-summary` deployed and scheduled (daily cron)
  - `supabase functions deploy refresh-safety-summary`
  - Verify cron schedule in `supabase.toml`: `cron = "0 6 * * *"`
- [ ] Stripe products/prices configured
  - Free plan limits documented
  - Pro plan features enabled
  - Webhook endpoint configured for `customer.subscription.*` events
- [ ] API rate limits and feature gates configured
- [ ] Observability configured
  - Sentry error tracking active
  - Metrics/analytics instrumentation verified
- [ ] Privacy policy, terms of service, contact page published

## Post-Deploy Steps

1. **Verify homepage loads**
   - Visit `https://truckercore.com` → should display homepage, not 404
   - Visit `https://app.truckercore.com` → should load app dashboard

2. **Run Supabase cron immediately (one-time manual trigger)**
   ```bash
   supabase functions invoke refresh-safety-summary
   ```
   Verify response is `200 OK`.

3. **Verify CSV export endpoint**
   - Hit `/api/export-alerts.csv?org_id=<test-org-id>` from authenticated session
   - Confirm CSV downloads with correct headers

4. **Check SafetySummaryCard loads data**
   - Open Fleet or Owner-Op dashboard
   - Verify card displays last 7 days of safety metrics

5. **Check TopRiskCorridors map renders**
   - Open Enterprise reports page
   - Verify MapLibre renders risk corridor polygons with heat colors

6. **Run smoke tests**
   ```bash
   npm run test:api:stage
   ```
   Confirm all critical endpoints return 200.

7. **Monitor logs and errors**
   - Check Sentry for any uncaught exceptions
   - Review Vercel function logs for errors

8. **Verify Stripe subscription gates**
   - Create Free account → confirm active load limit is 20
   - Upgrade to Pro → confirm limits removed instantly

9. **Warm critical endpoints** (optional)
   ```bash
   npm run rollout:warm
   ```

10. **Capture launch evidence**
    ```bash
    npm run rollout:evidence
    ```
    Saves screenshots/metrics to `evidence/` folder.

## Rollback Plan

If critical issues arise post-deploy:

1. **Revert Git commit**
   ```bash
   git revert HEAD
   git push origin main
   ```
   Vercel auto-redeploys previous version.

2. **Rollback database migration** (if schema change caused issue)
   ```bash
   supabase db reset --db-url <production-db-url>
   supabase db push --db-url <production-db-url> --linked
   ```
   **Warning:** Only if you have a backup. Test in staging first.

3. **Disable feature flag**
   ```bash
   npm run rollout:flags -- --disable roi,top_risk_corridors
   ```
   Hides new features without full rollback.

4. **Notify users**
   - Post status update on status page or in-app banner
   - Send email to affected orgs if necessary

## Success Criteria

- [ ] Homepage loads without 404
- [ ] App dashboard loads for authenticated users
- [ ] No Sentry errors in first 24 hours
- [ ] Supabase cron runs daily at 06:00 UTC
- [ ] CSV exports download successfully
- [ ] SafetySummaryCard displays live data
- [ ] TopRiskCorridors map renders with real corridors
- [ ] Stripe subscriptions create/update/cancel correctly
- [ ] API response times < 500ms (p95)
- [ ] Lighthouse score ≥ 95 on homepage and dashboard

---

**Checklist completed by:** _____________  
**Date:** _____________  
**Deploy commit SHA:** _____________
