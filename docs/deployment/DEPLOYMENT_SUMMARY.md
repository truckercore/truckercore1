# Safety Summary Suite - Deployment Summary

## Overview

Complete deployment automation for TruckerCore Safety Summary Suite supporting:
- Unix/Linux/macOS: Bash + Node.js scripts
- Windows: PowerShell scripts
- CI/CD: GitHub Actions workflows

## Components Deployed

### 1. Database (Supabase SQL)
- `safety_daily_summary` table
- `risk_corridor_cells` table
- `v_export_alerts` view
- `refresh_safety_summary()` RPC function

### 2. Edge Functions
- `refresh-safety-summary` (Deno/TypeScript)
- Scheduled via CRON: `0 6 * * *` (daily at 06:00 UTC)

### 3. API Routes (Next.js)
- `/api/export-alerts.csv` - CSV export endpoint

### 4. UI Components
- `ExportAlertsCSVButton` - Fleet/Owner-Op dashboards
- `SafetySummaryCard` - 7-day safety metrics
- `TopRiskCorridors` - Enterprise heat map + table

## Deployment Options

### Option A: Unix/macOS/Linux

bash
One-time setup
npm install -g supabase
export SUPABASE_URL="https://xxx.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="eyJ..."
export SUPABASE_ANON_KEY="eyJ..."
Deploy
npm run deploy:safety-suite
Or direct
node scripts/deploy_safety_summary_suite.mjs
Verify
npm run verify:safety-suite

### Option B: Windows (PowerShell)

powershell
One-time setup
npm install -g supabase
.\scripts\Setup-Environment.ps1 -Save
Deploy
npm run deploy:safety-suite:win
Or direct
.\scripts\Deploy-SafetySuite.ps1
Verify
npm run verify:safety-suite:win

### Option C: CI/CD (GitHub Actions)

yaml
Automatically deploys on push to main
See: .github/workflows/deploy-safety-suite.yml

## Available Scripts

| Command | Platform | Description |
|---------|----------|-------------|
| `npm run deploy:safety-suite` | Unix | Full deployment |
| `npm run deploy:safety-suite:dry` | Unix | Dry run (no changes) |
| `npm run deploy:safety-suite:win` | Windows | Full deployment |
| `npm run deploy:safety-suite:win-dry` | Windows | Dry run (no changes) |
| `npm run verify:safety-suite` | Unix | Post-deploy verification |
| `npm run verify:safety-suite:win` | Windows | Post-deploy verification |

## Deployment Steps

### Automated Flow

1. Preflight Checks
   - ✓ Supabase CLI installed
   - ✓ Node.js ≥18
   - ✓ Environment variables set
   - ✓ Project linked

2. SQL Migration
   - ✓ Create migration file (if missing)
   - ✓ Push to Supabase
   - ✓ Verify tables created

3. Edge Functions
   - ✓ Create function code (if missing)
   - ✓ Deploy to Supabase
   - ✓ Set secrets
   - ✓ Schedule CRON (manual step)

4. Web Build
   - ✓ Install dependencies
   - ✓ Build Next.js app
   - ✓ Verify build artifacts

5. Verification
   - ✓ Test table access
   - ✓ Test RPC function
   - ✓ Test Edge Function
   - ✓ Test views

6. Warmup
   - ✓ Prime endpoints
   - ✓ Measure response times

## Manual Steps (After Deployment)

### 1. Schedule CRON (Required)

bash
supabase functions schedule refresh-safety-summary "0 6 * * *"

### 2. Set Edge Function Secrets (If not set)

bash
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=eyJ...
supabase secrets set SUPABASE_URL=https://xxx.supabase.co

### 3. Verify CRON Schedule

bash
supabase functions list
Should show: refresh-safety-summary [scheduled: 0 6 * * *]

### 4. Add UI Components to Dashboards

Fleet Dashboard (`apps/web/pages/fleet/index.tsx`):

tsx
import { SafetySummaryCard } from '../../components/SafetySummaryCard';
import { ExportAlertsCSVButton } from '../../components/ExportAlertsCSVButton';
// Inside component:

Owner-Op Dashboard (`apps/web/pages/owner/index.tsx`):

tsx
// Same imports and usage as Fleet Dashboard

Enterprise Reports (`apps/web/pages/enterprise/reports/risk-corridors.tsx`):

tsx
import { TopRiskCorridors } from '../../../components/TopRiskCorridors';
// Inside component:

## Environment Variables

### Required

| Variable | Description | Example |
|----------|-------------|---------|
| `SUPABASE_URL` | Supabase project URL | `https://xxx.supabase.co` |
| `SUPABASE_SERVICE_ROLE_KEY` | Service role key (server-side only) | `eyJhbGc...` |

### Optional

| Variable | Description | Default |
|----------|-------------|---------|
| `SUPABASE_ANON_KEY` | Anon key (for client-side) | From env |
| `NEXT_PUBLIC_SUPABASE_URL` | Public URL (Next.js) | Same as SUPABASE_URL |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Public anon key | From env |

### Setting Variables

Unix/macOS/Linux:

bash
export SUPABASE_URL="https://xxx.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="eyJ..."

Windows (PowerShell):

powershell
$env:SUPABASE_URL = "https://xxx.supabase.co"
$env:SUPABASE_SERVICE_ROLE_KEY = "eyJ..."

Or use `.env` file:

env
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJ...
SUPABASE_ANON_KEY=eyJ...

## Verification Checklist

After deployment, verify:

- Tables exist and are accessible
  sql
  select count(*) from public.safety_daily_summary;
  select count(*) from public.risk_corridor_cells;

- RPC function works
  sql
  select public.refresh_safety_summary(null, 7);

