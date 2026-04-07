# Safety Suite Deployment - Quick Reference

## 🚀 Quick Deploy

### Unix/macOS/Linux

bash
npm run deploy:safety-suite

### Windows

powershell
npm run deploy:safety-suite:win

## 🔧 One-Time Setup

### Unix/macOS/Linux

bash
npm install -g supabase
export SUPABASE_URL="https://xxx.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="eyJ..."
supabase link --project-ref YOUR_REF

### Windows

powershell
npm install -g supabase
.\scripts\Setup-Environment.ps1 -Save
supabase link --project-ref YOUR_REF

## ✅ Verify

bash
npm run verify:safety-suite        # Unix
npm run verify:safety-suite:win    # Windows

📅 Schedule CRON (Required After First Deploy)

bash
supabase functions schedule refresh-safety-summary "0 6 * * *"

🔍 Check Status

bash
# Function logs
supabase functions logs refresh-safety-summary --tail 50

# List functions
supabase functions list

# Check secrets
supabase secrets list

📊 Test Endpoints

bash
# RPC
curl -X POST "$SUPABASE_URL/rest/v1/rpc/refresh_safety_summary" \
  -H "apikey: $SERVICE_KEY" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d '{"p_org":null,"p_days":7}'

# Edge Function
curl -X POST "$SUPABASE_URL/functions/v1/refresh-safety-summary" \
  -H "Authorization: Bearer $SERVICE_KEY"

# CSV Export
curl "http://localhost:3000/api/export-alerts.csv?org_id=xxx"

🆘 Troubleshooting

Issue | Solution
---|---
Supabase CLI not found | npm install -g supabase
Missing env vars | Run Setup-Environment.ps1 (Windows) or export (Unix)
Project not linked | supabase link --project-ref YOUR_REF
Migration fails | Check logs: supabase db push --debug
Function times out | Reduce p_days parameter

🔐 Security
- Keep `SUPABASE_SERVICE_ROLE_KEY` server-side only
- Never commit secrets to Git
- Use .env file for local development
- Verify RLS policies are enabled

📁 File Structure

scripts/
├── deploy_safety_summary_suite.mjs    # Unix deployment
├── verify_safety_summary.mjs          # Unix verification
├── Deploy-SafetySuite.ps1             # Windows deployment
├── Verify-SafetySuite.ps1             # Windows verification
└── Setup-Environment.ps1              # Windows env setup

supabase/
├── migrations/
│   └── 20250928_refresh_safety_summary.sql
└── functions/
    └── refresh-safety-summary/
        └── index.ts

components/
├── ExportAlertsCSVButton.tsx
├── SafetySummaryCard.tsx
└── TopRiskCorridors.tsx

pages/
└── api/
    └── export-alerts.csv.ts

📈 Success Metrics
- All verification tests pass (6/6)
- CRON scheduled and runs daily
- CSV exports work
- UI components render
- Zero 500 errors in logs

🎯 Next Steps After Deploy
- Add UI components to dashboards
- Test CSV export with real data
- Verify Risk Corridors map
- Monitor Edge Function logs
- Check first CRON execution (next day 06:00 UTC)
