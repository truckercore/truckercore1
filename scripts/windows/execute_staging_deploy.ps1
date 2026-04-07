param(
  [string]$SupabaseUrl,
  [string]$ServiceRoleKey,
  [string]$AnonKey,
  [string]$ProjectRef
)

$ErrorActionPreference = 'Stop'

Write-Host "=== TruckerCore Safety Suite: Staging Deploy (PowerShell) ===" -ForegroundColor Cyan

if (-not $SupabaseUrl -or -not $ServiceRoleKey -or -not $AnonKey -or -not $ProjectRef) {
  Write-Host "Usage: powershell -ExecutionPolicy Bypass -File scripts\\windows\\execute_staging_deploy.ps1 -SupabaseUrl <url> -ServiceRoleKey <key> -AnonKey <key> -ProjectRef <ref>" -ForegroundColor Yellow
}

$envFile = Join-Path (Get-Location) ".env.staging"

# 1) Create environment file (idempotent/overwrite)
@"
SUPABASE_URL=$SupabaseUrl
SUPABASE_SERVICE_ROLE_KEY=$ServiceRoleKey
SUPABASE_ANON_KEY=$AnonKey
SUPABASE_PROJECT_REF=$ProjectRef
NEXT_PUBLIC_SUPABASE_URL=$SupabaseUrl
NEXT_PUBLIC_SUPABASE_ANON_KEY=$AnonKey
"@ | Out-File -FilePath $envFile -Encoding UTF8

Write-Host "Created $envFile. Opening in Notepad so you can review/edit..." -ForegroundColor Green
try { Start-Process notepad $envFile -Wait } catch {}

# 2) Load environment into current process
Write-Host "Loading environment from .env.staging into Process scope..." -ForegroundColor Cyan
Get-Content $envFile | ForEach-Object {
  if ($_ -match '^(?<k>[^=]+)=(?<v>.*)$') {
    [Environment]::SetEnvironmentVariable($Matches['k'], $Matches['v'], 'Process')
  }
}

# 3) Validate required vars
$required = @('SUPABASE_URL','SUPABASE_SERVICE_ROLE_KEY','SUPABASE_ANON_KEY','SUPABASE_PROJECT_REF')
$missing = @()
foreach ($k in $required) { if (-not [Environment]::GetEnvironmentVariable($k, 'Process')) { $missing += $k } }
if ($missing.Count -gt 0) {
  Write-Error ("Missing environment variables: {0}" -f ($missing -join ', '))
  exit 1
}

# 4) Link Supabase project if possible (best-effort)
try {
  Write-Host "Linking Supabase CLI to project ref $ProjectRef (best-effort)..." -ForegroundColor Cyan
  supabase link --project-ref $ProjectRef | Out-Host
} catch {
  Write-Warning "Supabase link failed or CLI not installed. Ensure 'supabase' CLI is available in PATH."
}

# 5) Execute deployment
Write-Host "Running npm run deploy:safety-suite ..." -ForegroundColor Cyan
npm run deploy:safety-suite
if ($LASTEXITCODE -ne 0) {
  Write-Error "Deployment failed. Check output above."
  exit $LASTEXITCODE
}

# 6) Verification
Write-Host "Running npm run verify:safety-suite ..." -ForegroundColor Cyan
npm run verify:safety-suite
if ($LASTEXITCODE -ne 0) {
  Write-Warning "Verification reported failures. Review the logs above."
  exit $LASTEXITCODE
}

Write-Host "✅ Staging deployment and verification complete." -ForegroundColor Green