- Edge Function is callable
  bash
  curl -X POST "${SUPABASE_URL}/functions/v1/refresh-safety-summary" \
    -H "Authorization: Bearer ${SERVICE_KEY}"

- CRON is scheduled
  bash
  supabase functions list

- CSV export works
  bash
  curl "http://localhost:3000/api/export-alerts.csv?org_id=xxx"

- UI components render
  - Visit Fleet dashboard → see SafetySummaryCard
  - Visit Owner-Op dashboard → see SafetySummaryCard
  - Visit Enterprise reports → see TopRiskCorridors

## Monitoring

### Edge Function Logs

bash
Real-time logs
supabase functions logs refresh-safety-summary --follow
Recent logs
supabase functions logs refresh-safety-summary --tail 100

### Database Metrics

sql
-- Check summary freshness
select org_id, summary_date, total_alerts, urgent_alerts, updated_at
from public.safety_daily_summary
order by updated_at desc
limit 10;

-- Check corridor cells count
select org_id, count(*) as cell_count, sum(urgent_count) as total_urgent
from public.risk_corridor_cells
group by org_id;

### Alerts

Set up alerts for:
- Edge Function execution failures
- RPC execution time >30s
- Zero rows in safety_daily_summary after 07:00 UTC
- CSV export endpoint 500 errors

## Rollback Procedure

If deployment fails or causes issues:

### 1. Disable CRON

bash
supabase functions unschedule refresh-safety-summary

### 2. Hide UI Components

Use feature flags or comment out imports:

tsx
// Temporarily disable
// import { SafetySummaryCard } from '../../components/SafetySummaryCard';

### 3. Revert Migration (CAUTION: Deletes Data)

bash
Only if absolutely necessary
supabase db reset
Then restore from backup

### 4. Restore Previous Edge Function

bash
Deploy previous version (if tagged)
# example
# git checkout v1.0.0
# supabase functions deploy refresh-safety-summary

## Troubleshooting

### Common Issues

"Supabase CLI not found"

Solution:

bash
npm install -g supabase
Verify
supabase --version

"Missing environment variables"

Solution:

bash
Check current vars
# env | grep SUPABASE
Set missing vars
export SUPABASE_URL="https://xxx.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="eyJ..."

"Project not linked"

Solution:

bash
supabase link --project-ref YOUR_PROJECT_REF

"Migration fails with duplicate table"

Solution:

bash
Check existing tables
supabase db pull
If table exists, migration will skip with "if not exists"
Or manually drop:
drop table if exists public.safety_daily_summary cascade;

"Edge Function times out"

Solution:
- Increase timeout in function code
- Reduce `p_days` parameter
- Add indexes to alert_events table:
  sql
  create index if not exists idx_alert_events_org_created 
  on public.alert_events(org_id, created_at desc);

"CSV export shows wrong org data"

Solution:
- Ensure RLS policies are correct
- Verify JWT claims include `app_org_id`
- Check `x-app-org-id` header in API route

## Performance Tuning

### Database Indexes

Already included in migration:

sql
create index idx_safety_summary_org_date on safety_daily_summary(org_id, summary_date desc);
create index risk_corridor_cells_gix on risk_corridor_cells using gist(cell);
create index idx_risk_corridor_org on risk_corridor_cells(org_id, urgent_count desc);

### Edge Function Optimization

- Uses `params=single-object` for RPC calls
- Batches operations per org
- Limits lookback window (default 14 days for summaries, 30 for corridors)

### UI Component Optimization

- SafetySummaryCard: Caches for 5 minutes
- TopRiskCorridors: Limits to top 50 cells
- CSV export: Streams response (no memory buffering)

## Security Considerations

### Service Role Key

- DO: Store in environment variables
- DO: Use server-side only (Edge Functions, API routes)
- DON'T: Expose in client-side code
- DON'T: Commit to Git
- DON'T: Include in public builds

### RLS Policies

All tables have Row Level Security enabled:
- `safety_daily_summary`: Read by org members
- `risk_corridor_cells`: Read by org members
- `v_export_alerts`: Read with anon key (filtered by org in API)

### API Route Security

`/api/export-alerts.csv`:
- Uses service role key (server-side)
- Filters by `org_id` query param
- Consider adding JWT validation for per-user scoping

## Cost Estimates

### Supabase Usage

| Resource | Usage | Est. Cost (Free Tier) |
|----------|-------|----------------------|
| Database Storage | ~10MB per 10k alerts | Free up to 500MB |
| Edge Function Invocations | 1/day + manual | Free up to 500k/mo |
| Bandwidth | ~1MB/1k CSV exports | Free up to 5GB/mo |

### Expected Load

- CRON: 1 execution/day = 30/month
- Manual refresh: ~10/day = 300/month
- CSV exports: ~100/day = 3k/month
- Total: ~3,330 operations/month (well within free tier)

## Support

For issues or questions:

1. Check logs: `supabase functions logs refresh-safety-summary`
2. Review troubleshooting section above
3. Verify environment variables
4. Check deployment checklist
5. Open GitHub issue with logs attached

## Success Metrics

Track these KPIs post-deployment:

- Availability: >99.5% Edge Function uptime
- Performance: <5s refresh execution time
- Accuracy: Zero duplicate summary rows
- Adoption: >50% of fleet managers use SafetySummaryCard weekly
- Errors: <0.1% CSV export failure rate

## Next Iteration

Future enhancements:
- Add Slack/email alerts for critical incidents
- Expose refresh API to authenticated users
- Add PDF export option
- Real-time updates via WebSockets
- Historical trend charts (30/60/90 days)
- Predictive risk scoring (ML model)
