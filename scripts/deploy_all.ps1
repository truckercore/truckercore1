param(
  [switch]$SkipBuild
)

# scripts/deploy_all.ps1
# Deploy all Supabase Edge Functions for this repository.
# Prerequisites:
#   - Supabase CLI installed and authenticated: https://supabase.com/docs/guides/cli
#   - SUPABASE_ACCESS_TOKEN configured via `supabase login` (or interactive)
#   - Project selected (CLI will prompt if not provided)
# Usage:
#   powershell -File scripts/deploy_all.ps1
#   powershell -File scripts/deploy_all.ps1 -SkipBuild   # skip function bundling step

$ErrorActionPreference = 'Stop'

# Update this list if you add/remove functions
$functions = @(
  'ai_matchmaker',
  'org_job_worker',
  'org_queue_worker',
  'admin_diagnostics',
  'synthetic_load',
  'metrics_push',
  'stripe_webhooks'
)

Write-Host "[deploy_all] Deploying $($functions.Count) functions..." -ForegroundColor Cyan

foreach ($fn in $functions) {
  try {
    $args = @('functions','deploy',$fn)
    if ($SkipBuild) { $args += '--no-verify' }
    Write-Host "[deploy_all] supabase $($args -join ' ')" -ForegroundColor DarkGray
    supabase @args
    Write-Host "[deploy_all] OK -> $fn" -ForegroundColor Green
  } catch {
    Write-Error "[deploy_all] Failed: $fn"
    throw
  }
}

Write-Host "[deploy_all] Done." -ForegroundColor Cyan
