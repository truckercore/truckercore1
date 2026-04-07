# Windows Deployment Guide

## Prerequisites

1. PowerShell 5.1+ (Windows 10/11)
2. Node.js 18+ (https://nodejs.org)
3. Supabase CLI
   ```powershell
   npm install -g supabase
   ```
4. Git (optional)

## Quick Start

### 1. Set Environment Variables

Option A: Interactive setup
```powershell
powershell .\scripts\Setup-Environment.ps1 -Save
```

Option B: Manual setup
```powershell
$env:SUPABASE_URL = "https://xxx.supabase.co"
$env:SUPABASE_SERVICE_ROLE_KEY = "eyJ..."
$env:SUPABASE_ANON_KEY = "eyJ..."
```

Option C: Using .env (project root)
```
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJ...
SUPABASE_ANON_KEY=eyJ...
```

### 2. Link Supabase Project
```powershell
supabase link --project-ref YOUR_PROJECT_REF
```

### 3. Run Deployment

Full deployment:
```powershell
npm run deploy:safety-suite:win
```

Or directly:
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Deploy-SafetySuite.ps1
```

Dry run (no changes):
```powershell
npm run deploy:safety-suite:win-dry
```

With flags:
```powershell
.\scripts\Deploy-SafetySuite.ps1 -DryRun
.\scripts\Deploy-SafetySuite.ps1 -SkipBuild
.\scripts\Deploy-SafetySuite.ps1 -SkipVerify
```

### 4. Verify Deployment
```powershell
npm run verify:safety-suite:win
```

## Troubleshooting

Execution policy error (scripts disabled):
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```
Or run with bypass:
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Deploy-SafetySuite.ps1
```

Missing environment variables:
```powershell
Get-ChildItem Env:SUPABASE_*
$env:SUPABASE_URL = "your-value"
[Environment]::SetEnvironmentVariable("SUPABASE_URL", "your-value", "User")
```

Supabase CLI not found:
```powershell
npm install -g supabase
supabase --version
```

Node version too old:
```powershell
node --version
```
Upgrade from https://nodejs.org

## Script Flags

Deploy-SafetySuite.ps1
- -DryRun: Show commands without executing
- -SkipBuild: Skip Next.js build
- -SkipVerify: Skip post-deploy verification

Examples:
```powershell
.\scripts\Deploy-SafetySuite.ps1 -DryRun
.\scripts\Deploy-SafetySuite.ps1 -SkipBuild
.\scripts\Deploy-SafetySuite.ps1 -SkipVerify
```

## CI/CD (GitHub Actions)

Create .github/workflows/deploy-windows.yml:
```yaml
name: Deploy Safety Suite (Windows)
on:
  push:
    branches: [main]
  workflow_dispatch: {}
jobs:
  deploy:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: '18'
      - name: Install Supabase CLI
        run: npm install -g supabase
      - name: Setup environment
        env:
          SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
          SUPABASE_SERVICE_ROLE_KEY: ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}
        run: |
          echo "SUPABASE_URL=$env:SUPABASE_URL" >> $env:GITHUB_ENV
          echo "SUPABASE_SERVICE_ROLE_KEY=$env:SUPABASE_SERVICE_ROLE_KEY" >> $env:GITHUB_ENV
      - name: Deploy
        run: npm run deploy:safety-suite:win
```

## Common Issues

1) "Supabase not linked"
```powershell
supabase link --project-ref YOUR_REF
```

2) Migration fails
```powershell
supabase db pull
# Reset (destructive!)
supabase db reset
```

3) Edge Function deploy fails
```powershell
supabase secrets list
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=xxx
supabase secrets set SUPABASE_URL=xxx
```

## Success Checklist
- Preflight checks pass
- Migration applied
- Edge Function deployed
- Verification tests pass
- Endpoints warmed
- CRON scheduled

## Final Usage
```powershell
# One-time setup
npm install -g supabase
.\scripts\Setup-Environment.ps1 -Save

# Deploy
npm run deploy:safety-suite:win

# Verify
npm run verify:safety-suite:win
```
