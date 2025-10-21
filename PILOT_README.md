# TruckerCore Pilot – Quick Walkthrough

Login with the provided test credentials.

1) Owner‑Op Pilot
- Go to /owner-op
- Check ROI chart (revenue/miles). Seed includes IFTA + fuel purchase → quarterly CSV via Functions.
- Click “Find Loads” in Deadhead panel to see nearby profitable loads filtered by $/mi.

2) Fleet‑20 Pilot
- Go to /fleet20
- ROI trend for a multi‑driver org (rollups run nightly; you can trigger chunked rollup now).

3) IFTA CSV
- Hit Functions URL: /generate-ifta-report?org_id=<OO_ORG_ID>&quarter=2025-07-01 with your bearer token.

4) Instant Pay (Demo)
- Create a payout_request then call /functions/instant-pay with { payout_request_id }.
- Status should move to “approved” (no Stripe transfer in demo).

5) Monitoring
- Cron runs: check alert_outbox for function failures and rollup freshness alerts.
- Weekly geo maintenance executes reindex/vacuum of loads spatial index.

6) Offline PoD
- Create a PoD PDF, toggle offline, upload → queued.
- Go online → files flush to storage via signed URL.
